# Current Phase

**Updated:** August 13, 2026 - 12:55 PM EDT

---

## 🎉 ANDREW GOT THE JOB (Aug 12, 2026)

The interviews happened **Aug 6 and Aug 7** and the outcome was an offer: **SRE / DevOps on an order
management system at a financial institution.** Phase 14 was built to prepare for exactly those two days, so
**Phase 14 is CLOSED — goal met.** Nothing in it is half-finished; all 7 chapters were written,
audited, highlighted, built to `.docx` and committed, and the highlighting was **visually confirmed
good in Word by Andrew on Aug 12**, which closes the last open verification item.

**What changes:** the education material is no longer interview prep with a deadline. It is
onboarding prep for a job he now holds, which means **depth on the real stack** rather than breadth
before a panel.

✅ **RESOLVED Aug 13 — the real stack has landed.** Andrew wrote it down in
**`education/fin_tech_stack.txt`**, now the tracked source of truth for the study backlog. Focus is
**DevOps as it applies to an OMS / platform including portfolio and risk management tools**, and the
**Q3–4 2026 study list, in its stated priority order**, is: **Kubernetes; Redpanda + Redpanda Connect;
Docker Swarm; Jenkins; OpenSearch + OpenSearch Dashboards (logging/alerting); Prometheus + Grafana
(metrics/alerting); Redpanda Connect + Debezium CDC; MongoDB + Postgres; SAML/OIDC integration
(authentik as a self-hosted OIDC provider); Ansible.**

Three consequences:
- **Track 1 and track 2 are both confirmed on the list** (Kubernetes/Redpanda, Docker Swarm), so
  neither was wasted. **Jenkins is explicitly named**, which upgrades Phase 17 from provisional.
- ⭐ **ROADMAP RULE (Andrew, Aug 13): new phases work through `fin_tech_stack.txt` STEP-BY-STEP, in
  its stated order.** The list is the backlog — do not invent a curriculum or re-derive priorities.
  After Swarm, that means **Jenkins**, then OpenSearch, Prometheus/Grafana, Redpanda Connect +
  Debezium CDC, MongoDB/Postgres, SAML/OIDC (authentik), Ansible.
- ✅ **Chapter 7 of track 1 was RIGHT — leave it exactly as it is (Andrew, Aug 13).** Its six areas
  came from the job description and **are genuinely in the target stack**; they are simply **not what
  was suggested as the first focus.** The four that do not appear on the study list — **Cloudflare
  edge, Symantec PAM, Vault, PKI/cert-manager** — are **real and correctly documented, just lower
  priority.** ⚠️ **Do NOT rework, retract or reconcile away chapter 7**, and do not treat
  `phase15_education_program.md` §4 as having aimed at the wrong target. It was a straw man in the
  sense that it was unconfirmed, not in the sense that it was wrong. **Sequencing now comes from the
  study list; coverage from §4 and chapter 7 still stands.**

### 🚨 De-identification — a standing rule, learned the hard way on Aug 13

The first draft of that file named an **employer, a start date and who suggested the list**, and the
first fix was to **gitignore it**. That fix was wrong twice over:

1. **The facts had already been copied into `MEMORY.md` and `current_phase.md`** — both **tracked and
   public** — specifically so a cold reload would not need the ignored file. Ignoring the file did
   nothing about the copies. This was caught only because the GitHub dry-run output was read carefully;
   **all four of `push_github.sh`'s gates passed, because they look for credentials.**
2. **An ignored file makes a fresh clone miss the roadmap MEMORY points at**, which is the same trap as
   telling a reader to run something out of a gitignored `scratch/`.

**Andrew's fix, applied the same day and the one to copy in future:** de-identify the *content* rather
than hide the file. Generic title, generic framing, a neutral filename, then **track it normally.**
Also applied repo-wide the same day: the **industry term was genericised to "financial institution"**
in 7 places across `MEMORY.md`, `current_phase.md`, `phase14`, and **track 1 chapter 1 — whose
committed `.docx` was rebuilt**, since the Word builds are binaries and a text edit does not reach
them. ("Order management system" was explicitly kept.) History was **not** rewritten for the
already-public files; nothing carrying the employer name ever reached GitHub.

🚨 **Never put an employer name, a start date or "my boss" into a tracked file. The push gates protect
against secrets, not against private.**

---

## 🔵 ACTIVE: Phase 16 — Docker Swarm (education track 2)

**Full plan + implementation log: `phases/phase16_docker_swarm.md`.**

### ✅ Part 1 COMPLETE (Aug 13, 2026, 12:12–12:26 PM EDT)

Three nodes exist and are ready for `swarm init`:

| VMID | Name | IP | Spec | State |
|---|---|---|---|---|
| 191 | `docker-swarm-1` | 192.168.1.191 | 2 vCPU / 4 GB / 40 GB `vm-ephemeral` | running, `onboot=1`, Swarm inactive |
| 192 | `docker-swarm-2` | 192.168.1.192 | 2 vCPU / 4 GB / 40 GB `vm-ephemeral` | running, `onboot=1`, Swarm inactive |
| 193 | `docker-swarm-3` | 192.168.1.193 | 2 vCPU / 4 GB / 40 GB `vm-ephemeral` | running, `onboot=1`, Swarm inactive |

Docker **29.7.2** / Compose **v5.4.0**, Ubuntu 24.04 LTS from template 9000. All three snapshotted
**`s01-base-clean`**, taken hot and together (~1.6 s each, guest-agent freeze/thaw, nothing stopped).

**Built by two committed idempotent scripts**, not by typing commands three times —
`education/docker-swarm/scripts/provision_nodes.sh` (runs on the pve host) and `post_setup.sh` (runs
on each node). Three full clones took **38 seconds**; personalization ran on all three **in parallel**
in ~3 minutes.

**Pre-flight decisions taken:** **A5 closed** — the stack file and scripts live in
`education/docker-swarm/{manifests,scripts}/`, keeping the track self-contained per `CONVENTIONS.md`
and setting the pattern later tracks copy. **A2 deferred to Part 4** (whether this repo gains a
`.gitlab-ci.yml`), because it is really one decision together with the `workflow: rules:` guard that
stops every `push_gitlab.sh` backup from spawning a pipeline. **A3 stays deferred into Part 5** by
design. **Nothing blocks Part 2.**

**What was worth learning in an otherwise smooth build:**
- ✅ **`growpart` ran** — the plan's loudest warning was a non-event. ⚠️ But **`df -h /` reads 38G, not
  40G**: `sda15` (106M EFI) and `sda16` (913M `/boot`) come out of the 40 GB virtual disk. **38G is
  correct — do not go hunting the missing 2 GB.**
- ⚠️ **`host_setup.sh` really does install Chrome + Cursor on a headless node, and now we know why:**
  it runs the desktop branch if it finds `gnome-shell` **or `gsettings`**, and the Ubuntu 24.04 cloud
  image ships `gsettings`. The log even says "Desktop environment detected". Purging took each node
  from **4.4 GB to 2.2 GB used** — the ~1.8 GB the plan predicted. Apply this to every future clone.
- ✅ **`refresh.sh` needed no edit.** It targets an explicit allow-list (`.180`–`.184`), so new VMs are
  excluded by construction. The guest half still mattered: `unattended-upgrades`, `apt-daily` and
  `apt-daily-upgrade` are **masked** on all three (B4).
- ✅ **Nothing obstructs Swarm's ports.** `/etc/pve/firewall/` holds only `184.fw`, `185.fw` and
  `cluster.fw` — there is **no `19x.fw`**, so the guest firewall is off despite `firewall=1` on the
  NIC, and `2377`/`7946`/`4789` are clear. ⚠️ Adding a `19x.fw` later without those three rules
  **breaks the cluster silently.**
- ✅ **The registry config came free from the standard script**, which was the whole argument for using
  it: `insecure-registries` is in `/etc/docker/daemon.json` on all three, and `/v2/` answers **401**
  from `.191` (up, requiring auth).
- ✅ **No backup job sweeps them in** — `/etc/pve/jobs.cfg` has one job, scoped to `vmid 181`.
  Consistent with "backups: none, snapshots instead" for rebuildable VMs.

### ⬜ Next: Part 2 — form the cluster

`docker swarm init --advertise-addr 192.168.1.191`, join `.192`/`.193` as managers, confirm one
`Leader` + two `Reachable`, then `s02-swarm-up` on all three together (B3). After that, chapter 1
can be drafted, since it covers Parts 1–2 and half of it has now actually been run.

---

## ✅ Phase 15 — The Education Program (multi-track study repo)

**Full plan: `phases/phase15_education_program.md`.**

✅ **Its last open item closed Aug 13:** the `docker-swarm` row is now in `education/README.md`'s track
table, and `education/docker-swarm/README.md` exists, because the folder it was waiting on was created
by Phase 16 Part 1. ⚠️ **`build_docx.py --list` still shows only `k8s-k3s-redpanda`, and that is
correct** — a track only registers once it holds `chapterNN_*.md` files, and track 2 has none yet.

### ⭐ NEW Aug 13 — the learning method is finally written down: `education/METHOD.md`

Andrew's question was the right one: *are you following the same steps for every new subject, and did
you write yourself instructions for it?* **The honest answer was no.** `CONVENTIONS.md` is the
**writing** standard and `CURSOR_RULES` holds the **project** process (plan → approve → implement →
document). The actual learning loop — build it, break it, write from the wreckage — **existed nowhere**
and survived only as a *shape copied by imitation* from `phase14` into `phase16`. That is precisely how
a method drifts, and it was already visible: **two genuine improvements were invented mid-Phase-16 and
were not captured anywhere** — the **planted-traps table** (🅒, failures listed in advance and marked
do-not-fix) and **sorting caveats into four kinds** (🅐🅑🅒🅓, because the first draft's five "open
questions" read as five blockers when only two needed a human).

**`education/METHOD.md` is now the sibling of `CONVENTIONS.md`:** *how to run a track* beside *how to
write a track*. Five stages — **plan** (declare the traps up front), **build** (scripted, re-runnable,
**verified from inside the guest**), **break** (drills chosen for what they mean at 3am), **investigate**
(**the surprises ARE the deliverable** — almost nothing quotable in track 1 was planned), **document** —
plus an anti-patterns table.

⭐ **Andrew's explicit framing: a proven method, but a FLOOR NOT A CEILING.** Room to develop new or
topic-specific ideas and run with them, exactly like the two Phase 16 improvements. So the amendment
duty is the **first** rule in the file, not a footnote: **deviate deliberately, then fold what worked
back in during the same session.** An improvement that is not written down is lost.

### 🔓 `CURSOR_RULES` edited a SECOND time (Aug 13) — authorised in writing, still not precedent

Andrew authorised this edit explicitly and in writing, to wire `METHOD.md` in. **225 → 239 lines,
exactly one line removed** (old rule 2, deliberately rewritten). Changes: **checklist item 2g**
(METHOD is mandatory before starting or running a track), **METHOD.md added to the education file
list**, **new rule 1b**, **rule 2 widened** (conventions → `CONVENTIONS.md`, working practices →
`METHOD.md`, neither ever forked into a track), and **new rule 8** (floor not ceiling + fold-back
duty). The `RULES:` list now runs **1, 1b, 2–8** — `1b` deliberately avoids renumbering rules that
other documents reference.

⚠️ **Method note for the next time this file must change:** it was done as **one atomic Python pass
that asserted every anchor matched exactly once and that Andrew's own lines survived**, then verified
from the shell (`wc -l`, `md5sum`, `git diff | rg '^-'`). **Do it that way** — incremental edits to
`CURSOR_RULES` on this CIFS mount corrupted it twice on Aug 12.

`education/` was written flat for one subject on one deadline. With the job won and a whole stack to
learn, it had to stop being *a book* and become *a shelf*. Phase 15 is that conversion — framework
and doc reconciliation only, **no new study content**.

### ✅ Done (Aug 12)

- **Track 1 moved to `education/k8s-k3s-redpanda/`** — 67 `git mv`s, history preserved
  (`git log --follow` still reaches Jul 27). Chapters, `app/`, `diagrams/`, `images/`, `manifests/`,
  `docx/` and the ignored `scratch/` all travelled together.
- **`.gitignore` generalised** to `education/*/scratch/`, so every future track's scratch is ignored
  automatically. Verified with `git check-ignore -v`.
- **Tooling made shared and track-aware.** `education/tools/` stays at the top of the shelf;
  `build_docx.py` and `figcheck.py` now take the **track as their first argument**, and
  `build_docx.py --list` enumerates tracks. `figcheck.py` was **promoted out of the gitignored
  `scratch/`** so a fresh clone can actually run the command the docs describe.
  - **Regression check passed:** rebuilt all 7 chapters and compared the inner `word/document.xml`
    against `git show HEAD:` — **byte-identical in all seven.** The committed binaries were then
    restored so the commit stays a pure rename instead of 7 files of zip-timestamp noise.
- **The shelf documents written:** `education/README.md` is now the hub (track table + how to start a
  track), and `education/CONVENTIONS.md` holds every *how to write* rule so future tracks inherit
  them instead of copying them.
- **The emailed GitHub links preserved.** `education/README.md` stayed at its original path, and
  `education/docx/README.md` is a stub pointing at the track's builds, so
  `…/tree/main/education/docx` resolves instead of 404ing. Both URLs went to the hiring team Aug 5.
- **Track 1's README corrected** — it had listed chapter 7 as "Schema Registry 🔲 Planned" when
  chapter 7 was actually written as *the rest of the platform*. Schema Registry is now chapter 8.
- **Root `README.md` now documents `education/`** — it previously never mentioned it at all, which
  meant the repo's public face omitted the piece good enough to send to an employer.
- **Paths reconciled** across `MEMORY.md`, `current_phase.md`, `phase14_k8s_redpanda_poc.md`,
  chapters 1 and 6, and `seed-topics-job.yaml`.

### 🐛 Found while doing it — then closed as acceptable

**4 of 19 figures are below the 10 pt floor** Andrew set: `ch02_fig1_ownership` (9.7),
`ch03_fig1_partitions` (9.9), `ch05_fig1_assignment` (10.0 borderline) and `ch05_fig2_skew` (9.4), so
`figcheck.py` exits 1. Pre-existing; it only surfaced because promoting `figcheck.py` out of the
gitignored `scratch/` meant actually running it.

✅ **Resolved by real-world test, not by code: Andrew rendered and PRINTED all seven chapters on
Aug 12 and confirmed they look and print correctly.** So the 10 pt floor is a conservative guide
rather than a hard requirement, and these four stay as they are. **Do not "fix" the non-zero
`figcheck` exit on track 1** — treat it as known and apply the check to *new* figures only. If they
are ever revisited, the fix is a narrower diagram, never a bigger `fontsize`.

### 📐 Conventions are now a file, and it is authoritative

`education/CONVENTIONS.md` holds every *how to write* rule — chapter shape, the "only document what
Andrew actually ran" rule, the Graphviz gotchas, figure legibility, the Word build and the highlight
pass. **Read it before writing or editing any study material, and change conventions there rather
than forking them into a track.**

✅ **Wired into `CURSOR_RULES` on Aug 12.** Andrew gave **explicit one-time authorisation** to edit
that file (it normally forbids AI edits outright — the authorisation note now sits under the
never-edit line, and it is **not precedent**). Three changes:
1. **`PROJECT SCOPE` rewritten to Andrew's definition:** the repo owns **two** things — the Proxmox
   layer **and educational R&D done inside it**. "Application layer" means Capricorn and other real
   apps on the lab. The old text said "INFRASTRUCTURE layer ONLY", which left `/education` unclaimed.
2. **Checklist item 2f** — `CONVENTIONS.md` is a mandatory read for education sessions.
3. **New `=== EDUCATION PROGRAM (/education) ===` section** with 7 rules (conventions first, don't
   fork them, only document what was run, tracks self-contained, nothing from `scratch/`, one phase
   file per track, operational weighting).

### ⚠️ The repo is on a CIFS share and the editor cache lies — VERIFY EDITS FROM THE SHELL

Editing `CURSOR_RULES` produced **two silent corruptions**: a truncated paragraph and a stray line
(`EW instructs you to- CONFIRM that you will edi`) that had never existed in the file. Read-backs
returned stale content that concealed both, once showing a completely different region of the file
than `rg` showed for the same path, and the IDE reported 160 lines while disk had 204.

Both were caught by auditing removals (`git diff <file> | rg '^-'`) and verified with `wc -l` /
`md5sum` / `rg -c`. **Do that after every edit to an important file here.** And if Andrew has a file
open whose line count disagrees with disk, he must reopen it before saving — a stale buffer will
overwrite good work. Full rules at the top of `MEMORY.md`.

### 🔧 Also done this session — push tooling (Aug 12, 4:00–4:25 PM)

Andrew's idea: symmetrical scripts for both remotes, instructed by `CURSOR_RULES`, so pushing is
never a hand-typed `git push`. See the two script sections below for detail.
- **`push_github.sh` NEW** — fails closed on four gates before touching the public remote.
- **`gl-backup.sh` → `push_gitlab.sh`** (`git mv`, history preserved). Old name is gone on purpose;
  a stale call errors loudly rather than half-working. Added a github.com guard and `--dry-run`.
- **Snapshot auto-stamping** — closed a long-standing context leak; see the GitLab mirror section.
- `CURSOR_RULES` now opens that section with "ALWAYS PUSH WITH THE SCRIPTS. NEVER run a raw
  `git push`", and rules 2–5 were rewritten around them.

### 🔻 Also done this session — VM 186 right-sized (Aug 12, ~5:15 PM)

Andrew's question was the right one: *did we over-commit Redpanda for R&D?* Yes, and by a lot.
VM 186 held **32 GB / 16 vCPU** because the Phase 14 plan sized it for **OpenSearch**, which was
never installed (Part 5 was cut for time). Nine days of running measured **3.0 GB and ~1% CPU**.

**Now 16 GB / 8 vCPU**, which returns **16 GB and 8 threads** to the host for the Phase 15 study
clusters — the exact headroom the Docker Swarm / MongoDB tracks will need on a single physical box.

- **The floor is pod *requests*, not usage.** Kubernetes schedules on requests, and these pods
  reserve **7.7 GB / 3.25 cores** (three brokers at `1` core + `2560Mi` each). 16 GB / 8 vCPU keeps
  requests at **50% RAM / 41% CPU** and still leaves room to add OpenSearch later.
- **Redpanda needed no re-tuning.** Each broker's Seastar arena is sized from its *container* limit,
  not host RAM, so the brokers could not notice the change.
- **A CPU/RAM change needs a full stop, not a reboot** — `qm shutdown` (35 s, graceful via guest
  agent) → `qm set --cores 8 --memory 16384` → `qm start`. ⚠️ `qm set` on a *running* VM succeeds
  silently and only stages the change, which looks like success.
- **Verified:** 8 cores / 15 Gi in guest, node `Ready`, **all 12 pods Running**,
  `rpk cluster health` **`Healthy: true`** with 0 leaderless and 0 under-replicated, all 4 topics
  intact at RF 3, group `position-keeper` **Stable**, no OOM kills, and the Part 6 ledger on the PVC
  still sums to **exactly 800,000 shares across 2000 orders**. Host assigned RAM 100 GB → **84 GB**.

**Two pre-existing issues found while verifying** (both documented in the phase 14 file):
1. **All topic data has aged out** — default `retention.ms` is 7 days and the events were seeded
   Aug 3. Every partition now has `LOG-START == LOG-END`. **Re-seed before any chapter 8+ work.**
   This also explains a scary-looking `TOTAL-LAG 1665` on `orders-v2` p5: its committed offset of 0
   fell below the log start, so the consumer reset its *position* to the end but has nothing left to
   process and therefore never commits. Not data loss — the ledger proves it.
2. **The Redpanda trial licence expires ~Aug 25, 2026**, with `partition_auto_balancing_continuous`
   and `core_balancing_continuous` in use from chart defaults. Decide to disable or licence.

### 🔑 Also done this session — SSH access fixed properly (Aug 12, ~5:35 PM)

The resize work was slowed by an access problem that turned out to be two different things:

- **VM 186 never needed keys.** `ssh andrew@192.168.1.186` fails, `ssh agamache@192.168.1.186`
  works and always has — cloud-init injected the workstation key on Jul 25. **Every VM in this lab
  logs in as `agamache`.** `Permission denied (publickey,password)` from a wrong *username* is
  indistinguishable from a missing key, which is what sent the earlier attempt down a dead end.
  `kubectl`, `rpk`, `~/.kube/config` and passwordless `sudo` are all ready on that connection.
- **The Proxmox host genuinely lacked the key**, so `qm` work needed the PASSWORDS.md password over
  `sshpass`. **Fixed:** the workstation ED25519 key now lives in **`/root/.ssh/authorized_keys2`**.
  - Deliberately *not* `authorized_keys` — that is a symlink to `/etc/pve/priv/authorized_keys`,
    which PVE owns and rewrites, and which holds only the cluster's `root@pve` key.
  - `sshd -T` already lists `.ssh/authorized_keys2`, so **no sshd edit and no restart** were needed,
    and PVE will never clobber it.
  - Proven with `-o PasswordAuthentication=no` so a silent password fallback could not fake success.
    `sshd` left untouched (`permitrootlogin yes`, `passwordauthentication yes` still available).

Both facts are now in `MEMORY.md` under CREDENTIALS, where the old text claimed keys covered
".180-.185" and said nothing about the username or the host.

**Then audited the whole fleet against Andrew's stated policy** — key auth from the dev box to
everything with password fallback, and password-only from a remote laptop. **It already holds**;
there was nothing left to build after the host key went in. Full matrix in `MEMORY.md` →
CREDENTIALS → "SSH ACCESS MATRIX". Verified rather than read off config:

- Key auth ✅ to all 7 live hosts (.150 + six VMs; .185 is powered off by design).
- Password-only logins ✅ tested with `-o PubkeyAuthentication=no` on .150, .181, .184, .186. A
  config that says `passwordauthentication yes` and an account with a locked password look identical
  until you actually try one.
- **Remote works because the pve host is a Tailscale subnet router** advertising an approved
  `192.168.1.0/24` — no Tailscale needed on each VM.
- ⚠️ **Subnet routing SNATs (`NoSNAT: false`), so remote traffic reaches the VMs as `192.168.1.150`.**
  That is *why* hardened `.184` (policy_in DROP, SSH from only .182/.195/.150) is reachable remotely
  at all. It also means **VM auth logs cannot distinguish a remote login from a host login** — don't
  build fail2ban or audit rules on VM-side source IPs. Confirmed by SSHing pve → all six live VMs,
  the same post-SNAT path.
- ⚠️ **This dev box is not on the tailnet.** The tailnet's `agamache-z8g4` is the *Windows Z8 host*;
  the dev box is the VMware guest inside it.

**Written up as a runbook: `MEMORY.md` → "REMOTE LAB MANAGEMENT (laptop, outside the house)".**
Andrew's question was whether he could manage the lab from a laptop while away by cloning the repo
for the passwords file. **Yes — verified end to end**, with three things that matter:

1. ⚠️ **Clone GitLab, not GitHub.** `PASSWORDS.md` is gitignored, so GitHub's `main` has **no**
   credentials; the GitLab mirror is the only source. DNS needs no setup — public DNS resolves
   `gitlab.gothamtechnologies.com` to `192.168.1.181`, reachable via the subnet route. The
   `git-upload-pack` endpoint returned HTTP 200 with root credentials (401 without) from a post-SNAT
   source, so the whole path is proven.
2. ⚠️ **GitHub pushes will not work from the laptop** — `origin` is SSH and no private key is (or
   should be) in the repo, and there is no PAT in `github_credentials.md`. GitLab pushes do work.
3. ⚠️ **`.150` is a single point of failure with no out-of-band console.** One subnet router, no
   backup path: a bridge or firewall mistake on the host while remote is unrecoverable until Andrew
   is physically home. `tailscaled` is enabled at boot and the node key has no expiry, which covers
   reboots and long absences but not self-inflicted network breakage.

Also noted: the clone puts the GitLab root password in `.git/config` and `PASSWORDS.md` in plaintext
on the laptop, so full-disk encryption is load-bearing and the clone should be deleted after a trip.

**Andrew then added a second route, which is the better one and changes the risk picture.** Rather
than cloning credentials to the laptop, tailnet *into the workstation* and drive the pve GUI from
there — the dev box already has the keys and the repo, so **nothing sensitive leaves the LAN.**
- ⚠️ **Precision matters here: the dev box is not a tailnet node.** Tailscale is **not installed** on
  it (verified — no binary, no `tailscaled`, no `tailscale0`). The entry point is **`agamache-z8g4`,
  the Windows Z8 host** (`100.70.244.97` / LAN `.115`), with **RDP :3389 verified open**; the dev box
  is the VMware guest one hop further in.
- ✅ **This retires the single-point-of-failure worry for remote *entry*.** The Windows Z8 is its own
  independent tailnet node, so if `.150`'s `tailscaled` dies or stops advertising the subnet route,
  Route B still reaches the lab over the LAN. Keep the Z8 powered on and RDP-reachable when away.
  What it does *not* fix: breaking the pve host's own bridge or firewall remotely is still
  unrecoverable, because there is no out-of-band console.
- Corrected a wrong assumption while writing this up: `/mnt/DevShare` is **`//192.168.1.120`** (the
  NAS), *not* the Windows host — so this route depends on `.120` being up too.

⚠️ **Audit-regex correction for the CIFS check:** `git diff <file> | rg '^-[^-]'` **silently hides
removed Markdown bullets**, because a deleted `- item` appears as `-- item`. Use plain
`git diff | rg '^-' | rg -v '^--- '` instead. The earlier form under-reported this session's
removals by two lines (both intentional, re-audited clean).

### 🐳 Also done this session — the employer's stack is known, and Phase 16 is planned (Aug 12, ~6:30 PM)

**The O1 blocker is closed.** Andrew's description of the new employer's platform:

- Role is **DevOps/SRE, with DevOps first**. Job already accepted.
- Their platform, as far as he knows it today: **GitHub** (source), **Jenkins** (CI),
  **Docker Swarm** (orchestration). Jenkins may need building in the lab later; for now we stay on
  GitLab.

⚠️ **The uncomfortable implication, and why it changed the plan:** our lab is GitLab + GitLab CI, so
the *pipeline glue* is the one part of a Swarm phase that would **not** transfer — it would be written
in a syntax the employer does not use. Fix baked into the plan: **the deploy logic goes in a shell
script (`deploy_swarm.sh`) and the CI file is a thin wrapper that calls it.** GitLab CI calls it now;
a Jenkinsfile calls it later for roughly the same number of lines. Deploy logic is the durable part;
CI products are interchangeable.

**`phases/phase16_docker_swarm.md` written (508 lines) — plan only, nothing built.** Three managers at
`.191/.192/.193` from template 9000, 2 vCPU / 4 GB each (**exactly the 16 GB VM 186 gave back this
afternoon**), running Capricorn from the existing registry images.

**Two of the five open questions were answered by going and looking rather than by asking Andrew:**

- **O3 — is Capricorn stateful? Yes.** Inspected the live PROD stack on `.184`: four services
  (frontend, backend, postgres, redis), named volumes `postgres_data_prod` / `redis_data_prod`, plus a
  bind mount `./database/init` for schema init. This upgraded Part 5 from a paragraph to the best
  exercise in the phase, because **a Swarm named volume is node-local**: reschedule postgres and it
  comes up against a *new empty volume*, reports healthy, and has no data. Silent data loss that looks
  like a clean deploy. Added as drill 6.
- **O2 — where the deploy job lives.** Confirmed this repo is a GitLab project (`production/home-lab-setup`)
  with **no `.gitlab-ci.yml` today**, so the lab can own its whole deploy path here and
  **Capricorn's pipeline is never touched.** That keeps the standing rule intact: breaking the lab
  cluster must not be able to break `deploy_qa` (fires on every `develop` push) or `deploy_prod_local`.

⚠️ **Drift found in passing, worth remembering:** `/opt/capricorn/docker-compose.yml` on `.184`
declares `postgres:15.5-alpine`, but the **running container is the custom
`production/capricorn/postgres:latest`**. The file on disk does not describe what is deployed — so
"just redeploy from the compose file" would quietly change the database image on PROD. Recorded in the
phase plan; **not** fixed here, since Capricorn is application layer.

⚠️ **Deferred into Part 4 rather than blocking the phase:** whether the `.182` runner is even visible
to the `home-lab-setup` project, or is scoped to Capricorn. Also noted: adding a CI file to this repo
means `push_gitlab.sh` backups would start spawning pipelines, so the job needs a `workflow: rules:`
guard.

Other decisions: 3 managers (not 2+1), track name `education/docker-swarm/`, **fresh empty database**
in the lab with its own volume names — no PROD dump, no shared volumes. Jenkins is explicitly out of
scope as a possible Phase 17.

🚪 **AGREED OPENER FOR THE NEXT SESSION.** Andrew will say something close to *"Action @CURSOR_RULES,
the phase16 plan is approved, let's start Part 1."* Interpret that as: run the startup checklist, read
`phases/phase16_docker_swarm.md` **and `education/CONVENTIONS.md`** (chapter 1 gets drafted, so 2f
applies), then **walk the pre-flight §🅐 items — A2 and A5 — before cloning any VM.** That phrasing
also satisfies the MANDATORY PHASE PROCESS approval gate (step 3); do not ask for approval a second
time. **`phases/phase15_education_program.md` is *not* required reading to start Phase 16** — Phase 16
is self-contained, and phase15 §4's track list is the known-stale straw man.

📌 **Andrew's ask, and a good one:** the caveats had been raised in chat and scattered through 500
lines of plan, which is useless to a re-read weeks later. They are now consolidated into a
**pre-flight list at the top of `phase16_docker_swarm.md`**, sorted into four kinds so they cannot be
confused: **🅐 open items** (only **two** now need Andrew), **🅑 7 hard rules**, **🅒 7 deliberately
planted traps that must NOT be fixed in advance** (pre-empting them turns the phase into a tutorial),
and **🅓 3 inherited findings** recorded but out of scope. **Walk §🅐 with Andrew at the start of the
build session** — that is the agreed entry point for this phase.

### 🔍 Review pass over phase15 + phase16 (Aug 12, ~9:15–9:45 PM) — found a credential leak path

Andrew asked for a critical review of both phase docs. Seven real gaps in phase16, six staleness
problems in phase15. The one that mattered:

🚨 **Phase 16 as written could have put a PROD database password into a repo with a public GitHub
remote.** Capricorn's compose on `.184` has **no `.env`** — `POSTGRES_USER`, `POSTGRES_PASSWORD`,
`POSTGRES_DB` and a password-bearing `DATABASE_URL` are **inline, in plaintext, in the file**. The plan
said "write our own stack file referencing the same images" and never said where configuration comes
from, and the obvious implementation is to start from `.184`'s compose. ⚠️ **`push_github.sh` would
probably catch the `DATABASE_URL`** (its URL-with-embedded-password gate) **but would NOT catch a bare
`POSTGRES_PASSWORD=` line** — so the existing protection is partial and accidental. Now hard rule B7,
finding D3, and a Part 3 section that does it properly with **`docker secret`**.

Also added, all previously absent: **Docker secrets/configs** (zero mentions in a 600-line Swarm plan
— both the fix above and a curriculum gap, since they are the direct analogue of k8s Secrets and
ConfigMaps); **image resolution** (a Swarm service stores a **digest**, not a tag, so `:latest` does
not float the way compose taught you — now trap C7 and drill 9); **the deploy token was being passed
as an inline env assignment on the `ssh` command line**, visible in `ps` on the manager, now piped over
stdin, with an honest note that the HTTP registry sends it in clear anyway; and **`df -h /` added to
Part 1's verification** — template 9000's disk is only **3584M**, so if cloud-init's `growpart` does
not fire you get a 3.5 GB root that dies on the first image pull, with an error about layers rather
than about disk.

**Phase 15 was stale rather than wrong.** Its header still claimed "nothing is committed yet" (it went
in with `104a1e0`); all 23 task checkboxes were unticked despite §5c narrating the work as done; §1 was
titled "where things stand today" while describing the pre-move tree; and the validation table listed
`figcheck.py … exits 0` when §5c records it exiting **1** on four accepted sub-10pt figures — a future
reader would have read that as a regression. All corrected, with the `tools/` row marked `[~]` because
that move turned out to be unnecessary rather than done.

⚠️ **The substantive phase15 fix is §4.** The six job-description tracks are **not refuted** by
Andrew's answer — they are all *platform services* (MongoDB, observability, Vault, IAM, edge) while
GitHub/Jenkins/Swarm are *delivery tooling*. **Orthogonal, not competing.** What was wrong was the
**ordering**: it recommended observability → mongodb, and none of the three tools Andrew actually named
appeared anywhere. Revised order is **`docker-swarm` → `jenkins` → `observability` → `mongodb` → the
rest as reading**, and `jenkins` is now a provisional track row. O1 is marked **closed but partial** —
he said "what I know about their platform", so the platform-service half is still unconfirmed and
should be re-asked once he is inside.

### ⏭️ Next

1. ✅ **Done — the real stack is known** (GitHub + Jenkins + Docker Swarm; DevOps-first SRE role).
2. Fix the track list in `phases/phase15_education_program.md` §4 against that stack — Swarm is now
   confirmed track 2, and **Jenkins is a strong candidate for track 3**.
3. ✅ **Done — `phases/phase16_docker_swarm.md` written and awaiting Andrew's go-ahead** before any VM
   is cloned. **Agreed model: one phase file per track**, with the track README staying a
   reader-facing index and the phase file holding the working record.
4. Track 1's own chapters 8–10 (Schema Registry, OpenSearch + Fluent Bit, failure drills) remain
   planned and unblocked — the cluster is still at snapshot `s05-app-running`, now on 16 GB / 8 vCPU.
   ⚠️ **Re-seed the topics first** (7-day retention aged all events out on ~Aug 10), and note that
   OpenSearch still fits in 16 GB if chapter 9 goes ahead.
5. ⏳ **Time-boxed, not optional: the Redpanda trial licence expires ~Aug 25, 2026** (found Aug 12).
   `partition_auto_balancing_continuous` + `core_balancing_continuous` are in use from chart defaults.
   Decide to disable them or request a licence. Expiry on a rig this size should not be disruptive,
   but it should not be a surprise either — and it would make a good chapter-10 failure drill.
6. Cosmetic-only, low priority: the 4 figures at 9.4–9.9 pt. **Andrew confirmed print quality is
   fine**, so this is optional forever unless a reprint looks wrong.
7. **Infra follow-ups raised and deliberately deferred on Aug 12** (offered, Andrew chose docs only):
   - **GitHub pushes are impossible from the laptop** — `origin` is SSH and no PAT exists. Fix would
     be registering the laptop's key or switching to HTTPS + token.
   - **No out-of-band console for `.150`.** Route B (RDP to the Windows Z8) covers *entry* if the
     host's `tailscaled` fails, but a broken bridge/firewall on `.150` is still unrecoverable remotely.
   - **Tailscale on the dev box** would make it a direct tailnet node and drop the RDP hop.
8. Measure RAM/CPU headroom on the other VMs (GitLab 24 GB, SonarQube 12 GB) the way 186 was measured
   — 186 gave back 16 GB and 8 threads, and the Phase 15 study clusters will want more.

---

## ✅ CLOSED: Phase 14 — Kubernetes + Redpanda POC (was interview prep, ~1 week)

**Full plan + learning material: `phases/phase14_k8s_redpanda_poc.md`.** This was a learning rig
with a deadline (financial institution interview), not a production service. **It did its job — see above.**
All `education/` paths below moved to `education/k8s-k3s-redpanda/` on Aug 12.

### 🎯 THE ROLE (confirmed July 27) — SRE / DevOps on an ORDER MANAGEMENT SYSTEM

This is the single most important framing fact for everything in this phase. **Weight all teaching
and documentation toward operational reasoning** — failure modes, runbooks, what you do at 3am,
which instincts make an incident worse — rather than application design. **Tie every concept back
to a consequence for order/trade processing.** Examples that landed well: an unkeyed producer means
a cancel can be processed before the order it cancels; a 2-of-3 cluster has full data redundancy but
**zero** fault tolerance, so the reflex to "just bounce something" turns degraded into outage.
Andrew explicitly asked for these caveats to be kept in the docs.

### ✅ Parts 1 & 2 COMPLETE — the box is built and idle (July 25, 11:31–11:40 AM)

**Part 1 — first template in the lab: VM 9000 `tmpl-ubuntu-2404-cloudinit`**
- Installed `libguestfs-tools`, added `snippets` to `local` storage.
- `virt-customize` baked + enabled `qemu-guest-agent` into the Ubuntu 24.04 cloud image and
  truncated machine-id. Pristine image copy kept alongside it.
- VM 9000 built with the lab's standard disk flags, cloud-init drive attached, then templated.
  Its disk is now `vm-ephemeral/base-9000-disk-0` (4.81 GB) — PVE renames template volumes.
- ⚠️ **Key gotcha:** the host's `/root/.ssh/authorized_keys` (symlink to `/etc/pve/priv/`)
  holds **only the PVE cluster RSA key** — not the workstation key. Cloning with it would have
  produced an unreachable VM. Use **`/root/cloudinit-keys-all.pub`** (workstation ED25519 +
  PVE RSA) as the cloud-init key source for all future clones.

**Part 2 — VM 186 `vm-k8-redpanda-1` @ 192.168.1.186** (built 16 vCPU / 32 GB / 300 GB,
vm-ephemeral — **right-sized to 8 vCPU / 16 GB on Aug 12**, see the right-sizing section above)
- Full clone → booted → `cloud-init status: done` in **~30 seconds** (vs ~30 min of ISO clicking).
  Root fs auto-grew to 290 GB, unique machine-id, key-based SSH, guest agent responding.
- `host_setup.sh` ran unattended: Docker 29.6.2 + Compose v5.3.1, NAS at `/mnt/DevShare`,
  passwordless sudo — all verified. Needs `smb_credentials` staged next to it; it isn't auto-fetched.
- Purged **Chrome + Cursor** that `host_setup.sh` installs (desktop script on a headless box):
  4.4 GB → 2.6 GB. Consider a `--headless` flag on that script later.
- Disabled `unattended-upgrades` + `apt-daily` timers; VM 186 also stays **out of `refresh.sh`**.
  No package churn while learning. Swap is off, which is what the kubelet wants.
- Reboot test: back in 25 s, Docker + NAS persistent, no failed units.
- **Snapshot `s01-base-clean` taken.** Note: PVE snapshot names **must start with a letter** —
  `01-base-clean` is rejected, hence the `s` prefix.

### ✅ Part 3 — k3s INSTALLED (July 27, 8:33 AM) — snapshot `s02-k3s-up`

- **k3s v1.36.2+k3s1** (Kubernetes 1.36) on VM 186. Node `Ready` as `control-plane`, containerd
  2.3.2, ~512 MB RSS. Install took ~15 seconds. **Verified it survives a reboot.**
- Add-ons k3s brought: coredns, local-path-provisioner, metrics-server, traefik, svclb-traefik
  (DaemonSet), plus 2 `helm-install-traefik` Jobs at `Completed` (that's success, not failure).
- kubeconfig copied to `~/.kube/config` (mode 600). Used `$(id -u):$(id -g)` for chown, **not
  `$USER`** — `$USER` leaves the group as root and is unset in non-interactive SSH.
- Added to `~/.bashrc`: kubectl completion, `alias k=kubectl`, `KUBE_EDITOR=nano`.
- ⚠️ kubeconfig points at `127.0.0.1:6443` → only works ON VM 186. For the Z8, copy it and change
  the server to `https://192.168.1.186:6443`.
- ⚠️ `kubectl wait --for=condition=Ready pods --all -n kube-system` **times out on a healthy
  cluster** — Job pods complete instead of becoming Ready.

**Things proven live (kept as teaching material, all cleaned up afterwards):**
- Deleted coredns → replaced in 6 s. Ownership chain is Pod → ReplicaSet → Deployment, so the
  **controller-manager inside the k3s binary heals the add-on pods**.
- `local-path` PVs carry a **hard node affinity** to `vm-k8-redpanda-1`, and `WaitForFirstConsumer`
  means no volume exists until a pod is scheduled. So on node loss a pod isn't rescheduled
  elsewhere — it sits `Pending` forever.
- **Container restart ≠ pod replacement.** Container crash: same pod name/UID/IP, `RESTARTS` climbs.
  Pod deleted: new name, new UID, new IP, restarts back to 0. Different debugging entirely.

### 📘 NEW: `education/` series started (July 27)

Andrew's idea — printable study chapters with illustrations, for interview prep. Includes his own
**"ranch model"** analogy (ranch=cluster, field=node, herd=pod, cow=container, brand=label, barn
name=Service) plus a "where the analogy breaks down" section.

**Chapter 1 is now 846 lines / 6 diagrams / 31 self-test questions** (was 548 / 5 / 22). Everything
added on July 27 came out of something Andrew actually ran:

- **§5** gained the **EndpointSlice** chain (kube-proxy never evaluates selectors — a controller
  materialises them into an EndpointSlice, which is why an empty slice is the thing to check when a
  Service blackholes), the DNAT-invisibility proof, and **per-connection not per-request load
  balancing** → the gRPC/HTTP2 single-backend trap. That last one is squarely interview material
  for a firm shipping market data over gRPC.
- **§6** rewritten from a 24-line summary into a full walkthrough: new **fig6** showing the six
  layers from ZFS pool down to `/data/notes.txt`, the PVC lifecycle he drove, "the requested
  capacity is a fiction" (local-path sets no quota), and the single-failure-domain admission for
  the coming 3-broker Redpanda cluster.
- **§7** gained the 30-second grace-period table + PID 1 signal rule.
- **§9a** is new: the `kubectl` command grammar and the three real errors from the session.

**Chapter 3 (Redpanda) written July 27 — 1023 lines, 3 diagrams, 33 self-test questions.** It is
deliberately a **runbook**, not just theory: full install (incl. the failed first attempt and its
symptom cascade), the `rpk` wiring, verified demos, and the failure drills, so it can be replayed on
another lab cluster. New `education/k8s-k3s-redpanda/manifests/` folder holds real tested artefacts — currently
`redpanda-values.yaml`. Every command in it was executed and every output quoted is real; where a
result varies between runs (sticky-partition choice, initial leader assignment) the chapter says so
explicitly, because Andrew intends to re-run all of it.

**Chapter 2 (object model) written July 27 — 631 lines, 2 diagrams, 27 self-test questions.** Written
straight out of the 3:00–3:30 PM hands-on session below, so it is also a runbook:
`manifests/web-deployment.yaml` is the tested Deployment + Service with **both probe failure drills
documented inline as sed-able comments**, verified end-to-end (`apply` → `rollout status` → `200`s →
`delete`). Fig 2 is the chapter's payoff — the readiness-vs-liveness asymmetry side by side.

**Chapter 4 (provisioning application state) written Aug 3 — 823 lines, 3 diagrams, 24 self-test
questions + 10 worked interview answers.** The theme is the boundary between the two control planes:
Kubernetes builds brokers, Redpanda owns topics, and nothing owns the gap. Ships two tested artefacts
— `manifests/seed-topics.sh` (idempotent *and* drift-checking) and `manifests/seed-topics-job.yaml`
(the health-gated Job). Generalises deliberately: Schema Registry subjects, OpenSearch index
templates and DB migrations are the same problem, so Chapters 5–6 reuse the pattern.

**Chapter 5 (consumer groups) written Aug 3 — 488 lines, 3 diagrams, 24 self-test questions +
9 worked interview answers.** Covers partition assignment, the parallelism ceiling, key skew, lag,
rebalancing and delivery semantics. Ships `manifests/consumer-group-lab.sh`, a step runner that
replays the entire session. **Chapter numbering shifted:** Schema Registry is now 6, OpenSearch 7,
the app 8, failure drills 9.

**Diagrams are Graphviz `.dot` sources in `education/k8s-k3s-redpanda/diagrams/`, NOT AI-generated** — image
generators garble technical labels, and these need to be exactly right. Installed `graphviz` on the
Z8 for this. Editing gotchas (both now in `education/README.md`): newlines inside HTML-style labels
render as literal leading spaces, so keep each table cell on one source line; and `BALIGN="LEFT"`
only aligns lines *after* a `<BR/>` — set **both** `ALIGN="LEFT" BALIGN="LEFT"` on the `<TD>`, and
use a one-cell `<TABLE>` rather than `shape=box` for callouts.

### ✅ Part 3 COMPLETE — guided hands-on session (July 27, 11:15 AM – 12:50 PM)

**Andrew typed every command; I coached and verified out-of-band over SSH.** That format worked
well — keep using it. Cluster was returned to clean afterwards.

What he built and broke, in order:

- **Deployment by hand** (nginx:1.27-alpine, requests+memory limit). One manifest produced
  **three objects**: Deployment → ReplicaSet → Pod. Container is a fourth thing but not an API
  object.
- **`-l app=web` did not match the Deployment** — the manifest only put labels in
  `spec.template`, so the Deployment itself had none. Labels are per-object. Real manifests
  normally repeat them in top-level `metadata`.
- **Imperative/declarative drift:** `kubectl scale --replicas=3`, then re-applied the unchanged
  file → snapped back to 1. Best possible argument for GitOps. Scaling does **not** make a new
  ReplicaSet (template unchanged).
- **Self-healing:** deleted a pod → replacement in ~1 s, **new name, new IP**, ReplicaSet name
  unchanged. Speed was partly luck: the image was already cached. In production image pull time
  dominates recovery.
- **Rollout + rollback proved the hash is deterministic.** Changed image to `traefik/whoami` → a
  2nd ReplicaSet appeared. `kubectl rollout undo` → the **original RS came back to life, still
  50 minutes old**, rather than a third being created. Revision history then read `2, 3` (not
  `1, 2`) because a ReplicaSet only carries its most recent revision number.
- **Service.** ClusterIP `10.43.83.136`, 3 endpoints. `curl -w "%{remote_ip}"` returned the
  **ClusterIP every time** — DNAT is invisible to the client. The nginx access logs showed the
  real spread (4/3/5), so LB was working; the measurement was wrong.
- **PVC lifecycle.** `Pending` while unbound (WaitForFirstConsumer), `Bound` the instant a pod was
  scheduled, data survived pod deletion + recreation, and `kubectl delete pvc` destroyed the
  directory with no prompt (RECLAIMPOLICY=Delete).
- **Namespaces `redpanda` / `market` / `logging` created.** Demo workloads torn down; storage dir
  back to 0 entries.

**Three quirks worth remembering (all now documented in Chapter 1 §9a / §7):**

1. `name:web` (no space after the colon) → `cannot unmarshal string into Go struct field
   metadataOnlyObject.metadata of type v1.ObjectMeta`. YAML needs **colon + space**; that rule
   exists so `image: nginx:1.27-alpine` isn't torn in half. Use `--dry-run=client` to catch it.
2. `kubectl describe pod kube-system` → NotFound, because a **namespace was put in the name slot**.
   Grammar is `kubectl <verb> <type> <name> [-n <ns>]`, and `describe` defaults to `default`.
3. Object names must be **lowercase RFC 1123** — `kubectl run graceA` is rejected. They become DNS
   records.

**`kubectl delete pod` taking 30 s is correct behaviour**, and Andrew caught it himself. Measured
on this cluster, same busybox image: `sh -c "sleep 3600"` = **31 s**; with `trap ... TERM` = **2 s**;
nginx = **2 s**; `--grace-period=5` = **7 s**. Cause is the **PID 1 signal rule** — PID 1 in a
namespace only receives signals it has a handler for, even from the kubelet. Only SIGKILL/SIGSTOP
are forced. Consequence: containers that ignore SIGTERM make rolling updates and node drains crawl.
**Never `--grace-period=0 --force` a broker** — the replacement can start while the original still
holds the volume.

### ✅ Part 4 COMPLETE — Redpanda installed, broken, and healed (July 27, 1:00 – 2:50 PM)

**3-broker cluster live in ns `redpanda`.** Chart `redpanda-26.1.9` / app `v26.1.12`, `rpk v26.1.14`,
Helm v3.21.3. PVCs `datadir-redpanda-{0,1,2}` 20Gi local-path. Topic `market-ticks` 6 partitions RF 3.
Cluster currently **healthy 3/3**. Values file is committed at
`education/k8s-k3s-redpanda/manifests/redpanda-values.yaml` and verified to reproduce the live release
(`helm get values` matches; `helm template` renders 0 × `requiredDuringScheduling`).

**Two real problems solved — both are the good interview stories:**

1. **Install hung, pods `Pending`.** Chart ships **hard** pod anti-affinity → only 1 broker can
   schedule on a 1-node cluster. ⚠️ **The documented override `statefulset.podAntiAffinity.type:
   soft` is VESTIGIAL in 26.1.9 — setting it does nothing.** Real path is
   `statefulset.podTemplate.spec.affinity`: null the `required...` rule, add a `preferred...` one.
   Habit installed: **`helm template … | grep -A14 affinity` BEFORE installing.**
   Symptom cascade to remember: Helm hangs → pods Pending → **PVCs Pending is a *symptom*** (local-path
   is WaitForFirstConsumer) → redpanda-0 never Ready (no quorum alone) → config Job fails → Console
   crash-loops. Diagnose with `kubectl describe pod redpanda-1 | tail -20`; read the **earliest stuck**
   thing, not the loudest broken thing.
2. **`rpk` could not reach brokers.** Dialled `localhost:31092`, error named `redpanda-0...` — the
   mismatch IS the diagnosis. Bootstrap only asks "who are the brokers?"; the client then dials the
   **advertised listeners** directly. Fixed by teaching the host cluster DNS:
   `/etc/systemd/resolved.conf.d/k3s-cluster-dns.conf` → `DNS=10.43.0.10`, `Domains=~cluster.local`
   (`~` = routing-only). rpk profile `local` now bootstraps off all three internal FQDNs :9093
   (Kafka) / :9644 (Admin). Survives pod replacement — nothing references a pod IP.
   ⚠️ Only works because **the host IS the node** (pod IPs on `cni0`). Not a LAN-wide solution.

**Measured facts that corrected my own explanations:**

- **Unkeyed ≠ round-robin.** Sticky partitioner: 6 unkeyed → 1 partition; **300 unkeyed → still 1
  partition.** *Which* partition is random per producer session (saw p1 one run, p5 the next).
  Keys ARE deterministic and reproduced exactly across runs: AAPL→3, GOOG→3, MSFT→0, TSLA→5, AMZN→5
  — 5 keys, only 3 partitions used, two collisions, p1/p2/p4 idle. This is why ordering bugs pass
  every dev test.
- ⚠️ **`rpk topic describe -p`: HIGH-WATERMARK is awk field `$8`, not `$6`** — `REPLICAS [0 1 2]`
  contains spaces. Cost me one wrong record count.
- ⚠️ **`rpk topic consume -n N` HANGS** if fewer than N records exist; piping to `wc -l` shows
  nothing (no EOF). Use **`-o :end`** = read all + exit. `-o start:end` silently returns **0**.
- **Failover is surgical but NOT load-balanced.** Killed redpanda-1: 2/2/2 → broker 2 took **both**
  orphaned partitions (leads 4). Writes never stopped.
- **Healthy ≠ balanced.** After recovery: `Healthy: true`, yet broker 1 leads **0** partitions.
  Leader balancer runs on its own timer (minutes).
- **Quorum loss (scaled to 1):** survivor goes `1/2 Running` and steps down, `Leaderless (8)`
  including **`redpanda/controller/0`** (lose admin too), producer **hangs** rather than errors, and
  ⚠️ **`Under-replicated` reads 0** — no leader left to compute it. **Alert on `Leaderless` +
  `Nodes down`, never on `Under-replicated` alone.**
- **Zero data loss proven.** 32 records reconciled exactly (`-o :end` count == Σ high-watermarks).
  Both writes made while degraded survived; the write that hung during quorum loss never appeared.
  *Never lies about whether an order was accepted* — that's the OMS framing.
- `helm uninstall` does **not** delete StatefulSet PVCs. `kubectl -n redpanda delete pvc --all`.
- A `redpanda-configuration-*` pod in `Error` next to a `Complete` Job is **normal Job backoff**
  (post-install raced broker readiness). Judge the Job, not the pod.

**Drill hygiene learned the hard way:** always
`kubectl -n redpanda wait --for=delete pod/<name>` before judging. Checking too fast caught a
`Terminating`-but-still-serving broker and produced a write that "should" have failed.

### ✅ Chapter 2 session — Deployments, rollouts, probes (July 27, 3:00 – 3:30 PM)

Same format: Andrew typed everything, I verified over SSH. `default` ns, `nginx:1.27-alpine`,
`replicas:3`, `maxSurge:1`, `maxUnavailable:0`. Five revisions across four ReplicaSets.
**Cleaned up afterwards — `default` empty, Redpanda untouched (Healthy, 33 records).**

- **The headline demo: same broken path (`/healthz` → nginx 404), wired two ways.**
  - **Readiness broken → fails SAFE.** Rollout stalls at 4 pods / 3 Ready. EndpointSlice shows
    `10.42.0.82 ready=false` while the other three are `true`. Service returns `200 200 200 200 200 200`
    — **the bad build never served a single request.**
  - **Liveness broken → fails DEADLY.** Readiness still passed, so the **rollout SUCCEEDED** and
    deleted all three good pods; only *then* did liveness start killing. All pods
    `CrashLoopBackOff restarts=4`, service returns `000 000 000 000 000 000`. **Total outage.**
  - One-liner to remember: **readiness gates the rollout, liveness does not.**
- **`CrashLoopBackOff` + `Exit Code: 0` ⇒ something external killed it — almost always liveness.**
  Best debugging heuristic of the session. nginx caught SIGTERM and exited clean.
- **`rollout status --timeout=60s` is client-side patience only.** It went red while
  `progressDeadlineSeconds=600` kept the rollout grinding in the background. A red CI job can leave a
  half-rolled deploy that everyone assumes never shipped.
- **`Available=True` while the deploy was broken.** Availability ≠ rollout success. Monitor
  `Progressing` too.
- **`rollout undo` leaves a landmine.** After a *successful* rollback: live cluster `/` (good), file on
  disk `/healthz`, `last-applied-configuration` `/healthz` (both broken). The next `apply` re-ships the
  outage. Andrew got this instantly — strongest GitOps argument available. Also **revisions get
  re-tagged**: history went `1,2,3` → `1,3,4`, so a revision number quoted earlier in an incident may
  not exist any more.
- **The two rollbacks differed, and that's the lesson.** After the readiness stall the good pods were
  never touched (RS held 3/3, age climbed to 8m38s) = zero disruption. After the liveness outage they
  were already destroyed, so rollback created new pods under the same hash = real downtime.
- **Andrew's one genuine misconception — re-check this later.** He thought `maxUnavailable` protects
  Raft quorum. It doesn't: it's a **capacity** guarantee, and the Deployment controller counts Ready
  pods with no concept of consensus. Answered in Ch2 §9 (StatefulSet ordinal updates, PDBs for
  *voluntary* disruption only, cluster-aware readiness), tied back to Part 4's finding that
  `Healthy: true` coexisted with a broker leading zero partitions.
- Minor but confirmed: `apply` printing `configured` does **not** mean a rollout happened (only
  pod-template changes churn pods); scaling makes no new ReplicaSet; labels are per-object
  (`-l app=web` missed the Deployment until `metadata.labels` was added).

### ✅ Chapter 4 session — topic provisioning, idempotency, drift, the readiness race (Aug 3, ~1:00 – 5:45 PM)

Long session, six demos, all written up the same day. Framing was Andrew's: *"what would I do as a
DevOps guy during a pipeline deployment to get the brokers deployed and the topics seeded?"*

- **The gap, proved.** With `auto_create_topics_enabled=false`, producing to an unseeded topic fails
  `UNKNOWN_TOPIC_OR_PARTITION` exit 1 — while Helm says `deployed`, pods are `Running` and
  `rpk cluster health` says `Healthy: true`. **Infrastructure green ≠ service usable.**
- **`rpk topic create` is not idempotent** (exit 1 on `TOPIC_ALREADY_EXISTS`). Naive Job works on the
  first deploy, then fails forever. Guard is `rpk topic describe` (exit 0 = exists).
- **`kubectl wait --for=condition=complete` only watches for success.** Job died at 34s, the wait sat
  the full 90s then reported a *timeout* — wrong cause, wasted time. Race both conditions (§9a).
- **THE headline finding — pod-Ready is not cluster-ready.** Andrew spotted the state by accident,
  then we measured it: **`21:32:02` all 3 pods `2/2 Ready` → `21:32:11` `Healthy: true`. A 9-second
  window** where every Kubernetes signal was green and **11 of 18 partitions were leaderless.** It was
  11 not 18 because each partition is its own Raft group and they elect independently.
- **`Under-replicated partitions (0)` while 11 were leaderless — the metric lied for the second time**
  (first was the Jul 27 quorum drill). No leader ⇒ nobody computes it. **Alert on `Leaderless`.**
- **The trap inside the fix:** `rpk cluster health` is an **Admin API (:9644)** call. `-X brokers=`
  (Kafka API :9093) is *silently ignored*, so rpk fell back to `127.0.0.1:9644` and the guard hung
  5 minutes against a healthy cluster. Tested from inside `redpanda-0` it "worked" — because there
  localhost:9644 really is a broker. **A health gate that can't reach its target looks exactly like an
  unhealthy target.** Correct flag: `-X admin.hosts=`.
- **Retry moved from pod level into the container.** `backoffLimit` conflates "tolerate a slow
  dependency" with "retry a real error". An init container polling for health decouples them: 600s
  wait budget, `backoffLimit: 2` failure budget. Costs **0s** healthy, took **50s** through a full
  scale-to-zero outage.
- **Fixed sleeps are unfixable:** scheduled→Ready was **21s** warm and **~2 min** cold.
- **Idempotent ≠ reconciling.** An existence-only guard reports success forever on a topic with 2
  partitions where 6 were declared. Led to the **three-tier drift model**, all four behaviours
  captured live: **Tier 1** (retention → fix in place, exit 0), **Tier 2** (RF → report, exit 1, human
  schedules the data movement), **Tier 3** (partition count → *never* auto-fix, exit 1).
- **Script design notes:** `set -uo pipefail` deliberately **without `-e`** so every drift is reported
  in one run, not revealed serially; and `awk` on table output rather than `jq`, which the broker
  image doesn't ship — using the broker's own image also keeps `rpk` version-matched to the cluster.
- Confirmed `publishNotReadyAddresses: true` on the headless Service, so **DNS resolution is not a
  readiness signal** — it hands out brokers that aren't accepting connections yet.
- Also confirmed: `market-ticks` records from Jul 27 had **aged out** via `retention.ms=604800000`
  (`LOG-START-OFFSET` caught up to `HIGH-WATERMARK`). Not data loss.

### ✅ Chapter 5 session — consumer groups, rebalancing, delivery semantics (Aug 3, 5:50 – 6:30 PM)

Same format, five hands-on steps on topic `orders` (6 partitions, 1500 records, 12 keys) with group
`oms-processor` grown 1 → 7 members and back to 5.

- **Three rules of assignment:** one owner per partition at any instant; a consumer may own many;
  **assignment counts partitions, not records.** At 2 members the split was 3/3 by partition and
  **120 vs 60 by data** — one consumer doing double the work, permanently.
- **Parallelism ceiling proved:** 7 consumers on 6 partitions → the 7th got **no assignment, zero
  records**. And `c1` owned p0 which has **never held a record**, so 7 consumers, only 5 working.
  **Worst-case lag is set by the hottest partition, not the consumer count.**
- **But idle ≠ useless** — when the p2 owner was killed, the surplus `c7` **inherited it instantly**
  (already connected, already in the group). A surplus consumer is a **warm standby**. I'd called it
  "pure cost" one step earlier and the next demo disproved it.
- **Skew, quantified:** 12 keys hashed into 6 partitions gave p2 **5 keys = 42% of traffic** and p0
  **zero**. Andrew asked the right question — why doesn't Redpanda rebalance it? Two answers: the
  producer computes `hash(key) % n` **client-side** so the broker never gets a vote; and moving a key
  would split its history across two partitions read by two consumers → **a cancel could be processed
  before its order**. Separate small-numbers skew (self-correcting at real cardinality) from a
  genuinely hot key (needs a composite key or dedicated topic — *not* more partitions).
- **⭐ THE demo: SIGTERM vs SIGKILL on the same partition.** p2 had 4 owners over its life:
  `c1 0..74`, `c6 75..137`, `c7 138..395`, `c2 393..624`. **SIGTERM** → committed and left cleanly,
  `137→138`, **zero duplicates**. **SIGKILL** → consumed through 395 but last commit was 392, so the
  successor replayed **393/394/395 (ORD-10, ORD-11, ORD-2) — 628 processed for 625 written.**
  Real-world OOM kills, force-deletes and liveness kills are all the SIGKILL case.
- **Duplicates = throughput × time since last commit.** Tuning the commit interval changes the odds,
  never the possibility → **the fix is an idempotent consumer**, not tuning. Exactly-once only covers
  read-process-write loops that stay *inside* the cluster.
- **Reading the describe table:** lag is per-partition (`TOTAL-LAG` is only the sum, and hides a
  stalled hot partition — **alert on max per-partition lag**); `CURRENT-OFFSET  -` means *never
  committed*, which is not offset 0.
- **Rebalances make distribution less fair over time** — after two deaths, one consumer owned both p2
  (hot) and p3. Nothing balances for load.
- **Offsets live in `__consumer_offsets`** — 16 partitions, RF 3, **`cleanup.policy=compact`** so they
  can't age out. Group name hashes to one partition (`/7` here) whose leader is the coordinator.
  Explains why `-o start` did *not* replay history for a newly joined member.
- Andrew's one misread, worth noting: seeing p2 records in several logs he said "everyone got some of
  his messages." It's a **relay, not sharing** — contiguous, non-overlapping ranges over time. The log
  file is the union of everything that consumer ever owned.

### ✅ Part 6 + Chapter 6 session — our own producer and consumer (Aug 3, 6:40 – 9:10 PM)

Built unattended. Python 3.12 + `confluent-kafka` 2.6.1, one image `oms:dev` with two entrypoints,
side-loaded into k3s containerd (no registry). Topic `orders-v2` 6p/RF3, group `position-keeper`,
`order-gateway` Job + `position-keeper` Deployment in ns `market`. Source at `education/k8s-k3s-redpanda/app/`.
Workload is **2000 orders × (1 NEW + 4 FILL) = 10,000 events / 8,000 fills / 800,000 shares**, with
fixed arithmetic so the right answer is knowable without coordination.

**Chapter 6 is built around four bugs, three of them mine.** They turned out to be far better
material than the working version would have been.

- ⭐ **The demo that "failed".** Two ledgers, hard kill mid-stream, expecting the naive one to
  inflate. Got **zero duplicates in both** — because both were in the *same SQLite transaction*,
  committed just before the offset. The kill rolled the writes back, the offset was also
  uncommitted, so state and offset stayed in lockstep and redelivery re-applied cleanly.
  ⇒ **A transactional state store + commit-after-write is effectively-once for free.** No dedupe
  table, no exactly-once protocol. That is the cheap answer, and most consumers qualify.
- **So duplicates only hurt when the side effect escapes the transaction.** Reworked the second
  ledger as a separate file on an autocommit connection (a stand-in for a POST to a venue). Same
  kill: **8011 gateway calls for 8000 real fills — 11 duplicate executions, 1,100 shares nobody
  ordered** — while the transactional ledger stayed exactly 800,000.
- **The tail that never commits.** Commit trigger was record-count only, so on an idle topic the
  last partial batch never committed: **lag stuck at 13 indefinitely**, and that tail replayed on
  *every* restart — duplicates went **11 → 22 → 33, compounding**. Fix: commit on count **or**
  elapsed time, including on the idle path. ⇒ **stuck lag is a commit-policy bug; a slow consumer's
  lag changes.**
- ⚠️ **`kubectl delete pod --force --grace-period=0` is not a reliable SIGKILL.** The runtime still
  delivered SIGTERM and my handler shut down cleanly — I was testing the graceful path believing it
  was the hard one. `kill -9 1` inside the container fails too (the kernel shields PID 1). What
  works is killing from the node; confirmed by `lastState: Error:137`, the same code an **OOM kill**
  gives. It was a **container restart in place**, not a pod replacement.
- **A hung consumer looks exactly like a healthy one.** A SQLite lock bug left it processing one
  record while `1/1 Running` with a clean log and zero restarts. Only lag showed it. ⇒ liveness
  should assert **progress**, not that the process exists.
- **`acks=0` lost 29 records silently** — `delivered=15000 failed=0` but 14,971 in the topic, against
  15,000/15,000 for `acks=all`. **The whole benefit was 0.2 seconds.** A duplicate is loud and
  recoverable; a lost fill is a position you don't know you hold.
- **Ch5's skew caveat confirmed:** 12 keys gave 42% on one partition; **2000 keys gave a 9.4%
  spread.** Skew is a function of key *cardinality*, not partitioning.
- **Ordering proven, not assumed:** `seq_gaps=0` across 2000 orders, via per-order sequence tracking.
- `BALANCER range` here vs `cooperative-sticky` in Ch5 — **rebalance behaviour belongs to the
  clients, not the cluster.** And a per-event durable side effect cost **~8×** throughput (1,550 → 200
  events/s), which is *why* commit windows exist.

### ✅ Documentation session — audit, Word build, highlighting, Chapter 7 (Aug 3, 7:15 – 10:30 PM)

**Pure documentation. The VM was not touched — no k3s, no Redpanda, no drills.** Snapshot
`s05-app-running` is still the restore point and is unaffected.

- **Audited Ch1–6 against the artefacts** and fixed as I went (commit `8baab57`). Real errors, not
  polish: a wrong k3s memory claim, a broken `kubectl wait`, wrong `rpk group describe` column
  indices, a `Service` selector that did not match, a bad anti-affinity example, and record counts
  that disagreed with the scripts. Also hardened the shipped manifests — `restricted` PSA on ns
  `market`, `automountServiceAccountToken: false`, non-root `USER` in the Dockerfile.
- **Word `.docx` pipeline** (`education/tools/build_docx.py`, output committed to
  `education/k8s-k3s-redpanda/docx/`).
  7-inch column, Cambria 11 pt, single-spaced, images full width — Andrew's spec so it reads like a
  textbook and prints legibly. **The TOC was removed entirely** after it rendered as a literal "No
  table of contents entries found" banner on page 1; pandoc writes the field but only Word can
  populate it, so patching was the wrong fix and he said "drop all TOC".
- **Ch1's ranch allegory deleted** at his request; the piece-by-piece table stayed.
- **~15 % yellow highlighting across all 7 chapters** so he can revise from the marks alone.
  Character style `Key`, shade `#FFF3B0` (low saturation, chosen so print does not bleed). Marks are
  stored in the Markdown, so rebuilds keep them. Mechanics and traps are in MEMORY.md.
- **Chapter 7 — `additional_infra_stack`, 981 lines, 2 figures, 18 questions** (commits `720c655`,
  `134943b`). Commissioned straight off the job description and scoped by him to **research only,
  build nothing**: edge/Cloudflare, IAM + Symantec PAM, Vault, PKI/cert-manager, MongoDB, and
  OTEL → Prometheus/Grafana/OpenSearch, each framed as "how would this attach to *our* OMS at
  thousands of external and hundreds of internal users". Researched by five parallel subagents; the
  edge one died twice on `resource_exhausted` and I wrote that section by hand.
- **The chapter's argument, worth keeping:** every area maps onto something the earlier chapters
  already measured. Mongo write concern *is* `acks`; an arbiter downgrades the default write concern
  the way `min.insync.replicas=1` undermines `acks=all`; and putting the Kafka offset inside a Mongo
  transaction buys exactly-once for the database while **changing nothing** about the non-idempotent
  execution gateway — so **Ch5's 821,600 phantom shares would be exactly as phantom afterwards.**
- **Two corrections to earlier chapters, made inside Ch7** rather than by editing them (he said not
  to touch existing docs): Redpanda **does** now publish consumer-group lag behind an opt-in
  property, which qualifies Ch3 without overturning "lag is derived, not intrinsic"; and Ch6's
  "undetectable" hung consumer **is** detectable — a staleness gauge climbing at exactly one second
  per second.

### ⏭️ Next — SUPERSEDED (this list was written Aug 3, before the interviews)

> **Historical.** Read the Phase 15 section at the top of this file for what is actually next.
> The deadline this list was organised around has passed and the outcome was an offer.

1. **Nothing is blocked and nothing is half-finished.** All 7 chapters are written, audited,
   highlighted, built to `.docx` and committed.
2. ~~**Open verification item:** the `.docx` highlighting has never been *seen*.~~
   ✅ **CLOSED Aug 12** — Andrew confirmed the yellow looks right in Word. The OOXML inspection
   (318 `Key` runs, `FFF3B0` fill, no leaked markup) was correct. There is still no
   LibreOffice on the Z8, so future highlight work is still verified by unzipping.
3. ~~⛔ **Do NOT start chapters 8–10 before the interviews**~~ — no longer applies; the interviews
   happened Aug 6/7. Chapters 8–10 are now simply **planned and unblocked**. The motivation for 8
   (Schema Registry) is still sound: the app produces hand-rolled JSON with no contract, so renaming
   `qty` silently breaks the consumer. 9 is OpenSearch + Fluent Bit, 10 is failure drills.
4. Hands-on loose ends, ~an hour each, all still open and none urgent: a **liveness probe that
   asserts progress** on the consumer (Ch6 §13 argues for it but it was never built — it closes the
   one story that currently has no ending), Redpanda Console via port-forward, `rpk group seek` for
   replay, and a lag-alerting demo.

**📅 Timing — the interviews were Aug 6 and Aug 7, and Andrew got the job.** ✅ Everything from here
to the end of this section is the **Aug 3 run-up plan, kept as a record.** The one judgement in it
worth carrying forward: *unabsorbed documentation is worth nothing* — reading and drilling what
exists beat producing more of it, and that stayed true.

Two days almost certainly means two panels, so expect breadth. The asymmetry to manage: Ch1–6 is
material he *ran with his own hands* and can speak to from experience, whereas **Ch7 is the only
material he has merely read** — and it maps directly onto the job description's bullet list, which
makes it likely interview ground. That gap is the thing to close first.

Suggested use of the 3 days (proposed Aug 3, not yet agreed with Andrew):
- **Aug 4** — read all 7 chapters once, then revise from the yellow highlights. That is exactly what
  the 15 % pass was built for. Ch7 twice, since it is the unpractised half.
- **Aug 5** — hands on the box. Rebuild the muscle memory for the commands in the "know by heart"
  sections, and do the one build that is still missing: **a liveness probe that asserts progress**
  on the consumer. Ch6 §13 argues for it and it was never built, and "a hung consumer looks
  identical to a healthy one" is a strong story that currently ends without a fix.
- **Keep in reserve, only if time is genuinely free:** Redpanda Console, `rpk group seek` replay,
  lag alerting. All are nice; none are worth trading sleep for.

Redpanda remains the strongest part of the story. Part 5 (OpenSearch) is still the one to cut.

**Restore point: `qm rollback 186 s05-app-running`** (taken Aug 3 19:13, live via guest-agent
fs-freeze) — the OMS app deployed, reconciling, lag 0. Fallbacks: `s04-topics-seeded` (Aug 3 18:34,
pre-Part-6; rolling back that far removes `orders-v2`, the app and its PVC) and `s03-redpanda-up`
(Jul 27 14:58, healthy 3-broker cluster, no topics from Aug 3).
`s02-k3s-up` predates Redpanda — rolling back that far wipes it. Snapshot was taken **live** in 1.5 s
via guest-agent fs-freeze, no VM downtime, verified 0 restarts + 33 records readable after.

---

## ✅ qemu-guest-agent rolled out to all 5 live VMs (July 9, 1:20–1:28 PM)

Follow-up to the restore-drill finding (181 had no agent). For **181, 182, 183, 184, 200**:
- Installed + enabled `qemu-guest-agent` (Ubuntu pkg 1:8.2.2) inside each guest.
- `qm set <id> --agent enabled=1` on the host, then **graceful stop/start of each VM**
  (runner verified idle first; GitLab last). Total blip ~1 min/VM; GitLab ~3 min (Puma warmup).
- **All 5 answer `qm agent ping`** ✅ — PVE UI now shows guest IPs, clean shutdowns work,
  snapshot/backup fs-freeze available, future drills can verify via agent.
- Bonus: the stop/start cycled every VM onto the **new QEMU 11.0.2 binary** from this
  morning's PVE 9.2.4 upgrade (verified `running-qemu: 11.0.2` on all 5) — that loose end is closed.
- Post-checks: GitLab 200, public site https 200, QA 200, SonarQube 200, runner active.
- VM 185 (dormant OpenClaw) untouched — add the agent if it's ever revived.

---

## ✅ GitLab backup test-restore drill — PASSED (July 9, 1:08–1:20 PM)

Proved the nightly vzdump of VM 181 restores to a **fully working GitLab** (full procedure
+ findings in `phases/phase13_fable_proxmox_audit.md`, bottom section):
- `qmrestore` last night's backup → VMID 999 on vm-ephemeral (`--unique`): 2m17s, 0 errors.
- Isolation: NIC on a **host-only bridge vmbr999** (no physical port) + /32 route — clone
  runs with its baked-in .181 IP but can't touch the LAN; live GitLab unaffected (200 whole time).
- Verified: 16/16 gitlab-ctl services up, sign-in 200, DB intact (4 users, 5 projects,
  correct timestamps), **git clone of capricorn from the clone: 306 files, HEAD 92dc5fb** ✅.
- Teardown clean: VM 999 + bridge destroyed, vm-ephemeral back to 203G.
- Finding: VM 181 lacks qemu-guest-agent → install during future guest-internals phase.
- Repeat ~quarterly or after major GitLab upgrades.

---

## ✅ Phase 13 (final): Maintenance window — SNC off + kernel 7.0.14-4 adopted (July 9, 12:48–12:56 PM)

1. **SNC disabled in BIOS** (Andrew at console, F10 → "Sub-NUMA Clustering" → Disable) and
   **kernel 7.0.14-4-pve pin-tested via `--next-boot` in the same reboot.** Booted clean
   first try: **NUMA now 1 flat node / 128GB**, all 6 NVMe behind VMD, 0 NVMe errors, pools
   ONLINE, 5 VMs auto-started, public site 200. Slot 5 Bifurcation x4x4x4x4 + VROC untouched
   (confirmed: bifurcation, NOT SNC, drives the quad-NVMe card).
2. **7.0.14-4-pve made the PERMANENT pin** (was 7.0.6-2 since Jun 18). Fallbacks on ESPs:
   7.0.6-2 + 6.17.13-x. PERF-4 closed → **every audit fix Andrew approved is now done.**
3. **Subscription nag re-disabled:** widget-toolkit 5.2.6 (from today's upgrade) changed the
   code, killing the old sed patch in `/usr/local/bin/proxmox-update.sh`. Patched the live
   `proxmoxlib.js` (subscription check → `false`; backup `proxmoxlib.js.bak-nag-20260709`)
   AND rewrote the update-script line with the new perl pattern (idempotent, verified).

---

## ✅ Phase 13 (continued): Afternoon Session — BIOS checks, ashift rebuild, Z8 tuning (July 9)

**Everything below is also in `phases/phase13_fable_proxmox_audit.md` (findings + implementation log).**

### Done (11:53 AM – 12:35 PM)
1. **AMT verified DISABLED — no BIOS visit needed.** Discovered HP exposes all 280 BIOS
   settings read-only via `/sys/class/firmware-attributes/hp-bioscfg/attributes/` on the
   Proxmox host. "Intel AMT" = Disable, "ME Firmware Mode" = "AMT Disabled". Cross-checked:
   all AMT ports (623/664/5900/16992-16995) closed from LAN. SEC-5 closed.
   ⚡ REMEMBER: this sysfs path reads any BIOS setting on HP boxes without rebooting.
2. **SNC confirmed "Enable" at BIOS level** (same sysfs). Changing it still needs the console.
3. **vm-ephemeral rebuilt ashift=9 → 12** (PERF-2 closed). Procedure (~10 min total downtime):
   `qm shutdown 182 200` → `qm move-disk` both scsi0 → vm-critical (--delete) →
   `zpool destroy vm-ephemeral` → `zpool create -o ashift=12` on same 2 NM620s (by-id,
   serials …863 + …887, stripe) → `zfs set compression=lz4` → move disks back → start VMs.
   Verified: zdb ashift=12 both vdevs; runner buildx + QA Capricorn stack healthy.
   NOTE: NM620 only exposes 512B LBA (no 4Kn) — ashift MUST be set at pool creation.
4. **Z8 dev-workstation VM tuned (side quest, recorded in phase13 addendum):** 32 → 24 vCPUs
   as **2 sockets x 12**. sysbench: 898 → 996 ev/s per thread (93% scaling eff., was 83%),
   thread spread ±11.5% → ±4.3%. **Andrew's find: 2x12 → Windows schedules VM on idle PROC1;
   1x24 → co-located with Windows on PROC0. Keep 2x12** (VM owns a whole physical socket).

### Andrew's decisions this session
- **❎ WON'T-FIX:** vzdump jobs for 183/184 (rebuildable; WWW=vanity demo, Sonar barely used).
  GitLab 181 remains the only backed-up VM (it's the only one with irreplaceable data).
- **VM 185 (OpenClaw): leave dormant** — don't destroy, don't start.
- **host.fw: HOLD** (was already pending BIOS/ashift; now explicitly deferred with SEC-1/2).

### Remaining open items (all optional)
- ~~Console visit combo (SNC + kernel pin-test)~~ ✅ DONE 12:48 PM — see section above.
- ~~Test-restore drill of GitLab backup~~ ✅ PASSED 1:20 PM — see section above.
- Optional hardware: 2x32GB DDR4-2666 ECC RDIMMs → 6/6 memory channels (+bandwidth, →192GB).
- Deferred security items: SEC-1 (SSH key-only), SEC-2 (TOTP), host.fw.
- tailscaled NetInfo log noise (G3100 UPnP flapping) — ignore, or add
  TS_DEBUG_DISABLE_PORTMAPPER override; Andrew hasn't picked.
- Delete VM 184 snapshot `pre_phase12_firewall` once Phase 12 is trusted (~mid-July).

### Blockers
None.

---

## ✅ Phase 13: Proxmox Host Audit + Same-Day Fixes (July 9, 2026)

**Status:** Audit COMPLETE + all approved quick wins IMPLEMENTED. Full record (25 findings,
severity ratings, implementation log, rollback notes): `phases/phase13_fable_proxmox_audit.md`.
**Scope was host-only** (hardware/OS/PVE config); VM guest internals deferred to a later phase.

**Overall audit verdict:** host healthy — pools ONLINE 0 errors, NVMe 0–1% wear, no failed
units, kernel-pin policy working, Phase 12 rules live as documented.

### Done this session (chronological)
1. **Diag tools installed** (approved): nvme-cli, numactl, lm-sensors; coretemp persisted
   (`/etc/modules-load.d/coretemp.conf`). CPU pkg 51°C, all thermals healthy.
2. **Email alerting LIVE (was the #1 finding — every alert dead-ended before):**
   - PVE: endpoint `gmail-smtp` (smtp.gmail.com:587 STARTTLS, app pw in PASSWORDS.md),
     `default-matcher` → gmail-smtp. Covers vzdump + PVE alerts.
   - postfix: relayhost + SASL + root→gmail alias + ipv4 preference. Covers ZED/smartd/cron.
   - BOTH test mails confirmed received by Andrew. libsasl2-modules installed.
3. **Stale bookworm apt entries removed** (sources.list emptied; backup
   `/root/sources.list.bak-20260709`); apt verified clean.
4. **Full upgrade → PVE 9.2.4**, 0 pending. New kernels 7.0.14-4 + 6.17.13-15 landed on ESPs
   but **pin 7.0.6-2-pve verified intact** (won't boot until pin-tested). VMs stayed up;
   running VMs keep old QEMU binary until next stop/start.
5. **rpcbind + nfs-client disabled** — port 111 closed. NAS backup is CIFS → unaffected.
6. **ARC cap 8G → 16G** (runtime sysfs + zfs.conf + initramfs; backup /root/zfs.conf.bak-20260709).
7. **zpool upgrade** rpool/vm-critical/vm-ephemeral (block_cloning_endian, physical_rewrite).
8. **Deleted VM200 snapshot** `Generic-Host-Config` (+5.1G). Kept 184's `pre_phase12_firewall`
   deliberately until Phase 12 confidence window closes (delete in ~1-2 weeks).

### Decisions (Andrew)
- **⏸️ SEC-1 (SSH key-only on host) + SEC-2 (web UI TOTP) DEFERRED** — home lab in apartment,
  LAN-only, perimeter just locked down (Phase 12). Revisit later. Host SSH still root+password.
- Committing/pushing everything is ON HOLD (uncommitted: Phase 12 docs, phase13, MEMORY updates).

### Key discoveries for future work
- **vm-ephemeral pool is ashift=9** (zdb-verified; NM620 drives are 512B-LBA-only so fix =
  rebuild pool with `-o ashift=12`, ~1h Runner+QA downtime; vm-critical/rpool are correct at 12).
- **SNC enabled in BIOS** → 2 NUMA nodes (64.1+64.5 GB, distance 10/11); recommend disabling
  at next BIOS visit. Only **4/6 memory channels** populated (2x32GB more = +bandwidth +192GB).
- **Host runs Tailscale** (100.108.209.77) — was undocumented. **Idle Quadro P2000** on nouveau.
- **AMT unverified** — NIC literally named "amt" (I219-LM shared with Intel AMT); check MEBx
  at next BIOS visit.
- Fallback kernel 6.17.2-1 NO LONGER on ESPs (only 6.17.13-x, 7.0.x).

### Next steps (in rough priority)
1. vzdump jobs for VMs 183 + 184 (per phase8 recipe, stagger 02:30/03:00) + one test restore.
2. VM 185 (OpenClaw, retired) destroy decision → final backup then `qm destroy` (+51G freed).
3. Maintenance-window batch (console access): verify AMT off + disable SNC in BIOS →
   pin-test kernel 7.0.14-4 (--next-boot) → rebuild vm-ephemeral ashift=12 → optional host.fw.
4. Phase 8 monitoring stack (Prometheus/Grafana) — sensors now feed it.
5. Git commit/push when Andrew lifts the hold.

### Blockers
None. Host SSH access for automation = root + password (sshpass; PASSWORDS.md) — workstation
pubkey is NOT on the host (deliberate, SEC-1 deferred).

---

## ✅ DONE — Phase 12: Network Perimeter Lockdown (.184 as DMZ) — IMPLEMENTED July 8, 2026

**Status:** ✅ Implemented + validated. Full record: `phases/phase12_network_segmentation.md`.

**What's live (July 8):**
1. **Router:** public VNC/ARD to .200 deleted (Mac-mini = Tailscale-only). 80/443→.184 kept;
   Plex + Tailscale UPnP holes kept; .100 = Verizon ARRIS gear, left alone; UPnP stays enabled.
2. **Capricorn deploy = push:** runner (.182) pulls the images and streams them into .184 via
   `docker save | ssh docker load`; .184 never contacts the registry (.181:5050). On both
   `production` (e0f3057) and `develop` (9e5d2dc). Live-tested — pipeline #137 job #722 green.
3. **.184 inbound-only via Proxmox firewall** (`/etc/pve/firewall/184.fw`, datacenter fw
   enabled via new `cluster.fw`): IN DROP except 80/443 (any) + SSH from .182/.195/.150 + LAN
   ICMP; OUT allows gateway .1 + internet, DROPs all RFC1918. Other VMs unaffected (no .fw files).
   Rollback: `/root/184.fw.bak-20260708` on pve + VM snapshot `pre_phase12_firewall`.

**Validated:** .184 cannot reach .180/.181/.183/.150; internet + DNS from .184 fine; public
sites 200; admin (.195) + runner (.182) SSH in OK; .181→.184:22 blocked; :8080 blocked from LAN.
**.195 is a static IP** (Andrew confirmed) so the SSH allowlist won't go stale.

**Remaining (minor, optional):** off-LAN scan of the WAN IP to confirm only 80/443 answer.
**Next security work lives in Capricorn:** `unified_ui_DEV_PROD_GCP/project/phases/phase22*`
(the public app has no auth — app-layer hardening is now the weakest link).

**Where it came from:** a security review of the Capricorn app (other project,
`unified_ui_DEV_PROD_GCP`, `project/phases/phase22*`). While validating exposure I tested from
.184 itself and found the flat LAN lets the public-facing box reach everything private.

**Verified July 1, 2026 (probes run ON .184):**
- Network is flat: single `vmbr0`, `192.168.1.0/24`, no VLANs. Only .185 uses Tailscale.
- .184 (public, Traefik + Capricorn PROD) can reach **.180:5001/5002 (QA — REAL financial data,
  app has NO auth), .181:80/5050 (GitLab + registry), .183:9000 (Sonar)**. Pulled a real QA
  transaction from .184 with plain `curl` (total_count 4686).
- Router forwards only 80/443→.184, no :22 (per MEMORY — still VERIFY the G3100 table).
- .184 listeners: 80/443/22 + :8080 (Traefik dashboard, LAN-only, not public — bind to localhost).

**Andrew's model (decided this session):**
1. Public reaches ONLY .184:80/443. Nothing else public.
2. Internal LAN stays FLAT — everything-to-everything. NO internal micro-segmentation.
3. .184 does NOT need to reach any internal host → make it **inbound-only (DMZ)**.

**The one blocker to a pure DMZ:** `deploy_prod_local` in Capricorn's `.gitlab-ci.yml` currently
has .184 `docker login` + `docker pull` from the GitLab registry (.181:5050). Fix = switch to
**push** (runner does `docker save … | ssh agamache@.184 "docker load"`), removing .184's only
internal-outbound need. **This edit is in the Capricorn project — do it FIRST**, then this phase's
firewall change won't break deploys.

**Plan (see phase12 for full detail):**
1. Verify/tighten router: only 80/443 → .184.
2. (Capricorn) deploy push-not-pull.
3. Firewall .184: IN 80/443 any + SSH from .182/.195/.150; OUT internet + gateway .1 only;
   **DROP OUT to other 192.168.1.x VMs**. Snapshot + console access first (don't lock out SSH).
4. Optional: bind Traefik :8080 to localhost. Leave all other VMs unchanged (flat).

**⏳ DECISIONS AWAITED from Andrew:**
- Deploy method: `docker save|load` push (pure DMZ) vs keep .184 pulling + allow only .184→.181:5050?
- .184's DNS resolver (router .1 vs internal DNS VM) — needed so OUT rules don't break name resolution.
- Bind/keep Traefik :8080 dashboard?
- Order confirm: Capricorn deploy change first, then .184 firewall.

---

## GitLab VM backups → NAS (June 18, 2026, night) — Phase 8

**Status:** OPERATIONAL ✅  (details: phases/phase8_backups.md)
**What:** Set up nightly whole-VM backups of GitLab (VM 181) to the NAS for disaster recovery
(the ZFS mirror is not a backup; GitLab holds private-only data).

- NAS layout (NeoCortex 192.168.1.120, SMB only): `ProxmoxBackups/<hostname>/dump/...` —
  per-host subfolder so multiple servers can live under one `ProxmoxBackups`. GitLab →
  `ProxmoxBackups/vm-gitlab-1/`. Attached as Proxmox CIFS storage **`nas-gitlab`** (one storage
  per host, since a storage = one `dump/`).
- Created scheduled job **`gitlab-nightly`**: VM 181, storage nas-gitlab, **02:00 EDT** daily,
  **snapshot** mode (no downtime), **zstd**, **keep-last=7**.
- Seed backup verified: 500 GiB scanned (91% sparse) → **15.3 GB** archive, ~6 min, registered.
- Crash-consistent for now (guest agent not installed; safe for Postgres, and 2 AM is idle).
  App-consistent = enable QEMU guest agent + 1 reboot (deferred).
- Adding another server = mkdir `ProxmoxBackups/<host>` + per-host `nas-<host>` storage + job
  (see phases/phase8_backups.md).
- TODO: one proof-of-life test restore (VMID 999, isolated NIC).

---

## Dual-remote (GitHub-safe / GitLab-full) + secret scrub (June 18, 2026, night)

**Status:** COMPLETE ✅
**What:** Established the same dual-remote model as the Capricorn project
(unified_ui_DEV_PROD_GCP): SAFE/curated content → public GitHub, EVERYTHING (incl.
secrets, plaintext) → private GitLab. NO git-crypt / NO encryption.

### Remotes
- `origin` → GitHub (PUBLIC): `git@github.com:fiberoptix/home-lab-setup.git` (SSH). Curated;
  secrets `.gitignore`'d so they NEVER reach it. Update with **`./push_github.sh`**.
- `gitlab` → GitLab (PRIVATE): `http://root:<pw>@gitlab.gothamtechnologies.com/production/home-lab-setup.git`.
  HTTP "wallet" auth (pw baked into URL in `.git/config`, same as Capricorn/capricorn-docs).
  Full plaintext mirror, pushed with **`./push_gitlab.sh "msg"`**.

> ⚠️ **Renamed Aug 12, 2026: `gl-backup.sh` → `push_gitlab.sh`**, and a new `push_github.sh` was
> added. Push only via the scripts, never a raw `git push`. Everything below describing
> "gl-backup.sh" is the same code under the new name.

### push_gitlab.sh (repo root — formerly gl-backup.sh)
- Snapshots the ENTIRE working tree (tracked + ignored, minus `.DS_Store`) onto `gitlab/main`
  via a temp index — does NOT touch the working tree, real index, or the GitHub-bound `main`.
- Force-includes ignored files (PASSWORDS.md, github_credentials.md, proxmox/credentials,
  nas_credentials, /working/, /ddns/, vmware/*.zip, www/scripts/smb_credentials).
- Handles nested git repos (working/openclaw-ansible) by moving their `.git` to an external
  holding dir during the add, so their WORKING FILES are captured (not empty gitlinks) and
  their `.git` internals are NOT. Always restored.
- GitLab mirror = 98 files; GitHub = ~42 files. (As of Aug 12, 2026 the GitLab snapshot is 208
  files — the education program and its images account for most of the growth.)

### push_github.sh (repo root — new Aug 12, 2026)
- Pushes the curated tree to `origin/main`, and **fails closed**: nothing is pushed unless all four
  gates pass. Gates: (1) `origin` really is GitHub and we are on `main`; (2) no TRACKED file has a
  secret-looking name; (3) every known sensitive path that exists on disk is still gitignored;
  (4) the outgoing diff contains no private-key blocks, no URL with an embedded password, and no AWS
  keys. Then it lists the commits about to become public and demands a typed `yes`.
- **Why it exists:** GitHub has no encryption, so `.gitignore` was the only guard and "verify before
  pushing" was a convention a human or an agent could skip. This makes it enforced.
- ⚠️ **`--yes` is required for non-interactive use; without a TTY it refuses rather than assuming.**
- Content scanning deliberately uses only high-confidence patterns, so the *word* "password" in
  documentation does not trip it. The credentialed-URL check is the one that would catch the GitLab
  wallet (`http://root:<pw>@...`) being committed to a tracked file.
- **Proven, not assumed:** staging a fake `_gatetest.key` made it block, name the file and exit 1
  without pushing; repo state was byte-identical after cleanup.

### What the GitLab mirror preserves — and the context leak we closed

`gitlab/main` and `main` are **fully disjoint** (`git merge-base` finds nothing in common):
**82 real commits on `main` against 22 snapshots on `gitlab/main`.** The mirror keeps every *file*
perfectly and history only coarsely — though it is a genuine commit chain, so diffs between snapshots
work fine.

The leak was that a snapshot could not be tied back to the real history, and when the message
argument was forgotten the snapshot was labelled only `Full snapshot 2026-08-03 17:44:28 EDT` — tree
intact, reason gone. Two of the existing 22 look like that.

✅ **Closed:** `push_gitlab.sh` now auto-stamps. Default is
`Snapshot <ts> — main @ <sha>[+dirty]: <HEAD subject>`, and a message you pass gets
`[main @ <sha>]` appended. **`+dirty` flags a snapshot containing work in no commit at all**, which
is exactly when the SHA alone would mislead. Nothing is lost on the GitHub side — `push_github.sh`
never authors a commit, so real commit messages are untouched.

### Security scrub (CRITICAL — was a real leak)
- Found the master password (Proxmox/VMs/GitLab/NAS), the SonarQube admin password, an old
  deprecated password, and two SonarQube project tokens committed to PUBLIC GitHub (current
  files AND history) in MEMORY.md, phases/current_phase.md, www/scripts/setup_smb_mount.sh.
  (Actual values intentionally NOT repeated here — see PASSWORDS.md.)
- Scrubbed all of them from tracked files → `[See PASSWORDS.md]`. Real values live ONLY in
  PASSWORDS.md (gitignored → GitLab mirror) + `.git/config` wallet.
- Purged from ALL 54 commits with `git filter-repo --replace-text`, force-pushed GitHub
  (`546b85a`→`24cda0c`). Pre-rewrite safety bundle: `/tmp/home-lab-setup-prefilter-*.bundle`.
- User chose NOT to rotate the password. CAVEAT: GitHub may retain orphaned commits by SHA
  until GC; true fix would be rotation. (Offer remains open.)
- git-crypt setup that was started earlier was fully reverted (no `.gitattributes`, filters
  stripped, key removed).

### setup_smb_mount.sh password handling
- No longer hardcodes the SMB pw. Resolves it: `SMB_PASSWORD` env var → `www/scripts/smb_credentials`
  (gitignored; present on GitLab mirror so a LAN clone "just works") → interactive prompt.
- `www/scripts/smb_credentials` holds `SMB_PASSWORD='...'`, gitignored (rule in .gitignore),
  included on GitLab via gl-backup. NEVER on GitHub.

**Commits this session:** `24cda0c` (scrub + dual-remote + gl-backup), `db88fed` (smb_credentials
file wiring). GitLab snapshots: `f65cf2a` (initial full mirror), `087fc5b` (+ smb_credentials).

---

## Tested + adopted kernel 7.0.6-2-pve (June 18, 2026, later)

**Status:** COMPLETE ✅
**What:** After the PVE 9.2 upgrade pulled in `7.0.6-2-pve`, tested it with the same
reversible `--next-boot` procedure, then adopted it permanently.

- Shut down VMs → `kernel pin 7.0.6-2-pve --next-boot` → refresh → reboot.
- **Booted clean on 7.0.6-2** (permanent pin still 6.17.13-13 as auto-revert at that point):
  ZFS healthy, all 6 NVMe present behind VMD, **0 NVMe timeouts**, systemd running, VMs up.
- Made `7.0.6-2-pve` the **permanent pin** + refresh → **rebooted again to confirm it
  boots autonomously** (no next-boot crutch). Came back clean on 7.0.6-2, all 6 VMs up.
- **2 clean reboots total on 7.0.6-2.** `6.17.13-13` + `6.17.2-1` kept installed as fallbacks.
- Note: VM 185 (openclaw, `onboot=1`) auto-started slowly on the first 7.0.6-2 boot
  (had to `qm start 185`); on the confirmation reboot it auto-started fine. Minor timing,
  not kernel-related.

**Now running:** PVE 9.2.3, kernel **7.0.6-2-pve** (pinned). Revert if ever needed:
`proxmox-boot-tool kernel pin 6.17.13-13-pve && proxmox-boot-tool refresh` (console advised).

---

## Proxmox kernel upgrade 6.17.13-13 + PVE 9.1→9.2 + holds removed (June 18, 2026)

**Status:** COMPLETE ✅ (superseded same day by 7.0.6-2 adoption above)
**What:** Successfully escaped the pinned/held kernel state. Upgraded the Proxmox
host kernel into the 6.17 series again (the one that hung in Jan was 6.17.4-2; the
fix landed in 6.17.9+), brought the whole host current to PVE 9.2, and removed all
package holds so `apt` is normal again.

### Sequence (all with VMs gracefully shut down + physical console available)

1. **Graceful VM shutdown** — `qm shutdown` all 5 running guests, confirmed `stopped`.
2. **Installed `6.17.13-13-pve`** via dpkg-download (apt solver still blocked by the
   held `proxmox-default-kernel`). Set `proxmox-boot-tool kernel pin … --next-boot`
   (one-shot) so a failed boot would auto-revert to the permanently-pinned 6.17.2-1.
   `proxmox-boot-tool refresh` to write ESPs.
3. **Rebooted → booted clean on 6.17.13-13.** Verified: `zpool status -x` healthy,
   all 6 NVMe present behind VMD, **0 NVMe timeout/error lines**, `systemctl
   is-system-running` = running, all VMs auto-started (`onboot=1`). The Jan NVMe
   regression is GONE on this kernel.
4. **Made the pin permanent** (`kernel pin 6.17.13-13-pve` + `refresh`). Kept
   6.17.2-1 installed as fallback.
5. **Unheld** `proxmox-default-kernel` + `proxmox-kernel-6.17.2-1-pve-signed`.
6. **Full `apt full-upgrade`** → had to install the `proxmox-kernel-6.17` metapackage
   first (it was missing — that's the root of the recurring `proxmox-default-kernel
   : Depends: proxmox-kernel-6.17` solver error that also blocked tmux earlier). With
   the meta installed, the full upgrade ran clean: **PVE 9.1.4 → 9.2.3** (pve-manager
   9.2.3, qemu-kvm 11.0, ZFS 2.4.2, systemd 257.13, new shim/systemd-boot, ~160 pkgs).

### Current state

- **Running + permanently pinned:** `6.17.13-13-pve`
- **PVE:** 9.2.3 (`pveversion`)
- **Holds:** NONE (apt fully normal — the dpkg-download workaround is no longer needed)
- **Kernel images on disk:** `6.17.2-1` (old fallback), `6.17.13-13` (pinned/running),
  `7.0.6-2` (NEW PVE 9.2 default — installed but **NOT pinned, will not boot**)
- All 6 VMs running, ZFS healthy.

### ⚠️ Important for next time

- A new kernel **`7.0.6-2-pve`** was pulled in by PVE 9.2 as the new default. We are
  **deliberately NOT booting it** — the explicit pin on 6.17.13-13 controls boot
  regardless. If/when we want it, repeat the `--next-boot` dance (test, then make
  permanent) — same procedure as `phase1b`. Do this with console access.
- A **host reboot is recommended** to fully activate systemd 257.13 / libc / QEMU 11.
  It will safely boot back into pinned `6.17.13-13`. (Deferred — would restart VMs.)
- Running VMs still hold the **old QEMU 10.x binary** until each is stopped/started.

See `phases/phase1b_proxmox_kernel_upgrade_safe_try.md` for the full procedure + results table.

---

## `refresh` made detach/reattach-safe with tmux (June 18, 2026)

**Status:** COMPLETE
**What:** Wrapped the `refresh` command in tmux so a disconnected Proxmox web
console no longer kills an in-flight update+reboot run, and so the live status
screen can be re-attached after switching away.

### The problem (observed today)

Ran `refresh`; the 4 fast VMs (.180, .182, .183, .184) updated and rebooted and
showed `DONE` within ~5 min. GitLab (.181) is the slow one (Omnibus reconfigure
~6-15 min). While GitLab was still reconfiguring, the user switched the Proxmox
web UI from the **node Shell** to a **VM VNC console**. That tore down the node
Shell's websocket → `SIGHUP` → killed `refresh.sh` **and its child SSH session
to GitLab** before the final `sudo init 6` could fire.

Result: GitLab finished its apt upgrade (clean, `term.log` ended 18:06:42) but
**never rebooted** (uptime stayed at 14 days). Verified GitLab was idle
(dpkg lock free, no apt/dpkg/gitlab-ctl procs, Sidekiq drained to 0, no active
background migrations), then rebooted it manually from Proxmox
(`ssh agamache@.181 'sudo init 6'`). Came back healthy (all services `run:`,
`/-/readiness` → HTTP 200). All 5 VMs now updated **and** rebooted.

### The fix: tmux self-wrap in refresh.sh

`refresh.sh` now wraps itself in a tmux session named `refresh` (only when on a
terminal, not already inside tmux, and tmux is installed):

- **No existing session** → starts the run in a new tmux session `refresh`.
- **Session already exists** → `exec tmux attach-session` (re-attaches to the
  SAME running process; does NOT start a second run).
- After the run ends, the pane is held (`read`) so a reconnecting user can read
  the final summary (Enter to close, `Ctrl-b d` to detach anytime).
- Non-interactive callers (no tty, e.g. cron) fall through and run directly.
  Per-VM logs in `/tmp/refresh-<ip>.log` are written either way.

Because tmux's server is reparented to PID 1, the run survives the web console
dropping. So the workflow the user wanted now holds: type `refresh` → switch to
a VM VNC console → come back to the node Shell → type `refresh` → land back on
the **same** live status screen, still updating.

### tmux install note (kernel-hold gotcha)

`apt-get install tmux` was **blocked** by a pre-existing unmet dependency on the
Proxmox host: `proxmox-default-kernel : Depends: proxmox-kernel-6.17` (held back
per the kernel-pin policy — NVMe boot issue). Did **NOT** run
`apt --fix-broken install` (would pull a new kernel). Instead installed tmux
safely via dpkg with downloaded debs (deps already present), kernel untouched:
```bash
cd /tmp && apt-get download tmux libevent-core-2.1-7t64 libjemalloc2
dpkg -i tmux*.deb libevent-core*.deb libjemalloc2*.deb   # tmux 3.5a
```
**Pre-existing issue to flag:** the held kernel leaves apt's solver unable to do
normal `apt-get install` of new packages on the Proxmox host. Future package
installs there may need the dpkg-download workaround until the kernel hold is
lifted (Proxmox 6.17.5+ with NVMe fix).

### Validation (non-destructive)

Added a `REFRESH_SELFTEST=1` hook that swaps the per-VM remote command for a
harmless `sleep 45` (no apt, no `init 6`). Used it to prove, without touching
the VMs:
1. Script creates the `refresh` tmux session and runs the live display.
2. Killing the launching console (SIGHUP) leaves the session + run alive.
3. Re-invoking `refresh` attaches to the same session (still 1 session, still 5
   VM SSH sessions — not 10, i.e. no second run).

### Files

- `proxmox/build-scripts/refresh.sh` — added tmux self-wrap + selftest hook
- Deployed to Proxmox `/usr/local/bin/refresh.sh` (md5 matches repo)
- `tmux 3.5a` installed on Proxmox; `refresh` alias unchanged (script self-wraps)

---

## Parallel VM Refresh Script + GitLab Runner GPG Key Fix (May 23, 2026)

**Status:** COMPLETE
**Duration:** ~50 minutes (5:49 PM – 6:35 PM EDT)
**What:** Created `refresh.sh` on Proxmox to update + reboot all 5 home-lab VMs in parallel with live status display. Also fixed expired GitLab Runner apt signing key on .182.

### refresh.sh — Parallel VM Refresh

**Where it lives:**
- Repo: `proxmox/build-scripts/refresh.sh`
- Proxmox: `/usr/local/bin/refresh.sh` (deployed via scp)
- Alias: `refresh` in `/root/.bashrc` (just type `refresh` as root)

**VMs targeted (parallel):** .180, .181, .182, .183, .184
**Explicitly excluded:** .185 (vm-openclaw-1) — managed separately

**What it does on each VM:**
1. Pre-flight: records each VM's `/proc/uptime` (baseline for reboot detection)
2. SSH as `agamache` (key auth, no password)
3. `apt-get update && apt-get upgrade` non-interactively (`DEBIAN_FRONTEND=noninteractive`, `--force-confdef`/`--force-confold`, passwordless sudo)
4. On success (`&&`) → `sudo init 6`

**Live status (redraws every 30s with countdown between ticks):**

| State    | Meaning                                                                |
|----------|------------------------------------------------------------------------|
| RUNNING  | SSH session active, apt working                                        |
| SHUTDOWN | SSH ended (init 6 fired) but VM still reachable (<180s grace)          |
| BOOTING  | SSH ended, host unreachable (reboot in progress)                       |
| DONE     | Host back online with fresh uptime                                     |
| FAILED   | SSH ended; host stayed up with unchanged uptime past 180s grace        |

**Per-VM logs:** `/tmp/refresh-<ip>.log` on Proxmox

### SSH Key Setup (Option B chosen)

- Copied dev workstation's `~/.ssh/id_ed25519`/`.pub` to Proxmox `/root/.ssh/` (chmod 600/644)
- Same key already in `agamache@<vm>:~/.ssh/authorized_keys` (deployed Feb 27, 2026)
- Pre-populated `/root/.ssh/known_hosts` on Proxmox for .180–.184 via `ssh-keyscan`
- Verified: `root@pve → agamache@<each VM>` works key-only, passwordless `sudo -n` confirmed

### Bugs Found and Fixed During Development

**Bug 1: Wait loop blocked on hash-order, not completion order**
First draft used `for vm in "${!PIDS[@]}"; do wait ...; done` which iterates the associative array in bash hash-table order. Fast VMs were "stuck" behind slow ones in the display (GitLab took ~9 min while others took ~2 min, but their `[DONE]` lines couldn't print until GitLab's wait completed). Fixed by switching to **sentinel files** written by each subshell after its ssh exits, plus a polling loop that computes each VM's state independently each tick.

**Bug 2: Premature FAILED during VM shutdown window**
`sudo init 6` returns 0 immediately while shutdown proceeds asynchronously. SSH exits, but the VM is still reachable for ~5–90s before sshd dies. Initial detection logic saw `up >= PRE_UPTIME` and flagged FAILED — incorrectly. Fixed by adding a **180s grace window**: between sentinel-creation and grace expiry, the state is `SHUTDOWN` (not terminal). Only after 180s of "still reachable with old uptime" does it become `FAILED` (real apt failure with no reboot).

### GitLab Runner GPG Key Rotation (.182)

**Problem:** During refresh, `.182` emitted:
```
W: GPG error: ... EXPKEYSIG 3F01618A51312F3F GitLab B.V. (package repository signing key)
```

**Root cause:** Same key fingerprint, but the on-disk copy had `[expired: 2026-02-27]`. GitLab/packagecloud rotated the same keypair forward; the current upstream key expires **Feb 6, 2028**.

**Fix:**
```bash
sudo cp /etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg{,.bak.20260523}
curl -fsSL https://packages.gitlab.com/runner/gitlab-runner/gpgkey \
  | sudo gpg --batch --yes --dearmor \
             -o /etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg
sudo apt-get update   # confirmed clean
```

Fingerprint unchanged: `F6403F65 44A38863 DAA0B6E0 3F01618A 51312F3F`
Next rotation: before Feb 6, 2028

### Verified Both Refresh Runs Succeeded

| Run | All 5 VMs uptime after | systemd is-system-running |
|-----|------------------------|---------------------------|
| 1st (17:58–18:09) | 5–6 min (1 min for .181 due to GitLab Omnibus reconfigure) | running |
| 2nd (18:30–18:33) | 1–2 min (faster, no GitLab Omnibus update) | running |

### Lessons Learned

1. **`init 6` exit code is ambiguous** — often returns 0 because the SSH client reads the success status before the connection drops. Use uptime delta to confirm reboot, not exit code.
2. **Bash associative-array iteration is hash-order** — never rely on it for ordered work; use sentinel files / `wait -n` instead.
3. **GitLab Omnibus reconfigure is slow** (~6–15 min) because it walks hundreds of chef recipes (puma, sidekiq, gitaly, postgres, registry, prometheus, alertmanager). Other Ubuntu VMs finish in ~2 min.
4. **Packagecloud-style apt repos** (GitLab Runner, etc.) can re-issue the same keypair with a new expiration. Refresh by re-downloading from `packages.gitlab.com/.../gpgkey` and re-dearmoring into `/etc/apt/keyrings/` — no source list changes needed.

---

## OpenClaw Upgrade to v2026.4.5 — Three Config Fixes (Apr 6, 2026)

**Status:** RESOLVED
**Duration:** ~20 minutes (three rounds of crash-loop fixes)
**Problem:** After updating from v2026.3.28 to v2026.4.5, gateway crash-looped repeatedly due to multiple config schema changes. Doctor could not auto-fix all issues.

### Issue 1: `plugins.entries.telegram.config` rejected

v4.5 tightened the plugin config schema. The v3.28 doctor had duplicated Telegram channel settings (`groupPolicy`, `groupAllowFrom`) into `plugins.entries.telegram.config`, which v4.5 no longer allows.

**Fix:** Removed `config` sub-object from `plugins.entries.telegram` (data already existed in `channels.telegram`).

### Issue 2: `plugins.entries.elevenlabs.config` rejected

Andrew manually added ElevenLabs API key to `plugins.entries.elevenlabs.config` to restore TTS after the v3.28 migration stripped it. But v4.5 only allows `enabled` and `hooks` in plugin entries -- not a `config` block with API keys.

**Fix:** Removed `config` from `plugins.entries.elevenlabs`.

### Issue 3: ElevenLabs TTS credentials — correct v4.5 location

The ElevenLabs API key, voiceId, and modelId no longer go in `messages.tts` top-level keys (v3.x style) or `plugins.entries` (never valid). In v4.5, they belong under `messages.tts.providers.<provider>`:

```json
"messages": {
  "tts": {
    "auto": "inbound",
    "provider": "elevenlabs",
    "providers": {
      "elevenlabs": {
        "apiKey": "sk_...",
        "voiceId": "JBFqnCBsd6RMkjVDRZzb",
        "modelId": "eleven_multilingual_v2"
      }
    }
  }
}
```

**Schema discovery:** Used `openclaw config schema` piped through Python to find the correct path: `messages.tts.providers.elevenlabs` accepts `apiKey`, `voiceId`, `modelId`, `baseUrl`, `seed`, `applyTextNormalization`, `languageCode`.

### Verification

```bash
openclaw gateway status   # Running, RPC probe OK
openclaw status --all     # v2026.4.5, Telegram ON/OK, up to date
curl -s -o /dev/null -w "HTTP %{http_code}" http://127.0.0.1:1885/  # HTTP 200
```

### Lesson Learned

1. `openclaw doctor --fix` is not always sufficient -- it failed to fix the plugin config issues
2. `plugins.entries.<name>` in v4.5 only accepts `enabled` and `hooks` -- never API keys or channel settings
3. TTS provider credentials go under `messages.tts.providers.<provider>` (new in v4.5)
4. Use `openclaw config schema` to discover valid config paths when errors are unclear
5. Config backups before each upgrade are essential for diagnosing what changed

---

## OpenClaw Upgrade to v2026.3.28 Fix (Apr 6, 2026)

**Status:** RESOLVED
**Duration:** ~10 minutes
**Problem:** After updating OpenClaw and rebooting vm-openclaw-1, gateway crash-looped. Web UI wouldn't load, Telegram bot unresponsive.

### Root Cause

v2026.3.28 changed the TTS config schema. Two keys that were valid in v2026.3.23-beta.1 are no longer recognized:
- `messages.tts.elevenlabs` (removed/restructured)
- `messages.tts.openai` (removed/restructured)

Additionally, `channels.telegram.streamMode` was renamed to `channels.telegram.streaming`.

The gateway refused to start with the invalid config, crash-looping every ~5 seconds (reached restart counter 9+ within a minute of boot).

### Diagnosis

```bash
# Systemd logs showed crash loop
journalctl --user -u openclaw-gateway.service -n 50 --no-pager
# Every restart: "Config invalid" → "messages.tts: Unrecognized keys: elevenlabs, openai" → exit 1

# CLI also reported the issue
openclaw gateway status
# "Config invalid ... Run: openclaw doctor --fix"
```

### Fix Applied

```bash
# 1. Back up config
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak.pre-v3.28-fix

# 2. Run doctor to auto-fix config schema
openclaw doctor --fix --non-interactive
```

Doctor changes:
- Removed unrecognized `messages.tts.elevenlabs` and `messages.tts.openai` keys
- Renamed `channels.telegram.streamMode` → `channels.telegram.streaming`
- Archived 32 orphan transcript files
- Restarted gateway service

### Verification

```bash
openclaw gateway status   # Running, RPC probe OK (31ms)
openclaw status --all     # Telegram ON/OK, 1 agent active, 11 sessions
curl -s -o /dev/null -w "HTTP %{http_code}" http://127.0.0.1:1885/  # HTTP 200
```

### Lesson Learned

This is the **third** time an OpenClaw update has introduced breaking changes (v2026.2.23 allowedOrigins, v2026.3.22 missing UI assets, v2026.3.28 TTS schema). After any OpenClaw upgrade:
1. Back up config: `cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak`
2. Run `openclaw doctor --fix --non-interactive` immediately
3. Verify: `openclaw gateway status` and `openclaw status --all`

---

## OpenClaw Upgrade to v2026.3.23-beta.1 (Mar 23, 2026)

**Status:** COMPLETE
**Duration:** ~20 minutes
**Problem:** After upgrading from v3.13 to v3.22, Control UI showed "Control UI assets not found. Build them with `pnpm ui:build`"

### Root Cause

v2026.3.22 npm package has a **packaging bug**: the entire `dist/control-ui/` directory (index.html, assets/, favicon.ico) was omitted from the published package. The gateway runs fine but has no UI files to serve.

### Diagnosis

```bash
# Confirmed missing directory
ls $(npm root -g)/openclaw/dist/control-ui/
# No such file or directory

# Compared versions with npm pack --dry-run
# v3.13: dist/control-ui/ present ✅
# v3.22: dist/control-ui/ MISSING ❌
# v3.23-beta.1: dist/control-ui/ present ✅
```

### Fix Applied

Installed v3.23-beta.1 which includes the UI assets:

```bash
npm install -g openclaw@2026.3.23-beta.1
openclaw gateway restart
curl -s -o /dev/null -w "HTTP %{http_code}" http://127.0.0.1:1885/  # HTTP 200
```

### Lesson Learned

Before upgrading OpenClaw, verify the UI assets are included in the target version:
```bash
npm pack openclaw@<version> --dry-run | grep "control-ui/"
```
If no results, that version is broken. Skip it.

---

## OpenClaw Stuck Session Fix (Mar 16, 2026)

**Status:** RESOLVED
**Duration:** ~15 minutes
**Problem:** OpenClaw not responding to Telegram messages after apt updates + reboot

### What Happened

After upgrading to v3.13 and rebooting the VM, the Telegram bot received messages (showed "typing") but never responded. After 2 minutes, the typing indicator stopped without a reply.

### Root Cause

1. At 11:10 AM, a scheduled **heartbeat** request to `anthropic/claude-haiku-4.5` via OpenRouter timed out and was `aborted` after ~10 minutes
2. This left the session (`90acd894`) in a **locked state** with an active `.jsonl.lock` file
3. When the user's Telegram message arrived at 5:22 PM, it was routed into the same stuck session
4. The gateway showed "typing" for 2 minutes but the model call never executed

### Diagnosis

- Gateway was running (pid alive, RPC probe OK)
- Telegram channel showed OK (enabled, accounts 1/1)
- OpenRouter API worked fine (tested directly with curl → HTTP 200)
- Session transcript showed `prompt-error: error=aborted` for the heartbeat
- Active session lock file existed and was not stale

### Fix Applied

```bash
openclaw gateway restart
```

This cleared the stuck session lock and reset the processing pipeline. Telegram responded normally after restart.

### Lesson Learned

If OpenClaw receives messages but doesn't respond (typing indicator appears then stops):
1. Check logs for `typing TTL reached` — confirms messages arrive but model never responds
2. Check session locks: `ls ~/.openclaw/agents/main/sessions/*.lock`
3. Test OpenRouter directly: `curl -s -H "Authorization: Bearer $KEY" https://openrouter.ai/api/v1/chat/completions`
4. If API works but sessions are locked: `openclaw gateway restart`

---

## OpenClaw SSH & SSHFS Mount (Feb 27, 2026)

**Status:** COMPLETE
**Duration:** ~10 minutes

### What Was Done

1. **Fixed SSH key auth** from dev workstation to vm-openclaw-1 (192.168.1.185)
   - Used `sshpass` + `ssh-copy-id` to push ed25519 public key
   - SSH key auth now works (was broken since Phase 11 install — key offered but rejected)

2. **Set up persistent SSHFS mount** from dev workstation to OpenClaw VM
   - Mounts remote `/home/agamache` to local `/home/agamache/mnt/openclaw`
   - Symlink: `~/openclaw` → mount point (already existed from earlier attempt)
   - Implemented as systemd user service (`~/.config/systemd/user/sshfs-openclaw.service`)
   - Enabled lingering so service starts at boot (not just login)
   - Reconnect + keepalive options for network resilience

### Why systemd user service (not fstab)

fstab mounts run as root, so SSH auth tries root's keys (which don't exist for this host). A user service runs as agamache with the correct SSH key.

### Also enabled `user_allow_other` in `/etc/fuse.conf`

Uncommented `user_allow_other` in `/etc/fuse.conf` (needed for fuse mount options, left in place).

---

## SSH Key Auth + Cursor Sandbox Script Deployed to All VMs (Feb 27, 2026)

**Status:** COMPLETE
**Duration:** ~5 minutes

### What Was Done

1. **Deployed `fix_cursor_sandbox.sh`** to all 6 VMs (.180-.185)
   - Script fixes Cursor terminal sandbox on Ubuntu with kernel >= 6.2
   - Installs uidmap, sets capabilities on cursorsandbox binary, creates AppArmor profiles
   - Copied to `~/fix_cursor_sandbox.sh` on each VM

2. **Pushed SSH ed25519 key** to all 5 remaining VMs (.180-.184)
   - Used `sshpass` + `ssh-copy-id` (same method as .185 fix earlier)
   - All 6 VMs now have passwordless SSH key auth from dev workstation
   - No more `sshpass` needed for any VM

### VMs Updated

| VM | IP | SSH Key | Script |
|----|-----|---------|--------|
| vm-kubernetes-1 | .180 | ✅ | ✅ |
| vm-gitlab-1 | .181 | ✅ | ✅ |
| vm-gitrun-1 | .182 | ✅ | ✅ |
| vm-sonarqube-1 | .183 | ✅ | ✅ |
| vm-www-1 | .184 | ✅ | ✅ |
| vm-openclaw-1 | .185 | ✅ (earlier) | ✅ |

---

## OpenClaw Post-Update Fix (Feb 24, 2026)

**Status:** RESOLVED
**Duration:** ~15 minutes
**Problem:** OpenClaw gateway crash-looping after in-app update from v2026.2.19-2 to v2026.2.23

### What Happened

Andrew clicked the "Update & Restart" button in the OpenClaw Control UI. The update succeeded (v2026.2.19-2 → v2026.2.23) but the gateway immediately began crash-looping (567+ restarts by the time we connected, every ~10 seconds).

### Root Cause

v2026.2.23 introduced a **breaking security change**: non-loopback gateway binds (`gateway.bind: "lan"`) now require `gateway.controlUi.allowedOrigins` to be explicitly set. Without it, the gateway refuses to start with:

```
Error: non-loopback Control UI requires gateway.controlUi.allowedOrigins (set explicit origins),
or set gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback=true
```

The previous version (v2026.2.19-2) did not enforce this requirement.

### Fix Applied

1. SSH'd into vm-openclaw-1 (password auth -- SSH key auth from workstation is broken)
2. Backed up config: `~/.openclaw/openclaw.json.bak.pre-fix`
3. Added `gateway.controlUi.allowedOrigins` to `~/.openclaw/openclaw.json`:
   ```json
   "controlUi": {
     "allowedOrigins": [
       "https://vm-openclaw-1.tail8f8df.ts.net",
       "http://localhost:1885",
       "http://127.0.0.1:1885"
     ]
   }
   ```
4. Fixed config file permissions: `chmod 600 ~/.openclaw/openclaw.json`
5. Restarted gateway: `openclaw gateway restart`

### Verification

- Gateway: running (pid 19322, reachable in 28ms)
- Telegram: OK (@OC_GothamBot connected)
- Tailscale Serve: active (HTTPS → localhost:1885)
- `openclaw doctor`: clean (only non-blocking memory search warning about embeddings)

### Lesson Learned

OpenClaw updates can introduce breaking config requirements. Before updating:
- Check release notes / changelog
- Back up `~/.openclaw/openclaw.json`
- After update, run `openclaw doctor` and check `journalctl --user -u openclaw-gateway.service`
- Know how to rollback: `npm i -g openclaw@<old-version>`

### Also Discovered

- ~~SSH key auth from dev workstation to vm-openclaw-1 is broken~~ → **FIXED Feb 27, 2026** (ssh-copy-id)
- Memory search (embeddings) fails -- OpenRouter key doesn't work for OpenAI embeddings endpoint (non-blocking, chat works fine)

---

## ✅ Phase 11 COMPLETE: OpenClaw AI Agent Server (Feb 20, 2026)

**Status:** COMPLETE  
**Duration:** 4:01 PM - 7:47 PM EST (~3.75 hours including troubleshooting)  
**Result:** OpenClaw v2026.2.19-2 live on vm-openclaw-1, accessible via Tailscale Serve HTTPS, Telegram bot connected

### Final Working Configuration

**VM:** 185 (vm-openclaw-1) @ 192.168.1.185
- 16 GB RAM (upgraded from 8 GB -- Ubuntu Desktop used 90% at 8 GB)
- 8 cores, 50 GB disk on vm-critical
- Ubuntu 24.04 Desktop, vga: virtio

**OpenClaw:**
- Version: 2026.2.19-2
- Port: 1885 (non-default)
- Model: OpenRouter / Anthropic Claude Sonnet 4.6
- Skills: github, himalaya, nano-pdf, summarize, blogwatcher, goplaces
- Hooks: boot-md, bootstrap-extra-files, command-logger, session-memory
- Telegram: @OC_GothamBot (DM policy: pairing)

**Access:**
- Control UI: https://vm-openclaw-1.tail8f8df.ts.net/ (Tailscale Serve HTTPS)
- Localhost: http://localhost:1885 (from VM only)
- SSH: agamache@192.168.1.185 (LAN only)

### Implementation Steps Completed

1. ✅ Created VM 185 on Proxmox (SSH to .150, qm create)
2. ✅ Andrew installed Ubuntu 24.04 Desktop (Proxmox console)
3. ✅ Set static IP .185 (Ubuntu Network Settings GUI)
4. ✅ Ran host_setup.sh from script server
5. ✅ Configured Proxmox firewall (SSH + 1885 LAN + Tailscale UDP)
6. ✅ Installed Tailscale v1.94.2 (Andrew authenticated via browser)
7. ✅ Installed OpenClaw v2026.2.19-2 via bash script
8. ✅ Ran onboarding wizard (port 1885, LAN bind, token auth, Telegram)
9. ✅ Fixed HTTPS requirement with Tailscale Serve
10. ✅ Approved device pairing for Mac

### Troubleshooting Issues (IMPORTANT FOR FUTURE REFERENCE)

**Problem 1: VM booting from CD-ROM after Ubuntu install**

After Andrew removed the ISO, VM kept trying to boot from CD and failing.

**Root Cause:** Boot order was `order=ide2` (CD-ROM only). The disk `scsi0` was never added to boot order.

**Fix:** `qm set 185 --boot order=scsi0` on Proxmox host, then reboot VM.

**Lesson:** When creating VMs with ISO attached, boot order defaults to IDE. After install, change boot order to scsi0.

---

**Problem 2: 8 GB RAM not enough for Ubuntu Desktop**

VM was using 90% of 8 GB RAM immediately after Ubuntu Desktop install, before any services were running.

**Fix:** Stopped VM, set memory to 16384 (16 GB), restarted. `qm set 185 --memory 16384`

**Lesson:** Ubuntu 24.04 Desktop needs more RAM than Server. Use 16 GB minimum for Desktop VMs running services.

---

**Problem 3: SSH refused after Ubuntu install**

Could not SSH to VM after Ubuntu install. Connection refused on port 22.

**Root Cause:** OpenSSH server not installed yet -- host_setup.sh installs it.

**Fix:** Run host_setup.sh from the Proxmox console (not SSH). After script runs and reboot, SSH works.

**Lesson:** Always run host_setup.sh from the VM console first, then SSH for subsequent steps.

---

**Problem 4: OpenClaw onboarding wizard fails over non-interactive SSH**

The install script's onboarding wizard tried to open `/dev/tty` which doesn't exist in non-interactive SSH sessions.

**Root Cause:** `curl ... | bash` install script auto-launches the wizard, which needs an interactive terminal.

**Fix:** The install itself succeeded (exit code 1 was just the wizard failing). Run `openclaw onboard --install-daemon` separately from the VM terminal (Proxmox console or interactive SSH).

**Lesson:** Run the onboarding wizard from an interactive terminal on the VM, not via scripted SSH.

---

**Problem 5: npm PATH not configured**

After install, `openclaw` command not found in new terminals.

**Root Cause:** npm global bin directory `/home/agamache/.npm-global/bin` not in PATH.

**Fix:** Added to .bashrc: `export PATH="/home/agamache/.npm-global/bin:$PATH"`

**Lesson:** The install script warns about this -- follow its instructions.

---

**Problem 6: Control UI says "Disconnected (1008) - requires HTTPS or localhost"**

Opening `http://192.168.1.185:1885` in browser showed security error. The Control UI refused to connect over plain HTTP to a non-localhost address.

**Root Cause:** OpenClaw enforces HTTPS for all non-loopback connections. This is a security feature to prevent credential/chat interception.

**Fix:** Enabled Tailscale Serve which provides automatic HTTPS:
```bash
sudo tailscale serve --bg 1885
```
This creates an HTTPS proxy at `https://vm-openclaw-1.tail8f8df.ts.net/` that forwards to `localhost:1885`.

**Had to enable Tailscale Serve feature first:** Required visiting a Tailscale admin URL to enable "HTTPS Certificates" for the tailnet (not Funnel).

**Lesson:** OpenClaw CANNOT be accessed over plain HTTP from another computer. You MUST use either:
1. Tailscale Serve (HTTPS via tailnet domain) -- recommended
2. SSH tunnel (`ssh -N -L 1885:127.0.0.1:1885 agamache@192.168.1.185`)
3. Localhost from the VM itself

---

**Problem 7: CLI commands fail with SECURITY ERROR over LAN**

Running `openclaw devices list` via SSH failed because the CLI also enforces the HTTPS requirement when connecting to a LAN address.

**Root Cause:** Same HTTPS enforcement as the Control UI. CLI config points to `ws://192.168.1.185:1885` which is blocked.

**Fix:** Pass `--url ws://127.0.0.1:1885 --token <token>` to force localhost connection:
```bash
openclaw devices list --url ws://127.0.0.1:1885 --token [See working/open-claw-keys.txt]
```

**Lesson:** All CLI commands that talk to the gateway need `--url ws://127.0.0.1:1885 --token <token>` when running over SSH.

---

**Problem 8: Device pairing required for new browser connections**

Connecting from Mac showed "pairing required" error.

**Root Cause:** DM policy set to "pairing" during wizard -- new devices must be approved.

**Fix:** Approve via CLI:
```bash
openclaw devices list --url ws://127.0.0.1:1885 --token <token>
openclaw devices approve <requestId> --url ws://127.0.0.1:1885 --token <token>
```

**Lesson:** Each new browser/device needs to be approved. Use the CLI from the VM to list pending requests and approve them.

---

**Problem 9: Tailscale Serve not running after reboot**

After rebooting the VM, the Tailscale Serve HTTPS proxy was not active and the Control UI was unreachable.

**Fix:** Re-ran `sudo tailscale serve --bg 1885`. The `--bg` flag should persist, may have been a timing issue on first boot.

**Lesson:** If Control UI stops working after reboot, re-run `sudo tailscale serve --bg 1885`.

### Key Decisions Made During Implementation

| Decision | Choice | Why |
|----------|--------|-----|
| Install method | Bash script (not Ansible) | Ansible adds UFW, Fail2ban, creates separate user -- overkill for home lab |
| RAM | 16 GB (upgraded from planned 8 GB) | Ubuntu Desktop used 90% of 8 GB |
| Port | 1885 (not default 18789) | Avoid automated scanner detection |
| Access method | Tailscale Serve (HTTPS) | OpenClaw enforces HTTPS for non-localhost -- can't use plain HTTP over LAN |
| DM policy | Pairing | Most secure for personal use -- each device approved |
| Gateway bind | LAN | Needed for Tailscale Serve proxy to reach the gateway |

### Manual TODOs for Andrew

- [ ] Configure OpenRouter API key/credits at https://openrouter.ai
- [ ] Test Telegram bot from iPhone (install Telegram, message @OC_GothamBot)
- [ ] Approve iPhone as paired device when it connects

---

## ✅ Phase 7 COMPLETE: Local WWW/Production Server (Jan 22, 2026)

**Status:** COMPLETE 🎉🎉🎉  
**Duration:** 5:30 PM - 10:00 PM EST (~4.5 hours total)  
**Result:** Capricorn PROD + Splash page live, fully functional, localhost access configured, and all documentation updated. Primary production URL is cap.gothamtechnologies.com

### Final Working Configuration

**Services Running on vm-www-1 (192.168.1.184):**
- ✅ Traefik reverse proxy (ports 80/443/8080)
- ✅ Capricorn frontend (gitlab registry)
- ✅ Capricorn backend (gitlab registry)
- ✅ PostgreSQL (Capricorn database)
- ✅ Redis (Capricorn cache)
- ✅ Splash page (nginx)

**URLs Operational:**
- ✅ https://cap.gothamtechnologies.com (Capricorn PROD)
- ✅ https://www.gothamtechnologies.com (Splash page)
- ✅ https://192.168.1.184 (Direct IP access from internal network)
- ✅ Valid Let's Encrypt SSL certificates (auto-renewal)

### Critical Issue Resolved: Docker Networking

**Problem (8:00 PM):**
- HTTP worked, HTTPS timed out with "Gateway timeout"
- User tested from workstation, laptop, vm-www-1 itself - all failed
- Traefik logs showed it was trying to route to wrong IPs

**Root Cause:**
- Capricorn containers created their own network: `capricorn_capricorn-network` (172.19.0.0/16)
- Traefik was only on `web` network (172.18.0.0/16)
- Traefik couldn't reach backend services because they were on different network
- Traefik logs showed: "Creating server URL=http://172.19.0.5:80" (unreachable)

**Solution (8:40 PM):**
1. Connected Traefik to capricorn network: `docker network connect capricorn_capricorn-network traefik`
2. Updated `/opt/traefik/docker-compose.yml` to include both networks permanently:
   ```yaml
   networks:
     - web
     - capricorn_capricorn-network
   ```
3. Both services immediately started working!

**Architecture Decision:**
- Keep multi-network setup (security benefit)
- Postgres + Redis isolated on capricorn network only
- Traefik bridges both networks
- Frontend/Backend on both networks (can talk to DB and receive traffic)

### Implementation Summary

**Tasks Completed:**
1. ✅ Created VM 184 (vm-www-1, 8GB RAM, 8 cores, 50GB disk)
2. ✅ Installed Ubuntu 24.04 Desktop with static IP
3. ✅ Ran host_setup.sh (Docker, SSH, sudo, git, registry config)
4. ✅ Configured Proxmox firewall (SSH internal only, 80/443 open)
5. ✅ Installed Traefik with Let's Encrypt HTTP-01 challenge
6. ✅ Created splash page (nginx + custom HTML)
7. ✅ Andrew configured Verizon G3100 port forwarding (80, 443)
8. ✅ Verified NoIP DDNS (bullpup.ddns.net)
9. ✅ Andrew created Route53 CNAMEs (cap, www → bullpup.ddns.net)
10. ✅ Let's Encrypt certificates obtained automatically
11. ✅ Updated GitLab CI/CD pipeline (new deploy_prod_local job)
12. ✅ Deployed Capricorn via docker-compose (registry images)
13. ✅ Fixed database initialization (copied SQL scripts)
14. ✅ Resolved NAT hairpinning (added /etc/hosts entry)
15. ✅ Added IP-based routing (direct access via 192.168.1.184)
16. ✅ **FIXED Docker networking** (Traefik on both networks)
17. ✅ Full end-to-end testing (external + internal access)
18. ✅ **FIXED HTTPS mixed content** (frontend API auto-detection)
19. ✅ **Updated README files** (both projects direct users to cap.* primary URL)
20. ✅ **Configured localhost access** (routing rules + /etc/hosts for vm-www-1)

**Cost Savings:** ~$400/year by replacing GCP hosting!

### Post-Deployment Bug Fix: HTTPS Mixed Content (9:00 PM - 9:18 PM)

**Problem Discovered:**
- User attempted to import demo data → failed silently
- Browser console showed "Mixed Content" security errors
- All API calls from HTTPS page to HTTP backend blocked by browser

**Root Cause:**
- Frontend hardcoded `http://hostname:5002` for API URL
- HTTPS page (cap.gothamtechnologies.com) calling HTTP API blocked by browser security
- Vite environment variables are build-time, not runtime (setting at container runtime didn't work)

**Solution Implemented:**
- Updated `frontend/src/config/api.ts` to auto-detect protocol
- HTTPS page → use `https://hostname/api` (via Traefik)
- HTTP page → use `http://hostname:5002` (direct, DEV/QA)
- Single code change, single image works for ALL environments

**Deployment:**
- Commit `c83fe2f` pushed to develop → QA auto-deploy (verified HTTP still works)
- Merged develop → production
- Deployed via GitLab `deploy_prod_local` button
- **Result:** All API calls working, data import functional ✅

**Impact:**
- ✅ PROD-Local: FIXED
- ✅ DEV/QA: UNCHANGED  
- ✅ GCP: UNCHANGED
- ✅ Future: Automatic, no ongoing maintenance

### Final Documentation Updates: README Files (9:20 PM - 9:31 PM)

**Task:** Update public-facing documentation to direct users to local production

**Changes Made:**

**Home Lab Setup README (3 commits):**
1. `95f0dda` - Point to cap.* as primary production URL
   - Project overview: Added "Live Demo (PROD-Local)" with cap.*
   - Applications section: Separated PROD-Local (primary) and GCP (on-demand)
   - Target application: Clarified primary vs backup
2. `218110b` - Changed "GCP Backup" to "GCP Instance"
   - Wording: "GCP Instance" (not "Backup")
   - Purpose: "available on-demand for public demos" (not "interviews")

**Capricorn Project README (2 commits):**
1. `2b64657` - Emphasize cap.* as primary, GCP on-demand only
   - Added warning: "Not always running - deployed on-demand"
   - Added note: "For testing, please use cap.* (always available)"
   - Merged to both develop and production branches

**Result:**
- ✅ Both README files direct users to https://cap.gothamtechnologies.com
- ✅ GCP clearly marked as on-demand for public demos
- ✅ All public documentation consistent across projects
- ✅ GitHub users will find the always-available production instance

**Why This Matters:**
- Users testing Capricorn won't hit a "not available" GCP instance
- Clear messaging: Local is primary, GCP is supplemental
- Cost transparency: Demonstrates local hosting benefits
- Professional presentation: Always-available demo shows reliability

### Localhost Access Fix (10:00 PM - 10:05 PM)

**Problem:**
- User couldn't access app from Chrome on vm-www-1 using localhost or 192.168.1.184
- HTTP worked but HTTPS returned 404 or timed out

**Root Cause:**
- Traefik routing rules only configured for `cap.gothamtechnologies.com` and `192.168.1.184`
- No `Host(\`localhost\`)` routing rule
- `/etc/hosts` missing domain name entries for local trusted certificate access

**Solution Applied:**
1. Added domain names to `/etc/hosts`:
   ```
   127.0.0.1 cap.gothamtechnologies.com
   127.0.0.1 www.gothamtechnologies.com
   ```
2. Updated `/opt/capricorn/docker-compose.yml` with localhost routing labels:
   - Frontend: Added `Host(\`localhost\`)` router
   - Backend: Added `Host(\`localhost\`) && PathPrefix(\`/api\`)` router
3. Restarted containers: `sudo docker compose up -d`

**Result:**
- ✅ https://localhost (works with self-signed cert warning)
- ✅ https://192.168.1.184 (works with self-signed cert warning)
- ✅ https://cap.gothamtechnologies.com (works with Let's Encrypt trusted cert)

**Recommended:** Use domain name on vm-www-1 for trusted certificate without browser warnings.

**Time:** ~5 minutes

---

## 🌐 Phase 7 Implementation: Local WWW/Production Server (Jan 22, 2026) - ARCHIVED

**What:** Replace expensive GCP hosting with local production server

**Goal:** 
- Host Capricorn PROD locally at cap.gothamtechnologies.com
- Host splash page at www.gothamtechnologies.com
- Keep GCP (capricorn.gothamtechnologies.com) for interview demos only
- Save ~$30-45/month in GCP costs

**Phase 7 Plan:** `/phases/phase7_local_www.md`

**Key Decisions:**
| Decision | Choice |
|----------|--------|
| VM | vm-www-1 @ 192.168.1.184 (8GB RAM, 8 cores, 50GB vm-critical) |
| Reverse Proxy | Traefik on same VM (not separate) |
| SSL Method | HTTP-01 (Let's Encrypt, no AWS creds needed) |
| Dynamic DNS | NoIP hostname: bullpup.ddns.net (router-managed) |
| Router | Verizon G3100, ports 80/443 forwarded |
| Network Isolation | Proxmox firewall (SSH internal only, no external) |
| Pipeline | Two manual buttons: "Deploy to Local PROD" + "Deploy to GCP PROD" |

**DNS Layout:**
- cap.gothamtechnologies.com → CNAME → bullpup.ddns.net (local)
- www.gothamtechnologies.com → CNAME → bullpup.ddns.net (local)
- capricorn.gothamtechnologies.com → A → GCP IP (unchanged, interviews)

**Implementation Progress (Jan 22, 2026 - 5:30 PM onwards):**

| Step | Task | Status |
|------|------|--------|
| 1 | Create VM in Proxmox | ✅ DONE (VM 184 created) |
| 2 | Run host_setup.sh | ✅ DONE (running updates) |
| 3 | Configure Proxmox firewall | 🔲 Next |
| 4 | Install Traefik + Docker network | 🔲 |
| 5 | Deploy splash page | 🔲 |
| 6 | Configure G3100 port forwarding | 🔲 Andrew |
| 7 | Verify NoIP DDNS | ✅ DONE (bullpup.ddns.net = 108.6.178.182) |
| 8 | Configure Route53 CNAMEs | 🔲 Andrew |
| 9 | Test SSL certificates | 🔲 |
| 10 | Update GitLab CI/CD pipeline | 🔲 |
| 11 | Copy SSH key from runner | 🔲 |
| 12 | Deploy Capricorn via pipeline | 🔲 |
| 13 | End-to-end testing | 🔲 |

**VM Created:**
- VMID: 184
- Name: vm-www-1
- IP: 192.168.1.184
- RAM: 8GB, CPU: 8 cores
- Disk: 50GB on vm-critical (mirrored)
- OS: Ubuntu 24.04 Desktop

**Git Commits:**
- `46846d7` - Enhance setup_desktop.sh: file manager preferences + sysbench fix
- `92c389a` - Phase 7 planning: Local WWW server to replace GCP hosting

---

## 📋 Documentation Verification & Standardization (Jan 14, 2026 - 3:15-4:30 PM)

**What:** Verified actual Proxmox configuration matches documentation, updated all phase files with real hardware specs

**Problem:** Phase files had generic hardware info, drive serials not documented, startup procedure unclear

**Solution Implemented:**
1. ✅ Updated CURSOR_RULES with comprehensive Git Status Check procedure
2. ✅ SSH verified actual Proxmox configuration (storage, VMs, drives, kernel)
3. ✅ Updated phase0_hardware.md with real specs:
   - WD Blue SN5100 500GB boot drives (not generic)
   - Complete drive serial numbers for all 6 drives
   - Detailed BIOS settings table with menu locations
4. ✅ Updated phase1_proxmox.md with accurate config:
   - Real ZFS pool sizes and usage statistics
   - Documented compression settings (rpool=OFF is mistake, should be lz4)
   - Added ZFS management commands section
   - Added backup strategy section
   - Added best practices for creating new pools
5. ✅ Created SYSTEM_VERIFICATION.md:
   - Complete drive inventory with serial numbers
   - VM specifications with actual disk configurations
   - Health check schedule
   - Commands for future VM creation
6. ✅ Changed CURSOR_RULES startup reading order:
   - Now reads phase files first (reality) instead of old planning docs
   - Design.md optional for architecture philosophy

**Key Findings:**
- Boot drives: WD Blue SN5100 500GB (serials: 25434V801543, 25434V802501)
- VM drives: All Lexar NM620 1TB with serials documented
- rpool compression: OFF (mistake - should be lz4)
- vm-critical: 52GB used (58%) - mostly GitLab's 500GB disk
- vm-ephemeral: 40GB used (2%)
- All VMs using correct disk config: `aio=native,cache=none,discard=on,iothread=1`

**Why This Matters:**
- Documentation now accurately reflects production configuration
- Future VM creation will use correct settings
- Drive serial numbers documented for emergency replacement
- ZFS best practices clearly documented (always use lz4 compression)

**Git Commits (Session Total):**
- `f47a3f7` - Update CURSOR_RULES: Git Status Check procedure
- `577717d` - Verify and update documentation (5 files, +409 lines)
- `85e225b` - Update memory files
- `6fecdf3` - Fix: Enable lz4 compression on rpool

**Time:** ~90 minutes (documentation + compression fix)

**✅ Configuration Fix Applied:**
- Enabled lz4 compression on rpool (was OFF due to install mistake)
- All three ZFS pools now properly configured with lz4
- Compression ratios: rpool 1.00x, vm-critical 1.58x, vm-ephemeral 1.63x
- Existing 10GB on rpool remains uncompressed (by design, no issues)
- All future data will be compressed (20-40% space savings)

---

## ✅ COMPLETE: Phase 6 - SonarQube Code Quality Integration

**Status:** COMPLETE - Both test-app and Capricorn integrated!
**Infrastructure:** VM .183 (8GB RAM, 30GB vm-critical, 4 CPU) - optimized
**SonarQube:** v26.1.0 operational at http://192.168.1.183:9000
**Next:** Phase 7 (Monitoring) or Phase 8 (Traefik+SSL)

---

## 🔐 Password Security Cleanup (Jan 13, 2026 - 3:40-7:07 PM)

**What:** Removed hardcoded passwords from all documentation and centralized in git-ignored file

**Problem Identified:**
- Passwords hardcoded in 10+ documentation files
- The standard password and an old deprecated one were scattered throughout project
- All committed to public GitHub repository
- `www/scripts/setup_smb_mount.sh` had hardcoded NAS password in git history

**Solution Implemented:**
1. ✅ Created `PASSWORDS.md` - Central credential storage with all passwords
2. ✅ Added `PASSWORDS.md` to `.gitignore` (will never be committed)
3. ✅ Replaced 28 password instances with `[See PASSWORDS.md]` references
4. ✅ SSH tested to verify current password (value in PASSWORDS.md; old one deprecated)
5. ✅ Fixed markdown display issue (angle brackets → square brackets)

**Files Updated (28 replacements across 10 files):**
- MEMORY.md (8 instances)
- CURSOR_RULES (3 instances)
- phases/current_phase.md (1 instance)
- phases/phase6_sonarqube.md (6 instances)
- phases/phase5_ci_cd_pipelines.md (2 instances)
- phases/phase3_gitlab_server.md (1 instance)
- phases/phase2_host_setup_automation.md (2 instances)
- phases/phase1_proxmox.md (1 instance)
- proxmox/Home_Lab_Proxmox_Build_Plan.md (2 instances)
- proxmox/Home_Lab_Proxmox_Install.md (2 instances)

**Files Intentionally Left Unchanged:**
- `/proxmox/credentials` - Already git-ignored
- `/proxmox/nas_credentials` - Already git-ignored
(Note: `www/scripts/setup_smb_mount.sh` was later updated to read the password from the
 SMB_PASSWORD env var / prompt instead of hardcoding it — see the dual-remote cleanup below.)

**Git Commits:**
- `c71ef79` - Added sysbench to setup_desktop.sh
- `ad74d99` - Security: Remove hardcoded passwords from documentation
- `899d5c1` - Fix: Change angle brackets to square brackets

**Security Status:**
- ✅ Documentation cleaned of passwords
- ✅ Central PASSWORDS.md file (git-ignored)
- ✅ Git history later purged of all passwords/tokens (see dual-remote cleanup below)

**Password Summary:**
- **Current Standard:** [See PASSWORDS.md] (Proxmox, VMs, GitLab, NAS)
- **SonarQube:** [See PASSWORDS.md] (12+ chars required by v26.1.0)
- **Old/Deprecated:** [See PASSWORDS.md] (no longer valid, SSH test failed)

---

## 🎯 Infrastructure Optimization (Jan 12, 2026 - 9:00-9:30 PM)

**What:** Standardized and optimized all 4 VMs for performance and reliability

**Resource Reallocation:**
- GitLab: 16 GB (no change - keep high)
- Runner: 16 GB → **8 GB** (over-provisioned, saves 8 GB)
- SonarQube: 6 GB → **8 GB** (improves scan performance for 28k LOC projects)
- Kubernetes: 16 GB → **8 GB** (only using 2.6 GB with Capricorn running)
- **Total:** 54 GB → 40 GB allocated (14 GB freed, 86 GB available)

**Standardized Configuration (Applied to All VMs):**
1. ✅ CPU type: `host` (was mixed x86-64-v2-AES and host)
2. ✅ Firewall: Enabled on all (SonarQube was missing it)
3. ✅ Auto-start: Enabled on all (only SonarQube had it)
4. ✅ ISO unmount: Removed Desktop ISO from SonarQube
5. ✅ Disk optimizations:
   - `discard=on` - TRIM for ZFS space reclamation
   - `cache=writeback` - 10-30% faster disk writes
   - `aio=native` - Lower CPU overhead, better I/O performance

**Performance Impact:**
- Disk write speed: 10-30% improvement
- CPU overhead: 5-10% reduction
- ZFS efficiency: Better space management
- System reliability: Auto-recovery after Proxmox reboot

**Guest OS Standardization:**
- ✅ `sysbench` installed on all VMs
- ✅ Bash alias added: `sysbench` → runs CPU benchmark with all cores
- ✅ Updated `setup_desktop.sh` to include sysbench for future VMs

**Why This Matters:**
- All future VMs will be built with this standard configuration
- Documented in MEMORY.md "VM CONFIGURATION STANDARD" section
- Ensures consistency, performance, and reliability across the infrastructure

---

## 🔥 Critical Incident: Proxmox Kernel Issue (Jan 12, 2026)

**Moved.** Full write-up of the failed `6.17.2-1 → 6.17.4-2` upgrade, NVMe-timeout
boot failure, and rollback now lives in
**`phases/phase1a_proxmox_upgrade_fail_rollback.md`**. The forward-looking safe-retry
plan is in **`phases/phase1b_proxmox_kernel_upgrade_safe_try.md`**.

---

## ✅ COMPLETE: Phase 5 - CI/CD Pipelines (QA + GCP Both Working!)

**Infrastructure:** Production-ready with full automation (QA + GCP)
**Status:** Phases 0-5 complete, automated deployments to QA and GCP operational

---

## ✅ Completed This Session (Jan 12-13, 2026)

**Phase 6 Planning (5:00 PM - 5:56 PM):**
- Created comprehensive `/phases/phase6_sonarqube.md` plan
- VM specs: .183, 6GB RAM, 30GB disk on vm-critical (rpool2)

**Phase 6 Implementation (6:00 PM - 9:00 PM):**
- ✅ Created vm-sonarqube-1 (192.168.1.183, 6GB RAM, 30GB vm-critical, 4 CPU)
- ✅ Ran host_setup.sh (Docker, SSH, sudo, NAS, registry config)
- ✅ Installed SonarQube container (Docker)
- ✅ **UPGRADED:** 9.9.8 (lts-community) → 26.1.0 (community latest)
  - Old version showed "no longer active" warning
  - Had to wipe database (incompatible formats)
  - Changed Docker tag from `sonarqube:lts-community` to `sonarqube:community`
- ✅ Changed admin password: [See PASSWORDS.md] (12 chars required in new version)
- ✅ Created test-app project in SonarQube
- ✅ Generated test-app token: [See PASSWORDS.md]
- ✅ Created Capricorn project in SonarQube
- ✅ Generated Capricorn token: [See PASSWORDS.md]
- ✅ Added CI/CD variables to GitLab (SONAR_HOST, SONAR_TOKEN)
- ✅ Fixed variable naming issues (SONAR_ → SONAR_HOST)
- ✅ Updated token after database wipe
- ✅ Added scan stage to test-app/.gitlab-ci.yml
- ✅ Added scan stage to Capricorn/.gitlab-ci.yml (develop branch)
- ✅ **BOTH PIPELINES WORKING:** Scans complete, Quality Gates PASSED!

**Results:**
- test-app: 86 LOC, 0 bugs, 0 security issues ✨
- Capricorn: 28k LOC, Quality Gate PASSED (5 security, 144 reliability, 490 maintainability issues identified)

---

## ✅ Completed Previous Session (Jan 11, 2026 - Morning Session)

**GitHub Repository Setup (9:00 AM):**
- Published home-lab-setup to GitHub
- Created comprehensive README with hardware specs
- Multiple refinements (hardware cost, Z8 G4, rpool naming)
- 8 commits total to GitHub

**Phase 5 - Test App CI/CD (10:00 AM - 11:30 AM):**
- Created test-app (nginx + animated HTML splash page)
- Built 3-stage pipeline: build → push → deploy
- Fixed Docker API version (docker:27 not docker:24.0)
- Configured CI/CD variables in GitLab
- Setup SSH keys for deployment
- **SUCCESS:** http://192.168.1.180:8080 deployed via pipeline!

**Capricorn CI/CD Integration (11:45 AM - 1:35 PM):**
- Setup dual-remote configuration (GitHub + GitLab)
- Created "production" group in GitLab
- Established branch strategy (develop → QA, production → GCP)
- **CRITICAL REFACTORING:** Renamed all "prod" → "qa" for clarity
  - run-prod.sh → run-qa.sh
  - docker-compose.prod.yml → docker-compose.qa.yml
  - Dockerfile.*.prod → Dockerfile.*.qa
  - Updated all text: "PROD Environment" → "QA Environment (192.168.1.180)"
- Fixed .gitignore blocking lib/ directories (4 missing API files!)
- Created docker-compose.qa.deploy.yml (registry-based deployment)
- Built Capricorn .gitlab-ci.yml pipeline (QA + GCP stages)
- Fixed SSH key loading in pipeline
- **SUCCESS QA:** Capricorn auto-deploys to http://192.168.1.180:5001
- **SUCCESS GCP:** Capricorn deploys to http://capricorn.gothamtechnologies.com
- Added GCP deployment stage (manual trigger on production branch)
- Installed all tools in pipeline: terraform, gcloud, kubectl, docker buildx
- Fixed service account key file creation
- Added git to prerequisites (removes buildx warning)

**Issues Resolved:**
1. Docker API version mismatch (docker:24.0 → docker:27)
2. Registry authentication (CI/CD variables)
3. SSH key deployment (runner to QA host)
4. YAML script syntax (nested strings)
5. Missing lib/api-client.ts files (.gitignore blocking lib/)
6. SSH key format in CI/CD variable
7. Naming confusion (PROD → QA refactoring)
8. Build stages not running on production branch
9. Tool installation (terraform, gcloud, kubectl in Alpine)
10. Service account key file creation from variable
11. Git missing for docker buildx metadata

---

## Key Achievements

**Complete CI/CD Infrastructure:**
- ✅ GitLab Server verified (git push/pull, Container Registry)
- ✅ GitLab Runner verified (Docker builds, registry push, SSH deploy)
- ✅ Test app pipeline working (validation complete)
- ✅ **Capricorn pipeline working** (production application deployed!)

**Deployment Clarity Established:**
- **DEV** = Local workstation development
- **QA** = vm-kubernetes-1 @ 192.168.1.180 (automated CI/CD)
- **GCP** = Google Cloud Platform (real production)

---

## Previous Sessions

**January 8, 2026:**
- GitHub repository setup and published
- Updated hardware specs and documentation

**December 13, 2025:**
- GitLab Runner (gitlab-runner-1) installed @ 192.168.1.182
- Docker executor configured with socket mount
- Test pipeline verified (standard jobs work, DIND needs work)

---

## Next Steps

**Phase 7 Options:**
- **Option A:** Monitoring Stack (Prometheus + Grafana)
  - System metrics, application monitoring, dashboards
- **Option B:** Traefik + SSL (public HTTPS access)
  - Reverse proxy, automatic SSL certificates

**Future Work:**
- Gmail SMTP: Email notifications for GitLab (low priority)
- Review SonarQube findings and improve code quality
- Consider setting `allow_failure: false` for quality gates

---

## Quick Reference

| VM | IP | Status |
|----|-----|--------|
| QA/K8s | .180 | ✅ |
| GitLab | .181 | ✅ LIVE |
| Runner | .182 | ✅ LIVE |
| SonarQube | .183 | ✅ LIVE (v26.1.0) |

---

## Blockers

None. Phase 6 complete, ready for Phase 7!
