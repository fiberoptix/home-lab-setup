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
| 01 | [Building the cluster](chapter01_building_the_cluster.md) | Quorum arithmetic and why 2 managers are worse than 1; the manager-vs-worker token trap; idempotent provisioning; the address pool and CA expiry `swarm init` creates without telling you; `Ready` vs `Active` vs `Reachable` | ✅ Written |
| 02 | [Shipping to it](chapter02_shipping_to_it.md) | Stack vs compose and what Swarm silently ignores; secrets as files; **how registry auth really reaches a node**; why `deploy` exiting 0 means nothing; why replica counts mislead; digests vs tags; the routing mesh | ✅ Written |
| 03 | A pipeline that deploys | Portable deploy logic, deploy tokens, and why an HA control plane is not an HA delivery path | 🔲 Planned — blocked on Part 4 of the phase |
| 04 | [State: what the cluster will not carry for you](chapter04_state.md) | Named volumes are node-scoped, so state gets **stranded rather than lost**; durability ≠ availability; rotating a secret rotates only the client; `trust` on loopback; concurrent workers racing to seed one database | ✅ Written |
| 05 | [Breaking it on purpose](chapter05_breaking_it.md) | Ten drills with predictions written first: unpullable images and rollback; **an image that starts and is the wrong application**; quorum loss (writes *and* reads); the reboot that silently cost three replicas; how to run a drill that means something | ✅ Written |
| 06 | [False greens](chapter06_false_greens.md) | ⭐ The unplanned capstone: eight ways this cluster reported success for a question nobody asked, why every one of those signals was *honest*, the ladder of questions, and the smoke gate we built — including the failure it missed | ✅ Written |

Chapters are written after the work they describe, so the table fills in behind the build rather than
ahead of it. **Chapter 6 was not planned** — the same phenomenon appeared in every drill, in our own
tooling, and in five of our own experiments, which made it a subject rather than a footnote.

⚠️ **Chapter 2 has one known staleness**: it explains "exactly three `Rejected` tasks" from
`max_attempts: 3`, a setting later removed for the reason given in chapter 5 §3. The explanation still
holds for a service **create**; on an *update*, rollback ends the retries first. Repair is 🔲 tracked in
the phase file.

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

- [`COMMANDS.md`](COMMANDS.md) — ⭐ **every command used, indexed by the question it answers** rather
  than by chapter, plus how to *read* each failure state. Written as the track runs. Doubles as the
  specification for a portable read-only `docker-admin.sh` (not yet built — see its §11)
- `scripts/` — the provisioning and deploy scripts, as actually run
- `manifests/` — the Swarm stack file
- `diagrams/` — Graphviz sources; `images/` holds the rendered PNGs
- `docx/` — Word builds for printing (`python3 ../tools/build_docx.py docker-swarm`)
