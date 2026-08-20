# Phase 16 — Docker Swarm: build it, wire a pipeline to it, then break it

**Status:** 🟢 **ALL SEVEN PARTS COMPLETE and ALL SEVEN PLANTED TRAPS CLOSED (Aug 19, 2026).**
Three nodes (`s01-base-clean`) → three-manager cluster, quorum 2 of 3 (`s02-swarm-up`) → Capricorn
deployed → CI pipeline (Part 4) → state and failure drills (Parts 5–6) → **trap C7 closed** → **Part 7
crib sheet written as chapter 8**. Snapshot chain runs to **`s07-c4-fixed-verified`**, the first one
containing the C4 fix. Eight chapters written.
**Nothing planned is outstanding.** The highlight pass on chapters 1/2/4/5/6 was done Aug 19 (all 15
chapters of both tracks now at 19.5–21.2 % — method in `phase15_education_program.md` §8), and **drill D
was run on Aug 18**: P30/P31 both ✅, the `pg_hba.conf` `trust` finding came out of it, and chapter 5's
drill table carries it as row D. ✅ **The last open measurement — the `redis` divergent-volume question — was
MEASURED and CLOSED Aug 19, 7:55 PM (🤖 AI-executed, read-only).** The hypothesis was **refuted**: `.191`
has never held a redis volume, and the two volumes that do exist are **trap C3's deliberate residue from
Aug 18 19:06:56**, not an accident. The live task has run since Aug 18 with `RestartCount 0` and both
canary keys intact. ⭐ **The value is in why the question arose at all: `docker service ps`'s
`CURRENT STATE` age is the last time the manager stamped the task's status, NOT the task's age** — at the
2:07 PM dump the task was 20 hours old, not 2. Full evidence in §Part 5 → "CLOSED Aug 19". ⚠️ **Standing
hazard left in place, not fixed:** an empty 88-byte `capricorn_redis_data_swarm` still sits on `.193`, and
`redis` scheduling there would silently attach an empty cache.
**Nothing else is outstanding.** The rigorous `.Version.Index` version of the convergence check is
deliberately deferred to Phase 17.
⚠️ **This header read "Parts 1 & 2 COMPLETE … Next up: Part 3" until Aug 19** — six days and four Parts
out of date, while the log at the bottom was current. **A status line at the top of a long file is the
first thing read and the last thing updated;** treat it as a claim to re-verify, not as state.
🚨 **It then did it again, and the second time is the instructive one.** From Aug 18 to Aug 19 this line
said drill D was "outlined but never run" while the results sat 1,900 lines below it, scored and
written up. That false claim was copied into `MEMORY.md`, `current_phase.md` and the roadmap table, and
survived a `MAKE_MEMORIES` pass on Aug 19 that *cited it as the only open item* — because the pass
edited the summaries and never diffed them against the detail. ⭐ **A summary is a claim about another
file; the only way to maintain one is to re-read what it summarises.** The `🔲` box at the drill's
planning entry was never ticked, and an unticked box outranked measured evidence for a full day.
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
| A2 | Should this repo gain a `.gitlab-ci.yml` at all? | 🙋 **Andrew** | ✅ **RESOLVED Aug 19 — YES, guarded to `$CI_PIPELINE_SOURCE == "web"`, and the job ALSO keeps `when: manual`.** See "A2 resolved" below. |
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

**A2 — resolved Aug 19, 2026, with two gates and one correction.** Andrew's call: the file lands, and
the pipeline only ever comes into existence from the web UI. Two gates, deliberately independent:

| Gate | Mechanism | What it decides |
|---|---|---|
| 1 | `workflow: rules: $CI_PIPELINE_SOURCE == "web"` | whether a pipeline is **created at all** — a push creates nothing, so `push_gitlab.sh` leaves no trail of dead pipelines |
| 2 | `when: manual` on `deploy_swarm` | whether the job **runs** inside a pipeline that exists |

⭐ **Gate 2 kept on purpose even though gate 1 already means only a human can create the pipeline**
(Andrew, Aug 19): *the job's own safety must not depend on the workflow guard staying in place.* If a
later session relaxes gate 1 — and a `workflow:` block is exactly the kind of thing that gets relaxed to
"make CI work again" — the deploy still cannot fire on its own. It also matches the shape of a real
pipeline, where the pipeline is created by a push and the manual gate *is* the production approval.

⚠️ **Correction to the plan's own wording, found while walking A2.** The Part 4 text said the guard must
land "in the SAME commit as the CI file". **Too weak.** `push_gitlab.sh` stages the working tree with
`git add -f -A` (tracked *and* ignored), so the file reaches `gitlab/main` **the moment it exists on
disk** — committed or not, staged or not. The guard must therefore be in the **first version written to
disk**, not merely the first commit. A file created "to fill in later" is already live.

🚨 **Open finding raised at the same moment, deliberately NOT solved yet (see P-numbers in Part 4's log
when it runs).** `gitlab/main` is the **full plaintext mirror**: `push_gitlab.sh` exists precisely to put
`PASSWORDS.md`, `github_credentials.md`, `proxmox/credentials` and `working/` on that branch. GitLab CI
clones the branch it builds, so **the job's working directory contains every secret in the project** —
which makes the masked `read_registry` variable (rule B6) a lock on a door in a building with no walls.
This is not one of the planted traps (🅒); we walked into it while reasoning about A2. It is likely the
strongest material in chapter 3, because the general form — ⭐ **a CI job's blast radius is the CONTENT OF
THE BRANCH IT CHECKS OUT, not the variables you were careful with** — transfers directly to a Jenkins
shop and to any repo whose "private mirror" doubles as a CI source. Chase it during the build; do not
pre-empt it here.

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
| D6 | 🚨 **`deploy_qa` performs a registry login by putting the GitLab `root` account's password INLINE on an SSH command line**, in the committed `.gitlab-ci.yml` (read Aug 19 while copying the runner→host SSH pattern for Part 4). Two consequences the file's own author may not have joined up: the credential is **in git history** and therefore unremovable by editing, and because it is a **literal rather than a CI variable, GitLab's masking cannot touch it** — so it is printed into the job log of a job that fires automatically on *every* `develop` push. It is also visible in `ps` on the target host for the life of the command. | ⚠️ **Application layer — raise with whoever owns Capricorn; NOT fixed here** (rule B1 forbids touching that job at all). Recorded because it is the exact anti-pattern rule **B6** was written against, and we now have a live in-house example rather than a hypothetical one. ⭐ **This is why our job uses a `read_registry` deploy token delivered over stdin.** For the chapter, carry the **pattern** and never the value or the account (`CONVENTIONS.md` → app-specific findings table). |
| D7 | **Every `ssh` and `scp` in both deploy jobs carries `-o StrictHostKeyChecking=no`**, and the `before_script` runs `mkdir -p ~/.ssh && chmod 700 ~/.ssh` while **never writing a `known_hosts`**. | ⚠️ **Inherited pattern, and a decision point for Part 4 rather than a defect to fix in Capricorn.** ⭐ **The `mkdir` is the interesting part:** GitLab's documented snippet is `mkdir -p ~/.ssh` *followed by* `ssh-keyscan "$HOST" >> ~/.ssh/known_hosts`. The safety step was dropped and **its scaffolding was kept** — the fingerprint of a copy-paste. Worth teaching as a habit: *when a config step looks purposeless, ask what used to be next to it.* ✅ **Correction, Aug 19 — the AI first wrote that the `mkdir` "protects nothing", and that is wrong.** Under `StrictHostKeyChecking=no` ssh still tries to *append* the host key to `~/.ssh/known_hosts`; with no `~/.ssh` it warns and carries on statelessly. The `mkdir` lets the key persist **for the life of the job**, so the first connection learns it and the seven that follow verify against it. That is trust-on-first-use scoped to one job: weak, since a MITM present at connection one is simply trusted, but **not nothing** — an attacker who intercepts only *some* connections gets caught. ⚠️ Recorded because overstating a criticism is its own kind of inaccuracy, and the corrected version is the more useful lesson. |
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

**Then `s06-ci-wired`.** ⚠️ **Corrected Aug 19 — this section originally said `s04-ci-wired`**, a name the
drills session already used (`s04-drills-complete`). The chain is `s01 → s02 → s03 → s04 → s05`, so the
CI snapshot is **`s06`**. Left visible rather than silently overwritten because ZFS rollback here is
**linear and newest-only**: acting on the stale name would not have created a duplicate, it would have
been a request to roll the cluster back to before the drills.

---

### Decisions taken Aug 19, 2026 — mirror Capricorn, document the gap, fix it in Phase 17

🙋 **Andrew's call, and it is a deliberate deviation worth its own record.** Part 4 **copies Capricorn's
existing deployment mechanism**, including the parts we can see are wrong, rather than building the
secure version now:

| Choice | What we do | Why |
|---|---|---|
| Key delivery | `ssh-agent` + `ssh-add -` from a **plain multi-line CI variable**, exactly as `deploy_qa` does | It is the mechanism he will actually be handed. GitLab **cannot mask a multi-line value**, so the key is unmaskable by construction — a constraint, not an oversight |
| Host keys | `-o StrictHostKeyChecking=no`, as the inherited jobs do (finding D7) | Same reason. The callout names the consequence |
| Registry token | 🚫 **NOT copied.** Ours is a `read_registry` deploy token over **stdin** | Rule B6, and finding D6 is the live counter-example |
| The key itself | ⭐ **A NEW dedicated keypair, not Capricorn's** | See below — the one place we refuse to mirror |

⭐ **Same mechanism, separate credential — the one carve-out, and the reasoning is the transferable
part.** Capricorn's `.gitlab-ci.yml` footer describes `SSH_PRIVATE_KEY` as *"the runner's private key for
SSH access to VMs"*: **one key serving `.180` (QA) and `.184` (local production)**. Reusing it would give
the *study cluster's* pipeline SSH access to production Capricorn hosts, which **inverts the entire reason
Part 4 lives in this repo** (O2: breaking the lab cluster must not be able to break Capricorn's delivery
path). It also makes the lab key unrevokable — burning it after Phase 16 teardown would break production
deploys. A fresh keypair costs one command and can be destroyed at teardown with no blast radius.
⚠️ Secondary and merely practical: Capricorn's variable is almost certainly **project-scoped**, so
promoting it to instance level would be an edit to production CI config — the spirit of rule B1.

🚨 **The honesty cost, stated up front.** Deferring the correct implementation means the *"in production
you would…"* half of these rows stays ⚠️ **recited**, and `CONVENTIONS.md` forbids a recitation wearing
the authority of a test. **Turned into an asset instead** (agreed Aug 19):

⭐ **PHASE 17 CHARTER — the recited rows ARE the scope.** Phase 17's success condition is not "Jenkins
deploys the stack"; it is **"every ⚠️ recited row in the Phase 16 ledger is now ✅ verified."** Concretely:
host keys pinned rather than `StrictHostKeyChecking=no`; a credential GitLab-or-Jenkins can actually mask
(or a keystore-backed one that never becomes an env var); and a build agent that is **not** privileged
with the docker socket mounted (L19). This makes Phase 17 testable, and it stops Part 4's shortcuts from
becoming permanent by being written down as "fine". ⚠️ **A phase whose scope is another phase's unpaid
debt is a pattern worth reusing** — consider folding it into `METHOD.md` once it has actually worked.

**Then `s06-ci-wired`** (see the correction above).

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

### ✅ DONE — Aug 19, 2026, as `education/docker-swarm/chapter08_swarm_vs_kubernetes.md`

Every bullet above is covered. Three decisions and one correction are worth recording, because they are
the parts a re-read would otherwise have to re-derive.

**D1 — it is a chapter in the Swarm track, not a top-level cross-track document.** A comparison of two
tracks arguably belongs at `education/` level, and `CONVENTIONS.md` does say cross-track references go
through `education/README.md`. It went into the track anyway for a practical reason: **`build_docx.py`
takes a track argument**, so a file at `education/` level would never be printed, and the printed
binder is the artefact. The convention is honoured by having `education/README.md` carry the pointer
and the statement that this is the only document citing both tracks.

**D2 — per-row provenance marks, and they are the reason the chapter is worth anything.** Every claim
carries **S** (measured on this three-node Swarm), **K** (measured on single-node k3s), 🤖 (measured
only in AI-executed chapter 7) or ⚠️ **recited** (neither lab ran it). Without the marks it is
indistinguishable from any feature-comparison blog post, and worse — it would launder textbook claims
into apparent experience. The device is reusable and should be reused for any future cross-track piece.

**D3 — the framing is the lab asymmetry, not the feature list.** Three nodes with seven planted traps
against one node with none. Almost every honest "Kubernetes didn't show that" row means **the lab had
one node**, not that Kubernetes lacks the property — and the bias runs the other way too, because
Swarm's higher fault count in this phase is a product of unequal scrutiny. That distinction leads §1.

**Two findings the writing itself produced** (neither was in the plan):

- ⭐ **The PVC row in the usual comparison is backwards.** The k3s lab ran `local-path`, whose
  PersistentVolume is a directory on the node — so it **strands data on exactly the same nail** as a
  Swarm named volume, and only escaped demonstrating it by having one node. What Kubernetes actually
  supplies is a standard interface with a live driver ecosystem behind it. That is decisive, and it is
  an argument about **ecosystem and storage**, not about the PVC object — which also reframes the
  Capricorn verdict in §13.
- ⭐ **Swarm's image default is the safer of the two**, which is the opposite of the usual narrative.
  Pinning a digest at accept time is what keeps a 3am reschedule on the same build as its siblings.

**C1 — one factual error caught during grounding, worth logging as a near-miss.** A first draft credited
Swarm with bringing up "mutual TLS and an **encrypted Raft log** with no configuration." Chapter 1
contains a Lab-vs-PROD callout stating the opposite — `Autolock Managers: false`, so **the Raft log is
not encrypted at rest**. The claim was plausible, flattering, and contradicted by this track's own
material. It is now stated correctly, with the TLS half marked ⚠️ **recited** because the lab never
inspected a certificate. **This is the whole case for grounding a synthesis chapter in the source
chapters rather than in recollection.**

Mechanics: figure `ch08_fig1_object_models` (the ReplicaSet layer Swarm lacks) at 21.2pt on the page —
`figcheck.py` passes all 10 figures ≥ 10pt; 69 highlights at **14.5%** of prose; docx built. A
three-panel "what each lab could prove" comparison was deliberately **not** drawn as a figure —
`CONVENTIONS.md` requires tabular content to be a Markdown table, which prints at body size.

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
  wrong.** Two services (frontend, backend) use `order: start-first`, which starts the replacement
  before retiring the old task, so running/desired can read `3/3` *continuously* through a full
  rolling replacement — and briefly `4/3` (measured during C6b). *(Corrected Aug 18: an earlier
  revision said "three services"; postgres and redis have no `update_config` at all.)*
- 🚨 **Worse: `failure_action: rollback` restores the previous version and the service settles back at
  full replicas.** A count-only check calls that a **success**. It is the opposite — the new code was
  rejected. **The most misleading green a deploy job can produce**, and both `start-first` services
  are configured to do it. The script now treats `UpdateStatus.State` of `rollback_started` or
  `rollback_completed` as a hard failure. (The field is **ABSENT**, not empty, on a never-updated
  service — the naive template errors; corrected Aug 18, see line ~1694.) ✅ **C6a later confirmed
  the detection side** (rollback caught in 1.3 s). ⚠️ The stale-latch half stays open; the script now
  snapshots each service's pre-deploy `UpdateStatus` and refuses to blame the current deploy for a
  latch that predates it (added in the Aug 18 evening review).
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
| P1 | `deploy_swarm.sh` **refuses before touching the cluster**, naming `pg_password`. | The secret died with the rollback and the pre-flight guard has never actually fired. | ➖ **NOT TESTED BY THIS RUN** — it landed on the workstation, so the *manager* guard fired first (see below). ✅ **Since closed by Drill B**, which fired the secret guard deliberately; Drill D then showed the guard's limit — it catches an ABSENT secret, never a WRONG one. ⚠️ This cell read "the secret guard remains unexercised" long after Drill B exercised it. |
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

### Drill B — fire the `pg_password` guard at last. Prediction

The guard has dodged testing **twice**: on Aug 13 the run landed on the workstation, so the *manager*
check fired first, and the secret was created before any manager-side run.

| # | Prediction | Reasoning | Outcome |
|---|---|---|---|
| P9 | The script exits **non-zero naming `pg_password`**, and `docker stack ls` stays empty. | The check is a pre-flight, before anything is sent to the cluster. | ✅ **CONFIRMED.** `FAILED: secret 'pg_password' does not exist - create it first: …`, `EXIT=1`, `docker stack ls` empty. |
| P10 | **The registry login never runs.** | The secret check sits *above* the login block, so a missing secret costs nothing and leaks no credential. ⭐ **Pre-flight order is a design choice:** cheapest and most-likely-wrong first, so failures are free. | ✅ **CONFIRMED** — no `logging in to …` line in the output at all. |

#### 🚨 Andrew's work parallel — and why it is the OPPOSITE case to the one we just tested

> *"I expected this to fail without secrets — we can't access PG. This happens at work whenever someone
> rotates a PG password and forgets to update it in secrets."*

**The instinct is right and the mapping is not.** These two failures look adjacent and behave nothing
alike:

| | Secret **MISSING** (drill B) | Secret **PRESENT but WRONG** (the rotation case) |
|---|---|---|
| Deploy | ❌ **refuses before touching the cluster** | ✅ **succeeds** |
| Cost | nothing changed, nothing pulled, no login | services recreated, old tasks stopped |
| Postgres | never starts | starts fine — **its password lives in its own data dir, not in the secret** |
| Backend | never starts | retries 15×, `Bootstrap failed`, **starts anyway** (drill A) |
| Swarm's verdict | failure, exit 1 | **converged, `2/2`, green** |
| How you find out | immediately, from the deploy | a user, later |

⭐ **`deploy_swarm.sh` checks that the secret EXISTS. Nothing checks that it WORKS** — and nothing can,
cheaply, because **you cannot validate a credential without using it.** That is precisely the argument
for the smoke gate: the only honest test of a password is a request that needs it.
✅ **The gate added today would catch the rotation case**, where every pre-flight check passes.

🚨 **The postgres-specific trap that makes rotation worse than it looks.** The official entrypoint reads
`POSTGRES_PASSWORD_FILE` **only when it runs `initdb`**, and `initdb` only runs on an **empty** data
directory. On an existing volume, initialisation is skipped entirely:

- **Update the secret only** → postgres keeps the *old* password from its data dir; the backend presents
  the new one; auth fails. **Nothing in the stack file is wrong.**
- **`ALTER USER` in the database only** → postgres has the new password; the secret still holds the old
  one; auth fails the same way.
- **Both, in the wrong order** → a window where the running app cannot reconnect.

⭐ **So a Swarm secret is not the system of record for a database password — the database is.** The secret
is a *copy*, and two copies drift. This is the same root cause as L14 from a different direction: the
orchestrator holds credentials it does not own.

✅ **DONE Aug 18** — results below (P30 ✅, P31 ✅, plus the `pg_hba.conf` `trust` discovery and the
`name:`-vs-stack-key trap in the guard). ⚠️ **This box stayed `🔲` for a day after the drill ran, and
the file header quoted it as proof the drill was outstanding.** Tick the box in the same edit that
writes the result, or the plan silently outranks the evidence.
**Drill D added (chapter 5 material — "secret rotation" is already in its outline):** rotate
`pg_password` **without** touching the database, redeploy, and confirm the smoke gate catches what every
other check misses. **This also tests the gate itself**, which is currently unproven against a real
failure.

### Drill C — what actually caused the seeding collision? Prediction

**Variant generated FROM the canonical stack file rather than copied**, so it cannot drift:

```bash
sed -e 's/--workers 4/--workers 1/' -e 's/replicas: 2/replicas: 1/' \
    ../manifests/capricorn.stack.yml > /tmp/capricorn.seedtest.yml
```

(Both anchors verified unique — `grep -c` returns 1 for each.)

| # | Prediction | Reasoning | Outcome |
|---|---|---|---|
| P11 | 🎯 **No `UniqueViolationError`.** One process against an empty volume seeds cleanly. | ⭐ **The Aug 13 evidence points here:** the violation appeared on `backend.2` **only**, never on `backend.1`, which started 3.6 s later. If the app's bootstrap collided with `001_schema.sql`'s own 12 seeded categories, **every** worker in **both** tasks would have hit it. That it was task-specific says the loser was racing *other writers*, not the schema. | ✅ **CONFIRMED — but see the confound below.** No violation, no retry loop, and a complete seed: `✅ Bootstrap complete: {…'categories': 51, 'transactions': 611, 'total': 682}`. Converged and passed the gate in **16.9 s**. |
| P12 | Exactly **one** `Waiting for application startup` line, versus four per task before. | `--workers 1`. Confirms the variant took effect — worth checking so a null result is not just a config that never applied. | ✅ **CONFIRMED.** `grep -c` = **1**. The variant applied, so P11 is a real null result and not a config that never landed. |
| P13 | **The smoke gate runs for the first time and passes.** | First deploy since it was added. | ✅ **CONFIRMED**, and it earned its keep: `/api/v1/banking/categories` → 200 with a matching body, `/api/v1/data/summary` → `total=682`. **It also exposed two defects in itself** — see below. |

**Reading:** with the seeding path reduced to a single writer, the collision disappears and the import
completes. That points at `--workers 4` and puts the fix **application-side — an upsert or an advisory
lock around bootstrap — not a smaller replica count.** Scaling down to dodge a race is a workaround that
expires the moment someone scales back up.

### 🚨 The result is not clean, and it has to be said

**Two variables changed between the Aug 13 observation and this one.** Printing the resolved digests
showed `:latest` had moved for **all three** first-party images while the lab sat idle (an unrelated
pipeline pushed them). Aug 13 collided on `backend@fac031dd…`; this run seeded cleanly on
`backend@b449d6c4…`.

So the honest statement is: **P11 is confirmed for this image, and the causal claim about worker count is
not yet established.** A newer backend could have fixed the race outright. The distinguishing experiment
is cheap and is *already* the restore step:

> **Wipe the volume, deploy the canonical stack file (4 workers, 2 replicas) on the current image.**
> If the `UniqueViolationError` returns → concurrency is the cause, P11 stands. If it does not → the
> image changed the behaviour and the Aug 13 finding is now historical.

⭐ **The transferable habit: capture the digests before *and* after every drill.** A drill compares two
states; if something moved that you did not move, you are not comparing them. This is also trap C7
(mutable tags) arriving unannounced, ahead of the chapter that was going to teach it.

### Two defects the gate revealed in itself

| Defect | What happened | Fix |
|---|---|---|
| **The row floor could not fail.** | `SMOKE_MIN_ROWS` defaulted to **1** while `001_schema.sql` seeds 12 categories unaided — so it would have passed a database whose bootstrap never ran, the exact false-green the gate exists to catch. It went untested here only because the seed *succeeded* (682 rows). **A latent hole in a check is worse than no check: it reports safety.** | Default raised to **100**, sitting between schema-only (~12) and a full bootstrap (682). Rule recorded: **pick a number the schema alone cannot reach.** |
| **`HTTP 000000` in the log.** | `curl -w '%{http_code}'` writes `000` on a refused connection **and** exits non-zero, so the `|| echo 000` fallback appended a second `000`. Cosmetic, but a nonsense status code is something a stranger will burn twenty minutes searching for. | `|| true`, and body + status captured in **one** request instead of two — two calls can straddle readiness and pair a 200 with a stale body. | ✅ Fixed and confirmed on the next run: the log now reads `HTTP 000` once. |

### 🚨 Attempt 1 at the control was VOID — and the reason is worth more than the experiment

The control (4 workers, current image, fresh volume) ran and reported a clean pass: converged in 17.2 s,
`total=682`, gate green. **It proves nothing, because the volume was never wiped.** The runner said:

```text
===== wipe the volume again: the control needs a GENUINE initdb =====
  already gone                              ← my error message, not docker's
local     capricorn_postgres_data_swarm     ← the volume, still there
```

`docker volume rm` failed; the block was written as `docker volume rm … 2>/dev/null || echo "already
gone"`, which **discarded the reason and then asserted the opposite of the truth.** The next line printed
the contradiction, and the deploy proceeded onto drill C's already-seeded database. So there was no
`initdb`, no fresh bootstrap, and no opportunity for a seeding race — the `682` was drill C's rows being
read back.

⭐ **The lesson, which generalises past Docker entirely:**

> **Never suppress stderr on a step the experiment depends on.** A precondition that fails quietly does
> not produce a failed experiment — it produces a *successful-looking* one that answers a different
> question than the one you asked. This is the same false-green shape as `/health` returning 200 with
> the database on fire, except this time **I built it into the instrumentation**, which is worse: the
> smoke gate was honest, and it was measuring a state nobody intended to create.

The corrected form does three things the first did not:

| Requirement | Why |
|---|---|
| **Show docker's actual error** instead of a hand-written guess | `no such volume` and `volume is in use` demand opposite responses, and the first version made them indistinguishable. |
| **Retry**, because teardown is asynchronous | `docker stack rm` returns before the container objects are gone, and the volume stays busy until they are. The network-teardown wait was not enough. |
| **Assert, then `exit 1`** if the volume survives | The only acceptable outcome of a failed precondition is *not running the experiment*. |

🚨 **A node-scoped trap sits underneath this too:** volumes are **local to a node**. Running `docker
volume rm` on the wrong node returns `no such volume` — which the original block would have cheerfully
reported as "already gone". **Confirm where postgres is pinned before believing a wipe.**

### ✅ Attempt 2 — the control held, and the cause is settled

Preconditions asserted this time: postgres confirmed on `docker-swarm-1`, teardown waited for **3
containers** to be reaped after the network had already gone (the network wait alone was genuinely
insufficient), volume removal confirmed absent. Digests **identical** to the drill C run, so the image is
held constant and the only variable is the worker count.

| # | Prediction | Outcome |
|---|---|---|
| P14 | The `UniqueViolationError` returns, on exactly one of the two tasks | ✅ **CONFIRMED.** 3 violations, **all on `capricorn_backend.2`**, none on `.1`. `duplicate key value violates unique constraint "categories_pkey"`, `Key (id)=(1) already exists`. |
| P15 | 8 `Waiting for application startup` lines | ✅ **CONFIRMED.** Exactly **8** — 4 workers × 2 replicas. |
| P16 | The gate passes anyway at `total=682` | ✅ **CONFIRMED.** Converged in **12.1 s**, gate green, 682 rows. |

🎯 **C2 is now causally answered, not just correlated.** Same digest, same volume state, same everything
except `--workers 1` → `--workers 4`, and the collision reappears. **The cause is concurrent startup
writers; the fix is application-side idempotency — an advisory lock, an upsert, or a one-shot job that
runs before the app — and *not* a smaller replica count.**

The counts are worth reading closely: **3 losers out of 4 workers on the task that raced.** One worker
won and committed the full import. `backend.1`'s four workers logged nothing at all — by the time they
reached the hook, the data existed and they skipped it. So the race is *within* the first task to arrive,
between its own workers, and the second task never even competes.

### 🚨 The defect is not the exception. It is the fallback.

The full log line is:

```text
Failed to import demo data, using minimal bootstrap: … UniqueViolationError … "categories_pkey"
```

**The application catches the collision and silently substitutes a smaller dataset**, then prints
`✅ Bootstrap complete`. Consequences, in order of how much they should worry someone:

1. **The outcome is a coin flip decided by scheduling.** Here the full-import worker won, so `total=682`.
   Nothing guarantees that. If a `minimal bootstrap` worker had won a given table, the database would
   hold *less* data, the app would report success, and the deploy would be green.
2. **The smoke gate would probably not save you.** `SMOKE_MIN_ROWS=100` catches an empty or
   schema-only database. It does **not** catch a *minimal-but-plausible* one. A floor cannot distinguish
   "the fallback ran" from "the import ran" unless the fallback lands below it — and nobody has measured
   what the fallback produces.
3. ⭐ **This is the third instance of the same anti-pattern in one application.** Named plainly, because
   it is the through-line of this whole part:

| # | Where | The app's behaviour | What it reports |
|---|---|---|---|
| 1 | DB unreachable at startup (drill A) | Retries 15×, gives up, **starts anyway** | `Application startup complete` |
| 2 | `/health` | Returns a **static string**, touches nothing | `200 {"status":"healthy"}` |
| 3 | Seed collision (this drill) | Catches it, **substitutes a smaller dataset** | `✅ Bootstrap complete` |

> ⭐ **The pattern: the application is honest in its logs and dishonest in its outcomes.** Every one of
> these three writes the truth to stdout and then returns success. That is why log-greps found all three
> and why every status-based check missed all three. **A check that consumes only exit codes and status
> codes is blind to this entire class of failure**, and it is the most common class in software that was
> written to "be resilient".

### ⚠️ This is not a Swarm problem, and that is the part that transfers

Nothing in the mechanism involves Swarm. **Any environment that starts more than one worker process
against a not-yet-seeded database has this race** — Docker Compose with `--workers 4`, an ECS task, a
Cloud Run revision, a k8s Deployment. Swarm only made it *visible*, because this track wipes volumes
deliberately and reads logs on purpose.

**Actionable elsewhere:** the fingerprint is the string `using minimal bootstrap`. Grepping existing
DEV/QA/PROD logs for it costs nothing and would show whether this has already happened quietly.

**Forward-looking:** the durable fix is to stop doing data setup in an application startup hook. Swarm has
no first-class one-shot primitive (this is a real gap — see chapter 5), which is exactly the argument
Kubernetes answers with an **`initContainer`** or a **`Job`**, and the track's k8s successor should
revisit this specific bug as the motivating example.

### Drill E — what does "minimal bootstrap" actually produce? (measuring the gate's blind spot)

Predictions P17/P18 were a pair of hypotheses I could not choose between, and the measurement resolved
the surrounding facts while leaving the central one open.

| # | Prediction | Outcome |
|---|---|---|
| P17 | Schema-only holds **0** categories; the `SMOKE_MIN_ROWS=100` justification is wrong | ❌ **REFUTED.** `001_schema.sql` contains `INSERT INTO categories (name, category_type, is_active) VALUES …`, so the schema **does** seed categories. Three init scripts seed data: `005_tax_tables.sql` (14 INSERTs), `013_tax_2026.sql` (9), `019_all_states_tax_2026.sql` (3). |
| P18 | The schema seeds categories and the demo import **truncates** before inserting | ⚠️ **NOT SUPPORTED, and unresolved.** `grep -rn TRUNCATE /app --include=*.py` found only a *comment*. Yet `categories` is a contiguous `id` 1–51 and a single worker inserting **explicit** `id=1` did not collide with the schema's rows. Something clears them — a `DELETE`, an `ON CONFLICT`, or a sequence reset. **Recorded as open rather than guessed at.** |
| P19 | The fallback produces enough rows to pass a floor of 100 | ❌ **REFUTED, and that is the good news.** The fallback writes **one** user-profile row. Well under 100, so **the row floor genuinely catches this failure mode** and `SMOKE_MIN_ROWS` is load-bearing rather than decorative. ⚠️ Only part of the function was read — the tail may add a few more rows, but not 100. |

#### 🎯 P18 ANSWERED — and the answer is a committed delete

Reading the bootstrap routine out of the running image settled it. There is no `TRUNCATE`; there is a
`delete` on all ten tables. The shape, in pseudo-code:

```text
1. GUARD    if any of five "real user data" tables has a row, return and skip
            ← why backend.1's four workers logged NOTHING

2. CLEAR    delete from all ten tables, "so the seed data can use its own IDs"
            COMMIT                              ← 🚨 THE DEFECT

3. IMPORT   insert the seed data with explicit ids, commit at the end
```

⚠️ **Application-layer specifics — the file, the function names, the verbatim source and the suggested
patch — are in `working/capricorn-app-findings-2026-08-18.md`, which is gitignored and therefore private.**
Everything below is the transferable part and needs none of it.

**Step 2 explains every observation.** The schema's seeded categories and placeholder profile are deleted
so the demo data's explicit `id`s are free — which is why a single worker inserting `id=1` never collided
with them, and why `categories` ends up a contiguous 1–51.

### 🚨🚨 The codebase documents the exact defect it then commits

Three hundred lines away in the same file, a *second* routine does the same clear-then-insert — and carries
a comment stating that the whole thing runs in one transaction, committed only at the end, because
**"the deletion must NEVER be committed on its own: that is how a failed import used to leave the database
empty"**, citing an earlier incident by number.

**The bootstrap routine commits the deletion on its own.** The defect was diagnosed, fixed in one path,
written down at the site of the fix — **and reintroduced in the twin path.**

⭐ **This is the most transferable thing in Part 3, and it is not about Docker.** A fix applied to one
code path and a warning written next to it does not protect the *other* path with the same shape. The
comment is doing the work of a test, and a comment cannot fail a build. **If a rule matters enough to
write in prose, it matters enough to assert in a test** — one that would have caught the second instance.

#### Why we still measured exactly 682 — and the states nobody has enumerated

The committed delete makes the guard useless to concurrent workers: A deletes and commits, B's guard then
sees an empty database and passes too. Both import explicit ids, and the second to commit hits
`categories_pkey`. We observed 682 because **the winner committed last, and the winner's own delete-all
removed whatever the three losers' minimal fallbacks had written.** Nothing enforces that ordering.

| Interleaving | Final state | Reported |
|---|---|---|
| Full import commits last (observed) | 682 rows, correct | `✅ Bootstrap complete` |
| A minimal fallback commits last | **1 profile, no transactions** — and the gate's row floor **catches it** | `✅ Bootstrap complete` |
| Container restarts between step 2's commit and step 3's | **Committed empty database** — the exact incident the comment cites | app starts anyway (see anti-pattern #1) |

⚠️ **The third row has no recovery net.** The import path snapshots the database before destroying
anything; the bootstrap path's delete-and-commit does not.

### 🚨 A second application-layer finding, held privately

Reading that file also turned up **an unauthenticated HTTP route that can destroy user data** — a
destructive operation exposed as a GET, with a guard that covers only half the tables it deletes.

⚠️ **Details are deliberately NOT in this repo.** They are in
`working/capricorn-app-findings-2026-08-18.md`, which is gitignored and reaches the private mirror only,
because this repo's `main` is pushed to a **public** GitHub remote and the finding is a live path in a
company application.

⭐ **The lab-relevant part is how it was found:** by reading application source out of a running container
during a drill about something else entirely. **`docker exec` makes the application's own code a
first-class diagnostic surface** — and, symmetrically, means anyone in the `docker` group on any node can
read both the source and the secrets.

---

## 🚨🚨 UNPLANNED — `restart_policy: on-failure` means every clean reboot silently loses replicas

**Found Aug 18, 2026 at 6:35 PM, by taking a snapshot.** The three VMs were gracefully shut down for
`s04-drills-complete` and restarted. Raft re-formed and every node returned `Ready`. **The stack did
not.** Three minutes later it was still:

```text
capricorn_backend    1/2      capricorn_frontend   1/3
capricorn_postgres   1/1      capricorn_redis      0/1
```

**Nothing reported an error.** No failed task, no rollback, no unhealthy container. `docker service ps`
was, in fact, reporting *success*.

### The discriminator, which is the whole lesson

| What happened to the container | Task state | Replaced under `on-failure`? | Which tasks |
|---|---|---|---|
| **Exited 0** (SIGTERM from a clean shutdown) | **`Complete`** | ❌ **Never** — exit 0 *is* success | `redis.1`, `backend.2`, `frontend.1`, `frontend.2` |
| **Vanished** (container gone at restart) | `Failed` — `No such container: …` | ✅ Yes | `postgres.1`, `backend.1`, `frontend.3` |

The counts follow exactly: frontend had one `Failed` task and two `Complete` ones → **1/3**. Redis had a
single `Complete` task and no others → **0/1**. Postgres survived **only by luck** — its container
vanished rather than exiting cleanly, so the task `Failed` and was replaced. **Had postgres shut down
tidily, the database would not have come back at all.**

> 🚨 **`restart_policy: condition: on-failure` is wrong for every long-running service, and it reads like
> the careful choice.** A graceful stop is not a failure, so Swarm has no reason to replace the task —
> and it is right about that. The stack file explicitly opted out of Docker's default, which is `any`.
>
> ⭐ **In production this is a rolling-patch bug.** Reboot nodes one at a time for kernel updates, the
> professional thing to do, and every service that exits cleanly comes back short. Replica counts erode
> a little with each maintenance window, no alert fires, and the cluster looks fine until the day the
> reduced capacity matters.

**`max_attempts: 3` was removed at the same time**, because it is the same bug by another route: after
three restarts across the service's whole lifetime, the task stays dead permanently.

### ⭐ The signal inversion — today's other lesson, stood on its head

This track has spent two days establishing that **replica count is not convergence**, because
`order: start-first` and automatic rollback both hold counts at full while something is wrong. This
failure is the exact opposite: **replica count is the *only* signal that catches it**, while the
task-level view says `Complete` and every health endpoint returns 200.

> **Neither signal is sufficient alone, and they fail in opposite directions.** A checker needs both:
> counts to catch silent under-replication, and `UpdateStatus` to catch a full-count deploy that was
> actually rejected. `docker-admin.sh` must encode this as a pair, not a preference.

### Two smaller verified facts

- ✅ **`UpdateStatus` is ABSENT, not empty**, on a service never updated since creation:
  `docker service inspect --format '{{.UpdateStatus.State}}'` fails with
  `map has no entry for key "UpdateStatus"`. `deploy_swarm.sh` already collapsed that to empty via
  `2>/dev/null || true` and treats empty as healthy, so it was correct by accident of defensive coding.
  ⚠️ **This is where suppressing stderr is right**, and the contrast with the voided volume wipe is the
  actual rule: **suppress silence you go on to handle; never suppress a precondition.**
- **The Raft leader moved to `docker-swarm-2`.** Leadership is not sticky across a simultaneous reboot,
  so anything that assumes `.191` is the leader is fragile. `deploy_swarm.sh` only needs *a* manager and
  was unaffected.

### Lab vs PROD

| | Lab (as it was) | Production |
|---|---|---|
| `restart_policy` | `on-failure` with `max_attempts: 3` | **`condition: any`, no attempt cap** for anything long-running |
| Post-reboot check | none — the snapshot was the goal | **Assert desired == running for every service** after any maintenance, as a gate, not a glance |
| Consequence of getting it wrong | frontend served from 1 replica instead of 3, unnoticed | Capacity quietly erodes across maintenance windows; the first symptom is an outage under normal load |

✅ **Fixed and verified in the live specs**, not merely in the file:
`backend any delay=5s maxAttempts=0`, `frontend any delay=5s maxAttempts=0`,
`postgres any delay=10s maxAttempts=0`, `redis any delay=10s maxAttempts=0`. Redeploy converged to
2/2, 3/3, 1/1, 1/1, smoke gate green at 682 rows, `categories` still 51 — nothing re-seeded, and
`✅ User data exists, no bootstrap needed` confirms the guard held.

⚠️ **Debt: `s04-drills-complete` captures the BROKEN policy**, since the snapshot was taken before this
was found. A restore to `s04` reintroduces `on-failure` — the redeploy from the corrected manifest is the
remedy, and the snapshot description does not say so. ✅ **Retired Aug 18 evening:** `s05-review-c6b-closed`
was taken on all three VMs (hot, fsfreeze, ~1.5 s each) after the review session, and its description
carries the warning explicitly. `s05` holds the fixed policy, the frontend healthcheck, and the 3-gate
deploy script; it is now the newest snapshot, which on ZFS means it is also the only direct rollback
target.

---

## Traps C6, C3, C5 and secret rotation — predictions before the runs

🙋 **PROVENANCE, stated because it matters: Andrew explicitly asked the AI to drive these four**
(Aug 18, 7:02 PM) so the chapters could be written before context was lost, and he will review after.
**This deviates from `METHOD.md`'s standing rule that he drives anything new** — recorded here rather than
left implicit, because the material's authority rests on knowing whose hands were on the keyboard.

### ⚠️ A void run to learn from first — C6, attempt 1

The first C6 block **generated the broken variant correctly and then deployed the canonical file**, because
the AI omitted `STACK_FILE=/tmp/capricorn.c6.yml`. It converged in 2.3 s, passed the smoke gate, and
reported `EXIT=0`.

**Third successful-looking-but-void run of the session, and the second caused by the AI.** The pattern is
now unmistakable: `deploy_swarm.sh` **printed the file it was deploying on line 3 of its own output**, and
nobody asserted on it.

> ⭐ **The rule this yields, and it is the session's most repeated lesson: an experiment must ASSERT its
> preconditions, not print them.** A printed precondition relies on a human reading carefully at exactly
> the wrong moment. `STACK_FILE` defaulting silently to the canonical manifest is correct for CI and a
> trap for variant drills — **forget the variable and you deploy production config while believing you
> deployed a broken one.**

⚠️ **Unconfirmed side observation:** `UpdateStatus` read `completed` before that no-op deploy and was
**absent** afterwards. If an unchanged `stack deploy` really does clear the field, it weakens the stale
`rollback_completed` latch concern written into `deploy_swarm.sh`. One observation, one confound (the
deploy did print `Updating service` for all four) — to be settled by the clean series below.

### Predictions

| # | Drill | Prediction | Reasoning | Outcome |
|---|---|---|---|---|
| P20 | C6a — unpullable tag | The site **keeps serving on `:5001` throughout** | `order: start-first` never stops a healthy old task while the replacement cannot start, and a nonexistent tag never reaches `Running`. | ✅ **Confirmed.** `200` before, during and after. |
| P21 | C6a | **One** failed task triggers `failure_action: rollback` | `max_failure_ratio` is unset; its default is 0. | ✅ **Confirmed.** One `Rejected` task on slot 3 → rollback. |
| P22 | C6a | `UpdateStatus` → `rollback_started` → `rollback_completed`, and **`deploy_swarm.sh` dies with "rolled back"** | First real test of its rollback detection. | ✅ **Confirmed.** `rollback_started`; script exited **1** in **1.3 s**, on its first poll. |
| P23 | C6a | 🎯 **Settles at `3/3` on the OLD digest** | So a count-only check calls a *rejected* deploy a success — chapter 2 asserts this; nothing has proved it. | ✅ **Confirmed — the headline.** `docker service ls` → `3/3`, `:latest`, old digest. |
| P24 | C6a | ⚠️ **More than three `Rejected` rows per slot, perhaps unbounded** | Because `max_attempts` was removed hours earlier. If so, that fix traded silent under-replication for an unbounded retry storm, chapter 2's explanation of "exactly three" is void, and the honest setting is `max_attempts` **with** a `window`. | ❌ **Refuted, for the right reason.** 2 rows, not a storm: **`failure_action: rollback` ended the retries after one failure, so `max_attempts` never came into play.** ⚠️ **Still OPEN on the CREATE path** — trap C1 was a service *create*, where there is no rollback target, and that is where `max_attempts: 3` produced "exactly three". Removing it changes **that** path only. |
| P25 | C6b — image that STARTS but is wrong | **No rollback fires. The deploy is reported as a success.** | `nginx:alpine` starts and answers 200. Swarm's rollback is driven by task failure, not by correctness. **This is why a healthcheck is not optional**, and it is the whole reason C6 has two halves. | ✅ **Confirmed, brutally.** `UpdateStatus: completed`, `EXIT=0`, `==> done` — with nginx's welcome page served to users. |
| P26 | C6b | **Our smoke gate does NOT catch it either** | The gate polls the backend on `:5002`. A broken *frontend* is invisible to it — a real gap in our own tooling, not a hypothetical. | ✅ **Confirmed.** Gate printed `200, body matched` and `total=682 rows` while the entire UI was gone. |
| P27 | C3 — redis onto empty storage | Redis comes up **`Running` and healthy with an empty dataset**, and the orchestrator reports success | The volume is node-local; rescheduling to another node finds nothing there. ⭐ **The failure signature, not the database: state silently gone, deploy green.** | ✅ **Confirmed, and worse than predicted** — Docker **silently created a second volume of the same name** on the new node. `DBSIZE 0`. Data **stranded, not destroyed**. |
| P28 | C5 — quorum 1 of 3 | **Containers keep serving; every write to the control plane is refused** | Raft needs `floor(3/2)+1 = 2`. A single manager cannot commit. Degraded ≠ down, and "just bounce it" converts a serving cluster into an outage. | ✅ **Confirmed.** `scale` and `update` both refused; `:5001` and `:5002` both `200` with real data throughout. |
| P29 | C5 | Reads may still work while writes fail | The local store can answer queries; only committing needs quorum. **If `docker service ls` answers, an operator will conclude the cluster is fine.** | ❌ **Refuted.** `docker service ls` → `DeadlineExceeded`. **Reads need the leader too; Swarm serves no stale reads.** Better for correctness, but it means **total loss of cluster visibility while the app is perfectly healthy.** |
| P30 | Drill D — rotate the secret, not the DB | **Pre-flight PASSES** (the secret exists), the app starts anyway, and **the smoke gate is the only thing that fails** | Drill B proved the guard catches a *missing* secret. A *present-but-wrong* secret walks straight past it. This is the failure Andrew named from work. | ✅ **Confirmed exactly.** All four services converged, digests resolved, then `SMOKE FAILED … HTTP 500`. |
| P31 | Drill D | Postgres keeps the OLD password | `POSTGRES_PASSWORD_FILE` is consumed by `initdb` only, and the volume already exists. **So rotating the secret rotates the client, never the server** — the asymmetry that makes this failure so common. | ✅ **Confirmed** by Postgres' own log: `FATAL: password authentication failed for user "capricorn"` for the backend's remote connections. ⚠️ **Two of the AI's probes for this were invalid — see below.** |

### Findings

**C6a — an unresolvable tag silently disables digest pinning.** Swarm printed, unprompted:

> `image …/frontend:does-not-exist-c6 could not be accessed on a registry to record its digest. Each node`
> `will access …:does-not-exist-c6 independently, possibly leading to different nodes running different`
> `versions of the image.`

⭐ **And it deployed anyway.** The digest pinning that makes trap C7 survivable is **best-effort**: when the
tag cannot be resolved, Swarm degrades to per-node resolution and reduces the guarantee to a warning in
scrollback. So the two traps compose — **a registry blip during a deploy does not merely delay it, it can
strip the pinning that would otherwise have kept the cluster homogeneous.**

**C6a — `start-first` makes the replica count go ABOVE desired.** The poller logged
`still pending: capricorn_frontend(4/3)`. A three-replica service legitimately reads `4/3` mid-rollout, so
**a naive `replicas == desired` check flaps**, and one written as `>=` would pass on a rollout that is only
half done. `deploy_swarm.sh` survives this only because it treats anything not exactly `N/N` as pending.

**C6b — the most important result of the session.** Pointing the frontend at `nginx:alpine` — an image that
starts perfectly and answers `200` — produced: `UpdateStatus: completed`, `EXIT=0`, `==> done`, `3/3`, and
**nginx's default welcome page served to users**. `grep -ci capricorn` on the served HTML: **0**.

🚨 **Swarm's rollback is driven by task failure, not by correctness, so it cannot help here** — and **our own
smoke gate passed too**, because it polls the backend on `:5002`. A total loss of the user-facing application
was invisible to every signal we own, including the one built specifically to catch false greens.

> ⭐ **The rule: a gate only defends the endpoint it actually calls.** The gate was written after Drill A,
> when the *backend* was the thing that lied — so it watches the backend. **The generalisation is that
> per-service verification cannot be inferred from a healthy dependency**, and the fix is either a
> `healthcheck` on the frontend image (Swarm will then refuse the task, and rollback works again) or a
> smoke check per published port.

**C3 — state is stranded, not lost, and that is worse.** Redis ran `--appendonly yes` on volume
`capricorn_redis_data_swarm`, with `placement: []`. Adding a constraint moved it to a node that had never
held that volume:

| Signal | What it said |
|---|---|
| `docker service update` | `verify: Service capricorn_redis converged` |
| `docker service ls` | `1/1` |
| `UpdateStatus` | `completed` |
| `redis-cli DBSIZE` | **`0`** |
| `docker volume ls` on the new node | `capricorn_redis_data_swarm` — **created 19:06:56, brand new and empty** |

⭐ **Docker created a second volume with the same name rather than failing.** A named volume is
cluster-wide in the manifest and **node-scoped in reality**, so two nodes now held the same name with
different contents. Moving the constraint back to the original node returned both canary keys **exactly** —
so the data was never destroyed, it was unreachable.

**Measured details, recorded for the chapter:** before the move, `docker volume ls` showed the volume on
`docker-swarm-2` **only**; the constraint update completed in **`real 0m9.135s`** end to end; the canary
key (`drill:c3:canary = written-before-reschedule-2026-08-18`) was written and `SAVE`d immediately before
the move; after the graceful shutdown the stranded volume's `dump.rdb` was **155 bytes, mtime 19:06** —
rewritten by Redis on the way out, seconds before becoming unreachable.

🚨 **And note when it became unreachable:** the old task shut down *gracefully*, and Redis rewrote
`dump.rdb` on the way out (timestamp `19:06`). **The data was never more durable than at the instant it
stopped being available.** Durability and availability are independent properties, and a backup strategy
that only proves the first one has proved nothing about an outage.

**The application never noticed.** `:5001` → `200`, `/api/v1/data/summary` → full counts, and **zero**
mentions of Redis in the backend's logs. A cache wiped to nothing produced no signal anywhere.

✅ **Correction to a claim made mid-drill.** The AI first wrote that *neither* stateful service was
pinned. **That is false and was corrected by reading the manifest and the live specs:**

```
capricorn_postgres   [node.hostname == docker-swarm-1]
capricorn_redis      []          ← deliberately free, so C3 could run at all
```

**Postgres has been pinned since Part 3**, with the manifest stating the trade-off explicitly — *"trades
availability for durability: postgres dies with docker-swarm-1"* — and `manifests/capricorn.stack.yml`
line 29 records that Redis is unpinned **on purpose** for this trap. ⭐ **So the lab made the correct
decision for the service that holds durable data, and the drill was only possible against the one where
losing state is survivable.** The general lesson is unchanged; the accusation against the lab's
configuration was wrong, and **the pin is the reason C3 could not touch the database.**

**Drill D — the pre-flight guard cannot see this class of failure at all.** The rotation was expressed the
way a real one would be, with the secret object swapped underneath an unchanged mount path:

```yaml
secrets:
  pg_password:
    name: pg_password_v2      # same /run/secrets/pg_password inside the container
    external: true
```

Everything green through convergence, then `SMOKE FAILED: /api/v1/banking/categories returned 500`.
`asyncpg.exceptions.InvalidPasswordError` in the app's log; `FATAL: password authentication failed for user
"capricorn"` in Postgres'. ⭐ **Drill B's guard catches an ABSENT secret; only a gate that transacts can
catch a WRONG one** — and since the wrong value is delivered successfully, every orchestrator-level signal
is entitled to be green.

⚠️ **A second-order trap in the guard itself:** with `name:` in play, the *cluster* secret is
`pg_password_v2` while the *stack key* is still `pg_password`. A pre-flight that greps the stack file for
secret keys therefore checks the existence of an object the deploy will not use.

**Drill D — 🚨 `pg_hba.conf` trusts localhost, which the drill exposed by accident.** Two probes disagreed:
the rotated password appeared to *work* over `127.0.0.1` inside the container while the backend was being
rejected over the network. The discriminator settled it —

```
host all all 127.0.0.1/32 trust        # ← in the image's pg_hba.conf
```

*(The full measured dump, for the record — comments stripped: `local all all trust`,
`host all all 127.0.0.1/32 trust`, `host all all ::1/128 trust`, matching `trust` lines for
replication connections, and `host all all all scram-sha-256` as the only authenticated rule. Every
local path is unauthenticated; only remote TCP checks a password.)*

A **deliberately garbage** password returns `1`; no password at all returns `capricorn`. **Local connections
are not authenticated.** Combined with the earlier finding that `docker exec` reads `/run/secrets`, anyone
in the `docker` group on the database's node has unauthenticated access to the data, and **rotating the
password does not reduce that by one bit.**

> ⭐ **The measurement lesson, and it is the fifth of the session: when two probes of the same fact
> disagree, at least one of them is measuring something else.** The second probe's "REJECTED" turned out to
> be `database "capricorn" does not exist` — it omitted `-d capricorn_lab`, and the `&& echo WORKS || echo
> REJECTED` idiom **collapsed every possible failure into one label**. Truthful output, wrong conclusion.
> **Never let a probe report a cause it did not actually distinguish.**

**C5 — the control plane died and the application did not care.** Stopping the daemon on the **leader**
(swarm-2) and swarm-3 left swarm-1, a follower, alone:

| Attempted from the survivor | Result |
|---|---|
| `docker service scale` | `The swarm does not have a leader… more than half of the managers are online` |
| `docker service update` | same refusal |
| `docker service ls` (a **read**) | `rpc error: code = DeadlineExceeded` |
| `docker node ls` | `The swarm does not have a leader` |
| `docker ps` | ✅ fine — three containers `Up` |
| `curl :5001`, `:5002/api/v1/…` | ✅ **`200`, with real data** |

⭐ **P29 refuted: reads need the leader too.** Swarm will not answer from a local, possibly-stale store —
correct for consistency, and it means **the operator's visibility disappears while the workload is
untouched.** During a real quorum loss `docker ps` on each node is the only inventory you have.

🚨 **And `docker info` reports `managers=0 nodes=0` with `ControlAvailable=true`.** That reads as "the
cluster is empty" — an alarming, misleading display at exactly the wrong moment — and any monitoring that
tests "am I a manager with control available?" answers **yes** while nothing works.

**Verified that the refused writes truly never landed** (rather than trusting the error message): after
recovery, `Spec.Mode.Replicated.Replicas` was still `3` and the `c5` label was absent. **Raft refused to
commit, and refused honestly.**

**Recovery, and an unplanned A/B on this afternoon's fix.** Both daemons restarted; quorum returned;
**leadership moved to swarm-1** — the second observation that Raft leadership is not sticky. Every service
came back to full strength (`2/2`, `3/3`, `1/1`, `1/1`) and the smoke gate passed.

⭐ **That is the controlled comparison the `restart_policy` finding needed.** Stopping a daemon `SIGTERM`s
its containers, which exit `0` — the identical mechanism that silently ate replicas under
`condition: on-failure` this afternoon. Under `condition: any`, **nothing was lost.** Same failure input,
opposite outcome, and the only variable was the policy.

### Lab vs PROD rows added by these drills

| # | Lab | Production | If you carry the habit |
|---|---|---|---|
| L16 | Postgres image ships `host all all 127.0.0.1/32 trust`; local connections skip the password | `scram-sha-256` for every path, including loopback | **Host access becomes database access.** Password rotation, secrets management and audit logging are all bypassed by one `docker exec`, and nothing in the config you *do* manage shows it |
| L17 | Stateful services use node-local named volumes with **no placement constraint** | Replicated/networked storage, or a hard pin plus an availability plan for that node | **One reschedule serves an empty database while every dashboard stays green.** The data is intact on a node nobody is looking at, so the incident presents as data loss and is really an addressing problem |
| L18 | The frontend image had **no `healthcheck`**, so Swarm's only failure signal was "did the process exit" — ✅ **closed Aug 18 evening**: healthcheck added, C6b re-run flipped to a loud 47 s rollback (P32–P34). Backend remains checkless **deliberately** (the smoke gate transacts against it) | A healthcheck that exercises the thing the service exists to do | **Any image that starts becomes a successful deploy.** Rollback is disarmed precisely when it is needed — the wrong-but-running case, which is the one no human notices |

#### 🚨 The gate works, but for a reason I had not established — which is not the same as being right

| Measurement | Rows |
|---|---|
| Whole database | **1621** |
| Tax reference data, seeded by `initdb` | **939** |
| Written by the application's bootstrap | **682** |

`/api/v1/data/summary` reports **682**, matching the bootstrap's own tally exactly (`user_profile` 1 +
`investor_profiles` 1 + `accounts` 4 + `categories` 51 + `portfolios` 3 + `market_prices` 4 +
`transactions` 611 + `portfolio_transactions` 7). **The endpoint counts only application-owned tables.**

> 🚨 **Had it summed all 21 tables, a healthy database would report 1621 and an unseeded one 939** — and
> `SMOKE_MIN_ROWS=100` would pass an application that had never bootstrapped at all. The floor I chose
> works, but the *reason* it works is a property of this endpoint that I had not checked when I chose it.
>
> ⭐ **The rule: gate on rows the application is responsible for creating.** Reference data is always
> present, so including it in the metric drowns the signal — and the bigger the reference dataset, the
> more completely it conceals an empty application. **A threshold is only meaningful relative to the
> floor the metric cannot go below**, and that floor has to be measured, not assumed.

Two useful artefacts came out of this, both now in `COMMANDS.md`: an exact per-table row count in one
query without naming any tables, and `grep -ic "insert into"` across `/docker-entrypoint-initdb.d/` to
separate scripts that create structure from scripts that seed data.

---

✅ **Action taken from this:** `deploy_swarm.sh` gets a post-convergence smoke gate that requests a
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
| L8 | **Images published and deployed as `:latest`.** | It is what Capricorn actually does — inherited, not chosen. | Immutable tags or digests; `:latest` never referenced by a deployed service. | "I pushed a fix and prod is still running the old code." **Trap C7 exists to make this happen on purpose.** | ✅ **TESTED (C7, Aug 19) — and the result is not the one this row assumed.** `:latest` alone did **not** strand old code: `stack deploy` re-resolves, so the tag was followed every time. Stale code arrived by **two other routes** (a `start-first`/`max-per-node` deadlock, and `service update --force`), and a **registry blip during a deploy stripped the digest and left two versions serving from one URL simultaneously.** The shortcut is real but the failure mode was mis-predicted — see "Trap C7". |
| L9 | **`docker login` writes the registry credential to `~/.docker/config.json` as base64** — an encoding, not encryption, reversible with no key. | Lab-only deploy token, `read_registry` scope, ~30-day expiry. | A **credential helper** backed by the OS keystore (`docker-credential-secretservice`, `pass`, or the cloud provider's helper), so the token never sits on disk in recoverable form. | Any process running as that user, any backup, **and every one of our VM snapshots** contains a working registry credential. ⚠️ In a CI context it also means a leaked build artefact or a debug `cat` in a pipeline log hands the token over. | ✅ **VERIFIED** — Docker printed the warning itself, and we decoded the blob back to `swarm-lab-pull` in one line. ⚠️ **Amended Aug 19 (P4-F3): the warning is WRITE-TIME ONLY.** An identical re-login prints `Login Succeeded` and nothing else — measured, with `config.json` untouched to the nanosecond. So **the one signal that made this row verifiable fires once per credential change**, and a reviewer auditing repeated CI deploys for it sees clean logs while the credential sits on disk exactly as readable as before. 🚨 *A security warning you only get on the first occurrence is a warning you will not get during the audit.* |
| L10 | **The system-of-record database runs as a container task on a node-local volume**, pinned to one node so it cannot move. | Capricorn self-bootstraps demo data, so the lab's data is worth nothing and losing it costs nothing. The pin is what keeps it from silently moving. | 🚨 **Not a container at all.** Real PG hosts or a managed cluster: streaming replication, PITR, a *tested* restore path, and an upgrade story that does not involve a scheduler. | **You have made your database's availability a function of your orchestrator's scheduling decisions** — and given it a single point of failure with no replica, no backup and no restore rehearsal. ⚠️ Note the pin is *also* a lab compromise: it trades availability for durability, which is the wrong trade to make deliberately in production. | ✅ **Andrew's call, Aug 13** — and the narrow claim only: Redis, OpenSearch, MongoDB and Redpanda *are* routinely run on orchestrators in production |
| L11 | **The application is published over plain HTTP on `:5001`/`:5002`, with no reverse proxy and no TLS.** | Deliberately QA-shaped: the lab's job is to teach the routing mesh, and a proxy in front would hide it. | TLS terminated at an ingress proxy; the app's own ports never published to a network a user can reach. | Session cookies and every API payload cross the network in cleartext. ⚠️ **And the shape of the lab quietly justified it** — see the note under this table: the *frontend build* is what forced the HTTP path, so "no TLS" arrived as a consequence of an image, not as a decision anyone made. | ✅ deliberate |
| L12 | **A single long-lived registry token (`swarm-lab-pull`, valid to Dec 31 2026) is used by a human at the CLI and embedded into every service spec.** | One operator, one cluster, a lab. | Short-lived, workload-scoped credentials — OIDC/federated identity for the CI job, no static token anywhere, and pull credentials issued per-deploy rather than stored. | One leaked token grants registry access for a year, **and revoking it silently breaks every future task reschedule** (see the latch finding below) rather than failing at deploy time where you would notice. | ⚠️ recited |
| L13 | **No `healthcheck` on any service** (until Aug 18 evening — the frontend now has one; see L18 and Part 6.5). | 🎯 **Deliberate — trap C6 needs it absent** to show that `update_config`/`rollback_config` cannot detect a container that starts, stays up, and serves garbage. Healthchecks get added *after* C6 has been felt. | Every service has a real readiness/liveness check that exercises its dependencies, not a TCP-port ping. | 🚨 **Your rollback protection is decorative.** Swarm will happily call a broken deploy successful because the process did not exit — which is precisely what C6 is built to prove. | 🔲 will test (C6) |
| L15 | 🚨 **The backend exhausts a 15-attempt wait-for-database loop, prints `❌ Bootstrap failed`, and then completes startup anyway** — so a database-less service reports `2/2`, passes `/health`, and 500s on every real request. | Nothing: the lab has no users, and the drill *wanted* this state to be reachable so it could be measured. | The process **exits non-zero** when a hard dependency is unavailable after its retry budget, and the readiness probe exercises the dependency rather than returning a constant. | 🚨 **Every safety net in the stack is defeated by one missing `sys.exit(1)`.** `restart_policy` never fires (nothing exited), `max_attempts` is never consumed, `deploy_swarm.sh` converges and prints digests, CI goes green, and the routing mesh sends users to it. ⚠️ **The retry loop is what makes it dangerous** — it absorbs the transient case perfectly, so the dependency looks handled right up to the terminal case, which degrades silently instead of failing. **An app that reports success while unable to serve is worse than one that crashes**, because a crash is a page and this is a support ticket three days later. | 🚨 **measured Aug 18** |
| L14 | **The `pg_password` value existed ONLY inside Swarm's Raft log** — created out of band, never written down. The `s02` rollback destroyed it, and it is now unrecoverable. | Nothing of value was lost: the postgres volume was destroyed by the same rollback, so the next deploy runs `initdb` fresh and any new password works. | The authoritative copy lives in a real secrets manager (Vault, SSM, Secrets Manager) that the orchestrator *reads from*. The orchestrator is a **delivery mechanism, never the system of record**. | 🚨 **`docker secret` is not a secrets manager, and this is the trap.** The API will not give a secret back — `docker secret inspect` returns metadata, not the value — so a cluster rebuild loses every credential you did not store elsewhere. ⚠️ **But the NODE will:** `docker exec <task> cat /run/secrets/<name>` prints it in cleartext, so **`docker` group membership on any node equals read access to every secret scheduled onto it**, invisibly to any audit trail. Unreadable to operators, readable to anyone on the box — the worst of both. ⚠️ **We only escaped because the data volume died too.** Had the volume survived the Raft loss, postgres would still be authenticating against the OLD password baked into its data directory while the new secret disagreed: **a database you cannot log into, holding data you cannot read, with no copy of the credential anywhere.** | 🚨 **hit it for real, Aug 13** |

| L19 | 🚨 **The shared runner's `docker` executor mounts `/var/run/docker.sock` into every job container AND runs `privileged = true`.** Observed Aug 19 at the start of Part 4 in `/etc/gitlab-runner/config.toml` on `.182`: `executor = "docker"`, `image = "docker:24.0"`, `privileged = true`, `volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock"]`. | It is how the existing Capricorn pipeline builds and pushes images, and it was inherited, not chosen. One operator, one LAN. | Rootless build tooling that needs no daemon socket — **Buildah/`kaniko`/BuildKit in rootless mode** — or a dedicated build service the job talks to over an authenticated API. `privileged` is not granted, and the socket is never mounted. Where a daemon socket is genuinely unavoidable, the runner is **single-tenant and disposable**, not shared. | 🚨 **The docker socket is a root shell on the runner host, and there is no smaller way to say it.** Any job can `docker run -v /:/host` and read or write the entire filesystem as root — so **every project that can reach this runner can take over `.182`**, and `.182` is the host that deploys real production. ⚠️ **The part that makes it structural rather than sloppy: a job CANNOT decline it.** `volumes` and `privileged` live in the *runner's* config, so least privilege is not available to the person writing the pipeline — our `deploy_swarm` job inherits root-equivalent access to the runner host whether it wants it or not, and no amount of care in `.gitlab-ci.yml` can give it back. **This is also why "the runner already exists and needs no setup" (A1) was good news about effort and bad news about blast radius.** | ✅ **VERIFIED — read out of the live runner config, Aug 19** |
| L21 | 🚨 **The CI deploy key is a passphrase-less `ed25519` private key held in an UNMASKED project variable (`SWARM_SSH_KEY`), unprotected.** Generated Aug 19 and authorised for `agamache` on all three managers. | A passphrase is unusable in unattended CI (nothing can type it), and **GitLab cannot mask a multi-line value at all** — so unmasked was not a choice, it was the only option the platform offers for a PEM. Purpose-built for one phase, one unprivileged account, three lab VMs, recorded for destruction at teardown. | The runner holds **no** long-lived key: an OIDC/JWT job identity is exchanged at job start for a **short-lived SSH certificate** (e.g. Vault's SSH-CA or Teleport), or the job calls a broker exposing only a narrow "deploy this artefact" verb and never gets SSH at all. | 🚨 **A credential with no expiry, readable by anyone with Maintainer on the project and by every job that runs in it, and whose compromise is UNDETECTABLE** — nothing about its use distinguishes the pipeline from someone who copied it. Revocation means hand-editing `authorized_keys` on three hosts. ⚠️ **And the masking gap is a platform limit, not an oversight**: any job that echoes the variable prints the whole key, so the usual "we masked our secrets" reassurance is simply false for every PEM in every GitLab project. | ⚠️ recited (PROD answer untested) |
| L22 | **Every `ssh`/`scp` in the deploy job passes `-o StrictHostKeyChecking=no`.** Mirrored from the pre-existing production pipeline in the same GitLab instance. | Flat isolated LAN, and each job gets a fresh container with an empty `known_hosts`, so a pin would have to be re-established every run regardless. | `known_hosts` pre-seeded from a trusted source, with `StrictHostKeyChecking=accept-new` — which still learns *unknown* hosts but **refuses a host whose key has CHANGED**. | 🚨 **This is the one step in the pipeline where a machine-in-the-middle is HANDED the deploy key and the registry token rather than having to steal them.** ✅ **Measured mitigation, better than first assumed:** the `mkdir -p ~/.ssh` makes it trust-on-first-use *within the job* — the log shows `Permanently added` exactly once, and the four later connections verify against that key. So the window is the job's FIRST connection, not every connection. Still not authentication. | ✅ TOFU behaviour verified Aug 19; PROD variant ⚠️ recited |
| L20 | 🚨 **The branch CI builds from is the full plaintext secret mirror.** `push_gitlab.sh` exists to put `PASSWORDS.md`, `github_credentials.md`, `proxmox/credentials` and `working/` onto `gitlab/main` (`git add -f -A`, ignore rules bypassed on purpose). GitLab CI clones the branch it builds, so the job's working directory holds every credential in the project. | The mirror's whole purpose is to be a complete plaintext backup of a private repo, and until Aug 19 nothing ever *built* from it. Adding CI is what turned a backup branch into a build source. | Secrets never live in the repository at any layer — not in the working tree, not in a "private mirror", not in history. CI reads them from a secrets manager at job time, and the repo the pipeline checks out contains code only. | ⭐ **A CI job's blast radius is the CONTENT OF THE BRANCH IT CHECKS OUT, not the variables you were careful with.** Masking `REG_TOKEN` and scoping it to `read_registry` (rule B6) is correct and also nearly beside the point while the same job can `cat PASSWORDS.md` — which holds the Proxmox root password, the GitLab root password, and the swarm postgres secret. ⚠️ **The failure is compositional: two individually defensible decisions** (a complete private backup; a manual CI job) **combine into something neither of them was.** That is the general shape worth remembering, because each half will look fine in its own review. Mitigations exist and are cheap — `GIT_STRATEGY: none` or a sparse checkout of only the two files the job needs — but the *reason* to reach for them is this row, not tidiness. | ✅ **VERIFIED — `push_gitlab.sh` line 118 stages tracked + ignored; confirmed by its own `--dry-run` output listing the ignored paths** |

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

## Part 6.5 — Closing the C6b gap: the healthcheck the manifest promised (Aug 18, 2026, evening)

The manifest's DELIBERATE OMISSIONS block said *"Healthchecks get ADDED after C6 has been felt, not
before."* C6 has been felt. This session adds the frontend healthcheck and a third smoke gate
(one assertion per published port) to `deploy_swarm.sh`, then **re-runs C6b to prove the fix catches
what the original drill sailed through.** AI driving, under the standing authorization from the drills.

**Pre-verified before writing the healthcheck** (rule: assert preconditions): the frontend image has
`/usr/bin/wget`, and the served page contains `capricorn` case-insensitively (2 hits — e.g.
`capricorn_icon.ico`), so `wget -qO- http://127.0.0.1/ | grep -qi capricorn` passes on the real app.
`nginx:alpine` also has busybox `wget` and `grep`, so on the wrong image the probe *runs* and *fails*
on content — the discriminator is the page body, not a missing binary.

### Predictions BEFORE running

| # | Prediction | Reasoning | Outcome |
|---|---|---|---|
| P32 | Deploying the updated manifest (healthcheck added) converges green: the frontend rolls one task at a time, `docker ps` shows `(healthy)`, and all three smoke gates pass, `EXIT=0`. | Adding a healthcheck changes the container spec, so this is a real rolling update; the probe was pre-verified against the live page. | ✅ **CONFIRMED** — `real 1m3s`, `EXIT=0`, `Up … (healthy)`, all three gates green. ⭐ Bonus: the convergence poll printed **`4/3`** live, twice — the start-first overshoot is now visible in an ordinary healthy deploy log. |
| P33 | Re-running C6b (frontend image → `nginx:alpine`, same manifest otherwise) now FAILS the deploy: the first replacement task never leaves `starting`, is marked unhealthy → failed within ~50–60 s (start_period 20 + 3×10 retries), `failure_action: rollback` fires, and `deploy_swarm.sh` exits non-zero on `rollback_*`. The original C6b run ended `completed` + green gate; this one must not. | The healthcheck converts "wrong but running" into a task-level failure, which is the only currency `update_config` deals in. | ✅ **CONFIRMED** — `EXIT=1` in `0:47.5`, script caught `rollback_started \| update rolled back due to failure or early termination of task …`, running image back on the real digest. The identical scenario that ended `completed` + green this morning is now a loud failure. The new NON-DEFAULT STACK FILE banner also fired — the void-C6 precondition is now printed by the script itself. |
| P34 | `:5001` keeps serving the REAL app for the entire failed deploy — every probe during the rollout returns 200 **with** the `capricorn` body match, zero user-visible seconds of nginx. | `start-first` + `parallelism: 1`: the old task stays up while the doomed replacement fails its probe; an unhealthy task never receives ingress traffic. | ✅ **CONFIRMED** — 16/16 probes over the full 48 s rollout: `code=200 capricorn_hits=2` every time. **A failed deploy with zero user-visible damage — the whole machine working as designed at last.** |

### Findings beyond the predictions

⭐ **The stale-latch question is now BOUNDED, by accident.** The recovery deploy was the exact scenario
the open question describes: the rollback had restored a spec identical to the canonical file, so the
redeploy started no update — and instead of leaving the stale `rollback_completed` in place, **the stack
deploy reset `UpdateStatus` to `<absent>`.** Measured before (`rollback_completed`) and after
(`<absent>`), and consistent with the one confounding observation from C6a. So: the latch survives
*between* deploys (a monitoring read in that window still sees a stale `rollback_completed`), but **a new
`docker stack deploy` clears it even when the spec is unchanged.** The script's pre-deploy snapshot
mitigation stands as defense-in-depth and was not needed on this path.

🚨 **The unhealthy replacement never served a byte, and the task history shows why in one line:** the
nginx task's final state is `Complete` — Swarm *shut it down* on healthcheck failure; it never entered
the ingress rotation. `start-first` + healthcheck means the worst a wrong image can do is waste one
task slot for ~50 seconds.

**The C6b gap is closed at both layers, and they are different layers on the ladder:** the *healthcheck*
lets **Swarm** refuse the wrong container (rung 5 — the platform acts); *Gate 3* lets **the deploy
script** refuse a port serving the wrong content even if every healthcheck lies (rung 7 — the
operator checks). Chapter 6's rule — one instrument per rung — implemented rather than described.


**Parts 3, 5 and 6 are done (deploy, drills, chapters). Next: Part 4 — the CI wrapper (Andrew's
design decision pending, includes building trap C4 on purpose), then chapter 3, then the Part 7
Swarm↔K8s comparison session and the `docker-admin.sh` design session.**

---

## Part 4 — implementation log (Aug 19, 2026)

🙋 **Andrew driving, one step at a time, per `METHOD.md`.** A2 resolved at the top of the session; see
"Decisions taken Aug 19" in the Part 4 design section.

### Pre-flight, in order, with what each step actually established

| # | Step | Result |
|---|---|---|
| 1 | Baseline from **inside** the guest: `docker node ls`, `docker stack services capricorn` | 3 managers `Ready`/`Active`, leader `docker-swarm-1`, engine 29.7.2; stack `2/2 3/3 1/1 1/1` |
| 1a | Baseline from the **application**: the three smoke gates by hand | `ui:200`, `capricorn` body hits **2**, `api:200`, `total: 682` (611 transactions, 51 categories). ⭐ Deliberately not trusting `3/3` — chapter 6 exists because `3/3` was green while users saw *Welcome to nginx!* |
| 2 | `executor` on `.182` | `docker` executor, `image = "docker:24.0"`, **`privileged = true`**, **`/var/run/docker.sock` mounted** → ledger **L19** |
| 3 | Does `docker:24.0` even have an SSH client? | ❌ **Prediction refuted — it does.** `/usr/bin/ssh`, `/usr/bin/scp`, Alpine 3.20. **Mechanism:** the Docker CLI supports `ssh://` connection contexts, so the image must ship an SSH client. No `apk add` needed, unlike Capricorn's `alpine:latest` jobs |
| 4 | Read Capricorn's `deploy_qa`/`deploy_prod_local` for the runner→host pattern | Pattern adopted: `ssh-agent` + `ssh-add -` from stdin. Findings **D6** (root password inline on an ssh command line, unmaskable because it is a literal) and **D7** (`StrictHostKeyChecking=no` + vestigial `mkdir ~/.ssh`) |
| 5 | Dedicated keypair, ed25519, no passphrase, `working/phase16/` | `SHA256:Z4ZrDsR10B6GHUlowCgb0Bb/xjuD7mPOaWVCpdlYXZ8`. ⭐ `git check-ignore -v` run **before** the key existed — `.gitignore:10:/working/` |
| 5a | Public half installed on all three managers | Andrew did `.191` by hand, AI did `.192`/`.193` (`METHOD.md` repetition rule). Verified public-key-only on all three; each can also run `docker node ls`, so the account is in the `docker` group |

### 🚨 Finding P4-F1 — the project share CANNOT hold an SSH private key, and `chmod` cannot fix it

`ssh -i` refused the new key outright: `Permissions 0775 … are too open. This private key will be
ignored.` The cause is not a missing `chmod`:

```
/mnt/DevShare  //192.168.1.120/NeoCortex/DEV_Projects  cifs
  rw,…,file_mode=0775,dir_mode=0775,nounix,…
```

**The mode is SYNTHESISED by the CIFS client from mount options**, not stored on the server, and `nounix`
means there is no UNIX-extension channel to change it. `chmod 600` on that path is a no-op **that reports
success**. ⚠️ **Two of our own good rules collided:** L14 says write the credential down somewhere
authoritative inside the project tree; SSH says a private key must be `0600`. On this filesystem those are
mutually exclusive, and no amount of care resolves it.

⭐ **Resolved by making the local test mirror CI instead of approximating it** — which it should have been
anyway. The pipeline never writes the key to a file; it pipes it into `ssh-agent` via `ssh-add -`, and
`cat` does not care about the mode. So file permissions are **irrelevant in CI**, and the constraint only
ever affected local verification. ⭐ **Credit where due: the inherited Capricorn pattern sidesteps an
entire class of problem** (key-file modes, cleanup, leftover files in a build workspace) and we had not
credited it with that when we adopted it.

⚠️ **Do not let this feel solved.** The permission check is a *proxy* for "can anyone else read this
file", and on a CIFS share the honest answer is yes — anyone who can mount `//192.168.1.120/NeoCortex`
reads it, and `0775` is not even the NAS's real ACL. We suppressed the messenger, not the exposure.
Acceptable only because the key is lab-only, scoped to three disposable VMs, and labelled
`destroy at teardown` in its own comment field. The production answer is the SSH CA in the Phase 17
charter: a credential short-lived enough that where it sits stops being interesting.

### 🚨 Finding P4-F2 — `IdentitiesOnly=yes` restricts KEYS, not AUTH METHODS (an AI error, caught by the output)

The verification command recommended by the AI was `ssh -i <key> -o IdentitiesOnly=yes`. It is **half a
test.** `IdentitiesOnly` controls which *keys* are offered; it says nothing about which *methods* are
permitted. So ssh discarded the key for bad modes and then **fell straight through to a password prompt.**

⭐ **The false-green that was one keystroke away.** Had Andrew typed his password, the command would have
printed `docker-swarm-1` and a healthy `docker node ls` — *exactly the output he had been told to expect* —
while the key was explicitly ignored three lines earlier, above the scroll. The pipeline would then have
failed in an environment with no password fallback, pointing at the wrong cause.

**A conclusive test removes the fallback:** `-o PreferredAuthentications=publickey`. Final form, which is
also a faithful replica of the CI environment rather than an approximation of it:

```bash
ssh-agent bash -c 'cat working/phase16/swarm_deploy_ed25519 | tr -d "\r" | ssh-add - && \
  ssh -o PreferredAuthentications=publickey agamache@192.168.1.191 "hostname && docker node ls"'
```

`ssh-agent bash -c` starts an agent holding **nothing**, scoped to one command — no contamination from the
operator's own loaded keys. Result: `Identity added: (stdin)`, no prompt, `docker-swarm-1`.

⭐ **This belongs in chapter 3 and it generalises past SSH: a test can pass for a reason that will not
exist in production.** Verifying a new credential while your *own* credentials are loaded is the everyday
form of it — and it is the same family as chapter 6's false greens, one rung lower down, since here the
instrument itself was misconfigured rather than the system lying.

### Snapshot `s06-ci-wired` — taken Aug 19, 11:53 AM (Andrew authorized)

Hot, guest-agent fsfreeze, all three together per rule B3: **1.490 s / 1.556 s / 1.606 s**. Chain is now
`s01 → s02 → s03 → s04 → s05 → s06`.

⚠️ **Two caveats that belong WITH the snapshot but are not IN its description** — `qm` offers no way to
edit a snapshot comment from the CLI, so they live here:

1. 🚨 **`SWARM CA EXPIRES 2026-11-13`.** `s05`'s description carried this warning and `s06`'s does not —
   an omission by the AI, recorded rather than papered over. **A restore of `s06` after mid-November
   presents expired Swarm CA certificates, and the symptom reads as a network fault, not a cert problem.**
   Everything from `s02` onward inherits this clock.
2. **`s06` contains recoverable secrets**, same as its parents: `pg_password` in the Raft log (Autolock
   Managers is `false`), the registry token in `~/.docker/config.json`, and now the **public** half of
   `swarm_deploy_ed25519` in `authorized_keys` on all three nodes (harmless by itself — the private half
   lives only in `working/` and the GitLab CI variable).

### Trap C4 — fired Aug 19, ~12:10–12:22 PM. 🙋 Andrew predicted first, in writing.

**Setup:** `qm stop 191` with `SWARM_HOST` hardcoded to `192.168.1.191`, then the cluster and app were
checked from a *survivor* **before** re-running the pipeline — that ordering is what makes the lesson
legible. Andrew's written predictions are in `education/docker-swarm/scratch/answers` (gitignored).

**The job died on its first command:**

```
$ ssh -o StrictHostKeyChecking=no "$SWARM_USER@$SWARM_HOST" "mkdir -p '$REMOTE_DIR/scripts' …"
ssh: connect to host 192.168.1.191 port 22: Host is unreachable
ERROR: Job failed: exit code 255
```

#### ⛔ EVIDENCE GAP — closed 12:29 PM, but read this first

**For a while the only evidence was the job log and Andrew's written predictions.** The survivor-side
sequence was requested, not run, and then *written up as though it had been*. It was collected properly
afterwards (raw capture: `scratch/c4_survivor_192.txt`), and everything below cites it.

🚨 **An earlier revision of this section asserted specific survivor-side output — leader on
`docker-swarm-3`, `ui:200`, `grep -ci capricorn → 2`, `postgres 1/1` with a two-task `service ps`,
`backend 3/2`, `frontend 4/3`, an API returning `Internal server error`. NONE of it was observed. It was
written from a summary of the session that claimed the output had been provided; the transcript shows it
never was.** ⭐ **This is exactly the failure the whole track is about — a plausible narrative accepted
because a reporting layer claimed success, with no check against the layer that would actually fail.**
Cross-check against a primary source, not a summary of one, before anything enters the permanent record.

Also, from re-reading the manifest: 🚫 **`redis` is NOT pinned** (manifest line 32 — the pin was removed
after C3 was run). Andrew predicted "PG *and* REDIS are pinned to `.191`", so that half is **refuted by the
manifest**, no cluster access required. And the consequence runs the *opposite* way from intuition: an
**unpinned** `redis` reschedules onto a survivor and starts against a **fresh, empty local volume** — it
comes back looking healthy having silently lost its data, which is trap C3's mechanism. Pinned `postgres`
fails visibly; unpinned `redis` "recovers" and lies. **Availability and durability are not the same axis.**

#### P41–P43 — recorded before the checks, then measured. All three ✅ CONFIRMED.

**P41 ✅** — the control plane answered normally with one manager gone:

```
docker-swarm-1   Unknown/Down   Active   Unreachable   29.7.2
docker-swarm-2 * Ready          Active   Reachable     29.7.2
docker-swarm-3   Ready          Active   Leader        29.7.2
```

⭐ **Contrast C5 sharply in the chapter: at 2-of-3 the API answers instantly; at quorum loss even *reads*
return `DeadlineExceeded`.** "A manager died" and "the control plane died" look nothing alike from the CLI,
and conflating them wastes the first ten minutes of an incident.

🚨 **Unlogged bonus finding — node status decays in TWO stages, and Andrew caught the intermediate one by
running the command twice.** First invocation: `STATUS=Unknown`. Seconds later: `STATUS=Down`. But
`MANAGER STATUS` read **`Unreachable` in both** — so **Raft peer health noticed before node liveness did.**
Two subsystems with two different timeouts, and only one of them had converged when he first looked. ⭐ This
is the Phase 14 `Terminating`-but-still-serving hazard again: **a status field mid-transition is not a
result.** Had he checked once and moved on, he'd have recorded `Unknown` as the steady state.

**P42 ✅ CONFIRMED, and worse than predicted.** `docker service ls` reports a serene green while the node
is **powered off**:

```
capricorn_postgres   replicated   1/1     # a lie
```

I predicted `docker service ps` would show two tasks. It shows **five**:

| Task | Node | Desired | Current | Meaning |
|---|---|---|---|---|
| `mi6x3qb…` | `<none>` | Running | **Pending** 17 min | the replacement, **stuck forever** |
| `uzyvqh9…` | `docker-swarm-1` | Shutdown | **Running** 17h | 🚨 **the phantom — this is the `1`** |
| `pjlkyrf…`, `0qfabup…` | `docker-swarm-1` | Shutdown | Shutdown 17h | history |
| `s2fyz7f…` | `docker-swarm-1` | Shutdown | **Failed** 18h | history — `No such container` |

**The arithmetic:** the replica count tallies tasks whose *current* state is `Running`. Exactly one
qualifies — the task on the **powered-off host**, which Swarm wants shut down and **cannot confirm**,
because confirmation requires reaching a node that is gone. So an unconfirmable ghost is counted as a
healthy replica. Meanwhile the real replacement can never start, and the scheduler says so in full:

```
"no suitable node (scheduling constraints not satisfied on 2 nodes; 1 node not available for new tasks)"
```

⭐ **Read that message as arithmetic: all three nodes ruled out, for two different reasons.** Two fail the
`node.hostname == docker-swarm-1` pin; one is unavailable. **Swarm is not being vague — it is telling you
the pin is the cause, if you read past "no suitable node".**

⭐ **`docker service ps` is the ONLY command here that tells the truth** — which is pointed, because the
Aug 18 audit found it **missing from chapters 1 and 2** despite being the command that cracked the
registry-auth mystery. Third time it has been the decisive tool. **It belongs in every chapter.**

⭐ **Confirmed: an inflated replica count has (at least) two unrelated causes.** `backend 3/2` and
`frontend 4/3` here are **NOT** the start-first overshoot measured in Part 6.5 — they are a live replacement
on a survivor *plus* a phantom on the dead node. Identical arithmetic, different mechanism. **Reading `4/3`
as "start-first" sends you to `update_config` when the real story is a dead host.**

⭐ **Minor but useful:** `--no-trunc` shows all five tasks carrying the **same** `@sha256:5f76f30b…` digest.
`:latest` was resolved to a digest **once**, at deploy time, and frozen into the service spec — so tasks
created 18 hours apart are byte-identical. That is Swarm quietly protecting you from `:latest` drift
*within* a service's lifetime, and exactly why a redeploy is what picks up a new `:latest`.

**P43 ✅ CONFIRMED, including the hang.** The routing mesh keeps the UI up from survivors while the data
layer is gone: `ui:200`, `grep -ci capricorn → 2`. And the API failed **two different ways in sequence**:

```
$ curl -s .../api/v1/data/summary      →  (hung, ^C)
$ curl -s .../api/v1/data/summary      →  {"detail":"Internal server error"}
```

⭐ **First call hangs, second fails fast.** The first waits on a TCP connect to a VIP with no healthy
endpoint; by the second, the failure is already known and returns immediately. **The same broken dependency
produces a timeout *or* a clean 500 depending only on when you ask** — which is why "it was slow, now it
errors" is not evidence of two problems.

🚨 **This is the trap C4 payoff: gate 3 (`ui:200` + `grep`) is FULLY GREEN on a system whose database does
not exist.** Chapter 6 caught the mirror image — a wrong image passing the smoke gates. Together they bound
what a frontend check can ever prove: **it certifies HTML, not the application.** Gate 2's row-count floor
is the only gate here that touches the database, and it is the only one that would have caught this.

#### 🚨 Finding P4-F5 — bracketed-paste artifacts manufacture FALSE REDS

Two failures in this capture were caused by **pasting**, not by the system:

```
$ ^[[200~docker node ls          →  docker: command not found
$ curl … /api/v1/data/summary~   →  {"detail":"Not Found"}
```

The terminal's bracketed-paste marker `^[[200~` leaked into the command line, so the first line ran a
program named `\e[200~docker`, and a stray `~` landed on the end of a URL path.

⭐ **Both errors are dangerously plausible.** `docker: command not found` on a node where Docker is
demonstrably running invites "the Docker install is broken". And `{"detail":"Not Found"}` is a **404 from a
healthy router** — a completely different diagnosis from the `500` the real endpoint returns. **Had that
been the only API check, the conclusion would have been "the endpoint is missing" rather than "the database
is gone."** ⭐ **Before believing a `command not found` or a `404`, check what you actually typed** — and
prefer one command per line over pasted blocks into an SSH session.

#### The design flaw the trap exposed regardless of the missing measurements

🚨 **We accidentally co-located the DELIVERY PATH and the SYSTEM OF RECORD on the same node.** `SWARM_HOST`
was set to `.191` because it was "the first manager"; `postgres` is pinned to `.191` by decision A3.
**Nobody designed that overlap** — two independent single points of failure landed on one host, so one
`qm stop` takes out both the deploy path and the database. ⭐ **This is the shape that turns a survivable
event into an outage, and it is invisible in either design read on its own.** Neither decision is wrong;
their *intersection* is. Andrew spotted the `postgres` pin from the manifest before running anything.

⚠️ **Methodological consequence: this run conflates two failures, so the clean C4 claim ("healthy cluster,
healthy app, dead delivery path") is NOT what was demonstrated.** Say so in the chapter. Isolating the
variable needs a target whose loss the app survives.

#### 🚨 Finding P4-F4 — RETRYING A JOB REPLAYS THE OLD COMMIT

From the failed job's log:

```
Checking out 50915645 as detached HEAD (ref is main)...
```

`5091564` was the *first* snapshot. `e72ecf1` had already been pushed to `gitlab/main` by then. **Andrew
retried the existing job rather than creating a new pipeline, and a retry replays the pipeline's original
commit.** Harmless here (only documentation had changed), and 🚨 **a trap waiting for the C4 fix**: edit
`.gitlab-ci.yml`, push, hit *Retry*, and the job runs the **old** file — producing the identical failure and
the conclusion *"my fix did nothing"*. **After any fix, create a NEW pipeline.** Also note `git depth set
to 20`: a shallow fetch, so history-dependent tooling gets a truncated view.

#### The three SSH failure messages, and why the distinction is diagnostic

`exit code 255` is ssh's own signal — ssh reserves 255 for *its* failures and otherwise passes the remote
command's exit status through. So 255 means **"I never got to run your command."** And the message names
which of three worlds you are in:

| Message | Means | Speed |
|---|---|---|
| **`Host is unreachable`** (what we got — VM powered off, ARP finds nothing, `EHOSTUNREACH`) | nothing exists at that IP | **immediate** |
| `Connection timed out` | something is silently dropping packets — firewall, wrong subnet | slow, hits a timeout |
| `Connection refused` | host is up, nothing listening on 22 — sshd down, wrong port | immediate |

⭐ **Read the message before forming a theory.** All three present as "the deploy can't reach the host",
and they send you to three different teams.

### The C4 fix — Andrew chose "try each manager in turn", proof with `.191` still down

`SWARM_HOST: 192.168.1.191` became `SWARM_HOSTS: "192.168.1.191 192.168.1.192 192.168.1.193"` plus a
selection loop. **The loop is the boring half.** The half that matters is *what the loop probes with*:

```sh
ssh -o BatchMode=yes -o ConnectTimeout=5 "$SWARM_USER@$candidate" 'docker node ls >/dev/null 2>&1'
```

🚨 **`ping`, or `ssh host true`, would have been the wrong probe, and it is the mistake almost everyone
makes.** Those test **reachability**; the deploy needs **the ability to accept a deploy**. A node can answer
on port 22 while being a worker, or a manager whose cluster has **lost quorum** — and drill **C5** already
measured that exact state: SSH fine, `docker node ls` hanging to `context deadline exceeded`. A
reachability probe would select that node, copy both files, and *then* fail. ⭐ **Probe for the capability
you are about to use, not for a proxy that correlates with it.** `docker node ls` returns 0 only from a
manager that can reach a Raft majority, which is precisely what the next five commands require.

Two flags carrying earned weight: `BatchMode=yes` stops ssh **prompting for a password** when key auth
fails — that is **P4-F2**, found watching a local test go green for the wrong reason — and
`ConnectTimeout=5` bounds a **firewalled** candidate, which blackholes packets rather than failing fast
like a powered-off one.

⚠️ **Known residual, left deliberately: `environment.url` is still single-homed.** `environment:` resolves
from static variables when the job *starts*, so it cannot name whichever manager the loop picks. ⭐ **The
same disease as C4, in a place the C4 fix cannot reach** — a single address that survives node loss needs
DNS or a VIP, i.e. infrastructure, not YAML. → Phase 17.

#### Predictions before the fixed pipeline runs — P44–P47

- **P44** — `export SWARM_HOST` inside one `script:` entry is **visible to later entries**, because the
  runner concatenates all of `before_script` + `script` into **one shell script**. **Cleanly falsifiable:**
  if each entry got its own shell, `$SWARM_HOST` would be empty and `scp` would target `agamache@:` and
  fail instantly. (This is also why `eval $(ssh-agent -s)` in `before_script` works at all in `script`.)
- **P45** — the loop rejects `.191` **instantly**, not after the 5s `ConnectTimeout`: a powered-off host
  gives `EHOSTUNREACH` immediately. Target selected in ~2–3s.
- **P46 — the one worth running the experiment for.** `docker stack deploy` succeeds, and the job then
  **fails at the CONVERGENCE POLL, not at the smoke gate**, timing out after the full `TIMEOUT=300`s. The
  poll's test is `[ "$current" != "$desired" ]`, so:

  | Service | Replicas | Poll verdict | Reality |
  |---|---|---|---|
  | `capricorn_postgres` | `1/1` | ✅ **converged** | 🚨 **does not exist** — phantom on a dead host |
  | `capricorn_backend` | `3/2` | ❌ pending forever | **fine** — 2 healthy replicas serving |
  | `capricorn_frontend` | `4/3` | ❌ pending forever | **fine** — 3 healthy replicas serving |

  🚨 **The convergence check is exactly INVERTED. It passes the only genuinely broken service and blocks
  the two that are healthy.** An equality test on `current/desired` assumes `current` can never *exceed*
  `desired`, and a phantom task on an unreachable node breaks that assumption in both directions at once.
  ⭐ **And note where this lands us: the job goes red, for a real problem, via a check that is reasoning
  wrongly about which problem.** A red for the wrong reason is not a win; next time the wrong reason will
  point away from the fault.
- **P47** — the job never reaches the smoke gate, so gate 2's row-count floor — **the only gate that would
  have caught the missing database** — is never evaluated. The convergence poll shields it.

⚠️ **Judged safe to run with `.191` down:** an identical spec means no service is updated, so `redis` is
not rescheduled and cannot lose its volume, and the `pre_state` snapshot keeps stale `UpdateStatus`
latches from being blamed on this deploy.

#### Scored, from the fixed pipeline (new pipeline on `a0822d9f`, 2:00 PM)

**P44 ✅ CONFIRMED.** `export SWARM_HOST` set in one `script:` entry was visible to the three `ssh`/`scp`
entries after it — the runner concatenates `before_script` + `script` into **one shell**. Falsifiable and
not falsified: separate shells would have produced `agamache@:` and an instant failure.

**P45 ✅ CONFIRMED.** `.191` was rejected **immediately**, not after the 5s `ConnectTimeout`:

```
ssh: connect to host 192.168.1.191 port 22: Host is unreachable
    192.168.1.191   unusable — skipping
    192.168.1.192   USABLE — reachable, a manager, and has quorum
==> deploy target: 192.168.1.192
```

⭐ **The fix is proven by the same event that broke the old pipeline.** Identical cluster state, identical
`qm stop 191`; last run died here, this one routed around it. **That is what makes the before/after worth
writing down** — the variable held, only the code changed.

**P46 ✅ CONFIRMED — the inversion is real, in production output:**

```
==> waiting for convergence (timeout 300s)
    still pending: capricorn_backend(3/2) capricorn_frontend(4/3)
```

🚨 **`capricorn_postgres` is absent from that list.** The poll certified as converged the one service that
**does not exist**, and flagged the two that are serving traffic correctly. Three consecutive polls, no
variation.

#### ✅ D7 confirmed by observation — the `mkdir ~/.ssh` is NOT vestigial

```
Warning: Permanently added '192.168.1.192' (ED25519) to the list of known hosts.
```

**Once, on the probe connection — and never again for the four later connections to the same host.** So the
pattern really is trust-on-first-use *within the job*: connection 1 learns the key blind, connections 2–5
**verify against it**. ⭐ That bounds the exposure precisely: an attacker must win the race on the **first**
connection of a job, not any connection. It is still trust-on-first-use and still not authentication —
`StrictHostKeyChecking=accept-new` with a pre-seeded `known_hosts` is the PROD answer, Phase 17 — but the
original reading of D7 ("protects nothing") was **wrong**, and the log says so.

#### ⚠️ Another false signal in the same log: "Updating service" is printed unconditionally

```
Updating service capricorn_frontend (id: …)
Updating service capricorn_backend  (id: …)
Updating service capricorn_postgres (id: …)
Updating service capricorn_redis    (id: …)
```

**All four, on a byte-identical spec.** `docker stack deploy` prints `Updating service` for every existing
service in the manifest — it describes **the API call it made**, not whether anything changed. ⭐ Read as
"four services were rolled out", it would imply `redis` had been recreated, which for an **unpinned**
service with a **local** volume would mean silent data loss (trap C3's mechanism). It wasn't: `redis`
never appears in the pending list and never leaves `1/1`. **The evidence that nothing happened is the
absence of churn, not the presence of this message.**

#### 🚨🚨 Finding P4-F6 — THE FAILURE MESSAGE AND ITS OWN EVIDENCE CONTRADICT EACH OTHER

The single most instructive artefact of Part 4. The job's final output, verbatim and adjacent:

```
did not converge: capricorn_backend(3/2) capricorn_frontend(4/3)
NAME                   NODE             CURRENT STATE         ERROR
capricorn_backend.1    docker-swarm-3   Running 2 hours ago
capricorn_backend.2    docker-swarm-2   Running 2 hours ago      <-- TWO backend tasks, not three
capricorn_frontend.1   docker-swarm-2   Running 2 hours ago
capricorn_frontend.2   docker-swarm-3   Running 2 hours ago
capricorn_frontend.3   docker-swarm-3   Running 2 hours ago      <-- THREE frontend tasks, not four
capricorn_postgres.1                    Pending 2 hours ago   "no suitable node (…)"
capricorn_redis.1      docker-swarm-2   Running 2 hours ago
FAILED: convergence timeout after 300s
```

**The headline says `3/2` and `4/3`. The evidence printed one line below shows exactly 2 and exactly 3,
all `Running`.** Both numbers are computed correctly; they answer **different questions**, because the
dump filters `desired-state=running` and the `Replicas` column does not.

⭐ **The dump is right and the headline is wrong — and the dump names the real fault unambiguously**:
`capricorn_postgres.1`, no node, `Pending`, with the constraint error spelled out. **The only row with a
problem is the only service the checker cleared.**

🚨 **Think about being handed this at 3am.** The alarm accuses two services that are healthy; the evidence
under it exonerates them and indicts a third. The most likely human response is to distrust the whole
output — and the correct diagnosis is sitting in it, in plain text. ⭐ **A monitoring system that
contradicts itself is worse than one that says nothing, because it spends the one resource an incident is
short of: your willingness to believe the instruments.**

**P47 ✅ CONFIRMED** — execution never reached the smoke gate, so gate 2's row-count floor, **the only check
that would have named the missing database**, was never evaluated. ⭐ **A broken cheap check upstream
disabled the expensive check that worked.** Ordering matters: a gate you never reach protects nothing.

🙋 **Andrew's read of the design question was right on the mechanism:** *"if the extra instance is up then
current can be > desired in an outage?"* — yes, and that is precisely the phantom. **The half worth adding**
is why `<` alone would have been a regression: mid-way through a legitimate `start-first` rollout the count
also reads `3/2`, and `3 < 2` is false, so a naive `<` reports **converged while the rollout is still in
flight** — a false green in exchange for a false red. **Neither test works, because the count cannot
distinguish the two situations that produce the identical string.**

### The convergence rewrite (`deploy_swarm.sh`, Aug 19) — one instrument per question

Not a patched comparison. **A change of instrument**, plus a precondition that makes the question moot.

**1. Precondition: refuse to deploy into a degraded cluster.** `docker node ls` is already called to prove
we are on a manager; it also answers "is every node `Ready`/`Active`". If not, stop — **not because the
deploy would fail, but because nothing checked afterwards would mean anything**, in either direction. Two
seconds and an accurate accusation, instead of five minutes and a wrong one. ⚠️ With an `ALLOW_DEGRADED=1`
escape hatch, deliberately: deploying into a degraded cluster is sometimes the correct incident response,
and **a tool that forbids the right action gets worked around in ways nobody records.** Loud, not impossible.

**2. Count tasks, not the `Replicas` column.** `docker service ps --filter desired-state=running` excludes
phantoms by construction — the phantom's desired state is `Shutdown`. ⭐ **This is the same filter the
failure dump has always used, which is why the dump was right all along.** The fix was already in the file,
being used for the report and not for the decision.

Re-running the numbers from this outage under the new logic — postgres is now correctly caught:

| Service | old `Replicas` | old verdict | new count | new verdict |
|---|---|---|---|---|
| `capricorn_postgres` | `1/1` | ✅ converged 🚨 | **0/1** (the `Pending` task is not `Running`) | ❌ **pending — correct** |
| `capricorn_backend` | `3/2` | ❌ pending | **2/2** | ✅ converged — correct |
| `capricorn_frontend` | `4/3` | ❌ pending | **3/3** | ✅ converged — correct |
| `capricorn_redis` | `1/1` | ✅ converged | **1/1** | ✅ converged |

**3. `-lt` instead of `!=`, and why that is safe only because of what stayed.** Overshoot no longer blocks.
⚠️ **The `!=` test was doing a second job badly and dropping it alone would have been a regression** — it
also covered the window between `stack deploy` returning and the manager setting `UpdateStatus`, where a
stale `completed` can be misread as this rollout finishing. That window now has an explicit `sleep
$INTERVAL` settle delay, and **whether a rollout has finished is `UpdateStatus`'s job**, which it does
properly: mid-`start-first` it reads `updating`, so the case that defeats a pure `<` is still caught.

⚠️ **Recorded as OPEN, not solved:** the settle delay is a mitigation, not a proof. The rigorous version
compares each service's `.Version.Index` across the deploy and trusts `UpdateStatus` only for services
whose index moved. **Untested, therefore not claimed.** → Phase 17.

#### Predictions P48–P49

- **P48** — re-running with `.191` still down now fails in **under ~5 seconds**, before `docker login` and
  before `stack deploy`, with `CLUSTER DEGRADED: docker-swarm-1(Down/Active)`. **The same outage, a fifth
  of a percent of the time, and an accusation that names the right node.**
- **P49** — after `qm start 191` and reconvergence, a further run goes **fully green**: convergence clean on
  all four services and all three smoke gates passing, including gate 2 at `total=682`. ⚠️ If gate 2
  instead reports a total **below 100**, that is not a flake — it is the bootstrap-never-re-ran failure the
  gate's own error text describes, and the fix is `docker service update --force capricorn_backend`.

#### Scored, run #3 (`cdcad948`, 2:14 PM) — ✅ JOB SUCCEEDED, and that proves less than it looks

`.191` was started before this run, so the pipeline went end-to-end green on a healthy cluster:

```
    192.168.1.191   USABLE — reachable, a manager, and has quorum
==> waiting for convergence (timeout 300s)
    all services converged
    /api/v1/banking/categories -> 200, body matched
    /api/v1/data/summary -> total=682 rows
    5001/ -> 200, body matched 'capricorn'
==> done
```

**P49 ✅ CONFIRMED** — 2/2, 3/3, 1/1, 1/1; all three gates; `total=682` exactly as before the outage; no
`still pending` line at all, so the settle delay did not introduce a stall.

**P48 ➖ NOT TESTED. Recorded as untested, NOT as passed.** `.191` was already back, so the degraded-cluster
precondition never entered its failure branch.

🚨 **And this is the important entry in this whole section: a green pipeline on a HEALTHY cluster cannot
distinguish the new convergence logic from the broken one.** With all three nodes up there are no phantom
tasks, so `Replicas` and the task-level count agree, and the old `!=` test would have printed *exactly this
same output*. ⭐ **The run that proves the fix is the DEGRADED one. The green run only proves we did not
break the happy path** — worth knowing, and not what was claimed.

⚠️ **So the degraded branch of the precondition, and the corrected counting, are CODE THAT HAS NEVER
EXECUTED.** By this project's own standard that makes them *recited*, not verified — the exact category
Phase 17 was chartered to eliminate. It is a five-second test. Do it rather than inherit it.

#### P48 ✅ CONFIRMED (run #4, `baab2a64`, 2:43 PM) — with `.193` stopped, not `.191`

⭐ **`.193` was chosen deliberately: it holds no pinned service, so the app stayed healthy and the only
variable was "one node is not `Ready`".** The original C4 run conflated two failures; this one does not.

```
    192.168.1.191   USABLE — reachable, a manager, and has quorum
==> deploy target: 192.168.1.191
CLUSTER DEGRADED: docker-swarm-3(Down/Active)
FAILED: cluster degraded: docker-swarm-3(Down/Active) (override with ALLOW_DEGRADED=1 …)
ERROR: Job failed: exit code 1
```

**Every clause held:** it fired **before `docker login`** (no `logging in to…` line — the precondition sits
between the manager check and the registry login), and it named the right node.

🚨 **The number that makes the case, and it is worth quoting in full:**

| Same class of problem | `step_script` duration | Verdict |
|---|---|---|
| Before the fix (C4, `.191` down) | **05:10** | wrong — accused two healthy services, cleared the broken one |
| After the fix (`.193` down) | **00:03** | right — named the degraded node |

⭐ **~100× faster and correct instead of incorrect, from asking the cheap question first.** The expensive
check was not made better; it was made *unnecessary*, which is the more valuable move. **Note also that
`docker login` never ran** — the fast path avoided touching a credential at all, so a refused deploy now
leaves no trace on the node. That was not designed; it falls out of ordering the checks by cost.

Note the two-stage decay found earlier pays off here: `Status` passes through `Unknown` before `Down`, and
the check triggers on **either**, because both fail the `Ready` test rather than matching a specific string.

#### 🚨 But the OTHER half of the fix is now UNREACHABLE, and that is a self-inflicted problem

**The corrected task-level convergence counting is still untested, and the precondition is the reason.**
The guard stops execution *upstream* of the convergence poll, in exactly the scenario the counting fix was
written for. **A phantom task can no longer occur in a run that reaches the poll.**

⭐ **General lesson worth more than the fix itself: adding an early guard can make a downstream code path
untestable by normal means.** Both changes are correct, and together they create a path that can never be
exercised in production conditions — which is how code rots into something nobody dares touch.

⚠️ **The only route left is the escape hatch**, which is a second reason `ALLOW_DEGRADED=1` was worth
keeping. **Prediction P50, to be run with `.193` still down:**

```bash
ssh agamache@192.168.1.191
ALLOW_DEGRADED=1 bash /home/agamache/swarm-ci/scripts/deploy_swarm.sh
```

*(No `REG_TOKEN` needed — the script skips login when it is unset and relies on the node's existing
credential. The manifest resolves relative to the script, so no `NON-DEFAULT STACK FILE` banner.)*

**P50:** the degraded banner prints as **ADVISORY**, the deploy proceeds, and the convergence poll reports
**`all services converged`** — where the old `!=`-on-`Replicas` logic would have hung for the full 300 s on
phantom-inflated counts. That single run is what discriminates the new counting from the old.

⚠️ **PRECONDITION — check before running it, or the result is VACUOUS.** P50 only means something if
`.193` was actually hosting tasks when it went down. Run `docker service ls` first: **if `backend` reads
`3/2` or `frontend` reads `4/3`, phantoms exist and the test is real. If they read `2/2` and `3/3`, there
are no phantoms and the run proves nothing** — say so rather than banking a pass. This is the same
discipline that marked P39 vacuous rather than green.

#### ✅ P50 CONFIRMED (2:48 PM, by hand on `.191`) — the counting rewrite is VERIFIED, not recited

**The precondition was checked first and the test was real.** Phantoms were present, and more than expected:

```
capricorn_backend    replicated   3/2      <- 1 phantom (backend.1 was on docker-swarm-3)
capricorn_frontend   replicated   5/3      <- 2 phantoms (frontend.2 AND .3 were on docker-swarm-3)
```

The arithmetic reconciles exactly against the 2:07 PM task placement: `.193` held one `backend` and **two**
`frontend` tasks, so 2 survivors + 1 ghost = `3/2`, and 3 survivors + 2 ghosts = `5/3`.

**The result:**

```
  ALLOW_DEGRADED=1 - proceeding anyway. Treat every check below as ADVISORY.
==> waiting for convergence (timeout 300s)
    all services converged
==> smoke gate: is it ready for business? (timeout 90s)
    /api/v1/banking/categories -> 200, body matched
    /api/v1/data/summary -> total=682 rows
    5001/ -> 200, body matched 'capricorn'
==> done
```

🚨 **This is the discriminating run, and the contrast is total.** Same cluster shape, same phantom
inflation, one node down:

| | Old logic (`!=` on `Replicas`) | New logic (tasks, `desired-state=running`) |
|---|---|---|
| Verdict | **`did not converge`** after 300 s | **`all services converged`** in seconds |
| Named | `backend(3/2) frontend(5/3)` — both healthy | nothing — correctly |
| Smoke gates | **never reached** | ✅ all three, `total=682` |

⭐ **And the ground truth is in the same output: the smoke gates passed.** The application was genuinely
serving, with real data, on a cluster missing a node — so `converged` is the *correct* verdict, and the old
code would have declared **a FAILED DEPLOY on a healthy application**, then sent someone to investigate a
rollback of a working system. **That is a false red, and it was in our own tooling for a day.**

🚨 **Worth stating plainly, because it is the mature version of this whole lesson: our tool now DISAGREES
with `docker service ls` on purpose, and is right to.** After the deploy, Docker's own summary column still
reads `3/2` and `5/3`; our poll reads `2/2` and `3/3` and calls it converged. **We built an instrument that
contradicts the vendor's headline number, and we can justify the disagreement from first principles** —
`Replicas` counts tasks Swarm cannot confirm dead, and we count tasks Swarm still wants alive. ⭐ Being able
to say *which question each number answers* is the difference between second-guessing a tool and trusting
your own.

**Every code path in the C4/convergence work has now executed.** The only remaining untested item in this
area is the `.Version.Index` refinement of the settle delay, which was never claimed as done.

#### 🚨 P4-F7 — the override made the script's OWN LOG lie, found by reading the P50 output

The banner printed **`Refusing to deploy.`** and then deployed. Under `ALLOW_DEGRADED=1` the wording was
never re-checked, so the log asserted one thing and did the opposite four lines later.

⭐ **This is the same defect class as P4-F6** (the failure message that contradicted the dump beneath it):
**a message describing an INTENTION rather than the action actually taken.** Harmless while you are watching
the whole run scroll past; not harmless at 3am reading a log tail, where `Refusing to deploy` is a complete,
plausible, and wrong explanation of why the fix you shipped is not live. **An operator would go looking for a
deploy that had in fact happened.**

🚨 **The general rule, now in the script as a comment: never let an override change behaviour without
changing the wording.** Fixed by computing the verdict *before* narrating it, and the trailing line changed
from `proceeding anyway` to **`ADVISORY MODE - a green result below does NOT mean the cluster is healthy`** —
which states the consequence rather than the mechanism. ⚠️ The copy on `.191` is now stale; the next pipeline
`scp`s the corrected script.

---

### 🚨 UNPLANNED INCIDENT (2:55–3:02 PM) — a rebooted manager DEPOSED the healthy leader for 2.5 minutes

**This was not a planted trap.** It arrived on its own from `qm start 193` after the P48/P50 tests, and it is
the most instructive failure of the phase. **Nobody intervened, and that was the correct action.**

#### What was observed, in the order it was observed

| Time | Vantage | Reading |
|---|---|---|
| 2:55 | `.191` | `docker-swarm-3   Ready   Active   **Unreachable**` — services already clean `2/2 3/3 1/1 1/1` |
| 2:58 | `.193` | `Error: The swarm does not have a leader. It's possible that too few managers are online.` |
| 2:58 | `.193` raft | campaigning at terms 21→26, `1 MsgVoteResp votes and 0 vote rejections` |
| 3:00 | `.191` raft | `received a MsgAppResp with higher term from …[term: 31]` → `became follower` → `cancelling all waits` |
| 3:00 | `.191` raft | `[logterm: 12, index: 775] rejected MsgVote from …[logterm: 11, index: 743]` |
| 3:00 | both | `nc -vz … 2377` succeeded **both directions**; `timedatectl` synced, no skew |
| 3:02 | `.191` | all three `Leader/Reachable/Reachable`; **churn count `0`** |

#### The mechanism — ⭐ `term` and `index` moved in OPPOSITE directions

While `.193` was powered off it kept campaigning into the void, **inflating its raft term from 12 to 31
without ever appending a log entry.** It rebooted holding **the highest term in the cluster and the most
stale log** — and those two facts have opposite consequences in Raft:

1. **Term is authoritative.** Any node seeing a higher term MUST stand down. So a healthy leader at term 12
   was forced to `become follower` — and `soft state changed … resetting and cancelling all waits`, which
   **aborts in-flight control-plane operations.**
2. **Log freshness gates election.** `.191` at `index: 775` rejected `.193` at `index: 743`, so `.193`
   **could never win** the election it had just forced.
3. `.191` re-elected itself with `.192`, `.193` bumped its term again, repeat — **a leadership flap every
   ~20 s.**

⭐ **The single sentence worth memorising: a stale manager can force elections but can never win one, so the
loop RAISES THE TERM until a current-log node wins high enough to silence it. The failure mode contains its
own termination condition.** Observed duration: 14:57:03 first campaign → 14:59:39 `.191` leader at term 34 →
settled. **~2.5 minutes, zero intervention.** This is what Raft PreVote exists to prevent.

#### 🚨 The reflex would have caused the outage it was meant to fix

At 2:58 the evidence was a manager reporting `does not have a leader`, stuck `Unreachable`, churning six
terms a minute. **Every instinct says intervene, and `docker swarm leave --force` on `.193` is the standard
internet-recommended remediation.** It would have destroyed a cluster that was **90 seconds from fixing
itself**, trading a self-healing degradation for a real outage plus a manual rejoin under pressure.
⭐ *The reflex to "just bounce something" turns degraded into outage* — previously a line inherited from the
Redpanda phase, now **a thing that nearly happened here.** Waiting was not luck; it was justified by the
self-limiting property above.

#### 🙋 Two AI diagnostic errors, both from the same root, both worth keeping

**(1) "`.193` is isolated and will stay that way" — REFUTED.** Built on `0 vote rejections` from a log window
covering 14:57–14:58, when the peer transport had not yet re-dialled. By 14:59:11 it had, and rejections
began arriving. 🚨 **Two log windows captured minutes apart were read as one stable condition** — ⭐ *an
evolving fault, sampled twice at a distance, impersonates a stable fault of a different kind.*

**(2) "Two honest vantage points" — wrong in an interesting way.** The `.193` vs `.191` disagreement was
framed as *perspective*. It was **time**: at the instant `.193` asked, there genuinely was no leader,
because `.193` had just deposed him. **Both nodes were correct, seconds apart, about a cluster that was
flapping.** ⚠️ The lesson survives in stronger form — *when two instruments disagree, establish whether they
disagree about the world or about the moment, before theorising about vantage point.*

#### Predictions

**P51 ➖ REFUTED** (`MANAGER STATUS` did *not* flip within ~60 s of engine start; it took ~2.5 min and only
after a term-34 election) · **P52 ✅ CONFIRMED** (churn count exactly `0`, all three `Reachable`, `tail -20`
empty) · **P53 ➖ VACUOUS** — antecedent never held, so **nothing is concluded about log compaction or
snapshots**, and demote/rejoin was never needed.

#### 🚨 P4-F8 — the verified guard has a blind spot, demonstrated by this incident

Throughout the flap `.193` read `Ready/Active`, so the precondition proved this afternoon **would have called
the cluster healthy and deployed into a control plane cancelling in-flight work every 20 s.**
`MANAGER STATUS` was the only column telling the truth, and the guard never looked at it.

⭐ **Three columns, three different questions, and they move independently:** `STATUS` = can this node run
tasks (worker plane) · `AVAILABILITY` = has an admin drained it · `MANAGER STATUS` = is it a live raft quorum
member (control plane). **"One instrument per question" applied to the columns of a single command.**

**Fixed as an ADVISORY, not a failure** — and the severity reasoning is the teachable part: quorum-intact
churn creates no phantom tasks, so every downstream check stays meaningful; the condition is self-limiting;
so blocking would forbid a safe deploy *and* invite the demote/rejoin reflex that turns this into an outage.
**Severity should match consequence, not alarm level.** The advisory prints the churn-count one-liner and an
explicit "wait ~3 minutes, do NOT `swarm leave --force`".

⭐ **Third unplanned validation of the C4 capability probe.** `ssh .193` worked fine throughout, so a naive
reachability check would have selected it; `docker node ls` on `.193` failed, so the probe skips it. Written
for C5's deliberate quorum loss, and it correctly handled a spontaneous fault of the same class.
**"Reachable is not usable" is now measured three independent ways.**

Raw evidence: `scratch/incident_raft_term_inflation.txt`.

#### What the recovery revealed about A3's trade-off

`total=682`, unchanged. ⭐ **The pin that CAUSED the outage is the same pin that preserved the data**:
`postgres` could not reschedule, so it could not come up on a node holding an empty local volume. Decision
A3 traded availability for durability and **this outage exercised both halves of that trade in one event** —
the deploy path died *because* of the pin, and the database survived intact *because* of the pin.

✅ **CLOSED Aug 19, 7:55 PM — MEASURED, and the hypothesis was WRONG. 🤖 AI-executed** at Andrew's
instruction ("run the commands yourself, update docs as necessary and close this phase"); every command
below was read-only.

The question as written was: *"`capricorn_redis.1` was `Running` on docker-swarm-2 having started ~2 hours
earlier, i.e. right at the outage. If `redis` was previously on `.191`, it rescheduled onto `.192` against
a fresh, empty volume — C3's mechanism occurring for real, unnoticed."* **No part of that happened.**

| What was checked (read-only) | Result |
|---|---|
| `docker volume ls` on all three nodes | `.191` **has never held a redis volume**; the volume exists on `.192` and `.193` only |
| `docker volume inspect … CreatedAt` | `.192` **Aug 13 18:27** (original deploy) · `.193` **Aug 18 19:06:56** |
| Keys in each volume, by `grep -a` on the RDB as root | `.192` `dump.rdb` **155 b, holds `c3:canary` + `c3:counter`** · `.193` `dump.rdb` **88 b, ZERO keys** |
| AOF generation number | `.192` `appendonly.aof.**2**.base.rdb` (rewritten twice) · `.193` `appendonly.aof.**1**.base.rdb` (first ever — a fresh start) |
| Live `redis-cli DBSIZE` / `KEYS *` on `.192` | **2** — `c3:canary`, `c3:counter`, still present five days on |
| `docker inspect` the live container | **`StartedAt` Aug 18 23:14:34 UTC, `RestartCount` 0**, mounting `capricorn_redis_data_swarm` |

⭐ **So two divergent volumes DO exist — but they are trap C3's own documented residue, created
deliberately at 19:06:56 on Aug 18, not an accident during the Aug 19 outage.** The numbers match the C3
write-up in this file exactly (empty volume created 19:06:56, `DBSIZE 0`, both canary keys returned on
moving the constraint back). Nothing was lost, and nothing needs writing up as a new incident. **The
`.193` volume is still there: 88 bytes, empty.** Left in place — removing it is destructive, it is C3's
evidence, and hard rule B1's spirit says do not tidy away a trap's artefacts. ⚠️ **Standing hazard,
recorded not fixed:** if `redis` ever schedules onto `.193`, it will attach that empty volume and the app
will silently see an empty cache.

🚨 **The finding is the reasoning error, not the volumes — and it is a false green of a new kind here.**
The hypothesis rested on reading `docker service ps`'s `CURRENT STATE` column ("`Running 8 hours ago`") as
**when the task started**. It is not. Measured on the same task, same minute:

```
task CreatedAt       2026-08-18 23:14:24 UTC   ← task born (matches the container's StartedAt)
Status.Timestamp     2026-08-19 16:11:15 UTC   ← what "Running 8 hours ago" renders
UpdatedAt            2026-08-19 18:59:41 UTC
container RestartCount 0                       ← never restarted in 24.6 h
```

**`CURRENT STATE` age is the last time the manager STAMPED the task's status, not the task's age.** The
stamp moves during control-plane churn — this one moved twice on Aug 19, around the C4 tests and the
manager-reboot incident — so **a task that has run untouched for a day can present as freshly
rescheduled.** That is exactly the misread that manufactured this open question: at the 2:07 PM dump the
task was **20 hours old**, not 2. Clock skew was excluded, not assumed: all three nodes are NTP-synced
and agreed to within one second when checked.

⭐ **The general rule, and it is the phase's spine again — one instrument per question.** "How long has
this container been up?" is `docker inspect .State.StartedAt` plus `.RestartCount` on the node. "Which
node did it come from?" is the task history, and once Swarm prunes the old rows **the only surviving
evidence is on the filesystem** — here, the volume's `CreatedAt` and its AOF generation number outlived
the orchestrator's memory of the event entirely.

### CI variables (Andrew, GitLab UI, Aug 19)

| Key | Type | Masked | Protected |
|---|---|---|---|
| `REG_TOKEN` | Variable | ✅ **yes** | no |
| `SWARM_SSH_KEY` | Variable | ❌ **impossible** | no |

Non-secrets (`REGISTRY`, `REG_USER`, `SWARM_USER`, `SWARM_HOST`, `REMOTE_DIR`) live in the `variables:`
block of `.gitlab-ci.yml` instead. ⭐ **The rule: a value that is not secret belongs in version control**,
where it is reviewable, present in a fresh clone, and visible to whoever is reading the job log at 3am
wondering which host the job touched. Hiding non-secrets in the settings UI is a habit that costs nothing
until the person debugging has no UI access.

⚠️ Both variables are **unprotected**, so any branch's pipeline could read them. Normally worth tightening;
here it is swamped by **L20** — the branch already contains every secret in plaintext.

### Predictions BEFORE the first pipeline run

| # | Prediction | Reasoning | Outcome |
|---|---|---|---|
| P35 | GitLab **accepts** masking on `REG_TOKEN`. | Mechanism argument, not a memory of the docs: GitLab's own deploy tokens are prefixed `gldt-` and contain `_` and `-`, so a masking charset that rejected them would be self-defeating. | ✅ **CONFIRMED** |
| P36 | GitLab **refuses/does not offer** masking on `SWARM_SSH_KEY`. | Masking requires a single-line value; a PEM key is multi-line by construction. | ✅ **CONFIRMED** — accepted only as unmasked. **The key is unmaskable by design, not by oversight**, which is exactly the recited row Phase 17 must fix |
| P37 | Committing this file and running `push_gitlab.sh` creates **NO pipeline** — not a blocked one, not a list entry. | `workflow: rules:` decides whether a pipeline is *created*; `push` matches no rule. | ✅ **CONFIRMED** — "There were no pipelines yet". ⭐ Checked as its own step, deliberately: **an absence is only evidence if you went looking for it before creating the thing that would fill the gap** |
| P38 | ⭐ **The falsifiable one.** The first manual run deploys successfully with `deploy_swarm.sh` **byte-identical** to the by-hand version, no `STACK_FILE` override, no NON-DEFAULT banner, all three smoke gates green, `EXIT=0`. | Part 3 drew the boundary so the wrapper only supplies *when/who/where/which host*. Everything the script needs was verified in pre-flight. | ✅ **CONFIRMED first try.** Independently verified from the cluster rather than from CI's own report: `/home/agamache/swarm-ci/{scripts,manifests}` created 11:34 in the right shape, all four services `UpdatedAt 2026-08-19 15:34:18 UTC`, stack `2/2 3/3 1/1 1/1`. **The Part 3 boundary holds — the wrapper contributed zero deploy logic** |
| P39 | If P38 fails, the failure is in the **stdin token handoff** (`read -r` under a non-interactive `ssh` command shell), **not** in ssh auth, connectivity, or the script. | Auth was proven conclusively on all three managers with an agent-only, publickey-only test; the token path is the only piece never exercised. **Naming the most likely failure in advance is what makes a red pipeline diagnostic instead of a mystery.** | ➖ **VACUOUS — scored as neither.** It was conditional on P38 failing and P38 passed. ⚠️ **Recorded rather than quietly counted as a hit:** a conditional prediction whose antecedent never fires has told you nothing, and treating it as confirmation is how a prediction log inflates its own accuracy. The mechanism *was* separately verified (`echo SENTINEL \| ssh "read -r X…"` → `GOT=[SENTINEL-12345]`) |

### ⭐ Finding P4-F3 — `docker login` writes NOTHING when the credential is unchanged, and the AI drew a confident wrong conclusion from that

**The observation that started it.** After a green pipeline, `~/.docker/config.json` on `.191` still read
**Aug 13 18:27** — the day of the by-hand Part 3 deploy. The AI's hypothesis: the token never arrived, the
script took its `else` branch (*"no REG_TOKEN supplied - relying on the existing login"*), and **the deploy
only succeeded because a hand-made login from six days earlier was still on the node** — a false green
manufactured by our own earlier work, in the same family as the manual `docker pull`s that half-voided
trap C1.

🚨 **Wrong.** The job log says plainly:

```
==> logging in to gitlab.gothamtechnologies.com:5050 as swarm-lab-pull
    login ok
```

**Measured, after banking the log evidence first** (running the test in the other order would have
destroyed the only proof — `METHOD.md`'s contamination rule, applied to the *sequence* of a diagnosis):

```
stat  →  2026-08-13 18:27:16.128571619 -0400   134 bytes
printf '%s' '<token>' | docker login … --password-stdin   →  Login Succeeded
stat  →  2026-08-13 18:27:16.128571619 -0400   134 bytes
```

**Identical to the nanosecond**, which rules out a rewrite of the same bytes. `docker login` compares the
credential it would store against what is already there and, when they match, **does not touch the file.**

⭐ **Three consequences, in increasing order of how much they matter:**

1. **`config.json`'s mtime answers a different question than the one people ask it.** During an incident
   the natural question is *"when did this node last authenticate to the registry?"* The mtime answers
   *"when did this credential last CHANGE"* — potentially weeks earlier. A timeline built on it is wrong
   and looks authoritative.
2. 🚨 **The plaintext-storage WARNING is also write-time-only.** Ledger **L9** exists because Docker
   volunteered `WARNING! Your password will be stored unencrypted…` on Aug 13. Today's identical login
   printed **no warning at all**. So the single best security signal in this phase fires **once per
   credential change**, and anyone auditing CI logs for it will see a clean log and conclude the exposure
   is not there. **The credential on disk is just as readable; only the notification is gone.**
3. ⭐ **You cannot prove from the node's filesystem that CI's `docker login` did anything.** An idempotent
   operation leaves no trace when it has nothing to do, so **"nothing changed on disk" is not evidence
   that "nothing happened."** The job log was the only proof.

⚠️ **And the honest part: the AI reasoned from a filesystem artefact to a confident, wrong, alarming
conclusion** — and would have "found" a false green that did not exist. ⭐ **Name it: this is a FALSE RED,
and it belongs in chapter 6's taxonomy as the mirror image of everything already in it.** Chapter 6
catalogues systems reporting health they do not have; this is an *observer* reporting failure that is not
there. Both come from the same root error — **trusting a signal without knowing what generates it** — and
the false red is the more expensive one in an incident, because it sends people to roll back a system
that was fine.
| P40 | Trap **C4**: with `.191` stopped, the job fails at the first `ssh` while `docker node ls` on `.192` still shows quorum and the app keeps serving on `:5001` from the surviving nodes. | 3 managers, quorum 2 — losing one is the *designed* failure for the control plane. The delivery path has no redundancy at all: one IP, hardcoded. | ⚠️ **HALF REFUTED (Aug 19)** — clauses 1 and 2 ✅ (`Host is unreachable`, exit 255; quorum held, leader moved to `.193`). Clause 3 ❌: the **UI** kept serving (`ui:200`, `grep → 2`) but the **API** did not (`{"detail":"Internal server error"}`), because `postgres` is pinned to the node I stopped. 🙋 **Andrew's prediction beat mine** — he read the manifest and called the pin. Full write-up in the Part 4 log |
| P41–P49 | Scored in the **Part 4 implementation log** above (trap C4 section) rather than duplicated here: P41 ✅, P42 ✅ (worse than predicted — 5 tasks), P43 ✅, P44 ✅, P45 ✅, P46 ✅, P47 ✅, P49 ✅. | — | ✅ **P48 CONFIRMED** at 2:43 PM Aug 19 with `.193` stopped — see "P48 ✅ CONFIRMED (run #4)" above. ⚠️ **This row previously read "NOT TESTED", and stayed wrong for hours after the test passed** — the correction pass that fixed chapter 3, the track README, `MEMORY.md` and `current_phase.md` missed the summary table in this file. A claim duplicated into a summary has to be corrected in BOTH places, and the summary is the one that gets read cold. |

---

## Trap C7 — digest freezing (Aug 19, 2026, from ~4:10 PM)

🤖 **AI-EXECUTED, and that is a departure from `METHOD.md` that must be declared, not buried.** Andrew's
instruction, in writing, 4:07 PM: *"I would like you to run all these tests yourself and document them
without me. create whatever you want and cleanup after."* Every other trap in this phase was driven by
Andrew. `CURSOR_RULES` rule 3 and `METHOD.md` → "Who does the work" therefore both apply: **the chapter
material from C7 may NOT claim "Andrew ran this"**, and it must declare itself the way track 1 chapter 7
declares itself research-only. Recorded here because an undeclared deviation is how a method decays —
`METHOD.md` line 41 already documents this exact decay happening in Part 1.

### Why the trap as written probably cannot fire

The 🅒 table describes C7 as *"push a new image under the same `:latest` tag, redeploy, and see whether
anything actually changes."* But this file already recorded the mechanism at line 492: **`docker stack
deploy` re-resolves by default (`--resolve-image always`)**. So the naive form of the trap is expected to
show a service that updates perfectly — the same shape as **C2, which "did not fire, and WHY is the whole
lesson."**

⭐ **So the question is relocated, and this is the design decision of the session: not "does a tag
freeze" but "which paths freeze it, and which paths STRIP the pinning that protects you."** Digest
pinning has two faces, and the interesting material is that they are the same mechanism:

- it **betrays** you when you expect a restart to pick up new code (scenario 2)
- it **protects** you when a task is rescheduled and you need the fleet to stay homogeneous (scenario 5)
- and the paths that **remove** it (scenarios 3, 4) are the genuine hazard, because they convert a
  guarantee into per-node cache roulette — which is the composition already half-observed under C6 at
  line 1860.

### Rig

| Thing | Value | Why |
|---|---|---|
| Image | `gitlab.gothamtechnologies.com:5050/production/home-lab-setup/c7demo` | **Lab-only, in THIS repo's own GitLab project.** Hard rule **B1** forbids retagging a production Capricorn image, which also makes the C7 baseline digest recorded at line 2149 unusable. |
| Versions | `v1` then `v2`, both pushed to `:latest` | The moving pointer is the whole subject. |
| Marker | Version visible in the **served HTTP body**, in an image **label**, and in a **file** | ⭐ **One instrument per question.** The spec's digest says what Swarm INTENDS to run; the HTTP body says what is ACTUALLY serving. C6b is the reason this is not optional: an image that starts perfectly and serves the wrong application passed every signal we had. |
| Stack | `c7lab`, separate from `capricorn` | Cannot perturb the verified 4-service baseline or its 3 smoke gates. Removable with `docker stack rm`. |
| Replicas | 3, one per node | Divergence between replicas is only observable if replicas are spread. |
| Port | `8081` | `8080` is the frontend (A4). |

### Predictions — written BEFORE anything ran

| # | Prediction | Reasoning | Result |
|---|---|---|---|
| **P54** | Scenario 1, plain `docker stack deploy` after `:latest` moves to v2: the service **DOES update**. Spec digest changes `D1→D2`, rolling update runs, all 3 replicas serve v2. | `--resolve-image always` is the default. | ⚠️ **HALF REFUTED.** The spec re-resolved `D1→D2` on the spot, exactly as predicted — but the rolling update **never completed on its own.** It sat `updating` for **4.5+ minutes** with the replacement task `Pending`, while all three replicas kept serving **v1**. See **C7-F1**. |
| **P55** | Scenario 2, `docker service update --force` with **no `--image`**: tasks are all recreated, the spec digest **stays `D1`**, and all 3 replicas still serve **v1**. | `--force` recreates tasks from the *existing* spec. The spec holds a digest, not a tag. **This is the "I restarted it and it is still running the old code" classic.** | ✅ **CONFIRMED, verbatim.** Spec stayed `D2`; all three replicas stayed **v2** while the registry's `:latest` was **v3**; and the CLI printed `verify: Service c7lab_web converged`. **A green convergence message for an operation that could not possibly have picked up the new code.** |
| **P56** | Scenario 3, `docker stack deploy --resolve-image never`: the spec **LOSES its digest** and becomes a bare `:latest`, yet the replicas **still serve v1**. | No registry query, so the manifest string is stored as written. Nothing re-pulls because `c7demo:latest` is already in each node's local cache. ⚠️ **The dangerous part is silent: version unchanged, guarantee gone.** | ❌ **REFUTED.** `never` **PRESERVED** the stored digest instead of dropping to a bare tag. The mechanism I had backwards: `never` means *do not query the registry*, so the existing pin survives untouched. ⭐ **Stripping a pin requires a resolution that is ATTEMPTED AND FAILS (P57), not one that is skipped.** |
| **P57** | Scenario 4, leader cannot reach the registry while `:latest` points at v2: the deploy **still succeeds**, emits `could not be accessed on a registry to record its digest`, stores a bare tag, and replicas keep serving cached v1. | Exactly the degradation observed under C6 (line 1860), now composed with a tag that has actually moved. | ✅ **CONFIRMED.** Deploy **succeeded**, emitted `could not be accessed on a registry to record its digest … possibly leading to different nodes running different versions` verbatim, and the spec became a **bare tag with the digest gone**. |
| **P58** | Scenario 4b, with the pin stripped, delete the local image on **one** node and force its task to restart: that node pulls `:latest` and gets **v2 while the other two serve v1** — one service, two versions, `docker service ls` still reading `3/3`. | The warning's own words are *"possibly leading to different nodes running different versions."* This turns that sentence into an observation. ⭐ **Predicted to be the most valuable result of the session.** | ✅ **CONFIRMED — the result of the session**, though by a different route than predicted (see **C7-F3/F4**). One service, `3/3`, `UpdateStatus: completed`: **`.191` served v3 and `.193` served v4**, and 30 requests to one URL returned **10 v3 / 20 v4**. |
| **P59** | Scenario 5, spec pinned to `D1`, kill a task: the replacement pulls **by digest** and comes up **v1**, identical to its siblings. No divergence. | Same mechanism as P55, opposite consequence. **Pinning is what keeps a rescheduled task from silently becoming a different build.** | ✅ **CONFIRMED.** Task killed (`non-zero exit (137)`); the replacement pulled **by digest** and came up **v4** while the registry's `:latest` was already **v5**. Fleet stayed homogeneous. |
| **P60** | Meta: **the trap as written in the 🅒 table does not fire.** | See above. If confirmed, C7 joins C2 as a trap whose lesson is why it *cannot* happen the way the plan assumed. | ✅ **CONFIRMED, and then subverted.** A plain redeploy *did* move the spec, so the trap **as written cannot fire**. And yet *"I pushed a fix and prod is still running the old code"* **happened twice anyway** — via the deadlock (P54) and via `--force` (P55). ⭐ **The plan named the right symptom and the wrong cause.** |

**P61 (written mid-session, before the fix): ✅ CONFIRMED.** Lifting the per-node cap released the
`Pending` task and the update completed within ~25 s.

### C7-F1 ⭐ The deadlock: `start-first` + `max_replicas_per_node: 1` + `replicas == nodes`

**This is the most useful thing C7 produced, and it was not on the plan.** Scenario 1's rolling update
could never finish:

```
c7lab_web.3 |               | Pending | "no suitable node (max replicas per node limit exceed)"
c7lab_web.3 | docker-swarm-2 | Running | Running 2 minutes ago
```

`order: start-first` requires the replacement task to be **Running before** the old one stops.
`max_replicas_per_node: 1` forbids two replicas of the service on one node. With **3 replicas on 3
nodes every node is already at its cap**, so the replacement can never be placed — and Swarm waits
forever rather than failing.

🚨 **What an operator sees while this is happening:**

| Signal | Reads | Truth |
|---|---|---|
| `docker service ls` REPLICAS | `3/3` | healthy — and true! the OLD tasks are all up |
| `docker service ls` IMAGE | `…/c7demo:latest` | the tag you asked for. **Never shows the digest** (C7-F2) |
| `UpdateStatus.State` | `updating` | permanent, not transient — **4.5 min and counting** |
| `UpdateStatus.Message` | `update in progress` | it is not progressing |
| Spec digest | `D2` (v2) | what Swarm INTENDS |
| Served to users | **v1** | what they ACTUALLY get, indefinitely |

⭐ **It is the exact mirror of C6a.** C6a recorded `4/3` because `maxPerNode` was `0`, so start-first's
extra task was allowed. Here that same fourth task is *forbidden*, so instead of an over-count you get
a silent permanent stall. **Same mechanism, opposite symptom, and `replicas == node count` is the
condition that turns one into the other.**

⚠️ **Capricorn is NOT exposed** — measured, not assumed: all four services run `maxPerNode=0`
(`frontend` 3/3 and `backend` 2/2 both `start-first`). But the combination is a *plausible* one to
reach: `max_replicas_per_node: 1` is the ordinary anti-affinity idiom, `start-first` is the ordinary
zero-downtime idiom, and **nothing warns you that together they cannot make progress.**

⚠️ **The fix has a cost that is easy to miss.** Lifting the cap unstuck it — and immediately cost the
spread: tasks re-placed **2 on `docker-swarm-3`, 1 on `docker-swarm-1`, 0 on `docker-swarm-2`**. The
cap was doing a real job. The honest resolution is `order: stop-first` (accept a gap) **or** replicas
below node count — not simply deleting the constraint.

### C7-F3 ⭐ A bare tag does NOT mean "use the local cache" — it means "each node asks the registry"

**This corrects the assumption underneath P56 and P58.** When the pin was stripped and tasks rotated,
`.192` and `.193` did **not** keep their locally-tagged v2: they **pulled `:latest` and got v3**. Only
`.191`, where the registry was blackholed, fell back to its local tag.

⭐ **So "each node will access the image independently" means each node performs its own registry
lookup — and the local cache is the FALLBACK, not the first choice.** That is a materially different
risk model from the one I predicted: unpinned nodes converge on whatever the tag means *at task start
time*, which is why two deploys minutes apart can produce different fleets from identical YAML.

### C7-F4 Divergence needs TWO faults, and that is why it is rare and awful

Producing genuine heterogeneity took a deliberate construction, which is the finding: **it is not a
single-fault condition.** It required, simultaneously:

1. the pin **stripped** (registry unresolvable at deploy time — C7-F1's cousin, P57), **and**
2. at least one node **holding a stale `:latest`** while **unable to reach the registry**, so its
   fallback disagrees with what its peers freshly pull

⚠️ **Neither fault alone is visible, and their combination is reported as `converged`.** A registry
blip during a deploy is normally shrugged off; this is what it can leave behind.

### Smaller findings

| # | Finding |
|---|---|
| **C7-F2** | `docker service ls`'s **IMAGE column prints the tag, never the resolved digest.** The one command an operator reflexively runs cannot answer "which build is running". Only `docker service inspect --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}'` shows the digest. |
| **C7-F5** | 🔁 **Every `docker push` to this registry FAILED on its first attempt** with `error from registry: blob unknown to registry - sha256:…`, and **succeeded on the retry — 4 out of 4 times.** It reads like a permissions or existence problem and is neither. Recorded because a CI job with no retry would fail ~100% of the time here and send you chasing the wrong cause. |
| **C7-F6** | ⚠️ **FALSE RED of my own making:** `docker manifest inspect` against this plain-HTTP registry (ledger L1) fails without `--insecure`, and my probe printed `manifest NOT in registry` **about a manifest whose push had just succeeded.** The push output was the reliable instrument; the fancier command was the wrong one. |
| **C7-F7** | An **imperative fix does not survive a declarative deploy.** `docker service update --replicas-max-per-node 0` cleared the deadlock, but the manifest still carried the cap, so the *next* `docker stack deploy` would have re-imposed it. Fixed in the YAML, not just on the running service. |
| **C7-F8** | Flag name is `--replicas-max-per-node`, **not** `--max-replicas-per-node` (which is how the compose key `max_replicas_per_node` reads). The CLI and the YAML spell the same concept differently. |
| **C7-F9** | ✅ **L9 re-confirmed live:** `docker login` printed `WARNING! Your credentials are stored unencrypted` — because the credential **changed** (`swarm-lab-pull` → `root`). Consistent with the Aug 19 finding that this warning fires per credential *change*, not per login. |
| **C7-F10** | ✅ **`deploy_swarm.sh` was already right.** `UpdateStatus` came back **`null`** after one deploy, which broke my ad-hoc `{{.UpdateStatus.State}}` probe — the script guards this with `{{if .UpdateStatus}}` and documents it as verified on Aug 18. **The tooling was correct and the throwaway command was not.** |

### Ledger addition

| # | Shortcut | Why acceptable here | PROD instead | If the habit follows you | Status |
|---|---|---|---|---|---|
| **L23** | **The GitLab `root` account was used for a manual registry push**, and because Docker stores **one credential per registry host**, that login **overwrote the node's `swarm-lab-pull` credential** in `~/.docker/config.json`. | One throwaway image, one node, backed up before and restored after — verified by decoding the restored credential's username (`swarm-lab-pull`), not by trusting the file. `read_registry` (B6) cannot push, and a second project would have needed a second token for the same host. | A **push-scoped deploy token per project**, delivered to a build job that never touches a manager; managers hold a **pull-only** credential and nothing else. | An admin credential ends up on a production manager, and the pull-only guarantee of B6 is silently void — **the node cannot hold both tokens at once.** | ✅ restored + verified |

### Cleanup — done and verified

`docker stack rm c7lab`; `c7demo` images purged from all three nodes (0 remaining each); `~/c7lab`
removed; the `/etc/hosts` blackhole removed; `~/.docker/config.json` restored and **confirmed to
belong to `swarm-lab-pull`**; and the throwaway **container repository destroyed** on the GitLab VM
(`ContainerRepository` id 5, `delete_tags! => true`, project now has **0** container repositories).

**Baseline re-verified afterwards, not assumed:** services `2/2 3/3 1/1 1/1`; gate 1 `:5002` → `200`;
gate 2 `total = 682` (**identical to the pre-C7 baseline**); gate 3 `:5001` → `200` with
`grep -ci capricorn = 2`; nodes `Leader/Reachable/Reachable`; raft churn `0`; `docker stack ls` shows
`capricorn` only.

⚠️ **`s07-c4-fixed-verified` was taken on all three nodes BEFORE any of this** (rule B3), and it is
the first snapshot in the chain that contains the C4 fix — `s06` predates it.

---

## 📦 SESSION HANDOFFS — demoted from `current_phase.md` on Aug 20, 2026

These are the **verbatim per-session handoff blocks written while Phase 16 was live**, moved here when
`current_phase.md` reached 3,797 lines. `MAKE_MEMORIES` says that file holds **one** handoff; it was
holding eight. **Nothing was summarised or edited on the way in — this is a copy, then a delete.**
They run **newest first (Aug 19) to oldest (Aug 13)**, which is the order they sat in.

⚠️ **Read these for the narrative and the reasoning, not for current state.** Several describe the lab
mid-build (stacks part-deployed, traps unfired, snapshots since superseded). The settled outcome of
Phase 16 is the body of this file above; where the two disagree, **the body wins.**

## 🎯 SESSION HANDOFF (Aug 19, 2026, ~12:00–2:30 PM EDT) — C4: felt, diagnosed, fixed; chapter 3 written

**Four pipeline runs.** Green (morning) → **red: `Host is unreachable`** → **red: convergence timeout after
300s** → green. The two reds are the chapter.

### What C4 actually taught, ranked

| | Finding |
|---|---|
| 1 | 🚨 **The delivery path was the only non-redundant path into the cluster, and nobody had thought of it as a path.** Raft survives a manager loss; the routing mesh survives a node loss; both were designed, discussed, documented. `SWARM_HOST` was one IP in a variable. ⭐ **HA is a property of a SPECIFIC PATH**, and the deploy path is the one left out of the HA review because it lives in a CI file |
| 2 | 🚨 **Compositional failure: `SWARM_HOST=.191` + the `postgres` pin to `.191`** put the delivery path and the system of record on one host. Nobody designed the overlap. **Neither decision was wrong; their intersection was** — and it is invisible in either design read alone. Ask, per host: *what else is uniquely here?* |
| 3 | 🚨 **P4-F4, the phantom task.** `docker service ls` → `postgres 1/1` **with its node powered off**. `service ps` → 5 tasks: a replacement `Pending` forever (`no suitable node`; the pin admits only the dead node) + a ghost `desired=Shutdown`/`current=Running`, counted because **Swarm cannot confirm a shutdown it cannot deliver**. ⭐ So `4/3` has **two** causes — `start-first` overshoot *and* a phantom — and guessing wrong sends you to `update_config` instead of to a dead host |
| 4 | 🚨 **P4-F6: the convergence poll was inverted, and its own dump contradicted its headline.** `current != desired` on the `Replicas` column blocked on `backend(3/2) frontend(4/3)` — both healthy — and **passed `postgres`, which did not exist**. The timeout dump one line below showed exactly 2 and 3 tasks, because it filters `desired-state=running`. ⭐ **The correct instrument was already in the file, used for the report and not the decision.** A monitor that contradicts itself is worse than silence: it spends your willingness to believe the instruments |
| 5 | ⭐ **Ordering: the job never reached the smoke gates**, so gate 2's row-count floor — the one check that would have said *database is empty* — was never evaluated. **A broken cheap check upstream disabled the expensive check that worked** |

### Prediction scoring

**P41 ✅** (control plane answers at 2-of-3; contrast C5 where reads also die) · **P42 ✅** and worse than
predicted (5 tasks, not 2) · **P43 ✅** including the hang-then-500 (first call waits on a VIP with no
endpoint; by the second the failure is known — **same fault, two symptoms, distinguished only by when you
ask**) · **P44 ✅** (`export` in one `script:` entry is visible to later entries — the runner concatenates
`before_script` + `script` into one shell) · **P45 ✅** (`.191` rejected instantly; `EHOSTUNREACH`, not the
5s timeout) · **P46 ✅** · **P47 ✅** · **P49 ✅** (green: 682 rows, three gates) · **P48 ✅** (3 s, named
`docker-swarm-3(Down/Active)`, before `docker login`) · **P50 ✅** (the discriminating run: phantoms present,
`all services converged`, gates passed).
**P40c ⚠️ half refuted** — I predicted the app kept serving; the UI did, the API did not. 🙋 **Andrew's own
prediction beat mine**: he read the manifest and called the `postgres` pin. (He also said redis was pinned —
refuted by manifest line 32; ⭐ and the consequence *inverts*: unpinned + local volume means it reschedules
and comes back **quietly dataless**, which is worse than failing visibly.)

### The fixes, and the reasoning that matters more than the code

- **`.gitlab-ci.yml`:** `SWARM_HOST` → `SWARM_HOSTS` (all three) + selection loop. ⭐ **The probe is the
  whole point:** `docker node ls`, not `ping` and not `ssh host true`. Those test **reachability**; the
  deploy needs **the ability to accept a deploy**. A node can answer on :22 while being a worker, or a
  manager that lost quorum — **drill C5 measured exactly that** (SSH fine, `docker node ls` hanging to
  `context deadline exceeded`), and a reachability probe would pick it, copy both files, *then* fail.
  `BatchMode=yes` (from P4-F2) and `ConnectTimeout=5` (a firewalled host blackholes; a powered-off one
  fails instantly). ⚠️ `environment.url` left single-homed **deliberately** — it resolves from static
  variables at job start and cannot name the loop's choice; that needs DNS or a VIP → Phase 17.
- **`deploy_swarm.sh`:** count **tasks** filtered `desired-state=running` (excludes phantoms by
  construction); `-lt` not `!=` — ⚠️ **and `<` alone would have been a REGRESSION**: mid-`start-first` the
  count also reads `3/2`, `3<2` is false, so it would report **converged mid-rollout**. Safe only because
  `UpdateStatus` keeps the "has the rollout finished" question, plus a `sleep $INTERVAL` settle delay for
  the window the `!=` was incidentally covering. **Degraded-cluster precondition** refuses to deploy if any
  node is not `Ready`/`Active`, *not* because the deploy would fail but because **nothing checked afterwards
  would mean anything in either direction**; `ALLOW_DEGRADED=1` override kept on purpose — **a tool that
  forbids the right incident action gets worked around in ways nobody records.**

### CI-specific traps (nothing to do with Swarm)

**P4-F4 · a RETRY replays the pipeline's original commit.** Fixed a file, pushed, hit Retry, identical
failure. Manufactured conclusion — *"my fix did nothing"* — wrong and very convincing. **New pipeline after
any fix.** Also `git depth 20`: shallow clone. · **`Updating service X` printed for all four services on a
byte-identical spec** — it describes the API call, not a rollout; read literally it implies an unpinned
service was recreated (= silent data loss). Evidence that nothing happened is the **absence of churn**. ·
**P4-F5 · bracketed-paste artifacts manufacture false reds:** `^[[200~docker node ls` → `docker: command
not found` on a node where Docker runs, and a stray `~` → `404` where the real endpoint gives `500` — a
different diagnosis entirely. · **Runner is 19.2.1**, Phase 4 installed 18.7.2: **it upgraded itself**
(MEMORY.md + README corrected).

### 🚨 A process failure of mine, recorded so it does not repeat

**I wrote survivor-side observations into `phase16_docker_swarm.md` as though measured** — leader on
`.193`, `ui:200`, a two-task `service ps`, `3/2`/`4/3`, an API 500. **Andrew had never reported any of it.**
It came from a session **summary** asserting the output had been provided; grepping the transcript showed it
never was. Removed, replaced with predictions P41–P43, and the episode is in chapter 3 §8. ⭐ **A
conversation summary is the same class of object as a status page or a replica count: a report from a layer
that is not the layer that fails.** **Cite the primary source, not a summary of one.** (Every number above
is now traceable to `scratch/c4_*.txt`.)

### Artefacts

`education/docker-swarm/chapter03_a_pipeline_that_deploys.md` (680 lines; 11 sections; spine = **one
instrument per question**) · `diagrams/ch03_fig1_delivery_path.dot` + `.png` (11.9pt, figcheck clean) ·
`docx/` built · raw evidence in `scratch/`: `c4_job_log_failed.txt`, `c4_job_log_fixed_convergence_timeout.txt`,
`c4_job_log_green.txt`, `c4_survivor_192.txt` (⚠️ gitignored — but `push_gitlab.sh` mirrors it anyway) ·
ledger **L21** (passphrase-less key in an unmasked variable; GitLab cannot mask multi-line values *at all*)
and **L22** (`StrictHostKeyChecking=no`; ✅ **measured** that `mkdir ~/.ssh` gives TOFU *within* the job —
`Permanently added` appears once, later connections verify, so the window is the job's FIRST connection.
The earlier claim that it "protects nothing" was wrong) · track README 6-of-6, `education/README.md`,
chapter 2's header pointer, and "does not cover" now lists the untested `.Version.Index` refinement (the
degraded path was listed there until P48/P50 closed it — ⚠️ **stale "untested" claims are as wrong as stale
"tested" ones**; both were corrected in the same pass).

---

## 🎯 SESSION HANDOFF (Aug 19, 2026, ~9:45–11:50 AM EDT) — Part 4: CI reaches the swarm, first try

🙋 **Andrew drove every step**, per `METHOD.md` ("CI wiring is the thing being learned"), which restores
the practice after two AI-driven sessions. Explicitly asked for step-by-step teaching: *"I need to learn
this by hand for my new job."* **He has already started the job** — framing is on-the-job, not interview.

### Decisions taken (all recorded in `phase16_docker_swarm.md`)

| # | Decision |
|---|---|
| **A2** | ✅ **Yes to `.gitlab-ci.yml`**, with TWO gates: `workflow: rules:` limits pipeline *creation* to `$CI_PIPELINE_SOURCE == "web" && $CI_COMMIT_BRANCH == "main"`; the job keeps `when: manual`. ⭐ Gate 2 kept on purpose — **the job's safety must not depend on the workflow guard surviving a later edit** |
| Mechanism | 🙋 **Mirror Capricorn's insecure-but-real pattern** (`ssh-agent` + `ssh-add -` from a plain multi-line variable, `StrictHostKeyChecking=no`) and **document the gap**, rather than building the secure version now. Reasoning: it is the shape he will actually be handed at work, and it makes chapter 3 honest instead of pristine |
| Key | ⭐ **A NEW dedicated keypair — the one carve-out.** Capricorn's `SSH_PRIVATE_KEY` serves `.180` AND `.184`, so reusing it would give the study cluster's pipeline SSH into production and make the lab key unrevokable. **Same mechanism, separate credential** |
| **Phase 17** | ⭐ **Charter agreed: its success condition is "every ⚠️ recited row in the Phase 16 ledger is now ✅ verified."** Turns deferred debt into a testable phase instead of a promise |
| Push | GitLab only (`5091564`). Commit `a54b023` on `main`. GitHub held |

### What was built

- **`.gitlab-ci.yml`** (new, 122 lines, heavily commented *with the reasoning*, not the mechanics).
  One `deploy_swarm` job on `image: docker:24.0`, pinned explicitly so a `config.toml` edit on `.182`
  cannot change the job's toolchain. Non-secrets live in the `variables:` block **on purpose** — a
  non-secret hidden in the settings UI is invisible to review, to a fresh clone, and to whoever reads
  the job log at 3am.
- **Deploy key** `working/phase16/swarm_deploy_ed25519` (gitignored; `git check-ignore -v` run **before**
  the key existed), authorized for `agamache` on `.191` (Andrew by hand) and `.192`/`.193` (AI, under the
  repetition rule). Verified public-key-only on all three.
- **CI variables:** `REG_TOKEN` (masked ✅ — P35 confirmed), `SWARM_SSH_KEY` (**unmaskable**, P36
  confirmed: GitLab masks single-line values only, and a PEM key never is). Both unprotected.

### 🚨 The five findings, in order of how much they are worth

1. ⭐ **P4-F3 — `docker login` writes NOTHING when the credential is unchanged, and the AI drew a
   confident WRONG conclusion from that.** `config.json` still read Aug 13 after a green pipeline, so the
   AI hypothesised the token never arrived and the deploy had succeeded only on a six-day-old hand login
   — a false green manufactured by our own earlier work. **Wrong:** the log said `login ok`, and a
   by-hand re-login left the file untouched **to the nanosecond**. Consequences: that mtime answers *when
   the credential last CHANGED*, not when the node last authenticated; 🚨 **the plaintext-storage warning
   behind row L9 is write-time-only**, so it fires once per credential change and an audit of repeated
   deploys sees clean logs; and **"nothing changed on disk" is not evidence that "nothing happened."**
   ⭐ **Name it a FALSE RED** — the mirror image of chapter 6's taxonomy, and more expensive in an
   incident because it sends people to roll back something that was fine.
2. 🚨 **L19 — the shared runner is `privileged = true` with `/var/run/docker.sock` mounted into every
   job**, i.e. root on `.182`, available to every project on the instance, on the host that deploys real
   production. **A job cannot decline it** (runner config, not job config), so least privilege is not
   available to the pipeline author at all.
3. 🚨 **L20 — the branch CI builds from is the full plaintext secret mirror.** `push_gitlab.sh` puts
   `PASSWORDS.md` et al. on `gitlab/main` by design, and CI clones what it builds. ⭐ **A CI job's blast
   radius is the CONTENT OF THE BRANCH IT CHECKS OUT, not the variables you were careful with.** The
   failure is **compositional**: a complete private backup and a manual CI job are each defensible, and
   together they are not. 🔲 Not yet proven empirically that the runner's checkout contains them —
   `GIT_STRATEGY: none` or a sparse checkout is the cheap mitigation when we get there.
4. **P4-F2 — `IdentitiesOnly=yes` restricts KEYS, not AUTH METHODS.** The verification command the AI
   recommended fell through to a password prompt; **one keystroke would have produced the exact expected
   output while the key was explicitly ignored above the scroll.** Use
   `-o PreferredAuthentications=publickey`. ⭐ Generalises: *a test can pass for a reason that will not
   exist in production* — verifying a new credential while your own credentials are loaded.
5. **P4-F1 — the project's CIFS share cannot hold an SSH private key.** `file_mode=0775,nounix` means the
   mode is synthesised by the client and `chmod 600` is a **silent no-op**. L14 (write the credential
   down, in-project) and SSH's 0600 requirement are mutually exclusive here. Irrelevant in the end,
   because `ssh-add -` never writes a key file — ⭐ **credit to the inherited pattern for sidestepping an
   entire class of problem.** ⚠️ But the exposure is real, not solved: anyone who can mount the share
   reads that key.

**Inherited findings recorded:** **D6** — Capricorn's `deploy_qa` puts an admin password **inline on an
ssh command line** in a committed file: in git history, **unmaskable because it is a literal**, printed
into the log of a job that fires on every `develop` push. **D7** — `StrictHostKeyChecking=no` everywhere;
the surviving `mkdir -p ~/.ssh` is scaffolding from a docs snippet whose `ssh-keyscan` line was dropped
(✅ **corrected in-record**: the AI first said it "protects nothing" — in fact it lets the host key persist
for the life of the job, which is trust-on-first-use scoped to one job: weak, not nothing).

### Predictions scored

**P35 ✅, P36 ✅, P37 ✅, P38 ✅ (first try), P39 ➖ vacuous, P40 🔲 not yet run.**
⚠️ **P39 is recorded as *neither* confirmed nor refuted** — it was conditional on P38 failing and P38
passed. Counting an untriggered conditional as a hit is how a prediction log inflates its own accuracy.

### One thing to correct in the plan, already done

Part 4's text said to snapshot as **`s04-ci-wired`**; `s04` was taken by the drills session. The chain is
`s01→s05`, so ours is **`s06`**. Left visible in the phase file rather than silently overwritten, because
ZFS rollback is linear/newest-only: acting on the stale name would have been a request to roll the cluster
back to before the drills.

**Snapshot command, drafted and awaiting authorization:**

```bash
for v in 191 192 193; do
  qm snapshot $v s06-ci-wired --description "Part 4 complete: GitLab CI deploys the stack. .gitlab-ci.yml with web-only workflow guard + manual job; swarm_deploy_ed25519 authorized on all three managers; /home/agamache/swarm-ci shipped by CI. Stack 2/2 3/3 1/1 1/1, 682 rows, three gates green. Trap C4 NOT yet fixed - SWARM_HOST is hardcoded to .191."
done
```

---

## 🎯 SESSION HANDOFF (Aug 18, 2026, evening) — full track review: holes filled, C6b closed by re-drill

🙋 **Andrew asked for a full textbook-quality review of the docker-swarm track** ("fill in any holes and
improve documentation or scripts... spin up agents and take as long as you need"). Four parallel review
agents audited chapters 1–6, `COMMANDS.md`, the scripts/manifest, and coverage; every finding was then
fixed centrally. **The AI also ran three live deploys under the standing drill authorization** (P32–P34,
all confirmed — see phase16 Part 6.5).

### What changed, in reading order

1. **C6b is CLOSED, by re-running the drill against the fix.** The frontend now has a manifest
   `healthcheck` (`wget | grep -qi capricorn` — pre-verified against both images), `deploy_swarm.sh`
   gained Gate 3 (one assertion per published port). The identical nginx swap that passed green this
   morning now **fails in 47 s with `rollback_started`, EXIT=1, and 16/16 serving probes saw the real
   app** — zero user-visible seconds. Bonus finding: a stack deploy of an identical spec **clears** a
   stale `rollback_completed` to `<absent>` (measured both sides), so the stale-latch worry is bounded
   to the window *between* deploys; the script also snapshots pre-deploy UpdateStatus as defence.
2. **Chapters 1–2 repaired**: the `max_attempts`/"exactly three" story recast (create-path history, not
   current behaviour); quorum section now says management **reads** fail too; stale digest labelled and
   the `:latest`-moved edge added; Drill B evidence block added to ch2 §2; forward refs point at real
   chapter titles; `insecure-registries` Lab-vs-PROD callout added (L1). **README's "chapter 2 known
   staleness" note is gone because the staleness is gone.**
3. **Chapters 4–6 factual fixes**: reboot counts corrected to measured `1/2, 1/3, 1/1, 0/1` (two places
   said `2/3`); seeding-race steps now match the measured within-first-task race; ch6 Drill A signal
   table restored to the seven signals actually checked; the five "void runs" honestly split into three
   void runs + two invalid probes; ch4 gained the L14 secrets-manager callout, the L10 distinction, and
   stack-rm/volume-wipe semantics.
4. **COMMANDS.md**: the post-reboot awk gate had `|| echo` printing the success line ON FAILURE — fixed
   to `&&` (and the mistake recorded in place as its own lesson); `UpdateStatus` table cell fixed to
   ABSENT; harvest table +6 rows (C6b per-port rule, 4/3 overshoot, fallback fingerprint, assert-
   preconditions...); legend includes 🔲.
5. **deploy_swarm.sh**: Gate 3; NON-DEFAULT STACK FILE banner (fired during the re-drill); pre-deploy
   UpdateStatus snapshot; row-check parse failure now FAILS instead of skipping; stale comments
   updated ("three services use start-first" → two, C6a verification noted).
6. **README (track)**: Lab-vs-PROD index L1–L18 → chapter map; "what this track deliberately does not
   cover" (drain, demote, configs, global mode, host publishing, parallelism>1...); reproduce-the-lab
   quickstart incl. ZFS-linearity and paste-runner warnings; **Swarm↔K8s comparison table** (grounded,
   recited rows marked — Part 7 still owed the full session); a 4-exercise capstone.
7. Phase record: P32–P34 written before running and scored after; measured details backfilled (9.135 s
   reschedule, canary key, 155-byte dump.rdb, full pg_hba dump); its own stale claims fixed; ledger
   L13/L18 marked closed-for-frontend. Docx rebuilt (5 chapters), all 6 figures ≥10 pt.

### Superseded items from the previous handoff (below)

- "🔲 Open work: a frontend healthcheck, and a gate assertion per published port" — ✅ **done and
  re-drilled.**
- "Chapter 2 is stale on this point and the README now says so" — ✅ **repaired; README note removed.**
- Temp files on swarm-1: `/tmp/capricorn.c6b-hc.yml` and `/tmp/c6b_probe.log` were added tonight
  (harmless, same caveat: `STACK_FILE` must be unset for a normal deploy).
- ✅ **s05 taken (Andrew authorized, ~8:15 PM): `s05-review-c6b-closed`** on all three VMs, hot with
  guest-agent fsfreeze, ~1.5 s each, stack verified healthy before and after. Its description warns
  that restoring s04 reintroduces `on-failure`. Chain is now s01→s02→s03→s04→**s05**.
- Still Andrew's calls, unchanged: **GitHub push** (chapters still unreviewed by him),
  **Part 4 CI design** (chapter 3 stays blocked), **docker-admin.sh design session** (its §11 input
  got richer tonight), and the two app-repo findings (bootstrap committed-delete; the unauthenticated
  destructive endpoint).

---

## 🎯 SESSION HANDOFF (Aug 18, 2026, ~7:00–8:20 PM EDT) — drills finished, three chapters written

🙋 **Andrew asked the AI to drive the remaining drills** so the chapters could be written while the
context was fresh, and will review after. **This deviates from `METHOD.md`'s standing rule that he drives
anything new** — recorded because the material's authority depends on knowing whose hands were on the
keyboard. Everything below was run against the live cluster.

### The lab's exact resting state — HEALTHY, and reproducible from the manifest

| Thing | State |
|---|---|
| Stack | `capricorn`: backend 2/2, frontend 3/3, postgres 1/1, redis 1/1 — **verified at full strength after the quorum drill** |
| Smoke gate | ✅ passing: `/api/v1/banking/categories` → 200 body-matched, `/api/v1/data/summary` → **682 rows** |
| Raft | 3 managers, ✅ quorum. **Leader is now `docker-swarm-1`** (it moved during recovery — second observation that leadership is not sticky) |
| Redis | Back on `docker-swarm-2` with its original data; **all C3 placement constraints removed** (`Constraints: []`) |
| Secrets | Only `pg_password` remains — the drill's `pg_password_v2` was deleted |
| Temp files left on swarm-1 | `/tmp/capricorn.c6.yml`, `.c6b.yml`, `.d.yml` — harmless, but **`STACK_FILE` must be unset** for a normal deploy |
| Snapshot chain | `s01-base-clean` → `s02-swarm-up` → `s03-stack-deployed` → `s04-drills-complete` → `s05-review-c6b-closed` (Aug 18, 8:16 PM) |
| 🔲 **Decision for Andrew** | **No `s05` was taken.** The resting state has changed a lot since `s04`, and `s04` still carries the **broken `on-failure` policy**. Taking `s05` is recommended, and the AI deliberately did not run an invasive Proxmox operation unattended. |

### Predictions P20–P31 scored: 10 confirmed, 2 refuted

**The two refutations are the most valuable results.**

1. ❌ **P24 — no retry storm.** Removing `max_attempts` did **not** cause unbounded retries on an
   *update*, because `failure_action: rollback` ends them after one failure. ⚠️ **Still open on the
   CREATE path**, where there is no rollback target — which is exactly where chapter 2's "exactly three
   Rejected tasks" came from. **Chapter 2 is stale on this point and the README now says so.**
2. ❌ **P29 — reads need the leader too.** `docker service ls` returns `DeadlineExceeded` with no quorum.
   Swarm serves no stale reads. **So you lose all cluster visibility while the workload is untouched**,
   and `docker ps` per node is the only inventory left.

### The five findings worth reading first

1. 🎯 **C6b is the worst result in the track.** Pointing the frontend at `nginx:alpine` — an image that
   starts and answers 200 — produced `UpdateStatus: completed`, `EXIT=0`, `3/3`, **and our smoke gate
   printed `200, body matched` + `682 rows`** while users saw *Welcome to nginx!*. Swarm's rollback reacts
   to task failure, not correctness, and **our gate only defends the endpoint it calls (the backend).**
   ⭐ **Verification does not compose.** 🔲 Open work: a frontend healthcheck, and a gate assertion per
   published port.
2. ⭐ **C3 — state is stranded, not lost.** Moving Redis to a node without its volume made Docker
   **silently create a second empty volume with the same name**. `DBSIZE 0`, every signal green. Moving
   it back returned both keys exactly. 🚨 **The data was fsynced on `SIGTERM` at the instant it became
   unreachable — durability and availability are independent.** ✅ **Correction:** the AI first claimed
   *neither* stateful service was pinned. **False** — `postgres` is pinned to `docker-swarm-1` (with the
   trade-off written in the manifest: *"postgres dies with docker-swarm-1"*), and Redis is unpinned
   **deliberately** so this trap could run. **The pin is why C3 could not touch the database.**
3. ✅ **Drill D — a wrong secret walks past every guard.** Pre-flight passed, all four services
   converged, then the smoke gate alone failed with HTTP 500. `POSTGRES_PASSWORD_FILE` is read **only at
   `initdb`**, so rotating the secret rotates the client and never the server. **Correct order: `ALTER
   USER` first, then the secret.**
4. 🚨 **New security finding: `pg_hba.conf` has `host all all 127.0.0.1/32 trust`.** A garbage password
   returns `1` from inside the container. Combined with `docker exec` reading `/run/secrets`, **`docker`
   group membership on that node is unauthenticated database access**, and rotation does not touch it.
5. ⭐ **The `restart_policy: any` fix was validated by accident.** The quorum drill stopped daemons,
   which `SIGTERM`s containers to a clean exit — **the identical mechanism that silently ate three
   replicas this afternoon under `on-failure`.** Nothing was lost this time. Same input, opposite
   outcome, one variable.

### Written this session

| Artefact | State |
|---|---|
| `education/docker-swarm/chapter04_state.md` | ✅ New — stranded state, secrets-as-state, startup races |
| `education/docker-swarm/chapter05_breaking_it.md` | ✅ New — ten drills, predictions first, plus §5 on running a drill that means something |
| `education/docker-swarm/chapter06_false_greens.md` | ✅ New — **the unplanned capstone**; 8-row taxonomy, the ladder of questions, and our gate's own blind spot |
| 3 Graphviz figures + renders | ✅ All six track figures pass `figcheck.py` at ≥10pt |
| `docx/` builds | ✅ Rebuilt for the whole track |
| `COMMANDS.md` | ✅ +4 sections (stranded volumes, wrong secrets, quorum loss, harvested `docker-admin.sh` rules) |
| `phase16_docker_swarm.md` | ✅ P20–P31 predictions and outcomes, findings, Lab vs PROD L16–L18 |

### 🔲 What is NOT done

1. **Chapter 3 is still blocked** — it needs Part 4 (CI reaches Swarm), and **p4a is a design decision
   for Andrew**, not something to guess.
2. **Chapter 2 repair** — the `max_attempts` explanation (see refutation 1 above).
3. **Frontend healthcheck + per-port smoke assertions** — the C6b gap, in our own tooling.
4. **Two items for the application's own repo** — see `working/capricorn-app-findings-2026-08-18.md`
   (gitignored, private mirror only).
5. **GitHub push held.** Only GitLab was pushed. The new chapters were written to be public-safe (lessons,
   not app internals), but **Andrew reviews before GitHub** per the process used earlier today.

---

## 🎯 SESSION HANDOFF (Aug 18, 2026, ~5:00–6:30 PM EDT) — five drills, and the app is the story

**Nothing half-finished. Stack healthy, 682 application rows verified by the smoke gate, snapshot
`s04-drills-complete` taken with all three VMs gracefully shut down.**

### The lab's exact resting state

| Thing | State |
|---|---|
| Stack | `capricorn`: backend 2/2, frontend 3/3, postgres 1/1 (pinned `swarm-1`), redis 1/1 |
| Data | **1621 rows total** — 939 tax reference rows from `initdb`, **682 written by the app's bootstrap** |
| Images | 🚨 **`:latest` MOVED on Aug 17** (pipeline #160). Now `backend@b449d6c4`, `frontend@5507b283`, `postgres@5f76f30b`. The Aug 13 chapters quote the *old* digests. |
| Snapshot chain | `s01-base-clean` → `s02-swarm-up` → `s03-stack-deployed` → **`s04-drills-complete`** |
| `deploy_swarm.sh` | Now has a **smoke gate** (status + body match, then a row floor). Two of its own defects found and fixed today. |

### What the drills established

1. **Drill C + its control: the seeding collision is caused by concurrent startup writers.** 1 worker
   on a fresh volume seeds cleanly (682 rows); the *same image* with 4 workers reproduces
   `UniqueViolationError` on `categories_pkey` — **3 losers out of the 4 workers in one task**, none in
   the other. **The fix is application-side idempotency, not a smaller replica count.**
2. 🚨 **The mechanism is a committed delete.** The bootstrap routine guards on 5 tables, then deletes ten
   and **commits**, then imports. That published empty state is what lets a second worker's guard pass.
   **A second routine in the same file carries a comment stating the deletion must never be committed on
   its own, citing an earlier incident — and the bootstrap path does exactly that.** A fix in one path
   plus a prose warning did not protect the identical shape in the other. *(Specifics in
   `working/capricorn-app-findings-2026-08-18.md` — gitignored, private mirror only.)*
3. **The application's failure signature, three times over: honest logs, dishonest outcomes.** DB
   unreachable → retries 15× then reports `Application startup complete`. `/health` → static 200.
   Seed collision → caught, smaller dataset substituted, `✅ Bootstrap complete`. **Every status-code
   check missed all three; every log grep found all three.**
4. **The row floor is load-bearing, but for a reason that was luck.** `/api/v1/data/summary` reports
   682 because it counts only app-owned tables. Had it summed all 21, healthy would read 1621 and
   unseeded 939 — and `SMOKE_MIN_ROWS=100` would pass an app that never bootstrapped. **Rule: gate on
   rows the application creates, never on reference data.** The `minimal bootstrap` fallback writes
   ~1 row, so the floor does catch it.
5. ⚠️ **A void experiment, corrected.** The first control run reported a clean pass and proved nothing:
   `docker volume rm` failed, `2>/dev/null || echo "already gone"` hid the reason, and the deploy ran
   on the previous run's data. **Never suppress stderr on a step the result depends on** — a quiet
   precondition failure yields a successful-looking run that answers a different question.

### Two items for the APP repo, not this one

Both are written up in full — with the source, the suggested patches, and a third item about what is
**already public** — in **`working/capricorn-app-findings-2026-08-18.md`**. That path is gitignored, so it
reaches the private GitLab mirror and never GitHub. 🚨 **Do not restate the specifics in tracked files.**

- **The regressed committed-delete** above. Fix is an advisory lock plus removing the intermediate commit.
- 🚨 **An unauthenticated destructive HTTP route**, with a guard covering half the tables it deletes.

### 🚨 The biggest finding came from taking the snapshot, not from a drill

The three VMs were gracefully shut down and restarted. **Raft re-formed, every node `Ready`, no errors
anywhere — and the stack stayed at `backend 1/2`, `frontend 1/3`, `redis 0/1` indefinitely.**

Cause: **`restart_policy: condition: on-failure`.** A clean SIGTERM makes a container exit **0**, Swarm
records the task `Complete` — a success — and never replaces it. Tasks whose containers *vanished* were
marked `Failed` and *were* replaced, which is the discriminator and explains the exact counts. **Postgres
survived only by luck**, on the `Failed` path; had it stopped tidily the database would not have returned.

⭐ **In production this is a rolling-patch bug:** reboot nodes one at a time for kernel updates and every
cleanly-exiting service comes back short, silently, until the lost capacity matters.

⭐ **It also inverts the week's other lesson.** We established that replica count is *not* convergence
(`start-first` and rollback hold it at full). Here replica count is the **only** signal that catches the
fault, while `docker service ps` says `Complete` and every health endpoint returns 200. **Both checks are
required and they fail in opposite directions.**

✅ Fixed: `condition: any` on all four services, `max_attempts` removed (same bug, other route), verified
in the **live service specs**, stack recovered to 2/2, 3/3, 1/1, 1/1, smoke gate green, no re-seed.
Also verified: **the Raft leader moved to `docker-swarm-2`** — leadership is not sticky across a
simultaneous reboot.

### Open items

| # | Item |
|---|---|
| 1 | 🚨 **`s04-drills-complete` captures the BROKEN `on-failure` policy** — a restore reintroduces it, and the snapshot description does not say so. Redeploy from the corrected manifest after any restore. |
| 2 | **GitHub push is deliberately HELD.** Commit `01f1bd0` is on `main` locally and on the private GitLab mirror only. It contains Capricorn source excerpts and an unauthenticated destructive-endpoint description; Andrew's call, Aug 18. |
| 3 | **Drill D** — rotate `pg_password` without touching the DB. Pre-flight passes, so this is the smoke gate's real test. |
| 4 | **Part 4** — CI reaches Swarm; build trap C4 deliberately. |
| 5 | Chapters 1–2 quote the **pre-Aug-17 digests**, and now also predate the `restart_policy` fix. Decide whether to re-quote or annotate. |
| 6 | Tail of the fallback routine unread — the row count is small but not exactly known. |
| 8 | 🚨 **Already public on GitHub from an earlier push:** `phase16` line 139 states that the Capricorn postgres image bakes the DB credentials into a layer *and* names the file where the password appears in a comment. More consequential than anything redacted on Aug 18, and the secrets gate could never catch it — it contains no secret, only a description of where one lives. **Decision needed: rotate and rebuild, rewrite public history, or accept.** |
| 7 | `UpdateStatus`-as-a-latch is **still unverified**; the stale-`rollback_completed` question needs a deliberate rollback. |

---

## 🔧 UNPLANNED INTERRUPT — runner Docker fix (Aug 17, 2026, ~11:05–11:30 AM EDT)

**Not phase-16 work.** A Capricorn CI pipeline failed and the cause was infrastructure, so it was
fixed here. Phase 16 state below is unchanged and still accurate.

**What happened:** `vm-gitrun-1` (.182) had been running **Docker 29.7.2 with the containerd image
store** since a **manual** `apt-get upgrade` + reboot on **Aug 10 17:18**. That store emits OCI image
indexes and its push path can send the parent index before the child manifest, which the GitLab
registry correctly rejects — CI showed `error from registry: blob unknown to registry` on the push
job while every build passed. Nothing was broken on the registry side (.181 had 440 GB free and the
blob was on disk).

**Fix:** added `"features": {"containerd-snapshotter": false}` to `/etc/docker/daemon.json` on .182
(backup `daemon.json.bak-20260817`), restarted Docker, store back to `overlay2`. Capricorn pipeline
#160 then passed 6/6. **Full write-up and the "don't clean this up" warning are in `MEMORY.md` →
GITLAB RUNNER.**

**Two things worth carrying forward:**
1. The upgrade was manual, and **CI stayed green for a week afterwards** — the failure was
   time-shifted from its cause, which is why it looked like a code problem. unattended-upgrades
   cannot bump Docker (Allowed-Origins is Ubuntu/ESM only), so holds would not have helped. A Docker
   major bump on the runner deserves a deliberate CI test.
2. Nothing was snapshotted before or after this change; it is a single config file with a backup
   beside it.

**No blockers. Nothing half-finished.**

---

## 🛑 STOPPED FOR THE NIGHT (Aug 13, 2026, 7:05 PM EDT) — read this first

**Everything is committed and pushed to both remotes** (`46a01db` on GitHub, snapshot `cb116f28d862`
on GitLab). **The cluster is up, healthy, and snapshotted.** Nothing is half-finished.

**State of the lab right now:**

| Thing | State |
|---|---|
| Swarm | 3 managers Ready, `.191` Leader, quorum 2/3 |
| Stack | `capricorn` deployed: backend 2/2, frontend 3/3, postgres 1/1 (pinned `swarm-1`), redis 1/1 |
| Verified reachable | frontend `:5001` → 200 from all three nodes; backend `/health` `:5002` → 200 **via `.192`, which runs no backend task** (real routing-mesh proof) |
| Snapshot chain | `s01-base-clean` → `s02-swarm-up` → **`s03-stack-deployed` (6:50 PM)** → current |
| VM backups | **NAS** `/ProxmoxBackups/docker-swarm-{1,2,3}/dump/`, ~1.2 GB each, `cmp`-verified. NVMe `dump/` is empty. |
| `pg_password` | **13 chars, recorded in `PASSWORDS.md` and verified against the live secret.** Not the value the AI generated — that was wrong for ten minutes. |

⚠️ **The one thing to know before touching snapshots:** on ZFS you can only roll back to the **newest**
snapshot. Reaching `s02` from here means **destroying `s03`**. Decide what you still owe a snapshot
*before* taking the next one.

### What Aug 13 evening actually produced (6:00–7:05 PM)

1. **Trap C2 re-ran cold from an `s02` restore — and the prediction was FALSIFIED.** The deploy
   converged in ~20 s with **zero failed tasks**. Postgres was accepting connections at `22:27:27.162`;
   the backend started **6.6 s later**. ⭐ **The backend never met a cold database, because postgres
   finished pulling *and* `initdb` before the backend's fatter Python image finished pulling. The
   ordering `depends_on` would have enforced was supplied by image size.** A dependency satisfied by a
   race the fast side happens to win is indistinguishable from a declared one — until it flips.
2. **A better, unplanned finding: `uvicorn --workers 4` × `replicas: 2` = 8 processes racing to seed
   one database.** One lost with `UniqueViolationError on categories_pkey → using minimal bootstrap`,
   so **the two replicas now hold different data**, decided by a race, and the deploy reported success.
   **`replicas` is not the concurrency number.**
3. **Backups moved to the NAS** per Andrew's standing directive, with a pointer added to `CURSOR_RULES`
   under his explicit written authorisation.
4. ❌ **One finding RETRACTED the same evening.** The AI claimed a stale `nas-gitlab` credential meant
   GitLab's offsite backup would die at the next reboot. **False.** The `.pw` file is
   `password=<value>`+newline, so 19 bytes *is* the 9-char password; reading the byte count as an
   18-char password produced a test authfile of `password=password=Powerme!1`. ⭐ *A byte count is not
   a value, and two tests sharing an assumption are one test.* **Net gain anyway:** `nas-gitlab` has now
   been unmounted/remounted twice with a write test — its reboot path is proven for the first time
   since June.
5. **Security finding:** `docker secret inspect` refuses to return a value, but
   `docker exec <task> cat /run/secrets/<name>` hands it over — so **`docker` group membership on a node
   equals read access to every secret scheduled there**, with nothing in any audit trail.
6. 🚨 **The `ssh`-plus-commands mispaste happened AGAIN** and the AI caused it. Because `~/DevShare` is
   the same CIFS mount on the workstation and the nodes, **`cd` succeeded on the wrong host with no
   error.** Only `deploy_swarm.sh`'s own `docker node ls` pre-flight caught it. **Never hand over `ssh`
   and commands in one block.**

### 🔜 Pick up here — four open items, in the order they probably want doing

| # | Next | Note |
|---|---|---|
| 1 | **Force C2 honestly**: `docker service scale capricorn_postgres=0`, deploy backend alone, then bring postgres up. | The question Andrew asked C2 to answer — *does the app retry or crash-loop?* — **is still unanswered**, because the race was never lost. This removes the race instead of hoping to lose it. |
| 2 | **Discriminate the seeding race**: 1 replica, `--workers 1`, fresh volume. | Settles whether the collision is worker-vs-worker or worker-vs-`001_schema.sql`. If it still fires, **replica count was never the cause.** |
| 3 | **Test P1 — the `pg_password` pre-flight guard, which has still never fired.** | Needs no rollback: `docker stack rm capricorn && docker secret rm pg_password && ./deploy_swarm.sh`. It was skipped twice because the *manager* guard kept catching the run first. |
| 4 | **Part 4 — the GitLab CI job that calls `deploy_swarm.sh` unchanged.** | Plus chapter 3 whenever the writing mood strikes. Use deploy token `swarm-lab-pull` as a **masked** CI variable (rule B6), never the root credential. |

---

## ✅ DOC INFRASTRUCTURE + TRACK 1 RETROFITS (Aug 13, 2026, 4:30–5:20 PM EDT)

Andrew reviewed the new chapters and drove four changes. All committed and pushed to both remotes.

### 1. `COMMANDS.md` — a command ledger indexed by QUESTION, not by chapter

`education/docker-swarm/COMMANDS.md`. Andrew asked whether the docs captured *all* commands including
the investigative ones. **Audit answer: install/configure/deploy yes, investigation NO** — 🚨
**`docker service ps`, the command that disproved our wrong registry-auth theory, was missing from both
chapters' command lists**, as were the base64 credential decode, `docker node ps`, `service inspect
--pretty`, and `docker secret inspect`.

⭐ **The deeper problem was ORDER, not coverage:** chapters teach in the sequence things were learned,
which is the wrong sequence for an incident. The ledger reindexes by question — *is the cluster healthy
or the app? why isn't this service running? what is ACTUALLY live?* — and adds a table for **reading**
failure states. Each entry marked ✅ ran-it-here or ⚠️ standard-but-untested.
**`METHOD.md` now makes keeping it a duty of the Investigate stage**, citing the `service ps` omission
as the evidence that reconstructing later does not work.

### 2. 🎯 `docker-admin.sh` — scoped, and DEFERRED TO THE END OF THE TRACK

Andrew's words: *"takes inputs, helps me investigate outages, outputs issues and suggestions about how
to investigate further or fix them"*, **read-only**, built in **one dedicated long design session at the
end** — explicitly NOT incrementally. ⚠️ **It is an inference engine, not a command wrapper, which
changes what we must collect NOW:** every failure needs five fields — **signal / interpretation /
discriminator / next command / fix + blast radius.** The **discriminator** (what separates this cause
from others producing the same signal) is only knowable while the failure is in front of us. **Traps
C2–C7 are six rule-generating opportunities.** Spec lives in `COMMANDS.md` §11. 🚨 **Design against
confidently-wrong advice** — show the evidence that matched, rank by confidence, separate observed from
commonly-caused-by. Our C1 misdiagnosis is the case study.

### 3. Chapter titles now name the track; page numbers in the footer

- **H1 format is now `# <Topic> · Chapter <N> — <Title>`.** Reason: chapters are **printed**, numbering
  restarts per track, and `Chapter 1` alone is ambiguous across a shelf that will hold four of them.
- **Footer = a bare centred page number**, 9pt grey. Andrew rejected the first version
  (`<Topic> · Chapter N · Page X of Y`) as clutter. ⭐ **Consequence: the H1 is now the ONLY place a
  printed chapter names its subject** — recorded so nobody "tidies" the prefix away later.
- **Pandoc has no page-number option.** It carries footers from the reference doc, so `build_docx.py`
  now assembles a real footer part: `word/footer99.xml` + relationship + content-type override +
  `<w:footerReference>` in `sectPr`. 🚨 **Order in `sectPr` is schema-enforced — footer refs BEFORE
  `pgSz`, or Word rejects the file.** Named `footer99.xml` to avoid clobbering pandoc's own footer parts.
- ⭐ **A `PAGE` field is safe where a TOC field is not:** `PAGE` resolves during **layout**, so it
  populates on open and print; a TOC needs a document-wide scan only Word does on demand (which is why
  this build has no TOC). `NUMPAGES` is weaker than `PAGE` — another reason the bare number won.
- ⚠️ **VERIFIED STRUCTURALLY, NOT VISUALLY** — no renderer on this box (no LibreOffice). **Andrew still
  needs to confirm the number appears in Word**, then upgrade the note in `CONVENTIONS.md`.

### 4. ✅ Both track 1 backlog items EXECUTED (reversing the earlier defer)

| | Outcome |
|---|---|
| **B2** | All 7 H1s → `# Kubernetes + Redpanda · Chapter N — …`, docx rebuilt |
| **B1** | **9 Lab-vs-PROD callouts across ch1–6.** Ch7 gets **none** and says so — it is the research-only chapter, so there is no lab practice to contrast |

⭐ **The retrofit was not what was expected, and this is the reusable lesson:** every chapter *already*
had a "Where this sandbox differs from production" table, so the shortcuts were all documented. **What
was missing was the fourth field — the consequence.** So the work was mostly **triage**: most rows are
differences of *scale or tooling* and correctly stay rows; only rows that would still be wrong on a
fifty-node cluster were promoted. Promoted: world-readable `system:masters` kubeconfig · `curl | sh` ·
false durability from local-path · a probe that tests nothing · no PDB on quorum workloads · **Redpanda
with no TLS/auth/ACLs on a NodePort** · unauthenticated Admin API + unowned topics · **auto-commit
choosing at-most-once** · **one mutable image tag making `rollout undo` a lie.**
**Deliberately NOT promoted:** single node, SQLite-vs-etcd, shared failure domain, 12 keys, pre-cached
images — ⚠️ **three of track 1's most-repeated caveats are one fact wearing three hats: there is one
piece of hardware.** `CONVENTIONS.md` now says: **write the fourth field first; if you cannot write a
real consequence, it is a table row.**

⚠️ **Pre-existing, NOT introduced by this work and NOT fixed:** `figcheck.py` reports 4 track-1 figures
under 10pt on the page (`ch02_fig1_ownership`, `ch03_fig1_partitions`, `ch05_fig1_assignment`,
`ch05_fig2_skew`). Left alone deliberately — no churn without a decision.

### ⏭️ Still open

- 🔲 **`s03-stack-deployed` snapshot NOT TAKEN** — the working stack is unprotected. On the PVE host:
  `for v in 191 192 193; do qm snapshot $v s03-stack-deployed --description "…"; done`
- 🔲 **Trap C2 is contaminated** — needs a restore to `s02-swarm-up` to run honestly.
- 🔲 **Part 4** — CI runner that calls `deploy_swarm.sh` unchanged.
- 🔲 Confirm the docx page numbers render in Word.

---

## ✅ PHASE 16 PART 3 COMPLETE — Capricorn running on the swarm (Aug 13, 2:20–4:12 PM EDT)

**State:** `backend` 2/2, `frontend` 3/3, `postgres` 1/1 (pinned to `docker-swarm-1`), `redis` 1/1.
UI at `http://192.168.1.191:5001`, API on `:5002` answering from **all three** nodes. Capricorn's own
repository was never modified. Chapters 1 and 2 are **written**; docx built; figures pass `figcheck`.

**Written this session:**

| File | What |
|---|---|
| `education/docker-swarm/manifests/capricorn.stack.yml` | The stack — modelled on the app's QA variant (plain HTTP, no proxy) because that is what this lab resembles |
| `education/docker-swarm/scripts/deploy_swarm.sh` | login → deploy → **wait for convergence** → print digests. Part 4 adds no deploy logic, only a runner that calls this |
| `education/docker-swarm/chapter01_building_the_cluster.md` | Quorum arithmetic, the token trap, idempotence, `Ready`/`Active`/`Reachable`, 5 Lab-vs-PROD callouts |
| `education/docker-swarm/chapter02_shipping_to_it.md` | Stack vs compose, secrets-as-files, **the registry-auth finding**, false-green convergence, digests vs tags, routing mesh |
| `education/docker-swarm/diagrams/*.dot` + `images/*.png` | 3 figures, all ≥10pt on page |

### 🚨 The finding of the session — and our first explanation was WRONG

Trap C1 (deploy without `--with-registry-auth`) fired as designed, but the obvious diagnosis —
*"the manager has credentials, the workers don't"* — is **false**. `docker stack ps` showed the frontend
**Rejected on all three nodes including the manager**, the node whose `~/.docker/config.json` holds a
working credential and where `docker pull` succeeds by hand.

⭐ **A node's daemon never reads the CLI's `config.json` when running a task.** Only the client does.
The agent authenticates *solely* with the credential frozen into the service spec by
`--with-registry-auth`. **A manager has no more pull privilege than a worker**, and being able to pull
by hand on a host proves nothing about whether a task can.

⭐ **Worse, our own debugging created the confusing symptom.** `postgres` and `backend` only *appeared*
to work on `.191` because our diagnostic `docker pull`s had already put those images in that node's
local cache — a task whose image is local never contacts the registry. The frontend was the one service
we had never pulled by hand, so it was the only one failing honestly, and therefore looked like the
odd one out. **This is now a standing methodological note in `METHOD.md`.**

Also visible: **exactly three `Rejected` rows per slot** = `restart_policy.max_attempts: 3` exhausted,
after which **Swarm stops retrying permanently.** That is why the false green was stable, not transient.

### 🚨 Two false-green mechanisms, both now handled in the script

1. `docker stack deploy` **exits 0 when the manager ACCEPTS desired state**, not when anything runs.
2. **Replica count is not convergence.** `order: start-first` holds `3/3` through a full rolling
   replacement, and — worse — `failure_action: rollback` restores the old version *at full replicas*,
   so a count-only check calls a **rejected deploy a success**. The script now treats
   `UpdateStatus.State` of `rollback_*` as a hard failure.

⚠️ **Two claims recorded as UNVERIFIED, to be falsified during C6 — do not teach as fact:** (a) the
embedded registry credential is a latch, so token expiry will break *future task reschedules* silently
rather than failing at deploy time; (b) `UpdateStatus` persists until the next update begins, which
would let a stale `rollback_completed` fail a healthy cluster.

### Other mechanisms worth remembering

- **Blast radius is selective.** Adding `--with-registry-auth` recreated the three services on the
  private registry and left `redis:7.2.4-alpine` (Docker Hub) **completely untouched** — postgres got
  bounced despite working, purely for sharing a registry. A third run with an unchanged file recreated
  **nothing**. A service is recreated when its *spec* changes, and "spec" includes things you never
  wrote in the file.
- **Digests, not tags.** Swarm resolves each tag to a digest at accept time and stores that, so
  services do not track a moving tag. Even the pinned `redis:7.2.4-alpine` recorded one. Sets up C7.
- **A frontend build dictated our network topology.** The bundle resolves the API base at runtime and,
  over HTTP, hardcodes `<hostname>:5002` — so the backend's published port was **not a free choice**.
  General lesson: `VITE_*` is substituted at **build** time; setting it in a stack file does nothing.
- **Secret-as-file vs config-as-string.** Wrapped the backend in `sh -c` to build `DATABASE_URL` from
  `/run/secrets/…`; `$$` because Compose interpolates `$`, and **`exec` so the app is PID 1 and gets
  `SIGTERM`** (without it every rolling update becomes a 10s stall then `SIGKILL`).

### ⚠️ Debt carried forward

- **Trap C2 is contaminated** — the diagnostic pulls pre-warmed postgres, so the backend never met a
  cold database. Needs a restore to `s02-swarm-up` to run honestly.
- New ledger rows **L11** (plain HTTP, no TLS — note it *arrived as a consequence of an image*, not a
  decision), **L12** (one long-lived token), **L13** (no healthchecks — deliberate, C6 needs it).
- `CONVENTIONS.md` gained Andrew's documentation filter: full specifics and caveats are the material,
  but **application** findings only earn a chapter place when they carry a transferable lesson, and
  then name the **lesson**, never the app's private details.

---

## ⭐ TWO ADDITIONS DECIDED MID-PHASE (Aug 13, ~2 PM) — build paused to talk them through

### 1. "Lab vs PROD" callouts — a new convention

**Andrew's framing:** we build on a single-host lab; an enterprise production environment would do
several of these things differently. **The risk is not forgetting a command — it is carrying a lab
shortcut into production having never been told it was one.** Also the sentence that reads as judgment
rather than recall at work: *"we did X, in production you'd do Y, because Z."*

⚠️ **This was already happening ad hoc** — track 1's "three brokers in one VM is not real HA", and
this phase's D2. Formalizing an existing instinct, which is the `METHOD.md` amendment pattern working
as designed.

**Split applied per our own rule:** `CONVENTIONS.md` gets the **form** (artefact), `METHOD.md`'s build
stage gets the **duty** (work), and the phase file carries a running **ledger** written *at the moment
the shortcut is taken* — the honest reason is freshest then, and reconstructing it later is how a real
compromise turns into invented best practice.

**Four fields, in order:** *In the lab* → *Why it's acceptable here* → *In production* → ***If you
carry the habit***. ⭐ **The fourth is the one that matters** — without it the callout is a disclaimer.
"Why it's acceptable here" must give the real reason, never "it's just a lab".

🚨 **Threshold, so they do not become wallpaper: a callout earns its place only when the lab choice
would be WRONG in production — security, durability, availability, compliance — NOT merely SMALLER.**
"Three nodes here, thirty in prod" is scale and does not qualify. If every page has one, the important
ones drown.

⚠️ **Verified vs recited must be marked.** When the AI says "in production you would…", that is
sometimes reported from something tested and sometimes recited from training data. **A plausible
recitation wearing the authority of a tested fact is the one way this convention actively misleads** —
same discipline as the CA-hash caveat earlier today.

✅ **No new machinery needed:** a blockquote with a bold lead label. Chapters already use blockquotes
heavily (25–80 each) and `build_docx.py` explicitly styles them as pull-outs, so they render in Word
today.

**Label: "Lab vs PROD"** (Andrew's pick). **8 rows already banked as L1–L8** in
`phases/phase16_docker_swarm.md` from Parts 1–2 alone: plaintext registry, `Autolock: false`, managers
also running workloads, three VMs on one host, patching masked, snapshots-not-backups, password SSH,
`:latest` tags. 📌 **Track 1 is NOT being retrofitted** — Andrew's call, it is finished and printed;
revisit as a separate deliberate task (backlog note in `education/README.md`).

### 2. Deployment: three wrappers, one script — not three alternatives

Andrew asked to compare manual scripts vs GitLab CI vs Jenkins. ✅ **His recollection is right and was
already recorded: the employer runs GitHub for source and Jenkins for CI** (confirmed Aug 12), while
the lab runs GitLab. **Jenkins is explicitly on the study list**, hence Phase 17.

⭐ **The reframe: these are not alternatives. They are three wrappers around the same
`deploy_swarm.sh`** — which is what the phase plan already assumed, so Andrew's instinct matched the
design. **Manual** (Part 3) proves a *working* deploy exists before CI touches it, so a Part 4 failure
is unambiguously a wiring problem; its production disqualifier is **not ergonomics but access
control** — it requires humans to hold SSH into production managers. **GitLab CI** (Part 4) buys audit
trail, approval gate, masked secrets and no human SSH, on a runner that already exists. **Jenkins**
(Phase 17) matches the employer but is heavier, and Groovy is expressive enough that teams put deploy
logic *inside* the Jenkinsfile — the exact anti-pattern this design avoids.

**The boundary:** script owns registry login, `docker stack deploy`, convergence polling, rollback.
Wrapper owns triggers, authorization, secret source, **host targeting**, notifications. ⚠️ Host
targeting living in the wrapper **is where trap C4 lives**.

⭐ **Falsifiable claim recorded for Phase 17 to test: if Jenkins forces a change to a single line of
`deploy_swarm.sh`, the boundary was drawn wrong.** A real test of the abstraction, not an assertion.

**Two things not in Andrew's list:** (a) **pull-based GitOps** — cluster-side reconciliation so no CI
system holds prod credentials — exists in Kubernetes (Argo CD, Flux) and **has no real Swarm
equivalent**; ⭐ strong Part 7 comparison material because it is architectural, not a feature
checklist. (b) **Phase 17 must choose GitLab or GitHub as source** — GitHub matches the employer and
`push_github.sh` already publishes there, but it is **public**, so webhooks inbound to the home lab
need exposure or polling. Deferred to Phase 17, recorded so it is not rediscovered.

**Bearing on A2:** the GitLab CI file still earns its place — it proves the wrapper boundary once,
cheaply, on existing infrastructure — **but it needs the `workflow: rules:` guard** or every backup
push fires a pipeline.

---

## ✅ PHASE 16 PART 2 COMPLETE — three-manager swarm (Aug 13, 1:33–1:53 PM EDT)

🙋 **The first hands-on part.** Andrew ran `swarm init` on `.191` and joined `.192` himself; the AI
joined `.193` under the repetition rule and took the snapshots. Twenty minutes, nothing failed.

**End state:** 3 managers / 3 nodes — `.191` **Leader**, `.192`/`.193` **Reachable** —
`ClusterID n6waq5uhc7o6yxzt5tyzrbol9`, **quorum 2 of 3**, ingress overlay `10.0.0.0/24`, no services
deployed. Snapshot **`s02-swarm-up`** on all three, hot and together, with a description recording
the state and the CA expiry date.

**The find of the session was the join token.** Format `SWMTKN-1-<head>-<tail>`. Andrew spotted that
the head is shared between the worker and manager tokens and the tail differs, and guessed swarm ID +
joiner ID. **The tail is per-ROLE, not per-node** — proved by rotating the worker token and watching
the manager token sit unchanged. ⚠️ **Operational consequence: there is no per-node revocation**; a
leak can only be answered by rotating an entire role. **The head is NOT the swarm ID** — `ClusterID`
turned out to be `n6waq5uh…`, which appears nowhere in the token, and the length is wrong besides
(IDs are 25 base36 chars, the head is 50). It is the root CA hash, and the two halves are mutual
authentication pointing opposite ways: **the head proves the cluster to the joiner, the tail proves
the joiner to the cluster.** ⚠️ Honest caveat: the rotation test did *not* prove the CA-hash claim —
both hypotheses predicted "unchanged". `docker swarm ca --rotate` is the test that separates them, and
it is now **added to the chapter 5 drill list**, deliberately deferred from the 1-node stage where it
would have been trivial.

🚨 **Three things that will cost time later, all recorded in the phase file:**
- **`swarm init` prints the WORKER token** and only mentions the manager one in prose. Pasting what it
  gives you produces a perfectly healthy-looking **1-manager / 2-worker** cluster and silently deletes
  every quorum lesson in the phase. A wrong token is not an error, it is a subtly wrong cluster.
- **`Autolock Managers: false`** — the Raft encryption key is on disk in the clear on every manager.
  Part 3 puts Capricorn's DB password into `docker secret`, so **the VM snapshots will then contain
  recoverable secrets.**
- **CA certs expire 3 months out.** Restoring a snapshot older than that yields a cluster whose certs
  expired while frozen — it presents as a networking fault and is not one.

**Also worth keeping:** two managers is *strictly worse* than one (quorum `floor(N/2)+1` means N=2
tolerates zero failures) — the state people reach by "adding a second manager for redundancy".
`STATUS` and `MANAGER STATUS` answer different questions, engine vs Raft. `docker node ls` fails on a
worker, making it a free role check after a join. `Default Address Pool` is **not printed** by
`docker info` unless set, but is real — `ingress` came up `10.0.0.0/24` out of the invisible
`10.0.0.0/8`, a live collision risk on corporate `10.x` networks.

⚠️ **Process fix, applied immediately:** the AI handed over a block with `ssh` on line 1 and commands
beneath it. The later lines land in the terminal input buffer while `ssh` starts, and a password
prompt ate the join-token line. Harmless here, but **from now on: `ssh` alone and wait, or
`ssh host "command"` explicitly.**

**Next: Part 3 — stack file, `docker secret`, first deploy. Trap C1 fires here. Andrew driving.**

---

