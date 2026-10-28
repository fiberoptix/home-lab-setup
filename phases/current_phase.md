# Current Phase

**Updated:** October 27, 2026 - 11:10 PM EDT

📐 **Shape, and how to keep it:** `▶️ RESUME HERE` is the **first block** as of Aug 24 — it had been
at line 389 under six stale session blocks, so the one thing you must read first was the one you had
to scroll to find. **Keep it first.** Below it, newest session first. `MAKE_MEMORIES` step 0 now
counts blocks (spec: 2) and step 2 demotes at least one per pass, so this file drains instead of
growing — see that file for why the previous append-only version went undetected for seven months.

## ▶️ RESUME HERE — 🔵 **PHASE 18: THE CLUSTER EXISTS. STAGES 1 AND 2 ARE COMPLETE.**

🆕 **Oct 27 (late): PHASE 20 BUILT — Rancher on single-node K3s, VM 187 `.187`** — a separate track; it
does **not** touch the CKA cluster and does not change the Phase 18 next step below. Open items for Andrew
are in the Phase 20 session block underneath; the record is `phases/phase20_k3s_rancher.md` → ▶️ BUILD RESULTS.

✅ **A REAL 5-NODE HA KUBERNETES CLUSTER IS RUNNING as of Sep 17, 2026** — `vm-k8s-cka-control-1/2/3`
at `.201`–`.203` and `vm-k8s-cka-worker-1/2` at `.204`/`.205`, all **v1.35.8 `Ready`**, three stacked
etcd members with control-1 as leader, **kube-vip VIP `192.168.1.206` up and held by one node**, and
**Calico v3.32.2** (Tigera operator) on pod network **`10.244.0.0/16`**.
✅ **STAGE 1 COMPLETE (all six steps) AND STAGE 2 COMPLETE.** HA proven by an abrupt `qm stop` of the
VIP holder: **17 s** to recover, VIP moved, etcd held quorum 2/3 and **did not re-elect** (killing a
follower, not the leader). Cross-node pod-to-pod and CoreDNS both verified — ⭐ **`ttl=62` on the ping
proves the traffic is ROUTED, not encapsulated.**
✅ **`c02-virgin-cluster` is an OFFLINE baseline on all five, and its rollback is PROVEN — not assumed.**
⭐ **The method is the transferable part: a restore and a plain power cycle print the SAME thing, so
markers were planted first** (a ConfigMap in etcd *and* a file on every node). Both came back gone.
📊 **Restore costs `qm rollback` 6 s, ~49 s to reachable, full cycle under ~2 min** — cheap enough that
Stage 3 can break this cluster freely.
✅ **STAGE 1 IS DOCUMENTED (Sep 23, 2026) — chapters 02, 03 and 04 all written, so the gate into Stage 3
is OPEN.** ✅ **Chapter 05 plan APPROVED Sep 23** — the simplest CKA-congruent shape: metrics-server (Kustomize),
local-path-provisioner, the Gateway API CRDs, and Traefik (Helm) for both Ingress and Gateway API, NodePort
only, then an offline `c03-equipped-cluster`. 🔲 **NEXT: build Part 1, metrics-server v0.9.0 — Andrew drives. Step 1 is handed over and NOT yet run**
(`kubectl top nodes`; `kubectl get apiservices | grep metrics`).
⭐ **Stage 3 rule: does the exam test it, and is this the simplest way to practise it?** Production
choices for the work rebuild are parked beside the plan in `phase18`. ⏸️ **The Swarm chapter-8 `recited` rows are
DEFERRED, not dropped** (Andrew, Sep 23): they resume, together with Phase 17, once he knows the firm's
actual Swarm setup — a migration test is only worth its resemblance to the real platform. ⛔ Keep the
Swarm in place meanwhile. 🔄 *Its snapshots `s01`–`s07` were purged Sep 28 by Andrew's decision (Phase 19);
the only Swarm snapshot now is `baseline-2026-09-28`.* 🆕 **Hard rule B9: never install ingress-nginx — retired
upstream March 2026.**
⚠️ **The cluster ran six days unattended and was healthy on return** — raft term still 5, so no etcd
election at all in that time.
🆕 **Sep 28, 2026 — AUTOMATIC UPDATES FROZEN ON ALL FIVE NODES; the Sep 17 "do not mask" call is
REVERSED.** They were the only VMs in the lab still patching themselves: `unattended-upgrades` had
installed kernel **`6.8.0-142`** (Sep 25) and ~20 packages **after** `c02` was taken. ✅ Now masked
**and** stopped on all five (`2-personalize.sh --freeze-updates`, fixed today), verified independently:
0 scheduled apt timers, 0 failed units, cluster untouched. Full record: `phase18` Stage 3 drill block +
`MEMORY.md` → PATCHING POLICY. ✅ **`c02-virgin-cluster` was RETAKEN Sep 28** (old one deleted; new one
offline on all five, verified 1 → 0 → 1 at both the `qm` and ZFS layers): kernel 142, auto-updates
frozen, PVE 9.2.20 / QEMU 11.0.3. 🚨 **`c01-nodes-ready` still PREDATES THE MASK** (kernel 139, updates
enabled) — after a rollback to `c01`, re-run `sudo bash 2-personalize.sh --freeze-updates` on all five.
🔲 **NEXT, in order (Andrew approved Sep 28):** (1) ✅ freeze nodes — done. (2) ✅ **PVE host
upgraded to 9.2.20 and rebooted on the SAME pinned `7.0.14-4`** (Sep 28, 17:13 → 17:15:56). Cluster shut
down workers-first, started control-planes-first: 5/5 `Ready` on kernel **142**, 39/39 pods Running, DNS
verified, auto-updates still frozen. etcd leader is **control-2** (term 6; it was already control-2 at
term 5 before the reboot — "control-1 as leader" above is the Sep 16 build state). ⚠️ After the cold
start 15 pods sat in `Unknown` and one `calico-apiserver` flapped not-ready for ~2 min — both cleared
on their own; **check again a few minutes later before calling a cold start broken.** Host detail:
`MEMORY.md` → PATCHING POLICY (🚨 the upgrade silently dropped the proven fallback kernel off the ESPs).
(3) ✅ five-node baseline `c02-virgin-cluster` retaken — cluster back 5/5 Ready, all pods Running. (4) 🔲 **kernel drill on the NEXT kernel, within 60–90
days** — see `phase18`. (5) ✅ **host kernel trial DONE Oct 27, 2026 — on `7.0.14-26` (not `-19`; the
target moved), PVE 9.2.24.** See the Oct 27 session block below. ✅ Cluster 5/5 `Ready`, 39/39 pods after it.
⚠️ **Read the Stage 1 results block in `phases/phase18_k8s_cka_build.md` before touching this** — it
holds the corrections (kube-vip did NOT crash-loop; the Calico operator HARD-CODES
`192.168.0.0/16`; `node.spec.podCIDR` is inert; `RESTARTS 0` does not mean a static pod was
untouched).

## 📘 SESSION Oct 27, 2026 (22:00–23:10) — Phase 20: Rancher on K3s built end to end (AI-built)

🎯 **Outcome: https://rancher.gothamtechnologies.com is up (Rancher 2.15.2 on K3s v1.35.9, VM 187), with
monitoring, and http://hello-rancher.gothamtechnologies.com/ is deployed by Fleet GitOps from GitLab
`production/rancher-k3s` — push → serving in ~40 s. Drills D1–D4 passed.** 🙋 *"Try to build the whole
thing and note errors. I'll come back to help manage them."*

### ✅ Done (the AI built it; Andrew set scope, names and repo location)
1. VM 187 (template 9000 → new `rancher-k3s/1-provision-vm.sh` → `2-personalize.sh` → full-upgrade), in
   `refresh.sh` (md5 host = repo), Route53 `rancher` + `hello-rancher` → `.187`.
2. K3s → Helm v3 → cert-manager → Rancher → rancher-monitoring → GitLab project + tokens + CI → Fleet
   GitRepo → push-model SA. Scripts `3-`…`6-*.sh` all re-ran with 0 changes. Snapshots `r01` → `r02` → `r03`.
3. Drills: reboot 63 s to Rancher (after a fix), Rancher at 0 replicas does not stop apps OR GitOps, broken
   manifest is safe and reverts in 21 s, broken registry credential diagnosed and restored in 16 s.

### 🚨 Found (all in `phase20` → findings F1–F12, errors E1–E7)
- **One container ignoring SIGTERM cost 87 s on every VM reboot** (Python as PID 1). Fixed in the app.
- **Fleet's status lagged a finished rollout by ~4 min**; **Rancher's pod summary hides a registry 401**.
- Rancher 2.15.2 has **no `telemetry-opt` setting** (script error, fixed).

### 🔲 Open — for Andrew
- 🔲 **Log in and look around** — `admin`, password in `PASSWORDS.md`. The CA is Rancher's own, so the
  browser warns.
- 🔲 **E7: the GitLab root password was printed in this session's tool output** (redaction miss, local
  transcript only). The same string is already in tracked `MEMORY.md`/`current_phase.md` as the SMB
  password (pre-existing), so it is shared — rotating it is a lab-wide decision.
- 🔲 **Revoke the 7-day root PAT `phase20-ai-build`** when Phase 20 is closed (expires 2026-11-03 anyway).
- 🔲 **D5 due ≥ Oct 28 23:00** — Prometheus disk vs the 44.3 MB baseline. **D6** when Rancher > 2.15.2 ships.
- ⚠️ This file now holds **four** session blocks (spec: 2) — two demotions owed under `MAKE_MEMORIES`.

## 🔧 BUILD STANDARD OVERHAUL — a second distro, and the script server nearly deleted itself (Aug 21, 2026, evening) ✅ DONE

⚠️ **This session did NOT advance Phase 17.** Part 4 (deploy to the Swarm) is still the next Jenkins
action — see RESUME HERE below, which is unchanged and still correct. Tonight was Phase **2/2b**.

🙋 **Andrew: "I created some new host setup scripts on my laptop… please review them"**, then
**"YOU wrote the Fedora scripts… I trust you to fix anything. What needs fixing?"**

**Full detail is in `phases/phase2_host_setup_automation.md` and `phases/phase2b_fedora_host_setup.md`.
Do not duplicate it here.** What a cold reader needs:

| What changed | Why it matters later |
|---|---|
| **Script trees renamed** `www/scripts` → **`www/ubuntu`**, `www/scripts_fedora` → **`www/fedora`** | Old URLs still work via **301s in `nginx.conf`** — deployed VMs have the old `SCRIPT_SERVER` baked in and must keep working |
| **`www/index.html` landing page** at `http://192.168.1.195/` | The **copy to trust** for build commands; rewrites the host from `window.location`, so it is right from any interface |
| **`--hostname <name>` now on BOTH distros** | Fixes `/etc/hosts` (which `hostnamectl` never touches) and pins cloud-init, without which an Ubuntu clone **silently reverts at the next reboot** |
| **`--server` now on BOTH distros** | Exposed a bug that had been putting **1.44 GB of Chrome + Cursor on every headless Ubuntu host** |
| **`smb_credentials` moved to `www/smb_credentials`** | *Above* the two bind-mounted trees, so nginx cannot serve or `autoindex`-list it at all |

🚨 **The one that could have cost real work: `host_setup.sh` ATE THE SCRIPT LIBRARY.** Running it
with the working directory inside `www/ubuntu/` zeroed **all seven sub-scripts + `anysphere.gpg`** in
a single run. `wget -O` truncates its destination *before* transferring; the script downloads
sub-scripts *next to itself*; nginx serves that same directory *off disk*. So wget emptied each file,
asked nginx for it, and got back its own zeros. ⭐ **A program that fetches its inputs into its own
source directory, from a server backed by that directory, will eat itself.**
Fixed twice: both trees **refuse to start** in the source tree, and **downloads are now atomic**
(`.part` + `mv`) — which matters more, because *any* failed download previously replaced a working
script with an empty file, worst in the re-run-to-repair case. **Fedora had the identical `curl -o`
flaw** and escaped only because its distro guard exits first on Debian.
⚠️ **Recovery was luck:** `git checkout` would have restored *pre-session* content, and
`www/ubuntu/setup_hostname.sh` was **untracked** — git had nothing. Only stray `/tmp/tmp.*/`
bootstrap-test copies saved it. ⭐ **Commit before testing anything that writes into the repo.**

🩹 **Also fixed: `/` appeared to redirect to `/ubuntu/`.** The server was innocent — it returned
`200` the whole time. The *previously committed* config had `location / { return 301 /scripts/; }`,
and **a 301 is permanent, so browsers cache it indefinitely, often through a hard reload.** A cached
hop plus the new compat rule landed on `/ubuntu/`. ⛔ **Redirecting `/scripts/` back to `/` would be
an infinite loop** (the browser bounces `/` straight back); bare `/scripts/` now **serves** the
landing page instead. ⭐ **Only 301 to clients that will not hold you to it** — the remaining compat
redirects now carry `Cache-Control: no-store` for exactly that reason.

✅ **`.185` (Jenkins) reclaimed 1.5 GB** — purged Chrome + Cursor, simulated first, Jenkins stayed
`active`/`200` throughout. 🛑 **`apt-get autoremove` DECLINED on purpose (Andrew's call):** it wanted
**100 packages / 382 MB** of X11 + GTK libraries, and `.185` is a **CI host** — headless browser
testing needs exactly those. **Do not "finish the cleanup" without revisiting that trade.**

⚠️ **Unproven:** the `--server` *success* path has not run on real hardware on either distro. Fedora
was validated in a **stubbed sandbox** (branch selection + the D-Bus bypass, not real `dnf`), and the
only Ubuntu box available is the dev workstation, which must not be reconfigured. **VM 185 or a fresh
build is the honest place to confirm both.**

---

## 🔵 PHASE 17 PARTS 0 + 1 — Jenkins is up (Aug 20, 2026, ~1:00–2:30 PM EDT) ✅ DONE

🙋 **Andrew: "I'd like to go step-by-step with you building it so I understand all the pieces. I'd
like to run all the commands myself."** He did — every command, including the VM build. The AI's
contribution was instruction, live diagnosis, and **read-only verification** (Jenkins' REST API for
plugin/node state, `ps` and file modes over SSH). That division is stated in the track README too,
because a claim checked against `/api/json` outranks the same claim read off a web page.

**Working protocol agreed at the start and honoured throughout** (recorded as P1 in the phase file):
Part 0 is hands-on but earns **no chapter**; when a trap is near the AI says *"there's a trap coming
— what do you think it is?"* without revealing it; **build-process improvements get fixed live**
rather than logged for later; session scope was Part 0 + Part 1.

**What was built.** VM 185 `vm-jenkins-1` from template 9000 (4 vCPU, 8 GB, 60 GB on `vm-critical`),
then Jenkins **2.568.2 LTS** on **OpenJDK 21**, controller at **0 executors**, one SSH agent as OS
user `jenkins-agent`, label `swarm-deploy`, host key pinned, private key deleted from the host so it
exists only in Jenkins' credential store. Snapshot **`j02-jenkins-up`** taken (VM shut down for it)
and `.185` restarted clean.

**Findings — full detail in `phase17_jenkins.md`, do not duplicate it here:**

| # | What |
|---|---|
| **J-P2** | Part 0. Template clone ≠ live-VM clone: fresh `smbios1` UUID means cloud-init personalises it, and new host keys on a **reused address** caused a `known_hosts` mismatch. Also the first end-to-end test of the Cockpit + `nofail` build-script changes — **both passed** |
| **J-P3** | The apt install misleads twice: the **unversioned key filename is the OLDEST key** (dead since 2023), and the `jenkins` package **declares no Java dependency**, so it installs cleanly and cannot start |
| **J-P4** | Six deliberate plugin choices → **73 installed plugins**; and `ssh-agent` ≠ `ssh-slaves`, so the build standard's own list omitted the plugin its own topology needs |
| **J-P5** | The split, **proved with a queued build before the agent existed**. Plus: the agent can read `credentials.xml`, and `Running as SYSTEM` is a second privilege plane |

**Two decisions closed on the record.** Agent transport = **SSH**, argued from lifecycle ownership
(with SSH the controller can restart a dead agent; with JNLP it can only wait) rather than from
convenience — ledger row **J2** covers the cost of co-locating it. And patching policy: every VM's
`unattended-upgrades` and `apt-daily*` timers are **masked**, with `refresh.sh` the only path,
`.185` added to it.

📖 **Education track 3 opened** — `education/jenkins/README.md` + chapter 1, figure `figcheck`-clean
at 10.2 pt, highlighted to 20.1 % at drafting time, DOCX built, and the track indexed in
`education/README.md`. ⚠️ **There is deliberately no chapter 0** — Part 0 is the "assume it" plumbing
`CONVENTIONS.md` tells you to cut.

---

## 🩹 LAB-WIDE `nofail` SWEEP + a security find on .184 (Aug 20, 2026, ~12:38–12:50 PM EDT) ✅ DONE

🙋 **Andrew: "let's fix the nas issue on all current VMs."** Then, mid-sweep:
**"184 should NOT mount the NAS! It's prod-local."**

**Done: all 9 VMs + this dev workstation now show `RequiredBy=` empty.**

| Host | Before | After |
|---|---|---|
| .180 qa, .181 gitlab, .182 runner, .183 sonar, .186 redpanda, .191–.193 swarm, .195 dev | `RequiredBy=[remote-fs.target]` (.180 already fixed) | `RequiredBy=[]`, `WantedBy=[remote-fs.target]`, mounts untouched |
| **.184 www** | had the mount **and** it had been **failing every boot since July 9** | 🚫 **entry removed entirely** — see below |

**Method** (`working/fix_nofail.sh`, re-runnable): back up fstab → edit only the one CIFS line →
restore automatically if the edit doesn't verify → `daemon-reload` → assert `RequiredBy=` empty →
assert the live mount survived. Canaried on **.193** (least critical) and the swarm was re-checked
before touching anything else; **.181 GitLab went last-but-one and the dev box last.**
⭐ **The raw `sed` is NOT idempotent** — run twice it appends `nofail,nofail`. The script's
"already has nofail?" pre-check is what makes it safe, and a throwaway test caught that before it
ever touched a host.

### 🚫 The .184 find — a build standard leaking credentials into the DMZ

`.184` is the internet-facing PROD box. Phase 12 gave it `OUT DROP -dest 192.168.1.0/24`, so the NAS
is unreachable **by design** — confirmed: ping 100% loss, 445 blocked. Yet the standard build had
given it the NAS fstab entry, which had been failing at **every boot since July 9**, and — the part
that actually matters — had left **`/root/.smbcredentials` on the internet-facing host** for a share
it is forbidden to touch.

Removed: fstab line, mount unit, `/mnt/DevShare`, credentials file. Verified nothing referenced the
path (no container bind-mounts; only stale Cursor logs from January). **PROD re-checked after:
all 6 containers up, :80 → 301, :443 answering. Zero failed units.**

⭐ **The lesson: a uniform build standard will plant credentials on exactly the hosts your network
design isolates.** The firewall did its job perfectly; the **builder** was the leak.

**Two guards added so a rebuild cannot recreate it:**
- `bash host_setup.sh --no-nas` — deliberate skip for a prod-local host.
- **`setup_smb_mount.sh` now pre-checks `<nas>:445` and refuses** to write fstab or credentials if it
  cannot connect. ⭐ The better of the two, because it needs nobody to remember anything.
  **Proven by running it on .184 itself:** refused, wrote nothing, host stayed clean.

⚠️ **Gotcha found by testing:** `SKIP_NAS=1 sudo -E …` **does not work** — sudo has `env_reset`, warns
*"preserving the entire environment is not supported"*, and silently drops the variable, so the script
ran in full on the dev box. Harmless there (everything already existed), but the documented invocation
was wrong and is now `sudo SKIP_NAS=1 bash ./setup_smb_mount.sh`. 🧠 **Testing the happy path is not
testing the guard.**

### ⚠️ CORRECTION — we overstated what missing `nofail` costs

Earlier today this was written up as *"drops to an emergency console, no network, no SSH."* **That is
wrong**, and `.184` disproves it from inside our own lab: it failed this mount at every boot for six
weeks and came up fine each time. `_netdev` already keeps these entries out of `local-fs.target`; the
emergency-console behaviour belongs to network mounts written **without** `_netdev`. Real cost of
`_netdev` without `nofail`: a **bounded boot delay** (11 s measured, ~90 s worst case) and a
permanently failed unit. Worth fixing — not a catastrophe. 🧠 **A plausible mechanism was asserted
instead of checked, while the host running the experiment sat one `systemctl status` away.**
Corrected in `MEMORY.md`, the phase-2 doc, and the script comments.

⚠️ **Still unverified:** template **9000** has not been checked for a NAS fstab entry (it is stopped,
and checking means booting a clone). Any VM cloned from it runs the fixed `host_setup.sh` anyway.
👉 Check it during Phase 17 Part 0, when a clone is being made regardless.

---

## 🔧 BUILD STANDARD CHANGED — Cockpit is now on every Ubuntu server (Aug 20, 2026, ~12:25–12:40 PM EDT) ✅ DONE

🙋 **Andrew's call:** *"I think we should make this part of every new ubuntu server we build… make sure
we do it the safe way like you said."* Triggered by installing Cockpit by hand on `.186` earlier today.

**What changed — three files, all in the build path:**

| File | Change |
|---|---|
| `www/scripts/setup_cockpit.sh` | 🆕 **NEW.** Installs Cockpit; detects the network stack; **simulates the install and exits 1 if `network-manager` would appear** |
| `www/scripts/host_setup.sh` | Downloads and runs it in **Phase 1**, next to SSH and sudo |
| `www/scripts/setup_smb_mount.sh` | 🩹 **Unrelated bug found and fixed:** fstab got `_netdev` but **not `nofail`** |

⭐ **The design decision worth remembering: the script enforces the rule instead of documenting it.**
The obvious implementation was "write down the safe package list and trust future-us to use it." That
fails the first time someone in a hurry types `apt install cockpit`. Instead `setup_cockpit.sh` runs
`apt-get install -s`, greps the result, and **refuses to continue** if NetworkManager shows up on a
host that does not already use it. It also *adds* `cockpit-networkmanager` on hosts where
NetworkManager **is** active (desktop builds), so the rule is "match the host", not "never install it".

**Measured, not assumed** (dry run on swarm node .191, which has no Cockpit):

| Install | Packages added | Pulls network-manager? |
|---|---|---|
| `apt install cockpit` | **35** | **YES** + `dnsmasq-base`, `ppp`, `pptp-linux`, `wpasupplicant`, `wireless-regdb` |
| Our explicit list | **19** | No |

🩹 **The `nofail` find.** Chasing "where do we document server builds" led into `setup_smb_mount.sh`,
which wrote `_netdev` **without `nofail`** — so every VM ever built by the standard script carried it.
Fixed at the source, then **swept the whole lab (see the next block).** 🧠 **The lesson: when a per-VM
fix works, immediately ask whether the builder has the same bug.** Fixing the VM fixes one VM; fixing
the script fixes every future one.

**Verified:**
- `bash -n` clean on both scripts.
- Re-ran `setup_cockpit.sh` **on .186 where Cockpit already exists** — correctly reported "already
  installed, nothing to add", left the network stack alone, confirmed :9090 listening. **Idempotent.**
- Both scripts serve HTTP 200 from `http://192.168.1.195/scripts/`, and the served copies contain the
  guard and the `nofail` option — so a build started right now would pick them up.

**Not yet proven:** no VM has been built end-to-end with the new `host_setup.sh`. 👉 **Phase 17 Part 0
(the Jenkins VM) is the first real test**, and Part 0 now says so explicitly.

---

## 🔧 UNPLANNED INTERRUPT — QA server re-numbered 200 → 180 (Aug 20, 2026, ~11:25–11:40 AM EDT) ✅ DONE

🤖 **AI-executed infrastructure plumbing, Andrew approved the 8-step plan and said "go ahead."**

**What and why.** The QA box was **VMID 200, hostname `vm-kubernetes-1`, IP `.180`** — a VMID that didn't
match its IP and a hostname advertising Kubernetes it has never run (it runs **Capricorn QA on plain
`docker compose`**, not even Swarm). It is now **VMID 180, `vm-docker-qa-1`, `.180`**, matching the
`18x → .18x` convention every other VM follows. 🚨 **Proxmox cannot re-number a VM in place — "renumbering"
is always a clone**, which is why this was a copy-and-validate job rather than an edit.

~~**The old VM 200 is STOPPED with `onboot 0`, deliberately kept as the rollback until ~Sept 3, 2026,
then destroy.**~~ ⛔ **EXECUTED Sep 16, 2026 — VM 200 is DESTROYED** (`--purge`, no backup) and this
directive is spent. Nothing here is actionable any more; the `pre-clone-20260820` snapshot below went
with it.

⚠️ **Two hazards found before starting, both real:**

1. **The CIFS mount in `/etc/fstab` had no `nofail`** — an unreachable NAS could hang boot. Fixed on the
   original before cloning, so both VMs carry the fix. **Proof it worked is not the fstab line, it's
   the generated unit:** `systemctl show mnt-DevShare.mount` went to **`RequiredBy=` empty,
   `WantedBy=remote-fs.target`** — a *want*, not a *requirement*, so a dead NAS can no longer block boot.
2. **No cloud-init drive on this VM, so the IP is static inside the guest** — the clone claims `.180`
   too. **`onboot 0` on VM 200 is therefore load-bearing, not tidiness**: without it a host reboot
   starts both and they fight over the address.

🚨 **The snapshot outlives the fix: `pre-clone-20260820` still records `onboot: 1`.** Rolling VM 200 back
during the validation window **re-arms autostart** and re-creates the IP collision. `qm config 200`
shows the live value; `qm config 200 --snapshot <name>` shows the snapshot's — they differ, and reading
the raw `200.conf` shows *both* pairs, which is easy to misread.

**Three things that did NOT break, each worth knowing:**

| Survived | Why |
|---|---|
| **Networking, despite a new MAC** | The clone got `BC:24:11:20:08:8B` (was `…DB:8D:CD`). Netplan here matches on **interface name `ens18`**, not MAC, so `.180` came straight back. Had it matched on MAC the box would have booted deaf — the escape hatch was **`agent: enabled=1`**, since `qm guest exec` runs over virtio-serial and needs no network at all |
| **SSH from the dev box** | A clone keeps the **same host keys**, and the IP didn't change, so `known_hosts` needed no clearing |
| **`refresh.sh`** | It targets hosts **by IP, not VMID**, so re-numbering was invisible to it. Only its comment block was wrong |

**Verified after a deliberate cold stop/start** (not just after the clone boot): hostname persisted, NAS
auto-mounted, **zero failed systemd units**, all four `capricorn-*` containers up on their own restart
policies, `:5001` and `:5002` both **HTTP 200** from off-box. Snapshot **`q01-cloned-verified`** taken.
Docker's restart policies brought the stack back with no intervention.

✅ **CLONE ACCEPTED — Andrew re-ran the last Capricorn QA deployment from GitLab and it worked.** So the
**stored CI credentials still authenticate against the renamed host**, and **key-based SSH from the dev
box still works with no password**. That closes the migration: nothing in the pipeline referenced the
VMID or the hostname, only `192.168.1.180`. ✅ Independently swept — **no `/etc/hosts`, `~/.ssh/config`
or `known_hosts` entry on `.181`–`.184` or the dev box ever named `vm-kubernetes-1`.** Everything in
this lab addresses that box by IP, which is exactly why a re-number was cheap.

🚨 **AUTOSTART LOCKED DOWN (Andrew, same session): only 180, 181, 182, 183, 184 come back after a host
reboot.** **186 and 191/192/193 were all `onboot 1` and are now `onboot 0`** — they were quietly
starting themselves. ⚠️ **This means the Docker Swarm is DOWN after any host reboot**, so
`qm start 191 192 193` becomes a **prerequisite for Phase 17's Jenkins→Swarm deploys**, not an
afterthought. **Boot order also set** — GitLab first with a 60 s head start, then 182/183, then 180/184.
Both recorded in `MEMORY.md` → *AUTOSTART POLICY*. ✅ Verified **no HA resources and no cluster**, so
`onboot` is the only thing that can start a guest.

📸 **Snapshot `q02-qa-deploy-verified` taken OFFLINE** (VM shut down first, so disk state is consistent
by construction rather than by fs-freeze). It captures the accepted post-migration baseline: GitLab
deploy re-run successfully, `onboot=1`, `startup order=3`. ✅ **Unlike VM 200's snapshot, this one
records the CORRECT `onboot` value**, so rolling back to it is safe. VM 180 was restarted and
re-verified afterwards: no failed units, NAS mounted, four containers up, `:5001`/`:5002` HTTP 200.

🖼️ **Fixed the one stale reference outside the docs: `education/k8s-k3s-redpanda/diagrams/ch01_fig1_stack.dot`**
labelled a box `VM 200 / QA/k8s / .180`. Now `VM 180 / QA / .180` — **the "k8s" label was always wrong
and actively undercut that chapter**, whose whole point is that VM 186 is the only k3s box. PNG
re-rendered and **chapter 1's `.docx` rebuilt; the other six were left alone, so no rebuild noise.**
⚠️ **Known and accepted limitation:** the figure still omits 191–193 (built Aug 13, after the chapter)
and 185. It depicts the lab as of the k3s track and is not a live inventory.

📌 **RULING — VM 180 gets NO backup. Built, proven, then removed the same hour on Andrew's
instruction.** The AI created `nas-docker-qa` + a nightly job and proved it with a real run (live
`snapshot`, **2m20s, 10.66 GB**, `gmail-smtp` notification, artifact confirmed on the NAS). Andrew:
*"VM180 does not need backups. Remove the one you added."* **All of it is gone** — job, archive,
storage, credential file, local mountpoint, and the NAS folder. Verified: one storage list, one job
(`gitlab-nightly`), four `.pw` files. ⭐ **The reasoning generalises and is the part to keep: QA is
rebuilt by GitLab CI on every deploy, so it is a deploy target, not a data store. Only irreplaceable
state earns a backup.** 🚨 **Do not re-add it as a "helpful" gap-fill.**

📊 **Two things worth keeping from the exercise anyway.** Sizing: **80% of that 100 GB disk was zeros
and was sparse-skipped**, so archive size tracks *used* data, not provisioned size. And teardown:
`pvesm free` clears the archive but **PVE's `dump/` subdir survives and the CIFS dentry cache lies
about it** — `ls`/`find` showed a `dump` directory that `stat`/`rmdir` said did not exist and `rm -rf`
refused as *"Directory not empty."* **A fresh mount with `noserverino` fixed it instantly.** A deleted
folder may still enumerate as `d????????? ? ?`; `test -d` is the honest check. Full note in
`proxmox/Home_Lab_Proxmox_Storage.md`.

🚨 **The wider coverage gap is REAL and still open, and 180 is now deliberately part of it.** The lab has
**exactly one scheduled job** (`gitlab-nightly`, 181). Swarm nodes 191–193 have NAS storages but only
**one hand-made dump each from Aug 13, no schedule**; **180, 184, and 186 have nothing.** ⚠️ **Don't
infer coverage from `pvesm status` — read `/etc/pve/jobs.cfg`.** ⭐ **184 is the one that should still
bother us**: unlike QA it runs Capricorn **PROD** and the public site, so the "rebuildable" argument
that justifies skipping 180 does **not** cover it. **Andrew's call, not raised as urgent.**

🔁 **REPEATED A DOCUMENTED MISTAKE — worth reading, because the trap caught two different sessions.**
Four manual `mount -t cifs` attempts from `.150` all returned **error(13) Permission denied**, *including
the exact path `nas-gitlab` already mounts successfully*. The AI first concluded the credential in
`PASSWORDS.md` was stale. **It is not.** 🚨 **`/etc/pve/priv/storage/<id>.pw` contains `password=<value>`
plus a newline, NOT a bare password** — so its 19 bytes are `password=Powerme!1`, and passing
`$(cat …pw)` as the password sends the literal string `password=Powerme!1`. **`MEMORY.md` already
warned about this** (same sub-bullet, from a Jul 2026 session that made the identical error and had to
retract a fake "credential outage"). ⭐ **The lesson that didn't stick the first time: a byte count is not
a value.** Reading the existing note before probing would have saved all four attempts.

⚠️ **Attempts were stopped at four deliberately** — Synology-style auto-block trips around five failures
and would blackhole the Proxmox host's IP, killing the nightly GitLab backup and every guest's
`/mnt/DevShare`. ✅ **No harm done — re-verified afterwards:** all four NAS storages `active`,
`pvesm list nas-gitlab` works, a write-and-delete into it succeeded, and `.180`/`.181` still have
`/mnt/DevShare` mounted.

**Docs updated:** `MEMORY.md` (4 places), `README.md` (also corrected OpenClaw from "retired" to
destroyed), `refresh.sh` comment — **and re-deployed to `/usr/local/bin/refresh.sh`, which was
byte-identical to the repo copy beforehand and is again now.** `SYSTEM_VERIFICATION.md` was **banner-ed
as a stale historical snapshot rather than edited** — it is a dated Jan 14, 2026 report, and it is
missing five VMs and understates GitLab's RAM. Historical phase files 2/4/5/7 left untouched.

---

## 🟢 PREVIOUS — PHASE 16 CLOSED (Aug 19, 2026). Nothing outstanding.

**Phase 16 (Docker Swarm) is DONE: all 7 parts, all 7 planted traps, 8 chapters.** Part 7 closed on
Aug 19 as `education/docker-swarm/chapter08_swarm_vs_kubernetes.md` — the Swarm↔Kubernetes crib sheet
the whole two-track comparison was for.

**What chapter 8 is, in one line:** every claim carries a provenance mark — **S** (measured on the
three-node Swarm), **K** (measured on single-node k3s), 🤖 (measured only in AI-executed chapter 7), or
⚠️ **recited** (neither lab ran it, so it must never be quoted as experience). ⭐ **Reuse that device
for any future cross-track writing;** without it a synthesis chapter launders textbook claims into
apparent experience. Its two non-obvious conclusions: **the PVC abstraction is not what protects your
data** (the k3s lab's `local-path` strands it on the same nail as a Swarm named volume — the value is
the driver ecosystem, not the object), and **Swarm's digest-pinning default is the safer of the two
image models**, which is the opposite of the usual narrative. It also caught one flattering falsehood
in its own first draft (see the phase file, Part 7 → C1): "encrypted Raft log by default" is **wrong**,
and chapter 1's own Lab-vs-PROD callout says so.

⚠️ **What is actually left — and the claim that was wrong here for a day:**

1. 🚨 **Drill D is NOT outstanding. It ran Aug 18** (P30 ✅ smoke gate is the only thing that catches a
   rotated secret, P31 ✅ Postgres keeps the old password, plus the `pg_hba.conf` `trust` discovery and
   chapter 5's row D). **This block said "outlined but never run" until Aug 19 and the `MAKE_MEMORIES`
   pass that evening repeated it into `MEMORY.md` as the phase's only open item.** The cause: the
   drill's planning entry in the phase file still had an unticked `🔲` box, and the summaries were
   edited without being diffed against the results 1,900 lines below. ⭐ **Re-read what you summarise.**
2. ✅ **MEASURED AND CLOSED Aug 19, 7:55 PM — the `redis` divergent-volume question. 🤖 AI-executed,
   read-only, at Andrew's instruction.** The hypothesis was **refuted**: `.191` has never held a redis
   volume, and the two volumes that do exist (`.192` Aug 13, `.193` Aug 18 19:06:56) are **trap C3's
   deliberate residue** — the numbers match C3's own write-up. `.192` holds `c3:canary` + `c3:counter`
   (155 b, AOF generation 2); `.193` is **88 b with zero keys** (AOF generation 1, a fresh start). The
   live task has run since Aug 18 with `RestartCount 0`. Nothing was lost.
   🚨 **The real finding is why the question existed: `docker service ps`'s `CURRENT STATE` age is the
   last time the MANAGER STAMPED the task's status, not the task's age.** Task `CreatedAt` Aug 18
   23:14:24 UTC vs `Status.Timestamp` Aug 19 16:11:15 UTC — 20 hours apart, and it is the *stamp* that
   renders as "Running 8 hours ago". The stamp moves on control-plane churn, so **a day-old task can
   look freshly rescheduled.** Clock skew was excluded by measurement (all three nodes NTP-synced, agreed
   within 1 s). Now in `COMMANDS.md` as its own section, with the commands that answer each question.
   ⚠️ **Standing hazard left in place, not fixed:** the empty 88-byte volume still sits on `.193`, so
   `redis` scheduling there would silently attach an empty cache. Removing it is destructive and it is
   C3's evidence — Andrew's call, not a cleanup step.
3. **Deferred to Phase 17 on purpose:** the rigorous convergence check that compares each service's
   `.Version.Index` across a deploy instead of trusting the settle delay. Recorded as a mitigation, not
   a proof.

✅ **DONE the same evening — the highlight programme, both tracks (Aug 19, ~5:30–6:30 PM).** Andrew
raised the target to **20 %** after a trial he judged from the printed page, not the number. **All 15
chapters now sit at 19.5–21.2 %** (Swarm ch1/2/4/5/6 were at 2.3–3.6 %, i.e. 5–6 marks each; the k3s
track was at 12.6–14.9 %). Full before/after table and method: **`phases/phase15_education_program.md`
§8** — that section is the one to read before any future highlight work, for two reasons:

- ⭐ **Measure density PER SECTION, not per chapter.** k3s ch3 read 14 % overall while §5/§7/§8 sat at
  7.2/6.2/4.9 % — drafting-time marks cluster where the argument is and skip walkthroughs. A list aimed
  at the chapter average would have pushed the dense sections past 30 % and left the thin ones alone.
- 🚨 **A mark that swallows one half of a `**bold**` pair renders the asterisks LITERALLY in the
  `.docx`.** 15 marks were doing this across both tracks. `education/tools/highlight.py` now **refuses**
  that, and also refuses a mark opening inside an already-open mark (which had nested one in k3s ch4).
  ⭐ The Markdown passed every check that existed; the defect existed **only in the built artefact** —
  so verify the artefact (`unzip -p x.docx word/document.xml`, grep for literal `**`), not the source.
  ⚠️ The old blanket rule "never re-run `highlight.py` on a highlighted file" applies only to re-running
  the **same** list; a **top-up with a list of only-unmarked phrases is now the normal workflow.**

✅ **Cluster state at handoff: HEALTHY, and re-verified AFTER C7's cleanup** — not assumed. All three
`Leader/Reachable/Reachable`, raft churn `0`, services `2/2 3/3 1/1 1/1`, all three smoke gates green at
`total=682` (**identical to the pre-C7 baseline**), `docker stack ls` shows `capricorn` only.

⚠️ **OBSERVED, not caused by C7, and NOT "fixed": `docker-swarm-3` hosts ZERO Capricorn tasks.**
Placement is `swarm-1: 4, swarm-2: 3, swarm-3: 0`, with task ages of 2–5 hours — so this predates the
C7 session and dates from `qm stop 193` during the P48/P50 tests. ⭐ **Swarm does not rebalance when a
node comes back.** Every service still reads its desired count, so **`2/2 3/3 1/1 1/1` is true while a
third of the cluster sits idle** — the same family as chapter 5's "reboot that silently cost three
replicas". 🙋 **Left alone deliberately:** the only remedy is `docker service update --force`, which
restarts tasks (and, per C7 P55, restarts them on the *pinned* image) — that is Andrew's call, not a
cleanup step. **Chapter 5 / Part 7 material: capacity is not replica count.**

⭐ **`s07-c4-fixed-verified` taken on all three nodes** (rule B3) before C7 started. **It is the first
snapshot in the chain that contains the C4 fix** — `s06` predates it, which was a standing rollback hazard.

✅ **CORRECTED — the previous handoff claimed "`.191` still holds the PRE-FIX `deploy_swarm.sh`". That is
FALSE as of Aug 19 4:15 PM:** the node's copy and the repo copy are **md5-identical** (`0bf970b7`), and the
P4-F8 advisory string is present on the node. ⚠️ **A recorded claim about live state went stale within
hours, and the fix was to go and look** (`md5sum` on both sides) rather than to trust the handoff. Same
failure family as the P48 row that stayed "NOT TESTED" for hours after passing.

### ✅ CLOSED — trap C7, and the trap could not fire (🤖 AI-EXECUTED, 4:10–4:50 PM)

🤖 **Andrew's written instruction, 4:07 PM: run it and document it without him.** So C7 is the ONE part of
this track the AI drove. **Declared in chapter 7's opening, in the track README, and in `MEMORY.md`** —
`CURSOR_RULES` rule 3 and `METHOD.md` → "Who does the work" both apply, and the material is deliberately
marked **weaker** than the six chapters Andrew drove.

**The planted trap was unfireable** (P60 ✅): `docker stack deploy` re-resolves by default, so the spec
followed the moved tag every time. **But "I pushed a fix and prod is still running the old code" happened
twice anyway**, by mechanisms the plan never considered:

- 🚨 **The deadlock (unplanned, the session's best finding).** `order: start-first` + `max_replicas_per_node: 1`
  + `replicas == node count` **cannot make progress** — the replacement task has nowhere to go. Sat
  `updating` / `update in progress` for **4.5+ minutes** at a healthy-looking `3/3` while serving the old
  build. ⭐ **Exact mirror of C6a**, which read `4/3` because the cap was unset. ⚠️ Capricorn is NOT exposed
  (all four services measured at `maxPerNode=0`).
- **`docker service update --force` restarts the OLD build and prints `converged`** (P55 ✅). This also
  **corrected a FALSE claim in `COMMANDS.md`**, which said `--force` would ship whatever `:latest` points at.
- 🚨 **Two builds served from one URL** (P58 ✅): a registry blip during a deploy **strips the digest**
  (P57 ✅), after which each node resolves alone. Measured `3/3`, `UpdateStatus: completed`, and **10 of 30
  requests served v3 while 20 served v4**.
- **P56 ❌ REFUTED:** `--resolve-image never` **preserves** the pin. ⭐ A pin is stripped by a resolution
  that is **attempted and fails**, never by one that is skipped.
- **P59 ✅** the protective face: with the pin intact, a killed task's replacement came up **v4, not the v5
  in the registry**. Same mechanism as P55, opposite consequence.

**Scored P54–P61 (2 wrong, and the wrong ones taught more), 10 findings C7-F1–F10, ledger L23.** Cleanup
done and verified: stack/images/rig/`/etc/hosts` removed, `.191`'s registry credential **restored and
confirmed to belong to `swarm-lab-pull`** (root login had overwritten it — one credential per registry host
per node), and the throwaway GitLab container repository **destroyed** (0 remaining).
Raw evidence: `education/docker-swarm/scratch/c7_evidence.txt`; rig in `scratch/c7/`.

### ✅ CLOSED — the C4 fix is verified, not recited (P48 + P50, 2:40–2:48 PM)

Both previously-unexecuted paths have now run against a genuinely degraded cluster (`qm stop 193`, chosen
because it hosts no pinned service, so the app stayed healthy and the variable stayed isolated):

- **P48 ✅ precondition.** Pipeline failed in **3 s** naming `docker-swarm-3(Down/Active)`, vs **5 min 10 s**
  and a *wrong* answer pre-fix. `docker login` never ran — a refused deploy touches no credential.
- **P50 ✅ counting**, through `ALLOW_DEGRADED=1` by hand on `.191`, phantoms confirmed present **first**
  (`backend 3/2`, `frontend 5/3` — one ghost and two, reconciling exactly against task placement):
  `all services converged`, all three smoke gates, `total=682`.

🚨 **Two findings worth carrying, both bigger than the bug.** (1) **The precondition made the counting fix
unreachable** — it halts upstream of the poll in exactly the scenario the poll was written for; ⭐ *an early
guard can render a downstream path untestable*, which is the better reason the escape hatch exists.
(2) **The old logic would have spent 300 s reporting a FAILED DEPLOY on a demonstrably healthy application**
— the smoke gates in the same run are the ground truth. A false red, in our own tooling, for a day.
⭐ **Our poll now disagrees with `docker service ls` on purpose and is right to** (`3/2`/`5/3` vs `2/2`/`3/3`):
`Replicas` counts tasks Swarm cannot confirm dead; we count tasks Swarm still wants alive.

Raw logs: `scratch/c4_job_log_p48_degraded.txt`, `scratch/p50_allow_degraded_converged.txt`.

### ✅ CHAPTER 3 IS COMPLETE (3:2x PM) — incident written up, figure 2, highlight pass, docx

- **§7 retitled** "One node, three lies: a false count, a broken checker, and a deposed leader" — the old
  title stopped describing the section once the restart incident went in. Four new subsections cover the
  blind spot, the term/index mechanism, why doing nothing was right, and the advisory fix.
- **Figure 2** `ch03_fig2_term_inflation` — the disruption loop. ⚠️ **Sizing is not free-form:** `figcheck.py`
  enforces ≥10pt rasterised, and the build scales every figure to the 7in box, so **raw aspect ratio sets
  the font size**. One column = 8.7in tall (overflows); one row = 18in wide (4.2pt); two pairs on shared
  ranks = 9.0pt (rejected). One shared rank landed it at **12.5pt**. All 8 track figures now pass.
- **Highlight pass DONE** — 113 marks, **16.7%** of prose. Anchors: `scratch/ch03_anchors.py`.
  ⚠️ **Never re-run `highlight.py` on this file.** A first pass hit 22.9% because anchors were whole
  sentences; ⭐ *marking a whole sentence defeats the purpose — if everything is marked, nothing is*, so
  they were cut to the operative clause. Multi-line anchors work (the markdown is hard-wrapped).
- **docx rebuilt** and verified inside the zip: 249 `Key` runs, both figures embedded, footer present,
  **zero literal `custom-style` leakage** into body text.
- **Corrections made in the same pass:** a stale `(§6)` cross-reference that should have been `(§7)`, and
  `COMMANDS.md`'s claim that the "swarm does not have a leader" message can be trusted — today it appeared
  with **quorum fully intact**, so §9 now has a subsection on diagnosing it from a *different* node.

### 🔲 Found while doing this: the Swarm track never got a real highlight pass

| Track | Marks per chapter |
|---|---|
| `k8s-k3s-redpanda` | 33, 38, 39, 42, 45, 45, 103 — a real ~15% pass |
| `docker-swarm` | **5, 5, 6, 6, 5** (ch1, 2, 4, 5, 6) — incidental marks only, not a pass |
| `docker-swarm` ch3 | **113** ✅ (done today) |

⭐ Chapter 3 is now the only Swarm chapter that can be revised from its marks. The other five need anchor
lists (~40 each). Not urgent, but it is an inconsistency inside one printed track, and the anchor lists live
in gitignored `scratch/`, so they are not recoverable from a clone — see the accepted debt note in
`CONVENTIONS.md`.

### 🔲 Also open, smaller

- **Unmeasured: did unpinned `redis` silently lose its volume during the C4 outage?** In the 2:07 PM dump
  `capricorn_redis.1` was `Running` on `docker-swarm-2`, started ~2h earlier, i.e. right at the outage. If
  it was on `.191` before, it rescheduled onto `.192` against a **fresh empty local volume** — trap C3's
  mechanism, occurring for real, unnoticed, inside a different drill — and **two divergent volumes now
  exist**. Check: `docker volume ls` on both nodes, `redis-cli DBSIZE`. **Do not write it up until
  measured.**
- **Untested by design:** the rigorous settle-delay variant (compare each service's `.Version.Index`
  across the deploy, trust `UpdateStatus` only for services whose index moved). → Phase 17.
- **No snapshot was taken today.** Andrew declined `s07-c4-fixed`; the chain is still `s01→s06`. `s06`
  predates the C4 fix, so rolling back loses it.
- 🔲 **Unchanged from before:** **GitHub push held** (chapters unreviewed + the redaction question below);
  the two app-repo findings (bootstrap committed-delete; unauthenticated destructive endpoint —
  `working/`); **Part 7 Swarm↔K8s crib sheet** (now the last substantive Phase 16 item);
  `docker-admin.sh` design session (COMMANDS.md §11 is its spec).

⚠️ **Decision deferred, do not lose it:** L19/L20/D6 (and now L21/L22) in
`phases/phase16_docker_swarm.md` describe a working attack path on the lab in tracked, GitHub-bound files.
Andrew's call (Aug 19) was **"deal with it at GitHub-push time, in one review pass with the chapters."**
`push_github.sh` cannot catch this — its gates look for key blocks and passwords-in-URLs, not prose.
**No secret VALUES are in tracked files.**

**Lab state (verified by the 2:14 PM pipeline, from the cluster):** all three nodes up, stack
`2/2 3/3 1/1 1/1`, **682 rows**, all three smoke gates green. `.191` was stopped and restarted today, so
**the leader has moved — do not assume `docker-swarm-1`** (it went to `.193` during the outage; leadership
is not sticky, now observed four times). `/home/agamache/swarm-ci/{scripts,manifests}` exists on `.191`
**and `.192`** (both have been deploy targets). Old temp files `/tmp/capricorn.c6*.yml`,
`/tmp/c6b_probe.log` on swarm-1 are harmless, but `STACK_FILE` must be unset for a normal deploy.

---

## 📦 DEMOTION LOG — Aug 24 + Sep 16, 2026 (ONE block, on purpose — append a ROW, never a block)

⚠️ **This block exists because the first four demotions each left a marker block behind, so the block
count sat at 34 while 300+ lines left the file.** A per-demotion note is the obvious thing to write
and it quietly defeats the metric the whole exercise is gated on. ⭐ **If your cleanup emits one
artefact per unit of work, the artefacts become the backlog.** One log, appended to.

| Demoted from here | Lines | Went to | Salvaged because it was nowhere else |
|---|---|---|---|
| `Key Achievements`, `Previous Sessions`, `Next Steps`, `Quick Reference`, `Blockers` | 57 | `phase5`, `phase4` | Dec 13 2025 runner install + socket mount; **DEV/QA/GCP environment definition**; Jan 8 2026 repo publish; Prometheus/Grafana never built |
| `✅ Phase 7 COMPLETE` + `🌐 Phase 7 … ARCHIVED` | 233 | `phase7_local_www.md` | 5 commit SHAs; the **two manual deploy buttons** decision |
| `✅ Completed This Session (Jan 12-13)` | 32 | `phase6_sonarqube.md` | First-scan baseline (**86 LOC / 28k LOC**); the `9.9.8→26.1.0` **database wipe** invalidating every prior token |
| `✅ Completed Previous Session (Jan 11)` | 51 | `phase5_ci_cd_pipelines.md` | **`prod`→`qa` refactoring**; **`.gitignore` blocking `lib/`**; branch strategy; the 11-issue list |
| `✅ COMPLETE: Phase 5` (status stub) | 7 | — | nothing; `phase5` covers it |
| `🔥 Critical Incident: Proxmox Kernel` | 9 | — | nothing; it was **already just a pointer** to `phase1a`/`phase1b`, both referenced from `MEMORY.md` |
| **Sep 16, 2026 pass ↓** | | | |
| `🎯 Infrastructure Optimization` (Jan 12) | 39 | `phase1_proxmox.md` | Copied verbatim. 🚨 Its `cache=writeback` is **superseded and incompatible with `aio=native`** — the standard is `cache=none`, and the destination now warns before the quote |
| `🔐 Password Security Cleanup` (Jan 13) | 52 | — | nothing; every live rule verified present in `MEMORY.md` string-by-string. **SHAs preserved here instead:** `c71ef79`, `ad74d99`, `899d5c1` |
| `✅ COMPLETE: Phase 6 - SonarQube` (stub) | 9 | — | nothing, and it was **wrong twice**: `.183` at 8 GB (it has 12) and *"Next: Phase 7 (Monitoring)"* — Phase 7 was the WWW server, Monitoring never built |
| `📋 Documentation Verification` (Jan 14) | 59 | `phase1_proxmox.md` | Copied verbatim; drive serials already in `phase0`. Kept its 4 SHAs and the *rpool compression was an install mistake* story. Pool numbers flagged as a dated reading |
| `SSH Key Auth + Cursor Sandbox` (Feb 27) | 30 | `phase2_host_setup_automation.md` | 🚨 **`fix_cursor_sandbox.sh` is in NO commit and NO file** — this block was its only record in the project. Salvaged. SSH half was covered by the ACCESS MATRIX |
| `🧹 MEMORY MAINTENANCE` (the Aug 24 handoff) | 92 | — | nothing; its six durable rules verified present across `MEMORY.md` and `MAKE_MEMORIES`. **Superseded by the Sep 16 handoff** — this file holds ONE |
| **Sep 16, 2026 pass 5 ↓** | | | |
| `Parallel VM Refresh Script + GitLab Runner GPG Key Fix` (May 23) | 88 | — (2 lessons PROMOTED to `MEMORY.md`) | 🚨 **Two real findings existed nowhere else and were promoted, not filed:** bash iterates an **associative array in HASH order**, which is why the script uses sentinel files rather than a `wait` loop; and **packagecloud repos re-issue the SAME keypair** with a later expiry, so `EXPKEYSIG` means a stale local copy, not a replaced key. Everything else was already in `MEMORY.md` → REFRESH SCRIPT and GITLAB RUNNER |
| `refresh made detach/reattach-safe with tmux` (June 18) | 74 | — (1 procedure PROMOTED to `MEMORY.md`) | 🚑 **The GitLab safe-reboot checklist existed nowhere else** — dpkg lock free, no apt/dpkg/gitlab-ctl procs, Sidekiq drained, no background migrations, then `init 6` and verify `/-/readiness`. ⭐ Kept because **a successful upgrade that never rebooted looks like success in the log and failure in `uptime`.** Also folded the three tmux deb names into the existing dpkg-workaround note. Everything else was already in `MEMORY.md` → REFRESH SCRIPT |
| `Proxmox kernel upgrade 6.17.13-13 + PVE 9.1→9.2` (June 18) | 51 | — | nothing; `phase1b` holds the full procedure and its same-day follow-on, `MEMORY.md` holds current state and history. 🚨 **Priority because it MISLEADS, not because it is old:** it declared *"deliberately NOT booting 7.0.6-2"* and *"a host reboot is recommended (deferred)"* — both superseded, since the host went 7.0.6-2 then **7.0.14-4** and rebooted long ago. **A spent directive in a history log is worse than a stale fact** |
| `Tested + adopted kernel 7.0.6-2-pve` (June 18) | 21 | `phase1b` (verbatim) | ⭐ **`phase1b` held the PLAN and approval and never the OUTCOME** — it read as an unexecuted proposal for 3 months. Also: plan targeted `6.17.13-13`, reality adopted `7.0.6-2`; now superseded by `7.0.14-4`. **The procedure transferred, not the version** |
| `GitLab VM backups → NAS` (June 18) | 20 | `phase8_backups.md` (verbatim) | 🚨 **Closed TWO TODOs completed in July and never marked done** — the VMID-999 restore drill, and the deferred guest agent. **Verified against the host:** `qm config 181` → `agent: enabled=1`, so the nightly backup is **app-consistent, not crash-consistent**. ⚠️ A TODO that outlives its completion invites redoing the work |

| **Sep 17, 2026 pass 9 ↓** | | | |
| `Dual-remote (GitHub-safe / GitLab-full) + secret scrub` (June 18) | 86 | `phase3_gitlab_server.md` (verbatim) + 1 item PROMOTED to `MEMORY.md` | 🚨 **The leaked master password was NEVER ROTATED, and this block was the only record of it.** `MEMORY.md` said history had been purged, which reads as remediated — a purge is not a rotation, and GitHub can retain orphaned commits by SHA. Promoted to *Secret hygiene*. Also salvaged: `push_github.sh`'s gate was **proven** with a fake `_gatetest.key`. ⛔ **Nothing deleted on coverage grounds** — all eight governing rules were hand-verified in `CURSOR_RULES`, but see the finding below about the tool |

| `📌 Stage 0 record` (created THIS session) | 277 | `phase18` + `phase17` (verbatim, split at the Phase 17 boundary) | 🚨 **Nothing — this block should never have existed.** Rewriting the `RESUME HERE` heading on Sep 17 pushed the old content down under a NEW `##` heading, taking the count **19 → 20**. ⭐ **The process's own operator added backlog while running the process**, so it was cleaned up in the same pass rather than deferred. ⛔ **Watch for this when editing a block's HEADING: replacing a heading is safe, adding one below it is a demotion you now owe** |

| **Sep 23, 2026 pass 10 ↓** | | | |
| `✅ DONE — Phase 12: Network Perimeter Lockdown` (July 8) | 61 | `phase12` (verbatim) | Nothing promoted — every live fact was already in `phase12` and `MEMORY.md`. 🚨 **Its closing "DECISIONS AWAITED" list was SPENT** — all four decided and built the same day — so the copy is flagged at the top; **a spent to-do invites redoing finished work.** ⚠️ **The coverage check was first run with `\|` inside `grep -E`**, which searches for a literal pipe, and reported three false zeros — the same bug pass 9 recorded. Rerun with `|` |
| **Sep 28, 2026 pass 11 ↓** | | | |
| `📘 SESSION Sep 23, 2026` (handoff) | 44 | `phase18` (verbatim) | Replaced by the Sep 28 handoff. Nothing promoted — its corrections (50 s, 16 vs 64) and B9 were already in `phase18`/`MEMORY.md`. ⚠️ Its "no new kernel has landed" was already false (142 landed Sep 25) — flagged in the copy |
| `✅ Phase 13: Proxmox Host Audit + Same-Day Fixes` (July 9) | 57 | `phase13` (verbatim) | Nothing promoted — email alerting, ARC cap, rpcbind, SEC-1/2 deferral all already in `MEMORY.md` (hand-checked, positive control `7.0.14-4`). 🚨 **Its Next-steps list was SPENT** and it claimed the host had no workstation key (false since Aug 12) — flagged in the copy |
| `✅ Phase 13 (continued): Afternoon Session` (July 9) | 43 | `phase13` (verbatim) | Nothing promoted (hp-bioscfg, ashift, 2x12, WON'T-FIX all in `MEMORY.md`). 🚨 **FOUND A LAPSED TO-DO: 184's `pre_phase12_firewall` snapshot was never deleted** — 2½ months past its date. Raised with Andrew, not actioned |
| `✅ Phase 13 (final): Maintenance window` (July 9) | 16 | `phase13` (verbatim) | Nothing promoted (pin + nag fix in `MEMORY.md`). ⚠️ Its ESP-fallback line went stale TODAY — flagged in the copy |
| `✅ GitLab backup test-restore drill` (July 9) | 15 | `phase13` (verbatim) | 🔲 **Its cadence "repeat ~quarterly" had no due date anywhere** → next drill **~Oct 9, 2026**, now written into `MEMORY.md` |
| `✅ qemu-guest-agent rolled out to all 5 live VMs` (July 9) | 16 | `phase13` (verbatim) | Covered — nothing open. **All July blocks are now out of `current_phase.md`** |
| `🎉 ANDREW GOT THE JOB` (Aug 12) | 58 | `phase14` (verbatim) | COVERED — roadmap rule, chapter-7 rule and de-identification rule all hand-checked live in `MEMORY.md` (ll. 137/151/178). Audit also fixed two stale history rows: "19+" backlog → "20+" (Phase 19 is now storage tiers) and the Phase 16 row's purged snapshots |
| `✅ Phase 15 — The Education Program` (Aug 12–13) | 420 | `phase15` (verbatim) + 2 rules PROMOTED to `MEMORY.md` | 🚨 **Two live rules lived only here / deep in `phase14`:** track 1's `figcheck` exits 1 BY DESIGN (four accepted sub-10pt figures — a fresh session would "fix" it), and `qm set` on a running VM silently only stages a CPU/RAM change. Everything else COVERED (METHOD "Who does the work", CONVENTIONS chapter scope, CURSOR_RULES edu rule 6, CIFS audit regex at MEMORY l.44, SSH/Tailscale/remote runbook). Its Next list was SPENT — flagged in the copy |
| `🔵 ACTIVE: Phase 16 — Docker Swarm` (Aug 13) | 55 | `phase16` (verbatim) | 🚨 **Status was false:** "ACTIVE … Next: Part 2" six days after the phase closed — a fresh session reading top-down would resume finished work. All facts COVERED (38G-not-40G, `gsettings` desktop detection, `19x.fw` vs swarm ports, `s01-base-clean`, `provision_nodes.sh`) |
| `📘 SESSION Sep 28, 2026` (handoff) | 46 | `phase18` (verbatim) | Replaced by two later handoffs. Every live fact already COVERED (`--freeze-updates`, event-driven restore drill, STORAGE CHECK in CURSOR_RULES, `c01` rollback trap, kernel drill, UPS/NUT, `pve-host-config-backup`); its 🔲s were SPENT — flagged in the copy |
| `📘 SESSION Oct 27, 2026 — PVE 9.2.20 → 9.2.24` (handoff) | 30 | `phase1b` (verbatim) + 1 check PROMOTED to `MEMORY.md` | Superseded the same night by the Phase 20 handoff. 🚨 **The `vm-ephemeral` boot-import check (unproven until the next host boot) lived only here and in `phase19`** — promoted to the MEMORY Phase 19 row (commit 13c). Rest COVERED (`--next-boot` trap + pin-drop in `phase1b`/MEMORY, `--boot-check`, EDIT LOG 11 in CURSOR_RULES) |

⭐ **A THIRD FINDING, and it is a repeat this log had already warned about.** Pass 9 rebuilt an
automated coverage checker, validated it with a positive control (100% on a file searched against
itself), and got **2%** for this block — framing a safe demotion as archaeology. **The tool was not
broken; it was irrelevant.** A 9-word-overlap check measures STORAGE, and the knowledge lived in
`CURSOR_RULES` **paraphrased**. ⛔ **The positive control proves an instrument is not broken. It does
NOT prove the instrument answers your question.** ⚠️ **This log's pass-5 entry already said "a
verbatim-line check finds CANDIDATES, not verdicts" — and the lesson was re-derived anyway by
rebuilding the tool instead of reading the log.** ⭐ **Hand-verify facts one at a time; that check took
eight greps and gave a trustworthy answer.**

**Two findings from doing it, both in `MEMORY.md` → MEMORY MAINTENANCE:**
- ⭐ **A verbatim-line check finds CANDIDATES, not verdicts.** It flagged **86 of 173** Phase 7 lines
  as homeless; reading them left **six** real items. Acting on the 86 either way would have been wrong.
- ⭐ **Sort by how badly a block could MISLEAD, not by size.** The 57-line batch went first because
  three of those sections were *wrong* — a settled Prometheus-vs-Traefik choice presented as open, a
  VM table contradicting an explicit prohibition, and `ready for Phase 7` during Phase 17.
