# Phase 16 — Docker Swarm: build it, wire a pipeline to it, then break it

**Status:** 🔵 **IN PROGRESS — Parts 1 & 2 COMPLETE (Aug 13, 2026).** Three nodes built and
personalized (`s01-base-clean`), then formed into a **three-manager cluster, quorum 2 of 3**
(`s02-swarm-up`); see the [implementation log](#implementation-log) at the bottom.
**Next up: Part 3 — stack file, `docker secret`, first deploy, and trap C1.**
🙋 **Part 2 onward is HANDS-ON: Andrew runs the commands** — see
[`education/METHOD.md`](../education/METHOD.md) → "Who does the work". Part 1 was AI-driven and is the
last part that will be.
👉 The [pre-flight list](#-read-this-first--the-pre-flight-list) below was walked with Andrew on
Aug 13. **A5 is settled and A2 is deferred to Part 4**, so nothing is blocking. The seven hard rules
and the seven traps still apply for the rest of the phase — re-read them before each session.
📖 **`education/CONVENTIONS.md` is a MANDATORY read for this phase, not an optional one.** Session 1
drafts chapter 1, which makes this education content under `CURSOR_RULES` startup checklist item 2f.
Do not skip it on the grounds that Parts 1–2 look like pure infrastructure work.
**Created:** August 12, 2026
**Owner:** Andrew
**Track:** `education/docker-swarm/` (chapter numbering restarts at 01 — see `education/CONVENTIONS.md`)
**Weighting:** **DevOps first, SRE second.** Andrew's new role is DevOps/SRE with the emphasis on
DevOps, so Parts 1–4 (build it, make it repeatable, ship to it from a pipeline) carry the most
weight. Parts 5–6 are the SRE half and still matter, but they are not the centre of gravity the way
the failure drills were in Phase 14.

---

## 📌 READ THIS FIRST — the pre-flight list

Everything in this section also appears in context further down; this is the consolidated version so
that a re-read weeks later does not require scanning 500 lines to find the landmines. **Andrew asked
on Aug 12 that these be talked through at the start of the build session, not skimmed.**

Three kinds of item, and telling them apart matters:

### 🅐 Open items — and who actually resolves each

**Only two of these need Andrew, and both are one-minute decisions.** The rest were either closed by
going and looking (Aug 12) or are deferred into the work on purpose. Sorting them this way matters:
the original list read as five things blocking the phase, which was misleading.

| # | Item | Owner | State |
|---|---|---|---|
| A1 | Will the `.182` runner pick up jobs for `home-lab-setup`? | *verified, no human needed* | ✅ **CLOSED Aug 12 — yes, no runner change needed.** |
| A2 | Should this repo gain a `.gitlab-ci.yml` at all? | 🙋 **Andrew** | ⏸️ **DEFERRED to Part 4 (Aug 13)** — decide it with the `workflow: rules:` guard, since they are one decision |
| A3 | postgres storage: pin to a node, or NAS volume? | 🙋 **Andrew** | ✅ **RESOLVED Aug 13 (early, by argument) — PIN to a node, plus a time-boxed ~30 min NAS-volume demonstration.** See "A3 resolved" below. |
| A4 | Which published port, and does it collide? | *resolved, default chosen* | ✅ **CLOSED — publish `8080`.** |
| A5 | Is `education/docker-swarm/{scripts,manifests}/` the right home for the stack file and deploy script? | 🙋 **Andrew** | ✅ **CLOSED Aug 13 — yes, keep it in the track.** A track is self-contained per `CONVENTIONS.md`. Later tracks copy this. |

**A1 — closed, with evidence.** Queried GitLab's own database on `.181` (Aug 12, ~6:55 PM):

```
TOTAL RUNNERS: 1
  id=2 type=instance_type desc="gitlab-runner-1" tags=docker,linux,build projects=
HOME-LAB PROJECT: id=6 path=production/home-lab-setup   AVAILABLE TO IT: 2(instance_type)
RUNNER 2: run_untagged=true locked=false active=true
HOME-LAB CI ENABLED: builds_enabled=true shared_runners_enabled=true  default_branch="main"
```

Three things fall out of that, all favourable:
- The single runner is **`instance_type`** — an *instance-wide shared* runner, not project-scoped to
  Capricorn as feared. It is explicitly listed as available to project 6. **Part 4 needs no runner
  work at all.**
- **`run_untagged=true`**, so a job with no `tags:` will still be picked up. Worth knowing because the
  failure mode when this is `false` is silent: the job sits in `pending` forever with no error. Tags
  are optional here, but naming `tags: [docker]` explicitly is cheap and self-documenting.
- `builds_enabled` and `shared_runners_enabled` are already true on `home-lab-setup`, so CI works the
  moment a `.gitlab-ci.yml` lands — **which is exactly why A2 is a real question and not a formality.**

⚠️ **A1 closing makes A2 the only thing standing between us and Part 4.** Since CI is already enabled
on this project, adding the file is sufficient to start producing pipelines on every backup push. The
`workflow: rules:` guard is therefore not optional polish — it is part of the same decision.

**A3 — resolved early, and by argument rather than by trying both (Aug 13).** ⭐ **Andrew's position:**
*in production the OMS database is not a container at all — it is real PG hosts.* Containerized
system-of-record is the wrong shape: you want streaming replication, PITR, a tested restore path and an
upgrade story that does not involve a scheduler. Capricorn self-bootstraps demo data, so **losing the
lab's database costs nothing**, and the phase's real subject is **deploying and operating a
multi-container application on Swarm.**

**Accepted, with one trim and one consequence.**

⚠️ **The trim:** "no database runs in a container" is right for the **system of record** and too strong
as a general rule — Redis is in this very stack, and OpenSearch, MongoDB and Redpanda are all on the
study list and are all routinely run **on** the orchestrator, including in finance. The defensible
claim is the narrow one.

⭐ **The consequence — and the reason C3 survives:** the drill's value was never our data, it is the
**failure signature**, and that signature does not disappear when postgres becomes external, it
**relocates** — to Redis, to a service writing uploads or reports to a volume, to a Prometheus TSDB, to
an OpenSearch data node. **Andrew's argument IS the drill's conclusion**, so skipping the drill would
mean asserting the conclusion without earning it, which `METHOD.md` forbids outright. Hence C3
re-scoped to Redis (see traps table).

**So: postgres gets a `placement.constraints` pin to one node**, data is always demo data, and the
chapter says plainly that the production answer is an external cluster. **Plus a ~30 minute time-boxed
demonstration of a NAS-backed volume via `driver_opts`** — not as the architecture, but because it is
a real Swarm skill and how people solve this when they have no choice. ⭐ **The point of the timebox is
to be able to say "I have done it and here is why I would not reach for it"**, which carries more
weight in a conversation than either building it properly or skipping it.

**A4 — closed.** The nodes are fresh VMs on their own IPs, so a published port cannot collide with
anything existing in the lab; the only real constraints are avoiding Swarm's own `2377`/`7946`/`4789`.
**Publish `8080`** and move on. (Recorded rather than dropped, because "why 8080" is the sort of
question that comes back six months later.)

### 🅑 Hard rules — not up for negotiation once building starts

| # | Rule | Where |
|---|---|---|
| B1 | 🚨 **Do not modify `deploy_qa` or `deploy_prod_local`.** `deploy_qa` fires on every `develop` push; `deploy_prod_local` serves real production. Our job is additive, manual, and in a different project. | Part 4 |
| B2 | 🚨 **The lab stack gets its own volume names** (e.g. `postgres_data_swarm`) and is never pointed at `.184`'s volumes or data. Registry is the only thing shared with PROD. | Part 5 |
| B3 | ⚠️ **Snapshot all three nodes together, or not at all.** The Raft log is distributed state; rolling one node back to where the others have moved on produces an inconsistent cluster and a debugging session you did not sign up for. | Snapshots |
| B4 | ⚠️ **Exclude all three from `refresh.sh`**, disable `unattended-upgrades` + `apt-daily`. Package churn during a study phase manufactures failures that teach nothing and make real ones ambiguous. | Resource plan |
| B5 | ⚠️ **Purge Chrome + Cursor after `host_setup.sh`.** It is a workstation script; these are headless nodes (~1.8 GB wasted otherwise). | Part 1 |
| B6 | 🔑 **Use a deploy token scoped to `read_registry`**, masked, in CI variables — not the `root` password that already sits in this repo's remote URL. | Part 4 |
| B7 | 🚨 **NEVER copy `.184`'s credentials into this repo.** Capricorn's compose file carries **inline plaintext** `POSTGRES_PASSWORD`, `POSTGRES_USER` and a `DATABASE_URL` with an embedded password (there is no `.env`). Copying it as a starting point puts a **production database password into a repo with a public GitHub remote**. Invent lab-only credentials and deliver them as **Docker secrets**. | Part 3 |

### 🅒 Deliberately planted traps — do NOT fix these in advance

These look like bugs in the plan. They are the curriculum. **Hitting them on purpose is the point**;
pre-empting them removes the lesson and leaves you with a tutorial.

| # | Trap | The lesson it buys |
|---|---|---|
| C1 | Run `docker stack deploy` **without** `--with-registry-auth` once, on purpose. | Tasks wedge in `Preparing`/`Rejected` with `No such image`, but *only* on nodes that are not the manager you logged in on — while the same image pulls fine by hand. Auth is per-task, not per-deploy. |
| C2 | Let the backend start before postgres is ready. Swarm **ignores `depends_on`**, which Capricorn's compose file uses. | You find out whether the app retries its DB connection or crash-loops — a property of the app you cannot learn from the compose file. |
| C3 | ♻️ **RE-SCOPED Aug 13 — run on REDIS, not postgres.** Write a key, force a save, force the task onto another node, and watch it come up **healthy with empty storage**. | Silent state loss that looks like a clean deploy. ⚠️ **The lesson is the failure SIGNATURE, not the database:** *a task carrying node-local state can be silently rescheduled onto empty storage, and the orchestrator reports success.* Redis is the honest vehicle because **Redis really does run in containers in production** — lost sessions, a cache stampede against a cold backend, lost work if anything treats it as a queue. Postgres is excluded because it is **pinned** (A3) and because in production it would not be a container at all. |
| C4 | Point the deploy job at one manager by IP, then kill that manager while the cluster stays healthy. | HA control plane ≠ HA delivery path. The best CI lesson here. |
| C5 | Take quorum down to 1 of 3 and try to change something. | Containers keep serving; the control plane refuses all changes. Degraded ≠ down, and the reflex to "just bounce it" turns a serving cluster into a real outage. |
| C6 | Roll out a deliberately broken image tag. | Whether `update_config` / `rollback_config` actually saves you, and why a real healthcheck is not optional. |
| C7 | Push a **new image under the same `:latest` tag**, redeploy, and see whether anything actually changes. | Swarm resolves a tag to a **digest** and stores that, so services do not track a moving tag the way a `docker compose pull` does. Teaches `--resolve-image`, and why "I pushed a fix and prod is still running the old code" is a Swarm classic. |

### 🅓 Findings inherited from elsewhere — recorded, not fixed here

| # | Finding | Disposition |
|---|---|---|
| D1 | `/opt/capricorn/docker-compose.yml` on `.184` declares `postgres:15.5-alpine`, but the **running container is the custom `production/capricorn/postgres:latest`**. The file does not describe what is deployed, so "just redeploy from the compose file" would quietly change PROD's database image. | ⚠️ **Application layer — out of this repo's ownership.** Recorded because our stack file must reference the image that really runs, and because it is a perfect example of config drift. Raise with whoever owns Capricorn. |
| D2 | Three VMs on one physical host simulates **node** failure, not **host** failure. | Honest caveat to state in the chapter, same as Phase 14's three-brokers-in-one-VM note. Every drill is a real Raft event; losing the Z6 still loses all three. |
| D4 | 🚨 **`docker/docker-compose.qa.deploy.yml` is COMMITTED to the Capricorn repo with live third-party credentials inline** — a `DATABASE_URL` with the password, `MARKET_DATA_API_KEY`, `PLAID_CLIENT_ID`, `PLAID_SECRET`, and `EXPORT_ENCRYPTION_KEY` (the Fernet key that decrypts Plaid access tokens in `/data/export` files). ⚠️ **`PLAID_ENV=production`** — the QA environment is pointed at Plaid **production**, so these are not sandbox credentials. | ⚠️ **Application layer — raise with whoever owns Capricorn; NOT fixed here.** Materially worse than D3: D3 is a database password on one host, this is a **committed** set of live third-party financial-API credentials plus the key that decrypts exported access tokens. Editing the file does not help — it is in git history. Rotation at the provider is the only real remedy. **Values were deliberately NOT copied into this repo** (rule B7); the finding is recorded, the secrets are not. |
| D5 | ⚠️ **`Dockerfile.postgres` bakes `ENV POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` into the image**, which is why QA's compose supplies no postgres environment at all. The same password also appears **in a comment on line 3 of `001_schema.sql`**, likewise baked into a layer. | ⚠️ **Application layer.** Consequence worth stating: **anyone who can pull the image has the database password** — including this phase's own `swarm-lab-pull` deploy token, which was granted `read_registry` for image pulls and got a credential as a side effect. **This is why our stack overrides `POSTGRES_PASSWORD` to `""` and supplies a lab-only value through `docker secret`** instead of inheriting the baked one. A credential in an image layer cannot be removed by editing a file. |
| D3 | **Capricorn's compose on `.184` holds its secrets in plaintext, inline** — `POSTGRES_PASSWORD`, `POSTGRES_USER`, `POSTGRES_DB`, and a `DATABASE_URL` containing the password. There is **no `.env` file**; the values are committed into the compose file itself. | ⚠️ **Application layer — not ours to fix**, but it is the reason for hard rule B7. Note that `push_github.sh` would likely catch a leaked `DATABASE_URL` (its URL-with-password gate) but **would not catch a bare `POSTGRES_PASSWORD=` line** — so the protection against copy-paste is partial and accidental, not something to rely on. Raise the plaintext-secrets issue with whoever owns Capricorn. |

---

## Why this phase exists

Phase 14 taught the container-orchestration ideas on **one node**, where the interesting failures
could only be simulated inside a single VM. This phase is the opposite trade: a **genuinely
multi-node cluster** running a **real application** through a **real pipeline**.

That combination is the point. Most Swarm tutorials deploy `nginx` by hand and stop. Here the
workload is **Capricorn** — an app that already builds, scans and deploys through GitLab — so the
questions that come up are the ones that come up at work: how does a deploy authenticate to the
registry from a node it has never touched, what happens to a rolling update when the new image is
broken, and what do you do when the control plane is alive but refuses to accept changes.

**Success = Andrew can build a Swarm from nothing, ship to it from a pipeline, break it in several
different ways, and explain what each failure did to the application** — plus defend, out loud, why
you would choose Swarm or Kubernetes for a given job.

### The comparison is half the value

Andrew has just spent two weeks on k3s. Doing the *same app* on Swarm makes the differences
concrete rather than theoretical, and "I have run both, in anger, on the same workload" is a much
stronger claim than having read a comparison table. Part 7 captures it deliberately.

### The employer runs GitHub + Jenkins, and that shapes Part 4

Confirmed Aug 12: **Docker Swarm is in the employer's platform**, alongside **GitHub** for source
and **Jenkins** for CI. Our lab is GitLab and GitLab CI. Everything in this phase transfers cleanly
*except* the pipeline glue, which would be written in a syntax the employer does not use.

So Part 4 is designed for portability on purpose: **the deploy logic lives in a shell script
(`deploy_swarm.sh`), and the CI file is a thin wrapper that calls it.** GitLab CI invokes it today in
a handful of lines; a Jenkinsfile invokes it later in about the same. The transferable knowledge —
what a deploy actually has to *do* — sits in the script where it can be read, not spread through
YAML that only one CI product understands. This is also the honest engineering answer: CI systems are
interchangeable, deploy logic is not.

Jenkins itself is **out of scope for this phase** (see "Out of scope") — a possible Phase 17, and a
natural one, since this repo already pushes to GitHub via `push_github.sh`, which is exactly the
source side of the employer's setup.

---

## Learning objectives

By the end you should be able to explain, without notes:

**Swarm mechanics**
- Manager vs worker, and **why 2 managers is strictly worse than 1** (Raft quorum is
  `floor(N/2)+1`, so 2 managers means losing either one kills the control plane).
- What survives quorum loss: **running containers keep running**; what dies is your ability to
  *change* anything. This is the single most important operational fact about Swarm.
- Service vs task vs container, and how a service's desired state is reconciled.
- The **routing mesh**: why a published port answers on *every* node, even nodes not running a task.
- Overlay networking and what the `ingress` and `docker_gwbridge` networks are actually for.
- `update_config` / `rollback_config` — rolling updates, and automatic rollback on failure.
- Why Swarm has **no PersistentVolumeClaim equivalent**, and what you do instead.
- **`docker secret` and `docker config`** — how they differ from environment variables, why a secret
  is immutable, and how that constrains credential rotation.
- **Image resolution:** a service stores a **digest**, not a tag, so `:latest` does not float the way
  it does under `docker compose`. What `--resolve-image` does and when it bites.

**Shipping to a cluster (the DevOps half — most of the weight)**
- Why `docker stack deploy` needs **`--with-registry-auth`**, and the confusing failure without it.
- Why a highly-available control plane does **not** give you a highly-available *deploy path*.
- The difference between "the cluster is healthy" and "I can ship to it" — and how to monitor both.
- **How to keep deploy logic portable across CI systems**, and why that matters when the employer
  runs Jenkins and you learned on GitLab CI.
- Deploy **credentials**: why a scoped deploy token beats reusing an admin password, even in a lab.
- Provisioning as a **re-runnable script** rather than commands typed once — and what "idempotent"
  costs you in practice.

**Swarm vs Kubernetes (Part 7)**
- Where Swarm is genuinely simpler and where that simplicity costs you.
- Which Phase 14 concept maps to which Swarm concept, and which has no counterpart at all.

---

## Target architecture

Three VMs, all **managers**, cloned from template 9000. One of them is demoted to worker later, as
an exercise, rather than being built that way.

```
+---------------------------------------------------------------------+
|  Proxmox host  192.168.1.150                                        |
|                                                                     |
|  +---------------+  +---------------+  +---------------+            |
|  | 191           |  | 192           |  | 193           |            |
|  | docker-swarm-1|--| docker-swarm-2|--| docker-swarm-3|  Raft      |
|  | .191  manager |  | .192  manager |  | .193  manager |  quorum 2/3|
|  +---------------+  +---------------+  +---------------+            |
|          |                  |                  |                    |
|          +--------- overlay network -----------+                    |
|                    routing mesh: published port answers on all 3    |
+---------------------------------------------------------------------+
              ^                                    |
              | scp stack file + deploy_swarm.sh   | docker pull
              | then ssh 'bash deploy_swarm.sh'    v
     +-----------------+                 +-----------------------+
     | .182 gitlab-run |                 | registry :5050 (HTTP) |
     | (NOT a node)    |                 | on .181 gitlab        |
     +-----------------+                 +-----------------------+
              ^
              | manual job in THIS repo's .gitlab-ci.yml
              | (production/home-lab-setup — Capricorn's repo untouched)
```

**Deliberately NOT in the cluster:** the runner (`.182`) and VM 200 (`.180`). The runner is live CI
infrastructure, and VM 200 is the auto-deploy target for Capricorn QA on every `develop` push. Both
were considered and rejected — see "Out of scope".

**Ports Swarm needs between nodes** (no PVE firewall exists on these VMIDs today, so nothing to open
yet — but record them, because adding a `19x.fw` later without these breaks the cluster silently):

| Port | Proto | For |
|---|---|---|
| 2377 | tcp | cluster management (managers only) |
| 7946 | tcp + udp | node discovery / gossip |
| 4789 | udp | overlay network data plane (VXLAN) |

---

## Resource plan

| Resource | Per node | Reasoning |
|---|---|---|
| **vCPU** | 2 | Swarm's control plane is light — Raft on 3 nodes with a handful of services. Host has 44 of 48 threads assigned; +6 makes 50/48, a **1.04:1 overcommit** which is normal. CPU is the binding constraint here, not RAM. |
| **RAM** | 4 GB | Docker + a few Capricorn containers. Host has **84 GB of 125 GB** assigned, so 12 GB fits comfortably — **this is the 16 GB that VM 186 gave back on Aug 12.** |
| **Disk** | 40 GB on `vm-ephemeral` | Images dominate; Capricorn FE+BE+postgres+redis plus layers. Pool has **1.30 TB available**. |
| **Pool** | `vm-ephemeral` | Disposable and rebuildable by definition — the standing rule. |
| **Backups** | **None** | Consistent with the rule for rebuildable VMs. Protection is snapshots (below), not vzdump. |
| **`onboot`** | `1` | So the cluster survives a host reboot and quorum re-forms on its own. Worth watching the first time. |

**Total cost: 12 GB RAM, 6 vCPU, 120 GB disk.**

⚠️ **Exclude all three from `refresh.sh`** and disable `unattended-upgrades` + `apt-daily`, exactly
as VM 186 does. Package churn during a study phase manufactures failures that teach you nothing, and
worse, makes a real failure ambiguous.

---

## Snapshot checkpoints

Same discipline as Phase 14, and for the same reason: you learn this fastest by breaking things, and
that is only comfortable when rollback is instant. Take one on **each node** at each milestone.

| Snapshot | Taken when |
|---|---|
| `s01-base-clean` | Personalized, Docker present, before `swarm init` |
| `s02-swarm-up` | 3 managers, `docker node ls` shows 3 × Ready/Reachable |
| `s03-stack-deployed` | Capricorn running and reachable through the routing mesh |
| `s04-ci-wired` | The pipeline job deploys successfully end to end |

Names must start with a letter (PVE rejects `01-...` as an invalid configuration ID — learned in
Phase 14). Take them **hot**; the guest agent is baked into template 9000, so `qm snapshot` does a
filesystem-consistent freeze/thaw without stopping anything.

> ⚠️ **Snapshot all three together, or none.** A Swarm's Raft log is *distributed state*. Rolling one
> node back to a point where the others have moved on gives you an inconsistent cluster, which is a
> genuinely confusing thing to debug and is **not** the drill you meant to run. Script it:
> `for v in 191 192 193; do qm snapshot $v s02-swarm-up; done`

### 🚨 On ZFS, snapshots are a STACK, not a tree — learned the hard way, Aug 13, 2026

The table above reads like a set of independent bookmarks you can jump between. **On this lab's storage
that is false, and the plan above was written on the wrong mental model.** Taking `s03-stack-deployed`
and then trying to go back to `s02-swarm-up` to re-run trap C2 failed on all three nodes:

```
qm rollback 191 s02-swarm-up
  -> can't rollback, 's02-swarm-up' is not most recent snapshot on 'vm-ephemeral:vm-191-disk-0'
```

`vm-ephemeral` is a **`zfspool`** (`pvesm status`), so each disk is a zvol and each PVE snapshot is a
ZFS snapshot:

```
vm-ephemeral/vm-191-disk-0@s01-base-clean       Thu Aug 13 12:25
vm-ephemeral/vm-191-disk-0@s02-swarm-up         Thu Aug 13 13:53
vm-ephemeral/vm-191-disk-0@s03-stack-deployed   Thu Aug 13 18:00
```

⭐ **`zfs rollback` can only return to the most recent snapshot.** Going further back requires
`zfs rollback -r`, which **destroys every snapshot in between** — and PVE will not do that implicitly,
because it would silently delete restore points you asked it to keep. So refusing is the *correct*
behaviour, not a bug. **The practical rule: on ZFS you can only ever go BACK ONE STEP, and every new
snapshot permanently forfeits the ability to return to any older one without deleting it.**

⚠️ **This is storage-dependent, which is why it surprises people.** The identical `qm snapshot` /
`qm rollback` workflow on **qcow2 file-based storage really does branch** — qcow2 keeps internal
snapshots that can be restored in any order, and `qm listsnapshot` prints an indented *tree* on both
backends. **The display implies branching that the ZFS backend does not provide.** The lab's own
`listsnapshot` output looked exactly like a tree right up to the moment rollback refused.

🏭 **Lab vs PROD.** *Lab:* snapshot at every milestone, roll back freely, assume they are cheap
bookmarks. *Production:* snapshots are **not** a backup and not a branching history — they share the
pool with live data, a rollback is one-way, and reaching an older restore point means **destroying
everything after it**. *Consequence:* a team that plans DR around "we'll roll back to last Tuesday"
discovers at the worst possible moment that doing so **deletes Wednesday through Friday**, and that a
pool-level fault takes the snapshots with the data because they were never a separate copy. Real
recovery points need `vzdump`/PBS or replication to different storage.

**The planning rule this produces for the rest of this phase:** *decide which drills you still owe a
snapshot BEFORE taking the next one.* Any trap that must run from `s02` has to run **before**
`s03` exists. Milestone snapshots are checkpoints on a path, and taking one is a decision to stop
being able to go back.

---

## Part 1 — Three VMs from template 9000, provisioned by script

**Goal:** `docker-swarm-1/2/3` at `.191/.192/.193`, personalized, Docker running, nothing else.

VMID = last octet, matching 181–186. All three VMIDs and IPs were **verified free on Aug 12, 2026**
(no ping response, nothing in `/etc/hosts`, no references in the repo).

**DevOps framing:** write this as a script you can re-run, not commands you type three times. Typing
them three times is how the third node ends up subtly different from the first two, and a
"mysteriously broken" third node is the most common self-inflicted Swarm problem there is.

```bash
for n in 1 2 3; do
  ID=$((190+n))
  qm clone 9000 $ID --name docker-swarm-$n --full --storage vm-ephemeral
  qm set $ID --cores 2 --memory 4096 --onboot 1
  qm resize $ID scsi0 40G
  qm set $ID --ipconfig0 ip=192.168.1.$ID/24,gw=192.168.1.1 --nameserver "8.8.8.8 8.8.4.4"
  qm start $ID
done
```

Then the lab's standard personalization on each, which **already handles the registry** — this is the
step people usually do by hand and forget on two of three nodes:

```bash
mkdir -p ~/setup && cd ~/setup
wget -q http://192.168.1.195/scripts/host_setup.sh
wget -q http://192.168.1.195/scripts/smb_credentials   # required, not auto-fetched
echo y | bash host_setup.sh
```

`host_setup.sh` chains `setup_docker.sh`, which writes
`/etc/docker/daemon.json` = `{"insecure-registries": ["gitlab.gothamtechnologies.com:5050"]}` and
restarts Docker. **The registry is HTTP, and Swarm pulls on whichever node runs a task, so all three
nodes need this** — getting it for free from the standard script is the reason to use the script.
Registry reachability from a lab VM was confirmed Aug 12 (`/v2/` answers `401`, i.e. up and requiring
auth).

⚠️ **Then purge the desktop packages.** `host_setup.sh` runs `setup_desktop.sh`, which installs
Chrome + Cursor (~1.8 GB) — it is a workstation script and these are headless nodes:
`apt-get purge -y google-chrome-stable cursor && apt-get autoremove --purge -y`

⚠️ **`qm resize` is not optional here, and the guest side of it is the bit that bites.** Template 9000's
disk is **3584M — 3.5 GB** (verified Aug 12), so every clone starts far too small for a Docker host and
the grow to 40 GB is load-bearing rather than cosmetic. Growing is safe (`qm resize` only refuses to
*shrink*), but the resize enlarges the **virtual disk**, and the guest filesystem only follows if
cloud-init's `growpart` runs on first boot. **If it silently does not, you get a 3.5 GB root that fills
the first time you pull the Capricorn images**, and the error you see will be about image layers, not
about disk sizing. So confirm it from inside the guest, not from `qm config`.

**Verify per node:** hostname, `cloud-init status: done`, unique machine-id, `docker --version`,
`docker info | grep -i swarm` → `inactive`, `cat /etc/docker/daemon.json`, and
**`df -h /` showing ~40 GB rather than 3.5 GB**.
**Then `s01-base-clean` on all three.**

---

## Part 2 — Form the cluster

```bash
# on docker-swarm-1
docker swarm init --advertise-addr 192.168.1.191
docker swarm join-token manager        # prints the exact command to run elsewhere

# on -2 and -3, paste that command
docker node ls                          # from any manager
```

**What to look at, not just run:** `docker node ls` shows `MANAGER STATUS` — one `Leader`, two
`Reachable`. `docker info` on a manager reports the Raft state. Note that **`docker node ls` only
works on a manager**; running it on a worker errors, which is itself the clearest demonstration that
workers hold no cluster state.

**Questions to be able to answer before moving on:** which node is the leader and how was it chosen;
what `Reachable` means as distinct from `Ready`; and what quorum is for 3 managers.

**Then `s02-swarm-up` on all three.**

---

## Part 3 — Deploy Capricorn by hand, via the script CI will later call

Do this manually first. When the pipeline later fails, you need to already know what a *working*
deploy looks like, or you will be debugging two things at once.

**Write `deploy_swarm.sh` here, in Part 3, and run it by hand.** Part 4 then adds no new deploy
logic at all — it only arranges for the same script to be invoked by a runner. That is what makes the
CI portable, and it means a pipeline failure in Part 4 is unambiguously a *wiring* problem, because
the deploy itself was already proven.

The script does exactly three things:

```bash
# education/docker-swarm/scripts/deploy_swarm.sh  (runs ON a manager)
docker login "$REGISTRY" -u "$REG_USER" --password-stdin <<< "$REG_TOKEN"
docker stack deploy -c capricorn.stack.yml --with-registry-auth capricorn
docker stack services capricorn        # then poll until replicas converge, or fail loudly
```

That third line matters more than it looks: `docker stack deploy` **returns success as soon as it has
accepted the desired state**, not when the tasks are actually running. A deploy job that does not
poll for convergence will report green while the app is crash-looping. Make the script wait, and make
it exit non-zero when it does not converge.

⚠️ **`:latest` does not mean what compose taught you it means.** Swarm resolves an image tag to a
**digest** when the service is created and stores the digest in the service spec, so a service does
not follow a moving tag. `docker stack deploy` re-resolves by default (`--resolve-image always`), but
the moment that default changes, or the manager cannot reach the registry, you get a deploy that
reports success and silently keeps running the old code. Since Capricorn publishes to `:latest`, this
is squarely in the path of this phase. **Look at the resolved digest** with
`docker service inspect --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' capricorn_backend` —
it will show `…@sha256:…`, not the tag you typed. Trap C7 exists to make you meet this on purpose.

### Configuration and secrets — the part that will stop you on day one

🚨 **Read hard rule B7 before writing a single line of the stack file.** Capricorn's compose on `.184`
carries its configuration **inline and in plaintext** — `POSTGRES_USER`, `POSTGRES_PASSWORD`,
`POSTGRES_DB`, `VITE_API_URL`, and a `DATABASE_URL` with the password embedded in it. There is **no
`.env` file**; the literal values live in the compose file. Copying that file as a starting point is
the obvious move and it would put **a production database password into this repo, which has a public
GitHub remote.** Do not do it. Invent lab-only credentials; the database is empty and new anyway
(Part 5), so they can be anything.

**Swarm's own answer to this is `docker secret`, and using it is the right call twice over** — it
keeps credentials out of the stack file, and it is one of the few places Swarm is genuinely *nicer*
than the alternatives, so it belongs in the curriculum rather than being worked around:

```bash
printf 'some-lab-only-password' | docker secret create pg_password -
# then in capricorn.stack.yml:
#   secrets: [pg_password]
#   environment:
#     POSTGRES_PASSWORD_FILE: /run/secrets/pg_password
```

Three things to understand while doing it, because they are exam-grade:
- A secret is **stored in the Raft log, encrypted at rest, and mounted into the task as a tmpfs file**
  — it never lands on a node's disk and never appears in `docker inspect` output the way an
  environment variable does.
- Secrets are **immutable**. You cannot update one in place; you create a new secret and update the
  service to reference it. That constraint shapes how credential rotation works, and it is worth
  saying out loud in the chapter because it surprises people.
- `docker config` is the same mechanism for **non**-sensitive files, and is the honest analogue of a
  Kubernetes ConfigMap.

⚠️ **Postgres needs `POSTGRES_PASSWORD_FILE`, not `POSTGRES_PASSWORD`,** to read from a secret — the
official image supports the `_FILE` convention. Whether Capricorn's **custom** postgres image and its
**backend** honour the same convention is unknown, and that is a real thing to find out rather than
assume. If the backend can only take a `DATABASE_URL` string, say so in the chapter and describe the
workaround; that gap between "how the platform wants to pass secrets" and "how the app is willing to
receive them" is exactly the friction a DevOps engineer spends real time on.

### Our own stack file — Capricorn's repo stays untouched

The live PROD stack on `.184` was inspected Aug 12. It is **four services**:

| Service | Image (as it actually runs) |
|---|---|
| `frontend` | `gitlab.gothamtechnologies.com:5050/production/capricorn/frontend:latest` |
| `backend` | `gitlab.gothamtechnologies.com:5050/production/capricorn/backend:latest` |
| `postgres` | `gitlab.gothamtechnologies.com:5050/production/capricorn/postgres:latest` |
| `redis` | `redis:7.2.4-alpine` |

⚠️ **Finding worth recording:** `/opt/capricorn/docker-compose.yml` on `.184` declares
`postgres:15.5-alpine`, but the running container is the custom
`production/capricorn/postgres:latest` image. **The file on disk is out of sync with what is
deployed.** Our stack file should reference the custom image, since that is what really runs. (This
is an app-layer observation, not something to fix here — but it is exactly the sort of drift that
makes "just redeploy from the compose file" dangerous, and it belongs in the chapter.)

We write **`education/docker-swarm/manifests/capricorn.stack.yml`** in *this* repo, pulling those
published images and adding the `deploy:` keys Swarm needs. Capricorn's repository is never modified.

**The compose-vs-stack difference is the interesting part.** `docker stack deploy` eats the same
compose v3 file, but the two engines respect different halves of it:

| Key | `docker compose` | `docker stack deploy` |
|---|---|---|
| `deploy.replicas`, `placement`, `update_config`, `restart_policy` | **ignored** | honoured |
| `build` | builds the image | **ignored** — image must be pre-built and pullable |
| `depends_on` | orders startup | **ignored** — services must tolerate any start order |
| `container_name` | honoured | **ignored** |

⚠️ **`depends_on` being ignored is not academic here.** Capricorn's compose file uses it, and the
backend presumably expects postgres. On Swarm, the backend *will* start before the database is
ready, so it must either retry its connection or be allowed to crash-loop until postgres answers.
Watch this happen, then decide which of those two it is doing.

⚠️ **`--with-registry-auth` is the gotcha to hit deliberately.** Without it, the manager holds your
credentials but never forwards them, so tasks scheduled on the *other* nodes cannot pull. Symptom:
`docker service ps` shows tasks stuck in `Preparing`/`Rejected` with `No such image`, while the same
image pulls fine by hand on the manager. **Run it wrong once, read the error, then fix it** — it is a
far better lesson than reading this paragraph.

**Then prove the routing mesh:** curl the published port on a node that `docker service ps` says is
**not** running a task. It answers anyway. Explain why before you move on.

**Then `s03-stack-deployed`.**

---

## Part 4 — Wire a pipeline to the cluster

**Where it lives (settled Aug 12):** a **new `.gitlab-ci.yml` in this repo**
(`production/home-lab-setup`), with a single **manual** `deploy_swarm` job. This repo has no CI file
today, so the lab owns its entire deploy path and **Capricorn's `.gitlab-ci.yml` is never touched.**

🚨 **The hard rule this preserves: do not modify `deploy_qa` or `deploy_prod_local`.** `deploy_qa`
fires automatically on **every** `develop` push and `deploy_prod_local` serves real production. Both
run on the shared runner at `.182`. Keeping our job in a different project means breaking the lab
cluster *cannot* break Capricorn's real delivery path.

The job is deliberately thin — it is a wrapper, not a deploy:

```yaml
# roughly; the point is how little there is
deploy_swarm:
  when: manual
  script:
    - scp manifests/capricorn.stack.yml scripts/deploy_swarm.sh $SWARM_USER@$SWARM_HOST:~/
    # token goes over STDIN, never on the command line
    - echo "$REG_TOKEN" | ssh $SWARM_USER@$SWARM_HOST "REGISTRY=$REGISTRY REG_USER=$REG_USER bash deploy_swarm.sh"
```

⚠️ **Why the token is piped rather than assigned inline.** An obvious first draft writes
`ssh host "REG_TOKEN=$REG_TOKEN bash deploy_swarm.sh"`, which puts the token in the **remote process's
command line**, where any user on that node can read it out of `ps` for as long as the deploy runs.
Passing it on stdin keeps it out of the process table. GitLab masking hides it in *job logs* and does
nothing about this.

⚠️ **And be honest in the chapter about what is still exposed:** the lab registry is **plain HTTP**
(that is why `insecure-registries` is set), so `docker login` sends the token across the LAN in the
clear regardless of how carefully it was handled on either end. Least privilege is exactly why B6
scopes it to `read_registry` — the control you *do* have is limiting what a captured token is worth,
not preventing its capture.

**A Jenkinsfile later is the same two lines in Groovy.** That is the whole point of Part 3 writing the
script first.

Requirements to work through:
- ✅ **The runner is already usable — verified Aug 12, no work needed.** Runner `id=2` is
  `instance_type` (instance-wide shared), active, unlocked, `run_untagged=true`, and GitLab lists it as
  available to project `production/home-lab-setup` (id 6), which already has `builds_enabled=true` and
  `shared_runners_enabled=true`. Full evidence in the pre-flight list, item A1.
- ⚠️ **Stop backup pushes from spawning pipelines.** `push_gitlab.sh` pushes this repo constantly;
  adding a CI file means every one of those creates a pipeline. Use a `workflow: rules:` block so the
  pipeline only exists when triggered deliberately (e.g. `$CI_PIPELINE_SOURCE == "web"`), rather than
  leaving a trail of blocked manual pipelines on every backup.
- SSH from the runner (`.182`) to a manager, with a key — the runner already does exactly this for
  `.184`, so copy that pattern rather than inventing one.
- 🔑 **Use a GitLab deploy token scoped to `read_registry`**, stored as a masked CI variable — *not*
  the `root` password that already appears in this repo's remote URL. Least privilege is a DevOps
  habit worth building even when the blast radius is a lab.
- Deploy an **already-built, already-pushed** image. Do not add a build step; reuse the artefact the
  Capricorn pipeline already produces.
- ⚠️ **The deploy path is a single point of failure even though the control plane is not.** If the job
  targets one manager by IP and that manager is the one you killed, the deploy fails while the cluster
  is perfectly healthy. **Notice this, then fix it** (try each manager in turn, or a name that
  resolves to all three). This is the best CI lesson in the phase — HA control plane ≠ HA delivery.

**Then `s04-ci-wired`.**

---

## Part 5 — State: where Swarm actually hurts

**This is a real exercise, not a paragraph — confirmed Aug 12.** Capricorn is stateful: the live
stack declares named volumes **`postgres_data_prod`** and **`redis_data_prod`**, plus a **bind mount**
`./database/init:/docker-entrypoint-initdb.d:ro` for the schema init scripts.

**Swarm has no PersistentVolumeClaim, no StorageClass, and no volume orchestration.** In Phase 14,
k3s's `local-path` provisioner handed the app a PVC and the problem disappeared. Here, two specific
traps are waiting, and both are worth triggering on purpose:

1. ⚠️ **A named volume is local to whichever node the task lands on.** If postgres reschedules onto a
   different node, Docker creates a *new, empty* volume there and postgres starts up perfectly
   happily against an empty database. **No error, no warning — just a database with nothing in it.**
   This is the single most valuable thing in this phase: it is silent data loss, it looks like a
   healthy deploy, and it is a real production trap rather than a lab curiosity.
2. ⚠️ **A bind mount assumes the path exists on the node running the task.** `./database/init` is
   present on `.184` because that is where someone cloned it. On a three-node Swarm, the two nodes
   that lack the directory will either fail or silently mount an empty one, depending on the driver.

   📋 **First task in Part 5: find out whether we even need that bind mount.** The running postgres is
   the **custom** `production/capricorn/postgres:latest`, not stock — so the init scripts may already
   be baked into the image, which would make the bind mount redundant for us and the stack file
   simpler. Check with
   `docker run --rm --entrypoint ls production/capricorn/postgres:latest /docker-entrypoint-initdb.d`.
   If they are in the image, say so and drop the mount; if they are not, the `docker config` mechanism
   from Part 3 is the Swarm-native way to deliver them to every node without a shared filesystem.

So you get a real choice, and both options cost you something:

| Option | What it costs |
|---|---|
| Named volume + `placement.constraints` pinning postgres to one node | The HA story you just built dies for that service: the pinned node becomes a hard dependency. **This is what most real Swarm deployments actually do**, which is itself the lesson. |
| NFS/CIFS volume from the NAS (`192.168.1.120`) | Works from any node, but now the NAS is a shared single point of failure, and you inherit its latency and lock semantics — which for a database is a real question, not a formality. |

**Data for the lab stack: start fresh and empty**, built from the init scripts. No dump is restored
from `.184`.

🚨 **Hard isolation rule:** the lab stack gets its **own volume names** (e.g. `postgres_data_swarm`)
and must never be pointed at `.184`'s volumes or data. The lab and PROD Capricorn share a registry
and nothing else. An empty lab database is fully sufficient to demonstrate the empty-volume trap —
the trap is about the *volume being new*, not about how much was in the old one.

Either way, **write down which option you chose and why.** This is the sharpest
Swarm-vs-Kubernetes insight available, and an interviewer can tell instantly whether it was lived or
read.

---

## Part 6 — Failure drills (the SRE half)

**Snapshot all three nodes before each drill, restore after.**

| # | Drill | What to observe | What to conclude |
|---|---|---|---|
| 1 | `qm stop` one manager | Quorum holds (2/3). Tasks on the dead node reschedule onto survivors. App stays up. | This is the *designed* failure. Note how long rescheduling actually takes. |
| 2 | `qm stop` a **second** manager | ⚠️ Control plane loses quorum. **Running containers keep serving traffic**, but `docker service update`, `stack deploy` and rescheduling all fail. | **The most important lesson in the phase.** Degraded ≠ down, and the reflex to "just bounce it" converts a serving cluster into an outage. |
| 3 | `docker node update --availability drain` | Tasks migrate off; node stays a manager and keeps voting. | Drain is for maintenance, not eviction — and it is the safe way to patch a node. |
| 4 | Rolling update with a **deliberately broken** image tag | `update_config`/`rollback_config` behaviour; whether it auto-rolls-back or wedges half-updated. | Why `failure_action: rollback` and a real healthcheck are not optional. |
| 5 | Omit `--with-registry-auth` | Tasks stuck `Preparing`/`Rejected`, `No such image`, but only on non-manager nodes. | Auth is per-task, not per-deploy. |
| 6 | **Force postgres onto another node** (unpin it, drain its node) | A *new empty volume* appears; the app comes up with no data and reports healthy. | Silent data loss. The Part 5 trap, demonstrated rather than described. |
| 7 | Recover from drill 2 with `docker swarm init --force-new-cluster` | A single surviving manager rebuilds a working cluster. | The disaster-recovery procedure. Do it once so it is not novel when it matters. |
| 8 | Back up and restore `/var/lib/docker/swarm` | What is actually in the Raft store; restoring onto a rebuilt node. | The only real backup Swarm has. |
| 9 | Push a changed image to the **same `:latest` tag**, then redeploy | Whether the service picks it up; compare `docker service inspect`'s stored `…@sha256:…` before and after. | Services hold a **digest**, not a tag. Explains "I deployed the fix and it is still broken", and why immutable tags beat `:latest` in a real pipeline. |
| 10 | Rotate a `docker secret` | Secrets are immutable — you create a new one and update the service to point at it. | Credential rotation is a *deployment*, not an edit. Ties Part 3's secrets work to something operational. |

⚠️ **The honest caveat, to be stated in the chapter** (same as the 3-brokers-in-one-VM caveat in
Phase 14): three VMs on one physical host simulates **node** failure, not **host** failure. Killing a
VM is a genuine Raft event and every drill above is real — but losing the Z6 loses all three, and
nothing here proves otherwise.

---

## Part 7 — Swarm vs Kubernetes crib sheet

Written last, from experience rather than from docs. At minimum:

- Service ↔ Deployment; task ↔ Pod; `docker service scale` ↔ `kubectl scale`.
- Routing mesh ↔ Service/kube-proxy — and how they differ.
- **No PVC equivalent** (Part 5), no namespaces in the k8s sense, no CRDs, no operators.
- Raft in the manager set ↔ etcd in the control plane; quorum arithmetic is identical.
- `depends_on` ignored ↔ init containers / readiness gates.
- **`docker secret` ↔ Secret, `docker config` ↔ ConfigMap** — and the difference that matters: a Swarm
  secret is **immutable**, so rotation means creating a new object and updating the service, where a
  Kubernetes Secret can be edited in place and re-mounted. Say which you prefer and why.
- **Image handling:** Swarm pins a **digest** into the service spec at deploy time; Kubernetes keeps
  the tag in the manifest and leaves resolution to the kubelet's pull policy.
- Where Swarm's simplicity is a genuine advantage, and where it is a ceiling.
- One honest paragraph: which would you pick for Capricorn, and why.

---

## Suggested schedule

Reweighted DevOps-first: the build-and-ship half gets three sessions, the drills get two.

| Session | Work |
|---|---|
| 1 | Parts 1–2: three VMs (scripted), cluster formed, snapshots. Chapter 1 draft. |
| 2 | Part 3: stack file, `deploy_swarm.sh` by hand, routing mesh, the registry-auth gotcha. Chapter 2. |
| 3 | Part 4: runner check, `workflow: rules:`, deploy token, the manual job. Chapter 3. |
| 4 | Part 5 + drills 1–3. Chapter 4. |
| 5 | Drills 4–10 (the empty-volume demo, the `:latest` digest surprise, secret rotation), Part 7 crib sheet. Chapter 5. |

---

## Teardown / rollback

Cheap by design. `qm stop 191 192 193 && qm destroy 191 192 193` reclaims 12 GB, 6 vCPU and 120 GB.
Nothing else in the lab depends on these nodes — provided Part 4 stayed in this repo, which is
exactly why that decision was made. ⚠️ Delete the snapshots too; stale ZFS snapshots cost space and
were flagged in the Phase 13 audit. Also remove this repo's `.gitlab-ci.yml` (or its `workflow`
rules) if the lab cluster goes away, so pushes do not fail against missing hosts.

---

## Out of scope (deliberately)

- **Jenkins.** The employer uses it and we may build it later — a natural **Phase 17**, made cheaper
  by Part 3's portable script. Not in this phase; adding a second unfamiliar system while learning
  Swarm would blur which one broke.
- **Swarm on VM 200 (`.180`).** It is the live auto-deploy target for Capricorn QA on every `develop`
  push, and `swarm init` would add `ingress` + `docker_gwbridge` networks and reserve ports on a host
  that already runs containers. Rejected on Aug 12.
- **Swarm on the runner (`.182`).** Live CI infrastructure.
- **Reusing VMID 185.** Reusable, but it carries stale firewall/Tailscale/backup-name baggage; a clean
  contiguous block is worth more than a saved VMID.
- **Traefik / TLS in front of the Swarm.** The routing mesh plus a published port is enough to learn
  from. Capricorn PROD's Traefik on `.184` stays untouched.
- **Changing how Capricorn is built, or its repository.** This phase consumes the existing images and
  writes its own stack file; it does not touch the build, the scan, the app's source, or its CI.
- **Restoring PROD data into the lab.** Fresh empty database only (Part 5).

---

## Decisions (settled with Andrew, Aug 12, 2026)

| # | Question | Decision |
|---|---|---|
| **O1** | Is Docker Swarm actually in the employer's stack? | ✅ **Yes — confirmed.** Their platform is **GitHub + Jenkins + Docker Swarm**. The role is **DevOps/SRE, DevOps first**, and Andrew has already accepted it. Consequence: this phase is worth the ~5 sessions, and Part 4 is written to be **Jenkins-portable**. |
| **O2** | Where may the `deploy_swarm` job live? | ✅ **A new `.gitlab-ci.yml` in this repo** (`production/home-lab-setup`), manual job only. Verified Aug 12 that this repo is a GitLab project with **no CI file today**. Capricorn's pipeline is untouched. |
| **O3** | Does Capricorn have a database or writable state? | ✅ **Yes.** Verified on the live `.184` stack: **postgres + redis**, named volumes `postgres_data_prod` / `redis_data_prod`, plus a bind mount for DB init scripts. Part 5 becomes a real exercise, and drill 6 (silent empty-volume data loss) exists because of it. |
| **O4** | 3 managers, or 2 managers + 1 worker? | ✅ **3 managers**, then `docker node demote` one as an exercise. 2 managers is never a shape worth building. |
| **O5** | Track name? | ✅ **`education/docker-swarm/`**, chapters restart at 01 per `education/CONVENTIONS.md`. |
| **O6** | Lab postgres data? | ✅ **Fresh and empty** from the init scripts. No PROD dump, separate volume names, hard isolation from `.184`. |

**What is still open is *not* in this table — it is in the pre-flight list at the top of this file.**
As of Aug 12, ~7:00 PM that comes to **exactly two one-minute decisions for Andrew** (A2: does this
repo gain a `.gitlab-ci.yml`; A5: where the stack file and deploy script live) plus **A3, which is
deferred into Part 5 on purpose** because choosing the storage approach and writing up what it cost is
the deliverable. A1 and A4 were closed by verification rather than by asking.

---

## Implementation log

### Part 1 — three VMs from template 9000 ✅ COMPLETE (August 13, 2026, 12:12–12:26 PM EDT)

**Result: `docker-swarm-1/2/3` at `.191/.192/.193` are up, personalized, Docker 29.7.2 running,
Swarm `inactive`, snapshotted `s01-base-clean`. Nothing was surprising, and the one thing the plan
warned loudest about (`growpart`) worked.**

**Pre-flight decisions taken at the start of the session:**

| Item | Decision |
|---|---|
| A2 — does this repo gain a `.gitlab-ci.yml`? | ⏸️ **DEFERRED to Part 4 (session 3).** Not needed to build, and the `workflow: rules:` guard question rides along with it. |
| A5 — where do the stack file and deploy script live? | ✅ **`education/docker-swarm/{manifests,scripts}/`**, as planned. A track stays self-contained per `education/CONVENTIONS.md`. This sets the pattern later tracks copy. |

⚠️ **Unrelated finding, handled before any build work: `education/fin_tech_stack.txt` was untracked,
not covered by any `.gitignore` rule, and — in its first draft — identifying.** It named an employer,
a start date and who suggested the study list. It carries no credential, so **`push_github.sh`'s gates
would not have stopped it** reaching the public remote. The first fix was to gitignore it; the fix
that stuck was to **de-identify the content and track it normally**, since the facts had already been
copied into `MEMORY.md` and `current_phase.md`, which are tracked and public.
**Generalisable lesson: the push gates protect against *secrets*, not against *private* — and
ignoring a file does nothing about text you already copied out of it.**

#### What was actually run

Both scripts are idempotent and live in `education/docker-swarm/scripts/`.

| Script | Runs on | Does |
|---|---|---|
| `provision_nodes.sh` | Proxmox host `.150` as root | clone → set cores/memory/onboot/IP → resize → start |
| `post_setup.sh` | each node as `agamache` | purge Chrome + Cursor (B5), mask update timers (B4) |

**Verified free before cloning:** VMIDs 191/192/193 had no `/etc/pve/qemu-server/<id>.conf`, and
`192.168.1.191/192/193` returned no ping. Template 9000's disk read **3584M**, confirming the plan.

**Clone + start:** 38 seconds for all three full clones (3.5 GiB each, `vm-ephemeral`). Host had
51 GB RAM free and the pool 1.39 TB available, so the 12 GB / 6 vCPU / 120 GB cost landed without
pressure.

**Personalization:** `host_setup.sh` + `smb_credentials` fetched from `http://192.168.1.195/scripts/`,
run on all three **in parallel** — 3 minutes wall clock for all three rather than ~9 sequentially.

#### Findings worth keeping

- ✅ **`growpart` ran.** This was the plan's loudest Part 1 warning and it turned out fine:
  `df -h /` reads **38G used 2.2G** on all three, not 3.5 GB. ⚠️ **Note it reads 38G, not 40G** — the
  40 GB virtual disk also carries `sda15` (106M EFI) and `sda16` (913M `/boot`). **38G is the correct
  and expected number; do not go looking for the missing 2 GB.**
- ⚠️ **B5 was necessary, and for a reason the plan did not state.** `host_setup.sh` only runs
  `setup_desktop.sh` if it detects `gnome-shell` **or `gsettings`** — and the Ubuntu 24.04 cloud image
  ships `gsettings`. So the desktop branch fires on a headless node, and the log says
  "Desktop environment detected". Chrome 151 + Cursor 3.15.19 were installed on all three.
  **Purging them took each node from 4.4 GB used to 2.2 GB — exactly the ~1.8 GB the plan predicted.**
- ✅ **B4 needed no edit to `refresh.sh`.** That script targets an **explicit allow-list**
  (`.180`–`.184`), not "all VMs", so the swarm nodes are excluded by construction — same as VM 186.
  The guest half was still required: `unattended-upgrades.service`, `apt-daily.timer` and
  `apt-daily-upgrade.timer` are **masked** (not merely disabled) on all three.
- ✅ **No backup job sweeps them in.** `/etc/pve/jobs.cfg` holds one job, `gitlab-nightly`, scoped to
  `vmid 181`. Consistent with the "backups: none, snapshots instead" rule for rebuildable VMs.
- ✅ **The registry config came for free from the standard script**, which was the entire argument for
  using it. `/etc/docker/daemon.json` on all three reads
  `{"insecure-registries": ["gitlab.gothamtechnologies.com:5050"]}`, and
  `curl http://gitlab.gothamtechnologies.com:5050/v2/` from `.191` returns **401** — up, requiring
  auth, reachable from a node.
- ✅ **Nothing blocks the Swarm ports.** `/etc/pve/firewall/` holds only `184.fw`, `185.fw` and
  `cluster.fw`; there is **no `191.fw`/`192.fw`/`193.fw`**, so the guest firewall is off on all three
  despite `firewall=1` on the NIC. `2377`/`7946`/`4789` are unobstructed. Peers ping each other.
  ⚠️ **This is the state the "record the ports" note in Target Architecture was protecting** — if a
  `19x.fw` is ever added without those three rules, the cluster breaks silently.
- Versions as built: **Docker 29.7.2** (build a7dcaa6), **Docker Compose v5.4.0**, Ubuntu 24.04 LTS.
- Machine-ids are unique across the three (`69200ced…`, `6d47a820…`, `207eb761…`), so the template's
  `/etc/machine-id` truncation is still doing its job.
- `/mnt/DevShare` (NAS CIFS) is mounted on all three. Not needed yet; it becomes relevant if Part 5's
  A3 decision goes the NAS-volume way.

#### Snapshots

`s01-base-clean` taken on all three **together** (B3), **hot** — guest agent responded on all three,
`freeze guest filesystem` → snapshot → `thaw`, **~1.6 s each**, no VM stopped.

```
qm snapshot 191 s01-base-clean   # 1.635s
qm snapshot 192 s01-base-clean   # 1.566s
qm snapshot 193 s01-base-clean   # 1.599s
```

#### State at end of Part 1

| VMID | Name | IP | vCPU | RAM | Disk | Status | Swarm |
|---|---|---|---|---|---|---|---|
| 191 | `docker-swarm-1` | 192.168.1.191 | 2 | 4 GB | 40 GB (`vm-ephemeral`) | running, `onboot=1` | inactive |
| 192 | `docker-swarm-2` | 192.168.1.192 | 2 | 4 GB | 40 GB (`vm-ephemeral`) | running, `onboot=1` | inactive |
| 193 | `docker-swarm-3` | 192.168.1.193 | 2 | 4 GB | 40 GB (`vm-ephemeral`) | running, `onboot=1` | inactive |

#### ⚠️ Process note — Part 1 was AI-driven; Part 2 onward is NOT

**Andrew typed nothing during Part 1.** That was *consistent* with track 1, where the AI built the VM
and installed k3s (Parts 1–2) and Andrew drove from the Kubernetes object model onward — Part 1 here
was cloning from template 9000 and running `host_setup.sh`, both routine lab plumbing. But the
protocol had **never been written down**, which is why it needed re-deriving mid-phase.

🚨 **It is written down now: `education/METHOD.md` → "Who does the work".** From **Part 2 onward,
Andrew drives.** The loop is: AI says what and why → AI gives **one** command → Andrew runs it and
pastes the output → AI checks it and explains what it actually means. **When something breaks, Andrew
diagnoses first and the AI stays quiet** — which matters most for the seven planted traps, since
narrating the answer the moment one fires is the same mistake as pre-empting it. **Repetition:** Andrew
does the first node by hand, the AI does the other two.

---

### Part 2 — three-manager cluster ✅ COMPLETE (August 13, 2026, 1:33–1:53 PM EDT)

**Andrew drove this part.** He ran `swarm init` on `.191` and joined `.192` by hand; the AI joined
`.193` under the repetition rule and took the snapshots. Twenty minutes, no failures.

#### What was run

| Step | Where | Result |
|---|---|---|
| `docker swarm init --advertise-addr 192.168.1.191` | `.191` | node `pmpvb2i3…` is manager + **Leader** |
| `docker swarm join --token <manager> 192.168.1.191:2377` | `.192` | `fjk3zysr…` **Reachable** |
| same | `.193` | `g9lrfdrr…` **Reachable** |
| `qm snapshot 19{1,2,3} s02-swarm-up` | host `.150` | hot, all three together, ~3 s each |

**End state:** 3 managers / 3 nodes, `ClusterID n6waq5uhc7o6yxzt5tyzrbol9`, quorum **2 of 3**, ingress
overlay `10.0.0.0/24`, no services deployed.

#### Findings worth keeping

- ⭐ **The join token's two halves are mutual authentication pointing in opposite directions.** Format
  is `SWMTKN-1-<head>-<tail>`. **The tail is per-ROLE, not per-node** — proved by
  `docker swarm join-token --rotate worker`, which changed the worker tail
  (`38pe0btm…` → `8ln2dxbr…`) and left the manager tail `cr5jpjsv…` untouched. **Operational
  consequence: there is no per-node revocation.** A leak can only be answered by rotating the whole
  role, and already-joined nodes are unaffected because they stop using the token once they hold a
  certificate.
- ⭐ **The head is NOT the swarm ID.** Andrew's hypothesis, and a reasonable one — killed by evidence
  that arrived sideways: `ClusterID` is `n6waq5uhc7o6yxzt5tyzrbol9`, which appears **nowhere in the
  token**. Length is corroborating: cluster and node IDs are 25 base36 chars, the token head is 50 —
  right for a 256-bit hash, wrong for another ID. It is the root CA cert hash, and it is how the
  *joiner* verifies the *cluster*. ⚠️ **Note honestly that the rotation test did NOT prove this** —
  both hypotheses predicted "unchanged". `docker swarm ca --rotate` is the test that separates them;
  deferred to a chapter 5 drill (see below).
- ⚠️ **The printed join command is the WORKER token.** `swarm init` prints it unprompted and only
  *mentions* `docker swarm join-token manager` in prose. Pasting what it hands you produces a
  **1-manager / 2-worker cluster that looks perfectly healthy** and quietly removes every quorum
  lesson in the phase. A wrong token here is not an error, it is a subtly wrong cluster.
- **Two managers is strictly worse than one.** Quorum is `floor(N/2)+1`: N=1→1, **N=2→2**, N=3→2,
  N=4→3. The two-manager state tolerates *zero* failures. Worth naming in the chapter because
  "add a second manager for redundancy" is exactly how people land there.
- **`MANAGER STATUS` and `STATUS` are different questions.** `Ready` is the engine's ability to run
  tasks; `Leader`/`Reachable`/`Unavailable` is Raft. A node can be `Ready` and `Unavailable`
  simultaneously — knowing which column went bad is most of the diagnosis.
- **Every manager is a full API endpoint.** `docker node ls` from `.192` returned the whole cluster;
  the command *fails* on a worker (`This node is not a swarm manager`), which makes it a free
  role check after a join.
- **`Node Address` was auto-detected correctly** (`192.168.1.192`) because these VMs are single-NIC.
  That is the case where omitting `--advertise-addr` is safe; the risk is multi-homed hosts.
- ⚠️ **`Default Address Pool` is not printed by `docker info`** unless explicitly configured — but it
  is real. `docker network inspect ingress` returns **`10.0.0.0/24`**, the first `/24` out of the
  invisible `10.0.0.0/8` default. **A silent collision risk on any corporate `10.x` network.**
- ⚠️ **`Autolock Managers: false`** — the Raft log encryption key sits on disk in the clear on every
  manager. Fine for a lab, but Part 3 puts Capricorn's DB password into `docker secret`, so
  **these VM snapshots will contain recoverable secrets.**
- 🚨 **`CA Configuration: Expiry Duration: 3 months`, and this lab takes snapshots.** Certificates
  rotate automatically *while the cluster runs*. **Restore a snapshot older than three months and the
  certs expired while frozen** — it will present as a networking fault and will not be one. Recorded
  in the `s02-swarm-up` snapshot description so a future restore sees it.

#### Process finding — do not paste `ssh` and commands as one block

The AI handed over a block with `ssh …` on line 1 and commands beneath. Those later lines go into the
terminal's **input buffer** while `ssh` is still starting, and whatever reads stdin next consumes
them — here, a password prompt ate the join token line. Harmless this time; feeding a manager token to
a password prompt is not a habit to keep. **Fixed going forward: give `ssh` alone and wait, or write
`ssh host "command"` explicitly.** (The visible `already part of a swarm` error was a *second*,
redundant join attempt — the first had succeeded. Docker refusing there is correct: joining another
swarm means abandoning this one.)

🚨 **IT HAPPENED AGAIN on Aug 13 at 6:20 PM, worse, and the AI caused it again.** The C2 handoff put
`ssh 192.168.1.191` and `cd ~/DevShare/…/scripts` in one pasted block. The `ssh` had not connected
before the rest was consumed, so **`./deploy_swarm.sh` ran on the workstation `VM-UBUNTU-01`.**

⭐ **The new twist is the dangerous part: `cd` SUCCEEDED on the wrong host.** `~/DevShare` is the same
CIFS mount from `192.168.1.120` on both machines, so the path exists identically in both places and
**gave no error, no missing directory, nothing to notice.** The shell prompt was the only difference,
and a pasted multi-line block scrolls it out of view. **A shared network mount removes the usual
signal that you are on the wrong machine.**

✅ **What saved it was the script's own pre-flight** — `docker node ls || die "not a swarm manager"` —
which fired three times across two hosts. It was written as a cheap "am I in the right place" check
and it turned out to be the thing standing between a mispaste and a confusing deploy. **A guard that
names the *precondition* rather than the symptom pays for itself the first time somebody is somewhere
they did not expect to be.** The same paste also ran `docker secret create` on the workstation, where
it failed for the same reason — and *that* is why the `pg_password` guard (P1) still has not been
tested: a different guard kept catching the run first.

**Standing rule, now twice-earned: never hand over `ssh` and commands in one block.** Either `ssh`
alone and wait for the prompt, or `ssh host "cmd"` as a single quoted invocation.

#### Added to the drill list

| # | Drill | Why here |
|---|---|---|
| **New** | `docker swarm ca --rotate` on the live three-manager cluster. | Settles the token-head question by evidence — if it is a CA hash, **both** tokens' heads must change. Doubles as a real certificate-rotation exercise across three managers, which is the SRE-relevant version. Deliberately **not** run at 1 node, where it was trivial and taught nothing. |

---

### Part 3 — Capricorn deployed across three nodes ✅ COMPLETE (August 13, 2026, 2:20–4:12 PM EDT)

**Result:** `backend` 2/2, `frontend` 3/3, `postgres` 1/1, `redis` 1/1. UI renders at
`http://192.168.1.191:5001`; the API answers on `:5002` from **all three** nodes, including nodes
running no backend task. Capricorn's own repository was never modified (hard rule B7 held).

**Artefacts written — both live in `home-lab-setup`, not in Capricorn:**

| File | Role |
|---|---|
| `education/docker-swarm/manifests/capricorn.stack.yml` | The stack. Modelled on Capricorn's **QA** deployment, the variant that serves plain HTTP with no proxy — the closest analogue to this lab. |
| `education/docker-swarm/scripts/deploy_swarm.sh` | Login → deploy → **wait for convergence** → report digests. Part 4 adds no deploy logic; it only arranges for a runner to call this file. |

#### The command sequence that actually worked

```bash
# 1. the secret must exist first - the stack declares it external, so deploy fails without it
printf '<lab-only-password>' | docker secret create pg_password -

# 2. registry credential, on the manager you deploy from
docker login gitlab.gothamtechnologies.com:5050 -u swarm-lab-pull      # interactive, masked

# 3. deploy - the flag is NOT optional against a private registry
docker stack deploy -c capricorn.stack.yml --with-registry-auth capricorn
```

#### 🚨 Trap C1 fired — and our first explanation of it was WRONG

Deploying without `--with-registry-auth` produced `access forbidden` and services stuck at 0
replicas. The intuitive reading — *"the manager has credentials, the workers don't"* — is **false**,
and `docker stack ps` disproved it:

- **`frontend` was Rejected on all three nodes, `docker-swarm-1` included** — the very node whose
  `~/.docker/config.json` holds a working credential, and where `docker pull` succeeds by hand.
- ⭐ **A node's daemon does not read the CLI's `config.json` when it runs a task.** Only the *client*
  does. The agent authenticates **solely** with the credential frozen into the service spec, which is
  what `--with-registry-auth` puts there. **A manager is no more privileged than a worker at pull
  time.** Being able to pull an image by hand on a host tells you nothing about whether a task can.
- ⭐ **`postgres` and `backend` only *appeared* to work on `.191` because those images were already in
  that node's local image cache**, from `docker pull` commands we ran while investigating. **A task
  whose image is already local never contacts the registry, so it cannot be refused.** `frontend` had
  never been pulled by hand, so it failed honestly — and looked like the *only* broken service.
  🚨 **Our own debugging manufactured the asymmetry that made the failure hard to read.**
- ⭐ **Exactly three `Rejected` rows per task slot** = `restart_policy.max_attempts: 3` being consumed.
  After the third refusal **Swarm stops trying, permanently.** That is why the false green was stable
  rather than transient: `deploy` had already exited 0, the retries quietly exhausted themselves, and
  the service sat at zero replicas indefinitely with no error surfaced anywhere you would look.

⚠️ **Delayed-failure mode, recorded as a claim to test:** the credential is stored **in the service
spec in the Raft log**, so it is a *latch*, not a live lookup. When the token expires (Dec 31 2026),
tasks rescheduled **after** that date should fail to pull while nothing has changed and every config
file still reads correctly. Redeploying refreshes it. **Not yet verified — do not teach as fact.**

#### The blast radius of a deploy is not "everything" — and not "nothing"

Re-deploying with the flag added recreated `backend`, `frontend` and `postgres` but **left `redis`
untouched** (its task ran 30 minutes across two later deploys, with no shutdown row at all).

⭐ `--with-registry-auth` attaches a credential **only for images whose registry needs one**, so it
changed the spec of the three services on the private registry and did nothing to
`redis:7.2.4-alpine` from Docker Hub. **`postgres` was working correctly and got bounced anyway,
purely because it shares a registry with the services that were broken.** Nothing in the command you
type tells you which services are in scope. A third run with an unchanged file recreated **nothing**,
which is the declarative behaviour working as intended.

#### Convergence — the part a naive deploy job omits

- `docker stack deploy` exits **0 as soon as the manager ACCEPTS the desired state**, not when
  anything runs — and possibly forever before, if the image cannot be pulled. This is the entire
  reason `deploy_swarm.sh` polls.
- 🚨 **Replica count alone is not a sufficient test, and the first version of our script got this
  wrong.** Three services use `order: start-first`, which starts the replacement before retiring the
  old task, so running/desired can read `3/3` *continuously* through a full rolling replacement.
- 🚨 **Worse: `failure_action: rollback` restores the previous version and the service settles back at
  full replicas.** A count-only check calls that a **success**. It is the opposite — the new code was
  rejected. **The most misleading green a deploy job can produce**, and every one of the three
  services is configured to do it. The script now treats `UpdateStatus.State` of `rollback_started` or
  `rollback_completed` as a hard failure. (The field is empty on a never-updated service, so empty is
  healthy.) ⚠️ **Untested claim, in the script as a `UNVERIFIED` comment:** `UpdateStatus` looks like a
  latch that persists until the next update begins, so a stale `rollback_completed` could fail a
  healthy cluster. **To be falsified during C6.**
- **Digests, not tags.** Swarm resolves each tag to a digest when it accepts the spec and stores
  *that*, so services do not follow a moving tag the way `docker compose pull` does. Even the pinned
  `redis:7.2.4-alpine` recorded `sha256:c8bb255c…`. **The digest is the only honest answer to "what is
  running"** — and the setup for trap C7.

#### Configuration findings that shaped the stack file

- ⭐ **A published port was not a free choice.** `frontend/src/config/api.ts` resolves the API base **in
  the browser at runtime**: HTTPS → same origin; **HTTP → `http://<hostname>:5002`**. The image sets
  only `VITE_BUILD_NUMBER`, so no `VITE_API_URL` was baked in and the HTTP branch applies. Publishing
  the backend anywhere but `5002` silently breaks every API call **in the UI only** — `curl` against
  the backend keeps working, so the failure would look like a frontend bug.
  🚨 **General lesson: `VITE_*` variables are substituted at BUILD time.** Setting one in a compose
  file, a `.env`, or a service spec does nothing whatsoever — the value is already inside the bundle.
  **The image dictated our network topology, not the reverse.**
- ⭐ **`docker secret` delivers a FILE; the application wanted a URL.** Secrets appear as
  `/run/secrets/<name>`, but the backend reads a single `DATABASE_URL` with the password embedded.
  Resolved by composing it at container start:
  `sh -c 'export DATABASE_URL="postgresql://…:$$(cat /run/secrets/pg_password)@postgres:5432/…"; exec uvicorn …'`
  — `$$` because Compose interpolates `$`, and **`exec` so uvicorn becomes PID 1** and receives
  `SIGTERM` on update. Without `exec`, the shell holds PID 1, swallows the signal, and every rolling
  update degrades into a 10-second timeout followed by `SIGKILL`.
  **This gap between "secret as file" and "config as string" is generic** — it recurs with every
  secrets manager and is where teams give up and use a plain environment variable.
- **Postgres:** the custom image uses the official entrypoint, so `POSTGRES_PASSWORD_FILE` works — but
  it is **mutually exclusive** with `POSTGRES_PASSWORD`, which is baked into the image (finding D5).
  Setting `POSTGRES_PASSWORD: ""` explicitly is what makes the `_FILE` path win.
- **`depends_on` is silently ignored by Swarm.** Kept out of the stack file rather than left in to rot.
  Trap C2 covers what the app does about it.

#### ⚠️ Trap C2 was contaminated before it ran

The manual `docker pull` commands used to diagnose C1 also pre-warmed the postgres image, so postgres
started fast and the backend never met a cold database. **A methodological finding, now recorded in
`education/METHOD.md`: investigative commands mutate the environment, and a trap tested afterwards may
be testing the investigation instead.** C2 needs a snapshot restore to run honestly.

#### C2 re-run — predictions recorded BEFORE the drill (Aug 13, 2026, 6:05 PM)

`s03-stack-deployed` was taken first (hot, all three, ~1.5 s each), then all three nodes were rolled
back to `s02-swarm-up`. **That snapshot predates `docker login`, the `pg_password` secret, AND the
diagnostic `docker pull` commands**, so the restore buys a genuinely cold cluster and lets one restore
test four things instead of one.

⭐ **Writing the prediction down first is the point.** A drill you can only interpret after the fact
teaches you that Swarm is complicated. A drill with a prediction attached either confirms a model or
falsifies it, and both are worth something. These are claims, not facts — **whichever way they land,
the outcome gets recorded next to them.**

| # | Prediction | Why | Outcome |
|---|---|---|---|
| P1 | `deploy_swarm.sh` **refuses before touching the cluster**, naming `pg_password`. | The secret died with the rollback and the pre-flight guard has never actually fired. | ⚠️ **STILL NOT TESTED** — the run landed on the workstation, so the *manager* guard fired first (see below). The secret guard remains unexercised. |
| P2 | With `REG_TOKEN`/`REG_USER` the login branch runs and the deploy proceeds. | `config.json` is gone too, so this is the first real test of the path **CI will take**. | ✅ **CONFIRMED.** `logging in … → login ok`, and the `credentials are stored unencrypted` warning reappeared — fresh evidence for L9. |
| P3 | 🎯 **The deploy does NOT converge, and `backend` is the service that fails** — not postgres. | `restart_policy` gives backend one start plus `max_attempts: 3` at `delay: 5s` ≈ **20 s of patience**, while a cold postgres must pull its image *and* run `initdb` on an empty volume. There is **no healthcheck** (deliberate, for C6) so nothing makes backend wait. | ❌ **FALSIFIED.** Converged in ~20 s, `EXIT=0`, and `docker service ps` shows **zero failed tasks** on either service. Reasoning below. |
| P4 | The failure is **visible only on a cold cluster**. Re-running the same script immediately afterwards succeeds, unchanged. | Second run: images cached, postgres already initialised, volume populated. | ⚪ **MOOT** — there was no cold failure to contrast against. |

**If P3 and P4 both hold, the lesson is much bigger than `depends_on`:** this stack has a deploy that
passes on every warm cluster and fails on a fresh one, which is exactly the shape of the outage that
hits during a **DR rebuild or a brand-new environment** — the two moments when nobody wants a surprise.
The compose file looks identical in both cases.

**Ways P3 could be wrong, all of them informative:** the backend may retry its database connection
internally and never exit (then the app is the grown-up here and `depends_on` was never needed); or
postgres may come up fast enough that 20 s is sufficient; or an exhausted `max_attempts` may cause
Swarm to schedule a *replacement* task with a fresh attempt counter, in which case the service
eventually converges anyway and **`max_attempts` does not mean what the stack file makes it look like.**
That last one is worth the drill on its own.

**What the restore actually cost — the plan did not survive contact.** Three things went differently
than written, and all three are recorded because they are the kind of thing that only shows up when you
try it:

1. 🚨 **`qm rollback 191 s02-swarm-up` REFUSED on all three nodes** — ZFS only rolls back to the newest
   snapshot, so reaching `s02` required **destroying `s03`**. Full analysis under
   [Snapshot checkpoints](#-on-zfs-snapshots-are-a-stack-not-a-tree--learned-the-hard-way-aug-13-2026).
   **You cannot keep a checkpoint and go back past it.**
2. **So a real backup was taken first** — `vzdump 191 192 193 --storage local --mode stop --compress zstd`,
   with the VMs already stopped, so no `fsfreeze` guesswork: **~1.2 GB per archive, ~36 s each, 91% of
   each 40 GB disk was zero.** Verified with `zstd -t` (which proves the *stream* is intact, **not** that
   the VMA restores — only a test restore to a spare VMID proves that, and that is still owed).
   ⚠️ Deliberately **not** sent to `nas-gitlab`: despite appearing as a generic backup target in
   `pvesm status --content backup`, it is scoped to `subdir /ProxmoxBackups/vm-gitlab-1` and holds a
   nightly chain for **VM 181 only** — three foreign VMs in a per-VM folder would collide with whatever
   retention prunes it. `local` is a different pool (`rpool1`) but the **same host**, which is honest
   protection against this drill and against a `vm-ephemeral` fault, and none at all against losing the Z6.
3. ✅ **`qm shutdown` was graceful all the way down.** The service logs caught postgres printing
   `received fast shutdown request` → `aborting any active transactions`, so ACPI reached systemd
   reached docker reached a real `SIGTERM`. **`qm stop` would have been a power cut**, and a torn Raft
   log is not the drill we meant to run.

#### 🎯 C2 RESULT — the trap did not fire, and WHY is the whole lesson

**Timings, from `docker service logs --timestamps` (all 2026-08-13, UTC):**

| Event | Time | Δ from postgres ready |
|---|---|---|
| postgres `initdb` running | 22:27:27.078 | −0.08 s |
| **postgres `database system is ready to accept connections`** | **22:27:27.162** | — |
| schema seeded (`001_schema.sql`, 12 categories) | 22:27:27.46 | +0.3 s |
| `backend.2` (docker-swarm-3) application startup | 22:27:33.75 | **+6.6 s** |
| `backend.1` (docker-swarm-1) application startup | 22:27:37.34 | **+10.2 s** |

⭐ **The backend never met a cold database, because postgres finished pulling AND running `initdb`
before the backend image finished pulling.** The backend started 6.6 s *after* the database was already
accepting connections. `docker service ps --no-trunc` confirms it: **not one failed task, no restart,
no `max_attempts` consumed.**

⚠️ **So the trap is real and this environment simply cannot express it.** Two accidents, neither of
them a design decision, are what made the deploy work:

1. **The registry is on the LAN.** Every image pulled in seconds. `frontend` (3 replicas) and `redis`
   were both up within ~5 s of a completely cold start.
2. **The backend image is bigger than the postgres image.** A fat Python dependency tree took longer to
   pull than postgres needed to pull *and* initialise. **The ordering that `depends_on` would have
   enforced was delivered by image size instead.**

🚨 **This is worse than a failure would have been, and that is the finding.** A dependency that is
satisfied by a race the fast side happens to win is **indistinguishable from a dependency that is
correctly declared** — until the day the race flips. It flips when postgres gets slower (a real data
directory to recover, a WAL replay, slower storage) or when the backend gets faster (its layers already
cached on the node while postgres's are not — **exactly what the C1 diagnostics accidentally arranged
the first time**). **Nothing in the stack file changes on that day, and nothing warns you.**

**The correct fix is not `depends_on`** — Swarm ignores it, which is what started this. It is either a
real healthcheck plus `update_config` ordering, or connection retry in the application. **The lesson
Andrew asked C2 to buy — "does the app retry or crash-loop?" — is still unanswered**, and it is
unanswerable by observation here because the question never got put to the app.
🔲 **To force it honestly later:** scale postgres to 0, deploy backend alone, then bring postgres up.
That removes the race instead of hoping to lose it.

#### ⭐ The unplanned finding, and it is better than the planned one: 8 processes racing to seed one DB

`backend.2` logged this three times while starting:

```
Failed to import demo data, using minimal bootstrap: (sqlalchemy...IntegrityError)
  <class 'asyncpg.exceptions.UniqueViolationError'>: duplicate key value violates
  unique constraint "categories_pkey"
```

**`INFO: Waiting for application startup.` appears FOUR times per task** — because the command is
`uvicorn --workers 4`. So `replicas: 2` × `4 workers` = **8 independent processes, each running the
app's startup path, each trying to seed the same database at the same time.**

⭐ **`replicas` is not the concurrency number.** The stack file says 2; the number of processes racing
to initialise shared state is 8. **Anything an application does "once at startup" happens N×workers
times, in parallel, against one database** — and only the first one succeeds.

The app degrades gracefully rather than crashing (`using minimal bootstrap`), which sounds fine and is
the trap: **an import that failed was converted into a success message.**

❌ **CORRECTION (Aug 18) — the first version of this note was wrong, and the error is worth keeping
visible.** It claimed the two replicas "hold different data", one with demo data and one with a minimal
bootstrap, so the answer would depend on which replica you reached. **That cannot happen: both replicas
share one postgres database.** Per-replica divergence would require the app to cache state in-process,
which is unproven and was never checked. ⭐ **The mistake was reasoning about a stateless service as if
the failure it logged were local to it** — the failure was in *shared* state, which is a different
problem with a different blast radius.

**What the evidence actually supports**, re-measured Aug 18 with the same deploy still running:

| Claim | Status |
|---|---|
| 8 processes (`2 replicas × 4 workers`) each run the startup path | ✅ four `Waiting for application startup` per task |
| At least one import lost a race and violated `categories_pkey` | ✅ logged three times |
| The app caught it and reported `using minimal bootstrap` | ✅ |
| The database ended up populated | ✅ `/api/v1/data/summary` → 51 categories, 611 transactions, 4 accounts, 3 portfolios |
| Data was lost or left partial by the race | ❓ **unproven — this is what drill C is for** |

⚠️ **So the honest risk is not divergent replicas, it is a shared database whose final contents were
decided by a race, with the losing writer's failure downgraded to an informational log line.** The
population above looks complete, which is exactly why nobody would look — **a partial import would
present identically**, because the only signal is a caught exception the app chose not to treat as
fatal.

⚠️ **Not yet settled, and the logs cannot settle it:** whether the collision is worker-vs-worker or
worker-vs-`001_schema.sql` (which seeds 12 categories of its own, 0.3 s earlier). Only `backend.2`
logged the error; `backend.1`, starting 3.6 s later, logged none — consistent with *either* "the race
was already over" or "it took a different code path". 🔲 **Discriminator for later:**
`docker service scale capricorn_backend=1` with `--workers 1`, deploy against a fresh volume, and see
whether the violation still appears. If it does, the app collides with the schema seed and **replica
count was never the cause.**

**Cold state verified before starting — the discipline that C2's contamination taught.** After boot:
3 × `Ready`, `.191` still `Leader` with the same node ID (Raft restored consistently across all three),
`docker service ls` empty, `docker secret ls` empty, **no `~/.docker/config.json`**, and
`docker images` carrying **no Capricorn or redis layers**. ⭐ **The starting state is now a measured
fact rather than an assumption, which is the entire difference between this run and the first one.**

#### Security findings from the QA deployment — recorded as D4/D5, not fixed here

Reading Capricorn's QA compose to model this stack surfaced committed live third-party credentials and
a database password baked into an image layer. **The temporary clone was deleted; no values were
copied into this repo (rule B7).** Per Andrew's Aug 13 direction, the chapter carries only the two
generalisable lessons — *credentials in an image layer cannot be removed by editing a file*, and *a
non-production environment pointed at production third-party credentials* — and **none** of the
specifics. Detail stays in D4/D5 above as the working record.

---

## 🧪 Aug 18, 2026 — the three drills the C2 re-run left owed

Andrew returned after studying the printed chapters. Cluster verified untouched first: **no reboots
(4 d 23 h uptime)**, 3 × Ready with `.191` Leader, all four services at full replicas, 200 from all
three nodes. `s03-stack-deployed` is the **newest** snapshot, so it is genuinely rollback-able — which
is the safety net for everything below.

### Baseline established first — separating "up" from "working"

You cannot detect *healthy but broken* without an endpoint that touches the database. `/openapi.json`
is disabled (`DEBUG=false`), so the route table came from inside the container:

```bash
docker exec $(docker ps -q -f name=capricorn_backend | head -1) \
  python -c "from app.main import app; [print(p) for p in sorted(app.openapi()['paths'])]"
```

🚨 **The app has TWO health endpoints and they mean completely different things:**

| Endpoint | With postgres UP | Touches DB? |
|---|---|---|
| `/health` | `{"status":"healthy","service":"capricorn-api"}` | ❌ **No — a static string** |
| `/api/v1/banking/health` | `{"status":"healthy","module":"banking",…}` | ❌ reports *sub-module* readiness, not the DB |
| `/api/v1/banking/categories` | `{"success":true,"data":[…51 categories…]}` | ✅ |
| `/api/v1/data/summary` | 51 categories, 611 transactions, 4 accounts, 3 portfolios | ✅ |

⭐ **This is the healthcheck lesson before we even run a drill.** A `healthcheck:` block pointed at
`/health` would pass forever with the database on fire, and it would *look* like diligent engineering
in the stack file. **The endpoint named "health" is the one that proves the least.** Whoever adds
healthchecks after trap C6 must point them at something that fails when a dependency fails.

### Drill A — force C2 honestly. Predictions BEFORE running

C2 never fired because the backend won a race with postgres. **Removing the race instead of hoping to
lose it:** scale postgres to 0, then recycle the backend so it starts with no database at all.

| # | Prediction | Reasoning | Outcome |
|---|---|---|---|
| P5 | 🎯 **The backend starts SUCCESSFULLY with no database** — task `Running`, `Application startup complete` — rather than crash-looping. | Proven on Aug 13 that the app **catches** database exceptions during startup and continues (`Failed to import demo data, using minimal bootstrap`). If that handler also covers a connection failure, startup completes. | ✅ **CONFIRMED.** Both tasks `Running 36 seconds ago`, no `Failed`, no `Shutdown`. |
| P6 | **`max_attempts: 3` is never consumed and `docker service ps` stays clean**, so Swarm reports the service fully converged and healthy. | Nothing exits, so there is nothing to restart. **A deploy in this state would report green.** | ✅ **CONFIRMED.** `docker stack services` → `capricorn_backend 2/2` with `capricorn_postgres 0/0` right beside it. |
| P7 | `/health` returns **200** while `/api/v1/banking/categories` returns **5xx**. | The discriminator. `/health` is a static string; the categories route needs the DB. | ✅ **CONFIRMED exactly.** `/health` 200, `/api/v1/banking/health` 200, `/api/v1/banking/categories` **500** `{"detail":"Internal server error"}`. |
| P8 | When postgres returns, the API recovers **without intervention**, but any startup-only work (the demo import) does **not** re-run. | A connection pool reconnects lazily per request; startup hooks do not fire again. **So it may come back "working" against an unseeded database.** | ✅ **CONFIRMED (first half).** No backend restart: `/api/v1/banking/categories` 200, `/api/v1/data/summary` 200 with **51 categories / 611 transactions / 682 rows** intact. Second half **untestable here** — the data already existed, so a skipped bootstrap is indistinguishable. Drill C tests it on a fresh volume. |

#### ⭐ Andrew's read of P8 — half right, and the wrong half is the instructive one

**His prediction before seeing the output:** *"When we re-scale PG I'm assuming we need to bounce the rest
of the app to get it to go through the reconnection attempts."*

**Reasonable, and wrong here — no bounce was needed.** What matters is *which* thing failed:

| Failed at startup | Recovered by itself? |
|---|---|
| The **bootstrap** (demo-data import) — a one-shot startup task | ❌ never re-runs |
| The **connection pool** — never actually established | ✅ SQLAlchemy opens connections **lazily, per request**, so the first request after postgres returned resolved DNS afresh and connected |

⭐ **The generalisable rule: a dependency reached lazily per request heals itself; a dependency consumed
once at startup does not.** Both live in the same process and the same log file, so "did the app
recover?" has two different answers depending on which one you mean — and bouncing the service to
"fix" the first would have been pointless work during an incident.

🚨 **And the trap the lab could not show: this only looked clean because the VOLUME survived.** On a
fresh volume the identical sequence leaves the schema present and the bootstrap never run, so the API
returns **200 with empty results** — worse than the 500, because every monitor goes green. *That* is the
state worth fearing, and it is what drill C is set up to find.

✅ **Also confirmed incidentally:** scale-to-0 on a **pinned** service is a clean shutdown, not data
loss. Postgres logged `database system was shut down at 21:44:20`, came back on `docker-swarm-1`
because of the placement constraint, and found its data. **This is the opposite of trap C3**, which
works only because redis is deliberately *not* pinned.

#### 🎓 Andrew's professional takeaway (Aug 18, 2026) — the reason this drill was worth running

> *"While containers may be running and ready it does not mean that the service, or application itself,
> is ready. We need to check, and likely write validation scripts to include in pipelines that will
> check that the application is 'ready for business' before assuming anything."*

⭐ **Correct, and the drill proved something sharper than the general principle: EVERY signal available
to the orchestrator agreed the deployment was fine.**

| Signal | Said | Reality |
|---|---|---|
| `docker service ps` | 2 tasks `Running`, no failures | no database |
| `docker stack services` | `capricorn_backend 2/2` | no database |
| `restart_policy` / `max_attempts` | never triggered | no database |
| `deploy_swarm.sh` convergence poll | ✅ would converge and print digests | no database |
| `/health` | `{"status":"healthy"}` | no database |
| `/api/v1/banking/health` | `{"status":"healthy","module":"banking"}` | no database |
| **`/api/v1/banking/categories`** | **500** | ✅ **the only honest signal in the system** |

🚨 **Six of seven checks passed, and the one that failed is the only one that touched the dependency.**
This is why "ready for business" cannot be inferred from orchestrator state at all — the orchestrator's
job ends at *the process is running*, and it does that job correctly. **Everything past that boundary is
the application's claim about itself, and this application's claim was false.**

🔲 **Action taken from this:** `deploy_swarm.sh` gets a post-convergence smoke gate that requests a
**dependency-exercising** endpoint and fails the deploy on anything but 200 — so Part 4's pipeline
inherits the check rather than reimplementing it. **Convergence answers "did Swarm do what I asked".
The smoke gate answers "does the thing work".** They are not the same question and this drill is the
proof.

#### 🎯 C2 ANSWERED — the app retries, gives up, and then reports success

**Andrew's original question was "does the app retry its DB connection or crash-loop?" The answer is a
third thing neither option covered:**

```
⏳ Waiting for database (attempt 7/15)...          <- ×4, one per uvicorn worker
⏳ Waiting for database (attempt 14/15)...
❌ Bootstrap failed after 15 attempts: [Errno -2] Name or service not known
INFO:     Application startup complete.           <- and then it starts anyway
```

⭐ **The application has a proper wait-for-database loop — 15 attempts — and someone clearly thought
about this dependency. The defect is the three lines after the loop.** Having exhausted its retries and
printed `❌`, it **falls through into normal startup** instead of exiting non-zero.

🚨 **One `sys.exit(1)` is the entire difference between a loud failure and a silent one.** Trace what
would happen if the process exited after exhausting its retries:

| With `sys.exit(1)` | What actually happens |
|---|---|
| Task exits non-zero → `restart_policy: on-failure` restarts it | Task stays `Running` forever |
| 3 restarts, then `max_attempts` exhausted → service stuck below desired | `2/2`, fully converged |
| `deploy_swarm.sh` convergence poll never satisfied → **times out and exits non-zero** | Script reports **green**, prints digests, exits 0 |
| CI job fails. Somebody looks. | CI passes. Traffic is routed to it. Every real request 500s. |

**The retry loop is what makes this dangerous rather than merely broken.** It handles the *transient*
case beautifully — postgres up to ~30 s late is completely absorbed — so the dependency looks solved,
and it is solved, for the case that happens in testing. **The terminal case degrades into a process
that lies.** Combined with the absent healthcheck (L13), nothing anywhere in the stack disagrees.

⚠️ **REFINES the Aug 13 conclusion, which was too strong.** That entry said the cold-start race would
"flip someday" and take the deploy down. It would not — the 15-attempt loop gives roughly **30 seconds
of cushion**, far more than the 6.6 s margin measured. **The real boundary is ~30 s, and crossing it
does not produce a crash — it produces a silently degraded service.** So the risk was misidentified: not
a fragile deploy, but a deploy that cannot fail in a way anyone would notice.

#### The failure presented as DNS, not as a refused connection

`[Errno -2] Name or service not known` — **not** `connection refused`. Scaling a service to 0 removes
it from Swarm's internal DNS entirely, so `postgres` stopped resolving rather than refusing.

⚠️ **Practical consequence for triage: grepping logs for `connection refused` or `could not connect to
server` would have found nothing here.** A dependency that has been scaled to zero, or whose stack was
never deployed, looks like a **name resolution** problem — which sends you to the network and the
overlay instead of to the missing service. **In Swarm, "does the name resolve?" and "is the service
up?" are the same question**, and the error message only tells you about the first one.

**If P5–P7 hold, this is the strongest Lab vs PROD callout in the phase:** an application that reports
itself healthy, satisfies the orchestrator completely, passes a `/health` probe, and cannot serve a
single request that matters. **The alternative — a clean crash-loop — would be far better operationally**,
because `docker service ps` would show it and the deploy would fail loudly.

---

## 🏭 Lab vs PROD ledger

⭐ **Started Aug 13, 2026, at Andrew's request.** Every lab makes compromises an enterprise platform
would not accept. **The risk is not forgetting a command — it is carrying a shortcut into production
having never been told it was one.** Written here *as we take them*; chapter callouts are drawn from
this table. Format and threshold: `education/CONVENTIONS.md` → "Lab vs PROD callouts".

🚨 **Threshold:** a row earns its place when the lab choice would be **WRONG** in production, **not
merely SMALLER**. Scale differences do not qualify.

**Verified?** = did we *test* the production prescription, or is it recited? ⚠️ **Recited rows are
opinion until proven.** Do not let them wear the authority of the tested ones.

| # | In the lab | Why acceptable here | In production | If you carry the habit | Verified? |
|---|---|---|---|---|---|
| L1 | **Registry over plaintext HTTP** — `insecure-registries` in `/etc/docker/daemon.json` on all three nodes. | Isolated home network; lab-only credentials by rule B7. | Registry gets a real TLS cert; `insecure-registries` is never set. | A registry credential goes across the wire in cleartext. ⚠️ Worse, `insecure-registries` is the exact knob people reach for to make a TLS error "go away" — **it silences a warning that was correct**. | ⚠️ recited |
| L2 | **`Autolock Managers: false`** — Raft log encryption key sits on disk in the clear on every manager. | Default; lab has no real secrets **until Part 3**. | `docker swarm init --autolock`, key held in a secrets manager. Cost is real: **managers need manual unlock after restart**, which is an availability trade-off, not free. | Anyone with a manager's disk — **or one of our VM snapshots** — reads every `docker secret` in the cluster. | ⚠️ recited |
| L3 | **All three nodes are managers AND run workloads.** | Three nodes is the minimum for quorum; dedicating three more to be workers doubles the lab for no lesson. | Managers are drained (`--availability drain`) so the control plane never competes with application load. | A runaway container can starve Raft and cost you the control plane during the incident that spawned it — **exactly when you need to make changes**. | ⚠️ recited |
| L4 | **Three VMs on one physical host.** | Only host available; the Raft events are genuine. | Managers spread across failure domains — racks, hypervisors, AZs. | You will believe you have tested HA. **This simulates NODE failure, never HOST failure** — losing the Z6 loses all three at once. | ✅ inherent |
| L5 | **`unattended-upgrades` and `apt-daily` masked.** | Deliberate: package churn mid-study manufactures failures that teach nothing and make real ones ambiguous. | Staged patching with maintenance windows and a rollback path. | 🚨 **Unpatched CVEs.** This one is not merely suboptimal in production, it is negligent — and it is the row most likely to be copied without thinking, because it *feels* like tidiness. | ✅ deliberate |
| L6 | **No backups — snapshots only.** | Nodes are rebuildable from template 9000 in minutes; nothing here is authoritative. | Back up the Raft state and every named volume; snapshots are not backups. | **A snapshot is a rollback, not a recovery.** Lose the host and you lose every snapshot on it. | ✅ policy |
| L7 | **Password SSH auth still enabled** (observed during the `.192` join). | Template default; LAN-only. | Keys only, `PasswordAuthentication no`, ideally certificate-based with a bastion. | Cluster managers exposed to credential-stuffing, and no per-human audit trail. | ✅ observed |
| L8 | **Images published and deployed as `:latest`.** | It is what Capricorn actually does — inherited, not chosen. | Immutable tags or digests; `:latest` never referenced by a deployed service. | "I pushed a fix and prod is still running the old code." **Trap C7 exists to make this happen on purpose.** | 🔲 will test (C7) |
| L9 | **`docker login` writes the registry credential to `~/.docker/config.json` as base64** — an encoding, not encryption, reversible with no key. | Lab-only deploy token, `read_registry` scope, ~30-day expiry. | A **credential helper** backed by the OS keystore (`docker-credential-secretservice`, `pass`, or the cloud provider's helper), so the token never sits on disk in recoverable form. | Any process running as that user, any backup, **and every one of our VM snapshots** contains a working registry credential. ⚠️ In a CI context it also means a leaked build artefact or a debug `cat` in a pipeline log hands the token over. | ✅ **VERIFIED** — Docker printed the warning itself, and we decoded the blob back to `swarm-lab-pull` in one line |
| L10 | **The system-of-record database runs as a container task on a node-local volume**, pinned to one node so it cannot move. | Capricorn self-bootstraps demo data, so the lab's data is worth nothing and losing it costs nothing. The pin is what keeps it from silently moving. | 🚨 **Not a container at all.** Real PG hosts or a managed cluster: streaming replication, PITR, a *tested* restore path, and an upgrade story that does not involve a scheduler. | **You have made your database's availability a function of your orchestrator's scheduling decisions** — and given it a single point of failure with no replica, no backup and no restore rehearsal. ⚠️ Note the pin is *also* a lab compromise: it trades availability for durability, which is the wrong trade to make deliberately in production. | ✅ **Andrew's call, Aug 13** — and the narrow claim only: Redis, OpenSearch, MongoDB and Redpanda *are* routinely run on orchestrators in production |
| L11 | **The application is published over plain HTTP on `:5001`/`:5002`, with no reverse proxy and no TLS.** | Deliberately QA-shaped: the lab's job is to teach the routing mesh, and a proxy in front would hide it. | TLS terminated at an ingress proxy; the app's own ports never published to a network a user can reach. | Session cookies and every API payload cross the network in cleartext. ⚠️ **And the shape of the lab quietly justified it** — see the note under this table: the *frontend build* is what forced the HTTP path, so "no TLS" arrived as a consequence of an image, not as a decision anyone made. | ✅ deliberate |
| L12 | **A single long-lived registry token (`swarm-lab-pull`, valid to Dec 31 2026) is used by a human at the CLI and embedded into every service spec.** | One operator, one cluster, a lab. | Short-lived, workload-scoped credentials — OIDC/federated identity for the CI job, no static token anywhere, and pull credentials issued per-deploy rather than stored. | One leaked token grants registry access for a year, **and revoking it silently breaks every future task reschedule** (see the latch finding below) rather than failing at deploy time where you would notice. | ⚠️ recited |
| L13 | **No `healthcheck` on any service.** | 🎯 **Deliberate — trap C6 needs it absent** to show that `update_config`/`rollback_config` cannot detect a container that starts, stays up, and serves garbage. Healthchecks get added *after* C6 has been felt. | Every service has a real readiness/liveness check that exercises its dependencies, not a TCP-port ping. | 🚨 **Your rollback protection is decorative.** Swarm will happily call a broken deploy successful because the process did not exit — which is precisely what C6 is built to prove. | 🔲 will test (C6) |
| L15 | 🚨 **The backend exhausts a 15-attempt wait-for-database loop, prints `❌ Bootstrap failed`, and then completes startup anyway** — so a database-less service reports `2/2`, passes `/health`, and 500s on every real request. | Nothing: the lab has no users, and the drill *wanted* this state to be reachable so it could be measured. | The process **exits non-zero** when a hard dependency is unavailable after its retry budget, and the readiness probe exercises the dependency rather than returning a constant. | 🚨 **Every safety net in the stack is defeated by one missing `sys.exit(1)`.** `restart_policy` never fires (nothing exited), `max_attempts` is never consumed, `deploy_swarm.sh` converges and prints digests, CI goes green, and the routing mesh sends users to it. ⚠️ **The retry loop is what makes it dangerous** — it absorbs the transient case perfectly, so the dependency looks handled right up to the terminal case, which degrades silently instead of failing. **An app that reports success while unable to serve is worse than one that crashes**, because a crash is a page and this is a support ticket three days later. | 🚨 **measured Aug 18** |
| L14 | **The `pg_password` value existed ONLY inside Swarm's Raft log** — created out of band, never written down. The `s02` rollback destroyed it, and it is now unrecoverable. | Nothing of value was lost: the postgres volume was destroyed by the same rollback, so the next deploy runs `initdb` fresh and any new password works. | The authoritative copy lives in a real secrets manager (Vault, SSM, Secrets Manager) that the orchestrator *reads from*. The orchestrator is a **delivery mechanism, never the system of record**. | 🚨 **`docker secret` is not a secrets manager, and this is the trap.** The API will not give a secret back — `docker secret inspect` returns metadata, not the value — so a cluster rebuild loses every credential you did not store elsewhere. ⚠️ **But the NODE will:** `docker exec <task> cat /run/secrets/<name>` prints it in cleartext, so **`docker` group membership on any node equals read access to every secret scheduled onto it**, invisibly to any audit trail. Unreadable to operators, readable to anyone on the box — the worst of both. ⚠️ **We only escaped because the data volume died too.** Had the volume survived the Raft loss, postgres would still be authenticating against the OLD password baked into its data directory while the new secret disagreed: **a database you cannot log into, holding data you cannot read, with no copy of the credential anywhere.** | 🚨 **hit it for real, Aug 13** |

⭐ **L9 is the best row in this table and it wrote itself.** Docker *volunteered* the warning
(`WARNING! Your credentials are stored unencrypted…`) without being asked. The tool told us it had just
done something substandard, and **the near-universal response is to scroll past it.** That is the
lesson: the warning is not noise, and "it looks like an opaque blob" is why people assume otherwise.

### Baseline for trap C7 — record before anything is deployed

`docker pull …/production/capricorn/backend:latest` on `.191` (Aug 13, 2:33 PM) resolved to:

```
Digest: sha256:fac031dd827c3f1c78d6732d925ae6888ee65b821c08218dd4b1ea7ae8f237a1
```

⚠️ **Write this down now, because trap C7 depends on comparing against it later.** `:latest` is a
moving pointer; that digest is what it pointed at today. When C7 pushes a new image under the same tag,
this is the number that proves whether the running service followed the tag or stayed pinned.

**Also confirmed here:** `read_registry` **alone** was sufficient to pull — `read_repository` was
deliberately not granted and was not needed. Worth recording because the instinct when a pull fails is
to widen the scope, and we now have evidence the narrow one was enough.

---

## 🔀 Deployment: three wrappers, one script

Discussed Aug 13. **Confirmed: the employer runs GitHub for source and Jenkins for CI**, while the lab
runs GitLab and GitLab CI. The three deployment approaches are **not alternatives to choose between —
they are three wrappers around the same `deploy_swarm.sh`:**

| Approach | Who invokes | What it buys | What disqualifies it |
|---|---|---|---|
| **Manual** (Part 3) | a human over SSH | Proves a *working* deploy exists before CI touches it, so a Part 4 failure is unambiguously a wiring problem. Survives as break-glass. | Requires humans to hold **SSH access to production managers** — precisely the access you want to eliminate. Not ergonomics; access control. |
| **GitLab CI** (Part 4) | runner on `.182` | Audit trail, manual approval gate, masked secrets, **no human SSH to the cluster**. Runner already exists and needs no setup (A1). | YAML in a dialect the employer does not use. |
| **Jenkins** (Phase 17) | Jenkins agent | Matches the employer exactly. | Heavier — JVM plus a plugin ecosystem whose CVE churn becomes your operational problem. Groovy is expressive enough that teams put **deploy logic inside the Jenkinsfile**, which is the anti-pattern this whole design avoids. |

**The boundary:** the **script** owns registry login, `docker stack deploy`, convergence polling and
the rollback decision. The **wrapper** owns when it runs, who may run it, where the secret comes from,
**which host it targets**, and who gets notified. ⚠️ Note that host targeting sits in the wrapper —
**that is where trap C4 lives**, since pointing it at one manager by IP gives an HA control plane
behind a single-point-of-failure delivery path.

⭐ **Falsifiable claim, recorded now so Phase 17 can test it: if Jenkins requires changing a single
line of `deploy_swarm.sh`, the boundary was drawn in the wrong place.** That is a real test of the
abstraction rather than an assertion about it.

**A fourth model exists and Swarm does not have it.** Pull-based GitOps — something *inside* the
cluster watching a repo and reconciling toward it, so no CI system ever holds credentials into
production. Kubernetes has Argo CD and Flux; **Swarm has no real equivalent.** ⭐ **This is strong
Part 7 comparison material** because it is an architectural difference, not a feature-checklist one.

**Phase 17 will have to choose its source: GitLab or GitHub.** GitHub matches the employer and
`push_github.sh` already publishes there — but it is a **public** repo, and webhooks from public
GitHub into the home lab need inbound exposure or polling. GitLab is entirely internal and simpler.
**Deferred to Phase 17**; recorded so it is not rediscovered.

**Bearing on A2:** knowing Jenkins is coming, the GitLab CI file still earns its place — it proves the
wrapper boundary once, cheaply, on infrastructure that already exists. But it needs the
`workflow: rules:` guard, or every backup push starts firing pipelines.

---

**Next: Part 3 — the stack file, `docker secret`, and the first deploy. Trap C1
(`--with-registry-auth` omitted on purpose) fires here. Andrew driving.**
