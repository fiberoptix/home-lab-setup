# IP/host inventory prose: ARP check, node addressing, household devices

Topic reference (not tied to one phase). Loaded ON TOUCH via `phases/INDEX.md`. Blocks below are copied VERBATIM from `MEMORY.md` as of tag `pre-memory-diet` (Nov 24, 2026).

---

## COPIED VERBATIM FROM `MEMORY.md` @ `pre-memory-diet` (lines 1107–1198) — Nov 24, 2026 (memory-diet, copy-first) — IPs & HOSTS prose: ARP check, K8s nodes, household devices, Aug 24 verification


---

## IPs & HOSTS

| Host | IP | Status |
|------|-----|--------|
| Proxmox | .150 | ✅ Running — `ssh root@192.168.1.150`, key auth ✅ (via `authorized_keys2`, Aug 12 2026). 🚨 **THE HOST DOES NOT ANSWER PING** (measured Sep 16, 2026: 5/5 packets lost while SSH answered normally and uptime read 20 days). Normal for PVE with the datacenter firewall enabled — its default host rules permit management ports, not ICMP. ⛔ **So `ping .150` failing is NOT evidence the host is down** — it cost a few minutes once; use `ssh` or `nc -z .150 8006` |
| **QA** | **.180** | ✅ LIVE — **VMID 180, hostname `vm-docker-qa-1`** as of Aug 20, 2026. **Capricorn QA server** (`:5001` frontend, `:5002` backend, auto-deploy on `develop` push), plain `docker compose` — NOT Swarm. ⛔ **No Kubernetes here.** *(🔻 Until Oct 27, 2026 this said "the only Kubernetes in this lab is k3s on VM 186" — false since Sep 17: there are three clusters, k3s `.186` (frozen), kubeadm CKA `.201`–`.205`, and K3s+Rancher `.187`.)* The old misnamed `vm-kubernetes-1` (VMID 200) was cloned to this one and was **DESTROYED Sep 16, 2026** (`--purge`, no backup, rollback window closed Sept 3). ⚠️ **Any note reading "VM 200 = `.180`" predates Aug 20, 2026 and now describes nothing at all** — VMID 200 is free |
| GitLab | .181 | ✅ LIVE |
| Runner | .182 | ✅ LIVE — **VM name is `vm-gitrun-1`**, not `gitlab-runner-1`. ⚠️ `gitlab-runner-1` is the **GitLab runner registration name**, which is a different thing and was listed here as the hostname until Aug 24, 2026. `qm` and `ssh` need `vm-gitrun-1` |
| SonarQube | .183 | ✅ LIVE (vm-sonarqube-1, v26.1.0) |
| **WWW** | **.184** | **✅ LIVE (vm-www-1, Traefik, Capricorn PROD, Splash)** — 🚫 **PROD-LOCAL: no NAS mount, no `/mnt/DevShare`, no `.smbcredentials`** (removed Aug 20, 2026; Phase 12 DMZ blocks the LAN). Rebuild it with **`host_setup.sh --no-nas`** |
| **~~OpenClaw~~ → Jenkins** | **.185** | ⛔ **OpenClaw DESTROYED Aug 19, 2026 (totally gone).** VMID 185 + `.185` reassigned to `vm-jenkins-1` — Phase 17 |
| **K8s/Redpanda POC** | **.186** | **🔵 BUILT July 25, 2026 (vm-k8-redpanda-1, Phase 14 sandbox) — `ssh agamache@192.168.1.186`, key auth ✅.** 🖥️ **Cockpit web UI at `https://192.168.1.186:9090/`** (added Aug 20, 2026) — log in with the `agamache` fleet password, self-signed cert so click through the warning. ⚠️ **`onboot 0` — CONFIRMED still 0 on Aug 24, 2026, but it was RUNNING when measured.** `onboot 0` means it will not come back after a host reboot; it does **not** mean it is off now. Check, do not assume |
| **Rancher / K3s** | **.187** | 🔵 **BUILT Oct 27, 2026 — VMID 187 `vm-k3s-rancher-1`, Phase 20.** `ssh agamache@192.168.1.187` (key auth), Rancher UI `https://rancher.gothamtechnologies.com`, demo app `http://hello-rancher.gothamtechnologies.com/`, Cockpit `:9090`. 6 vCPU / 24 GB / 120 G on `vm-ephemeral`, **onboot 1, startup order=4**. Auto-updates masked; patched by `refresh.sh`. Operate the cluster ON the VM (`sudo kubectl`, `sudo -E helm` with `KUBECONFIG=/etc/rancher/k3s/k3s.yaml`) |
| **SWARM** | **.191 .192 .193** | ✅ **`docker-swarm-1/2/3` — VMIDs 191/192/193, all three RUNNING and `Ready/Active` (measured Aug 24, 2026 via `docker node ls` on `.191`).** `docker-swarm-1` is **Leader**, the other two `Reachable`; engine **29.7.2**. 2 vCPU / 4 GB / 40 GB on **`vm-ephemeral`** each. ⚠️ **All three are `onboot 0`** — a host reboot leaves the whole Swarm down, and `vm-ephemeral` is the pool that gets rebuilt, so treat this cluster as **disposable by design**. 🚨 **Phase 17 Part 4 deploys HERE**, as stack **`capricorn-jenkins`** — ⛔ never `capricorn`, which is the Phase 16 GitLab-CI stack kept alive as the comparison. Full detail: `phases/phase16_docker_swarm.md` |
| Dev box / script server | **.195** | ✅ **THIS machine** — where the AI runs, the repo lives (on **CIFS**, see the gotcha below), and the **host-setup script server** is served from (`cd www && ./run_www.sh`, landing page at `http://192.168.1.195/`). ⚠️ **Not a Proxmox VM**, so it never appears in `qm list` — which is why a session looking for `.195` there concludes it is remote and unreachable. It is not |
⭐ **HOW TO CHECK WHETHER A LAB ADDRESS IS FREE — use ARP, not ping** (learned Sep 16, 2026). A host can be
**alive and silent to ICMP** (`.150` is exactly that), so a ping sweep reporting "free" may simply mean
"present but dropping pings". On a local subnet **ARP cannot be declined** by the host's IP firewall, so it
is the honest instrument:
```bash
sudo ip neigh del <ip> dev <iface>; ping -c1 -W1 <ip} >/dev/null 2>&1; ip neigh show <ip> dev <iface>
# a lladdr in the output = OCCUPIED, even if the ping failed;  no lladdr = genuinely free
```
✅ **Validated with a positive control before being trusted:** `.150` reports OCCUPIED by ARP while failing
5/5 pings. ⭐ **A sweep that cannot distinguish "absent" from "quiet" is not a measurement.**

✅ **BUILT Sep 16, 2026 — the Phase 18 Kubernetes nodes are LIVE:** `vm-k8s-cka-control-1/2/3` at
**`.201`/`.202`/`.203`** and `vm-k8s-cka-worker-1/2` at **`.204`/`.205`** (VMIDs match the last octet),
2 vCPU / 4 GB / 40 GB each on **`vm-critical`** (moved from `vm-ephemeral` Sep 28, Phase 19), all **`onboot 0`** — so **a host reboot leaves this cluster
down**, exactly like the Swarm. ⏳ **`.206` is RESERVED for the kube-vip VIP and has NO VM behind it** — do
not allocate it, and do not hunt for it in `qm list`.
⚠️ **State: Kubernetes PACKAGES installed and INERT** (v1.35.8, apt-held; containerd 2.3.5 with CRI
enabled; `crictl` 1.35.0 + `/etc/crictl.yaml`; `containerd.io` and `cri-tools` also HELD) — **but NO
CLUSTER.** 🔻 **CORRECTED Sep 17, 2026: the kubelet is NOT `inactive` — it is `activating
(auto-restart)`, restarting every ten seconds on a missing `/var/lib/kubelet/config.yaml`** until
`kubeadm init`/`join` writes it. **The earlier `inactive` was an artefact of a node that had not
rebooted since install.** ✅ **Snapshot `c01-nodes-ready` on all five, taken Sep 17 after a
deliberate reboot onto kernel 6.8.0-139** — the Sep 16 record claimed this snapshot and it had never
been taken.
📖 **Built by the three scripts in `education/k8s-cka-prep/scripts/`** — `1-provision-vms.sh` (Proxmox,
only its contract is portable), `2-personalize.sh` (environment; portable), `3-k8s-base.sh` (kubeadm-ready,
assigns NO role; portable). All three take `--check` and are idempotent — a second run must report **0
changes**. See that folder's `README.md`. ⚠️ **`k8s-setup.sh` was deleted** — its content lives in 2 and 3.

🏠 **HOUSEHOLD devices on this subnet, not lab infrastructure** (identified by MAC, Sep 16 2026 — recorded
because three sessions of address hunting went into devices nobody had written down):
**`.200` = Apple**, the Mac mini running Plex — the docs were right and there is now evidence.
**`.231` = D&M Holdings / Denon** AV receiver.
🔻 **The Denon MOVED TWICE and earlier revisions of this file were left contradicting themselves — it is
on `.231` now.** It sat on `.202` for months, was briefly hand-assigned `.199` **by mistake**, and landed
on `.231` once set back to DHCP. ⛔ **So `.199` is free and `.202` is now `vm-k8s-cka-control-2`** — any note
calling either of those a household device is stale.
✅ **DHCP POOL CONFIRMED `.221–.250`, and the earlier alarm was WRONG — corrected Sep 16, 2026, 3:47 PM.**
Andrew set the Denon back to DHCP and it took **`.231`**, inside the pool (second data point: `.230`).
🔻 **`.199` was NOT the router handing out an out-of-pool address — Andrew had assigned it BY HAND, by
mistake.** ⭐ **So the real recurring risk here was never DHCP; it was a human typing a static address into
the range the lab uses.** That is exactly why the Phase 18 reservation is written into this file: the
protection against it is a *record*, not a router setting.
⚠️ **Still true and worth keeping: three household devices sit at `.215`, `.217` and `.220` — BELOW the
pool.** They are holding leases issued *before* the pool was narrowed and are keeping them, the same
mechanism that kept the Denon on `.202` through three reboots. ⛔ **Do not allocate lab addresses in
`.207–.220`** without sweeping first. **`.201–.206` are clear and nothing new will be offered there**, because
the DHCP server only hands out from its pool.

✅ **VERIFIED LIVE Aug 24, 2026** — `qm list` and `qm config` on `.150`, plus `docker node ls` on
`.191`. Not transcribed from a phase file. Also present and deliberately not given a row:
**VMID 9000** `tmpl-ubuntu-2404-cloudinit` (stopped — it is a template; see **CLOUD-INIT TEMPLATE**).

🔻 **What that check corrected, because the errors are the instructive part:**
- ⭐ **The three Swarm nodes were MISSING ENTIRELY**, having lived only in `phase16` since Phase 16
  closed. **Phase 17 Part 4 deploys to them** — so the next thing to be built targeted hosts absent
  from the file that is supposed to be authoritative on hosts. ⛔ **Closing a phase must not retire
  its INFRASTRUCTURE into the phase file.** A phase file is the right home for the narrative and the
  wrong home for a live address; the demotion rules in `MAKE_MEMORIES` route a *live rule* to its
  proper home for exactly this reason, and a running VM is the same kind of thing.
- **`.182` was listed as hostname `gitlab-runner-1`.** The VM is **`vm-gitrun-1`**; `gitlab-runner-1`
  is the *runner registration* name. Two different namespaces, one of them useless to `qm` and `ssh`.
- **`.186`'s note read as though `onboot 0` meant "currently off".** It was **running**. `onboot 0`
  is a statement about the *next host reboot*, not about now.
- **`.195` had no row at all** despite being the machine everything runs from — the same gap that
  produced the Aug 21 wrong inference that the script server was unreachable and needed Andrew to
  restart it. It is not a Proxmox VM, so `qm list` will never show it.

⚠️ **The pattern in all four: this table drifted where the lab CHANGED SHAPE**, not where facts got
old. Nobody mistyped an IP; hosts were added, renamed, cloned and re-scoped, and the table was only
ever updated for the host the session happened to be touching. ⭐ **Re-measure the whole table
occasionally rather than the row you are looking at** — the rows you are *not* looking at are exactly
the ones that go quietly wrong.
