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

## ⚠️ WORKSTATION GOTCHA — THIS REPO LIVES ON A CIFS SHARE (found Aug 12, 2026)

The repo path `/home/agamache/DevShare/cursor-projects/home-lab-setup` is a **CIFS/NAS mount**
(`/mnt/DevShare`), and **the editor's file cache goes stale against it.** Observed on Aug 12 while
editing `CURSOR_RULES`:
- Two edits landed **corrupted** — one paragraph truncated mid-sentence, and a stray line
  (`EW instructs you to- CONFIRM that you will edi`) appeared inside a section that never contained
  it. Neither string existed in `HEAD`; both were introduced by the write itself.
- Read-backs returned **stale content that hid the damage**, and at one point reported a completely
  different region of the file than `rg` did on the same path.
- The IDE reported the file as **160 lines while disk had 204**.

**Rules that follow from this — apply to any large/critical file in this repo:**
1. **After editing an important file, VERIFY FROM THE SHELL**, not from a read-back:
   `wc -l`, `md5sum`, and `rg -c '<expected phrase>'`. Trust the shell view.
2. **Audit deletions before committing:** `git diff <file> | rg '^-' | rg -v '^---'` should show only
   lines you meant to remove. This is what caught both corruptions.
3. ⚠️ **A stale editor buffer WILL OVERWRITE good changes if saved — this actually happened.** At
   16:04 on Aug 12, Andrew edited the "never edit" directive in `CURSOR_RULES` from a stale buffer
   and **wiped all 3 uncommitted AI edits** (204 lines → 158). If Andrew has a file open and its line
   count disagrees with disk, tell him to close and reopen it *before* he saves anything.
4. ⭐ **THE REAL FIX IS TO COMMIT EARLY.** The clobbered edits were unrecoverable from git because
   they had never been committed — they had to be retyped from session context, which only worked
   because the session was still live. **Commit important file edits promptly** (locally is enough)
   so the next clobber is repaired with `git checkout <file>` instead of from memory.
5. Prefer **one atomic, asserted write** over many small edits on this mount. The successful rebuild
   used a single Python pass that asserted each anchor matched exactly once and that Andrew's own
   lines survived, then verified from the shell.

---

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

| Touching this | Read this FIRST | You will be WRONG without it |
|---|---|---|
| 🟢 **Docker Swarm** (VMs .191–.193), the swarm CI pipeline, `education/docker-swarm/` | `phases/phase16_docker_swarm.md` (**4137 ln — grep it, never read it whole**) | **Hard rule B1: NEVER retag/push production Capricorn images.** All 7 parts done and all 7 planted traps CLOSED (C7 last, Aug 19) — do NOT "re-fix" them; the drills are spent and their write-ups are the value. **8 chapters**, the last being the Swarm↔k8s crib sheet, whose per-row **provenance marks (S / K / 🤖 / recited)** are the device to reuse for any future cross-track writing. Also holds the P-numbered prediction log **P1–P61**, ledger **L1–L23** (lab-vs-PROD compromises), and the `s01→s07` snapshot chain (⭐ **s07 is the first with the C4 fix; s06 predates it**) |
| 🔵 **Jenkins (VM 185 `.185`), the Jenkins↔GitLab↔Swarm pipeline, `education/jenkins/`** | `phases/phase17_jenkins.md` | ⭐ **Weighting is Andrew's and is NOT Phase 16's:** install + configure + wire it up, and above all **Part 6 — bad deployments and recovery — is the centre of gravity.** The Phase 16 security charter is **Part 7 and secondary**; it is also **scoped** — only L21, L22, L12(partial) and the agent's privilege are in scope, because L1/L2/L3 are registry/Swarm work Jenkins cannot fix. 🎭 The phase is written as a **firm-supplied build standard**, so every spec line is marked 🔧 MECHANICS (rely on it) or 📐 CONVENTION (an AI invention standing in for the firm — **never quote it as what their firm does**). **8 planted traps T1–T8, do-not-fix before they fire**; T7 (a pinned, keystore-held key that still grants a full shell) fires *after* the deploy looks hardened. **A1/A2 settled: bookmark `http://192.168.1.185:8080/`, no DNS, no TLS.** No TLS is ledger row **J1** (accepted knowingly — a CI session cookie is a credential to everything Jenkins can deploy). **No DNS is cosmetic *because the address is static*** — the cost only appears if `.185` moves, when four things need hand-editing (Jenkins URL, webhook, agent, bookmark — the OAuth redirect is gone with A8); in a chapter that is a Lab-vs-PROD **table row, not a callout**, per CONVENTIONS' "wrong, not merely smaller" threshold. ⚠️ **T8 is NOT caused by skipping DNS** (the plan misattributed it once): GitLab blocks webhooks by **resolved address**, so a hostname on `192.168.1.185` is blocked identically. Two hard rules you cannot infer from the code: **Jenkins deploys the stack `capricorn-jenkins`, NEVER `capricorn`** (the Phase 16 GitLab pipeline stays alive as the comparison, and must be neutered rather than deleted if it is ever silenced), and 🚨 **B10 — Jenkins pushes images ONLY to the `lab` group, NEVER `production/*`, because QA `.180` and PROD `.184` pull `production/capricorn/<svc>:latest` and an overwrite there SHIPS TO PRODUCTION.** ⚠️ **Parts 4 and 5 were swapped Aug 20** — deploy precedes build so both CI systems ship identical artifacts; restoring the old order destroys the comparison |
| 🔵 **Any education track / chapter / diagram / docx** | `education/CONVENTIONS.md` + `education/METHOD.md` + that track's `README.md` | Figures must clear a **10pt** floor (`figcheck.py`) and raw aspect ratio sets rendered font size; the highlight pass targets **~20%** (raised from 15% Aug 19, 2026) measured **per section, not per chapter**, and a **top-up pass with a list of only-unmarked phrases is the normal workflow** — the old "never re-run `highlight.py`" rule applies solely to re-running the SAME list; chapter H1 format is fixed. Inventing a format per track is explicitly forbidden. 🚨 **Two traps you will otherwise walk into, both now IN `CONVENTIONS.md` (moved out of this file Aug 19, 2026): (a) a rebuild rewrites EVERY `.docx` via zip timestamps, so commit the one you changed and `git checkout` the rest or the track's history becomes unreviewable; (b) the highlight pass SKIPS tables and code blocks, so a load-bearing fact in a table cell is invisible to a highlights-only reader — restate it in prose.** ⚠️ **This row replaced ~200 lines that summarised `CONVENTIONS.md`/`METHOD.md` here.** Do not re-summarise them — read them; `CURSOR_RULES` already makes both mandatory before touching study material |
| **k3s / Redpanda / OpenSearch** (VM 186) | `phases/phase14_k8s_redpanda_poc.md` (1720 ln) | Phase CLOSED. 🚨 **`.186` is RUNNING and DELIBERATELY FROZEN** — `unattended-upgrades` masked, **not** in `refresh.sh`; do not patch it and **never** run `k3s-uninstall.sh` to "get a clean cluster". ⛔ **The Aug 20 verbatim demotion at the END of the file is the ONLY copy of ~40 findings** (local-path PV layout, `ALLOWVOLUMEEXPANSION=false`, the `Error:137` OOM signature, consumer-rebalance timings) — re-deriving them is days. ⚠️ **Paths moved to `education/k8s-k3s-redpanda/` Aug 12 — every `education/<x>` reference in the file's *CLOSING RECORD* section is PRE-MOVE and stale by design** (demoted verbatim from `current_phase.md` Aug 20, and editing it would have made the copy unverifiable). Holds the quorum/leaderless alerting findings |
| **The `/education` tree itself** (moving, renaming, restructuring) **or any highlight pass** | `phases/phase15_education_program.md` (480 ln) | ⚠️ That file is a **RECORD, not a plan** — §3 is already executed and §1 describes the *pre-move* tree. **Re-running it would undo the current layout.** ⛔ **§8 is the highlight-pass method** and is not optional reading before marking a chapter: it holds the per-section measurement rule and the `**`-straddle bug that prints literal asterisks in the `.docx`. Marking from instinct reproduces both |
| **vm-www-1 (.184), Traefik, PROD Capricorn hosting** | `phases/phase7_local_www.md` (1508 ln) | Network architecture is load-bearing and marked CRITICAL in that file; `.184` deliberately **never contacts the registry** (images arrive via `docker load`) |
| **Proxmox host config, kernels, ZFS pools, backups** | `phases/phase13_fable_proxmox_audit.md` (551 ln) + `phases/phase1b_*` | Kernel pinning is deliberate; a 50G thick zvol with refreservation sits on `vm-critical`. See also the BACKUP DIRECTIVE in `CURSOR_RULES` — **backups go to NAS, never NVMe** |
| 🔧 **Physical hardware — RAM/DIMMs, drives, serials, part numbers, storage capacity, PCIe slots** (either workstation) | `phases/phase0_hardware.md` → **Memory Configuration** + **Storage Capacity Audit** | **RAM:** both boxes are at 4-of-6 channels (Z6 *and* Z8, verified Aug 19 2026) — ⛔ **the Z8 is NOT a DIMM donor.** `phase13` PERF-3's slot numbers were **wrong** (free = `CPU0-DIMM3/4`) and its price is **~10x stale** (32GB DDR4 ≈ **$300** → the "$50–80" fix is ~$600). **STORAGE: no purchase needed — only 137 GiB is written across 3.24 TiB (4%).** ⭐ `vm-critical`'s scary **70.9% is `refreservation`, not data — `zpool alloc` is 7.5%**; both VM pools are thick (`sparse` unset/0). ⚠️ **`nvmeXn1` names in the docs DRIFT — identify drives by serial.** Bigger risk than capacity: the **Swarm cluster + its `s01–s06` snapshots sit on a no-redundancy stripe**, and **only VM 181 has a scheduled backup** |
| **Firewall, port-forwards, public exposure** | `phases/phase12_network_segmentation.md` (200 ln) | Perimeter is deliberately closed to everything but the WWW box; open ports listed there include ones flagged for removal |
| **GitLab / runner / CI** | `phases/phase3_gitlab_server.md`, `phase4_gitlab_runner.md`, `phase5_ci_cd_pipelines.md` | The runner is **privileged with the host Docker socket mounted** — any job on it is effectively root on the runner host (ledger L19) |
| **SonarQube** | `phases/phase6_sonarqube.md` (625 ln) | — |
| **OpenClaw agent (.185)** | `phases/phase11_openclaw.md` (**1099 ln**) | ⛔ **VM DESTROYED Aug 19, 2026 — totally gone, no backup, no snapshot. Nothing in that file is actionable.** VMID 185 + `.185` now belong to **Jenkins** (Phase 17), so **any `.185` in it means OpenClaw, not Jenkins.** Its *OPERATIONAL LOG* section (demoted from `current_phase.md` Aug 20) is six months of run-and-repair history; the one transferable pattern is **upgrades that silently reset config files, so the service starts clean and the customisation is what breaks** |

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

## CURRENT STATE

- **🎉 ANDREW GOT THE JOB (confirmed Aug 12, 2026).** The interviews happened **Aug 6 and Aug 7** and
  the outcome was an offer — **SRE / DevOps on an ORDER MANAGEMENT SYSTEM at a financial institution.**
  Phase 14 existed to prepare for those interviews, so **its goal is met and it is CLOSED.** Do not
  extend it. The education material is no longer interview prep; it is **onboarding prep for the job
  he now holds**, which changes the priority from breadth-before-a-panel to depth-on-the-real-stack.
  ✅ **The target stack is now CAPTURED IN FULL (Aug 13, 2026)** in **`education/fin_tech_stack.txt`**,
  which Andrew wrote himself and which is **the tracked source of truth for the study backlog**.
  🚨 **KEEP IT DE-IDENTIFIED — this is a standing rule, and it was learned the hard way on Aug 13.**
  The first draft named the employer, the start date and who suggested the list, and the first fix was
  to **gitignore** it. That fix was wrong twice over: the facts had already been copied into
  `MEMORY.md` and `current_phase.md`, which are **tracked and public**, and an ignored file makes a
  fresh clone miss the roadmap MEMORY points at. **Andrew's fix, applied the same day, was to
  de-identify the content instead** — generic title ("Current and future tech stack for modern FinTech
  DevOps/SRE"), generic framing ("Course selection and objectives for Q3-4 2026"), a neutral filename,
  and then **tracked normally**. 🚨 **Never reintroduce an employer name, a start date, or
  "my boss" into ANY tracked file** — `push_github.sh`'s gates look for *credentials* and would not
  stop it. **The push gates protect against secrets, not against private.**
  The list, so a cold reload needs no second file:
  - **Focus:** DevOps as it applies to an **OMS / platform including portfolio and risk management
    tools**.
  - **Study list, in its stated priority order (Q3–4 2026):** Kubernetes · Redpanda + Redpanda
    Connect · **Docker Swarm** · **Jenkins** · OpenSearch + OpenSearch Dashboards (logging and
    alerting) · Prometheus + Grafana (metrics and alerting) · Redpanda Connect + **Debezium CDC** ·
    **MongoDB + Postgres** · **SAML/OIDC** (Andrew already runs **authentik** as a self-hosted OIDC
    provider in his homelab and finds it easy to work with) · **Ansible**.
  - Also confirmed earlier: **GitHub** for source and **Jenkins** for CI. The lab stays on GitLab for
    now; Jenkins gets built when its phase comes.
  ⭐ **ROADMAP RULE (Andrew, Aug 13): new phases work through `education/fin_tech_stack.txt`
  STEP-BY-STEP, in that list's order.** Do not invent a curriculum or re-derive priorities — the list
  is the backlog. Track 1 (Kubernetes + Redpanda) and track 2 (Docker Swarm, Phase 16) are already on
  it; **Jenkins is next after Swarm.**
  ✅ **Chapter 7 of track 1 was RIGHT and must be LEFT ALONE (Andrew, Aug 13).** Its six areas
  (Cloudflare edge, IAM + Symantec PAM, Vault, PKI/cert-manager, MongoDB, OTEL→Prometheus/Grafana/
  OpenSearch) came from the job description and **are genuinely in the target stack** — they are
  simply **not in what was suggested as the first focus.** So the four that do not appear on the
  study list (Cloudflare, Symantec PAM, Vault, PKI/cert-manager) are **real and correctly
  documented, just lower priority**. ⚠️ **Do NOT rework, retract or "reconcile away" chapter 7**, and
  do not treat `phases/phase15_education_program.md` §4 as wrong — it was a straw man, but it aimed at
  the right target. Sequencing now comes from the study list, not from §4.

- **🔑 LAB ACCESS IS NOW FULLY SORTED (Aug 12, 2026) — read the two sections below before debugging
  any connection problem:** `CREDENTIALS → SSH ACCESS MATRIX` and `REMOTE LAB MANAGEMENT`.
  Headlines: **every VM logs in as `agamache`, never `andrew`** (a wrong username returns
  `Permission denied (publickey,password)`, which looks exactly like a missing key and wasted real
  time today); **the Proxmox host now accepts the workstation key** via `/root/.ssh/authorized_keys2`
  (*not* `authorized_keys`, which is a PVE-managed symlink into `/etc/pve/priv/`); and **remote
  access works two ways** — a laptop on the tailnet via the host's approved `192.168.1.0/24` subnet
  route, or RDP into the Windows Z8 (`agamache-z8g4`) and drive the pve GUI from there, which keeps
  all plaintext credentials on the LAN and survives `.150`'s `tailscaled` failing.

- **🔵 ACTIVE — Phase 15: the education program** (`phases/phase15_education_program.md`).
  Restructured `education/` from one flat series into a multi-track shelf (see the education section
  below). Framework work only; the first new track gets its own phase file per the agreed model.
  ⚠️ **`CURSOR_RULES` HAS NOW BEEN EDITED TWICE — Aug 12 and Aug 13, 2026.** That file says the AI
  must never edit it; **on each occasion Andrew gave explicit authorisation in writing, for that
  change only**, and the note recording the standing condition sits under the never-edit line.
  **Neither is precedent** — get the same explicit approval or do not touch it. **Both edits were
  done as a single atomic Python pass that asserted every anchor matched exactly once and that
  Andrew's own lines survived, then verified from the shell** (`wc -l`, `md5sum`, and a
  `git diff | rg '^-'` deletion audit). Do it that way again; see the CIFS gotcha at the top of this
  file for what happens otherwise.
  **The Aug 13 edit (second): wiring in `education/METHOD.md`** — 225 → 239 lines, exactly one line
  removed (old rule 2, deliberately rewritten). Four changes: **new startup checklist item 2g**
  making `METHOD.md` a mandatory read before starting or running a track; **`METHOD.md` added to the
  education file list**; **new rule 1b** (read METHOD before running a track — CONVENTIONS governs the
  artefact, METHOD the work); **rule 2 widened** to route convention changes to `CONVENTIONS.md` and
  working-practice changes to `METHOD.md`, neither ever forked into a track; and **new rule 8** — the
  method is a **floor, not a ceiling**, deviate per topic but fold what works back in the same
  session. **The `RULES:` list is now numbered 1, 1b, 2–8** (`1b` avoids renumbering rules that other
  documents reference).
  **The Aug 12 edit (first) — three changes went in:**
  - **`PROJECT SCOPE` rewritten (Andrew's own definition):** this repo owns **TWO** things — the
    Proxmox/infrastructure layer **and educational R&D done inside the lab** (the `/education` tracks
    plus the POC builds they are written from). "Application layer" = **Capricorn and other real apps
    running on the lab**, which belong to their own projects. So the OMS producer/consumer in
    `education/k8s-k3s-redpanda/app/` **IS ours** (study material); Capricorn is not. The old wording
    said "INFRASTRUCTURE layer ONLY", which would have made a literal reader disown `/education`.
  - **Startup checklist item 2f** — `education/CONVENTIONS.md` is a mandatory read when the session
    touches education content.
  - **New `=== EDUCATION PROGRAM (/education) ===` section**, 7 rules (now 8 + `1b` after Aug 13).

- **🔵 ACTIVE — Phase 17: Jenkins** (`phases/phase17_jenkins.md`, started Aug 19, 2026).
  ✅ **PARTS 0 AND 1 ARE DONE (Aug 20, 2026) — Jenkins is UP, do not rebuild it.** `http://192.168.1.185:8080/`,
  **Jenkins 2.568.2 LTS on OpenJDK 21**, controller at **0 executors**, one SSH agent `jenkins-agent-1`
  (OS user `jenkins-agent`, uid 1001, no sudo, no groups) with label `swarm-deploy`. 🙋 Andrew ran every
  command. A1/A2 are closed (bare IP, no TLS = ledger J1). ✅ **Part 2 also done, RESHAPED — next is
  Part 3 (webhook + `Jenkinsfile`).**
  🚨🚨 **HIGHEST-BLAST-RADIUS RULE IN THIS PHASE (B10, set Aug 20 — J-P7). Jenkins-built images go to
  the GitLab group `lab`, project `capricorn-swarm`, and NEVER to `production/*`.** Capricorn's own
  pipeline publishes `production/capricorn/<svc>:latest` and **QA `.180` and PROD `.184` pull that exact
  tag**, so a Jenkins push to the natural-looking path **overwrites what PROD runs** — this one escapes
  the lab. Enforce with a **token scoped to `lab/` only**. ✅ **BUILT AND PROVEN Aug 20 (J-P8):** group
  `lab` + project `lab/capricorn-swarm` exist; push to
  `gitlab.gothamtechnologies.com:5050/lab/capricorn-swarm/<image>`; group deploy token
  `jenkins-lab-push` (value in `PASSWORDS.md`, **expires 2026-12-31**) is granted `push,pull` on `lab/`
  and **`pull` only** on `production/capricorn`. ⚠️ **The `pull` is NOT a scope leak — `production/
  capricorn` is an INTERNAL project, so every authenticated identity can read it. A deploy-token scope
  grants; it does not fence. The floor is set by project visibility.** All Jenkins images are **git-SHA tagged, never `:latest`** (B11). ⚠️ **THREE delivery paths
  now coexist and none may touch another's artifacts:** Capricorn's CI → the real app on `.180`/`.184`;
  this repo's `.gitlab-ci.yml` → stack `capricorn`; Jenkins → stack `capricorn-jenkins`.
  ⛔ **Never `git rm` this repo's `.gitlab-ci.yml`** (B1, amended A11) — it is the *control* for the
  whole Jenkins track. When Andrew wants it quiet, **neuter it with a `workflow:` rule**; a deleted
  pipeline can be read but not **run**, which makes every later comparison unfalsifiable.
  📌 **`Jenkinsfile` lives at `education/jenkins/Jenkinsfile`** — one pipeline per education track, in
  its own track folder, **not** the repo root (A10). ⛔ **Do not "tidy" it into a cleaner repo: trap T5
  requires the job to clone the plaintext `gitlab/main` mirror, so moving it silently DISARMS the trap
  and leaves no error behind.**
  🔻 **PARTS 4 AND 5 ARE SWAPPED (Aug 20): deploy is Part 4, build+push is Part 5.** Deploy goes first
  so Jenkins ships the **same `:latest` images** as the Phase 16 pipeline and the CI system is the only
  variable. ⭐ **Part 4 reuses `education/docker-swarm/scripts/deploy_swarm.sh` UNCHANGED** (it is
  already parameterised — `STACK="${STACK:-capricorn}"`); expect its loud `NON-DEFAULT STACK FILE`
  banner every run — **that is the script working, not a fault.** ⚠️ **A separate manifest IS required:
  `capricorn.stack.yml` publishes 5001/5002 `mode: ingress` and two stacks cannot share ingress ports**
  → `education/jenkins/manifests/capricorn-jenkins.stack.yml` at 5011/5012. Volumes and networks are
  already per-stack namespaced.
  🔻 **A8 CLOSED Aug 20 — NO OAuth in the lab, ever, and this is not a "we'll get to it".** Andrew's
  firm uses **GitHub**, not GitLab, so GitLab OAuth would teach a provider he will never touch; and
  coupling Jenkins login to GitLab during a phase that deliberately breaks the Jenkins↔GitLab path
  violates *one instrument per question*. Auth stays **local accounts + matrix authorization**.
  ⛔ **CORRECTION — an earlier revision of this entry was WRONG and would have misled you:** it said
  the local admin is a "break-glass account" that keeps you in when the identity provider dies. **It
  is not.** Jenkins has **exactly ONE security realm at a time**, so an OAuth realm would *replace*
  the local user database and that account could not log in at all. **Real break-glass on any Jenkins
  is root on the host** — stop the service, edit `JENKINS_HOME/config.xml`, restart. ⚠️ **Stop Jenkins
  FIRST: it rewrites `config.xml` on shutdown and will erase your edit.** ⭐ Targeted vs blunt matters:
  if only *authorization* broke, replace the `<authorizationStrategy>` block and **login still
  works**; the universally-recited `useSecurity=false` + delete-the-realm recipe is only needed when
  the **realm** is broken and leaves the box **fully unauthenticated on plain HTTP** meanwhile.
  ⚠️ Also **do not "tidy" these**: the `zz-executor-proof` job is a deliberate liveness probe,
  `credentials.xml` being world-readable and the agent having no `docker` access are **Part 5/7**
  material (T2 and the hardening charter), not oversights.
  📐 **Standing policy, Andrew, Aug 20: Jenkins runs the EDUCATION pipelines; GitLab CI runs the REAL
  applications** — *"that way we do not pollute our real GitLab environment."* ⚠️ **This does NOT make
  Jenkins GitLab-free**: it still clones from GitLab and is still webhook-triggered, so T1/T4/T5/T8 all
  live on that surviving link. The boundary is at the **pipeline engine**, not at GitLab.
  📐 **Registry = GitLab's own, standing in for the Artifactory his firm uses** (ledger J3 — same VM as
  the git server, plain HTTP, no scanning, no signing). ⭐ **The swap to a real artifact store is a
  hostname and a credential, not a redesign** — an OCI registry is an OCI registry.
  📖 **Education track 3 opened: `education/jenkins/` — README + chapter 1 written Aug 20** (there is
  deliberately **no chapter 0**; Part 0 is assumed plumbing, decision P1).
  ⛔ **Part 0 step 1 is already DONE and is irreversible: VM 185 `vm-openclaw-1` was destroyed** on
  Andrew's instruction with **no backup and no snapshot** — see `phase11_openclaw.md` → "CLOSED". VMID
  185 and `.185` are reassigned to `vm-jenkins-1`. ⭐ **Andrew's weighting: install + configure Jenkins,
  wire it to GitLab and the Swarm, and above all LEARN TO FIX BAD DEPLOYMENTS** the way Phase 16 did on
  GitLab CI — that is Part 6 and it is the centre of gravity. The Phase 16 hardening charter is **Part 7,
  required but secondary**, and **scoped** to L21 + L22 + L12(partial) + agent privilege. 🎭 The phase
  runs as a **firm-supplied build standard** (Andrew's framing) with every spec line marked 🔧 mechanics
  or 📐 invented convention — a deliberate deviation from `METHOD.md` that gets folded back in **only if
  it proves out.**
  ⭐ **Six cross-phase rules earned here, worth more than the phase that produced them:**
  1. **Before destroying anything, read its config AND grep the docs for what depended on it.** The
     pre-destroy read of VM 185 caught a **wrong core count** (12, recorded as 8) and two facts it
     silently invalidated: it was the **only VM running Tailscale**, and one of only two with PVE
     firewall rules. After the destroy, none of that is recoverable — including from a backup, since
     there wasn't one. ✅ Also verified: **`qm destroy --purge` deletes the VM's `/etc/pve/firewall/<id>.fw`.**
  2. 🚨 **A superseded DIRECTIVE left in a history log is more dangerous than a stale fact**, because a
     future session can *act* on it. `current_phase.md` still held *"VM 185: leave dormant — don't
     destroy"* after Andrew ordered it destroyed. Strike obsolete directives where they lie; do not
     rely on the reader inferring the date.
  3. **Do not generalise a product's policy from one subsystem's behaviour.** Measured on `.181`:
     GitLab **blocks** project webhooks to private addresses while **allowing** system hooks to the
     same target. "GitLab blocks LAN egress" is false as stated.
  4. ⭐ **PROVE THE NEGATIVE BEFORE YOU BUILD THE POSITIVE** (Aug 20). To verify a boundary, first
     demonstrate the failure it should cause, *while the thing that would mask it does not yet exist*.
     Jenkins: controller set to 0 executors, then a job run **with no agent attached** — it sat in the
     queue; the agent was added and **the same job, unchanged**, ran. Attaching the agent first can
     never distinguish an enforced boundary from one that was never enforced, because a green build
     only proves *something* ran it. **Reading a config field tells you what a system was told; a
     failure tells you what it will do.**
  5. ⭐ **A MANIFEST IS NOT A CAPABILITY** (Aug 20). Confirming the named things are installed proves
     the list was followed, not that the system can do what the list was written for. Jenkins: the
     build standard named **"SSH Agent"** (`ssh-agent` = a pipeline step that forwards a key *into* a
     build) while the topology needed **"SSH Build Agents"** (`ssh-slaves` = the thing that launches
     agents over SSH). Following the standard exactly produced a controller that could not attach the
     agent the same standard demanded. Same shape as "reachable is not usable".
  6. ⭐ **TWO PRIVILEGE PLANES — hardening one says nothing about the other** (Aug 20). A Jenkins build
     ran as OS user `jenkins-agent` (unprivileged, kernel-enforced: `master.key` denied) **and** as
     Jenkins' internal `SYSTEM` identity (full permissions through Jenkins' own APIs) *at the same
     time*. **"The agent is unprivileged" is a true statement about one plane and a half-truth overall.**
     Generalises to any runner: the OS account and the application-level identity are separate grants
     with separate fixes. ⚠️ Related, same host: `JENKINS_HOME` is `755` and `credentials.xml` is `644`,
     so **every local account can read the encrypted credentials** — the only thing between them and
     plaintext is the `700` on `secrets/`. **One layer, nothing behind it.**

- **🟢 COMPLETE — Phase 16: Docker Swarm** (`phases/phase16_docker_swarm.md`) — all 7 parts, all 7
  traps, 8 chapters, closed Aug 19, 2026 with the Swarm↔Kubernetes crib sheet (chapter 8). Only two
  **NOTHING PLANNED IS OUTSTANDING** — the highlight pass was done Aug 19, and **drill D was run Aug 18**
  (P30/P31 ✅; it produced the `pg_hba.conf` `trust` finding). 🚨 **Both this line and `current_phase.md`
  claimed drill D was "never run" for a full day, and the Aug 19 `MAKE_MEMORIES` pass repeated it as the
  phase's only open item** — because it edited the summary without diffing it against the phase file,
  where the scored results sat 1,900 lines down. The planning entry's `🔲` box had never been ticked.
  ⭐ **A summary is a claim about another file. Re-read what you are summarising, or you will launder a
  stale checkbox into a status.** ✅ **The last open measurement (the `redis` divergent-volume question)
  was made Aug 19 and REFUTED the hypothesis** — the two volumes are trap C3's deliberate residue, not an
  unnoticed incident. 🚨 **Its lesson is a general one and cost a fictional incident: `docker service ps`'s
  `CURRENT STATE` age ("Running 8 hours ago") is the last time the MANAGER STAMPED the task's status, not
  the task's age.** The stamp moves on control-plane churn, so a day-old task reads as freshly
  rescheduled; the task in question was 20 hours old, not 2. Use `docker inspect <container>` →
  `.State.StartedAt` + `.RestartCount` for uptime, task history for provenance, and rule out clock skew by
  measuring it. ⭐ **When Swarm prunes old task rows, the only surviving evidence of a move is on the
  filesystem** (volume `CreatedAt`, Redis' AOF generation number). The narrative below is the Part 4
  detail, kept because the CI wiring is the part most likely to be needed again.
  🎯 **PART 4 COMPLETE — CI DEPLOYS THE STACK, TRAP C4 FIRED AND FIXED, CHAPTER 3 WRITTEN (Aug 19, 2026,
  ~10:00 AM – 2:26 PM). 🙋 Andrew drove it, one step at a time.** GitLab CI now deploys the swarm stack. **A2 RESOLVED: yes, this repo has a `.gitlab-ci.yml`**,
  with **two independent gates** — `workflow: rules:` restricts pipeline *creation* to
  `$CI_PIPELINE_SOURCE == "web" && $CI_COMMIT_BRANCH == "main"` (because `push_gitlab.sh` pushes
  constantly), and the job stays `when: manual` so its safety does not depend on that guard surviving a
  future edit. ⚠️ **The guard had to be in the FIRST version written to DISK, not the first commit** —
  `push_gitlab.sh` stages the working tree with `git add -f -A`, so an untracked file is already live on
  `gitlab/main`. **P38 confirmed first try: the wrapper added ZERO deploy logic** — `deploy_swarm.sh` ran
  byte-identical, no `STACK_FILE` override, three gates green. Verified from the *cluster*, not from CI's
  report: `/home/agamache/swarm-ci/{scripts,manifests}` shipped by CI, all four services
  `UpdatedAt 15:34:18 UTC`, stack `2/2 3/3 1/1 1/1`. **The wrapper reproduces the DIRECTORY SHAPE the
  script expects** (`scripts/` + `manifests/` siblings) because `deploy_swarm.sh` resolves the manifest
  relative to itself — copying both files flat and passing `STACK_FILE=` would fire the NON-DEFAULT STACK
  FILE banner on every routine deploy and turn a working alarm into wallpaper.
  **Credentials:** dedicated `working/phase16/swarm_deploy_ed25519` (ed25519, no passphrase,
  `SHA256:Z4ZrDsR10B6GHUlowCgb0Bb/xjuD7mPOaWVCpdlYXZ8`) authorized for `agamache` on **all three**
  managers; CI variables `REG_TOKEN` (masked ✅) and `SWARM_SSH_KEY` (**unmaskable — GitLab can only mask
  single-line values, and a PEM key never is**), both unprotected. ⭐ **Deliberately a NEW keypair, not
  Capricorn's `SSH_PRIVATE_KEY`**, which serves `.180` AND `.184`: sharing it would have given the study
  cluster's pipeline SSH into production and made the lab key unrevokable.
  🚨 **Two ledger rows worth reloading cold. L19:** the shared runner is `privileged = true` **with
  `/var/run/docker.sock` mounted into every job** — a root shell on `.182`, the host that deploys real
  production, available to **every project on the GitLab instance**, and **a job cannot decline it**
  (it is runner config, not job config). **L20:** `gitlab/main` is the full plaintext mirror, and CI
  clones the branch it builds, so **the job's working directory contains `PASSWORDS.md` and every other
  secret** — which makes the masked token a lock on a door in a building with no walls.
  ⭐ **P4-F3, the best finding: `docker login` writes NOTHING when the credential is unchanged.** Measured
  to the nanosecond (`config.json` unmoved at Aug 13 18:27:16.128571619, 134 bytes, across a
  `Login Succeeded`). Consequences: (a) that mtime answers *"when did the credential last CHANGE"*, not
  *"when did this node last authenticate"* — a forensic timeline built on it is wrong; (b) 🚨 **the
  plaintext-storage WARNING behind row L9 is write-time-only**, so it fires once per credential change and
  an audit of repeated CI deploys sees clean logs; (c) an idempotent action leaves no trace, so **"nothing
  changed on disk" is not evidence that "nothing happened"** — the AI reasoned from the stale mtime to a
  confident *wrong* conclusion (a phantom false-green), which is a **FALSE RED** and the mirror image of
  chapter 6's taxonomy. **P4-F1:** the project's CIFS share (`file_mode=0775,nounix`) **cannot hold an SSH
  private key** — `chmod 600` is a silent no-op — but it does not matter, because the `ssh-agent` +
  `ssh-add -` pattern never writes the key to a file. **P4-F2:** `IdentitiesOnly=yes` restricts *keys*, not
  *auth methods*; the test fell through to a password prompt and one keystroke would have produced a
  convincing false pass. Use `-o PreferredAuthentications=publickey`.
  ✅ **PART 4 IS COMPLETE (Aug 19, 2:26 PM): trap C4 fired, fixed, and chapter 3 written — the track is
  6 of 6.** C4: with `SWARM_HOST` hardcoded to `.191` and that VM powered off, the job died on its first
  command (`Host is unreachable`, **exit 255** — ssh reserves 255 for *its own* failures, so it means "I
  never ran your command") while quorum held, `.193` took the lead, and the UI kept serving.
  🚨 **The accident worth remembering: `SWARM_HOST=.191` and the `postgres` pin to `.191` put the DELIVERY
  PATH and the SYSTEM OF RECORD on one host.** Nobody designed that overlap; neither decision was wrong,
  their intersection was. Epilogue: the pin that caused the outage **saved the data** (a pinned service
  cannot reschedule onto an empty local volume — 682 rows intact on recovery).
  🚨 **P4-F4, the phantom task — the strongest false green in the phase.** `docker service ls` reported
  `capricorn_postgres 1/1` **while its node was powered off**. `docker service ps` showed 5 tasks: one
  replacement stuck `Pending` forever (`no suitable node`, the pin admits only `docker-swarm-1`) plus a
  ghost on the dead node, `desired=Shutdown`/`current=Running`, **counted as Running because Swarm cannot
  confirm a shutdown it cannot deliver.** ⭐ So an inflated count has **two** unrelated causes — the
  `start-first` overshoot *and* a phantom — and reading `4/3` as "start-first" sends you to `update_config`
  when the real story is a dead host.
  🚨 **P4-F6: `deploy_swarm.sh`'s convergence poll was INVERTED, and its own failure dump contradicted its
  headline.** Testing `current != desired` on the `Replicas` column, it spent 300s printing
  `still pending: capricorn_backend(3/2) capricorn_frontend(4/3)` — both perfectly healthy — while
  `postgres`, which did not exist, **passed**. The dump printed one line below showed exactly 2 and 3
  tasks, because it filters `desired-state=running` and the `Replicas` column does not. ⭐ **The right
  instrument was already in the file, used for the report and not for the decision.**
  ✅ **FIXES SHIPPED.** `.gitlab-ci.yml`: `SWARM_HOST` → **`SWARM_HOSTS`** (all three managers) with a
  selection loop whose probe is `ssh -o BatchMode=yes -o ConnectTimeout=5 host 'docker node ls'` — ⭐ **not
  `ping` and not `ssh host true`: probe the CAPABILITY you are about to use, not a proxy that correlates
  with it** (a node can accept SSH while being a worker, or a manager that lost quorum — drill C5's exact
  state). `deploy_swarm.sh`: **counts TASKS** filtered to `desired-state=running` (excludes phantoms by
  construction), `-lt` not `!=` so overshoot no longer blocks, a `sleep $INTERVAL` settle delay covering
  the window the `!=` was incidentally protecting, and a **degraded-cluster precondition** that refuses to
  deploy if any node is not `Ready`/`Active` (override `ALLOW_DEGRADED=1`, kept deliberately — a tool that
  forbids the right incident action gets worked around in ways nobody records).
  ✅ **BOTH VERIFIED against a genuinely degraded cluster (Aug 19, 2:48 PM), not recited.** Precondition: job
  failed in **3 s** naming `docker-swarm-3(Down/Active)`, vs **5 min 10 s** and a wrong answer before the fix
  — and `docker login` never ran, so a refused deploy touches no credential. 🚨 **That guard then made the
  counting fix UNREACHABLE by normal means** (it stops execution upstream of the poll, in exactly the
  scenario the poll fix was for) — ⭐ *an early guard can render a downstream path untestable*, which is the
  better reason `ALLOW_DEGRADED=1` exists. Counting was therefore proved through the hatch, phantoms
  confirmed present FIRST (`backend 3/2`, `frontend 5/3` — one ghost and two, reconciling exactly against
  task placement): **`all services converged`** plus all three smoke gates and `total=682`. 🚨 **The old
  logic would have burned 300 s reporting a FAILED DEPLOY on a demonstrably healthy application** — a false
  red in our own tooling. ⭐ **Reload this framing: our poll now DISAGREES with `docker service ls` on
  purpose and is right to** — post-deploy, Docker read `3/2`/`5/3` while we read `2/2`/`3/3`, because
  `Replicas` counts tasks Swarm cannot confirm dead and we count tasks Swarm still wants alive. Being able to
  say *which question each number answers* is what licenses contradicting a vendor's headline number.
  ⚠️ Still untested: the
  rigorous settle-delay variant (compare `.Version.Index` across the deploy). Also unmeasured: whether
  unpinned `redis` silently lost its local volume when it rescheduled during the outage (trap C3's
  mechanism, possibly having occurred for real inside a different drill).
  🚨 **UNPLANNED INCIDENT, Aug 19 2:55–3:02 PM — `qm start 193` made the restarted manager DEPOSE the healthy
  leader every ~20 s for 2.5 minutes, and DOING NOTHING WAS CORRECT.** Reload the whole mechanism, it is the
  best material in the phase. While powered off, `.193` kept campaigning and inflated its raft **term** 12→31
  **without appending a log entry**, so it rebooted holding *the highest term and the stalest log* — and those
  have opposite consequences. **Term is authority:** any node seeing a higher term must stand down, so `.191`
  (a healthy leader at term 12) logged `became follower` + `soft state changed … resetting and cancelling all
  waits`, which **aborts in-flight control-plane work** — a deploy landing in that window fails inexplicably.
  **Index gates election:** `.191` at `index 775` rejected `.193` at `743`, so `.193` **could never win the
  election it forced.** ⭐ **THE SENTENCE TO REMEMBER: a stale manager can force elections but can never win
  one, so each forced election raises the term until a current-log node wins high enough to silence it — the
  failure mode contains its own termination condition.** `.191` took term 34 with `.192`'s vote; settled;
  churn count `0`. 🚨 **`docker swarm leave --force` on `.193` — the standard internet remediation — would
  have destroyed a cluster 90 s from self-healing.** After a manager reboot: **wait ~3 min, re-measure churn**
  (`journalctl -u docker --since '2 min ago' | grep -cE 'became leader|became follower|lost leader'`, `0` =
  settled) and only escalate to demote/rejoin if churn stays non-zero (that points at log compaction, not term
  inflation). ⚠️ **Diagnose from a node that is NOT the suspect:** `docker info` on `.193` said `The swarm does
  not have a leader … too few managers are online` — **true at that instant and its stated explanation false**,
  because `.193` had just deposed the leader. `nc … 2377` succeeded both directions and clocks were NTP-synced,
  so network and skew were ruled out by measurement.
  ✅ **P4-F8 FIXED — `MANAGER STATUS` is a THIRD question the guard never asked.** Throughout the flap `.193`
  read `Ready/Active`, so the precondition called the cluster healthy. ⭐ `STATUS` = can it run tasks (worker
  plane) · `AVAILABILITY` = drained? · `MANAGER STATUS` = live raft quorum member (control plane); **they move
  independently — "one instrument per question" applied to three columns of ONE command.** `deploy_swarm.sh`
  now prints a **`CONTROL PLANE DEGRADED (advisory)`** block and **PROCEEDS**, deliberately: quorum-intact
  churn creates no phantoms so downstream checks stay valid, the condition self-limits, and blocking would
  forbid a safe deploy *and* invite the reflex that causes the outage. **Severity should match consequence,
  not alarm level.** ⚠️ The awk filter needs **`NF > 1`** — a worker's `ManagerStatus` is EMPTY, so without it
  every worker is flagged a broken manager forever.
  ✅ **P4-F7 FIXED:** the degraded banner printed `Refusing to deploy` and then deployed under
  `ALLOW_DEGRADED=1` — the log contradicted itself. Verdict is now computed *before* it is narrated.
  ⭐ **Never let an override change behaviour without changing the wording** (same class as P4-F6).
  ⚠️ **`.191` still holds the PRE-FIX copy of `deploy_swarm.sh`;** the next pipeline `scp`s F7+F8 over it.
  ⭐ **Two CI-specific traps worth reloading cold. (1) A job RETRY replays the pipeline's ORIGINAL commit**
  — we fixed a file, pushed, hit Retry, and the runner checked out the old commit and failed identically;
  the manufactured conclusion "my fix did nothing" is wrong and extremely convincing. **After a fix, create
  a NEW pipeline.** **(2) `Updating service X` is printed for every service on a byte-identical spec** — it
  describes the API call, not a rollout; read literally it implies an unpinned service was recreated, which
  would be silent data loss. Also: bracketed-paste artifacts manufactured `docker: command not found` on a
  node where Docker was running, and a `404` where the real endpoint returns `500` (**P4-F5**).
  ⚠️ **A process failure worth not repeating: survivor-side observations were written into the phase file
  as though measured, sourced from a session SUMMARY that claimed they had been provided. They had not.**
  Caught by grepping the transcript. ⭐ A conversation summary is the same class of object as a status page
  or a replica count — a report from a layer that is not the layer that fails. **Cite the primary source.**
  📄 **Chapter 3 `chapter03_a_pipeline_that_deploys.md`** (680 lines) + figure
  `ch03_fig1_delivery_path.dot/.png` (11.9pt, figcheck clean) + docx. Ledger rows **L21** (passphrase-less
  key in an unmasked CI variable — GitLab cannot mask multi-line values *at all*) and **L22**
  (`StrictHostKeyChecking=no`; ✅ measured that `mkdir ~/.ssh` makes it TOFU *within* the job — `Permanently
  added` appears once, later connections verify, so the window is the job's FIRST connection). Spine of the
  chapter: **one instrument per question.**
  ⭐ **PHASE 17 CHARTER agreed:** its success condition is *"every ⚠️ recited row in the Phase 16 ledger is
  now ✅ verified"* — host keys pinned, a maskable/keystore credential, an unprivileged agent.
  🎯 **FULL TRACK REVIEW DONE (Aug 18, evening): four review agents audited everything; all findings
  fixed; C6b CLOSED BY RE-DRILL.** Frontend got a manifest `healthcheck` (`wget | grep -qi capricorn`
  — pre-verified in both the real image and nginx:alpine), `deploy_swarm.sh` got **Gate 3** (assert
  every published port), a NON-DEFAULT STACK FILE banner, a pre-deploy UpdateStatus snapshot, and a
  row-gate that FAILS instead of skipping on parse errors. **P32–P34 all confirmed**: healthy deploy
  63 s green with `(healthy)`; identical nginx re-drill **failed loudly in 47 s** (`rollback_started`,
  EXIT=1) with **16/16 serving probes on the real app — zero user-visible seconds**; and the recovery
  deploy showed **a stack deploy of an identical spec CLEARS a stale `rollback_completed` to
  `<absent>`** (measured both sides) — the stale-latch worry is bounded to the window between deploys.
  Chapter fixes worth remembering: reboot counts were misquoted in ch5/ch6 (**measured: backend 1/2,
  frontend 1/3, postgres 1/1, redis 0/1**); ch6's Drill A table was rewritten back to the seven signals
  actually checked; the "five void runs" are honestly **3 void runs + 2 invalid probes**; COMMANDS.md's
  own post-reboot gate had `|| echo` printing success ON FAILURE (fixed to `&&`, kept as a lesson);
  "three services use start-first" was always wrong — **two** (frontend, backend). Track README now
  carries the L1–L18 index, a not-covered list, a reproduce quickstart, a grounded Swarm↔K8s table
  (Part 7 still owed), and a capstone. Chapter 2's max_attempts staleness is repaired — the
  "exactly three" story is labelled create-path history under the old policy, current create-path
  behaviour recorded as OPEN.
  **Earlier that evening (7:00–8:20 PM): ALL DRILLS DONE AND CHAPTERS 4, 5, 6 WRITTEN.** 🙋 Andrew asked
  the **AI to drive** the last four drills so the chapters could be written before context was lost — a
  deliberate exception to `METHOD.md`, recorded in both the phase file and `current_phase.md`.
  **P20–P31: 10 confirmed, 2 refuted, and the refutations matter most.** (a) ❌ Removing `max_attempts`
  causes **no** retry storm on an *update* — `failure_action: rollback` ends retries after one failure;
  ⚠️ **still open on the CREATE path**, which is where chapter 2's "exactly three Rejected tasks" came
  from — ✅ chapter 2 repaired during the evening review. (b) ❌ **With no quorum, READS fail too** —
  `docker service ls` → `DeadlineExceeded`; Swarm serves no stale reads, so you lose all cluster
  visibility while the app serves normally and **`docker ps` per node is the only inventory.**
  🎯 **The worst result in the track is C6b: `nginx:alpine` on the frontend deployed GREEN.**
  `UpdateStatus: completed`, `EXIT=0`, `3/3`, **and our own smoke gate passed** (`200, body matched`,
  `682 rows`) while every user saw *Welcome to nginx!*. **Swarm's rollback reacts to task failure, not
  correctness; our gate only defends the endpoint it calls.** ⭐ **Verification does not compose** — ✅ the open
  work (frontend `healthcheck` + per-port smoke assertion) was done and re-drilled the same evening.
  ⭐ **C3: state is STRANDED, not lost.** Moving Redis off its node made Docker **silently create a second
  empty volume of the same name**; `DBSIZE 0`, everything green; moving it back returned both keys exactly.
  🚨 **It was fsynced on `SIGTERM` at the instant it became unreachable — durability ≠ availability.**
  ✅ **Correction to an AI claim made mid-drill:** postgres **IS** pinned (`node.hostname ==
  docker-swarm-1`, manifest says *"trades availability for durability: postgres dies with
  docker-swarm-1"*); **redis is unpinned deliberately** so C3 could run. **The pin is why C3 could not
  touch the database** — the lab's config was right and the accusation was wrong.
  🚨 **New security finding: `pg_hba.conf` ships `host all all 127.0.0.1/32 trust`** — a garbage
  password returns `1` from inside the container, so with `docker exec` reading `/run/secrets`, **`docker`
  group on a node = unauthenticated DB access, and rotation does not change it.** Never test a DB
  credential from inside its own container.
  ⭐ **Drill D: a WRONG secret passes every guard** (pre-flight ✅, converged ✅, digests ✅) and **only the
  smoke gate catches it.** `POSTGRES_PASSWORD_FILE` is read **only at `initdb`**, so rotation touches the
  client and never the server → correct order is `ALTER USER` **first**, then the secret.
  ⭐ **The `restart_policy: any` fix was validated by accident** — the quorum drill stops daemons, whose
  containers exit `0`, the identical mechanism that ate three replicas under `on-failure`; nothing was lost.
  ✅ **Resting state HEALTHY**: 2/2, 3/3, 1/1, 1/1, smoke gate green, quorum restored, **leader moved to
  `docker-swarm-1`** (leadership not sticky — observed twice), C3 constraints removed, `pg_password_v2`
  deleted. ✅ **`s05-review-c6b-closed` taken Aug 18 ~8:15 PM (Andrew authorized)** — all three VMs, hot
  fsfreeze, description warns that `s04` still contains the **broken `on-failure` policy**. 🔲 **GitHub push held**; GitLab only.
  **Previously, Aug 18 (5:00–6:30 PM) — five drills whose findings were about the APPLICATION,
  not Swarm.** Resting state: stack healthy, **1621 DB rows = 939 tax reference (from `initdb`) + 682
  written by the app**, snapshot **`s04-drills-complete`** (all three VMs gracefully shut down first).
  🚨 **`:latest` MOVED on Aug 17** (pipeline #160) — `backend@b449d6c4`, `frontend@5507b283`,
  `postgres@5f76f30b`; **chapters 1–2 quote the OLD digests.** It also *confounded a drill*, so **print
  digests before AND after every experiment.**
  🚨 **The seeding collision is causally settled: concurrent startup writers.** Same image, `--workers 1`
  seeds cleanly; `--workers 4` reproduces `UniqueViolationError` on `categories_pkey` — 3 losers among one
  task's 4 workers, 0 in the other task (its guard saw data and skipped). **Mechanism:
  the bootstrap routine guards on 5 tables, deletes ten, COMMITS, then imports** — the committed empty
  state is what lets a second worker's guard pass. **A second routine in the same file carries a comment
  stating the deletion must NEVER be committed alone, citing an earlier incident — and the bootstrap path
  does it.** ⭐ **A fix in one path plus a prose warning did not protect the identical shape in the other;
  a comment cannot fail a build.**
  ⭐ **The app's signature, three instances: honest logs, dishonest outcomes.** (a) DB unreachable →
  retries 15× → `Application startup complete`; (b) `/health` → static 200, touches nothing; (c) seed
  collision → caught, **smaller dataset substituted**, `✅ Bootstrap complete`. **Status-code checks missed
  all three; log greps found all three.** Fingerprint for other environments: `using minimal bootstrap`.
  ✅ **`deploy_swarm.sh` now has a smoke gate** (dependency-exercising endpoint + body match + row floor).
  **Two of its own defects were found and fixed:** `SMOKE_MIN_ROWS` defaulted to 1 (a floor below the
  schema's own seed **cannot fail**) — now 100; and `|| echo 000` after `curl -w '%{http_code}'`
  double-printed, logging `HTTP 000000`. 🚨 **The floor works only because `/api/v1/data/summary` counts
  app-owned tables** — had it summed all 21, healthy would read 1621 and unseeded 939, and 100 would pass
  an app that never bootstrapped. **Rule: gate on rows the application creates, never on reference data.**
  ⚠️ **One experiment was VOID and had to be re-run:** `docker volume rm` failed, `2>/dev/null || echo
  "already gone"` hid the reason, and the "control" ran on the prior run's data while reporting a clean
  pass. **Never suppress stderr on a step the result depends on.** Also: **volumes are node-local**, so
  `volume rm` on the wrong node says `no such volume` — indistinguishable from success if stderr is
  discarded. And `docker stack rm` returns **before the containers are reaped**; wait for the containers,
  not just the network.
  📌 **APP-LAYER FINDINGS ARE HELD PRIVATELY in `working/capricorn-app-findings-2026-08-18.md`** —
  `working/` is gitignored, so it reaches the private GitLab mirror and never public GitHub. It holds the
  committed-delete regression with its patch, **an unauthenticated destructive HTTP route** whose guard
  covers half the tables it deletes, and a third item on what is already public. 🚨 **Do not restate those
  specifics in tracked files**, and remember `push_github.sh` cannot catch this class — it screens for
  secrets, not for a precise description of where a secret lives.
  🚨🚨 **THE BIGGEST FINDING CAME FROM TAKING A SNAPSHOT, NOT A DRILL — `restart_policy: on-failure`
  loses replicas on every clean reboot.** All three VMs were gracefully shut down for
  `s04-drills-complete` and restarted: Raft re-formed, all nodes `Ready`, **no error anywhere**, and the
  stack sat at `backend 1/2`, `frontend 1/3`, `redis 0/1` indefinitely. **Discriminator: a container that
  exits 0 (clean SIGTERM) becomes task state `Complete` — a SUCCESS — and `on-failure` never replaces it;
  containers that VANISHED became `Failed` and were replaced.** Postgres survived **only by luck**, via
  the `Failed` path. ⭐ **In production this is a rolling-patch bug** — reboot nodes one at a time for
  kernel updates and every cleanly-exiting service comes back short, silently. ⭐ **It also INVERTS the
  week's other lesson: replica count is the ONLY signal that catches this**, while `docker service ps`
  reports `Complete` and health endpoints return 200 — so counts *and* `UpdateStatus` are both required
  and **fail in opposite directions**. ✅ **Fixed: `condition: any` on all four services, `max_attempts`
  removed** (same bug, other route), verified in the LIVE SPECS, stack recovered 2/2 3/3 1/1 1/1.
  ⚠️ **`s04` captures the BROKEN policy** — a restore reintroduces it. Also verified: **the Raft leader
  moved to `docker-swarm-2`** (leadership is not sticky across a simultaneous reboot), and
  **`UpdateStatus` is ABSENT, not empty**, until a service is first updated (`map has no entry for key`)
  — ⭐ the one place suppressing stderr is RIGHT, because the code handles the silence, unlike the
  precondition case above.
  📌 **GITHUB PUSH IS HELD (Andrew's call, Aug 18):** the drill commit describes Capricorn source and an
  unauthenticated destructive endpoint; it lives on the **private GitLab mirror only**. Do not push
  `main` to `origin` without asking.
  ⭐ **Andrew's paste-runner (Aug 18):** paste command blocks into
  `education/*/scripts/run_commands.sh` (git-ignored) and execute the file rather than pasting into an
  interactive shell — **this eliminates the mispaste class outright**, since both prior incidents were
  lines stolen from the input buffer while `ssh` connected. Rules: never type a secret into it (it lives
  on the CIFS share), always give it `set -euo pipefail`.
  🎯 **PART 3 IS ALSO COMPLETE (Aug 13, 2026, 2:20–4:12 PM) — Capricorn runs on the swarm:** `backend`
  2/2, `frontend` 3/3, `postgres` 1/1 (pinned `docker-swarm-1`), `redis` 1/1; UI on `:5001`, API on
  `:5002` answering from **all three nodes**; Capricorn's repo untouched (rule B7 held).
  **`education/docker-swarm/manifests/capricorn.stack.yml`** + **`scripts/deploy_swarm.sh`** are
  committed, and **chapters 1 and 2 are WRITTEN** (3 figures, docx built, `figcheck` passes).
  🚨 **The finding that matters, because our first explanation was WRONG: a node's daemon NEVER reads
  the CLI's `~/.docker/config.json` when running a task** — only the client does; the agent
  authenticates *solely* with the credential `--with-registry-auth` freezes into the service spec. So
  **a manager has no more pull privilege than a worker**, and `docker pull` succeeding by hand on a host
  proves nothing about whether a task can pull there. Trap C1's frontend was `Rejected` on **all three**
  nodes including the manager. ⚠️ **And our own diagnostic `docker pull`s manufactured the confusing
  symptom** — they warmed the local image cache so postgres/backend *looked* fine on `.191`, leaving the
  never-pulled frontend as the only honest failure. **`METHOD.md` now carries this as a standing note.**
  🚨 **Two false greens to design against forever:** (a) `docker stack deploy` **exits 0 when the
  manager ACCEPTS desired state**, not when anything runs; (b) **replica count is not convergence** —
  `order: start-first` holds `3/3` through a full replacement, and `failure_action: rollback` restores
  the old version *at full replicas*, so a count-only check reports a **rejected deploy as a success**.
  Check `UpdateStatus.State` and treat `rollback_*` as failure. ⚠️ **Two claims logged as UNVERIFIED
  until trap C6 — do not teach as fact:** the registry credential is a *latch* (token expiry breaks
  future task *reschedules* silently, not the deploy), and `UpdateStatus` may persist such that a stale
  `rollback_completed` fails a healthy cluster. **Also: blast radius is selective** — adding
  `--with-registry-auth` recreated the three private-registry services and left Docker Hub's
  `redis:7.2.4-alpine` untouched, bouncing a working postgres purely for sharing a registry; a third
  run with an unchanged file recreated **nothing**. ⚠️ **Debt: trap C2 is CONTAMINATED** (pre-warmed
  postgres means the backend never met a cold DB) — **it needs a restore to `s02-swarm-up` to run
  honestly.** **Next: Part 4 — a CI runner that calls `deploy_swarm.sh` unchanged.**
  🎯 **NEW DELIVERABLE, scoped Aug 13 and deferred to the END of the track:** a **read-only
  `docker-admin.sh`** Andrew can take to work — *"takes inputs, helps me investigate outages, outputs
  issues and suggestions about how to investigate further or fix them."* **He will ask for a dedicated
  long design session; do NOT build it incrementally.** ⚠️ **This is an inference engine, not a command
  wrapper, and that changes what we collect NOW:** every failure must be recorded as a decision rule
  with five fields — **signal / interpretation / discriminator / next command / fix + blast radius** —
  because the *discriminator* (what separates this cause from others producing the same signal) is only
  knowable while the failure is in front of us. **Traps C2–C7 are six rule-generating opportunities;
  capture them as they fire or reconstruct them later from guesses.** Spec + growing ledger live in
  **`education/docker-swarm/COMMANDS.md`** (§11), which indexes every command by *the question it
  answers* rather than by chapter. 🚨 **Design against confidently-wrong advice:** show the evidence that
  matched, rank by confidence, and separate "I observed this" from "commonly caused by" — our own C1
  experience is the case study, since the obvious explanation was wrong and a tool asserting it would
  have been believed.
  **PARTS 1 & 2 ARE COMPLETE (Aug 13, 2026): `docker-swarm-1/2/3` exist at `.191/.192/.193`**, cloned
  from template 9000, 2 vCPU / 4 GB / 40 GB each — funded by the 16 GB VM 186 gave back on Aug 12 —
  personalized, **Docker 29.7.2 / Compose v5.4.0**, snapshotted **`s01-base-clean`** (hot, ~1.6 s each).
  **Part 2 formed a THREE-MANAGER cluster** — `.191` Leader, `.192`/`.193` Reachable,
  `ClusterID n6waq5uhc7o6yxzt5tyzrbol9`, **quorum 2 of 3**, ingress overlay `10.0.0.0/24`, no services
  yet, all three snapshotted **`s02-swarm-up`**. 🙋 **Andrew drove Part 2 by hand** (init + the `.192`
  join); the AI joined `.193` under the repetition rule. 🚨 **Three Swarm facts that will cost time
  later:**
  (a) `swarm init` prints the **WORKER** token — pasting it yields a healthy-looking 1-manager cluster
  with no quorum lesson left; use `docker swarm join-token manager`; (b) **`Autolock Managers: false`**,
  so the Raft key is on disk in the clear and **the VM snapshots will contain `docker secret` values**
  once Part 3 runs; (c) **swarm CA certs expire 3 months out** — restoring an older snapshot gives a
  cluster whose certs expired while frozen, which presents as a network fault and is not one. The end
  goal is
  unchanged: **Capricorn from the existing registry images**, deployed by a **manual job in THIS
  repo's** `.gitlab-ci.yml`, *not* Capricorn's.
  👉 **Open the next session by re-walking the file's `📌 READ THIS FIRST` pre-flight list.** It sorts
  every caveat into four kinds so they cannot be mistaken for one another: **🅐 open items**,
  **🅑 seven hard rules**, **🅒 seven deliberately planted traps that must NOT be fixed in advance**
  (pre-empting them turns the phase into a tutorial where nothing fails), and **🅓 inherited findings
  that are out of scope**. **Pre-flight status after Aug 13: A1, A4 and A5 closed; A5 = the stack file
  and scripts live in `education/docker-swarm/{manifests,scripts}/`; A2 (does this repo gain a
  `.gitlab-ci.yml`) is DEFERRED to Part 4 because it is one decision with the `workflow: rules:`
  guard; A3 stays deferred into Part 5 by design.** No open item blocks Part 2.
  **Part 1 findings that save a later session time:**
  - ✅ **`growpart` worked** — the plan's loudest warning was a non-event. But **`df -h /` reads 38G,
    not 40G**, because `sda15` (106M EFI) + `sda16` (913M `/boot`) come out of the 40 GB virtual disk.
    **38G is correct; do not hunt the missing 2 GB.**
  - ⚠️ **`host_setup.sh` DOES install Chrome + Cursor on a headless cloud image.** The desktop branch
    triggers on `gnome-shell` **or `gsettings`**, and the Ubuntu 24.04 cloud image ships `gsettings`.
    Purging took each node 4.4 GB → **2.2 GB used**. Always apply this to a template-9000 clone.
  - ✅ **`refresh.sh` needed no edit** — it targets an explicit allow-list (`.180`–`.184`), so new VMs
    are excluded by construction. The guest half still mattered: `unattended-upgrades`, `apt-daily`
    and `apt-daily-upgrade` are **masked** on all three.
  - ✅ **No `191/192/193.fw` exists**, so the guest firewall is off despite `firewall=1` on the NIC and
    Swarm's `2377`/`7946`/`4789` are unobstructed. ⚠️ Adding a `19x.fw` later **without those three
    rules breaks the cluster silently.**
  - ✅ Registry reachable from a node: `curl http://gitlab.gothamtechnologies.com:5050/v2/` → **401**.
    `/etc/docker/daemon.json` carries the `insecure-registries` entry on all three, courtesy of
    `setup_docker.sh` — which was the whole argument for using the standard script.
  - Scripts are committed and idempotent: **`education/docker-swarm/scripts/provision_nodes.sh`**
    (runs on the pve host) and **`post_setup.sh`** (runs on each node).
  ⚠️ **Three facts established Aug 12 that a later session should not waste time re-deriving:**
  - **The GitLab runner is not a blocker.** Runner `id=2` is **`instance_type`** (instance-wide shared,
    not project-scoped to Capricorn), active, `run_untagged=true`, and already available to
    `production/home-lab-setup` (project id 6), which has `builds_enabled=true` and
    `shared_runners_enabled=true`. So Part 4 needs no runner work — **but it also means dropping in a
    `.gitlab-ci.yml` starts producing a pipeline on every `push_gitlab.sh` backup**, which is why the
    `workflow: rules:` guard is part of the decision rather than polish.
  - **Capricorn is stateful** — postgres + redis with named volumes `postgres_data_prod` /
    `redis_data_prod` and a bind mount for DB init scripts. This is why Part 5 is a real exercise, and
    why the centrepiece drill is **"a Swarm named volume is node-local, so a rescheduled postgres comes
    up healthy against a brand-new empty database"** — silent data loss that looks like a clean deploy.
  - **Two problems with `/opt/capricorn/docker-compose.yml` on `.184`, both recorded and NEITHER ours
    to fix** (application layer — raise with whoever owns Capricorn):
    - **Config drift.** It declares `postgres:15.5-alpine` while the **running container is the custom
      `production/capricorn/postgres:latest`**. "Just redeploy from the compose file" would quietly
      change PROD's database image.
    - 🚨 **Plaintext credentials, and they are a copy-paste hazard for us.** There is **no `.env`** —
      `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` and a password-bearing `DATABASE_URL` are
      written **inline in the compose file**. Any lab work that starts from that file as a template
      puts a **production database password into this repo, which has a public GitHub remote.**
      ⚠️ **`push_github.sh` would probably catch the `DATABASE_URL`** (its URL-with-embedded-password
      gate) **but would NOT catch a bare `POSTGRES_PASSWORD=` line** — the protection is partial and
      accidental, so do not lean on it. Phase 16 hard rule B7 forbids the copy outright and uses
      `docker secret` with invented lab-only credentials instead.

- **✅ CLOSED — Phase 14: Kubernetes + Redpanda POC (was interview prep).** 📦 **The 332-line block that
  was here was DEMOTED VERBATIM to `phases/phase14_k8s_redpanda_poc.md` on Aug 20, 2026** (see its
  "DEMOTED VERBATIM" section at the end) — a closed interview-prep phase was holding **14 % of this
  always-loaded file**, and **k3s/Kubernetes is explicitly OUT OF SCOPE for Phase 17.**
  ⛔ **What it costs you to skip it — this is not "background reading":** the phase left **VM 186
  `.186` (`vm-k8-redpanda-1`) RUNNING** with a live single-node k3s and a 3-broker Redpanda cluster,
  and **VM 200 no longer exists** (it became `.180` `vm-docker-qa-1`). ⚠️ **`.186` is deliberately
  frozen: `unattended-upgrades` is masked and it is NOT in `refresh.sh`, so DO NOT "bring it up to
  date"** — the whole point is an unchanging cluster to learn on. 🚨 **And do not reach for
  `k3s-uninstall.sh` to "get a clean cluster"**: several planted-state facts and ~40 hard-won details
  (the local-path PV layout, `ALLOWVOLUMEEXPANSION=false`, the `Error:137` OOM signature, the consumer
  rebalance timings) live **only** in that demoted block, and re-deriving them is days of work.
  📖 It is also the source track for `education/k3s/` — **the `ch01_fig1_stack.dot` VMID/label error
  fixed on Aug 20 came from here**, so a future diagram edit needs it.

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
    ~~**VM 185 (OpenClaw) stays dormant as-is** (not destroyed).~~ ⛔ **SUPERSEDED Aug 19, 2026 —
    Andrew ordered VM 185 killed and removed. It is totally gone: destroyed with `qm destroy 185
    --purge`, no backup taken (declined on purpose), no snapshot existed. Verified: config file gone,
    no ZFS volumes left on `vm-critical`, and `--purge` removed `/etc/pve/firewall/185.fw` too.
    16 GB + 12 cores returned to the host. VMID 185 and `.185` are now Jenkins (Phase 17).**
  - 📌 **STANDING RULE (Andrew, Aug 13, 2026) — ALL vzdump backups go to the NAS under
    `/ProxmoxBackups/<vm-name>/`, NEVER to NVMe.** Per-VM folders require **one CIFS storage per VM**
    (`--subdir /ProxmoxBackups/<vm-name>`) because PVE dumps everything into a single `dump/` per
    storage. Defined: `nas-gitlab` (181), `nas-docker-swarm-1/2/3` (191/192/193, `keep-last=3`).
    Full recipe + gotchas in `proxmox/Home_Lab_Proxmox_Storage.md` → *Backup Strategy*.
    - 🚨 **SCHEDULED jobs are much rarer than storages — as of Aug 20, 2026 there is exactly ONE:**
      `gitlab-nightly` (181, 02:00, keep 7). **A defined storage is NOT a backup.** 191/192/193 each
      hold **one hand-made dump from Aug 13 and have no schedule**, and **180, 184 (WWW/PROD), 186,
      and 9000 have no backup at all.** Don't infer coverage from `pvesm status`; read
      `/etc/pve/jobs.cfg`.
    - 📌 **RULING (Andrew, Aug 20, 2026) — VM 180 (QA) is deliberately NOT backed up.** A
      `nas-docker-qa` storage + nightly job were built and a 10.66 GB archive proven, then **removed
      the same day on his instruction.** ⭐ **The reasoning generalises: QA is rebuildable from GitLab
      CI, so it is a deploy target, not a data store — only irreplaceable state earns a backup.**
      Do not "helpfully" re-add it.
    - 📊 **Sizing datapoint kept from that one run** (VM 180, 100 GB disk, ~15 GB used): live
      `snapshot` mode with the guest agent took **2m20s** for a **10.66 GB** archive — **80% of the
      disk was zeros** and sparse-skipped. Archive size tracks *used* data, not provisioned size.
    - 🚨🚨 **`/etc/pve/priv/storage/<id>.pw` is `password=<value>` + newline, NOT a bare password.
      THIS HAS NOW BURNED TWO SEPARATE SESSIONS (Jul 2026 and Aug 20, 2026). Read it before you
      touch NAS auth.** A 9-char password = 19 bytes on disk. Two distinct failures come from the
      same misread:
      - **Writing it:** pre-placing a bare password is malformed, and `pvesm add` fails
        `NT_STATUS_LOGON_FAILURE` — an auth-shaped error for a format problem. **Pass `--password`
        and let PVE write the file.**
      - **Reading it:** `mount -t cifs ... -o password=$(cat …pw)` sends the literal string
        `password=Powerme!1` and returns **`mount error(13) Permission denied`**, which looks exactly
        like a NAS ACL problem. **Type the real password from `PASSWORDS.md` instead.**
      ⭐ **The distilled lesson, which is why this keeps happening: A BYTE COUNT IS NOT A VALUE.**
      Both sessions inferred the password's length from `wc -c` and never opened the file.
      ⚠️ **And stop after 3–4 failed SMB auth attempts** — Synology-style auto-block trips near five
      and would blackhole the Proxmox host, killing the nightly GitLab backup and every guest's
      `/mnt/DevShare`.
    - ⚠️ **`pvesm set --password` needs `--username` in the same call** even when the config already
      has one, or it warns `no user set` and writes an EMPTY password.
    - ⚠️ **The `subdir` must exist on the NAS first**; PVE will not create it, and it cannot be
      created *through* its own storage (the subdir is part of the mount source).
    - ⚠️ **vzdump excludes snapshots** — the archive is current disk state only.
  - ❌ **RETRACTED same day — there was NO stale `nas-gitlab` credential and NO pending backup
    outage.** The AI read `wc -c` = 19 as "an 18-char password", then built a test authfile as
    `password=$(cat …pw)` → `password=password=Powerme!1`, which fails to authenticate. Two tests
    agreed because **both inherited the same wrong parse of the file.** ⭐ *A byte count is not a
    value, and two tests sharing an assumption are not two confirmations.* Full write-up in
    `proxmox/Home_Lab_Proxmox_Storage.md`. ✅ **Net gain anyway:** `nas-gitlab` has now been
    unmounted/remounted twice with a write test — its reboot path is *proven*, not assumed, for the
    first time since Jun 18. The true part kept: **a live CIFS mount is not evidence of a working
    credential**, since CIFS never re-authenticates an existing mount.
  - **Audit discoveries:** host runs Tailscale (100.108.209.77, `pve` on tailnet); idle Quadro
    P2000 GPU (nouveau, passthrough candidate); SNC enabled in BIOS → 2 NUMA nodes (64G each);
    only 4/6 memory channels populated (⚠️ **slot numbers in that audit are wrong — corrected in
    `phase0_hardware.md`; the free slots are `CPU0-DIMM3/4`**); fallback kernel 6.17.2-1 no longer
    on ESPs.
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
    185 skipped (was dormant, ⛔ destroyed Aug 19, 2026). ⭐ **Phase 17's Jenkins VM needs the agent
    installed** so `vzdump` can fs-freeze it rather than taking a crash-consistent copy.
  - **Still open/optional:** ~~2x32GB DIMMs for 6-channel bandwidth~~ ⏸️ **ON HOLD Aug 19, 2026 —
    now ~$600 (32GB DDR4 ≈ $300 each, DDR4 is EOL), the gain is still UNMEASURED, and the free
    levers come first: cap `zfs_arc_max` (unmeasured) + measure VM working sets. Slots are
    `CPU0-DIMM3/4`. The Z8 is also 4-of-6 per socket, so it is NOT a donor — `phase0_hardware.md`**;
    tailscaled NetInfo log
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
    the old 184.fw had been inert). Other VMs have no .fw files → unaffected (185.fw existed until
    Aug 19, 2026 — ✅ **verified that `qm destroy --purge` deletes a VM's `.fw` file along with it**;
    it is gone now that the VM is). Rollback: `/root/184.fw.bak-20260708` on pve, VM snapshot
    `pre_phase12_firewall`.
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
- **Phase 11 ~~COMPLETE~~ RETIRED:** OpenClaw AI Agent Server was live at `.185` (Tailscale Serve, Telegram) → ⛔ **VM destroyed Aug 19, 2026, totally gone.**
- **`refresh` command on Proxmox:** Parallel update + reboot of all 5 VMs (.180-.184), live status display. See REFRESH SCRIPT section. ⭐ **Phase 17 adds `.185` (Jenkins) to the allow-list** — and `unattended-upgrades` stays masked there on purpose, so `refresh` is the only patching path for a host that must not restart mid-build.
- Next: Phase 8 (Monitoring Stack)

---

## IPs & HOSTS

| Host | IP | Status |
|------|-----|--------|
| Proxmox | .150 | ✅ Running — `ssh root@192.168.1.150`, key auth ✅ (via `authorized_keys2`, Aug 12 2026) |
| **QA** | **.180** | ✅ LIVE — **VMID 180, hostname `vm-docker-qa-1`** as of Aug 20, 2026. **Capricorn QA server** (`:5001` frontend, `:5002` backend, auto-deploy on `develop` push), plain `docker compose` — NOT Swarm. ⛔ **The only Kubernetes in this lab is k3s on VM 186.** The old misnamed `vm-kubernetes-1` (VMID 200) was cloned to this one and is now **stopped, `onboot 0`, awaiting destroy after ~Sept 3, 2026** |
| GitLab | .181 | ✅ LIVE |
| Runner | .182 | ✅ LIVE (gitlab-runner-1) |
| SonarQube | .183 | ✅ LIVE (vm-sonarqube-1, v26.1.0) |
| **WWW** | **.184** | **✅ LIVE (vm-www-1, Traefik, Capricorn PROD, Splash)** — 🚫 **PROD-LOCAL: no NAS mount, no `/mnt/DevShare`, no `.smbcredentials`** (removed Aug 20, 2026; Phase 12 DMZ blocks the LAN). Rebuild it with **`host_setup.sh --no-nas`** |
| **~~OpenClaw~~ → Jenkins** | **.185** | ⛔ **OpenClaw DESTROYED Aug 19, 2026 (totally gone).** VMID 185 + `.185` reassigned to `vm-jenkins-1` — Phase 17 |
| **K8s/Redpanda POC** | **.186** | **🔵 BUILT July 25, 2026 (vm-k8-redpanda-1, Phase 14 sandbox) — `ssh agamache@192.168.1.186`, key auth ✅.** 🖥️ **Cockpit web UI at `https://192.168.1.186:9090/`** (added Aug 20, 2026) — log in with the `agamache` fleet password, self-signed cert so click through the warning. ⚠️ **`onboot 0`, so it is offline until you `qm start 186`** |

### 🖥️ COCKPIT — now STANDARD on every Ubuntu server we build (Andrew's call, Aug 20, 2026)

⭐ **Don't hand-install it — it is baked into the build.** `www/scripts/setup_cockpit.sh` runs in
**Phase 1 of `host_setup.sh`**, alongside SSH and sudo (it is an *access* method, not a tool: if a
later step wedges the box, Cockpit is already a second way in). Full write-up in
`phases/phase2_host_setup_automation.md` § "3. setup_cockpit.sh". The notes below are the *why*, kept
here because the trap will bite anyone who installs it manually on an existing box.

⭐ **The script simulates the install and REFUSES to proceed if `network-manager` appears.** A comment
saying "don't pull NetworkManager" gets ignored a year from now; a script that exits 1 does not. It
also auto-includes `cockpit-networkmanager` **only** on hosts where NetworkManager is already active
(desktop builds), where the module manages what is already in charge.

🚨 **NEVER `apt install cockpit` on these VMs.** The metapackage **Recommends `cockpit-networkmanager`,
which drags in `network-manager`** — and every lab VM runs **netplan + systemd-networkd**. Letting
NetworkManager onto a box whose interfaces are already managed elsewhere risks losing the network on a
machine you administer over SSH. Verified by simulation before installing: the metapackage pulls
`network-manager`, `dnsmasq-base`, `ppp`, `wpasupplicant` and 10 NM-related packages. **Install the
parts explicitly instead:**

```bash
sudo apt-get install -y cockpit-ws cockpit-bridge cockpit-system cockpit-storaged cockpit-packagekit
# simulate anything unfamiliar first:  apt-get install -s <pkgs> | grep ^Inst
```

Measured on a swarm node, Aug 20 2026: the metapackage adds **35** packages including
`network-manager`, `network-manager-pptp`, `pptp-linux`, `dnsmasq-base`, `ppp`, `wpasupplicant`,
`wireless-regdb`. The explicit list adds **19** and none of those.

- **Socket-activated** (`cockpit.socket`, enabled automatically) — it listens on **9090** and only
  spawns the web server on a connection, so idle cost is ~nothing. Good on a POC box.
- **Login is PAM**, so the user needs a real password: `passwd -S <user>` must show **`P`**, not `L`.
  ⛔ **A key-only account cannot log into Cockpit.** `sudo` group membership enables *Administrative
  access* inside the UI.
- **Self-signed cert**, so browsers warn. ⚠️ **The Cursor built-in browser CANNOT open it at all** —
  it fails `ERR_CERT_AUTHORITY_INVALID` with no "proceed anyway". Use a real browser.
- ⭐ **Verify auth without a browser** — this is the real proof it works:
  `curl -sk -u user:pass https://<ip>:9090/cockpit/login` returns **`{"csrf-token":...}`** on success
  and an *Authentication failed* page on a bad password. ⚠️ **`/login` is the wrong path** — it serves
  the HTML login page and returns 200 for good AND bad credentials, so testing it proves nothing.

---

## CREDENTIALS

**File:** `/proxmox/credentials`

- Proxmox: root / [See PASSWORDS.md]
- All VMs: agamache / [See PASSWORDS.md]
- **SSH key auth:** ✅ ed25519 key deployed to ALL VMs (.180–.186) from dev workstation
  (Feb 27, 2026; **.186 inherited it from the cloud-init template**, verified working Aug 12, 2026).
  - ⚠️ **The login user on every VM is `agamache`, never `andrew`.** `ssh andrew@192.168.1.186`
    fails with `Permission denied (publickey,password)`, which reads exactly like a missing key and
    sends you off fixing a problem that does not exist. Verified working:
    `ssh agamache@192.168.1.186` → `kubectl` and `rpk` are on `PATH` with `~/.kube/config` already
    in place, and `sudo -n` needs no password.
  - ✅ **Proxmox HOST key auth added Aug 12, 2026 — `ssh root@192.168.1.150` now works with the
    workstation key**, so `qm` work no longer needs the password from PASSWORDS.md.
    - **The key went in `/root/.ssh/authorized_keys2`, deliberately NOT `authorized_keys`.** The
      latter is a **symlink to `/etc/pve/priv/authorized_keys`** — a PVE-managed file on the cluster
      filesystem that holds only the cluster's own `root@pve` RSA key, and that PVE rewrites on
      cluster operations. `sshd -T` on the host reports
      `authorizedkeysfile .ssh/authorized_keys .ssh/authorized_keys2`, so the second file is read
      natively: **no sshd config change and no service restart were needed.**
    - Verified with password auth explicitly disabled
      (`ssh -o PreferredAuthentications=publickey -o PasswordAuthentication=no root@192.168.1.150`),
      which is the only way to prove the key is doing the work rather than a silent password
      fallback. `sshd` was left untouched: `permitrootlogin yes`, `passwordauthentication yes`.
    - ⚠️ Until Aug 12 this was the trap that made host work painful, and it is the *same* trap
      documented in the cloud-init section: the workstation key lives in
      `/root/cloudinit-keys-all.pub`, which **sshd never reads**. If host key auth ever stops
      working, check `authorized_keys2` still exists before assuming anything else.
- **GitLab Web: root / [See PASSWORDS.md]**
- **SonarQube Web: admin / [See PASSWORDS.md]**
- NAS (SMB): fiberoptix / [See PASSWORDS.md] @ 192.168.1.120

### SSH ACCESS MATRIX — the intended policy, fully verified Aug 12, 2026

**The policy Andrew wants, and which now holds:** key auth from the dev box to *everything* with
password as fallback, and **password-only** access from any other machine (laptop while remote).

| Target | User | Key auth from dev box (.195) | Password fallback | From remote tailnet |
|---|---|---|---|---|
| **.150 pve** | `root` | ✅ (`authorized_keys2`) | ✅ | ✅ direct, it *is* the tailnet node |
| **.180 vm-docker-qa-1** | `agamache` | ✅ | ✅ | ✅ via subnet route — **the Aug 20 clone kept the same SSH host keys, so `known_hosts` did NOT need clearing** |
| **.181 vm-gitlab-1** | `agamache` | ✅ | ✅ | ✅ via subnet route |
| **.182 vm-gitrun-1** | `agamache` | ✅ | ✅ | ✅ via subnet route |
| **.183 vm-sonarqube-1** | `agamache` | ✅ | ✅ | ✅ via subnet route |
| **.184 vm-www-1** | `agamache` | ✅ | ✅ | ✅ — see the firewall note below |
| **.185** | — | ⛔ **vm-openclaw-1 DESTROYED Aug 19, 2026.** Address free; Phase 17 rebuilds it as `vm-jenkins-1` | — | — |
| **.186 vm-k8-redpanda-1** | `agamache` | ✅ | ✅ | ✅ via subnet route |

Every VM reports `passwordauthentication yes` with `agamache` holding a usable password
(`passwd -S` → `P`), and the host the same for `root`. **Proven by test, not by reading config** —
password-only logins were confirmed with `ssh -o PubkeyAuthentication=no
-o PreferredAuthentications=password` against .150, .181, .184 and .186. Config that *says* yes and
an account whose password is locked look identical until you try it.

**How remote (laptop) access actually works — this is the part worth understanding:**

1. **The pve host is a Tailscale subnet router.** It advertises **`192.168.1.0/24`**, and the route
   is approved (it shows in `PrimaryRoutes`). So any device on the tailnet can address
   `192.168.1.x` directly — there is no need to put Tailscale on each VM. ⛔ **Corrected Aug 19, 2026:
   `.185` used to be the only VM running Tailscale, and it was destroyed — so NO VM runs Tailscale
   now.** Remote access depends entirely on the subnet route advertised by the pve host.
2. **Subnet routing SNATs by default** (`NoSNAT: false`). Traffic from a remote laptop therefore
   arrives at the VMs **with a source IP of `192.168.1.150`**, not the laptop's `100.x` address.
3. ⚠️ **That SNAT is what makes .184 reachable at all.** `184.fw` is `policy_in: DROP` and permits
   port 22 from only three sources — `.182` (runner), `.195` (dev box) and **`.150` (the host)**.
   Remote traffic passes *because* it is rewritten to `.150`. Verified by SSHing from the pve host to
   all six live VMs, which is the same post-SNAT path.
4. ⚠️ **The corollary: remote logins are indistinguishable from host logins in the VMs' auth logs** —
   everything appears to come from `.150`. Do not build fail2ban rules, audit trails or source-IP
   allow-lists on VM-side source IPs and expect them to identify a remote user.
5. **The tailnet devices that matter:** `bullpup` (macOS laptop) and `fibermedia` (macOS).
   ⚠️ **This dev box is NOT on the tailnet** — `agamache-z8g4` on the tailnet is the *Windows Z8
   host*; the dev box is the VMware guest inside it. Remote work from the dev box goes via Windows.
6. **No guest-level firewall is in the way:** `ufw` is `inactive` on all six live VMs. **Only .184 has
   PVE-level rules** (`.185`'s went away with the VM on Aug 19, 2026); `cluster.fw` is enabled but
   carries no rules of its own.

---

## REMOTE LAB MANAGEMENT (laptop, outside the house) — verified Aug 12, 2026

**Answer to "can I manage the lab from my laptop over the tailnet?" — yes, completely.** Every link
below was tested, not inferred. **There are two routes**, and they differ in one important way:
**Route A puts plaintext credentials on the laptop, Route B does not.** Prefer B.

### Route A — work from the laptop itself (requires cloning the credentials)

1. **Tailscale up on the laptop.** The **pve host is the tailnet's subnet router**, advertising an
   approved **`192.168.1.0/24`**, so every LAN address is directly reachable. No VM needs Tailscale.
2. **DNS needs no setup.** `gitlab.gothamtechnologies.com` resolves to **`192.168.1.181` from public
   DNS** (verified against `8.8.8.8`) — a private address published in public DNS. You do **not**
   need an `/etc/hosts` entry on the laptop.
3. **Clone the GitLab mirror to get the credentials** (see the warning below):
   ```bash
   git clone http://root:<pw>@gitlab.gothamtechnologies.com/production/home-lab-setup.git
   ```
   Verified from a post-SNAT source: the `git-upload-pack` endpoint returns **HTTP 200** with the
   root credentials and **401** without, so auth genuinely works over the tailnet path.
4. **Then manage everything** — SSH by password to `root@.150` and `agamache@<any VM>`, plus the
   **Proxmox web UI on `.150:8006`** (open, verified) for console, snapshots and start/stop.

⚠️ **Clone GitLab, NOT GitHub — GitHub has no credentials at all.** `PASSWORDS.md` is gitignored, so
it is **absent from GitHub's `main`** along with every other secret. The **GitLab mirror is the
plaintext snapshot** and is the only place that carries `PASSWORDS.md`, `github_credentials.md`,
`proxmox/credentials`, `proxmox/nas_credentials` and `www/scripts/smb_credentials`. **No private keys
are tracked in either remote** (verified) — that is deliberate and should stay true.

### Route B — tailnet into the dev box, then drive the pve **GUI** (no credential clone needed)

**This is the better route when the goal is "manage the lab", and it avoids putting `PASSWORDS.md`
on the laptop at all.** The dev box already holds the SSH keys and this repo, so once you are on it
you are in exactly the position you are in at home.

⚠️ **Precisely: you cannot Tailscale *into the dev box itself* — it is not a tailnet node.**
Tailscale is **not installed** on it (no binary, no `tailscaled`, no `tailscale0`), verified
Aug 12, 2026. The tailnet's `agamache-z8g4` is the **Windows Z8 host** (`100.70.244.97`, LAN
`192.168.1.115`); the dev box is the **VMware Workstation guest inside it** (`VM-UBUNTU-01`, `.195`).
So the Windows host is the entry point and the dev box is one hop further in.

```
laptop ──tailnet──► agamache-z8g4 (Windows Z8, RDP :3389 verified OPEN)
                        ├──► browser ──► https://192.168.1.150:8006     (pve GUI, quickest)
                        └──► VMware Workstation console ──► VM-UBUNTU-01 (.195, the dev box)
                                                              └──► pve GUI + SSH keys + this repo
```

**Why prefer landing on the dev box:** its SSH keys reach the host and every VM (see the access
matrix), and the repo with `PASSWORDS.md` is already there — so **no plaintext credentials ever touch
the laptop**, which removes the biggest risk in Route A.

**Three ways to reach the Proxmox GUI at `https://192.168.1.150:8006`** (port verified open),
cheapest first — pick by how much capability you need:

1. **Laptop browser, straight there.** The subnet route makes `.150:8006` reachable with no clone and
   no RDP. Log in `root` / PVE password. **Enough for start/stop, console, snapshots and `qm` work.**
2. **RDP to the Windows Z8, use its browser.** Same GUI, full desktop, and it does not depend on
   `.150`'s `tailscaled` (see gap 3).
3. **RDP to the Windows Z8 → VMware console → dev box.** The full working environment: Cursor, this
   repo, and key-based SSH to the host and every VM. Slowest to reach, most capable once there, and
   the only one that can push to GitHub.

> **Optional improvement, not done:** installing Tailscale **on the dev box** would make it a direct
> tailnet node and remove the RDP hop entirely. Worth considering if remote work becomes routine —
> it would make Route B as cheap as Route A while keeping the no-credentials-on-laptop benefit.

### Three real gaps — know these before you rely on remote access

1. ⚠️ **Route A cannot push to GitHub** (Route B can). `origin` is `git@github.com:...` over **SSH**,
   and the private key is (correctly) not in the repo; `github_credentials.md` holds a password and
   an SSH-key reference but **no personal access token**. **GitLab pushes work fine** from either
   route (credentials are embedded in the remote URL), so laptop work can be committed and mirrored —
   just not published to GitHub until you are home, on the dev box, or the laptop's key is registered.
2. ⚠️ **Route A has a bootstrap circularity:** you need the **GitLab root password to obtain the file
   that stores your passwords.** It is the standard lab password, so in practice fine — but it must
   **also** live in a password manager, never only in this repo. Route B sidesteps this entirely.
3. ⚠️ **No out-of-band console exists.** If you break the pve host's bridge or firewall while remote,
   **nothing recovers it until you are physically home** — neither route helps, because both
   ultimately need `.150` to be up and on the network. **Treat any network or firewall change on
   `.150` as unsafe to attempt remotely.**
   - ✅ **But remote *entry* is no longer single-path.** `.150`'s `tailscaled` is only required for
     **Route A**; **Route B enters through `agamache-z8g4`**, which is its own independent tailnet
     node with a direct connection. So if pve's `tailscaled` dies or the subnet route stops being
     advertised, **Route B still reaches the lab over the LAN.** That makes the Windows Z8 the de
     facto backup entry point — worth keeping powered on and RDP-reachable when travelling.
   - Also in place for Route A: `tailscaled` on `.150` is `systemctl enabled` **and** the node's key
     has **no expiry** (`KeyExpiry: None`), so neither a reboot nor months away locks you out.

### Smaller notes

- **macOS and Windows accept advertised subnet routes by default**; a **Linux** laptop needs
  `tailscale up --accept-routes` or it will not see `192.168.1.0/24`.
- Tailnet laptops on file: `bullpup` (macOS), `fibermedia` (macOS). ⚠️ `agamache-z8g4` is the
  **Windows Z8 host**, not the dev box — the dev box (VMware guest) is *not* on the tailnet.
- 🔒 **Laptop hygiene (Route A only):** that clone writes the GitLab root password into `.git/config`
  and drops `PASSWORDS.md` in plaintext next to it. **A lost, unencrypted laptop is the whole lab.**
  Full-disk encryption is load-bearing, and the clone should be deleted when the trip ends. **Route B
  avoids all of this** — nothing sensitive is ever copied off the LAN.
- ⚠️ **The repo itself lives on the NAS, not on the dev box or the Windows host.** `/mnt/DevShare` is
  `//192.168.1.120/NeoCortex/DEV_Projects` over CIFS (per `/etc/fstab`). So Route B depends on **`.120`
  being up** as well as `.150` — and it is the reason for the stale-cache hazard documented in the
  workstation gotcha at the top of this file. (The Windows Z8's open `445` is ordinary Windows file
  sharing and is *not* the source of this mount.)
- Remote logins reach the VMs **source-NATted as `192.168.1.150`** — see the SSH ACCESS MATRIX above
  for why that matters to `.184`'s firewall and to any log-based auditing.

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

### 🚨 What that socket mount actually costs (read out of config.toml, Aug 19 2026 — Phase 16 ledger L19)

Verbatim from `/etc/gitlab-runner/config.toml`:

```
executor = "docker"
  image = "docker:24.0"
  privileged = true
  volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock"]
```

**The docker socket is a root shell on `.182`.** Any job can `docker run -v /:/host` and read or write
the whole filesystem as root. Runner #2 is **`instance_type`** (instance-wide shared) with
`run_untagged=true`, so **every project on this GitLab can do that** — and `.182` is the host that runs
`deploy_prod_local` against real production.

⚠️ **A pipeline author CANNOT decline it.** `privileged` and `volumes` are *runner* config, so least
privilege is unavailable at the job level no matter how the `.gitlab-ci.yml` is written. Phase 16's
"the runner already exists and needs no setup" (item A1) was good news about effort and bad news about
blast radius. Fixing this is part of the **Phase 17 charter**, not a Phase 16 task.

### `docker:24.0` already ships an SSH client (verified Aug 19, 2026)

`docker run --rm docker:24.0 sh -c 'command -v ssh; command -v scp'` → `/usr/bin/ssh`, `/usr/bin/scp`,
on Alpine 3.20. **Mechanism:** the Docker CLI supports `ssh://` connection contexts, so the image must
carry one. So a deploy job on this image needs **no `apk add --no-cache openssh-client`** — unlike
Capricorn's `alpine:latest` jobs, which do. Pin `image:` in the job anyway, so a `config.toml` edit here
cannot silently change a job's toolchain.

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

### 🚨 containerd image store is DISABLED here on purpose (Aug 17, 2026) — do not "clean this up"

`/etc/docker/daemon.json` on .182 (backup: `daemon.json.bak-20260817`):

```json
{
  "insecure-registries": ["gitlab.gothamtechnologies.com:5050"],
  "features": { "containerd-snapshotter": false }
}
```

Verify with `docker info | grep -i 'storage driver'` → must say **`overlay2`**. If it ever says
`overlayfs` with `driver-type: io.containerd.snapshotter.v1`, the flag was lost and CI pushes will
start failing again.

**Why.** Docker 29.7.2 defaults to the containerd image store, which makes `docker build` emit **OCI
image indexes**. Its push path can send the **parent index before the child manifest** it references,
and the GitLab registry (v4.40.2) correctly rejects that:

```
PUT .../manifests/sha256:cdd1b210…  → 400  MANIFEST_BLOB_UNKNOWN (detail: sha256:ebc0db88…)
PUT .../manifests/sha256:ebc0db88…  → 201  ← the child, 5ms later
```

Symptom in CI is `error from registry: blob unknown to registry` on the push job while all builds
pass. **It is not a registry problem** — the blob is on disk and .181 had 440 GB free. It is also a
**race, not a certainty**, so it hides: it only bites when several images have genuinely new content
in one pipeline, and a job that changes one image will pass and look like proof the daemon is fine.

**How we got there — the actual lesson.** A **manual** `apt-get upgrade` on **Aug 10 17:18** (by
`agamache`, reboot 17:20) took docker-ce 29.6.2→29.7.2, containerd.io 2.2.6→2.3.3, buildx
0.35→0.36.1, gitlab-runner 19.2.0→19.2.1. **CI then stayed green for a week** and broke on Aug 17,
so nothing connected the failure to the upgrade. unattended-upgrades is enabled on all four VMs but
its `Allowed-Origins` is Ubuntu/ESM only and can never touch `download.docker.com` — **package holds
would not have helped.** The exposure is hand-run `apt upgrade` on the runner. Treat a Docker major
bump on .182 as a change that needs a deliberate CI test, not a routine patch.

**⚠️ After toggling this flag, images in the old store are invisible to the new driver** (`docker
images` reads empty). Retrying just the push job cannot work — there is nothing to push. **Run a new
pipeline**; the first one is a genuine full rebuild.

Application-side detail (Capricorn pipelines #159 fail → #160 green) is recorded in the Capricorn
project: `project/phases/phase25_all_states_tax_brackets.md`, "CI incident".

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

### 🚨 AUTOSTART POLICY (Andrew, Aug 20, 2026) — only FIVE VMs come back after a host reboot
**`onboot 1`: 180, 181, 182, 183, 184. Everything else is `onboot 0` and starts by hand** — that means
**186 (k3s POC) and 191/192/193 (the Docker Swarm)**, all four flipped from `1` to `0` on Aug 20, plus
200 (retired) and 9000 (template, never set). Rule of thumb: **the always-on service tier autostarts;
lab/POC gear does not.**

**Boot ORDER, set the same day** (`qm set <id> --startup order=N,up=S`; `up` = seconds to wait *after*
starting that VM before continuing):

| Order | VMs | Delay after |
|---|---|---|
| 1 | **181 GitLab** | `up=60` — everything else that talks to it gets a head start |
| 2 | **182 Runner, 183 SonarQube** | `up=10` each |
| 3 | **180 QA, 184 WWW** | — |

⚠️ **Consequence: 184 (public site) now waits ~80 s longer after a host boot than it used to**, because
it sits behind GitLab's delay. It has no actual dependency on GitLab — **if that ever matters, move it
with `qm set 184 --startup order=1`.** ✅ **No HA resources and no cluster exist, so `onboot` is the sole
authority** — nothing can restart a guest behind your back.

⚠️ **Operational consequence, do not be surprised by it: after any host reboot the Swarm is DOWN.**
Phase 17 deploys Jenkins → Swarm, so `qm start 191 192 193` (and let the cluster converge) is a
**prerequisite step for that work**, not an afterthought. Same for 186 before any k3s work.
✅ **Jenkins (185) BUILT Aug 20, 2026 and joined the autostart tier: `onboot 1`, `startup order=4`
(last).** Andrew's call — it is core infrastructure, and nothing else waits on it to boot.
⭐ **Startup order gives ORDERING, not READINESS.** GitLab CE takes minutes to actually serve, far
longer than its `up=60`, so Jenkins can be up before GitLab can answer an OAuth request no matter what
number it has. **That is not fixable with ordering — it is why Jenkins keeps a break-glass local
admin.**

### 🚨 PATCHING POLICY (Andrew, Aug 20, 2026) — `refresh.sh` is the ONLY way anything gets upgraded

🙋 *"We should disable all auto-upgrades everywhere and only trigger upgrades from the refresh
script."* ✅ **DONE and verified on all 10 VMs** — `unattended-upgrades`, `apt-daily.timer` and
`apt-daily-upgrade.timer` are **`masked`** everywhere.

⭐ **The problem it fixed:** `.180`–`.184` had **two** upgrade mechanisms — `refresh.sh` (deliberate,
windowed, you are watching) **and** `unattended-upgrades` (unscheduled, invisible, will restart a
service mid-job). **Two upgrade paths where one is uncontrolled is worse than either alone**, because
the state you believe you froze can move on its own.

⚠️ **It was never the convention MEMORY implied.** Measured before the change: **masked** on the 3
swarm nodes, **disabled** on `.186`, **enabled** on `.180`, `.181`, `.182`, `.183`, `.184`. *Three
states across nine hosts is an accident, not a policy* — and the boxes where an unscheduled restart
hurts most (GitLab, the runner) were in the `enabled` group.

- **`mask`, not `disable`.** A masked unit is symlinked to `/dev/null` and **cannot be started even as
  another unit's dependency** — which is the whole point, since `apt-daily-upgrade.timer` would
  otherwise pull the service in. `disable` does not stop that.
- 🚨 **Reading `/etc/apt/apt.conf.d/20auto-upgrades` will LIE to you.** It still says
  `APT::Periodic::Unattended-Upgrade "1"` on every masked host. **The timers decide; the config only
  describes.** *The layer that reports is not the layer that decides.*
- **`refresh.sh` now targets `.180`–`.185`** (Jenkins added Aug 20). ⚠️ **`.186` and `.191`–`.193` are
  masked AND not in `refresh.sh`, so they get NO automatic patching at all** — deliberate (frozen
  known state), but it means patching them is a manual act nothing will remind you about.
- **PVE host `.150` needs nothing:** `unattended-upgrades` is **not installed**, so its apt-daily
  timers refresh package lists but cannot install anything. Host upgrades stay the deliberate pinned
  process from phases 1a/1b.
- 🚨 **Hazard found while doing this — `refresh.sh` can be broken by a REBUILT VM.** It SSHes with
  `StrictHostKeyChecking=accept-new`, which accepts *new* keys but **rejects changed** ones, and its
  **preflight aborts the entire run on the first host it cannot probe.** So a VM rebuilt at a reused
  IP (exactly what `.185` is) leaves a stale host key that **takes down the whole refresh for every
  VM**, not just that one. ⭐ **After rebuilding any VM, SSH to it from the PVE host once by hand
  before the next `refresh`.**

### Current VMs (Last verified Feb 20, 2026)
| VM | CPU | RAM | Disk | Storage | Config |
|----|-----|-----|------|---------|--------|
| **180 - QA** (`vm-docker-qa-1`, IP `.180`) | 8 cores | 12 GB | 100 GB | vm-ephemeral | ✅ Standard — **full clone of the old VMID 200, Aug 20, 2026.** VMID now matches the IP like every other VM. Only ~15 GB of the 100 GB is actually used |
| **181 - GitLab** | 8 cores | 24 GB | 500 GB | vm-critical | ✅ Standard |
| **182 - Runner** | 8 cores | 12 GB | 100 GB | vm-ephemeral | ✅ Standard |
| **183 - SonarQube** | 4 cores | 12 GB | 30 GB | vm-critical | ✅ Standard |
| **184 - WWW** | 8 cores | 8 GB | 50 GB | vm-critical | ✅ Standard |
| ~~**185 - OpenClaw**~~ | ~~12 cores~~ | ~~16 GB~~ | ~~50 GB~~ | ~~vm-critical~~ | ⛔ **DESTROYED Aug 19, 2026 — all of it returned to the host.** ⚠️ It held **12 cores, not the 8 recorded here** — measured from `qm config` before the destroy |
| **186 - K8s/Redpanda POC** | 8 cores | 16 GB | 300 GB | vm-ephemeral | ✅ Standard (from template 9000) — **right-sized down from 16c/32 GB Aug 12, 2026** |
| **191 - docker-swarm-1** | 2 cores | 4 GB | 40 GB | vm-ephemeral | ✅ Standard (template 9000) — **built Aug 13, 2026, Phase 16** |
| **192 - docker-swarm-2** | 2 cores | 4 GB | 40 GB | vm-ephemeral | ✅ Standard (template 9000) — **built Aug 13, 2026, Phase 16** |
| **193 - docker-swarm-3** | 2 cores | 4 GB | 40 GB | vm-ephemeral | ✅ Standard (template 9000) — **built Aug 13, 2026, Phase 16** |
| ~~**200 - QA**~~ (old `vm-kubernetes-1`) | ~~8 cores~~ | ~~12 GB~~ | ~~100 GB~~ | ~~vm-ephemeral~~ | 🟡 **STOPPED + `onboot 0` Aug 20, 2026 — kept as the rollback for VM 180 until ~Sept 3, 2026, then destroy.** Its VMID never matched its IP (.180) and its hostname claimed Kubernetes it never ran; both were fixed by cloning to 180. **Consumes disk only, no RAM/CPU, while stopped.** ⚠️ Its `pre-clone-20260820` snapshot still records `onboot: 1` — a rollback would re-arm autostart and collide with .180 |
| **9000 - TEMPLATE** | 2 cores | 2 GB | 3.5 GB | vm-ephemeral | 📀 `tmpl-ubuntu-2404-cloudinit` |

### RAM Allocation Strategy
- **GitLab:** 24 GB (memory-hungry, upgraded from 16 GB)
- **SonarQube:** 12 GB (upgraded from 8 GB for large project scans)
- **Runner:** 12 GB (upgraded from 8 GB)
- **QA (`.180`, VMID 180, `vm-docker-qa-1`):** 12 GB (upgraded from 8 GB). **Old VMID 200 is stopped, so
  this 12 GB is counted once, not twice** — a stopped VM reserves no RAM.
- **WWW:** 8 GB (Traefik + Capricorn PROD + splash)
- **~~OpenClaw:~~ 0 GB** — ⛔ **VM 185 destroyed Aug 19, 2026. The 16 GB and 12 cores are actually free
  now, not merely idle.** Phase 17's `vm-jenkins-1` takes 8 GB / 4 vCPU of it, so the lab **nets 8 GB
  and 8 cores.** Host measured **33 GB free** immediately after the destroy.
- **K8s/Redpanda POC (186):** **16 GB** — was 32 GB, sized for 3 Redpanda brokers **+ OpenSearch**.
  OpenSearch (Phase 14 Part 5) was never installed, so **right-sized to 16 GB / 8 cores on
  Aug 12, 2026** after nine days of measurement showed **3.0 GB and ~1% CPU actually in use**.
  The floor is set by pod *requests* (7.7 GB / 3.25 cores), not consumption — 16 GB keeps requests
  at 50% and still fits OpenSearch later if Part 5 is ever revived. Brokers were unaffected: each
  Seastar arena is sized from its container limit (`2560Mi`), not host RAM. Verified healthy 3/3
  with the Part 6 ledger reconciling to exactly 800,000 shares. See
  `phases/phase14_k8s_redpanda_poc.md` → "Right-sized Aug 12, 2026".
- **Docker Swarm nodes (191/192/193):** **4 GB each, 12 GB total** — built Aug 13, 2026, and funded
  exactly by the 16 GB VM 186 gave back the day before. Swarm's control plane is light; CPU
  (2 vCPU each) is the binding constraint, not RAM.
- **Total Allocated (updated Aug 19, 2026, after 185 was destroyed):** **96 GB of 128 GB (75%)**, and
  now the paper number and the real number agree — the 16 GB that used to be "allocated but powered
  off" is genuinely released. vCPU drops to **38 of 48 threads assigned**, so the 1.04:1 overcommit
  is **gone**. ⭐ **Phase 17's `vm-jenkins-1` takes 8 GB / 4 vCPU**, leaving the lab at **104 GB (81%)
  and 42 threads** — still under-committed on CPU for the first time since the Swarm build. Host
  measured **33 GB free** right after the destroy. ⚠️ Budget from here: **there is no dormant VM left
  to harvest.** The next 16 GB has to come from right-sizing something that is running.

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
- ⚠️ **The template's disk is only 3584M (3.5 GB), so `qm resize` is mandatory, not optional** — and
  it grows the *virtual* disk, while the *filesystem* only follows if cloud-init's `growpart` runs on
  first boot. **Verify from inside the guest with `df -h /`**, not from `qm config`. If growpart
  silently does not fire, the VM dies on its first large `docker pull` with an error about image
  layers rather than about disk space, which is a genuinely confusing 20 minutes.
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

### 🔁 CLONING AN EXISTING VM (not the template) — proven Aug 20, 2026 doing 200 → 180

🚨 **Proxmox CANNOT re-number a VM in place. "Renumbering" is always a clone**, so treat it as a
copy-and-validate job, not an edit. A full clone of a 100 GB zvol with ~15 GB used took **23 seconds**.

⛔ **The dangerous part is not the clone, it is the two machines afterwards.** Checklist that worked:

1. ⚠️ **If the source has no cloud-init drive, its IP is STATIC INSIDE THE GUEST — the clone claims the
   same address.** Set **`onboot 0` on the original before anything else.** This is load-bearing, not
   tidiness: without it, one host reboot starts both and they fight over the IP.
2. 🚨 **A snapshot stores `onboot` too.** The original's pre-clone snapshot still says `onboot: 1`, so
   **a rollback silently re-arms autostart.** `qm config <id>` shows live; `qm config <id> --snapshot
   <name>` shows the snapshot. Reading the raw `<id>.conf` shows *both* and is easy to misread.
3. ✅ **Netplan here matches on interface NAME, not MAC**, so the clone's new MAC did not break
   networking. ⚠️ **The name is NOT uniform across the fleet — `.180` is `ens18`, `.186` is `eth0`.**
   Check the source VM's actual name before assuming; `ip -o -4 addr` beats guessing. ⭐ **The escape hatch if it ever does: `agent: enabled=1` means `qm guest exec`
   works over virtio-serial with NO network at all.** Check the agent is enabled *before* you boot a
   clone you might not be able to reach.
4. ✅ **A clone keeps the source's SSH host keys**, so if the IP is unchanged, `known_hosts` needs no
   clearing anywhere.
5. ✅ **`refresh.sh` targets hosts by IP, not VMID**, so re-numbering is invisible to it — only its
   comment needed fixing. Check the same before assuming any script cares.
6. **Fix `/etc/fstab` BEFORE cloning** so both copies inherit it. Any network mount needs `nofail`.
   ⭐ **Verify the fix on the generated unit, not the fstab line:** `systemctl show <unit> -p RequiredBy
   -p WantedBy` must show **`RequiredBy=` empty** — that is what proves a dead NAS can no longer
   block boot.
   ✅ **FIXED AT SOURCE Aug 20, 2026:** `www/scripts/setup_smb_mount.sh` wrote `_netdev` but **not**
   `nofail`, so *every* VM ever built by it carried it. New builds are safe, and the whole lab was
   swept the same day — **all 9 VMs + the dev workstation now show `RequiredBy=` empty.**
   🧠 **The lesson that generalises:** when a per-VM fix works, go ask whether the *builder* has the
   same bug. Fixing one VM fixes one VM; fixing the script fixes every future one.
   ⚠️ **BUT the severity was overstated and is now corrected — see the `_netdev` note below.**

### 🩹 `nofail` / `_netdev` — what missing `nofail` ACTUALLY costs (corrected Aug 20, 2026)

⚠️ **We claimed it "drops the host to an emergency console, no network, no SSH." That is WRONG.**
`_netdev` already keeps the entry out of `local-fs.target`, and **`.184` is the disproof sitting in
our own lab** — it failed this exact mount at *every* boot from **July 9** onward and still came up
each time with networking and SSH working.

| Entry | Lands in | A dead NAS at boot means |
|---|---|---|
| network mount, **no `_netdev`, no `nofail`** | `local-fs.target` | ⛔ **emergency console** — the scary one |
| `_netdev`, **no `nofail`** | `remote-fs.target`, `RequiredBy=` | ⚠️ bounded **boot delay** (11 s measured on .184, ~90 s worst case) + a permanently failed unit |
| `_netdev,nofail` | `remote-fs.target`, `WantedBy=` | ✅ ignored at boot; still mounts when the NAS is there |

🧠 **The thinking error worth remembering: a plausible mechanism was asserted instead of checked,
while a host that had been running the experiment for six weeks sat one `systemctl status` away.**
Still worth fixing — a failed unit and a boot stall are real — just not a catastrophe.

### 🚫 PROD-LOCAL HOSTS MUST NOT MOUNT THE NAS — `.184` (`vm-www-1`)

🙋 **Andrew, Aug 20 2026: "184 should NOT mount the NAS! It's prod-local."** `.184` is the
internet-facing DMZ box; Phase 12 gave it `OUT DROP -dest 192.168.1.0/24`, so the NAS is unreachable
**by design**. The standard build had mounted it anyway — failing every boot since July **and leaving
`/root/.smbcredentials` on the internet-facing host** for a share it may never reach. All removed
(fstab line, unit, `/mnt/DevShare`, credentials); `.184` now has **zero failed units**.

⭐ **The generalisable point: a uniform build standard will plant credentials on the very hosts your
network design isolates.** The firewall worked perfectly; the **builder** was the leak.

**Two guards now, both in the build:**
- `bash host_setup.sh --no-nas` — deliberate skip for a known prod-local host.
- **`setup_smb_mount.sh` pre-checks `<nas>:445` and refuses** to write fstab or credentials if it
  cannot connect. ⭐ This is the one that matters — it needs no operator knowledge. **Verified by
  running it on `.184` itself:** refused, wrote nothing, host stayed clean.

⚠️ **`SKIP_NAS=1 sudo -E …` DOES NOT WORK here.** sudo has `env_reset`; it warns *"preserving the
entire environment is not supported"* and **silently drops the variable**, so the script runs in
full. Put it after sudo: **`sudo SKIP_NAS=1 bash ./setup_smb_mount.sh`**.

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
**Excluded:** ~~.185 (vm-openclaw-1) — managed separately~~ → ⛔ **that VM is gone (Aug 19, 2026).**
🔲 **Phase 17 TODO: add `.185` back as `vm-jenkins-1`, this time as an INCLUDED host.**

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
| vm-critical | 2x Lexar NM620 1TB | mirror | 952GB | 66GB (6%) | lz4 ✅ | 1.40x | GitLab, Sonar, WWW, ~~(OpenClaw)~~ → **Jenkins** (185's 50 GB freed Aug 19, 2026) |
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
| 14 | Kubernetes + Redpanda POC (was interview prep) | ✅ **CLOSED Aug 12, 2026 — goal met: the interviews happened Aug 6/7 and Andrew got the job.** Parts 1–6 done, 7 chapters written. VM 186 right-sized to 8 vCPU / 16 GB and left at snapshot `s05-app-running`. **Do not extend it**; Ch8–10 are track-1 education work, not phase 14. |
| 11 | OpenClaw AI Agent | ✅ COMPLETE Feb 20, 2026 → ⛔ **RETIRED AND DESTROYED Aug 19, 2026.** VM totally gone, no backup. VMID/IP reused by Phase 17 |
| 15 | Education program — multi-track study repo | ✅ **Parts A–D COMPLETE Aug 12, 2026.** `education/` is now a shelf: one folder per track, shared `tools/`, `CONVENTIONS.md`. One item open — the `docker-swarm` row in `education/README.md`'s track table, held until the folder exists. |
| 16 | Docker Swarm (education track 2) | 🟢 **COMPLETE — ALL 7 PARTS, ALL 7 TRAPS CLOSED (Aug 19, 2026); 8 chapters written.** VMs 191/192/193 from template 9000; three-manager swarm, quorum 2 of 3; snapshots `s01-base-clean` → **`s07-c4-fixed-verified`** (⭐ **`s07` is the FIRST snapshot containing the C4 fix — `s06` predates it**). CI deploys the stack from GitLab; **C1–C5 fired, C6/C6b closed, C7 run Aug 19**; C4 fixed and VERIFIED against a degraded cluster (P48+P50). 🤖 **C7 + chapter 7 were AI-EXECUTED at Andrew's written instruction — declared in the chapter and the README, and deliberately marked WEAKER than chapters 1–6, which he drove.** **Part 7 closed as chapter 8 — the Swarm↔Kubernetes crib sheet, every row marked S / K / 🤖 / ⚠️ recited so nothing recited can be quoted as experience.** ⭐ Its two non-obvious conclusions: **the PVC abstraction is not what protects data** (the k3s lab's `local-path` strands it identically — the value is the driver ecosystem, not the object), and **Swarm's digest-pinning default is the SAFER of the two image models.** **🟢 CLOSED Aug 19, 2026 — nothing outstanding.** Drill D ran Aug 18 (P30/P31 ✅), the highlight pass finished Aug 19 (all 15 chapters, both tracks, 19.5–21.2 %), and the last open measurement — the `redis` divergent-volume question — was made and **refuted** (the two volumes are trap C3's deliberate residue). 🚨 **Its transferable lesson: `docker service ps`'s `CURRENT STATE` age is the manager's last STATUS STAMP, not the task's age** — it moves on control-plane churn, so a day-old task presents as freshly rescheduled, which manufactured a fictional data-loss incident until measured. ⚠️ **Standing hazard, recorded not fixed: an empty 88-byte `capricorn_redis_data_swarm` sits on `.193`** — `redis` scheduling there attaches an empty cache. 🙋 Andrew drives by default (`education/METHOD.md` → "Who does the work"). Re-walk the `📌 READ THIS FIRST` pre-flight list in `phases/phase16_docker_swarm.md` each session. |
| 17 | Jenkins (education track 3) | 📋 **CONFIRMED NEXT after Phase 16** — Jenkins is named explicitly on the study list (`education/fin_tech_stack.txt`), so this is no longer provisional. Phase 16 Part 3 deliberately keeps deploy logic in a shell script, so this track is largely "write a different wrapper". |
| 18+ | Remaining study list | 💭 **Backlog, worked STEP-BY-STEP in its stated order** after Jenkins: OpenSearch + Dashboards → Prometheus + Grafana → Redpanda Connect + Debezium CDC → MongoDB + Postgres → SAML/OIDC (authentik) → Ansible. Source of truth is `education/fin_tech_stack.txt`; do not re-derive priorities. |

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

## OPENCLAW — ⛔ DEAD. VM DESTROYED Aug 19, 2026. (detail demoted to phase11)

⛔ **`vm-openclaw-1` was destroyed on Aug 19, 2026** — `qm destroy 185 --purge`, no backup (declined
on purpose), no snapshot had ever been taken, ZFS volumes and firewall config purged with it. **There
is no way to restore it and that was the decision — do not go looking for one.**

⭐ **VMID 185 and `192.168.1.185` now belong to JENKINS** (`vm-jenkins-1`, built Aug 20, 2026). So any
OpenClaw-era address, port, token or URL in an old note is not merely dead — it now points at a
DIFFERENT MACHINE. 🚨 The one that actually bites: because `.185` was reused, a stale `known_hosts`
entry produces a host-key MISMATCH, which reads like an attack rather than like a rebuild.

📖 **The full 151-line build record — gateway config and `allowedOrigins`, the v2026.3.22 packaging
bug, the TTS schema moves across v3.28/v4.5, the SSHFS mount, the Tailscale Serve setup and the
firewall rules — was demoted VERBATIM to `phases/phase11_openclaw.md` on Aug 20, 2026** (diffed
identical before removal). **Cost of skipping it:** nothing, unless OpenClaw is ever rebuilt — at
which point the upgrade traps recorded there are the entire value, and none of them are inferable
from the software.


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
  Curated showcase. Secrets are .gitignore'd and NEVER reach GitHub. Push with: **`./push_github.sh`**.
- **GitLab (PRIVATE):** http://gitlab.gothamtechnologies.com/production/home-lab-setup — remote `gitlab`.
  Full plaintext mirror of the ENTIRE working tree (incl. ignored secrets/binaries).
  Auth = HTTP "wallet" baked into the remote URL in .git/config
  (`http://root:<GitLab root pw — see PASSWORDS.md>@gitlab.gothamtechnologies.com/production/home-lab-setup.git`),
  identical to how Capricorn/capricorn-docs authenticate. No SSH key needed for GitLab.
  The real password lives ONLY in .git/config (never pushed) + PASSWORDS.md (gitignored).
- ⚠️ **PUSH ONLY VIA THE TWO SCRIPTS (Aug 12, 2026). NEVER a raw `git push`.**
  **`gl-backup.sh` WAS RENAMED to `push_gitlab.sh`** (`git mv`, history preserved) so the two
  remotes have symmetrical entry points. The old name no longer exists — a stale `./gl-backup.sh`
  just errors, which is the intended loud failure.
  - **`./push_github.sh`** → PUBLIC GitHub (origin/main), curated tree. **New and it FAILS CLOSED.**
    Four gates: origin really is GitHub and branch is `main`; no TRACKED file has a secret-looking
    name; every known sensitive path that exists is still gitignored; and the outgoing diff has no
    private-key blocks, no URL with an embedded password (**this is what would catch the GitLab
    wallet leaking**), and no AWS keys. Then it prints the commits going public and requires a typed
    `yes`. **Refuses to push unattended unless given `--yes`.** If it blocks, FIX THE CAUSE.
  - **`./push_gitlab.sh "message"`** → PRIVATE GitLab (gitlab/main), full plaintext mirror. Same
    proven logic as before (temp index, never touches the real index/worktree/`main`, handles nested
    git repos). Added guard: it ABORTS if the `gitlab` remote ever resolves to github.com, because
    this script deliberately stages secrets.
  - **Both take `--dry-run`** — every check runs, nothing is pushed. Verified Aug 12: the GitLab
    dry-run built a 208-file snapshot including PASSWORDS.md and the nested openclaw-ansible files,
    and the real index was byte-identical afterwards.
- ⚠️ **WHAT THE GITLAB MIRROR DOES AND DOES NOT PRESERVE** (understood properly Aug 12).
  `gitlab/main` and `main` are **FULLY DISJOINT — `git merge-base` finds no common ancestor.**
  As of Aug 12: **82 real commits on `main` vs 22 snapshots on `gitlab/main`.** The mirror preserves
  **files perfectly** and **history coarsely**; it IS a real commit chain, so diffing between
  snapshots works normally. What it never had was correlation — no way to tell which `main` commit a
  snapshot matched — and two of the older snapshots are messaged only `Full snapshot <timestamp>`,
  where the reason for the snapshot is simply gone.
  - ✅ **Fixed Aug 12: snapshots are now AUTO-STAMPED.** Default message is
    `Snapshot <ts> — main @ <sha>[+dirty]: <HEAD subject>`; a message you pass gets `[main @ <sha>]`
    appended. **`+dirty` means the snapshot contains work that is in NO commit**, which is the case
    worth noticing — the SHA alone would not describe the tree being pushed.
  - **Nothing is lost on the GitHub side.** `push_github.sh` never creates a commit; it only pushes.
    Commit messages are authored normally with `git commit` and are unaffected by either script.
  - **Neither script pushes tags** (there are currently 0 tags in the repo). If tagging ever starts,
    `push_github.sh` needs `--follow-tags`.
  - Do NOT `git push gitlab main` directly — that sends only the curated tree, not the secrets.
- **No auto-push-to-both.** Pushes are explicit; ALWAYS ASK "GitHub, GitLab, or both?" first.
  See the "GIT REMOTES & COMMIT ROUTING" section in CURSOR_RULES.
- **GitLab always looks "diverged" from `main` (e.g. 82 ahead / 22 behind). That is BY DESIGN** —
  it is a separate snapshot history built by push_gitlab.sh, not a problem to reconcile.
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
