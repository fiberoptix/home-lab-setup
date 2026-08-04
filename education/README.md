# Home-Lab Education Series

Study notes written to be **printed and re-read**, covering the technologies built in
[Phase 14](../phases/phase14_k8s_redpanda_poc.md): Kubernetes, Redpanda, OpenSearch, and the
market-data application that ties them together.

These are learning documents, not build instructions. The phase file records *what we did*; these
chapters explain *what it means and why*.

---

## Chapters

| # | Chapter | Covers | Status |
|---|---|---|---|
| 1 | [Kubernetes and the k3s cluster](chapter01_kubernetes_k3s.md) | What Kubernetes is for, what the k3s install produced, the three networks, storage | ✅ Written Jul 27, 2026 |
| 2 | [The object model](chapter02_object_model.md) | Deployments, ReplicaSets, the template hash, rolling updates, and the two probes — including the one that causes outages | ✅ Written Jul 27, 2026 |
| 3 | [Redpanda](chapter03_redpanda.md) | Brokers, topics, partitions, Raft quorum, StatefulSets — plus a full install runbook and failure drills | ✅ Written Jul 27, 2026 |
| 4 | [Provisioning application state](chapter04_provisioning_state.md) | The boundary between Kubernetes and application state: seeding topics, idempotency, the readiness race, tiered drift, operators vs Jobs | ✅ Written Aug 3, 2026 |
| 5 | [Consumer groups](chapter05_consumer_groups.md) | Partition assignment, the parallelism ceiling, skew, lag, rebalancing, and why SIGKILL produces duplicates | ✅ Written Aug 3, 2026 |
| 6 | [The application](chapter06_the_application.md) | Our own producer and consumer: `acks` and silent loss, commit ordering, effectively-once, and the four bugs found building it | ✅ Written Aug 3, 2026 |
| 7 | Schema Registry | Avro, schema evolution, compatibility modes | 🔲 Planned |
| 8 | OpenSearch and Fluent Bit | Log shipping with DaemonSets, OpenSearch as a data store | 🔲 Planned |
| 9 | Failure drills | What actually happens when you break each piece | 🔲 Planned |

---

## Layout

```
education/
├── chapterNN_*.md      the chapters
├── app/                the order management application (Chapter 6)
│   ├── producer.py     order gateway — keyed events, acks/idempotence as env knobs
│   ├── consumer.py     position keeper — explicit commits, two ledgers
│   ├── oms.py          shared event model and the fixed arithmetic
│   ├── Dockerfile      one image, two entrypoints
│   ├── build.sh        docker build + k3s ctr import + verify
│   └── k8s/            producer Job and consumer Deployment + PVC
├── diagrams/           Graphviz .dot sources — edit these
├── images/             rendered .png — generated, never edited by hand
├── manifests/          working config referenced by the chapters
├── tools/build_docx.py builds docx/ — 11pt, single-spaced, full-width figures
├── docx/               Word builds — generated, never edited by hand
└── scratch/            review notes and the figure-legibility tooling
```

Build the Word versions of every chapter with:

```bash
python3 education/tools/build_docx.py        # or pass chapter numbers: 3 6
```

Requires `pandoc`. Output goes to `education/docx/`.

`manifests/` holds real, tested artefacts rather than snippets. They are meant to be re-used on
another cluster:

| File | What it is |
|---|---|
| [`redpanda-values.yaml`](manifests/redpanda-values.yaml) | Reproduces the deployed Helm release exactly (verified with `helm get values`), including the single-node anti-affinity override |
| [`web-deployment.yaml`](manifests/web-deployment.yaml) | Chapter 2's reference Deployment + Service, with both probe failure drills documented inline. Verified `apply` → `rollout status` → `200`s → `delete` |
| [`seed-topics.sh`](manifests/seed-topics.sh) | Chapter 4's topic reconciler. Idempotent, and checks *shape* not just existence: fixes Tier 1 config drift in place, reports Tier 2/3 drift and exits 1. Verified against missing, unchanged, retention-drifted and partition-drifted topics |
| [`seed-topics-job.yaml`](manifests/seed-topics-job.yaml) | The Job that runs it, with an init container that polls the **Admin API** until `Healthy: true`. Verified to cost 0s on a healthy cluster and to survive a full scale-to-zero outage |
| [`consumer-group-lab.sh`](manifests/consumer-group-lab.sh) | Chapter 5's lab as a step runner (`reset` / `seed` / `start` / `who` / `work` / `keys` / `dups`). Replays the whole session, including the SIGTERM-vs-SIGKILL duplicate contrast |

Chapter 6's application lives in [`app/`](app/) rather than `manifests/`, because it is source code
rather than configuration. It is deployable as-is: `./build.sh` then `kubectl apply -f k8s/`.
Verified end-to-end at 10,000 events with an exact 800,000-share reconciliation, zero sequence gaps,
and repeated hard kills.

---

## How each chapter is structured

Every chapter follows the same shape, so it works as a reference after the first read:

1. **Verified facts header** — versions and addresses as they actually were, with a date. Software
   moves; the header tells you when the chapter was true.
2. **Explanation with diagrams** — the concepts, and why they are built that way.
3. **Honest limitations** — where this sandbox differs from production, stated plainly. Knowing the
   difference is worth more in an interview than pretending there isn't one.
4. **Commands to know by heart.**
5. **Glossary.**
6. **Check yourself** — questions to answer out loud, with section references rather than answers,
   so you have to reconstruct rather than recognise.

---

## The diagrams

Every illustration is generated from a **Graphviz source file** in `diagrams/`, not drawn by hand
and not AI-generated. That means labels are exactly correct, and any diagram can be corrected and
re-rendered rather than redrawn.

```bash
cd education/diagrams
dot -Tpng -Gdpi=150 ch01_fig1_stack.dot -o ../images/ch01_fig1_stack.png
```

Re-render everything:

```bash
cd education/diagrams
for f in *.dot; do dot -Tpng -Gdpi=150 "$f" -o "../images/${f%.dot}.png"; done
```

Requires `graphviz` (`sudo apt install graphviz`).

### Keeping figures legible on a printed page

A figure is scaled uniformly to fit the page, so a figure that is physically large on screen is the
one whose type ends up *smallest* on paper. Two rules keep every label at 10pt or better in the
Word and PDF builds:

- **Width ≤ 1155px and height ≤ 1386px** when rendered at `-Gdpi=150`.
- **Prose belongs in the chapter, not in the figure.** A bordered "lesson" box rasterised into a
  PNG is the first thing to become unreadable. Write it as a blockquote under the figure instead,
  where it renders at full body size.

A figure that is *taller* than 1.2× its width cannot fill the column, because height becomes the
binding constraint — so stacking blocks to save width is usually counter-productive. Check any
change with:

```bash
python3 education/scratch/figcheck.py
```

It reports the on-page point size of the smallest type in every figure and exits non-zero if any
falls below 10pt. `scratch/tighten.py` and `scratch/rewrap.py` will reclaim space automatically by
shrinking padding and re-wrapping long label lines, neither of which touches content.

Anything that is purely tabular should be a **Markdown table in the chapter**, not a figure. Tables
reflow to the page width and always print at body size; four of the original figures were converted
for exactly this reason.

> **Editing gotchas** in Graphviz HTML-style labels:
> - Newlines in the source render as literal spaces. Keep each table cell's content on one source
>   line, or the first line of text will appear indented.
> - `BALIGN="LEFT"` only aligns the lines *after* a `<BR/>`. The first line still centres. Set both
>   `ALIGN="LEFT" BALIGN="LEFT"` on the `<TD>` to left-align the whole cell.
> - For a standalone callout box, use a one-cell `<TABLE>` rather than `shape=box` with a plain
>   HTML label — box labels ignore alignment in the same way.

---

## Printing

The Markdown is written to survive being printed. Diagrams are sized to fit a portrait page. To make
a PDF of a chapter:

```bash
sudo apt install pandoc texlive-xetex        # one time
pandoc chapter01_kubernetes_k3s.md -o chapter01.pdf --pdf-engine=xelatex -V geometry:margin=2cm
```
