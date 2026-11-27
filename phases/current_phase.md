# Current Phase

**Updated:** November 4, 2026 - 1:40 PM EST

📐 **Shape, and how to keep it:** `▶️ RESUME HERE` is the **first block** as of Aug 24 — it had been
at line 389 under six stale session blocks, so the one thing you must read first was the one you had
to scroll to find. **Keep it first.** Below it, newest session first. `MAKE_MEMORIES` step 0 now
counts blocks (spec: 2) and step 2 demotes at least one per pass, so this file drains instead of
growing — see that file for why the previous append-only version went undetected for seven months.

## ▶️ RESUME HERE — 🔵 **PHASE 18, STAGE 3: exercise chapters 09+ (from `c03-equipped-cluster`)**

⛔ **Budget ≤ 6 KB.** State + next step + blockers ONLY. History goes to the phase file (`phase18`), not here.

🎯 **State (Nov 4, 2026; unchanged since):** 5-node kubeadm **v1.35.8** HA cluster, `.201`–`.205`, kube-vip VIP `.206`, Calico
v3.32.2, all `Ready`. Add-ons: metrics-server, local-path (default SC), Gateway API v1.6.3 standard CRDs, Traefik (Helm,
NodePort 30080/30443). **`c03-equipped-cluster` is the offline "READY" reset point** (all five nodes). Chapters 01–08 written;
`wal_fsync` idle p99 ≤ 128 ms baseline taken; exercise bank `education/k8s-cka-prep/exercises.md` (X01–X15 + backlog).

🔄 **Session start for Phase 18 work:** `bash education/k8s-cka-prep/scripts/lab_check.sh` (workstation; 422 checks vs `c03`,
names the lowest drifted layer). L4 drift → the exercise's Reset or `--clean`; L1–L3 → `scripts/reset_cluster.sh --check` then
`--yes` (≈ 250 s to `CLEAN`). ⛔ Never reset by hand; any new baseline snapshot ⇒ `lab_check.sh --record` straight after.

🔲 **NEXT:** exercise chapters **09 onward** (every Stage 3 part adds ≥ 1 exam-shaped task to the bank); coverage matrix before the
first mock exam. Rule for Stage 3: *does the exam test it, and is this the simplest way to practise it?* Original tasks only —
never exam / Killer.sh content.

🧭 **How Andrew and the AI work here (phase18 §12):** commands go to Andrew as a separate `ssh` block FIRST; on "check", read his
terminal file. Run every step on **control-1** (`ssh agamache@192.168.1.201`) — the workstation has no kubeconfig.
**CKA work pushes to BOTH remotes, GitLab first** (still ask).

🔲 **Carried / due:**
- **Node patching drill due ~Nov 27 – Dec 27** (60–90 days from the Sep 28 update freeze); step 0 is `sudo apt update`.
- `vm-ephemeral` boot-import check at the next HOST reboot: `journalctl -b -u 'zfs-import@vm\x2dephemeral'` (unproven).
- Swarm chapter-8 conversion is DEFERRED — ask which Swarm features the new job actually uses.
- Phase 20 open items for Andrew: log in, E7, delete the expired root PAT, D6 (`phase20` → 🔲 Open items).
- Sep 28 `move-20x.log` files in `education/k8s-cka-prep/scratch/` — agreed: delete, **ask first**.
- `script-server.service` (Nov 22) is **not proven across a reboot** — `journalctl -b -u script-server` after the next one;
  also test `http://192.168.1.195/files/` from a second machine.

🔐 **Standing:** a real password sat on public GitHub until Nov 4 (redacted, **not rotated** — Andrew's call); `push_github.sh`
step 5 now blocks known secret values. 🔓 The Aug 18 Swarm GitHub hold is lifted (L19–L22 are public by decision).

📌 **Where the rest is:** `phases/INDEX.md` (area → file). Cluster build record, Stage 1–2 results, the four corrections that
mislead, `c01`/`c02`/`c03` rules and the etcd/backup finding are all in `phase18`.

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
| `🔵 PHASE 17 PARTS 0 + 1 — Jenkins is up` (Aug 20) | 38 | `phase17` (verbatim) | COVERED: J-P2…J-P5, `j02-jenkins-up`, ledger J2, the trap protocol (all in `phase17`); no-chapter-0 rule and patching policy in MEMORY. Its "✅ DONE" heading is true for Parts 0–1 only — the phase is paused, flagged in the copy |
| `🔧 BUILD STANDARD OVERHAUL — a second distro, and the script server nearly deleted itself` (Aug 21) | 50 | `phase2` (verbatim) + 1 caveat PROMOTED to `MEMORY.md` | COVERED: tree rename + 301s, landing page, `--hostname`, `www/smb_credentials`, the self-eating `wget -O` + atomic `.part`, "a 301 is a promise" (MEMORY l.~1698, `nginx.conf`), `.185` autoremove declined. 🚨 **"`--server` success path unproven on real hardware" lived ONLY here and is STILL TRUE** (no Ubuntu/Fedora host built with `host_setup.sh` since Aug 21) — promoted. **Last pre-Sep block: the file is now RESUME + one handoff + this log** |
| **Nov 24, 2026 pass 16 ↓** | | | |
| `📘 SESSION Nov 4, 2026` (handoff) | 67 | `phase18` (verbatim) | Replaced by the Nov 22-24 handoff. Nothing promoted - all facts already in `phase18`/`MEMORY.md`. 🚨 **Its 'delete the pve-1@pre-pve-9.2.20 snapshot - ask first' was SPENT: the snapshot is already gone** (host check Nov 24, positive control 34 snapshots / c03 x5); `MEMORY.md` and `phase18` still said 'kept' - corrected. Its other 🔲s carried into the new handoff |
| **Nov 27, 2026 pass 17 ↓** | | | |
| `📘 SESSION Nov 22–24, 2026` (handoff: `/files/` + boot order + MEMORY DIET) | 72 | `phase2` (verbatim) | Replaced by the Nov 27 handoff. Nothing promoted — `/files/` + unit rules already in `MEMORY.md` §3 + `phase2` SCRIPT SERVER; diet numbers in `MAKE_MEMORIES` backlog. 🚨 **Its reboot-proof item looked SPENT (`uptime -s` = Nov 23) and was NOT** — the boot journal shows the boot predates the unit; a clock jump. Carried. ⭐ Check the boot journal, not `uptime` |

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
