# Current Phase

**Updated:** November 4, 2026 - 11:40 AM EST

📐 **Shape, and how to keep it:** `▶️ RESUME HERE` is the **first block** as of Aug 24 — it had been
at line 389 under six stale session blocks, so the one thing you must read first was the one you had
to scroll to find. **Keep it first.** Below it, newest session first. `MAKE_MEMORIES` step 0 now
counts blocks (spec: 2) and step 2 demotes at least one per pass, so this file drains instead of
growing — see that file for why the previous append-only version went undetected for seven months.

## ▶️ RESUME HERE — 🔵 **PHASE 18: THE CLUSTER EXISTS. STAGES 1 AND 2 ARE COMPLETE.**

🔐 **Nov 4, 2026 — A REAL PASSWORD WAS FOUND ON PUBLIC GITHUB, AND IS NOW REDACTED + GATED.** The NAS/SMB
password (= GitLab root, Phase 20 E7) sat in plain prose 7× in 4 tracked files, public since `46a01db`
(Aug 13). Redacted to `<value>`; **Andrew chose NOT to rotate** (lab-only, LAN-only) and not to purge;
`push_github.sh` **step 5** now blocks any known secret value. Detail: `MEMORY.md` → GIT → *Secret hygiene*.
🔓 The Aug 18 Swarm GitHub hold is **LIFTED** (Andrew, Nov 4) — L19–L22 stay public by decision; the
Capricorn endpoint specifics stay in gitignored `working/`.

🆕 **Oct 27 (late): PHASE 20 BUILT — Rancher on single-node K3s, VM 187 `.187`** — a separate track; it
does **not** touch the CKA cluster and does not change the Phase 18 next step below. Open items for Andrew
(log in, E7, delete the expired root PAT, D6) are in `phases/phase20_k3s_rancher.md` → 🔲 Open items.

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
only, then an offline `c03-equipped-cluster`. ✅ **Nov 4: Part 1 BUILT — metrics-server v0.9.0 via
Kustomize, x509 failure seen first, then fixed by a patch; `kubectl top` works** (`phase18` Chapter 05 plan,
item 1). ✅ **Nov 4: Part 2 BUILT — local-path-provisioner v0.0.37, now the DEFAULT StorageClass;
bind, survive-a-pod-delete and reclaim-`Delete` all proven** (item 2). ✅ **Nov 4: Part 3 BUILT — Gateway
API standard CRDs v1.6.3** (10 CRDs + a `safe-upgrades` admission policy; v1.6.3 because stable Traefik
v3.7.17 is built on it) (item 3). ✅ **Nov 4: Part 4 BUILT — Helm v4.3.1 on control-1 only, Traefik
chart 42.3.0 (v3.7.17) on NodePort 30080/30443; one Ingress and the same route as Gateway + HTTPRoute both
serving; upgrade + rollback drilled** (item 4). 🔲 **NEXT: Part 5, offline snapshot `c03-equipped-cluster`
on all five** (decide first whether the `hello` test objects stay in it), then the etcd `wal_fsync` p99
baseline before the first breaking drill. ⚠️ **Run every step on control-1** (`ssh agamache@192.168.1.201`) — the workstation has no kubeconfig.
🎯 **NEW Nov 4 — THE EXERCISE BANK: `education/k8s-cka-prep/exercises.md`.** Exam-shaped tasks (X01–X15 +
backlog) for a timed mock exam later. 🚨 **Every Stage 3 part adds at least one task before it is called
done** — rule and shape in `phase18` → § *EXERCISE BANK*.
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
target moved), PVE 9.2.24.** Record: `phase1b` → last section (that session's handoff block was demoted there too). ✅ Cluster 5/5 `Ready`, 39/39 pods after it.
⚠️ **Read the Stage 1 results block in `phases/phase18_k8s_cka_build.md` before touching this** — it
holds the corrections (kube-vip did NOT crash-loop; the Calico operator HARD-CODES
`192.168.0.0/16`; `node.spec.podCIDR` is inert; `RESTARTS 0` does not mean a static pod was
untouched).

## 📘 SESSION Nov 4, 2026 (10:57–11:50 EST) — back after 5 weeks: Ch 05 Part 1 built, exercise bank started

🙋 *"I'm back after a long time. where are we on phase18?"* → nothing had moved since Sep 23.

### ✅ Done
1. **Health on return (read-only):** pools rpool 3 % · vm-critical 9 % · vm-ephemeral 4 %, all ONLINE;
   cluster 5/5 `Ready` on kernel 142, 0 pods not Running; backups ran every night unattended — GitLab 7,
   critical 49 (7 VMs × 7), host-config 30 archives, newest Nov 4, **0 failed vzdump tasks since Sep 28**.
2. **Committed the Oct 28 session's leftovers** (`0af942d`, Phase 20 drill D5). `fin_tech_stack.txt` held
   back until Andrew de-identified it himself (Nov 4).
3. **Ch 05 Part 1 — metrics-server v0.9.0 BUILT by Andrew** (Kustomize; x509 seen first, then patched).
   Record: `phase18` Chapter 05 plan item 1; commands `COMMANDS.md` §13; files `manifests/ch05/metrics-server/`.
4. 🎯 **EXERCISE BANK started** (`education/k8s-cka-prep/exercises.md`, X01–X11 + 21 backlog) and its rule
   written into `phase18` § EXERCISE BANK: every Stage 3 part adds at least one exam-shaped task.
5. `MAKE_MEMORIES` pass 14: 9 → 7 blocks (14a Oct 27 handoff → `phase20`; 14b Phase 16 closed → `phase16`).
6. **Ch 05 Part 2 — local-path-provisioner v0.0.37 BUILT by Andrew** (made default; claim bound, data
   survived a pod delete, reclaim `Delete` removed the folder). Record: `phase18` Chapter 05 plan item 2;
   `COMMANDS.md` §13; `manifests/ch05/local-path/`; exercise X12. Committed `473d231`.
7. **Ch 05 Part 3 — Gateway API standard CRDs v1.6.3 BUILT by Andrew**; a Gateway with no controller shown
   sitting at `Unknown / Pending`. Record: `phase18` item 3; `COMMANDS.md` §13; `manifests/ch05/gateway-api/`; X13.
   Committed `1c1610e`; pushed GitLab then GitHub.
8. **Ch 05 Part 4 — Helm v4.3.1 + Traefik 42.3.0 BUILT by Andrew** (Ingress, then Gateway + HTTPRoute by hand;
   `allowedRoutes: Same` refusal seen; upgrade + rollback). Record: `phase18` item 4; `COMMANDS.md` §13;
   `manifests/ch05/traefik/`; X14, X15. Also fixed X11's verify (`grep -c` = 2, not 1).

### 🚨 Found
- **The password on public GitHub** (see RESUME HERE). Found while reading the next block to demote —
  🚨 **demotion stopped there on purpose**, because moving it verbatim moves the secret.
- **The Aug 18 "GitHub push HELD" for Swarm material was overtaken unrecorded** — `phase16` ledger L19–L22
  (attack-path prose) is public. 🔓 Andrew lifted the hold the same day (`MEMORY.md` beside the old note).
- 🤖 **The AI broke a host rule once:** wrote two temp files to `/dev/shm` on the dev box while verifying 14a
  ("NEVER write outside project directory on this host"). Deleted at once (verified 0 left); later checks
  used pipes only.

### 🔲 Open — for Andrew
- ✅ **Password: REDACTED + `push_github.sh` step 5 gate, proven on the real leak** (blocked → redact →
  pass). Andrew: no rotation, no purge. ✅ Swarm GitHub hold lifted — L19–L22 stay public.
- ✅ GitLab pushed (`dde819b`); GitHub after the redaction, with Andrew's go-ahead.
- 🔲 **Phase 18 next: Ch 05 Part 5, snapshot `c03-equipped-cluster`** (offline, all five, both layers), then the
  `wal_fsync` baseline, then write Chapter 05.
- 🔲 Carried: kernel drill (by ~end Dec); delete `rpool/ROOT/pve-1@pre-pve-9.2.20-2026-09-28` (host trial
  passed Oct 27) — ask first; Swarm chapter 8 — ask which Swarm features the new job actually uses;
  Sep 28 logs in `education/k8s-cka-prep/scratch/` (agreed: delete "next session" — ask).

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
| `📘 SESSION Oct 27, 2026 (22:00–23:10) — Phase 20` (handoff) | 30 | `phase20` (verbatim) | Previous session handoff. Open items all COVERED in `phase20` → 🔲 Open items (D6, root PAT, E7, token renewals) **except "Andrew: log in and look around" — added there**. Its "Not yet committed" study-track status was false since `427f22c` (Oct 28) — corrected in `phase20` line 5 |
| `🟢 PREVIOUS — PHASE 16 CLOSED (Aug 19)` | 197 | `phase16` (verbatim) + 1 flag PROMOTED to `MEMORY.md` | Oldest block. COVERED: provenance marks (`METHOD`/`CONVENTIONS`), empty 88 b redis volume on `.193`, `STACK_FILE`, swarm-does-not-rebalance, highlight per-section + bold-pair (`CONVENTIONS`/`highlight.py`), figure aspect ratio. Spent: the redis open item. 🚨 **The Aug 19 "deferred — review L19–L22 attack-path prose at GitHub-push time" lived ONLY here, and the trigger had already passed: those rows are on public `origin/main`, and no record lifts the Aug 18 hold.** Flag promoted to MEMORY; decision is Andrew's |
| `🔧 UNPLANNED INTERRUPT — QA server re-numbered 200 → 180` (Aug 20) | 116 | `phase5` (verbatim) | Oldest block; **safe to move only since the Nov 4 redaction** (it had held a real password). COVERED: 180-no-backup ruling, AUTOSTART POLICY, `.pw` format, `jobs.cfg` rule, Synology auto-block (MEMORY); `noserverino` (Storage doc). Its "exactly one scheduled job" paragraph is SUPERSEDED (Phase 19) — flagged in the copy |
| `🔧 BUILD STANDARD CHANGED — Cockpit is now on every Ubuntu server` (Aug 20) | 42 | `phase2` (verbatim) | COVERED: `setup_cockpit.sh` design + "fix the builder" lesson (MEMORY l.~1200, `phase2` §3). 🚨 Its "not yet proven" was SPENT (proven Phase 17 Part 0) and its `www/scripts/` paths stale since Aug 21 — both flagged in the copy |
| `🩹 LAB-WIDE nofail SWEEP + a security find on .184` (Aug 20) | 61 | `phase2` (verbatim) | COVERED: `--no-nas`, the `:445` pre-check, `sudo SKIP_NAS=1` (env_reset) gotcha, the bounded-delay correction, .184 no-NAS rule (MEMORY + `phase2`). 🚨 **Its open item "template 9000 not checked for a NAS fstab entry" had been open 76 days — CLOSED Nov 4 by reading the template disk read-only (`virt-cat`): clean.** |

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
