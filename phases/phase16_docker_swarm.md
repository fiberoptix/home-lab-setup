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
| A3 | postgres storage: pin to a node, or NAS volume? | Andrew, **while doing Part 5** | 🔒 **DEFERRED BY DESIGN** — do not pre-decide |
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
| C3 | Force postgres onto a different node and watch it come up **healthy with an empty database**. | Silent data loss that looks like a clean deploy. The most valuable thing in this phase. |
| C4 | Point the deploy job at one manager by IP, then kill that manager while the cluster stays healthy. | HA control plane ≠ HA delivery path. The best CI lesson here. |
| C5 | Take quorum down to 1 of 3 and try to change something. | Containers keep serving; the control plane refuses all changes. Degraded ≠ down, and the reflex to "just bounce it" turns a serving cluster into a real outage. |
| C6 | Roll out a deliberately broken image tag. | Whether `update_config` / `rollback_config` actually saves you, and why a real healthcheck is not optional. |
| C7 | Push a **new image under the same `:latest` tag**, redeploy, and see whether anything actually changes. | Swarm resolves a tag to a **digest** and stores that, so services do not track a moving tag the way a `docker compose pull` does. Teaches `--resolve-image`, and why "I pushed a fix and prod is still running the old code" is a Swarm classic. |

### 🅓 Findings inherited from elsewhere — recorded, not fixed here

| # | Finding | Disposition |
|---|---|---|
| D1 | `/opt/capricorn/docker-compose.yml` on `.184` declares `postgres:15.5-alpine`, but the **running container is the custom `production/capricorn/postgres:latest`**. The file does not describe what is deployed, so "just redeploy from the compose file" would quietly change PROD's database image. | ⚠️ **Application layer — out of this repo's ownership.** Recorded because our stack file must reference the image that really runs, and because it is a perfect example of config drift. Raise with whoever owns Capricorn. |
| D2 | Three VMs on one physical host simulates **node** failure, not **host** failure. | Honest caveat to state in the chapter, same as Phase 14's three-brokers-in-one-VM note. Every drill is a real Raft event; losing the Z6 still loses all three. |
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

#### Added to the drill list

| # | Drill | Why here |
|---|---|---|
| **New** | `docker swarm ca --rotate` on the live three-manager cluster. | Settles the token-head question by evidence — if it is a CA hash, **both** tokens' heads must change. Doubles as a real certificate-rotation exercise across three managers, which is the SRE-relevant version. Deliberately **not** run at 1 node, where it was trivial and taught nothing. |

**Next: Part 3 — the stack file, `docker secret`, and the first deploy. Trap C1
(`--with-registry-auth` omitted on purpose) fires here. Andrew driving.**
