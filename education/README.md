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
| [**docker-swarm**](docker-swarm/README.md) | Docker Swarm: building a three-manager cluster, shipping to it, deploying through a pipeline, breaking it on purpose, the false-greens capstone, and the Kubernetes comparison | 8 written | **Yes** — a real three-node cluster running a real application, deployed by a real pipeline, with failure drills run against it | ✅ Ch1–8 complete (Ch7 AI-executed, Ch8 synthesis) |
| [**jenkins**](jenkins/README.md) | Jenkins: a controller built from nothing, wired to the same GitLab and deploying the same application to the same Swarm — then made to fail on purpose | 1 written | **Yes** — a real controller and agent, aimed at the registry and cluster track 2 already uses | 🔵 In progress — Ch1 written, rest planned in [`phase17`](../phases/phase17_jenkins.md) |

**The two tracks are one comparison, and this is where it is drawn.** The k3s track ran Kubernetes on
**one** node; the Swarm track ran three, with a real pipeline and seven planted traps. That asymmetry
makes several rows tempting and wrong, so the crib sheet
[**docker-swarm/chapter08_swarm_vs_kubernetes.md**](docker-swarm/chapter08_swarm_vs_kubernetes.md)
labels every claim with the lab that measured it, and marks as **recited** anything neither lab ran.
It is the only document that cites both tracks; the chapters themselves stay self-contained.

⭐ **Track 3 extends that comparison in a different direction.** Where tracks 1 and 2 compare two
*orchestrators*, the Jenkins track compares two *delivery systems* aimed at the same target: GitLab CI
already builds and deploys Capricorn to the Swarm, and Jenkins is built to do the same job beside it.
Both pipelines stay running, deploying separate stacks, so the differences are observable rather than
argued.

Further tracks are being scoped against the stack Andrew works on now. The roadmap lives in
[`phases/phase15_education_program.md`](../phases/phase15_education_program.md); each track gets its
own phase file when it starts.

## ✅ Track 1 retrofits — both COMPLETE (Aug 13, 2026)

Both came from conventions introduced with `docker-swarm`, after track 1 was already finished and
printed. Deferred at first, then executed the same day at Andrew's direction.

| # | Retrofit | Outcome |
|---|---|---|
| **B1** | **"Lab vs PROD" callouts** ([`CONVENTIONS.md`](CONVENTIONS.md) → *Lab vs PROD callouts*) | ✅ **9 callouts across chapters 1–6** (3·2·1·1·1·1). Chapter 7 deliberately gets none — it is the research-only chapter, so there is no lab practice to contrast; it states that explicitly instead |
| **B2** | **H1s lead with the topic** ([`CONVENTIONS.md`](CONVENTIONS.md) → *The H1 must name the track*) | ✅ All 7 retitled to `# Kubernetes + Redpanda · Chapter N — …`, docx rebuilt |

⭐ **What the retrofit actually turned out to be, which was not what was expected.** Every chapter
already had a *"Where this sandbox differs from production"* table, so the material was largely present.
**What was missing was the fourth field — what breaks if you carry the habit — and honest marking of
which production prescriptions were never tested.** The work was therefore mostly *triage*: most rows in
those tables are differences of **scale or tooling** (one node, twelve keys, shell jobs instead of
Deployments) and correctly stay as table rows. **Only the rows that would still be wrong on a fifty-node
cluster were promoted to callouts:**

| Chapter | Promoted to a callout | Why it qualified |
|---|---|---|
| 1 | World-readable `system:masters` kubeconfig · `curl \| sh` install · replication that is real while durability is not | Security, supply chain, and a false durability guarantee |
| 2 | A probe that does not test the application · no PodDisruptionBudget on a quorum workload | Health checking that cannot fail; `drain` can destroy quorum even when rollouts are safe |
| 3 | A data store with no TLS, no auth and no ACLs on a NodePort | ⭐ **Not a consequence of having one node** — it was convenience, not constraint |
| 4 | Unauthenticated Admin API and topics with no owning principal | *ACLs applied later are ACLs applied never* |
| 5 | Auto-commit, which chooses at-most-once delivery for you | The only row that decides whether data can be **lost** |
| 6 | One mutable image tag for every build | Makes `rollout undo` a lie — and would be wrong at any scale |

⚠️ **Deliberately NOT promoted:** single-node k3s, SQLite instead of etcd, three brokers sharing a
failure domain, twelve keys instead of millions, pre-cached images. Those are honest limitations already
stated in the tables, and **three of track 1's most-repeated caveats are the same fact wearing three
hats — there is one piece of hardware.** Promoting them would have produced exactly the wallpaper the
convention's threshold exists to prevent.

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
