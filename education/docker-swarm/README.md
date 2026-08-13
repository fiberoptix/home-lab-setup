# Docker Swarm

Orchestration on a **genuinely multi-node cluster**, running a **real application** through a **real
pipeline**. Three VMs on the home lab's Proxmox host form a three-manager Swarm, and the workload is
Capricorn — the same finance app that already builds, scans and deploys through GitLab.

That combination is the point. Most Swarm material deploys `nginx` by hand and stops, which never
raises the questions that come up at work: how a deploy authenticates to a registry from a node it has
never touched, what a rolling update does when the new image is broken, and what you do when the
control plane is alive but refuses to accept changes.

This track is also **the second half of a comparison.** The
[k3s + Redpanda track](../k8s-k3s-redpanda/README.md) covered the same ideas on Kubernetes, on one
node. Running the same workload on Swarm makes the differences concrete instead of theoretical.

**Working record:** [`phases/phase16_docker_swarm.md`](../../phases/phase16_docker_swarm.md) — the
plan, the decisions, the traps that are deliberately left in place, and what was actually run.

---

## Chapters

| # | Chapter | Covers | Status |
|---|---|---|---|
| 01 | Building the cluster | Provisioning nodes from a template as a re-runnable script; manager vs worker; Raft quorum; what `Reachable` means | 🔲 Planned |
| 02 | Shipping to it | The stack file, `docker secret`, compose-vs-stack, `--with-registry-auth`, the routing mesh, digests vs tags | 🔲 Planned |
| 03 | A pipeline that deploys | Portable deploy logic, deploy tokens, and why an HA control plane is not an HA delivery path | 🔲 Planned |
| 04 | State, where Swarm hurts | No PersistentVolumeClaim equivalent; node-local volumes; the choices and what each costs | 🔲 Planned |
| 05 | Failure drills | Quorum loss, drain, broken rollouts, silent empty-volume data loss, secret rotation | 🔲 Planned |

Chapters are written after the work they describe, so the table fills in behind the build rather than
ahead of it.

---

## The lab this is written on

| | |
|---|---|
| Nodes | `docker-swarm-1/2/3` at `192.168.1.191/192/193` |
| Each | 2 vCPU, 4 GB RAM, 40 GB on `vm-ephemeral` |
| Built from | Proxmox template 9000 (`tmpl-ubuntu-2404-cloudinit`), Ubuntu 24.04 LTS |
| Docker | 29.7.2, Compose v5.4.0 |
| Registry | `gitlab.gothamtechnologies.com:5050` (HTTP, hence `insecure-registries`) |

⚠️ **Honest limitation, stated up front:** three VMs on one physical host simulates **node** failure,
not **host** failure. Every drill in chapter 5 is a real Raft event, but losing the Proxmox host loses
all three nodes at once, and nothing here proves otherwise.

---

## Contents

- `scripts/` — the provisioning and deploy scripts, as actually run
- `manifests/` — the Swarm stack file
- `diagrams/` — Graphviz sources; `images/` holds the rendered PNGs
- `docx/` — Word builds for printing (`python3 ../tools/build_docx.py docker-swarm`)
