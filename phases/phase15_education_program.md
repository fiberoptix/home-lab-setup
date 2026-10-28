# Phase 15 — The Education Program: multi-track study repo

**Status:** ✅ **Parts A–D COMPLETE (Aug 12, 2026)**, committed in `104a1e0` and mirrored to GitLab;
the later doc reconciliation went in with `0503ac1`.
🔸 **Part E is all but done:** **O1 (the real stack) closed** the same evening, so §4 is now reconciled
against it rather than derived from the job description, and its deliverable
`phases/phase16_docker_swarm.md` is written and awaiting the build session. **One item remains** — the
track table in `education/README.md` still lists only track 1. That is deliberate: adding a
`docker-swarm` row before the folder exists would publish a dead link, so it lands with Phase 16 Part 1.
⚠️ **This file is now a RECORD, not a plan.** Everything in §3 has been executed; §1 describes the
tree as it was *before* the move. Do not re-run it.
**Created:** August 12, 2026
**Owner:** Andrew
**Supersedes as active phase:** Phase 14 (K8s + Redpanda POC) — the interviews happened Aug 6/7 and
**Andrew got the job.** Phase 14's goal is met; it should be closed, not extended.

---

## Why this phase exists

`education/` was built for one deadline: a single subject (k3s + Redpanda), written flat at the top
of the folder, on the assumption there would never be a second subject. There is now. The job is
won, and the material to learn is the **employer's stack**, which is a list of six or seven
technologies rather than one.

So the folder needs to stop being *a book* and start being *a shelf*. This phase is that conversion
plus the scaffolding that makes adding the second, third and fourth book cheap.

**This phase deliberately contains no new study content.** It is the move, the framework and the
doc reconciliation. Writing the next track is Phase 16 onward.

---

## 1. Where things stood BEFORE the move (historical — kept as the "why")

> 📎 This section is a snapshot of `education/` **as it was on the morning of Aug 12, 2026**, before
> Part A ran. It is retained because it records the survey work that made the move safe, not because
> it describes the tree today. For the current layout see `education/README.md`.

### The tree

```
education/
├── README.md                       series index + all shared conventions
├── chapter01_kubernetes_k3s.md     951 lines
├── chapter02_object_model.md
├── chapter03_redpanda.md
├── chapter04_provisioning_state.md
├── chapter05_consumer_groups.md
├── chapter06_the_application.md
├── chapter07_additional_infra_stack.md   981 lines, research-only
├── app/            Ch6 source: producer.py, consumer.py, oms.py, Dockerfile, build.sh, k8s/
├── diagrams/       19 Graphviz .dot sources
├── images/         19 rendered .png
├── manifests/      5 tested artefacts
├── tools/          build_docx.py, highlight.py
├── docx/           7 Word builds (tracked)
└── scratch/        GITIGNORED — anchors, research dumps, figcheck/tighten/rewrap
```

69 tracked files. `scratch/`, `__pycache__/` and `.DS_Store` are ignored.

### What makes the move cheap (verified, not assumed)

| Concern | Reality |
|---|---|
| Relative links **out of** `education/` | Exactly **one**: `README.md` line 4 → `../phases/phase14_k8s_redpanda_poc.md`. Becomes `../../phases/...`. |
| Relative links **within** chapters (`images/…`) | Unaffected — they stay siblings. |
| `tools/build_docx.py` | `EDU = Path(__file__).resolve().parent.parent`. Move-safe as-is. |
| `tools/highlight.py` | Takes paths as `argv`. Move-safe. |
| `scratch/figcheck.py` | `HERE = Path(__file__).parent`, images/diagrams via `HERE.parent`. Move-safe. |
| `git mv` | Preserves history for all 69 files. |

### What actually breaks or goes stale

1. **`.gitignore` line 65** — `education/scratch/` stops matching once scratch is one level deeper.
2. **Prose path references** — `education/...` written as text in **MEMORY.md (11)**,
   `phases/current_phase.md` (7), `phases/phase14_k8s_redpanda_poc.md` (8),
   `education/README.md` (6), `chapter01` (1), `chapter06` (3), `manifests/seed-topics-job.yaml` (1),
   `tools/build_docx.py` (1 comment).
3. **⚠️ The two GitHub URLs in the introduction email** (`education/scratch/email`) that Andrew sent
   to the hiring team:
   - `…/blob/main/education/README.md` — **survives** if we keep a README at `education/`.
   - `…/tree/main/education/docx` — **404s** after the move. GitHub does not redirect.
   This needs a decision (see Q3).
4. **`education/README.md` is stale regardless of this phase** — its chapter table lists
   "7 | Schema Registry | 🔲 Planned", but chapter 7 was actually written as
   *additional infra stack*, and Schema Registry is now the chapter-8 candidate.
5. **The root `README.md` never mentions `education/` at all** — the repo's public showcase omits
   the piece that was good enough to send to an employer.
6. **`build_docx.py` globs `chapter0*.md`** — single digit only. A track with ten chapters silently
   builds nine.

---

## 2. Proposed target structure

```
education/
├── README.md               ← THE SHELF. Track table, status, how to start a new track.
│                             (Keeps the URL that was emailed to the employer.)
├── CONVENTIONS.md          ← everything currently mixed into README about *how* to write:
│                             chapter shape, Graphviz rules, figure legibility, docx build,
│                             highlight pass, the "only document what you ran" rule.
├── tools/                  ← SHARED pipeline, used by every track          [D1]
│   ├── build_docx.py         build_docx.py <track> [chapter numbers]
│   ├── highlight.py
│   └── figcheck.py           promoted out of scratch/ — it is a real tool   [D4]
├── docx/
│   └── README.md           ← stub only: keeps the emailed GitHub URL alive  [D3]
│
├── k8s-k3s-redpanda/       ← TRACK 1 — everything that is in education/ today
│   ├── README.md             the current series index, minus the shared conventions
│   ├── chapter01..07.md
│   ├── app/  diagrams/  images/  manifests/  docx/
│   └── scratch/              gitignored
│
└── <track-2>/              ← same shape, created by Phase 16
    ├── README.md
    ├── chapterNN_*.md
    ├── diagrams/  images/  docx/  scratch/
    └── manifests/ or app/    only if that track builds something
```

### The three rules that make a track a track

1. **A track is self-contained.** Chapters, its own figures, its own artefacts, its own `docx/`.
   Nothing in a track links sideways into another track by relative path; cross-references go
   through `education/README.md`.
2. **Chapter numbering restarts at 01 in every track.** `k8s-k3s-redpanda/chapter03` and
   `mongodb/chapter03` are both fine and never collide.
3. **Tooling is never copied.** One `build_docx.py` for the whole shelf. If a track needs
   different behaviour, that is a flag, not a fork.

---

## 3. Tasks

### Part A — the move (mechanical, ~20 min)

- [x] `git mv` the seven chapters + `app/ diagrams/ images/ manifests/ docx/` into
      `education/k8s-k3s-redpanda/`, and `git mv education/README.md` there too.
- [x] `mv education/scratch education/k8s-k3s-redpanda/scratch` (untracked, plain `mv`).
- [x] `.gitignore`: `education/scratch/` → `education/*/scratch/` (and confirm
      `git check-ignore education/k8s-k3s-redpanda/scratch/anchors_ch01.py` still fires).
- [~] `git mv education/k8s-k3s-redpanda/tools education/tools` — **NOT NEEDED.** `tools/` was
      already at `education/tools/`, its target. The plan had it travelling down and back up again.
- [x] `git mv education/k8s-k3s-redpanda/scratch/figcheck.py education/tools/figcheck.py`
      (this promotes a currently-untracked file into the repo — intentional, see Q4).
- [x] Fix the one cross-boundary link (`../phases/` → `../../phases/`).

### Part B — the shared pipeline (~45 min)

- [x] `build_docx.py`: take a track directory as `argv[1]`; derive `EDU` from it instead of
      `__file__.parent.parent`; keep the digit filter as `argv[2:]`. Widen the chapter glob to
      `chapter[0-9][0-9]_*.md`. Reference-doc temp path moves to `<track>/scratch/docx/`.
- [x] `figcheck.py`: same — track directory as an argument, default to erroring rather than
      silently checking the wrong folder.
- [x] `highlight.py`: no change needed (already argv-driven), but confirm.
- [x] **Validation:** rebuild all 7 chapters of track 1 and diff byte sizes against the committed
      `docx/`. A pipeline refactor that changes output is a regression, not a refactor.

### Part C — the shelf documents (~1 hr)

- [x] New `education/README.md` — the hub. Track table: name, subject, why it is being studied,
      chapter count, status, link. Plus a short "how to start a new track" section.
- [x] New `education/CONVENTIONS.md` — lift the conventions out of the old README verbatim
      (chapter shape, Graphviz gotchas, the ≤1155×1386px figure rule, the docx spec, the highlight
      pass and its two traps, "only document what you actually ran").
- [x] `education/k8s-k3s-redpanda/README.md` — keep the track-specific parts: chapter table
      (**corrected**: Ch7 is *additional infra stack*, Schema Registry moves to Ch8), the layout
      block, the manifests table, the app note.
- [x] Root `README.md` — add an `education/` section. This is the public GitHub face of the repo.
- [x] `education/docx/README.md` — the link-preserving stub [D3]. One short paragraph explaining the
      restructure and linking to `../k8s-k3s-redpanda/docx/`.

### Part D — doc reconciliation (~1 hr)

- [x] **MEMORY.md** — 11 path references, plus the two facts that are missing entirely:
      **Andrew took the interviews Aug 6/7 and got the job**, and the education series is now a
      multi-track program rather than one series.
- [x] **`phases/current_phase.md`** — mark **Phase 14 COMPLETE** (goal met: the interviews happened
      and the outcome was a hire), retire its "Next" list, and make **Phase 15 the active phase**.
      7 path references.
- [x] **`phases/phase14_k8s_redpanda_poc.md`** — status header → COMPLETE with the outcome recorded;
      8 path references.
- [x] `chapter01` (1), `chapter06` (3), `manifests/seed-topics-job.yaml` (1),
      `tools/build_docx.py` (1 comment) — path text only.
- [x] Sweep: `rg -n "education/(chapter|app|manifests|diagrams|images|docx|scratch)"` must return
      zero hits that are not already track-qualified.

### Part E — the study backlog (planning only, no content)

- [x] **Blocked on O1** — get the real stack from Andrew, then fix the track list and order (§4).
- [ ] **STILL OPEN** — record the roadmap in `education/README.md`'s track table. Held until Phase 16
      Part 1 creates `education/docker-swarm/`, so the table never links to a folder that is not there.
- [x] Write `phases/phase16_<first-track>.md` as a normal phase plan [D2] and present it for
      approval. Do **not** start writing chapters before that plan is agreed.

---

## 4. The candidate tracks — RECONCILED against the real stack (Aug 12, evening)

> ✅ **O1 closed.** Andrew named the platform he is joining: **GitHub** for source, **Jenkins** for CI,
> **Docker Swarm** for orchestration, on a **DevOps/SRE role weighted to DevOps**.
>
> ⚠️ **The important thing about that answer is what it did *not* contradict.** Every track in the
> table below is a **platform service** (a database, observability, secrets, identity, the edge), and
> every tool Andrew named is **delivery and orchestration tooling**. The two lists are *orthogonal,
> not competing* — his answer did not invalidate the table, it revealed a whole axis the table never
> had. He also described it as "what I know about their platform", i.e. partial knowledge, so treat
> the six rows below as still-plausible-but-unconfirmed rather than as refuted.
>
> 🚨 **What this section got wrong was the ordering, not the contents.** The old recommendation was
> *observability → mongodb → the rest*, chosen when nothing was known about the toolchain. The three
> tools Andrew actually named appear **nowhere** in the table, and one of them is now Phase 16.
> **Revised order: `docker-swarm` (Phase 16, planned) → `jenkins` (likely Phase 17) → then the
> platform-service tracks below, observability first.** Delivery tooling wins because it is the part
> of the job he is certain about *and* the part he will touch on day one.

The employer's stack is already enumerated — Chapter 7 was commissioned straight off the job
description, and its six sections *are* the syllabus. **And the raw research already exists**:
`scratch/` holds `research_mongodb.md` (104 KB), `research_observability.md` (95 KB),
`research_secrets_certs.md` (84 KB) and `research_iam.md` (74 KB), written by the Aug 3 subagents
and only ever compressed into Ch7's summary sections. Four tracks have their source material
sitting on disk already.

| Proposed track | Subject | Seed material | Hands-on possible in the lab? |
|---|---|---|---|
| `k8s-k3s-redpanda` | existing — Ch8 Schema Registry, Ch9 OpenSearch + Fluent Bit, Ch10 failure drills | Ch7 §6, the live VM 186 | **Yes** — cluster still exists at snapshot `s05-app-running` |
| `mongodb` | replica sets, write concern, read concern, transactions, the OMS ledger migration | `research_mongodb.md` 104 KB | **Yes** — 3-node RS on VM 186 or a new VM |
| `observability` | OpenTelemetry, Prometheus, Grafana, OpenSearch | `research_observability.md` 95 KB | **Yes** — and it closes Ch6's hung-consumer story |
| `secrets-and-pki` | Vault, cert-manager, PKI, rotation | `research_secrets_certs.md` 84 KB | **Partly** — Vault yes, corporate PKI no |
| `iam-pam` | identity lifecycle, SSO, Symantec PAM, recertification | `research_iam.md` 74 KB | **No** — reading track |
| `edge-traffic` | Cloudflare, WAF, rate limiting, the gRPC/HTTP2 single-backend trap | Ch7 §1 (hand-written) | **Partly** — Traefik yes, CDN no |

**Two tracks the table above never had, added when O1 closed:**

| Track | Subject | Seed material | Hands-on possible in the lab? |
|---|---|---|---|
| `docker-swarm` | multi-node Swarm, shipping Capricorn to it from a pipeline, failure drills | none — written from scratch | **Yes** — `phases/phase16_docker_swarm.md`, 3 VMs at `.191–.193` |
| `jenkins` *(provisional)* | Jenkinsfile vs GitLab CI, agents, credentials, deploying to Swarm | none | **Yes** — a VM, deploying to the Phase 16 cluster |

**Revised order (supersedes the original recommendation):** `docker-swarm` → `jenkins` →
`observability` → `mongodb` → the rest as reading. Track 1's Ch8–10 slot in opportunistically, since
the cluster is still up at `s05-app-running` and the muscle memory is warm, but it is **no longer
first** — Andrew now has the job, so certainty about the toolchain beats finishing something tidy.

⚠️ **Do not start the Jenkins track by building Jenkins.** Phase 16 Part 3 deliberately puts the deploy
logic in a shell script with the CI file as a thin wrapper, precisely so that a Jenkins track is
mostly "write a different wrapper" rather than a second full build. Read that decision first.

A track that cannot be built in the lab should say so **in its README's first paragraph**, the way
Chapter 7 does. That honesty is the thing that made Ch7 usable.

---

## 5. Decisions (settled with Andrew, Aug 12)

**D1 — Tooling is SHARED.** One `education/tools/` for the whole shelf; the track is passed as an
argument. Nobody copies the build script into a track. (Part B carries the refactor.)

**D2 — A phase file PER TRACK.** `phases/` keeps owning the study work: `phase16_<track>.md`,
`phase17_<track>.md`, and so on, each following the normal CURSOR_RULES phase process (write the
plan, present it, wait for approval, then document what actually happened). A track's README stays
a *reader-facing* index — what the chapters are and how to build them — while the phase file holds
the working record: decisions, blockers, what was run, what broke. Phase 15 is the framework only.

**D3 — Keep the emailed GitHub URL alive with a stub.** `education/docx/README.md` stays at the old
path and points at `k8s-k3s-redpanda/docx/`, so `…/tree/main/education/docx` still resolves and
renders something useful instead of a 404. One file, no structural compromise.

**D4 — Promote `figcheck.py` only.** It moves to `education/tools/figcheck.py` and becomes tracked,
because the README documents running it and a fresh clone currently cannot. The one-shot surgery
scripts (`tighten.py`, `rewrap.py`, `renumber_figures.py`, `decallout.py`, `liftcallouts.py`) stay
in the ignored `scratch/`.
⚠️ **Consciously accepted debt:** the highlight **anchor lists** (`anchors_ch0*.py`) remain
gitignored, so the ~15 % highlight pass is **not reproducible from a clone** — only its *output* is,
since the marks live in the committed Markdown. Revisit if a track ever needs re-highlighting from
scratch.

---

## 5b. Still open

**O1 — ✅ CLOSED Aug 12 (evening), partially.** Andrew named **GitHub + Jenkins + Docker Swarm** and a
**DevOps-first SRE role**. §4 has been reconciled: the six job-description tracks were not refuted,
but they were all *platform services* and missed the *delivery tooling* axis entirely, which is now
first in the order. ⚠️ **Still partial** — he described it as "what I know about their platform", so
the rest of the stack (whether MongoDB, Vault, the observability suite and the Cloudflare edge are
really there) is **still unconfirmed** and worth asking about again once he is inside and can see it.
Chapter 7's six areas remain job-description-derived until then.

**O2 — ✅ CLOSED Aug 12.** The `.docx` highlighting was only ever verified by inspecting OOXML
(318 `Key` runs, `FFF3B0` fill, no leaked markup), never seen rendered. **Andrew confirmed the
rendered documents look right and print correctly** — which also validates Part B's regression check,
since that check assumed the existing output was correct, and retires the figure-legibility concern
(see §5c).

**O3 — ✅ CLOSED Aug 12. `CURSOR_RULES` now documents the education program.** Andrew gave **explicit
one-time authorisation** to edit that file, which normally forbids AI edits outright; the
authorisation is recorded under the never-edit line and is **not precedent**. Went in: a mandatory
startup read of `education/CONVENTIONS.md` (item 2f), a full `=== EDUCATION PROGRAM (/education) ===`
section with 7 rules, and a **rewritten `PROJECT SCOPE`** — Andrew's definition is that the repo owns
the Proxmox layer **and the educational R&D done inside it**, while "application layer" means
Capricorn and other real apps. The old "INFRASTRUCTURE layer ONLY" wording would have left
`/education` unclaimed by a literal reader. 156 → 204 lines; every original section verified intact
and the only removed lines were the 9 old scope lines.

**O4 — ⚠️ The CIFS share corrupts edits silently. Not resolved; mitigated by process.** Two of the
`CURSOR_RULES` writes landed damaged (a truncated paragraph, and a stray `EW instructs you to-
CONFIRM that you will edi` line that had never been in the file), and read-backs served stale content
that hid both — at one point returning a different region of the file than `rg` did for the same path,
and the IDE showing 160 lines against 204 on disk. **Mitigation, now recorded at the top of
`MEMORY.md`:** verify important edits from the shell (`wc -l`, `md5sum`, `rg -c`), audit removals with
`git diff <file> | rg '^-' | rg -v '^---'` before committing, and never save from a buffer whose line
count disagrees with disk.

---

## 5c. What was actually built (Aug 12, 3:20–3:50 PM EDT)

Parts A–D ran as planned. Deviations and findings, which are the parts worth reading:

- **`tools/` needed no move at all.** The plan had it travelling into the track and back out again.
  It was already at `education/tools/`, which is its target location — so the only change was making
  the scripts track-aware. One less rename.
- **The docx regression check passed exactly.** All 7 chapters rebuilt with the refactored pipeline
  produced **byte-identical `word/document.xml`**. The `.docx` files themselves differed by 1 byte
  each (zip metadata), so the committed binaries were **restored from `HEAD`** afterwards — the
  commit is a pure rename rather than 7 files of binary noise. MEMORY.md already warned about this
  trap from the Aug 3 session, which is why it was checked for.
- **All 67 renames registered at 100 % similarity**, so `git log --follow` will reach Jul 27 once
  committed. (`--follow` returns nothing *before* the commit, because the new path does not exist in
  `HEAD` yet — that is expected, not a failure.)
- **`resolve_track()` refuses to guess.** `build_docx.py` requires the track name and errors with the
  available list rather than defaulting. A default here would silently build the wrong track the
  moment a second one exists, which is the kind of bug you find three chapters later.
- **Chapter glob widened** from `chapter0*.md` to `chapter[0-9][0-9]_*.md`. The old pattern would
  have silently skipped a tenth chapter, and track 1 is planned out to 10.
- **🐛 Found, then closed as acceptable: 4 of 19 figures are under the 10 pt floor** —
  `ch02_fig1_ownership` (9.7 pt), `ch03_fig1_partitions` (9.9), `ch05_fig1_assignment` (10.0,
  borderline), `ch05_fig2_skew` (9.4), so `figcheck.py` exits 1. **Pre-existing, not caused by this
  work** — it only surfaced because promoting `figcheck.py` out of gitignored `scratch/` meant
  actually running it. ✅ **Andrew then rendered and printed all seven chapters and confirmed they
  look and print fine**, so the floor is a conservative guide, not a hard gate. These four stay.
  Apply the check to *new* figures; if ever revisited, the fix is a narrower diagram, never a bigger
  `fontsize`.
- **Ch7 mislabelled in the track README** — it had said "Schema Registry 🔲 Planned" while chapter 7
  was in fact *the rest of the platform*. Corrected, and Schema Registry moved to chapter 8.
- **✅ O2 closed:** Andrew confirmed the `.docx` highlighting looks right in Word.

Validation results: 58 relative markdown links checked across 18 files, **0 dead**; scratch still
ignored under the new pattern; no secrets tracked; zero stale `education/<subdir>` references outside
the two files that discuss the move itself.

---

## 6. Validation

| Check | Command |
|---|---|
| History preserved | `git log --follow education/k8s-k3s-redpanda/chapter01_kubernetes_k3s.md` shows Jul 27 |
| Nothing untracked-by-accident | `git status --short` clean after commit; `git ls-files education \| wc -l` ≥ 69 |
| Scratch still ignored | `git check-ignore -v education/k8s-k3s-redpanda/scratch/anchors_ch01.py` |
| No secrets staged for GitHub | `git ls-files \| grep -iE 'password\|cred\|\.env\|\.key'` empty |
| Word build unchanged | rebuild all 7 → sizes match committed `docx/` |
| Figures still legible | `python3 education/tools/figcheck.py k8s-k3s-redpanda` — ⚠️ **exits 1, and that is the accepted state.** Four pre-existing figures sit at 9.4–10.0 pt (see §5c); Andrew printed all seven chapters and confirmed they read fine. **Do not treat a non-zero exit here as a regression** — compare the named figures instead, and only investigate if the list grows. |
| No dead relative links | `rg -n '\]\(\.\./' education/` reviewed by hand |
| No stale path prose | `rg -n 'education/(chapter\|app\|manifests\|diagrams\|images\|docx\|scratch)'` |

---

## 7. Git

Per CURSOR_RULES: **ask before any commit or push, and ask GitHub / GitLab / both.**
A rename-only commit should be its own commit (`git mv` + `.gitignore`), separate from the doc
rewrites, so the diff stays reviewable — otherwise GitHub renders 69 renames and a rewrite as one
unreadable blob.

---

## 8. The highlight programme — both tracks to 20 % (Aug 19, 2026, evening)

**Ran by me, not Andrew** — he asked for the density change and then for the k3s track, and reviewed
the rendered page. Recorded here rather than in a track README because it spans both tracks and
changed the shared tooling.

### 8a. Why the number moved, and why the number is the least interesting part

Andrew's call: *"we can set highlighting to 20 % from now on."* Offered a trial first, and he chose to
**decide from the printed page rather than from the number** — Swarm ch5 was marked to 20.9 %, one
dense passage rendered at both ~16 % and ~21 %, and the two were nearly indistinguishable (one clause
per screen). He then said 20 % everywhere, including k3s. `CONVENTIONS.md` §"The highlight pass" now
carries the target plus the rules below; that file, not this one, is canonical.

### 8b. Before and after, all 15 chapters

| Track | Chapter | Before | After |
|---|---|---|---|
| Swarm | 01 building the cluster | 3.6 % | 20.1 % |
| Swarm | 02 shipping to it | 2.8 % | 19.8 % |
| Swarm | 03 a pipeline that deploys | 16.7 % | 20.2 % |
| Swarm | 04 state | 2.8 % | 19.9 % |
| Swarm | 05 breaking it | 2.7 % | 20.9 % |
| Swarm | 06 false greens | 2.3 % | 19.5 % |
| Swarm | 07 the tag that lies | 14.3 % | 20.5 % |
| Swarm | 08 swarm vs kubernetes | 14.5 % | 19.9 % |
| k3s | 01 kubernetes & k3s | 12.6 % | 21.2 % |
| k3s | 02 object model | 12.8 % | 21.1 % |
| k3s | 03 redpanda | 14.1 % | 19.7 % |
| k3s | 04 provisioning state | 14.5 % | 20.9 % |
| k3s | 05 consumer groups | 13.8 % | 20.3 % |
| k3s | 06 the application | 13.6 % | 20.2 % |
| k3s | 07 additional infra stack | 14.9 % | 19.8 % |

⚠️ **Note what the Swarm "before" column says:** chapters 1, 2, 4, 5 and 6 were at **2.3–3.6 %**, i.e.
5–6 marks each, not the ~40 a real pass produces. `current_phase.md` had recorded this correctly as an
open item, but the *assumption in conversation* was that those chapters had already been passed. **The
figure was checked before agreeing.** Anchor lists are in each track's gitignored `scratch/`.

### 8c. The finding worth keeping: chapter averages hide 5 % sections

Measured density **per `##` section** before writing each anchor list, and the distribution was badly
skewed on the k3s track, because marks written at drafting time cluster wherever the argument is:

| k3s ch3 section | Density before |
|---|---|
| §1 what Redpanda is | 32.3 % |
| §4 quorum | 27.3 % |
| §2 topics/partitions | 21.1 % |
| §5 StatefulSet + headless Service | **7.2 %** |
| §7 wiring up `rpk` | **6.2 %** |
| §8 verified demos | **4.9 %** |

The chapter read 14.1 % overall. **A list sized to the chapter average would have driven §1/§2/§4 past
30 % and left the three walkthrough sections untouched.** Same shape in ch6: §5 was at 59.7 % while the
**1,045-word interview-answers section had never been marked at all**, despite being the densest
revision material in the chapter. ⭐ **A chapter that averages 20 % with a 5 % stretch in the middle is
not a 20 % chapter.** Rule is now in `CONVENTIONS.md`.

`Lab vs PROD` callouts are the deliberate exception, left near **10–15 %**: they already carry bold
labels and 🚨/⭐/⚠️ markers, so highlight on top competes with that emphasis rather than adding to it.

### 8d. 🚨 The rendering bug this pass exposed — and the guards that now prevent it

**15 marks straddled one half of a `**bold**` pair.** Pandoc cannot close emphasis across a span
boundary, so the asterisks rendered **literally in the Word output**:

```
# what the printed .docx actually said
means **three directories on the same filesystem, on the same virtual
the collision happened **among the four workers of the first task to start**
```

11 were in the Swarm chapters passed earlier the same day, 4 in k3s. Separately, **one anchor in k3s
ch4 landed inside an existing mark** whose text wrapped across source lines, nesting one highlight
inside another. Both were tool gaps, so `education/tools/highlight.py` was fixed rather than only the
output — two new refusals, `splits a '**' pair` and `inside an existing mark`, verified on a synthetic
case (both fire; valid anchors still pass). All 15 `.docx` rebuilt and confirmed to contain **zero**
literal `**`.

⭐ **The lesson generalises past highlighting.** The Markdown passed every check that existed, and the
defect lived **only in the built artefact**. Same family as the Aug 19 morning failure of trusting a
conversation summary as evidence: **verify the thing you ship.** With no LibreOffice on the Z8 that
means `unzip -p x.docx word/document.xml`, strip tags, and grep the rendered text — searching for
literal `**` is what exposed this, and nothing at the Markdown layer could have.

### 8e. How to verify any of the above from a cold start

```bash
# per-chapter and per-section density (regex must be multiline: marks wrap across source lines)
cd education && python3 tools/highlight.py <chapter.md> <anchors.py> --check   # never writes

# the check that found the bug — expect no output
unzip -p <chapter.docx> word/document.xml | python3 -c "import sys,re;print(re.sub(r'<[^>]+>','',sys.stdin.read()).count('**'))"

# the Key style really landed (run counts exceed mark counts: bold/code split a mark into runs)
unzip -p <chapter.docx> word/document.xml | grep -c 'w:rStyle w:val="Key"'
```

---

## DEMOTED VERBATIM FROM `phases/current_phase.md` — Oct 27, 2026 (`MAKE_MEMORIES` pass 13)

⚠️ Copied verbatim from the `current_phase.md` Phase 15 block (Aug 12–13, 2026). Its **⏭️ Next** list is SPENT or superseded as of Oct 27, 2026: item 2 (fix §4) was done in the same block's review pass; the Redpanda trial-licence date (~Aug 25) has passed — see `phase14`; Phase 16 is closed and Phase 17 on hold. Two live rules were PROMOTED to `MEMORY.md` rather than left here: the track-1 `figcheck` exit-1-by-design warning (PHASE INDEX education row) and "`qm set` on a running VM only stages the change" (VM CONFIGURATION STANDARD).

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

### 🚨 THIS IS HANDS-ON TRAINING — ANDREW RUNS THE COMMANDS (added Aug 13, same session)

Andrew caught the omission immediately: *"before, you told me what to do and then I did it by hand so
I could learn and you would check — is that verbiage in the METHOD file?"* **It was not.** And the
proof of why that matters was sitting right there: **Phase 16 Part 1 had just been driven entirely by
the AI. Andrew typed nothing.**

⚠️ The practice was never invented — it was always how track 1 worked. `phase14`'s log says
"ready for the **guided** Part 3", then "Part 3 **hands-on, Andrew driving**", then "everything
documented came from something he ran". **But it lived only as a diary entry, never as a rule** — the
identical decay that nearly lost the planted-traps table. Written up now as
`education/METHOD.md` → **"Who does the work"**, a section that governs all five stages.

**Why it is not ceremony:** *"only document what Andrew actually ran" is worthless if the AI ran it.*
It silently becomes "only document what was executed", and the material stops being something he can
stand behind in an incident or an interview.

**The split** — the test is *"is this what we are here to learn"*, not *"is this hard"*:

| Work | Driver |
|---|---|
| Anything **NEW** — the technology being studied and its failure modes | 🙋 **Andrew** |
| Routine plumbing the lab has proven — template-9000 clones, `host_setup.sh`, `qm` resize/snapshot | 🤖 AI may drive |
| Writing — chapters, phase files, MEMORY, diagrams, committed scripts | 🤖 AI |

Track 1 drew this exact line, which is why **Part 1 being AI-driven was defensible** (cloning a VM for
the tenth time) — but **Part 2 is where it must switch, and it will.**

**The loop:** AI says what and why → **ONE** command → Andrew runs it and pastes output → AI checks it
and explains what it actually means → repeat → snapshot at the milestone. Not a wall of commands.

🚨 **When something breaks, Andrew diagnoses FIRST and the AI stays quiet** until asked, or until he is
burning real time. Debugging while confused *is* the job skill. This matters most for the **seven
planted traps** — narrating the answer the moment one fires is the same mistake as pre-empting it, one
step later.

**Repetition:** Andrew does the first node by hand, the AI does the other two — unless the repetition
*is* the lesson (writing the re-runnable script), which makes it his.

**Chapter scope, settled at the same time** (`CONVENTIONS.md` → "What belongs in a chapter"): routine
lab plumbing is **assumed, not re-taught**; what belongs is the infrastructure *as it pertains to this
build* plus the **what and why** — why three nodes, why all managers, why `vm-ephemeral`, why the
3.5 GB template disk had to grow. The test: *would this still be worth reading by someone who already
runs the lab?*

✅ **No `CURSOR_RULES` change was needed** — rule 1b already says to read and follow `METHOD.md`, so
the protocol is covered transitively.

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

