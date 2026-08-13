# Home-Lab Education Program

Study notes written to be **printed and re-read**, built on technology that is actually running in
the [home lab](../README.md) rather than on tutorials.

Each **track** is a self-contained series of chapters on one subject, with its own diagrams, its own
tested artefacts, and a Word build for printing. Every track follows the same conventions and is
produced by the same tooling.

- **How to run a track:** [`METHOD.md`](METHOD.md) — plan, build, break, investigate, document
- **How to write a track:** [`CONVENTIONS.md`](CONVENTIONS.md) — chapter shape, diagrams, the builds
- **Shared tooling:** [`tools/`](tools/) — the Word build, the highlighter, the figure checker

---

## Tracks

| Track | Subject | Chapters | Built in the lab? | Status |
|---|---|---|---|---|
| [**k8s-k3s-redpanda**](k8s-k3s-redpanda/README.md) | Kubernetes (k3s), Redpanda, and an order management system built on both | 7 written | **Yes** — everything in Ch1–6 was run on a real cluster | ✅ Ch1–7 complete · Ch8–10 planned |
| [**docker-swarm**](docker-swarm/README.md) | Docker Swarm: building a three-manager cluster, shipping to it from a pipeline, and breaking it | 5 planned | **Yes** — a real three-node cluster running a real application | 🔵 In progress — cluster being built |

Further tracks are being scoped against the stack Andrew works on now. The roadmap lives in
[`phases/phase15_education_program.md`](../phases/phase15_education_program.md); each track gets its
own phase file when it starts.

## 📌 Backlog — two deferred track 1 retrofits

Both come from conventions introduced with `docker-swarm` on **Aug 13, 2026**, after track 1 was
finished and printed. ⚠️ **Andrew's call, both items: do NOT churn track 1 now.** Revisit each as a
**separate, deliberate task** — never as drive-by edits. **Exception for B2 only:** apply the new title
format to any track-1 chapter already being edited for another reason, since it is a one-line change.

| # | Retrofit | Scope | Why deferred |
|---|---|---|---|
| **B1** | **"Lab vs PROD" callouts** — where the lab does something that would be **wrong** in an enterprise production environment, say so, say what production does instead, and say what breaks if the habit follows you (see [`CONVENTIONS.md`](CONVENTIONS.md) → *Lab vs PROD callouts*) | All 7 chapters. Known gaps: single-node k3s presented as a cluster, `insecure-registries`, three brokers in one VM, patching disabled | Substantial rewrite — each callout needs four fields and a judgement about whether the choice was *wrong* or merely *smaller*. Real work, not formatting |
| **B2** | **Retitle H1s to lead with the topic** — `# Chapter 1 — …` becomes `# Kubernetes + Redpanda · Chapter 1 — …` (see [`CONVENTIONS.md`](CONVENTIONS.md) → *The H1 must name the track*) | 7 one-line edits, then rebuild the docx | Cheap, but pointless in isolation — it would rewrite seven `.docx` binaries for a cosmetic gain. Fold it into B1, or into any other edit |

⭐ **Why B2 matters at all, given it looks cosmetic:** the printed footer is a bare page number by
design, so **the title line is the only place a printed chapter names its own subject** — and chapter
numbering restarts in every track, so `Chapter 1` alone is ambiguous across a shelf that will hold four
of them.

---

## Why it is organised this way

The first track was written flat at the top of this folder, for a single deadline. Once there was a
second subject, the folder had to stop being *a book* and start being *a shelf* — hence one directory
per track, shared tooling, and chapter numbering that restarts inside each track.

Two things carried over from the first track because they turned out to matter more than expected:

- **Only document what you actually ran.** Chapters quote real output from real commands. Where a
  chapter is research rather than experience, it says so in its opening paragraph.
- **Diagrams are Graphviz sources, never AI-generated images.** Image models garble technical labels,
  and a diagram whose labels are subtly wrong is worse than no diagram.

Both rules, and the reasons behind the figure-legibility and Word-build decisions, are in
[`CONVENTIONS.md`](CONVENTIONS.md).

---

## Starting a new track

```bash
mkdir -p education/<track>/{diagrams,images,scratch}
```

Then write `education/<track>/README.md` (chapter table + what the track is for), add the track to
the table above, and read [`CONVENTIONS.md`](CONVENTIONS.md) before the first chapter. `docx/` is
created by the build; `manifests/` and `app/` only if the track builds or writes something.

```bash
python3 education/tools/build_docx.py --list          # confirm the track is seen
python3 education/tools/build_docx.py <track>         # build to <track>/docx/
python3 education/tools/figcheck.py <track>           # figures legible on paper?
```
