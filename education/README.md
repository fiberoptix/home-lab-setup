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
| 2 | The object model | Pods, Deployments, ReplicaSets, Services — built by hand | 🔲 Next |
| 3 | Redpanda | Brokers, topics, partitions, Raft quorum, StatefulSets | 🔲 Planned |
| 4 | Schema Registry | Avro, schema evolution, compatibility modes | 🔲 Planned |
| 5 | OpenSearch and Fluent Bit | Log shipping with DaemonSets, OpenSearch as a data store | 🔲 Planned |
| 6 | The market-data application | Producers, consumers, consumer groups, offsets, ordering | 🔲 Planned |
| 7 | Failure drills | What actually happens when you break each piece | 🔲 Planned |

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

> **Editing gotcha:** in Graphviz HTML-style labels, newlines in the source render as literal
> spaces. Keep each table cell's content on one source line or the first line of text will appear
> indented.

---

## Printing

The Markdown is written to survive being printed. Diagrams are sized to fit a portrait page. To make
a PDF of a chapter:

```bash
sudo apt install pandoc texlive-xetex        # one time
pandoc chapter01_kubernetes_k3s.md -o chapter01.pdf --pdf-engine=xelatex -V geometry:margin=2cm
```
