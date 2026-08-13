# How to write a track

These conventions apply to **every** study track in `education/`. They were worked out while writing
the [k3s + Redpanda track](k8s-k3s-redpanda/README.md) and most of them exist because something went
wrong first. A new track should start by reading this rather than by rediscovering them.

> This file governs the **artefact**. Its sibling [`METHOD.md`](METHOD.md) governs the **work that
> produces the material** — plan, build, break, investigate, document. Read that one when starting or
> running a track; read this one when writing or editing chapters.

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

### 🚨 The H1 must name the TRACK, not just the chapter number

```
# Docker Swarm · Chapter 1 — Building the Cluster
```

**Format: `# <Topic> · Chapter <N> — <Chapter Title>`.** Middle dot before the chapter number, em dash
before the title.

⭐ **Why** (Andrew, Aug 13, 2026): chapters are **printed and read on paper**, where a page opening
`Chapter 1 — Building the Cluster` gives no clue which technology it is about. Chapter numbering also
restarts in every track, so `Chapter 1` alone is ambiguous across the shelf — there will eventually be
four of them.

**The title line is the only place the topic appears in the printed document.** The footer is a bare
page number by choice (see "The Word build"), so nothing else recovers this information — which is
what makes the H1 format load-bearing rather than cosmetic.

⚠️ **Track 1 predates this convention** and its chapters still read `# Chapter N — …`. Retitling them is
🔲 **backlog item B2 in [`README.md`](README.md)** — deliberately NOT a churn-now item (Andrew, Aug 13).
Apply the new format to any track-1 chapter you are already editing for another reason; do not open
seven files just for this.

### The rest of the shape

The same every time, so a chapter works as a reference after the first read:

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

### What belongs in a chapter

**The subject, not the keystrokes.** The lab has a lot of settled plumbing, and re-explaining it in
every track buries the thing the track is actually about.

**Assume it** — routine work the lab has done many times and documented elsewhere: cloning from
template 9000, running `host_setup.sh`, `qm` resize and snapshot mechanics, standard VM sizing. A
sentence and a pointer is enough.

**Explain it** — the infrastructure *as it pertains to this build*, and above all the **what and the
why**: why three nodes rather than two, why every node is a manager, why `vm-ephemeral` rather than
`vm-critical`, why the template's 3.5 GB disk had to grow before Docker images would fit. The
reasoning is the part that transfers to a different lab; the commands are not.

The test: **would this sentence still be worth reading by someone who already runs the lab?** If it
only tells them how to do something they do weekly, cut it.

⭐ **Include the specifics and the caveats — that is the material** (Andrew, Aug 13). Every command
that was run, every file that was written, and the mechanism behind anything that surprised us: how
registry auth actually reaches a node, why a flag restarted one service and not another, why a port
number was not a free choice. **Precision is the point; a chapter that omits the caveat is a tutorial.**

🚨 **But findings about the deployed APPLICATION belong in a chapter ONLY when they carry a general
lesson — and then name the LESSON, not the application's private details** (Andrew, Aug 13):

| App-specific finding | In the chapter? |
|---|---|
| Credentials baked into an image layer, so anyone who can pull the image holds them | ✅ **Yes** — general, transferable, and cannot be fixed by editing a file |
| A compose file on disk that does not describe what is actually running | ✅ **Yes** — config drift; "just redeploy from the file" is dangerous |
| Build-time env vars (`VITE_*`) baked into a bundle, so setting them at runtime does nothing | ✅ **Yes** — general, and it constrained our port mapping |
| A non-production environment pointed at **production** third-party credentials | ✅ **Yes, as a PATTERN** — never the provider, the keys, or the values |
| A gap in the app's migration numbering | ❌ No — trivia about one codebase |
| The actual secret values, project names, or customer-facing identifiers | 🚨 **Never** |

The phase file keeps the full detail as the working record. The chapter carries only what a reader who
has never seen this application would still learn something from.

### ⭐ "Lab vs PROD" callouts

The material is written in a home lab and read by someone working on an enterprise platform. **The
danger is not forgetting a command — it is carrying a lab shortcut into production without ever
having been told it was a shortcut.** Name them where they happen.

**Format: a blockquote with a bold lead label.** No new machinery — chapters already use blockquotes
throughout and `build_docx.py` styles them as pull-outs, so these render in Word with no pipeline
work.

> **Lab vs PROD — plaintext registry.** *In the lab:* `/etc/docker/daemon.json` lists the registry
> under `insecure-registries`, so pulls and `docker login` cross the LAN over HTTP. *Why it's
> acceptable here:* isolated home network, and the credentials are lab-only by rule. *In production:*
> the registry gets a real TLS certificate and `insecure-registries` is never set. *If you carry the
> habit:* you have put a registry credential on the wire in cleartext — and `insecure-registries` is
> precisely the knob people reach for to make a TLS error "go away", silencing a warning that was
> correct.

**Four fields, in that order.** *In the lab* → *Why it's acceptable here* → *In production* → ***If
you carry the habit*.** ⭐ **The fourth field is the one that matters**; without it the callout is a
disclaimer rather than operational reasoning. "Why it's acceptable here" must give the actual reason,
never "it's just a lab".

🚨 **Threshold — or they become wallpaper.** A callout earns its place when the lab choice would be
**WRONG** in production (security, durability, availability, compliance), **not merely SMALLER**.
"Three nodes here, thirty in prod" is scale and does **not** qualify. "Registry credentials cross the
wire in cleartext" does. If every page has one, the important ones drown.

⚠️ **Mark unverified prescriptions as such.** "In production you would…" is sometimes reported from
something we tested and sometimes recited from training data. Say which. Presenting a plausible
opinion as an established practice is the one way this convention can actively mislead.

**Retrofit status:** introduced with the `docker-swarm` track (Aug 13, 2026) and ✅ **retrofitted into
track 1 the same day** — 9 callouts across chapters 1–6; see [`README.md`](README.md) for what was
promoted and, more instructively, **what was deliberately left as a table row**.

⭐ **The lesson from doing that retrofit, worth applying to every future track.** Track 1 already had a
*"Where this sandbox differs from production"* table in every chapter, so the shortcuts were all
documented. **What was missing was the consequence** — the fourth field — and that turned out to be the
part that changes behaviour. A table row saying `TLS off | TLS + SASL` is a fact you skim. A callout ending
*"anyone who can reach the port owns the log, and there is no second gate"* is one you remember. **Write
the fourth field first if you are ever unsure whether a callout is warranted; if you cannot write a real
consequence, it is a table row.**

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

### ⭐ Page numbers in the footer

**Every page carries a bare page number — just the digit — centred in the bottom margin, 9pt grey.**
Added Aug 13, 2026 at Andrew's request; he had been inserting them by hand in Word before every print.

⭐ **Bare number by explicit choice** (Andrew, Aug 13): **no "Page", no "of N", no running title.** The
first draft put `<Topic> · Chapter N · Page X of Y` down there and it was rejected as clutter — these
pages are dense technical prose and the footer should be furniture you never notice. The H1 already
names the track. **A useful consequence: the footer no longer varies per chapter, so one reference
document is built per track rather than one per chapter.**

**Pandoc has no page-number option**, because page numbers are not a Markdown concept. It does carry
headers and footers over from the reference document, so the footer is built as a **real footer part
inside the reference `.docx`** that `build_docx.py` assembles. Four things must agree or Word declares
the file corrupt:

| Piece | Where |
|---|---|
| `word/footer99.xml` — the footer body, holding a single `PAGE` field | written by `add_footer()` |
| A relationship pointing at that part | `word/_rels/document.xml.rels` |
| A content-type override declaring it | `[Content_Types].xml` |
| `<w:footerReference>` inside `<w:sectPr>` | `patch_sectpr()` |

Two traps worth knowing before editing this:

- 🚨 **Order inside `<w:sectPr>` is schema-enforced.** Header and footer references come **first**;
  putting `<w:pgSz>` ahead of them yields a file Word refuses to open.
- **The part is named `footer99.xml`, not `footer1.xml`**, because pandoc's default reference document
  may already ship footer parts and silently clobbering one would be a miserable bug to track down.

⚠️ **There is deliberately no table of contents.** Pandoc's `--toc` writes a field that only Word
itself can populate, so an unopened document renders a literal "No table of contents entries found"
banner on page 1. All TOC handling was removed rather than patched.

⭐ **A `PAGE` field is safe where a TOC field is not, and that distinction is why both decisions are
correct.** `PAGE` is resolved during **layout** — the renderer is already numbering pages in order to
lay them out — so it populates on open and on print. A TOC field needs a *document-wide scan* that only
Word performs on demand, which is why it renders as an error banner until someone presses F9. Same
field mechanism, different evaluation time.

> **Aside worth knowing if the footer ever grows:** `NUMPAGES` ("of 24") is a *weaker* field than
> `PAGE`. It needs the final page count, which is not known until layout completes, so some renderers
> show a stale value until the document is repaginated. Another small reason the bare number is the
> right call.

⚠️ **Verified structurally, not visually.** The footer part, relationship, content-type override and
`footerReference` were all confirmed present in the built `.docx`, and the field syntax is correct. **No
renderer was available on this machine to confirm the numbers appear on the page** — LibreOffice is not
installed. Confirm in Word once, then this note can be upgraded.

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
