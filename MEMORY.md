# Home Lab Project - AI Memory

**Purpose:** Context reload for AI. No humans read this.

---

## PROJECT SCOPE (READ FIRST — stay in your lane)

This repo covers the **INFRASTRUCTURE layer ONLY**:
- Hardware (HP Z6 G4 Proxmox host, NAS, networking)
- Proxmox host config, kernel/package management, storage, backups
- VM provisioning / deployment / lifecycle management (create, resize, snapshot, shut down, restore)
- Host-level services that make VMs reachable (DNS, port-forwards, firewall at the infra edge)

It does **NOT** own the **APPLICATION layer**. Application state, functionality, image tags,
DB schema, app docker-compose internals, and app config are owned by their OWN projects
(e.g. **Capricorn** / `unified_ui_DEV_PROD_GCP`). 

Practical rules:
- Do NOT maintain or "reconcile" application docker-compose files, app image tags, or app DB
  contents here. That's the app project's job. If you capture them, label them clearly as a
  *read-only reference snapshot* and point to the owning project — don't treat drift as a bug here.
- At the VM level, document only what's infra-relevant: "vm-www-1 (.184) runs Docker + a Traefik
  ingress (80/443, Let's Encrypt) and hosts the Capricorn PROD stack + splash page." The internals
  of that stack live in the Capricorn project.

---

## CURRENT STATE

- **🔵 ACTIVE — Phase 14: Kubernetes + Redpanda POC (interview prep).** Plan + learning material
  in `phases/phase14_k8s_redpanda_poc.md`. **🎯 THE ROLE: SRE / DevOps on an ORDER MANAGEMENT
  SYSTEM at a hedge fund** (confirmed Jul 27). This drives everything — weight all material toward
  **operational** reasoning (what breaks, what the cluster does about it, what you do at 3am, which
  reflexes make an incident worse) over application design, and tie every concept back to a
  consequence for **order/trade processing** (e.g. unkeyed producers → a cancel processed before
  its order; a degraded cluster → don't rolling-restart it). Interview ~Aug 1.
  **Parts 1, 2, 3 and 4 all COMPLETE (July 25–27).** Restore points on VM 186:
  `s01-base-clean` (pre-k3s) → `s02-k3s-up` (k3s only, **predates Redpanda**) →
  **`s03-redpanda-up` (Jul 27 14:58) = the one to roll back to.** Live snapshot with guest-agent
  fs-freeze, 1.5 s, VM never stopped; verified healthy with 0 restarts afterwards.
  **Next: consumer groups + rebalancing, then Part 6 (the Python app).**
  - **k3s v1.36.2+k3s1 on VM 186.** Installed with
    `curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -`.
    Node `Ready`, containerd 2.3.2 (NOT Docker), ~512 MB RSS, survives reboot. `kubectl` and
    `crictl` in `/usr/local/bin` are **symlinks to the k3s binary**. `k3s-uninstall.sh` removes
    everything.
  - **kubeconfig:** `/etc/rancher/k3s/k3s.yaml` (mode 644) copied to `~/.kube/config` (mode 600).
    ⚠️ It points at **`127.0.0.1:6443`, so it only works ON VM 186** — for the Z8, copy it and
    change the server to `https://192.168.1.186:6443`.
  - ⚠️ **`chown $(id -u):$(id -g)`, never `chown $USER`** — `$USER` leaves the group as root and is
    unset in non-interactive SSH commands.
  - ⚠️ **`kubectl wait --for=condition=Ready pods --all` times out on a HEALTHY cluster.** Job pods
    (`helm-install-traefik`) reach `Completed`, never `Ready`. `Completed` is success.
  - k3s re-applies its add-ons from `/var/lib/rancher/k3s/server/manifests/`, so deleting a whole
    add-on Deployment gets it rebuilt from there.
  - **`local-path` PVs carry a hard nodeAffinity** to the node + `WaitForFirstConsumer` binding.
    Consequence: on node loss a pod is NOT rescheduled elsewhere, it sits `Pending` forever.
  - **A `local-path` PV is literally a directory** at
    `/var/lib/rancher/k3s/storage/<pv-name>_<ns>_<claim>/`, on the VM's single `/dev/sda1` ext4
    root. **The requested capacity is not enforced — there is no quota**, so a runaway pod can
    fill the node. `ALLOWVOLUMEEXPANSION=false` (can't grow it) and `RECLAIMPOLICY=Delete`
    (`kubectl delete pvc` destroys the data instantly, no prompt). Proxmox knows nothing below
    "VM 186 has a 300 GB disk".
  - ⚠️ **`kubectl delete pod` blocking for ~30 s is normal**, not a hang. Default
    `terminationGracePeriodSeconds` is 30, and **PID 1 in a container only receives signals it has
    installed a handler for** — even from the kubelet. Plain `sh`/`sleep` ignores SIGTERM and waits
    for the SIGKILL. Measured here: `sh -c "sleep 3600"` 31 s, same with a `trap ... TERM` 2 s,
    nginx 2 s, `--grace-period=5` 7 s. **Never `--grace-period=0 --force` a broker** — the
    StatefulSet replacement can start while the original still holds the volume.
  - **Debugging a Service that blackholes: check `kubectl get endpointslices`.** kube-proxy never
    evaluates label selectors; the EndpointSlice controller does, and writes the pod-IP list that
    kube-proxy turns into iptables rules. Empty slice = selector matches nothing, even though every
    pod is healthy. Also: **`curl -w "%{remote_ip}"` cannot identify the backend** — DNAT is
    transparent, so it always reports the ClusterIP. Read the pods' own logs instead.
  - **Services load-balance per TCP connection, not per request** → a gRPC/HTTP2 client pins to one
    pod forever. Fix with a headless Service + client-side LB, or a mesh. Likely interview question
    given the firm moves market data over gRPC.
  **Part 4 — Redpanda (July 27, 1:00–2:50 PM). 3 brokers live in ns `redpanda`, healthy 3/3.**
  Chart `redpanda-26.1.9` / app `v26.1.12`, `rpk v26.1.14`, Helm v3.21.3. PVCs
  `datadir-redpanda-{0,1,2}` 20Gi local-path. Topic `market-ticks` 6 partitions RF 3. Full runbook =
  `education/chapter03_redpanda.md`; the working values file is
  **`education/manifests/redpanda-values.yaml`** (verified to reproduce the live release).
  - ⚠️ **The chart's documented anti-affinity override `statefulset.podAntiAffinity.type: soft` is
    VESTIGIAL in 26.1.9 — it silently does nothing.** Hard anti-affinity means only 1 broker can
    schedule on a 1-node cluster. Real path: `statefulset.podTemplate.spec.affinity` — set
    `requiredDuringSchedulingIgnoredDuringExecution: null` + add a `preferred...` term.
    **Habit: `helm template … | grep -A14 affinity` BEFORE installing anything you're overriding.**
  - Failed-install symptom cascade: Helm hangs → pods `Pending` → **PVCs `Pending` are a *symptom***
    (local-path is WaitForFirstConsumer) → redpanda-0 never Ready (can't quorum alone) → config Job
    fails → Console crash-loops. **Read events on the earliest stuck thing, not the loudest broken
    one:** `kubectl -n redpanda describe pod redpanda-1 | tail -20`.
  - `helm uninstall` **leaves StatefulSet PVCs behind.** `kubectl -n redpanda delete pvc --all` for a
    truly clean reinstall. A `redpanda-configuration-*` pod in `Error` beside a `Complete` Job is
    normal Job backoff (post-install raced broker readiness) — judge the Job, not the pod.
  - **`rpk` = `/usr/local/bin/rpk`, a plain static binary — NOT an alias.** Kafka API `:9093`,
    Admin API `:9644` (`rpk cluster health` uses Admin). Profile `local` in `~/.config/rpk/rpk.yaml`
    bootstraps off **all three** internal FQDNs so diagnostics survive a dead broker.
  - **Advertised-listener fix:** dialling `localhost:31092` failed with an error naming
    `redpanda-0...` — bootstrap only asks "who are the brokers?", then the client dials the
    **advertised** addresses directly. Fixed with
    `/etc/systemd/resolved.conf.d/k3s-cluster-dns.conf` → `DNS=10.43.0.10` (CoreDNS),
    `Domains=~cluster.local` (`~` = routing-only). Survives pod replacement (nothing references a
    pod IP). ⚠️ **Works only because the host IS the node** (pod IPs on `cni0`); not LAN-wide.
    General rule: *a broker must advertise an address clients can resolve AND route to, from where
    the client is.*
  - ⚠️ **`rpk topic describe -p`: HIGH-WATERMARK is awk field `$8`, not `$6`** — `REPLICAS [0 1 2]`
    contains spaces. HWM = committed record count; summing it is the authoritative total.
  - ⚠️ **`rpk topic consume -n N` HANGS** when fewer than N records exist, and `| wc -l` then shows
    nothing (no EOF). **`-o :end` = read all and exit.** `-o start:end` silently returns **0** —
    looks exactly like data loss.
  - **Unkeyed is NOT round-robin.** Sticky partitioner sent 6 unkeyed → 1 partition and **300
    unkeyed → still 1 partition**; *which* partition is random per producer session (p1 one run, p5
    the next). Keys are deterministic and reproduced exactly: AAPL→3, GOOG→3, MSFT→0, TSLA→5,
    AMZN→5 (5 keys, 3 partitions, 2 collisions, p1/p2/p4 idle). Demo partitioning with **one**
    producer (`printf 'a\nb\n' | rpk topic produce`), never a shell loop — a loop spawns a producer
    per record and fakes round-robin.
  - **Failure drills.** One broker down: failover is surgical but **not load-balanced** (2/2/2 →
    broker 2 took *both* orphans, leading 4); writes never stopped. After recovery **`Healthy: true`
    while broker 1 leads 0 partitions** — the leader balancer runs on its own timer, so *healthy ≠
    balanced*. Quorum loss (scaled to 1): survivor goes `1/2 Running` and steps down,
    `Leaderless (8)` incl. **`redpanda/controller/0`** (admin dies too), producers **hang rather
    than error**, and ⚠️ **`Under-replicated` reads 0 because no leader is left to compute it.**
    **Alert on `Leaderless` + `Nodes down`; `Under-replicated` alone will mislead you.**
  - **Zero data loss proven:** 32 records, `-o :end` count == Σ HWM. Both writes made while degraded
    survived; the write that hung during quorum loss never appeared. OMS framing = *never lies about
    whether an order was accepted*.
  - **Drill hygiene:** always `kubectl -n redpanda wait --for=delete pod/<name>` before judging.
    Checking too fast caught a `Terminating`-but-still-serving broker and produced a write that
    "should" have failed.

  - **`education/` series** — printable study chapters with diagrams (Andrew's idea, for the
    interview). **Ch1 (Kubernetes/k3s) 846 lines / 6 diagrams / 31 questions; Ch2 (object model)
    631 lines / 2 diagrams / 27 questions; Ch3 (Redpanda) 1023 lines / 3 diagrams / 33 questions.**
    Ch2 and Ch3 are deliberately **replayable runbooks** — Andrew re-runs this material, so where
    output varies between runs (sticky-partition choice, initial leader assignment, which partition
    an unkeyed producer picks) the text says so explicitly. `education/manifests/` holds real tested
    artefacts: `redpanda-values.yaml` and `web-deployment.yaml` (the latter verified end-to-end
    apply → rollout → 200s → delete on Jul 27, with both probe failure drills documented inline).
    Rule for this series: only document things Andrew actually ran. **Diagrams are Graphviz `.dot`
    sources in `education/diagrams/`, deliberately NOT AI-generated** (image models garble technical
    labels); `graphviz` installed on the Z8. Two HTML-label gotchas: newlines render as literal
    leading spaces (keep each table cell on one source line), and `BALIGN="LEFT"` only affects lines
    *after* a `<BR/>` — set **both** `ALIGN="LEFT" BALIGN="LEFT"` on the `<TD>`, and use a one-cell
    `<TABLE>` instead of `shape=box` for callout boxes.
  - **Teaching format that works: Andrew types every command, I verify out-of-band over SSH and
    explain the output.** Used for Parts 3 & 4 and the Ch2 session. He catches his own anomalies this
    way (he spotted the 30-second delete himself), and his mistakes turn into the best documentation.

  **Chapter 2 hands-on session (July 27, 3:00–3:30 PM) — Deployments, rollouts, probes.**
  All in `default` ns on VM 186 with `nginx:1.27-alpine`, `replicas:3`, `maxSurge:1`,
  `maxUnavailable:0`. Produced 5 revisions across 4 ReplicaSets. **Cleaned up afterwards; Redpanda
  untouched (Healthy, 33 records).** Findings worth keeping:
  - **The centrepiece is the readiness-vs-liveness asymmetry, and it demoed perfectly.** Same broken
    path (`/healthz` → nginx 404) wired two ways. **Readiness broken = fails SAFE:** rollout stalls
    at 4 pods / 3 Ready, EndpointSlice shows the bad pod `ready=false`, service serves
    `200 200 200 200 200 200` — the bad build never took a request. **Liveness broken = fails
    DEADLY:** rollout SUCCEEDS (readiness still passed), all 3 good pods deleted, then every pod
    hits `CrashLoopBackOff` restarts=4 → `000 000 000 000 000 000`, total outage. One-liner:
    **"readiness gates the rollout, liveness does not."** This is Fig 2 of Ch2.
  - **`CrashLoopBackOff` + `Exit Code: 0` = something EXTERNAL killed it, nearly always liveness.**
    Best single debugging heuristic from the session; nginx caught SIGTERM and exited clean.
  - **`rollout status --timeout=60s` is CLIENT-side only.** It returned failure while
    `progressDeadlineSeconds=600` kept the rollout grinding. SRE angle: a red CI job can leave a
    half-rolled deploy running that everyone assumes never shipped.
  - **`Available=True` while the deploy was broken** (3 pods serving). Availability ≠ rollout success;
    monitor `Progressing` too.
  - **`rollout undo` leaves a landmine.** Measured after a successful rollback: live cluster `/` (good)
    but **both** the file on disk and `last-applied-configuration` still `/healthz` (broken). Next
    `apply` re-ships the outage. Andrew got this immediately — it's the strongest GitOps argument
    we have. Also: **revisions get re-tagged** (history went `1,2,3` → `1,3,4`), so a revision number
    quoted earlier in an incident may no longer exist.
  - **Two rollbacks behaved differently and the contrast is the lesson:** after the readiness stall
    the good pods were *never touched* (RS stayed 3/3, age kept climbing to 8m38s) = zero disruption;
    after the liveness outage the good pods were already destroyed, so rollback had to create new
    ones under the same hash = real downtime.
  - **Andrew's one real misconception, worth re-checking later:** he thought `maxUnavailable` protects
    Raft quorum. It does not — it is a **capacity** guarantee; the Deployment controller counts Ready
    pods and knows nothing about consensus. Corrected in Ch2 §9 with the StatefulSet / PDB /
    cluster-aware-readiness answer, tied back to Ch3's finding that `Healthy: true` can coexist with a
    broker leading zero partitions.
  - Also confirmed: `apply` printing `configured` does **not** imply a rollout (only pod-template
    changes churn pods); scaling creates no new ReplicaSet; labels are per-object (`-l app=web` missed
    the Deployment until `metadata.labels` was added).

  **From the Parts 1 & 2 build (July 25) — still current:**
  - **The lab now has its first VM template: 9000 `tmpl-ubuntu-2404-cloudinit`** (Ubuntu 24.04
    cloud image + baked-in `qemu-guest-agent`, cloud-init drive, `--ciupgrade 0`). Clone → fully
    booted VM in **~30 seconds**. This replaces hand-building from an ISO; see the
    "CLOUD-INIT TEMPLATE" section below for the exact recipe.
  - **VM 186 `vm-k8-redpanda-1` @ .186** built from it: 16 vCPU / 32 GB / 300 GB on vm-ephemeral,
    `host_setup.sh` applied. Snapshots: **`s01-base-clean`** (pre-k3s) and **`s02-k3s-up`**.
  - **⚠️ Never use `/root/.ssh/authorized_keys` on the Proxmox host as a cloud-init key source** —
    it's a symlink to `/etc/pve/priv/authorized_keys` and holds only the PVE cluster RSA key, not
    Andrew's workstation key. Use **`/root/cloudinit-keys-all.pub`** (both keys) instead.
  - **`host_setup.sh` installs Chrome + Cursor** (~1.8 GB) — it's a desktop script. On headless
    VMs, purge them after: `apt-get purge -y google-chrome-stable cursor && apt-get autoremove --purge -y`.
    It also needs `smb_credentials` downloaded next to it; it does not fetch that itself.
  - **PVE snapshot names must start with a letter** (they're config IDs). `01-base-clean` fails
    with `invalid configuration ID`; use `s01-base-clean`.
  - VM 186 is **excluded from `refresh.sh`** and has `unattended-upgrades` + `apt-daily` timers
    **disabled** — no package churn while learning on it.

- **✅ Dev workstation OS upgrade: Ubuntu 25.10 → 26.04 LTS — July 25, 2026.** The Z8's
  VMware guest (`VM-UBUNTU-01`, the machine we work from — NOT infra, logged here because
  it's our tooling host). Now **26.04 "Resolute Raccoon", kernel 7.0.0-28**. Upgrade itself
  was clean (0 broken pkgs, 0 failed units). Post-upgrade review found + fixed 4 real breaks:
  - **All 5 third-party apt repos were disabled** by `do-release-upgrade` (standard behavior).
    Re-enabled cursor/docker/chrome/hashicorp + fixed stale suites (docker `questing`→`resolute`,
    hashicorp `noble`→`resolute`). That surfaced 7 Docker pkgs still on 25.10 builds → upgraded
    to the 26.04 rebuilds (same versions); daemon restart bounced containers, all returned
    (`unless-stopped`). **NodeSource left DISABLED on purpose** (pinned dead `node_20.x`, older
    than Ubuntu's node 22 → would conflict; re-enabling needs an apt pin).
  - **npm/npx vanished:** node moved NodeSource 20 → Ubuntu's **22.22.1**, which doesn't bundle
    npm. Ubuntu's `npm` pkg wanted **377** `node-*` deps for a 2022-era npm 9 → skipped. Instead
    installed official **npm 11.18.0** standalone in `/usr/local` (npm 12 needs node ≥22.22.2;
    Ubuntu ships .1). Upgrade path later: `sudo npm i -g npm@latest`. corepack also gives pnpm/yarn.
  - **Python 3.13 → 3.14 orphaned 38 user pip pkgs** (`~/.local/lib/python3.13`, 82M, deleted;
    inventory saved at `~/python313-packages-before-2604-upgrade.txt`). poetry+virtualenv
    rebuilt via **pipx** (isolated venvs → immune to future python bumps). Flask 2.0.3 + httpx
    deliberately NOT recreated (26.04 enforces PEP 668; nothing on the host needs them — the
    Capricorn backend gets httpx from its container).
  - **`sshfs-openclaw.service` disabled** — was retrying the retired VM 185 every 100s forever.
  - Housekeeping: 37 `rc` configs purged, orphaned postgresql-client-17 removed (18 present),
    17 stale snap revs deleted (5.2G→2.7G) + `refresh.retain=2`, dead apt `.bak`/`.orig` files
    archived to `/root/apt-sources-backup-20260725/`. Kept 6.17.0-41 kernel as fallback.
  - Config files the upgrade replaced (all reviewed, no loss): sysctl.conf identical, grub kept
    ours, gdm3 autologin survived, ca-certificates replaced with 26.04 default (distrusts 39
    legacy Mozilla CAs — correct, applied cleanly).
  - Verified after: Docker 29.6.2 + all 5 containers up, Capricorn FE/BE 200, GitLab 200,
    public https 200, CIFS `/mnt/DevShare` mounted, ssh-agent key loaded, journal clean.
  - **Capricorn NOT reviewed** (app layer, own project). Checked exposure only: backend
    container = python 3.11.8, frontend container = node 22.23.1, host `node_modules` has no
    native `.node` binaries, no engines/.nvmrc pin → host node 20→22 actually aligns *closer*
    to the containers. No action expected.

- **✅ Phase 13 Proxmox host audit + same-day fixes — July 9, 2026.** Full record in
  `phases/phase13_fable_proxmox_audit.md` (findings, action plan, implementation log). Done:
  - **Email alerting LIVE:** PVE notification endpoint `gmail-smtp` (smtp.gmail.com:587,
    app password in PASSWORDS.md "Gmail SMTP Relay") + default matcher retargeted; postfix
    relayhost + SASL + `root:` alias → ZED/smartd/vzdump/cron mail all reach Andrew's Gmail.
    Both paths tested + confirmed received. Rollback notes in phase13.
  - **Host upgraded to PVE 9.2.4**, 0 pending pkgs. Kernel 7.0.14-4 pin-tested + adopted
    same day (see below). Stale bookworm apt entries removed (`/etc/apt/sources.list` emptied, backup
    `/root/sources.list.bak-20260709`).
  - **ARC cap 8G → 16G** (runtime + `/etc/modprobe.d/zfs.conf`, initramfs rebuilt).
  - **rpcbind/nfs-client disabled** (port 111 closed; NAS backups are CIFS, unaffected).
  - **`zpool upgrade` all 3 pools** (feature-current). **VM200 snapshot deleted** (+5.1G);
    only remaining snapshot = 184's `pre_phase12_firewall` (keep until Phase 12 window closes).
  - **Tools added:** nvme-cli, numactl, lm-sensors (+ coretemp persisted via
    /etc/modules-load.d/coretemp.conf), libsasl2-modules. CPU pkg ~51°C healthy.
  - **vm-ephemeral REBUILT with ashift=12** (afternoon session, ~10 min downtime): 182+200
    shut down → disks qm-move-disk'd to vm-critical → pool destroyed/recreated (same 2 NM620s,
    by-id, `-o ashift=12` + lz4) → disks back → VMs verified healthy. Old pool was ashift=9.
  - **AMT verified DISABLED without BIOS visit:** HP exposes BIOS read-only from Linux via
    `/sys/class/firmware-attributes/hp-bioscfg/attributes/` (280 attrs). "Intel AMT" = Disable,
    "ME Firmware Mode" = "AMT Disabled"; all AMT ports (623/664/5900/16992-5) closed from LAN.
    **This sysfs trick works for reading ANY BIOS setting on the HP hosts — remember it.**
  - **⏸️ DEFERRED by Andrew:** SSH key-only hardening (SEC-1) + web UI TOTP (SEC-2) + host.fw —
    LAN-only home lab behind Phase 12 perimeter; revisit later.
  - **❎ WON'T-FIX by Andrew:** vzdump backups for 183 (Sonar, barely used) + 184 (WWW =
    vanity/demo box) — both easily rebuilt. Only GitLab (181) holds irreplaceable data.
    **VM 185 (OpenClaw) stays dormant as-is** (not destroyed).
  - **Audit discoveries:** host runs Tailscale (100.108.209.77, `pve` on tailnet); idle Quadro
    P2000 GPU (nouveau, passthrough candidate); SNC enabled in BIOS → 2 NUMA nodes (64G each);
    only 4/6 memory channels populated; fallback kernel 6.17.2-1 no longer on ESPs.
  - **✅ Console visit DONE (Jul 9, 12:53 PM):** SNC disabled in BIOS (host is now 1 flat
    NUMA node / 128GB) AND kernel **7.0.14-4-pve pin-tested + made PERMANENT pin** (booted
    clean 1st try: 6/6 NVMe, 0 errors, pools ONLINE, VMs up, public site 200). Fallbacks on
    ESPs: 7.0.6-2 + 6.17.13-x. Slot 5 Bifurcation x4x4x4x4 unaffected (it, not SNC, drives
    the quad-NVMe card — Andrew's question, answered from hp-bioscfg).
  - **Subscription nag:** widget-toolkit 5.2.6 (Jul 9 upgrade) broke the old sed patch in
    `/usr/local/bin/proxmox-update.sh`. BOTH fixed: live proxmoxlib.js patched (check →
    `false`) and update script line 28 now uses a perl pattern matching the new code
    (idempotent). If nag reappears after a future update → pattern needs refreshing again.
  - **✅ GitLab backup test-restore drill PASSED (Jul 9, 1:20 PM):** qmrestore of the
    nightly vzdump → VMID 999 on vm-ephemeral (2m17s), clone kept its baked-in .181 IP but
    was isolated on a **host-only bridge vmbr999 + /32 route** (no LAN exposure; live 181
    unaffected). Verified 16/16 services, DB (4 users / 5 projects), and a real
    `git clone` of capricorn (306 files). Torn down clean. Procedure in phase13 (bottom).
    Repeat ~quarterly (agent can now do in-VM checks directly).
  - **✅ qemu-guest-agent on ALL 5 live VMs (Jul 9, 1:28 PM):** installed in guests
    181/182/183/184/200 + `agent enabled=1` + graceful stop/start each (runner idle-checked,
    GitLab last). All answer `qm agent ping`. Restarts also put every VM on the **new QEMU
    11.0.2** binary (upgrade loose end closed). All services verified healthy after.
    185 (dormant) skipped — add agent if ever revived.
  - **Still open/optional:** 2x32GB DIMMs for 6-channel bandwidth; tailscaled NetInfo log
    noise (G3100 UPnP flapping; fix = TS_DEBUG_DISABLE_PORTMAPPER override if it bothers);
    delete 184 snapshot `pre_phase12_firewall` ~mid-July.
  - **Dev workstation (Z8) side quest:** Ubuntu VMware VM resized 32→24 vCPUs **as 2 sockets
    x 12** — Andrew found 2x12 makes Windows place the VM on idle PROC1 (1x24 co-locates with
    Windows on PROC0). +11%/thread, 93% scaling eff. Details in phase13 addendum.

- **✅ Phase 12 network perimeter lockdown — IMPLEMENTED July 8, 2026.** Full detail in
  `phases/phase12_network_segmentation.md`. What's live now:
  - **Router (G3100):** deleted public VNC/ARD forwards (3283/5900/5988→.200); Mac-mini is
    Tailscale-only. Kept: 80/443→.184, Plex .200:32400, Tailscale UPnP holes, .100 (Verizon
    ARRIS equipment — ISP-managed, accepted). UPnP stays ENABLED (Andrew's call).
  - **Capricorn deploy = PUSH model:** `deploy_prod_local` now pulls images on the runner (.182)
    and streams them via `docker save | ssh .184 "docker load"`. .184 never contacts the
    registry. On `production` (e0f3057) AND `develop` (9e5d2dc). Live-tested: pipeline #137
    job #722 succeeded, cap.gothamtechnologies.com 200.
  - **.184 is inbound-only (Proxmox fw):** `/etc/pve/firewall/184.fw` — IN policy DROP
    (allow 80/443 anywhere; 22 from .182/.195/.150 only; LAN ICMP); OUT = ACCEPT to gateway .1
    + internet, DROP to all RFC1918. Datacenter fw ENABLED via new `cluster.fw` (was disabled —
    the old 184.fw had been inert). Other VMs have no .fw files → unaffected (185.fw exists,
    VM stopped). Rollback: `/root/184.fw.bak-20260708` on pve, VM snapshot `pre_phase12_firewall`.
  - **Validated:** .184→.180/.181/.183/.150 all blocked; .184→internet/DNS works; public 200;
    .195/.182 SSH in OK; .181→.184:22 blocked; :8080 dashboard blocked from LAN.
  - **Still open (minor):** off-LAN scan of WAN IP (needs external vantage); .195 workstation
    is STATIC IP (SSH allowlist rule safe). Related Capricorn work: `unified_ui_DEV_PROD_GCP`
    `project/phases/phase22*` (app has NO auth + is the sole public door → app hardening matters).

- Proxmox running at 192.168.1.150 (HP Z6 G4: single Xeon Platinum 8168 24c/48t, 128GB RAM, ZFS) — **PVE 9.2.4**, kernel **7.0.14-4-pve** (pinned + tested Jul 9, 2026; SNC disabled → single NUMA node)
- **NOTE:** The Proxmox server is a **Z6 G4** (single CPU, 128GB). The **dev workstation** we work from is a **Z8 G4** (dual Platinum 8168, 256GB). Don't confuse the two.
- **Dev workstation guest** = `VM-UBUNTU-01`, VMware Workstation on the Z8, 24 vCPU (2 sockets x12, on idle PROC1), **Ubuntu 26.04 LTS** since Jul 25, 2026 (see CURRENT STATE). Uses `open-vm-tools`, NOT qemu-guest-agent (that's for the Proxmox VMs). Not on Tailscale.
- **Jun 18, 2026: kernel fully un-stuck.** Went 6.17.2-1 → 6.17.13-13 → **7.0.6-2-pve** (all NVMe-clean), full host upgrade to PVE 9.2.3, all package holds removed. 7.0.6-2 tested via --next-boot, then made permanent and confirmed it boots autonomously (2 reboots clean). 6.17.13-13 kept as fallback. See current_phase.md + phase1b.
- Script server running at http://192.168.1.195/scripts/
- **GitLab CE LIVE at http://192.168.1.181** (root/[See PASSWORDS.md])
- **GitLab Runner LIVE at 192.168.1.182** (gitlab-runner-1, v18.7.2)
- **Container Registry OPERATIONAL** on port 5050
- **CI/CD Pipeline PRODUCTION-READY** - Full automation working!
- **Test app deployed:** http://192.168.1.180:8080 (via pipeline)
- **Capricorn QA:** http://192.168.1.180:5001 (auto-deploy on develop push)
- **Capricorn GCP:** http://capricorn.gothamtechnologies.com (manual deploy on production)
- **GitHub repos:** home-lab-setup + Capricorn (both updated)
- **SonarQube LIVE at http://192.168.1.183:9000** (v26.1.0, admin/[See PASSWORDS.md])
- **Phase 6 COMPLETE:** Both test-app and Capricorn integrated with SonarQube!
- **Phase 7 COMPLETE:** Local WWW Server operational + all documentation updated! (vm-www-1 @ .184)
- **PROD URLs (PRIMARY):** https://cap.gothamtechnologies.com (Capricorn) + https://www.gothamtechnologies.com (splash)
- **GCP Instance (on-demand):** https://capricorn.gothamtechnologies.com (for public demos)
- **Cost Savings:** ~$400/year by replacing GCP hosting
- **README Files:** Both projects direct users to cap.* as primary production URL
- **Phase 11 COMPLETE:** OpenClaw AI Agent Server LIVE (vm-openclaw-1 @ .185, Tailscale Serve, Telegram)
- **`refresh` command on Proxmox:** Parallel update + reboot of all 5 VMs (.180-.184, excluding .185), live status display. See REFRESH SCRIPT section.
- Next: Phase 8 (Monitoring Stack)

---

## IPs & HOSTS

| Host | IP | Status |
|------|-----|--------|
| Proxmox | .150 | ✅ Running |
| QA/K8s | .180 | ✅ Built (vm-kubernetes-1) |
| GitLab | .181 | ✅ LIVE |
| Runner | .182 | ✅ LIVE (gitlab-runner-1) |
| SonarQube | .183 | ✅ LIVE (vm-sonarqube-1, v26.1.0) |
| **WWW** | **.184** | **✅ LIVE (vm-www-1, Traefik, Capricorn PROD, Splash)** |
| **OpenClaw** | **.185** | **⏸️ DORMANT (vm-openclaw-1) — retired, do not use** |
| **K8s/Redpanda POC** | **.186** | **🔵 BUILT July 25, 2026 (vm-k8-redpanda-1, Phase 14 sandbox)** |

---

## CREDENTIALS

**File:** `/proxmox/credentials`

- Proxmox: root / [See PASSWORDS.md]
- All VMs: agamache / [See PASSWORDS.md]
- **SSH key auth:** ✅ ed25519 key deployed to ALL VMs (.180-.185) from dev workstation (Feb 27, 2026)
- **GitLab Web: root / [See PASSWORDS.md]**
- **SonarQube Web: admin / [See PASSWORDS.md]**
- NAS (SMB): fiberoptix / [See PASSWORDS.md] @ 192.168.1.120

---

## GITLAB

- **URL:** http://192.168.1.181 (or gitlab.gothamtechnologies.com)
- **Registry:** http://gitlab.gothamtechnologies.com:5050
- **Sign-up:** Disabled
- **Email:** Not configured yet (Gmail SMTP pending)

**Registry Note:** Uses HTTP. Docker needs `insecure-registries` config:
```json
{"insecure-registries": ["gitlab.gothamtechnologies.com:5050"]}
```
`setup_docker.sh` now auto-configures this for new VMs.

---

## GITLAB RUNNER

- **VM:** vm-gitrun-1 @ 192.168.1.182
- **Name:** gitlab-runner-1 (ID #2)
- **Executor:** Docker (docker:24.0)
- **Tags:** docker, linux, build
- **Status:** ✅ Online, runs untagged jobs
- **Config:** `/etc/gitlab-runner/config.toml`

**DIND Note:** Docker-in-Docker (services: docker:dind) fails. Standard jobs work fine.
Use docker socket mount for builds: `volumes = ["/var/run/docker.sock:/var/run/docker.sock"]`

**APT signing key (packages.gitlab.com):**
- Keyring: `/etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg`
- Source list: `/etc/apt/sources.list.d/runner_gitlab-runner.list` (uses `signed-by=`)
- Fingerprint: `F6403F65 44A38863 DAA0B6E0 3F01618A 51312F3F`
- **Current expiration: Feb 6, 2028** (rotated May 23, 2026 after the old copy expired Feb 27, 2026)
- Backup of expired key: `/etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg.bak.20260523`

**Refresh procedure (when EXPKEYSIG appears again ~early 2028):**
```bash
sudo cp /etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg{,.bak.$(date +%Y%m%d)}
curl -fsSL https://packages.gitlab.com/runner/gitlab-runner/gpgkey \
  | sudo gpg --batch --yes --dearmor \
             -o /etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg
sudo apt-get update   # should be clean: no EXPKEYSIG
```

---

## SCRIPT SERVER

**URL:** http://192.168.1.195/scripts/  
**Restart:** `cd www && ./run_www.sh`

**Setup new host:** 
```bash
wget http://192.168.1.195/scripts/host_setup.sh
chmod +x host_setup.sh
./host_setup.sh
```

**Or one-liner:**
```bash
wget http://192.168.1.195/scripts/host_setup.sh && chmod +x host_setup.sh && ./host_setup.sh
```

**Note:** The main script automatically downloads all sub-scripts (setup_ssh.sh, setup_docker.sh, etc.) before running them.

**After reboot:** Run `update` from terminal to apply system updates.

---

## VM CONFIGURATION STANDARD

**Last Updated:** January 14, 2026 (4:30 PM EST)  
**Documentation Verified:** All specs match running production configuration  
**ALL NEW VMs MUST USE THESE SETTINGS:**

### Proxmox VM Settings (qm create/set)
```bash
-cpu host                    # Use host CPU type (best performance)
-numa 0                      # NUMA disabled for single-socket
-onboot 1                    # Auto-start on Proxmox boot
-scsihw virtio-scsi-single   # SCSI controller
-net0 virtio=XX:XX:XX:XX:XX:XX,bridge=vmbr0,firewall=1  # Firewall ENABLED

# Disk configuration (CRITICAL - use all these flags):
-scsi0 POOL:vm-XXX-disk-0,iothread=1,discard=on,cache=none,aio=native,size=XXG

# Explanation:
# - iothread=1       : Dedicated I/O thread (better performance)
# - discard=on       : TRIM support for ZFS space reclamation
# - cache=none       : No cache (required for aio=native compatibility)
# - aio=native       : Native Linux AIO (lower CPU overhead)

# ⚠️ IMPORTANT COMPATIBILITY NOTE:
# cache=writeback + aio=native are INCOMPATIBLE!
# - aio=native requires cache.direct=on (direct I/O)
# - cache=writeback uses cache.direct=off (buffered I/O)
# - Use cache=none with aio=native (working configuration)
# - Or use cache=writeback with aio=threads (default, but higher CPU)
```

### Current VMs (Last verified Feb 20, 2026)
| VM | CPU | RAM | Disk | Storage | Config |
|----|-----|-----|------|---------|--------|
| **181 - GitLab** | 8 cores | 24 GB | 500 GB | vm-critical | ✅ Standard |
| **182 - Runner** | 8 cores | 12 GB | 100 GB | vm-ephemeral | ✅ Standard |
| **183 - SonarQube** | 4 cores | 12 GB | 30 GB | vm-critical | ✅ Standard |
| **184 - WWW** | 8 cores | 8 GB | 50 GB | vm-critical | ✅ Standard |
| **185 - OpenClaw** | 8 cores | 16 GB | 50 GB | vm-critical | ✅ Standard |
| **186 - K8s/Redpanda POC** | 16 cores | 32 GB | 300 GB | vm-ephemeral | ✅ Standard (from template 9000) |
| **200 - Kubernetes** | 8 cores | 12 GB | 100 GB | vm-ephemeral | ✅ Standard |
| **9000 - TEMPLATE** | 2 cores | 2 GB | 3.5 GB | vm-ephemeral | 📀 `tmpl-ubuntu-2404-cloudinit` |

### RAM Allocation Strategy
- **GitLab:** 24 GB (memory-hungry, upgraded from 16 GB)
- **SonarQube:** 12 GB (upgraded from 8 GB for large project scans)
- **Runner:** 12 GB (upgraded from 8 GB)
- **Kubernetes/QA:** 12 GB (upgraded from 8 GB)
- **WWW:** 8 GB (Traefik + Capricorn PROD + splash)
- **OpenClaw:** 16 GB (retired/dormant — VM 185 is not running, so this is reserved on paper only)
- **K8s/Redpanda POC (186):** 32 GB (3 Redpanda brokers + OpenSearch are memory-hungry; Phase 14)
- **Total Allocated:** 116 GB of 128 GB (91%) — **but 185 is powered off**, so ~100 GB (78%) is
  actually committed. ⚠️ Headroom is now thin: do not add another large VM without either
  destroying 185 or shrinking 186 when Phase 14 wraps.

---

## CLOUD-INIT TEMPLATE (VM 9000) — how to build any new VM in ~30 seconds

**Created July 25, 2026 (Phase 14, Part 1). This is now the preferred way to build a VM —
do not hand-build from an ISO unless there's a reason.**

`9000 = tmpl-ubuntu-2404-cloudinit`: Ubuntu 24.04 cloud image with `qemu-guest-agent` baked in,
machine-id truncated, cloud-init drive attached. Its disk is `vm-ephemeral/base-9000-disk-0`
(PVE renames a volume to `base-*` when the VM becomes a template).

```bash
# Clone and personalize — that's the whole job
qm clone 9000 <VMID> --name <vm-name> --full --storage <pool>
qm set <VMID> --cores <n> --sockets 1 --memory <MB> --onboot 1
qm resize <VMID> scsi0 <size>G          # cloud-init's growpart expands the fs on first boot
qm set <VMID> --ipconfig0 ip=192.168.1.<VMID>/24,gw=192.168.1.1 --nameserver "8.8.8.8 8.8.4.4"
qm start <VMID>
```

`ciuser` (agamache), `cipassword`, and `sshkeys` are **inherited from the template** — no need to
re-specify. Hostname is taken from `--name`. Standard disk flags are inherited too.

**Rules learned building it:**
- **Key source is `/root/cloudinit-keys-all.pub`** on the host (workstation ED25519 + PVE RSA).
  `/root/.ssh/authorized_keys` → `/etc/pve/priv/authorized_keys` has ONLY the cluster RSA key;
  using it produces a VM the workstation can't SSH into.
- **Don't set `--searchdomain`** — the lab resolves internal names via `/etc/hosts`, so a search
  domain only adds failed lookups.
- `--ciupgrade 0` keeps first boot fast and keeps clones identical. Upgrade deliberately instead.
- Modern PVE imports a disk in one step: `qm set <id> --scsi0 <pool>:0,import-from=<path>,...`.
  The two-step `qm importdisk` recipe in most blog posts is obsolete.
- `virt-customize` needs `export LIBGUESTFS_BACKEND=direct` on this host (no libvirt configured).

**SSH password auth is ENABLED in the template** (July 25). Ubuntu cloud images ship
`/etc/ssh/sshd_config.d/60-cloudimg-settings.conf` with `PasswordAuthentication no`, which made
clones key-only and inconsistent with the rest of the fleet (182/184 allow passwords). Changed to
`yes` inside the template disk so all clones match. Login is `agamache` / fleet password.

**Editing the template's disk in place (no need to un-template):** its zvol is writable at
`/dev/zvol/vm-ephemeral/base-9000-disk-0`, so `virt-customize`/`virt-cat` work directly on it:

```bash
zfs snapshot vm-ephemeral/base-9000-disk-0@pre-change     # cheap insurance, delete after validating
export LIBGUESTFS_BACKEND=direct
virt-customize -a /dev/zvol/vm-ephemeral/base-9000-disk-0 --run-command '<your change>'
virt-customize -a /dev/zvol/vm-ephemeral/base-9000-disk-0 --truncate /etc/machine-id   # ALWAYS LAST
virt-cat -a /dev/zvol/vm-ephemeral/base-9000-disk-0 /etc/machine-id | wc -c            # MUST be 0
```

> ⚠️ **`virt-customize` re-populates `/etc/machine-id` on every single run** (it prints
> "Setting the machine ID"). If you don't re-truncate it afterwards, **every future clone gets
> an identical machine-id** — the exact identity collision the template exists to prevent.
> Always finish with `--truncate /etc/machine-id` and verify it reads 0 bytes.
> The `@__base__` snapshot on the template zvol is PVE's own marker — leave it alone.

**Validating a template change:** clone to a throwaway VMID, boot, test, `qm destroy --purge`.
Takes ~40 seconds and is the only real proof. Done for the password-auth change: fresh clone
accepted password *and* key SSH, guest agent active, machine-id unique.

**Updating the template:** you can't boot a template. Clone it to a scratch VMID, boot,
`apt upgrade`, shut down, re-template, delete the old one. Refresh a couple times a year.

---

## REFRESH SCRIPT (PROXMOX HOST)

**Purpose:** Update + reboot all 5 home-lab VMs in parallel from the Proxmox host.

- **Location:** `/usr/local/bin/refresh.sh` on Proxmox (192.168.1.150)
- **Source in repo:** `proxmox/build-scripts/refresh.sh`
- **Alias:** `refresh` in `/root/.bashrc` on Proxmox
- **Invocation:** SSH to Proxmox as root, then type `refresh`

**tmux detach/reattach-safe (since Jun 18, 2026):**
- `refresh.sh` self-wraps in a tmux session named `refresh`.
- Type `refresh` with no session running → starts the run in tmux.
- Type `refresh` while a run is active → **re-attaches to the same run** (does NOT re-run).
- Survives the Proxmox web console dropping (e.g. switching to a VM VNC console);
  tmux server is reparented to PID 1, so the update+reboot keeps going.
- After completion the pane is held so you can reconnect and read the summary
  (Enter to close, `Ctrl-b d` to detach).
- `tmux 3.5a` is installed on Proxmox. It was installed via `apt-get download` +
  `dpkg -i` (NOT `apt-get install`) because the held kernel
  (`proxmox-default-kernel`/`proxmox-kernel-6.17`) breaks apt's solver for new
  installs on the Proxmox host. Same workaround applies to future host packages
  until the kernel hold is lifted.
- **Test hook:** `REFRESH_SELFTEST=1 refresh` runs the full machinery but the
  per-VM remote command is just `sleep 45` (no apt, no reboot) — safe to test.

**Lesson from Jun 18:** A `refresh` run was killed mid-flight when the Proxmox
web console was switched to a VM VNC console. The 4 fast VMs had already
rebooted, but GitLab (slow Omnibus reconfigure) finished apt but never got to
`init 6`, so it didn't reboot. tmux wrapping prevents this.

**VMs targeted (parallel):** .180, .181, .182, .183, .184
**Excluded:** .185 (vm-openclaw-1) — managed separately

**What it does on each VM:**
1. Records pre-update `/proc/uptime` (baseline for reboot detection)
2. SSHes as `agamache` (key auth, no password)
3. Runs `apt-get update && apt-get upgrade` non-interactively
   (`DEBIAN_FRONTEND=noninteractive`, `--force-confdef`/`--force-confold` to keep existing config files, passwordless sudo)
4. On success (`&&`) runs `sudo init 6` to reboot

**Live status display** (redraws every 30s, with countdown in between):

| State    | Meaning                                                                  |
|----------|--------------------------------------------------------------------------|
| RUNNING  | SSH session active, apt is working                                       |
| SHUTDOWN | SSH ended (init 6 fired) but VM still reachable (mid-shutdown, <180s)    |
| BOOTING  | SSH ended, host unreachable (reboot in progress)                         |
| DONE     | Host back online with fresh uptime (reboot complete)                     |
| FAILED   | SSH ended; host stayed up with unchanged uptime past 180s grace          |

**Per-VM logs:** `/tmp/refresh-<ip>.log` on Proxmox (overwritten each run)

**SSH from Proxmox root to VMs:**
- Dev workstation's `~/.ssh/id_ed25519` keypair was copied to Proxmox `/root/.ssh/` (Option B from May 23, 2026 setup)
- Same key is in `agamache@<vm>:~/.ssh/authorized_keys` on all VMs (deployed Feb 27, 2026)
- `/root/.ssh/known_hosts` pre-populated for .180–.184

**Reboot detection trick:** `init 6` exits SSH with ambiguous exit code (often 0) and the VM stays reachable for ~5-90s before sshd dies. Don't rely on ssh exit code — compare `/proc/uptime` before vs after.

**Created:** May 23, 2026 (this session, see `phases/current_phase.md`)

### Storage Pool Selection
- **vm-critical (mirror):** GitLab, SonarQube, Monitoring (data persistence)
- **vm-ephemeral (stripe):** Runner, QA Host (disposable/rebuildable)

### ZFS Pool Creation (NEW POOLS)
**ALWAYS enable lz4 compression on new pools:**
```bash
# Create pool (mirror or stripe)
zpool create <pool-name> [mirror] /dev/<disk1> /dev/<disk2>
# Enable compression (REQUIRED)
zfs set compression=lz4 <pool-name>
```

### Guest OS Setup
After VM creation, run setup script:
```bash
wget http://192.168.1.195/scripts/host_setup.sh
bash host_setup.sh
```
Installs: Docker, SSH keys, passwordless sudo, NAS mount, insecure-registry config, sysbench

---

## PROXMOX KERNEL MANAGEMENT

**Current Status:** June 18, 2026 — on 6.17.13-13-pve, PVE 9.2.3, holds removed

### Active Kernel
- **Running + permanently pinned:** **7.0.14-4-pve** ✅ (tested Jul 9, 2026 via --next-boot
  during the SNC BIOS change window, then pinned permanent — 0 NVMe timeouts, all 6 NVMe
  behind VMD, ZFS healthy). Prior good: 7.0.6-2-pve (Jun 18 → Jul 9).
- **Fallbacks on ESPs (verified Jul 9, 2026):** 6.17.13-x and 7.0.x lines only — 6.17.2-1 is
  NO LONGER boot-selectable. To revert, `proxmox-boot-tool kernel pin 6.17.13-13-pve` +
  `proxmox-boot-tool refresh` (console access advised).
- **History on this box:** 6.17.4-2 hung (Jan); ran 6.17.2-1 pinned; Jun 18 → 6.17.13-13
  → 7.0.6-2; Jul 9 → 7.0.14-4 (current). All 6.17.9+ / 7.0 kernels are NVMe-clean here.
- **Holds:** NONE ✅ — `proxmox-default-kernel` + `proxmox-kernel-6.17.2-1-pve-signed`
  unheld Jun 18. `apt install` is normal again (dpkg-download workaround no longer needed).
- **Root cause of the recurring solver error** (`proxmox-default-kernel : Depends:
  proxmox-kernel-6.17`, which had blocked tmux + the first full-upgrade attempt): the
  `proxmox-kernel-6.17` **metapackage was not installed**. Installing it (`apt-get
  install proxmox-kernel-6.17`, deps already satisfied) fixed it permanently.
- **History:** 6.17.4-2 hung the box (Jan 12); ran pinned on 6.17.2-1 until Jun 18.
  See `phases/phase1a_*` (failure) and `phases/phase1b_*` (this upgrade + results).

### Status
- systemd 257.13 / libc / QEMU 11 now fully active (host rebooted Jun 18). VMs were
  stopped+started during the kernel test, so they now run on the new QEMU 11 binary too.

### ⚠️ KNOWN ISSUE: Kernel 6.17.4-2-pve
**Problem:** NVMe timeout errors on all disks during boot (HP Z6 G4 + Intel VMD; 6.17 NVMe regression).
**Full incident + rollback write-up:** `phases/phase1a_proxmox_upgrade_fail_rollback.md`
**Safe retry plan (to 6.17.13-13):** `phases/phase1b_proxmox_kernel_upgrade_safe_try.md`

Short version: Jan 12, 2026 the `update` script bumped `6.17.2-1 → 6.17.4-2`; reboot
hung with NVMe timeouts on all drives. Recovered via GRUB → old kernel, then pinned
`6.17.2-1-pve` and held `proxmox-kernel-6.17.2-1-pve-signed` + `proxmox-default-kernel`,
purged the bad kernel.

**Current Protection (as of Jun 18, 2026):**
```bash
# Pinned kernel (always boots this one):
proxmox-boot-tool kernel list
# Shows: Pinned kernel: 7.0.14-4-pve
#   (7.0.6-2-pve and 6.17.13-x-pve also installed as fallbacks)

# Holds: NONE — removed Jun 18, 2026. apt install works normally again.
apt-mark showhold   # (empty)
```

**Update Script:**
- `/usr/local/bin/proxmox-update.sh` created with alias `update`
- Automatically disables subscription nag after each update
- Checks for reboot required
- The **pin** (not holds) is now what controls which kernel boots. A routine
  `apt upgrade` may install newer kernels, but they will NOT boot until explicitly
  `proxmox-boot-tool kernel pin`-ed and tested with console access.

**KERNEL POLICY (post Jun 18, 2026):** Holds are removed; rely on the **boot pin**
instead. The pin is on `7.0.14-4-pve`. Before adopting any future newer kernel, use the
reversible `--next-boot` procedure in
`phases/phase1b_proxmox_kernel_upgrade_safe_try.md` **with physical/console access**,
verify NVMe + ZFS, then make the pin permanent (this is exactly how 6.17.13-13, 7.0.6-2
and 7.0.14-4 were validated).

---

## HOST EMAIL ALERTING (Phase 13, Jul 9 2026) — see phase13 for full detail

All Proxmox-host alerts now reach Andrew's Gmail via app password (PASSWORDS.md "Gmail SMTP Relay"):
- **PVE notifications** (vzdump results, PVE alerts): endpoint `gmail-smtp`
  (smtp.gmail.com:587 STARTTLS) + builtin `default-matcher` retargeted to it.
  Manage: `pvesh get/set /cluster/notifications/...`. Test:
  `pvesh create /cluster/notifications/targets/gmail-smtp/test`
- **Local root mail** (ZED pool events, smartd disk warnings, cron): postfix
  `relayhost = [smtp.gmail.com]:587` + SASL (`/etc/postfix/sasl_passwd`, root-only) +
  `/etc/aliases` root→gmail. `smtp_address_preference = ipv4` (host has no IPv6 route).
  Test: `echo hi | mail -s test root` then check journal for `status=sent ... gsmtp`.
- Rotate credential at Google → Security → App passwords (named "pve").

---

## STORAGE

**Last Verified:** January 14, 2026 (4:35 PM EST)

| Pool | Drives | Type | Size | Usage | Compression | Ratio | Use |
|------|--------|------|------|-------|-------------|-------|-----|
| rpool | 2x WD Blue SN5100 500GB | mirror | 460GB | 11GB (2%) | lz4 ✅ | 1.17x | Proxmox, ISOs |
| vm-critical | 2x Lexar NM620 1TB | mirror | 952GB | 66GB (6%) | lz4 ✅ | 1.40x | GitLab, Sonar, WWW, (OpenClaw) |
| vm-ephemeral | 2x Lexar NM620 1TB | stripe | 1.86TB | 46GB (2%) | lz4 ✅ | ~1.5x | Runner, QA |

**ashift (verified/fixed Jul 9, 2026):** ALL pools now ashift=12 (vm-ephemeral was 9 —
rebuilt Jul 9; NM620s only expose 512B LBA so ashift must be set at pool creation).
ARC cap = **16 GiB** (`/etc/modprobe.d/zfs.conf`, raised from 8 Jul 9).
All pools feature-flag current (zpool upgrade Jul 9).

**Note:** All pools now have lz4 compression enabled. rpool shows 1.00x ratio because existing data is uncompressed (new data will be compressed).

**Drive Serial Numbers:** See `/SYSTEM_VERIFICATION.md` for complete inventory.

---

## PHASES

| # | Name | Status |
|---|------|--------|
| 0-2 | Hardware/Proxmox/Automation | ✅ |
| 12 | Network perimeter lockdown (.184 DMZ) | ✅ IMPLEMENTED July 8, 2026 (see phase12 + current_phase.md) |
| 13 | Proxmox host audit + fixes (Fable) | ✅ AUDIT + quick wins DONE July 9, 2026 (see phase13; maintenance-window items open) |
| 1a | Proxmox kernel upgrade failure + rollback (Jan 12) | ✅ RESOLVED (pinned/held) |
| 1b | Proxmox kernel upgrade — safe retry (→6.17.13-13) | ✅ COMPLETE (Jun 18, 2026, running+pinned) |
| 3 | GitLab Server | ✅ VERIFIED |
| 4 | GitLab Runner | ✅ VERIFIED |
| 5 | CI/CD Pipelines | ✅ COMPLETE (QA + GCP both working!) |
| 6 | SonarQube | ✅ COMPLETE (test-app + Capricorn both integrated!) |
| 7 | Local WWW Server | ✅ COMPLETE (vm-www-1 @ .184, cap + www live!) |
| 8 | Monitoring Stack | 🔲 Planned (build it from template 9000) |
| 14 | Kubernetes + Redpanda + OpenSearch POC (interview prep) | 🔵 IN PROGRESS — Parts 1-2 done Jul 25, 2026 (template 9000 + VM 186); Part 3 k3s next |
| 11 | OpenClaw AI Agent | ✅ COMPLETE (vm-openclaw-1 @ .185, Feb 20, 2026) |

**Phase docs:** `/phases/`

---

## SONARQUBE

- **URL:** http://192.168.1.183:9000
- **Version:** 26.1.0 (community, latest)
- **Login:** admin / [See PASSWORDS.md]
- **Container:** `sonarqube:community` (Docker)
- **Data:** `/opt/sonarqube/data` (persisted)

**Projects:**
- test-app (token: [See PASSWORDS.md])
  - Quality Gate: PASSED ✅
  - 86 lines of code (HTML, Docker)
  - 0 security issues, 0 bugs, 1 maintainability issue
- capricorn (token: [See PASSWORDS.md])
  - Quality Gate: PASSED ✅
  - 28k lines of code (TypeScript, Python)
  - 5 security issues, 144 reliability issues, 490 maintainability issues

**Note:** Upgraded from 9.9.8 → 26.1.0 (required fresh database)

**Pipeline Integration:** Scan stage runs after build/push, before deploy (allow_failure: true)

---

## WWW SERVER (LOCAL PRODUCTION)

- **VM:** vm-www-1 @ 192.168.1.184
- **RAM:** 8 GB | **CPU:** 8 cores | **Disk:** 50 GB (vm-critical)
- **OS:** Ubuntu 24.04 Desktop
- **URLs:** 
  - https://cap.gothamtechnologies.com (Capricorn PROD)
  - https://www.gothamtechnologies.com (Splash page)
  - https://192.168.1.184 (Direct IP access from internal network)
- **Reverse Proxy:** Traefik v3 (ports 80/443/8080)
- **SSL:** Let's Encrypt (HTTP-01 challenge, auto-renewal)
- **DDNS:** bullpup.ddns.net (Verizon G3100 router-managed)
- **DNS:** AWS Route53 CNAMEs → bullpup.ddns.net

### Docker Network Architecture

**Key Learning:** Traefik must be on BOTH networks to route traffic correctly!

```
web (172.18.0.0/16) - Public-facing network
├── traefik (172.18.0.5)
├── splash (172.18.0.2)
├── capricorn-frontend (172.18.0.4)
└── capricorn-backend (172.18.0.3)

capricorn_capricorn-network (172.19.0.0/16) - Internal application network
├── traefik (172.19.0.6) ← MUST be here to reach backend services!
├── capricorn-frontend (172.19.0.5)
├── capricorn-backend (172.19.0.4)
├── postgres (172.19.0.3) ← NOT on web network (security)
└── redis (172.19.0.2) ← NOT on web network (security)
```

**Why two networks:**
- `web` network: Public-facing services (Traefik, frontend, splash)
- `capricorn_capricorn-network`: Application services + database isolation
- Traefik bridges both networks to route traffic
- Databases stay isolated from public network (security best practice)

### Traefik Configuration

**Location:** `/opt/traefik/`

**docker-compose.yml:**
```yaml
services:
  traefik:
    image: traefik:latest
    networks:
      - web
      - capricorn_capricorn-network  # ← CRITICAL: Must join both networks!
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"  # API/dashboard for debugging
```

**traefik.yml:**
- DEBUG logging enabled (helpful for troubleshooting)
- HTTP-01 challenge for Let's Encrypt
- Auto HTTP→HTTPS redirect
- Docker provider with `exposedByDefault: false`

### Capricorn PROD Deployment

**Location:** `/opt/capricorn/`

**Key Features:**
- Images pulled from GitLab Container Registry
- Traefik labels for routing (both hostname and IP)
- Database initialization via mounted SQL scripts
- Persistent volumes for postgres + redis

**Routing:**
- `cap.gothamtechnologies.com` → frontend + backend (/api)
- `192.168.1.184` → frontend + backend (/api) - for internal access

### Security - Proxmox Firewall

**vm-www-1 Firewall Rules:**
- ✅ IN: SSH (22) from 192.168.1.0/24 ONLY
- ✅ IN: HTTP (80) from anywhere
- ✅ IN: HTTPS (443) from anywhere
- ✅ OUT: Allow all (for apt, docker pulls, Let's Encrypt)
- ❌ NO SSH from internet (blocked by source IP filter)

**Router Port Forwarding (Verizon G3100):**
- 80 → 192.168.1.184:80
- 443 → 192.168.1.184:443
- NO port 22 forwarding (SSH internal only)

### Troubleshooting Notes (Jan 22, 2026)

**Problem 1:** HTTPS timeout, but HTTP worked (redirected to HTTPS)

**Root Cause:** Traefik and Capricorn containers on different networks
- Traefik on `web` network (172.18.0.x)
- Capricorn on `capricorn_capricorn-network` (172.19.0.x)
- Traefik logs showed wrong IPs (172.19.0.5 instead of actual container IPs)

**Solution:**
1. Connected Traefik to capricorn network: `docker network connect capricorn_capricorn-network traefik`
2. Updated `/opt/traefik/docker-compose.yml` to include both networks permanently
3. Containers restarted successfully, traffic flowing

**Lesson:** Multi-service applications with their own networks require reverse proxy to join ALL networks!

---

**Problem 2:** Localhost access not working on vm-www-1 itself (10:00 PM)

**Root Cause:** 
- Traefik routing rules only configured for `cap.gothamtechnologies.com` and `192.168.1.184`
- No routing rule for `localhost` hostname
- `/etc/hosts` didn't have domain name entries for local resolution

**Solution:**
1. Added `/etc/hosts` entries for local domain resolution:
   ```
   127.0.0.1 cap.gothamtechnologies.com
   127.0.0.1 www.gothamtechnologies.com
   ```
2. Updated `/opt/capricorn/docker-compose.yml` with localhost routing:
   - Frontend: Added `traefik.http.routers.capricorn-localhost.rule=Host(\`localhost\`)`
   - Backend: Added `traefik.http.routers.capricorn-api-localhost.rule=Host(\`localhost\`) && PathPrefix(\`/api\`)`
3. Restarted containers: `cd /opt/capricorn && sudo docker compose up -d`

**Result:** Now accessible three ways from vm-www-1:
- ✅ https://localhost (self-signed cert, works)
- ✅ https://192.168.1.184 (self-signed cert, works)
- ✅ https://cap.gothamtechnologies.com (Let's Encrypt cert, trusted)

**Lesson:** Always configure localhost routing for services running on the same machine as the reverse proxy!

### GitLab CI/CD Integration

**Pipeline Stages:** build → push → scan → deploy_qa → deploy_prod

**New Deployment Jobs (production branch):**
- `deploy_prod_local` (manual) → vm-www-1 @ 192.168.1.184
- `deploy_prod_gcp` (manual) → Google Cloud Platform (for interviews)

**Deployment Method:**
- SSH to vm-www-1
- Pull latest images from GitLab registry
- `docker compose up -d` in `/opt/capricorn/`

### Cost Savings

- **Before:** GCP hosting ~$30-45/month (~$400/year)
- **After:** Local hosting ~$2-3/month electricity
- **Savings:** ~$400/year 💰

---

## OPENCLAW

- **VM:** vm-openclaw-1 @ 192.168.1.185 (16GB RAM, 8 cores, 50GB vm-critical)
- **OS:** Ubuntu 24.04 Desktop
- **Version:** 2026.4.5 (updated Apr 6, 2026; prior: 3.13 → 3.22 → 3.23-beta.1 → 3.28 → 4.5)
- **Install Method:** Bash script (`curl -fsSL https://openclaw.ai/install.sh | bash`)
- **Gateway Port:** 1885 (non-default to avoid scanner detection; default is 18789)
- **Gateway Bind:** LAN (0.0.0.0)
- **Gateway Auth:** Token [See working/open-claw-keys.txt]
- **AI Model:** OpenRouter / Anthropic Claude Sonnet 4.6
- **Status:** ✅ LIVE

**Access:**
- **Control UI (HTTPS):** https://vm-openclaw-1.tail8f8df.ts.net/ (via Tailscale Serve)
- **Control UI (localhost):** http://localhost:1885 (from VM only)
- **Telegram Bot:** @OC_GothamBot (DM policy: pairing required)
- **SSH:** ssh agamache@192.168.1.185 (from LAN only)

**Tailscale:**
- **Tailscale IP:** 100.119.212.71
- **Tailscale Serve:** HTTPS proxy on port 443 → localhost:1885
- ~~This is the ONLY VM with Tailscale in the lab~~ **CORRECTION (Jul 9, 2026): the Proxmox
  HOST also runs Tailscale** (tailscaled active on pve, 100.108.209.77). .185 remains the only *VM* with it.

**CRITICAL: Control UI requires HTTPS or localhost!**
- Plain HTTP to LAN IP (http://192.168.1.185:1885) will NOT work -- OpenClaw blocks it
- Must use Tailscale Serve (HTTPS) or access from VM itself (localhost)
- Tailscale Serve provides auto-managed TLS certs via the tailnet domain

**CRITICAL: allowedOrigins required since v2026.2.23!**
- Non-loopback bind (`gateway.bind: "lan"`) now requires `gateway.controlUi.allowedOrigins`
- Without it, the gateway refuses to start (crash loop, exit 1)
- Current config has: `["https://vm-openclaw-1.tail8f8df.ts.net", "http://localhost:1885", "http://127.0.0.1:1885"]`
- If updating OpenClaw in the future, check release notes for similar breaking security changes

**Services (all auto-start on boot):**
- `openclaw-gateway.service` (systemd user service, enabled, lingering)
- `tailscaled.service` (systemd service, enabled)
- Tailscale Serve (persistent via --bg flag)

**Config:** `~/.openclaw/openclaw.json` on vm-openclaw-1 (permissions: 600)
**Config backups on VM:**
- `~/.openclaw/openclaw.json.bak` (auto-created by doctor)
- `~/.openclaw/openclaw.json.bak.pre-fix` (pre-v2026.2.23 fix)
- `~/.openclaw/openclaw.json.bak.pre-v3.28-fix` (pre-v3.28 fix, Apr 6 2026)
- `~/.openclaw/openclaw.json.bak.pre-v4.5-fix` (pre-v4.5 fix, Apr 6 2026)
- `~/.openclaw/openclaw.json.bak.pre-elevenlabs-fix` (pre-ElevenLabs fix, Apr 6 2026)

**TTS (ElevenLabs) — v4.5 config location:**
- Provider credentials go in `messages.tts.providers.elevenlabs` (NOT `plugins.entries` or top-level `messages.tts`)
- Valid keys: `apiKey`, `voiceId`, `modelId`, `baseUrl`, `seed`, `applyTextNormalization`, `languageCode`
**Logs:** `/tmp/openclaw/openclaw-YYYY-MM-DD.log`
**npm global bin:** `/home/agamache/.npm-global/bin` (added to PATH in .bashrc)

**Installed Skills:** github, himalaya (email), nano-pdf, summarize, blogwatcher, goplaces
**Google Places API Key:** configured in openclaw.json

**Proxmox Firewall (VM 185):**
- IN: SSH (22/tcp) from 192.168.1.0/24
- IN: OpenClaw Control UI (1885/tcp) from 192.168.1.0/24
- IN: Tailscale (41641/udp) from anywhere
- OUT: Allow all
- Default IN policy: DROP

**CLI Commands (must use localhost due to HTTPS enforcement):**
```bash
export PATH=/home/agamache/.npm-global/bin:$PATH
openclaw devices list --url ws://127.0.0.1:1885 --token [See working/open-claw-keys.txt]
openclaw devices approve <requestId> --url ws://127.0.0.1:1885 --token [See working/open-claw-keys.txt]
openclaw gateway status
openclaw gateway restart
openclaw doctor --non-interactive
openclaw status --all
sudo tailscale serve --bg 1885
```

**Update procedure (safe):**
```bash
# 1. Back up config FIRST
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak.pre-update

# 2. Update (pick one)
curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard
# Or: npm update
npm i -g openclaw@latest

# 3. Try doctor first (may not fix everything)
openclaw doctor --fix --non-interactive

# 4. Check if gateway started
openclaw gateway status

# 5. If still crash-looping, check the error and fix config manually:
journalctl --user -u openclaw-gateway.service -n 20 --no-pager
# Then edit ~/.openclaw/openclaw.json to remove offending keys
# Then: openclaw gateway restart

# 6. Final verification
openclaw status --all
```

**Rollback (if update breaks things):**
```bash
npm i -g openclaw@<version>   # e.g. openclaw@2026.2.19-2
openclaw doctor
openclaw gateway restart
```

**Reference:** Ansible playbook at `working/openclaw-ansible/` (not used, kept for reference)
**Phase Plan:** `phases/phase11_openclaw.md`

**SSH:** Key auth from dev workstation ✅ FIXED (Feb 27, 2026 — `ssh-copy-id` via sshpass, same as all other VMs)

**SSHFS Mount (Dev Workstation → OpenClaw):**
- **Mount point:** `/home/agamache/mnt/openclaw` (mounts remote `/home/agamache`)
- **Symlink:** `~/openclaw` → `/home/agamache/mnt/openclaw`
- **Service:** `~/.config/systemd/user/sshfs-openclaw.service` — **DISABLED Jul 25, 2026**
  (VM 185 retired; it was failing + retrying every 100s forever and was the only journal noise
  on the workstation). Unit file left in place — `systemctl --user enable --now sshfs-openclaw`
  to revive if OpenClaw ever comes back.
- **Persistence:** Survives reboot (systemd user service + linger enabled)
- **Options:** reconnect, ServerAliveInterval=15, ServerAliveCountMax=3
- **Manage:** `systemctl --user {status|start|stop|restart} sshfs-openclaw`
- **Why user service not fstab:** fstab mounts run as root (wrong SSH keys); user service runs as agamache

**⚠️ KNOWN BUG: Skip v2026.3.22!**
- npm package is missing `dist/control-ui/` directory (packaging bug)
- Control UI shows "assets not found" error
- v3.13 and v3.23+ both have the UI assets; v3.22 does not
- Verify before upgrading: `npm pack openclaw@<version> --dry-run | grep control-ui/`

**⚠️ POST-UPGRADE: Always run doctor, then verify manually!**
- v2026.3.28: Changed TTS config schema, renamed `streamMode` → `streaming`
- v2026.4.5: Tightened plugin entries (only `enabled`/`hooks` allowed); moved TTS creds to `messages.tts.providers.<name>`
- Doctor FAILED to auto-fix plugin config issues in v4.5
- Gateway crash-loops if config has unrecognized keys
- **After ANY upgrade:** back up config, run `openclaw doctor --fix --non-interactive`, then `openclaw gateway status`
- **If doctor fails:** check `journalctl --user -u openclaw-gateway.service -n 20`, inspect config, remove offending keys
- **Schema discovery:** `openclaw config schema | python3 -c "import sys,json; ..."` to find where keys moved

**Manual TODOs:**
- [x] Configure OpenRouter API key/credits (done, working as of Mar 2026)
- [ ] Test Telegram bot from iPhone

---

## GITHUB

- **Repo:** https://github.com/fiberoptix/home-lab-setup
- **User:** fiberoptix (SSH: ~/.ssh/id_ed25519)
- **Email:** andrew.gamache@gmail.com
- **Credentials:** See `github_credentials.md` (git-ignored)

---

## HOME-LAB-SETUP REPO (this repo) — dual-remote (Capricorn method, NO encryption)

Same model as Capricorn/capricorn-docs: SAFE content → GitHub, EVERYTHING → GitLab.
There is NO git-crypt and NO encryption — safety on GitHub comes purely from .gitignore.

- **GitHub (PUBLIC):** https://github.com/fiberoptix/home-lab-setup — remote `origin` (SSH, id_ed25519).
  Curated showcase. Secrets are .gitignore'd and NEVER reach GitHub. Push with: `git push origin main`.
- **GitLab (PRIVATE):** http://gitlab.gothamtechnologies.com/production/home-lab-setup — remote `gitlab`.
  Full plaintext mirror of the ENTIRE working tree (incl. ignored secrets/binaries).
  Auth = HTTP "wallet" baked into the remote URL in .git/config
  (`http://root:<GitLab root pw — see PASSWORDS.md>@gitlab.gothamtechnologies.com/production/home-lab-setup.git`),
  identical to how Capricorn/capricorn-docs authenticate. No SSH key needed for GitLab.
  The real password lives ONLY in .git/config (never pushed) + PASSWORDS.md (gitignored).
- **Push EVERYTHING to GitLab with `./gl-backup.sh "message"`** — it snapshots the whole working
  tree (tracked + ignored, minus .DS_Store) onto `gitlab/main` via a temp index, WITHOUT touching
  the working tree or the GitHub-bound `main`. Do NOT `git push gitlab main` directly (that only
  sends the curated tree, not the secrets). Always use gl-backup.sh for the full private mirror.
- **No auto-push-to-both.** Pushes are explicit; ALWAYS ASK "GitHub, GitLab, or both?" first.
  See the "GIT REMOTES & COMMIT ROUTING" section in CURSOR_RULES.
- **Ignored-and-therefore-GitHub-safe:** PASSWORDS.md, github_credentials.md, proxmox/credentials,
  proxmox/nas_credentials, /working/, /ddns/, *.pem, *.key, *.crt, .env*,
  www/scripts/smb_credentials  (verify: `git check-ignore <f>`).
- **smb_credentials:** `www/scripts/smb_credentials` holds `SMB_PASSWORD='...'`; gitignored (GitHub
  never sees it) but rides the GitLab mirror, so a LAN clone lets setup_smb_mount.sh run unattended.
- **Secret hygiene:** NEVER put real passwords/tokens in tracked files (they go public on GitHub).
  History was purged once already (git filter-repo) after a leak — keep it clean.
- **Branch:** `main` only (docs/scripts repo — no CI/CD or registry like Capricorn).

---

## VM BACKUPS → NAS (Phase 8, June 18 2026) — see phases/phase8_backups.md

- **Why:** GitLab (VM 181) holds private-only data (home-lab-setup full mirror, capricorn-docs,
  registry). ZFS mirror ≠ backup. Whole-VM vzdump → NAS = bare-metal DR.
- **Layout:** NAS NeoCortex (192.168.1.120, SMB only) → share `NeoCortex` →
  `ProxmoxBackups/<hostname>/dump/...`. Per-host subfolder; `dump/` is Proxmox-fixed.
  GitLab → `ProxmoxBackups/vm-gitlab-1/`.
- **Storage:** one CIFS storage **per host** (a storage = one `dump/`). GitLab = **`nas-gitlab`**
  (subdir `/ProxmoxBackups/vm-gitlab-1`, content=backup). Pw root-only at
  `/etc/pve/priv/storage/nas-gitlab.pw`.
- **Job:** `gitlab-nightly` in /etc/pve/jobs.cfg — VM **181**, storage **nas-gitlab**, **02:00 EDT**
  daily, **snapshot** (no downtime), **zstd**, **keep-last=7**. Seed verified (15.3 GB, ~6 min).
- **Add another server:** mkdir `ProxmoxBackups/<host>` → `pvesm add cifs nas-<host> ... --subdir
  /ProxmoxBackups/<host> --content backup` → `pvesh create /cluster/backup --id <host>-nightly
  --storage nas-<host> --vmid <id> ...` (stagger schedules). See phase8_backups.md.
- **Consistency:** app-consistent since Jul 9, 2026 — qemu-guest-agent installed + enabled on
  all live VMs, so vzdump snapshot mode uses fs-freeze/thaw. (Was crash-consistent before.)
- **Restore:** GUI Storage→nas-gitlab→Backups→Restore, or
  `qmrestore /mnt/pve/nas-gitlab/dump/<file>.vma.zst <vmid> --storage <tgt>`. Needs a `vmbr0`.
- **TODO:** one-time proof-of-life test restore (VMID 999, isolated NIC); optionally add jobs for
  VMs 182/183/184/200; offsite/second copy (NAS is a single point).

---

## CAPRICORN PROJECT

- **GitLab:** http://gitlab.gothamtechnologies.com/production/capricorn
- **GitHub:** https://github.com/fiberoptix/capricorn
- **Remotes:** Dual-remote setup (origin=GitHub, gitlab=GitLab)
- **Branches:** develop (QA auto-deploy), production (Local PROD + GCP manual deploy)
- **Production (Local):** https://cap.gothamtechnologies.com (Phase 7 - in progress)
- **Production (GCP):** http://capricorn.gothamtechnologies.com (for interviews)
- **QA (CI/CD):** http://192.168.1.180:5001 ✅ PIPELINE DEPLOYED
- **Local Path:** /home/agamache/DevShare/cursor-projects/unified_ui_DEV_PROD_GCP/capricorn

**Note:** Standard project path is now `unified_ui_DEV_PROD_GCP` (no date suffix)

---

## PASSWORD MANAGEMENT

**PASSWORDS.md** - Central credential storage (git-ignored)
- Contains ALL system passwords and credentials
- All documentation references: [See PASSWORDS.md] (NEVER write real passwords in tracked files)
- Current + deprecated passwords are recorded ONLY in PASSWORDS.md
- Also stored in: `/proxmox/credentials` and `/proxmox/nas_credentials` (git-ignored)

---

## FILES TO READ

1. `PASSWORDS.md` - All credentials
2. `SYSTEM_VERIFICATION.md` - Complete hardware inventory, drive serials, VM configs (Jan 14, 2026)
3. `/phases/current_phase.md` - Current work status
4. `/phases/phase0_hardware.md` - Hardware specs and BIOS settings
5. `/phases/phase1_proxmox.md` - ZFS configuration and best practices
   - `/phases/phase1a_proxmox_upgrade_fail_rollback.md` - Jan 12 kernel failure + rollback
   - `/phases/phase1b_proxmox_kernel_upgrade_safe_try.md` - planned reversible kernel upgrade
6. `/phases/phase5_ci_cd_pipelines.md` ✅ COMPLETE
7. `/phases/phase6_sonarqube.md` ✅ COMPLETE
8. `/phases/phase11_openclaw.md` ✅ COMPLETE
