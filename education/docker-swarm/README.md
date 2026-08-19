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
node. Running the same workload on Swarm makes the differences concrete instead of theoretical — the
short version is [below](#swarm--kubernetes-what-the-two-tracks-actually-showed); the full crib sheet
is a planned Part 7 session.

**Working record:** [`phases/phase16_docker_swarm.md`](../../phases/phase16_docker_swarm.md) — the
plan, the decisions, the traps that are deliberately left in place, and what was actually run.

---

## Chapters

**Prerequisites:** comfort with Docker and compose files, and a terminal. The k3s track helps for the
comparison asides but is not required. Read in numeric order — each chapter's header lists what it
assumes. `COMMANDS.md` is a reference, not a chapter; keep it beside you from Chapter 2 on.

| # | Chapter | Covers | Status |
|---|---|---|---|
| 01 | [Building the cluster](chapter01_building_the_cluster.md) | Quorum arithmetic and why 2 managers are worse than 1; the manager-vs-worker token trap; idempotent provisioning; the address pool and CA expiry `swarm init` creates without telling you; `Ready` vs `Active` vs `Reachable` | ✅ Written |
| 02 | [Shipping to it](chapter02_shipping_to_it.md) | Stack vs compose and what Swarm silently ignores; secrets as files; **how registry auth really reaches a node**; why `deploy` exiting 0 means nothing; why replica counts mislead; digests vs tags; the routing mesh | ✅ Written |
| 03 | [A pipeline that deploys](chapter03_a_pipeline_that_deploys.md) | Where the CI/deploy-logic boundary goes and how to test that you drew it right; a key into a runner without ever writing it to disk, and the two false greens found proving it; masking vs `ps` — different surfaces; ⭐ **an HA control plane is not an HA delivery path**; how one dead node makes a replica count report a database that does not exist as `1/1`, and breaks a convergence check in **both directions at once**; the lies a *CI log* tells | ✅ Written |
| 04 | [State: what the cluster will not carry for you](chapter04_state.md) | Named volumes are node-scoped, so state gets **stranded rather than lost**; durability ≠ availability; rotating a secret rotates only the client; `trust` on loopback; concurrent workers racing to seed one database | ✅ Written |
| 05 | [Breaking it on purpose](chapter05_breaking_it.md) | The failure drills, predictions written first: unpullable images and rollback; **an image that starts and is the wrong application — first passing every signal, then re-run against the fix and caught in 47 seconds**; quorum loss (writes *and* reads); the reboot that silently cost three replicas; how to run a drill that means something | ✅ Written |
| 06 | [False greens](chapter06_false_greens.md) | ⭐ The unplanned capstone: eight ways this cluster reported success for a question nobody asked, why every one of those signals was *honest*, the ladder of questions, and the smoke gate we built — including the failure it missed and how the gap was closed | ✅ Written |

Chapters are written after the work they describe, so the table fills in behind the build rather than
ahead of it. **Chapter 6 was not planned** — the same phenomenon appeared in every drill, in our own
tooling, and in five of our own experiments, which made it a subject rather than a footnote.

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

### Reproducing it

1. Three Ubuntu 24.04 VMs that can reach each other and a registry. `scripts/provision_nodes.sh`
   installs Docker idempotently; Chapter 1 §3 covers `swarm init`/`join` and the token trap.
2. A registry with the application images, and a read-scoped deploy token.
3. `printf '<password>' | docker secret create pg_password -` on a manager (Chapter 2 §2 — `printf`,
   never `echo`).
4. `scripts/deploy_swarm.sh` on a manager does the rest: pre-flight, login, deploy, convergence poll,
   and three smoke gates. Every knob is an environment variable with a commented default.
5. Before drills, snapshot — and read the ZFS caveat below first.

**Two lab-ops rules that cost us real experiments, recorded so you keep the afternoon we lost:**

- ⚠️ **Proxmox ZFS snapshots are a linear stack, not a tree.** `qm listsnapshot` renders what looks
  like branches; in fact taking `s03` after rolling back to `s02` **forfeits** the newer lineage, and
  rollback to anything but the most recent snapshot is refused until the newer ones are deleted. Plan
  snapshots as a sequence of save-points, not as a branchable history.
- ⚠️ **Never paste a multi-line block into an interactive shell on the wrong host.** One drill ran on
  the workstation instead of the node because a shared mount made both prompts look identical. Write
  the block to a file, have the file **assert where it is** (`docker node ls` refuses on a non-manager),
  then run the file. `COMMANDS.md` §0 has the pattern.

---

## The Lab-vs-PROD ledger, in one place

Every chapter marks the places where the lab's configuration would be wrong in production, using the
callout format from [`../CONVENTIONS.md`](../CONVENTIONS.md). The full ledger with consequences lives
in the [phase file](../../phases/phase16_docker_swarm.md) (search "Lab vs PROD ledger"); this index
maps each row to where it is taught:

| # | The lab habit | Taught in |
|---|---|---|
| L1 | Registry over plaintext HTTP (`insecure-registries`) | Ch 2 §3 |
| L2 | Raft encryption key on disk (`Autolock: false`) | Ch 1 §6 |
| L3 | Every manager also runs workloads | Ch 1 §6, Ch 5 §2 |
| L4 | Three VMs, one physical host | Ch 1 §6, above |
| L5 | Unattended upgrades masked | Ch 1 §6 |
| L6 | Snapshots instead of backups | Ch 1 §6, Ch 4 §1 |
| L7 | Password SSH still enabled | phase file only — lab ops, not Swarm |
| L8 | Deploying `:latest` | Ch 2 §4, Ch 5 (the tag that moved mid-drill) |
| L9 | Registry credential as base64 in `~/.docker/config.json` | Ch 2 §3 |
| L10 | The system-of-record database as a container task | Ch 4 §1 |
| L11 | Plain HTTP, no reverse proxy, no TLS | Ch 2 §5 |
| L12 | One long-lived registry token, used by a human | Ch 2 §3 |
| L13/L18 | No healthchecks — **closed for the frontend on Aug 18**, kept deliberately for the backend | Ch 5 §1, Ch 6 §3 |
| L14 | A secret whose only copy was Swarm's Raft log | Ch 4 §2 |
| L15 | An app that starts anyway when its database is missing | Ch 6 §1 |
| L16 | `pg_hba.conf` trusts every local connection | Ch 4 §2 |
| L17 | Stateful service on a node-local volume, unpinned | Ch 4 §1 |
| L19 | CI runner `privileged` with the host Docker socket mounted | Ch 3 §5 |
| L20 | The branch CI builds from is a full plaintext secret mirror | Ch 3 §5 |
| L21 | Passphrase-less SSH deploy key in an unmasked CI variable | Ch 3 §4 |
| L22 | `StrictHostKeyChecking=no` on every `ssh`/`scp` in the job | Ch 3 §4 |

---

## What this track deliberately does not cover

House rule: chapters only document what was actually run. These standard Swarm topics were **not**
exercised here, and pretending otherwise would be this track's own false green. Each is one honest
sentence, so you know to learn it elsewhere:

- **Worker-only nodes / `node demote`** — all three nodes stayed managers; role separation is
  described (Ch 1), never felt.
- **`node drain`** — the maintenance switch every course teaches; we described it and then rebooted a
  live node instead, which is exactly what drain exists to avoid (Ch 5 §3).
- **`docker config`** — secrets were used extensively; configs never were.
- **Global mode services** — every service here is replicated.
- **Overlay network encryption, autolock unlock, live CA rotation** — described in Ch 1's Lab-vs-PROD
  callouts, never performed.
- **`mode: host` publishing** — everything used the routing mesh (`ingress`).
- **Placement preferences and node labels** — only hard constraints were used (the Postgres pin).
- **Update `parallelism > 1`** — every rollout moved one task at a time.
- **Resource limits under real pressure** — limits are declared in the manifest; the scheduler was
  never made to enforce them against contention.
- **Multi-network stacks, non-default logging drivers, log volume at scale** — out of scope.
- **Deploying into a degraded cluster.** Chapter 3 §7 adds a precondition that refuses to, and a
  corrected convergence check that counts tasks rather than replicas. Both were written *because* a
  degraded cluster broke the old check — but the fixed code has only ever run against a **healthy**
  cluster, where the old and new logic agree. ⚠️ **Its failure branch has never executed**, and the
  chapter says so where it matters.

---

## Swarm ↔ Kubernetes: what the two tracks actually showed

⚠️ *Grounded in what the two tracks ran (k3s on one node, Swarm on three); rows the labs did not
exercise are marked recited. The full comparison is a planned Part 7 working session.*

| Question | Swarm (this track) | Kubernetes (k3s track) |
|---|---|---|
| Deploy unit | `stack` of `service`s from compose syntax; tasks, not pods | `Deployment` → ReplicaSet → Pods, template-hash mechanics (k3s ch 2) |
| What a tag means | Resolved to a digest **once, at accept time** — services never follow a moving tag; the *next* deploy re-resolves (Ch 2 §4) | Kubelet-side `imagePullPolicy`; `:latest` defaults to pull-always — opposite default, same class of surprise (recited) |
| Correctness signal the platform can act on | Container `healthcheck` — added here only after C6b was felt (Ch 5 §1) | Liveness + readiness probes, first-class; the k3s track ran both, including "the probe that causes outages" (k3s ch 2) |
| Rolling update failure | `failure_action: rollback`, automatic, and **silent in the exit code** — proved by drill (Ch 5 §1) | Rollout halts at `maxUnavailable`; `kubectl rollout status` blocks and reports; undo is manual |
| Secrets | **Immutable objects**; rotation = new object + redeploy, and the value is unrecoverable via API (Ch 4 §2) | Secret objects are editable in place; consumers still need a restart to notice — different mechanics, same client-side blindness |
| Control plane quorum | Raft across managers; losing it freezes management **reads and writes** while apps keep serving — measured (Ch 5 §2) | k3s lab was single-node (no quorum to lose); the same Raft arithmetic was studied in *Redpanda* instead (k3s ch 3) |
| Traffic to a moving target | Routing mesh: every node answers a published port (Ch 2 §5) | Service/ClusterIP + kube-proxy; single-node lab could not show the multi-node property (recited) |
| Pull-based GitOps | **No real equivalent** — an architectural gap, not a missing feature (phase file, Part 4 design) | Argo CD / Flux exist and are standard (recited — not run in the k3s lab either) |
| Where state lives | Named volumes, **node-scoped**, silently duplicated per node — the stranding drill (Ch 4 §1) | PVC abstraction; single-node local-path in the lab, so the stranding class was invisible there |

---

## Capstone — prove it stuck

Do these against your own rebuilt lab, without the chapters open. Each has a full walkthrough if
needed (Chapter 5 for mechanics, Chapter 6 for what to watch):

1. **Ship a wrong-but-running image** and produce a deploy that *fails loudly with zero user-visible
   seconds*. You must be able to say which layer caught it and why the other layers could not.
2. **Strand a stateful service's data** by moving its placement, then get the data back. Say out loud
   at each step whether it is lost or stranded, and what proves it.
3. **Take down quorum** with the app serving, then produce a complete inventory of what is running —
   without a working `docker service ls`. Recover, and verify the leader afterwards without assuming
   it is the node you expect.
4. Hardest, from Chapter 6: for one green signal of your choice, write down the question it actually
   answers, the question you were treating it as answering, and the cheapest instrument that answers
   the real one.

---

## Contents

- [`COMMANDS.md`](COMMANDS.md) — ⭐ **every command used, indexed by the question it answers** rather
  than by chapter, plus how to *read* each failure state. Written as the track runs. Doubles as the
  specification for a portable read-only `docker-admin.sh` (not yet built — see its §11)
- `scripts/` — the provisioning and deploy scripts, as actually run. `deploy_swarm.sh` carries the
  three smoke gates and the pre-deploy `UpdateStatus` snapshot; its comments are lesson-bearing
- `manifests/` — the Swarm stack file; the DELIBERATE OMISSIONS block records which gaps are
  experiments and which are now fixes
- `diagrams/` — Graphviz sources; `images/` holds the rendered PNGs
- `docx/` — Word builds for printing (`python3 ../tools/build_docx.py docker-swarm`)
