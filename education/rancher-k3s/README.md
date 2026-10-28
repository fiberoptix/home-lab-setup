# Rancher on K3s

How Rancher works, learned from one that was built for real: **Rancher 2.15.2, installed by Helm onto its
own single-node K3s cluster**, with monitoring, and with GitOps delivery from GitLab through Fleet.

🙋 What this track is for, in Andrew's words: *"You're writing this so I can learn about Rancher. Later we
will build a proper k8s cluster by hand. Now I just need to learn enough to know how it works."* So the
weight is on **what each piece is, why it is there, and what depends on what**. The procedures are kept
as evidence — every claim is tied to a command that was run — not as something to memorise.

**Working record:** [`phases/phase20_k3s_rancher.md`](../../phases/phase20_k3s_rancher.md) — the plan, the
decisions, the error log (E1–E7), the findings (F1–F15) and the drills (D1–D6).

> 🤖 **DECLARATION — every chapter in this track is AI-executed.** Phase 20 was built and drilled by the AI
> at Andrew's explicit instruction (*"Try to build the whole thing and note errors"*). Every command was
> really executed on VM 187 and every output quoted is real — but the operator judgement behind it was not
> earned at a keyboard. This is the same declaration as the Swarm track's chapter 7, applied to a whole
> track. When Andrew replays a chapter by hand, its declaration is removed — that chapter only.

Conventions: [`../CONVENTIONS.md`](../CONVENTIONS.md) · Method: [`../METHOD.md`](../METHOD.md)

---

## Chapters

**Prerequisites:** basic Kubernetes vocabulary (pod, Deployment, Service, namespace) and a terminal. Read in
order; each chapter's header says what it assumes. [`COMMANDS.md`](COMMANDS.md) is a reference, not a
chapter.

| # | Chapter | Covers | Status |
|---|---|---|---|
| 1 | [What Rancher is](chapter01_what_rancher_is.md) | Rancher is a Deployment, and its state is Kubernetes objects; manager vs downstream clusters; why it gets **its own** cluster; what the install really put on the node (13 Helm releases, 29 pods); why K3s and one node here; the community patch policy | ✅ Written Oct 27, 2026 · 🤖 AI-executed |
| 2 | [Installing it](chapter02_installing_it.md) | The order and why: VM → DNS → K3s → Helm → cert-manager → Rancher → settings; the `sudo helm` trap; 🚨 **the TLS chain traced end to end — Rancher's own CA, a cert-manager leaf, and what the browser warning really means** | ✅ Written Oct 27, 2026 · 🤖 AI-executed |
| 3 | [Seeing it: rancher-monitoring](chapter03_monitoring.md) | What the chart is (kube-prometheus-stack, repackaged); the version is chosen by Rancher; why K3s needs PushProx; 🚨 **the volume's 20 Gi is a label — retention is the only cap**; the five-minute cached 502; alerts that go to `"null"` | ✅ Written Oct 27, 2026 · 🤖 AI-executed |
| 4 | [Shipping to it](chapter04_shipping_to_it.md) | Pull vs push, and **who holds which credential**; `registries.yaml`; CI build → bump commit `[skip ci]`; Fleet's object chain GitRepo → Bundle → BundleDeployment → Helm release; push → serving in 36–42 s; Fleet status lag; PID 1 and SIGTERM; a namespace-scoped push identity | ✅ Written Oct 27, 2026 · 🤖 AI-executed |
| 5 | [Breaking it](chapter05_breaking_it.md) | Four drills, prediction first: a reboot that found a SIGTERM bug; **Rancher at zero while the app and GitOps carried on**; a broken manifest that failed safe (and a `Stalled` condition that never fires); a registry 401 that Rancher's summary hides. D5 and D6 still to run | ✅ Written Oct 27, 2026 · 🤖 AI-executed (D5, D6 🔲) |

---

## The lab this is written on

| | |
|---|---|
| VM | **187** `vm-k3s-rancher-1`, `192.168.1.187` — 6 vCPU, 24 GB RAM, 120 GB on `vm-ephemeral` (thin ZFS), Ubuntu 24.04.5 |
| Kubernetes | K3s **v1.35.9+k3s1**, single node, Traefik 3.7.13, `local-path` storage |
| Rancher stack | Helm **v3.22.1** · cert-manager **v1.21.3** · Rancher **2.15.2** (1 replica) · rancher-monitoring **110.0.2+up80.9.1-rancher.22** |
| Names | `rancher.gothamtechnologies.com`, `hello-rancher.gothamtechnologies.com` → `.187` (Route53) |
| Apps repo | GitLab `production/rancher-k3s` — app source, Fleet manifests, CI |
| Build scripts | [`proxmox/build-scripts/rancher-k3s/`](../../proxmox/build-scripts/rancher-k3s/) — `3-k3s.sh` … `6-gitops.sh`, each with a `--check` mode that reported **0 changes** on re-run |

⚠️ **Honest limitations, stated up front:** one node, so there is no high availability to study and a
reboot is a whole-site outage; no downstream clusters, so Rancher's main job — managing *other* clusters —
is described, not exercised. The CKA cluster was deliberately **not** imported.

---

## The Lab-vs-PROD callouts, in one place

| The lab habit | Taught in |
|---|---|
| Apps on Rancher's own `local` cluster | Ch 1 |
| Rancher's self-signed CA instead of a trusted certificate | Ch 2, Step 7 |
| Monitoring with no alert receiver (`"null"`) | Ch 3, §6 |
| Registry and Git over plain HTTP, carrying tokens | Ch 4, Step 1 |
| A cluster credential on a privileged CI runner (push model) | Ch 4, Step 6 |

---

## What this track deliberately does not cover

Chapters only document what was run. These were **not** exercised here — learn them elsewhere, or in the
hand-built cluster that comes next:

- **Downstream clusters** — importing or provisioning a cluster, the `cattle-cluster-agent`, Fleet targeting
  through `fleet-default`.
- **High availability** — three Rancher replicas, a multi-node management cluster, etcd.
- **Rancher upgrades** — drill D6, waiting for a newer community release.
- **Users, projects and RBAC inside Rancher** — only the built-in `admin` was used.
- **The UI as a daily tool** — almost everything was verified through `kubectl` and Rancher's API, not by
  clicking. ⚠️ Grafana dashboards were not opened in a browser.
- **Backups** — `rancher-backup` was not installed; the VM has Proxmox snapshots only.

---

## Contents

- [`COMMANDS.md`](COMMANDS.md) — every command used, indexed by the question it answers
- `manifests/` — copies of the values files, Fleet and RBAC objects and the apps repo as built; each file's
  header names its source of truth
- `diagrams/` — Graphviz sources; `images/` holds the rendered PNGs
- `docx/` — Word builds for printing (`python3 ../tools/build_docx.py rancher-k3s`)
