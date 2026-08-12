# Track 1 — Kubernetes (k3s), Redpanda, and an order management system

Study notes written to be **printed and re-read**, covering the technologies built in
[Phase 14](../../phases/phase14_k8s_redpanda_poc.md): Kubernetes, Redpanda, and the order management
application that ties them together.

These are learning documents, not build instructions. The phase file records *what we did*; these
chapters explain *what it means and why*.

**Chapters 1–6 were all run by hand on a real cluster** (`vm-k8-redpanda-1`) — every command was
executed and every output quoted is real. Chapters 2–6 double as **replayable runbooks**, so where
output legitimately varies between runs the text says so. **Chapter 7 is the one research-only
chapter**, and says so in its opening paragraph.

Conventions for this and every other track: [`../CONVENTIONS.md`](../CONVENTIONS.md).

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
| 7 | [The rest of the platform](chapter07_additional_infra_stack.md) | Edge/CDN, identity and PAM, secrets, PKI, MongoDB, and telemetry — how each would attach to the OMS. **Research only; nothing here was run** | ✅ Written Aug 3, 2026 |
| 8 | Schema Registry | Avro, schema evolution, compatibility modes. The app produces hand-rolled JSON with no contract, so renaming `qty` silently breaks the consumer | 🔲 Planned |
| 9 | OpenSearch and Fluent Bit | Log shipping with DaemonSets, OpenSearch as a data store | 🔲 Planned |
| 10 | Failure drills | What actually happens when you break each piece | 🔲 Planned |

---

## Layout

```
k8s-k3s-redpanda/
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
├── docx/               Word builds — generated, never edited by hand
└── scratch/            gitignored: research notes, highlight anchors, one-shot scripts
```

Build the Word versions of every chapter with:

```bash
python3 education/tools/build_docx.py k8s-k3s-redpanda        # or add chapter numbers: 3 6
```

Requires `pandoc`. Output goes to `docx/`.

---

## The tested artefacts

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
