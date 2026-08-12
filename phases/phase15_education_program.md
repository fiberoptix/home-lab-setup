# Phase 15 — The Education Program: multi-track study repo

**Status:** ✅ **Parts A–D COMPLETE (Aug 12, 2026).** Part E is **blocked on O1** — the real stack.
Nothing is committed yet; Andrew has not been asked about push targets.
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

## 1. Where things stand today

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

- [ ] `git mv` the seven chapters + `app/ diagrams/ images/ manifests/ docx/` into
      `education/k8s-k3s-redpanda/`, and `git mv education/README.md` there too.
- [ ] `mv education/scratch education/k8s-k3s-redpanda/scratch` (untracked, plain `mv`).
- [ ] `.gitignore`: `education/scratch/` → `education/*/scratch/` (and confirm
      `git check-ignore education/k8s-k3s-redpanda/scratch/anchors_ch01.py` still fires).
- [ ] `git mv education/k8s-k3s-redpanda/tools education/tools` — tools go **up**, not across.
- [ ] `git mv education/k8s-k3s-redpanda/scratch/figcheck.py education/tools/figcheck.py`
      (this promotes a currently-untracked file into the repo — intentional, see Q4).
- [ ] Fix the one cross-boundary link (`../phases/` → `../../phases/`).

### Part B — the shared pipeline (~45 min)

- [ ] `build_docx.py`: take a track directory as `argv[1]`; derive `EDU` from it instead of
      `__file__.parent.parent`; keep the digit filter as `argv[2:]`. Widen the chapter glob to
      `chapter[0-9][0-9]_*.md`. Reference-doc temp path moves to `<track>/scratch/docx/`.
- [ ] `figcheck.py`: same — track directory as an argument, default to erroring rather than
      silently checking the wrong folder.
- [ ] `highlight.py`: no change needed (already argv-driven), but confirm.
- [ ] **Validation:** rebuild all 7 chapters of track 1 and diff byte sizes against the committed
      `docx/`. A pipeline refactor that changes output is a regression, not a refactor.

### Part C — the shelf documents (~1 hr)

- [ ] New `education/README.md` — the hub. Track table: name, subject, why it is being studied,
      chapter count, status, link. Plus a short "how to start a new track" section.
- [ ] New `education/CONVENTIONS.md` — lift the conventions out of the old README verbatim
      (chapter shape, Graphviz gotchas, the ≤1155×1386px figure rule, the docx spec, the highlight
      pass and its two traps, "only document what you actually ran").
- [ ] `education/k8s-k3s-redpanda/README.md` — keep the track-specific parts: chapter table
      (**corrected**: Ch7 is *additional infra stack*, Schema Registry moves to Ch8), the layout
      block, the manifests table, the app note.
- [ ] Root `README.md` — add an `education/` section. This is the public GitHub face of the repo.
- [ ] `education/docx/README.md` — the link-preserving stub [D3]. One short paragraph explaining the
      restructure and linking to `../k8s-k3s-redpanda/docx/`.

### Part D — doc reconciliation (~1 hr)

- [ ] **MEMORY.md** — 11 path references, plus the two facts that are missing entirely:
      **Andrew took the interviews Aug 6/7 and got the job**, and the education series is now a
      multi-track program rather than one series.
- [ ] **`phases/current_phase.md`** — mark **Phase 14 COMPLETE** (goal met: the interviews happened
      and the outcome was a hire), retire its "Next" list, and make **Phase 15 the active phase**.
      7 path references.
- [ ] **`phases/phase14_k8s_redpanda_poc.md`** — status header → COMPLETE with the outcome recorded;
      8 path references.
- [ ] `chapter01` (1), `chapter06` (3), `manifests/seed-topics-job.yaml` (1),
      `tools/build_docx.py` (1 comment) — path text only.
- [ ] Sweep: `rg -n "education/(chapter|app|manifests|diagrams|images|docx|scratch)"` must return
      zero hits that are not already track-qualified.

### Part E — the study backlog (planning only, no content)

- [ ] **Blocked on O1** — get the real stack from Andrew, then fix the track list and order (§4).
- [ ] Record the agreed roadmap in `education/README.md` as the track table with statuses.
- [ ] Write `phases/phase16_<first-track>.md` as a normal phase plan [D2] and present it for
      approval. Do **not** start writing chapters before that plan is agreed.

---

## 4. The candidate tracks — PROVISIONAL, pending O1

> ⚠️ **This whole section is a straw man derived from the job description, not from the job.**
> Andrew is describing the real stack next; expect this table to change before any track is started.

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

**Recommended order:** finish track 1 (Ch8–10, the cluster is still up and the muscle memory is
warm) → `observability` (highest leverage: it is the on-call skill, and it retro-fits onto the OMS
we already have) → `mongodb` (the deepest single technology on the list) → the rest as reading.

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

**O1 — The actual employer stack.** Andrew is going to describe the real stack before the track
list in §4 is fixed. Chapter 7's six areas came from the *job description*; the interviews and the
offer are newer information. **Nothing in §4 should be treated as agreed until this lands** — it is
the highest-value input to the whole program, and picking six technologies wrong costs weeks.

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
| Figures still legible | `python3 education/tools/figcheck.py k8s-k3s-redpanda` exits 0 |
| No dead relative links | `rg -n '\]\(\.\./' education/` reviewed by hand |
| No stale path prose | `rg -n 'education/(chapter\|app\|manifests\|diagrams\|images\|docx\|scratch)'` |

---

## 7. Git

Per CURSOR_RULES: **ask before any commit or push, and ask GitHub / GitLab / both.**
A rename-only commit should be its own commit (`git mv` + `.gitignore`), separate from the doc
rewrites, so the diff stays reviewable — otherwise GitHub renders 69 renames and a rewrite as one
unreadable blob.
