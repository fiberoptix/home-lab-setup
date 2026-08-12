# How to write a track

These conventions apply to **every** study track in `education/`. They were worked out while writing
the [k3s + Redpanda track](k8s-k3s-redpanda/README.md) and most of them exist because something went
wrong first. A new track should start by reading this rather than by rediscovering them.

---

## The one rule that matters most

**Only document what you actually ran.**

A chapter's authority comes from the fact that every command in it was executed and every output
quoted is real. Material you have merely read is worth less in an incident and much less in a
conversation with someone who has operated the thing.

There is exactly one sanctioned exception, and it has to be **declared in the chapter's opening
paragraph**: a research-only chapter, written to map territory you cannot build in the lab.
[Chapter 7 of track 1](k8s-k3s-redpanda/chapter07_additional_infra_stack.md) is the worked example —
it opens by saying plainly that nothing in it was run, and that honesty is what makes it usable.

Where output legitimately **varies between runs** — which partition an unkeyed producer picks, the
initial leader assignment, a sticky-partition choice — say so in the text. A track doubles as a
replayable runbook, and a runbook that promises output it cannot deliver trains you to distrust it.

---

## Track layout

```
education/<track>/
├── README.md           chapter table, status, what this track is for
├── chapterNN_name.md   two-digit, numbering restarts at 01 in every track
├── diagrams/           Graphviz .dot sources — the editable originals
├── images/             rendered .png — generated, never edited by hand
├── docx/               Word builds — generated, never edited by hand
├── manifests/          tested config artefacts        (only if the track builds something)
├── app/                source code                    (only if the track writes software)
└── scratch/            GITIGNORED — research dumps, anchor lists, one-shot scripts
```

Three rules keep tracks from tangling:

1. **A track is self-contained.** Its chapters only ever use relative links to its own
   `images/`, `manifests/` and `app/`. Cross-track references go through `education/README.md`.
2. **Chapter numbering restarts per track.** Two tracks can both have a `chapter03`.
3. **Tooling is never copied into a track.** `education/tools/` is shared; if a track needs
   different behaviour, that is a flag on the shared tool, not a fork of it.

Anything in `scratch/` is invisible to a fresh clone. Do not put something there that the README
tells the reader to run.

---

## How each chapter is structured

The same shape every time, so a chapter works as a reference after the first read:

1. **Verified facts header** — versions and addresses as they actually were, *with a date*. Software
   moves; the header tells the reader when the chapter was true.
2. **Explanation with diagrams** — the concepts, and why they are built that way.
3. **Honest limitations** — where the lab differs from production, stated plainly. Knowing the
   difference is worth more than pretending there isn't one.
4. **Commands to know by heart.**
5. **Glossary.**
6. **Check yourself** — questions to answer out loud, with *section references rather than answers*,
   so you have to reconstruct rather than recognise.

Weight the writing toward **operational reasoning**: failure modes, what you do at 3am, and which
instincts make an incident worse. Tie each concept to a consequence for the system being studied.

---

## Diagrams

Every illustration is generated from a **Graphviz source in `diagrams/`** — not drawn by hand and
**not AI-generated**. Image models garble technical labels, and these have to be exactly right. The
payoff is that any diagram can be corrected and re-rendered rather than redrawn.

```bash
cd education/<track>/diagrams
dot -Tpng -Gdpi=150 ch01_fig1_stack.dot -o ../images/ch01_fig1_stack.png

# re-render everything
for f in *.dot; do dot -Tpng -Gdpi=150 "$f" -o "../images/${f%.dot}.png"; done
```

Requires `graphviz` (`sudo apt install graphviz`).

### Keeping figures legible on a printed page

A figure is scaled **uniformly** to fit the page, so the figure that is physically largest on screen
is the one whose type ends up *smallest* on paper. Two rules keep every label at 10pt or better in
the Word and PDF builds:

- **Width ≤ 1155px and height ≤ 1386px** when rendered at `-Gdpi=150`.
- **Prose belongs in the chapter, not in the figure.** A bordered "lesson" box rasterised into a PNG
  is the first thing to become unreadable. Write it as a blockquote under the figure instead, where
  it renders at full body size.

A figure *taller* than 1.2× its width cannot fill the column, because height becomes the binding
constraint — so stacking blocks to save width is usually counter-productive. Check any change with:

```bash
python3 education/tools/figcheck.py <track>
```

It reports the on-page point size of the smallest type in every figure and exits non-zero if any
falls below 10pt. `scratch/tighten.py` and `scratch/rewrap.py` reclaim space automatically by
shrinking padding and re-wrapping long label lines, neither of which touches content.

Anything purely tabular should be a **Markdown table in the chapter**, not a figure. Tables reflow to
the page width and always print at body size; four of track 1's original figures were converted for
exactly this reason.

> **Editing gotchas** in Graphviz HTML-style labels:
> - Newlines in the source render as literal spaces. Keep each table cell's content on one source
>   line, or the first line of text will appear indented.
> - `BALIGN="LEFT"` only aligns the lines *after* a `<BR/>`. The first line still centres. Set both
>   `ALIGN="LEFT" BALIGN="LEFT"` on the `<TD>` to left-align the whole cell.
> - For a standalone callout box, use a one-cell `<TABLE>` rather than `shape=box` with a plain HTML
>   label — box labels ignore alignment the same way.
> - Unicode escapes: `\uXXXX` does **not** work in plain DOT strings.

---

## The Word build

```bash
python3 education/tools/build_docx.py <track>        # every chapter
python3 education/tools/build_docx.py <track> 3 6    # chapters 3 and 6 only
python3 education/tools/build_docx.py --list         # what tracks exist
```

Requires `pandoc`. Output goes to `education/<track>/docx/` and is committed.

The build is opinionated on purpose, so it reads like a textbook and prints legibly: **7.00in text
column, Cambria 11pt, single-spaced, every image the full column width** (height-capped so a tall
figure does not overflow the page).

⚠️ **There is deliberately no table of contents.** Pandoc's `--toc` writes a field that only Word
itself can populate, so an unopened document renders a literal "No table of contents entries found"
banner on page 1. All TOC handling was removed rather than patched.

---

## The highlight pass

Roughly **15 % of each chapter is highlighted** so the material can be revised from the marks alone.
It is a character style named `Key`, filled `#FFF3B0` — a ~31 % tint of yellow, chosen because Word's
built-in highlighter is a closed set of 15 full-strength colours that lay down a wet band of ink on
an inkjet. The tint is obvious on screen, cheap to print, and still legible as grey in greyscale.

Marks live **in the Markdown, not in the `.docx`**, as `[text]{custom-style="Key"}`, so they survive
every rebuild. This requires `bracketed_spans` in pandoc's `--from` (already set).

```bash
python3 education/tools/highlight.py <chapter.md> <anchors.py>
python3 education/tools/highlight.py <chapter.md> <anchors.py> --check   # validate only
```

`highlight.py` **refuses to write unless every anchor matches exactly once** — a silently-missed
anchor is the one failure you would never notice.

⚠️ **Two traps:**
- **Never re-run `highlight.py` against an already-highlighted file.** Every existing anchor becomes
  a nested match.
- **Anchor lists live in `<track>/scratch/`, which is gitignored.** The highlights themselves are
  safe because they are committed inside the Markdown, but the anchor lists are not reproducible
  from a clone. Accepted debt; see `phases/phase15_education_program.md`.

---

## Printing a PDF

The Markdown is written to survive being printed, and figures are sized to fit a portrait page.

```bash
sudo apt install pandoc texlive-xetex        # one time
pandoc chapter01_kubernetes_k3s.md -o chapter01.pdf \
  --pdf-engine=xelatex -V geometry:margin=2cm
```
