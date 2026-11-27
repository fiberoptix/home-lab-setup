# Archive of MEMORY.md material that is history, not rule (index intro, status bullets, phase table, maintenance notes)

Topic reference (not tied to one phase). Loaded ON TOUCH via `phases/INDEX.md`. Blocks below are copied VERBATIM from `MEMORY.md` as of tag `pre-memory-diet` (Nov 24, 2026).

---

## COPIED VERBATIM FROM `MEMORY.md` @ `pre-memory-diet` (lines 60–73) — Nov 24, 2026 (memory-diet, copy-first) — PHASE INDEX intro

## 🗂️ PHASE INDEX — what is NOT in this file, and when NOT reading it makes you WRONG

**This file holds project-wide facts and prohibitions. The working record — decisions, drills, raw
evidence, prediction logs — lives in phase files.** ⭐ The whole corpus is only ~13k lines, so
`rg '<topic>' phases/` is faster than reading any one of them. **Grep first, then read the hit.**

🚨 **The trigger discipline, because a pointer you skip is worse than no pointer at all** (a big
MEMORY fails safe; a skipped pointer makes you *confidently* wrong): **the first time in a session you
touch an area, read its file and SAY IN YOUR MESSAGE which files you read.** A claim you have to write
down is one Andrew can check. ⚠️ **This exact failure happened twice on Aug 19, 2026** — a diagnosis
built on a log window that had already closed, and observations written up from a *summary* that
claimed the evidence had been provided. **Treating a reference to evidence as the evidence is the
house failure mode. Do not do it.**

---

## COPIED VERBATIM FROM `MEMORY.md` @ `pre-memory-diet` (lines 92–117) — Nov 24, 2026 (memory-diet, copy-first) — PHASE INDEX tail: 2026-08-20 demotion table


⚠️ **`phases/current_phase.md` is the session log (2067 lines).** Read the **`▶️ RESUME HERE` block**
for state and next steps; `rg -n '^## ' phases/current_phase.md` maps it — **never trust a line number,
they drift every session.** Read below that block ONLY to answer a specific question about a past
session. The rest is history the phase files also carry.

📉 **Aug 20, 2026 — three demotions took this file 3797 → 2067 (−1730, the largest reduction yet):**

| Moved | Lines | Into |
|---|---|---|
| Eight stacked Phase 16 session handoffs | 786 | `phase16_docker_swarm.md` → *SESSION HANDOFFS* |
| Phase 14 closing record | 478 | `phase14_k8s_redpanda_poc.md` → *CLOSING RECORD* |
| Six OpenClaw run/repair logs + Phase 11 completion | 471 | `phase11_openclaw.md` → *OPERATIONAL LOG* |
| OpenClaw build record (gateway config, upgrade traps, SSHFS, firewall) | 151 | `phase11_openclaw.md` → *DEMOTED VERBATIM FROM `MEMORY.md`* — moved Aug 20, 2026, **first time this file lost a whole `##` section** |
| **Phase 14 CURRENT STATE block (k3s + Redpanda POC)** | **331** | `phase14_k8s_redpanda_poc.md` → *DEMOTED VERBATIM FROM `MEMORY.md`* — Aug 20, 2026. ⭐ **The demotion that finally made `MEMORY.md` shrink: 2414 → 2098.** A closed interview-prep phase was holding 14 % of the always-loaded file while its subject is out of scope. **44 distinctive strings existed ONLY in the `MEMORY.md` copy**, so it was copied verbatim, not summarised |

⭐ **Every one was copy → verify → delete, one block per commit**, and a line-by-line diff check
confirmed **0 removed lines missing** from the target each time. ⚠️ **All three were ~0% duplicated —
`current_phase.md` held the ONLY copy**, so a straight delete would have destroyed them. **Always run
the duplication check before assuming a phase file "already covers it."**

⭐ **The rule that made this necessary and is easy to let slide: `current_phase.md` holds ONE handoff.**
It had been accumulating since Aug 13. **When you write a new handoff, move the old one out.**

---

---

## COPIED VERBATIM FROM `MEMORY.md` @ `pre-memory-diet` (lines 1086–1103) — Nov 24, 2026 (memory-diet, copy-first) — CURRENT STATE: Jan-Feb status bullets (stale)

- **GitLab CE LIVE at http://192.168.1.181** (root/[See PASSWORDS.md])
- **GitLab Runner LIVE at 192.168.1.182** (gitlab-runner-1, **v19.2.1** as of a job log Aug 19, 2026 —
  Phase 4 installed **v18.7.2**, so the runner has been upgraded underneath us, presumably by apt.
  ⚠️ Version drift in a CI executor is worth noticing: it is a component whose behaviour our pipelines
  depend on, upgrading itself without a decision or a record.)
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

---

## COPIED VERBATIM FROM `MEMORY.md` @ `pre-memory-diet` (lines 2333–2361) — Nov 24, 2026 (memory-diet, copy-first) — PHASES history table

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
| 14 | Kubernetes + Redpanda POC (was interview prep) | ✅ **CLOSED Aug 12, 2026 — goal met: the interviews happened Aug 6/7 and Andrew got the job.** Parts 1–6 done, 7 chapters written. VM 186 right-sized to 8 vCPU / 16 GB and left at snapshot `s05-app-running`. **Do not extend it**; Ch8–10 are track-1 education work, not phase 14. |
| 11 | OpenClaw AI Agent | ✅ COMPLETE Feb 20, 2026 → ⛔ **RETIRED AND DESTROYED Aug 19, 2026.** VM totally gone, no backup. VMID/IP reused by Phase 17 |
| 15 | Education program — multi-track study repo | ✅ **Parts A–D COMPLETE Aug 12, 2026.** `education/` is now a shelf: one folder per track, shared `tools/`, `CONVENTIONS.md`. One item open — the `docker-swarm` row in `education/README.md`'s track table, held until the folder exists. |
| 16 | Docker Swarm (education track 2) | 🟢 **COMPLETE — ALL 7 PARTS, ALL 7 TRAPS CLOSED (Aug 19, 2026); 8 chapters written.** VMs 191/192/193 from template 9000; three-manager swarm, quorum 2 of 3; snapshots `s01-base-clean` → **`s07-c4-fixed-verified`** (⭐ **`s07` is the FIRST snapshot containing the C4 fix — `s06` predates it**). CI deploys the stack from GitLab; **C1–C5 fired, C6/C6b closed, C7 run Aug 19**; C4 fixed and VERIFIED against a degraded cluster (P48+P50). 🤖 **C7 + chapter 7 were AI-EXECUTED at Andrew's written instruction — declared in the chapter and the README, and deliberately marked WEAKER than chapters 1–6, which he drove.** **Part 7 closed as chapter 8 — the Swarm↔Kubernetes crib sheet, every row marked S / K / 🤖 / ⚠️ recited so nothing recited can be quoted as experience.** ⭐ Its two non-obvious conclusions: **the PVC abstraction is not what protects data** (the k3s lab's `local-path` strands it identically — the value is the driver ecosystem, not the object), and **Swarm's digest-pinning default is the SAFER of the two image models.** **🟢 CLOSED Aug 19, 2026 — nothing outstanding.** Drill D ran Aug 18 (P30/P31 ✅), the highlight pass finished Aug 19 (all 15 chapters, both tracks, 19.5–21.2 %), and the last open measurement — the `redis` divergent-volume question — was made and **refuted** (the two volumes are trap C3's deliberate residue). 🚨 **Its transferable lesson: `docker service ps`'s `CURRENT STATE` age is the manager's last STATUS STAMP, not the task's age** — it moves on control-plane churn, so a day-old task presents as freshly rescheduled, which manufactured a fictional data-loss incident until measured. ⚠️ **Standing hazard, recorded not fixed: an empty 88-byte `capricorn_redis_data_swarm` sits on `.193`** — `redis` scheduling there attaches an empty cache. 🙋 Andrew drives by default (`education/METHOD.md` → "Who does the work"). Re-walk the `📌 READ THIS FIRST` pre-flight list in `phases/phase16_docker_swarm.md` each session. 🔄 *Snapshots `s01`–`s07` were PURGED Sep 28, 2026 (Andrew, Phase 19); the only one now is `baseline-2026-09-28`.* |
| 17 | Jenkins (education track 3) | ⏸️ **ON HOLD since Sep 16, 2026 — Parts 0–3 DONE, resume at Part 4 (deploy to the Swarm).** Jenkins is live on `.185` and a `git push` builds it unattended; chapters 1–3 are written and built. **Paused for a new project, NOT closed** — hard rules B10/B11 bind, traps T1–T8 stay unfixed, and `.185` keeps running. ⚠️ Both registry tokens expire **2026-12-31**, so resuming after that starts with two dead credentials. |
| 18 | **Kubernetes HA + CKA prep** (education track 4) | 🔵 **BUILT Sep 17, 2026 — Stages 0–2 complete, Stage 3 open; Ch 05 add-ons built + `c03-equipped-cluster` Nov 4.** `phases/phase18_k8s_cka_build.md`. A 5-node **`kubeadm` v1.35.8** cluster (3 control planes w/ stacked etcd + 2 workers) at **VMIDs 201–205 → `.201`–`.205`**, **kube-vip VIP `.206`** (no VM behind it), CNI **Calico v3.32.2**. Upgrade to v1.36 is a planned drill. ⛔ **`.186` (k3s) is FROZEN and is not part of it.** 🔻 *Until Sep 28 this row still showed the Sep 16 DRAFT — v1.36.4 and a reservation of `.187`–`.190`/`.194`/VIP `.196`. That reservation was NEVER used; those addresses are not held by this phase (sweep before allocating anything, as always). The PHASE INDEX row at the top of this file is the current one.* |
| 19 | **Storage tiers** (infrastructure) | ✅ **OPENED AND CLOSED Sep 28, 2026.** `phases/phase19_storage_tiers.md`. Both VM pools thin; k8s 201–205 moved to the mirror with snapshots (`zfs send -R`); `critical-nightly` backup job + `nas-critical` storage; hourly capacity email; Swarm `s01`–`s07` purged → `baseline-2026-09-28`; restore drill passed. Tier rule: rebuildable → `vm-ephemeral`, otherwise `vm-critical` + nightly backup |
| 20 | **Rancher on single-node K3s** (infrastructure / work evaluation) | 🔵 **BUILT Oct 27, 2026.** `phases/phase20_k3s_rancher.md`. VM 187 `.187`; K3s v1.35.9, Rancher 2.15.2, cert-manager v1.21.3, rancher-monitoring 110.0.2; Fleet GitOps from GitLab `production/rancher-k3s`. Drills D1–D4 done, D5 measured Oct 28 (1 GB/day; 7-day window governs, ~6–8 GB steady state, 15 GiB cap never reached), D6 when a newer Rancher exists. CKA cluster deliberately NOT imported. Study track `education/rancher-k3s/` (5 ch., 🤖 AI-executed) written Oct 27 |
| 21+ | Remaining study list | 💭 **Backlog, worked STEP-BY-STEP in its stated order** after Phase 18 (numbered 20+ until Oct 27, 2026, when Phase 20 became the Rancher phase; 19+ until Sep 28, 2026, when Phase 19 became the storage-tiers phase) (was "after Jenkins" until Sep 16, 2026 — inserting Phase 18 moved the boundary): OpenSearch + Dashboards → Prometheus + Grafana → Redpanda Connect + Debezium CDC → MongoDB + Postgres → SAML/OIDC (authentik) → Ansible. Source of truth is `education/fin_tech_stack.txt`; do not re-derive priorities. |

**Phase docs:** `/phases/`

---

---

## COPIED VERBATIM FROM `MEMORY.md` @ `pre-memory-diet` (lines 2728–2806) — Nov 24, 2026 (memory-diet, copy-first) — MEMORY MAINTENANCE + REFERENCE INDEX

## MEMORY MAINTENANCE — why the demotion step never ran (Aug 24, 2026)

`current_phase.md` is specified to hold **one** `▶️ RESUME HERE` block at the top and **one** session
handoff. On Aug 24 it held **39 blocks**, 21 dated January-July, with `RESUME HERE` at **line 389**.
Its line count had gone **2067 → 2444 over twelve consecutive commits without a single decrease** —
the same runaway this file had in June, and the demotion step added then was supposed to prevent it.

**It ran every session and could not see the breach.** Fixed in `MAKE_MEMORIES`; three rules survive
the specific file:

- ⭐ **If a spec states a number, MEASURE THAT NUMBER.** Step 0 measured *lines* while the rule was a
  *block count*. A proxy stood in for the spec, and **2444 lines reads as a big file rather than a
  violated rule** — the number was honest, reported every session, and carried no signal. A file with
  a countable rule and no count of it is unenforced no matter how diligently something adjacent is
  measured. Same shape as *probe the capability you are about to use, not a proxy*.
- ⭐ **A process step whose trigger is an OPINION is an optional step.** The trigger was "whenever the
  size report makes you wince". It never fired once in seven months, and not through laziness:
  wincing is a judgement, judgement is the first thing a session under time pressure spends, and the
  cost lands on a *later* session. **Every individual skip was locally reasonable.** Gate anything you
  want to happen reliably on something a script can print.
- ⭐ **A line-level coverage check finds CANDIDATES, not verdicts.** Demoting the Phase 7 blocks, a
  verbatim comparison flagged **86 of 173 lines as having "no home"** — reading them showed almost all
  were prose restating facts `phase7_local_www.md` gives in different words, and the real residue was
  **five commit SHAs and one sentence**. ⚠️ Ask *"is the knowledge preserved somewhere appropriate?"*,
  not *"is this text duplicated?"* — those give **opposite** answers. The Phase 15 block reads as
  320/320 lines missing, yet its load-bearing content was already in `education/METHOD.md`.
  And **validate the tool before trusting it**: the first version of that check reported 100% missing
  because it stripped markdown from the search key but not the searched file, caught only by a
  positive control that found 7 of 25 of a file's own lines.

📌 **Sort demotions by how badly a block could MISLEAD, not by size.** The first pass took the five
trailing template sections — `Next Steps` still offering a Prometheus-vs-Traefik choice settled in
January, a `Quick Reference` table naming `.180` "QA/K8s" against an explicit prohibition in this
file, `Blockers: ready for Phase 7` during Phase 17. Small, and the only ones that could be *acted on*.

---

## REFERENCE INDEX — ⛔ NOT a boot list. `CURSOR_RULES` decides what loads when.

🔻 **Retitled Aug 24, 2026. It was called `FILES TO READ`, and that title was actively dangerous.**

**What was wrong:** this section listed **eight** files with **`PASSWORDS.md` as item 1**, while the
`CURSOR_RULES` startup checklist says load *"ALWAYS these two, and ONLY these two, at boot"* and marks
credentials **⛔ ON DEMAND ONLY — do NOT read at boot**, because *"credentials do not belong in
context 'just in case'."* Two authorities, flatly contradicting each other.

🚨 **And the stale one won, because it is the one you hit first.** `MEMORY.md` *is* loaded at boot, so
every cold session reached a heading reading "FILES TO READ" that told it to pull the credential file
in immediately — reversing a decision Andrew made and authorised in writing on **Aug 19, 2026**, in
the very rewrite that trimmed boot to two files. ⭐ **This is the third instance of one pattern found
on Aug 24 alone** (the others: `MAKE_MEMORIES` step 2e vs the never-commit rule, and `CURSOR_RULES`
item 4's stale VM list). ⛔ **Two files stating the same rule is one file too many. State it once and
point at it** — which is why this section is now an index and names its owner in the heading.

⚠️ **Why the credential rule earns its strictness:** ledger row **J8** — `PASSWORDS.md` is force-added
into the **GitLab mirror** by `push_gitlab.sh` (`git add -f -A`), and that is the repo **Jenkins
clones**. It is a *live* mirror, not a stale copy: it grew 14,854 → 16,781 B during the Part 3 session,
so a token written to it was in Jenkins' reach within the hour. **Confirmed still on-demand by Andrew,
Aug 24, 2026.**

**Where to actually look** (the routing table with the *cost of skipping* is the **PHASE INDEX** near
the top of this file — prefer it over this list):

| File | Holds |
|---|---|
| `CURSOR_RULES` | ⭐ **Boot order, scope, git routing. The authority for what loads when.** |
| `PASSWORDS.md` | All credentials. ⛔ **On demand only** — never at boot |
| `MEMORY_SECRET.md` | 🔒 **Confidential context — READ AT BOOT** (`CURSOR_RULES` item 2c, added Sep 16, 2026). Employer, dates, personal circumstances and the priorities that follow. **Gitignored, never public.** ⛔ **Never copy anything out of it into a tracked file** — write the consequence, leave the fact |
| `SYSTEM_VERIFICATION.md` | Hardware inventory, drive serials, VM configs (Jan 14, 2026) |
| `phases/current_phase.md` | ▶️ **`RESUME HERE` block at the top** — read that, not the whole file |
| `phases/phase0_hardware.md` | Hardware specs and BIOS settings |
| `phases/phase1_proxmox.md` | ZFS configuration and best practices — plus, since Sep 16, 2026, the two demoted **January 2026** session blocks. ⚠️ The Jan 12 one prescribes `cache=writeback`, which is **superseded** (incompatible with `aio=native`; use `cache=none`); its own section header says so |
| `phases/phase1a_*` / `phase1b_*` | Jan 12 kernel failure + rollback / the reversible retry |
| `phases/phase18_k8s_cka_build.md` | 🔵 **CURRENT PHASE** — the 5-node kubeadm/CKA build, **built Sep 17, 2026**. ⚠️ Read its Stage 1 results block before touching the cluster (four corrections that each mislead) |
| `phases/phase19_storage_tiers.md` | ✅ Closed Sep 28, 2026 — storage tiers, thin pools, `critical-nightly`, the snapshot-preserving move recipe, and how to place a NEW VM |
| `phases/phase20_k3s_rancher.md` | 🔵 Built Oct 27, 2026 — Rancher on single-node K3s (VM 187), Fleet GitOps, error log E1–E7, findings F1–F15, drills D1–D6; also the phase file of study track `education/rancher-k3s/` |
| `education/k8s-cka-prep/` | CKA research: exam environment, curriculum + weights, logistics, lab-parity decisions, sources with contradictions marked |
| `phases/phase17_jenkins.md` | ⏸️ **ON HOLD since Sep 16, 2026** (paused, not closed). Hard rules B10/B11 still bind, traps T1–T8 still unfixed. Resume at Part 4 |
| `education/CONVENTIONS.md` + `METHOD.md` | **Both** are mandatory before any study material |

📌 **The MEMORY DIET session record itself** (Nov 24, 2026 — method, numbers, approvals) is item 6 of the Nov 22–24 handoff, demoted verbatim to `phases/phase2_host_setup_automation.md` (pass 17a, Nov 27); the per-pass numbers are in `MAKE_MEMORIES` → BACKLOG.
