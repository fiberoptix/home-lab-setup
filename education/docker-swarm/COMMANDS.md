# Swarm command ledger

Every command this track actually used, **organised by the question it answers rather than by the
chapter it appeared in.** Chapters teach in the order things were learned; an incident does not
cooperate with that order.

⭐ **This file is the specification for a future `docker-admin.sh`** (Andrew's idea, Aug 13, 2026) — a
portable read-only investigation tool. It is written *as the track runs*, not reconstructed at the end,
because by the time the drills finished there were a hundred commands and, without this file, there
would have been no memory of which ones mattered. See
[§11](#11-toward-docker-adminsh) for the design rules that fall out of it.

**Verified?** column:
- ✅ **ran it here** — executed in this lab, output understood
- ⚠️ **standard, not run here** — believed correct, **not** exercised. Do not present as tested.
- 🔲 **planned** — a drill or check that is designed but has not been run yet.

---

## 0. How to run a block of these — the paste-runner

⭐ **Andrew's practice, Aug 18, 2026.** Do not paste a multi-line block into an interactive shell. Paste
it into a file and run the file:

```bash
# on the target node — write once, run once
vi ~/DevShare/cursor-projects/home-lab-setup/education/docker-swarm/scripts/run_commands.sh
chmod +x run_commands.sh && ./run_commands.sh
```

**Why this is not a style preference.** Both mispaste incidents on this track had the same shape: a
block beginning with `ssh` was pasted, and the *remaining lines* sat in the terminal's input buffer
while `ssh` was still connecting — so they were consumed by the wrong shell. On this lab that was
almost invisible, because `~/DevShare` is mounted at the same path on the workstation and on the
nodes, so `cd` succeeded on the wrong machine. **A file is read by one process from beginning to end.
There is no buffer for another process to steal.** It also gives you the block verbatim to re-run
after a change, which is what makes a drill a measurement instead of an anecdote.

Two rules that come with it:

| Rule | Why |
|---|---|
| **Never type a secret into the file.** Keep using `read -rsp 'pg password: ' PGPW`. | The file persists on disk, and here that disk is a **CIFS share** — a password in it is now on the NAS, in the project directory, next to a git repo. `read -rsp` keeps it in one process's memory and out of shell history. |
| **Give it `#!/usr/bin/env bash` and `set -euo pipefail`.** | Without them the runner keeps going after a failed step, and you score a drill against output produced in a state you did not intend. The Aug 18 runner lacked both; it happened not to matter because nothing failed. |

`education/*/scripts/run_commands.sh` is **git-ignored**: its contents change every time, and the
artefact is this ledger, not the scratch pad.

---

## 1. The 3am order — is the CLUSTER healthy, or the APP?

Ask in this sequence. Each step narrows the blast radius, and **step 1 before step 2 matters**: a
control-plane problem and an application problem look identical from the outside.

| # | Command | Question | Verified? |
|---|---|---|---|
| 1 | `docker node ls` | Are all nodes `Ready`, and are managers `Reachable`? **The `MANAGER STATUS` column is your quorum signal**, not `STATUS`. Fails outright on a worker, which is a free role check. | ✅ |
| 2 | `docker stack ls` | Which stacks exist, and how many services does each claim? | ✅ |
| 3 | `docker stack services <stack>` | Replica counts. `0/3` or `2/3` tells you *where* to look next — but see §4, **counts lie during updates.** | ✅ |
| 4 | `docker stack ps <stack>` | **Task history, including failed attempts.** This is the first command that shows you an *error*. | ✅ |
| 5 | `docker stack ps <stack> --no-trunc` | The rest of the error message. **The useful half is usually past the truncation point.** | ✅ |

> 🚨 **Quorum loss does not stop the application.** Containers keep serving because workers need no
> consensus to keep doing what they were last told. What you lose is the ability to *change* anything.
> So a healthy-looking website proves nothing about the control plane, and vice versa.

---

## 2. Why isn't my service running?

| Command | Question | Verified? |
|---|---|---|
| `docker service ps <svc>` | ⭐ **The single most useful command in Swarm.** Per-task state *with history* — `Rejected`, `Failed`, `Shutdown` rows included, plus which node each attempt landed on. **This is the command that disproved our registry-auth theory** by showing the manager rejecting a pull. | ✅ |
| `docker service ps <svc> --no-trunc` | The full error string. | ✅ |
| `docker service ps <svc> --filter desired-state=running` | Hide the historical noise once you know the shape. | ✅ |
| `docker service logs <svc> --tail 50` | The application's own account. Aggregated across replicas; `--follow` works. | ✅ |
| `docker service logs <svc> --since 10m` | Scope to the incident window. | ⚠️ |
| `docker service inspect <svc> --pretty` | Human-readable spec — the settings actually in force, not what your file says. | ✅ |
| `docker events --filter type=service` | Live stream of state changes. Useful *while* reproducing. | ⚠️ |
| `docker service logs <svc> --timestamps` | ⭐ **The command that answered C2**, and `--tail`/`--since` cannot replace it. Ordering *between* services is the whole question in a dependency problem, and you cannot get it without absolute times. It showed postgres ready at `22:27:27.162` and the backend starting at `22:27:33.75` — **proving the backend never met a cold database**, so the trap never fired. | ✅ |
| `docker service logs <svc> --timestamps \| grep -iE "ready to accept\|initdb"` | Pull a **readiness timestamp** out of a noisy startup log, so it can be compared against the dependent service's first log line. | ✅ |
| `docker service ps <svc> --no-trunc` (as a **negative** test) | ⭐ **Absence of evidence is evidence here.** A clean history — no `Failed`, no `Shutdown` — proves the task never crash-looped and **`max_attempts` was never touched**. Convergence alone cannot distinguish "started cleanly" from "crashed twice and recovered inside its retry budget"; this can. | ✅ |

**How to read the failure modes:**

| What you see | What it usually means |
|---|---|
| `Rejected` + `access forbidden` / `No such image` | The **node** could not pull. See §6 — and note the node's daemon does **not** use your CLI's credential |
| `Rejected`, exactly N times, then silence | `restart_policy.max_attempts: N` exhausted. **Swarm has stopped trying permanently** — nothing will retry it |
| `Preparing` for a long time | Pulling a large image, or the registry is unreachable |
| `Running`, then `Shutdown`, repeatedly | The app is crashing. Go to `service logs` |
| `Pending` forever | Nothing satisfies placement — constraints, resource reservations, no `Active` node |
| Task count fine, app broken | 🚨 **No healthcheck.** The process is up and serving garbage; Swarm cannot tell. (The frontend now carries one — added and re-drilled Aug 18 evening, see §4b — the backend deliberately does not; the smoke gate covers it) |
| `Name or service not known` from the app | 🚨 **A dependency service is at 0 replicas or was never deployed.** A scaled-to-zero service leaves Swarm's DNS entirely, so a missing dependency presents as **name resolution**, not `connection refused`. ⚠️ **Grepping for `connection refused` finds nothing** and sends you to the overlay network instead of to the missing service |
| `Waiting for database (attempt N/15)` then `Bootstrap failed` then `Application startup complete` | 🚨 **The app retried, gave up, and started anyway.** Measured Aug 18. Nothing exits, so `restart_policy` never fires, `max_attempts` is never consumed, the deploy converges green, and every request that touches the DB 500s. **One missing `sys.exit(1)`** |

---

## 3. Where is it running, and what is on this node?

| Command | Question | Verified? |
|---|---|---|
| `docker node ps <node>` | What tasks is **this node** carrying? The complement of `service ps` — essential before draining anything. | ⚠️ |
| `docker node ps self` | Same for the node you are on. | ⚠️ |
| `docker node inspect <node> --pretty` | Labels, availability, resources, engine version. | ✅ |
| `docker ps` | Containers **on this host only.** ⚠️ A Swarm service is invisible here unless a task happens to be local — the classic "my service is running but `docker ps` is empty" confusion. | ✅ |
| `docker volume ls` | 🚨 **Volumes are NODE-LOCAL, and Swarm will not tell you otherwise.** Run this on the wrong node and the database volume simply is not there. | ✅ |

### 🚨 Wiping a Swarm-managed volume — the safe form

Measured Aug 18, 2026: a "controlled" drill was **voided** because a `docker volume rm` failed silently
and the deploy ran against the previous run's data. The rules that came out of it:

| Command | Question | Verified? |
|---|---|---|
| `docker service ps <svc> --format '{{.Node}}'` | ⭐ **Which node holds the volume?** `docker volume rm` on any other node returns `no such volume`, which is indistinguishable from success if you discard the error. | ✅ |
| `docker ps -a --filter name=<svc> --format '{{.Names}}\t{{.Status}}'` | **Is the container really gone?** `docker stack rm` returns before the container objects are reaped, and the volume stays busy until they are. Waiting for the *network* to disappear is not sufficient — measured. | ✅ |
| `docker volume rm <vol>` **without `2>/dev/null`** | `no such volume` and `volume is in use` require opposite responses. Hiding stderr makes them the same message. | ✅ |
| `docker volume ls -q \| grep -qx <vol> && exit 1` | ⭐ **Assert the precondition, then refuse to continue.** | ✅ |

```bash
# retry, report docker's own error, and abort rather than run the wrong experiment
for i in $(seq 1 30); do
  out="$(docker volume rm capricorn_postgres_data_swarm 2>&1)" && { echo "  removed"; break; }
  printf '  attempt %s: %s\n' "$i" "$out"; sleep 2
done
docker volume ls -q | grep -qx capricorn_postgres_data_swarm \
  && { echo "ABORT: volume survived - the run would use stale data"; exit 1; }
```

⭐ **The general rule, and it is not about Docker:** **never suppress stderr on a step the result depends
on.** A precondition that fails quietly does not give you a failed run, it gives you a *successful-looking*
run that answers a different question — the same false-green shape as [§4b](#4b-is-it-ready-for-business-as-distinct-from-running),
but built into the instrumentation instead of the app.

### 🚨 The dataset is empty but nothing failed — is the state LOST, or STRANDED on another node?

Measured Aug 18, 2026 (drill C3). Redis was moved to a node that had never held its volume: Swarm said
`converged`, `1/1`, `UpdateStatus: completed` — and `DBSIZE` was `0`. **The data was intact the whole
time, on the node it came from.** This sequence separates the two in about a minute.

| Command | Question | Verified? |
|---|---|---|
| `docker service ps <svc> --filter desired-state=running --format '{{.Node}}'` | ⭐ **Which node am I talking to, and is it the one I was talking to yesterday?** The first question, before anything about the data. | ✅ |
| `docker volume inspect <vol> --format '{{.CreatedAt}}'` | 🎯 **The single most diagnostic field.** A creation time of *seconds ago* means the daemon **created a new empty volume with the same name** because the task landed on a node that lacked it. | ✅ |
| `docker volume ls --filter name=<stem>` — **on every node in turn** | Which nodes hold this name? There is no cluster-wide view; two nodes holding the same name with different contents is normal and invisible. | ✅ |
| `sudo ls -la /var/lib/docker/volumes/<vol>/_data/` | **Is the old data still there?** Run it on the *previous* node. File timestamps show when the departing container last flushed. | ✅ |
| `docker service inspect <svc> --format '{{.Spec.TaskTemplate.Placement.Constraints}}'` | ⭐ **Is anything pinning this service to its data?** `[]` on a stateful service means only scheduling luck has kept them together. | ✅ |

```bash
# Recover a stranded volume by sending the service back to its data, then decide on a permanent pin
docker service update --constraint-add 'node.hostname==<node-with-the-data>' --detach=false <svc>
```

⭐ **Two things this teaches that generalise past Docker.** First, **durability and availability are
independent** — Redis had `--appendonly yes` and fsynced on `SIGTERM`, so the data was *never more
durable* than at the moment it became unreachable. Second, **the incident presents as data loss and is
really an addressing problem**, so the dangerous instinct is the diligent one: restoring a backup over
the top of a healthy-but-stranded volume turns a recoverable event into a real one.

---

## 4. What is ACTUALLY deployed? (drift, versions, convergence)

The gap between "what the file says" and "what is running" is where outages live.

| Command | Question | Verified? |
|---|---|---|
| `docker service inspect <svc> --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}'` | ⭐ **The resolved DIGEST, not the tag you asked for.** Swarm pins a tag to a digest at accept time, so this is the only honest answer to "what version is live". | ✅ |
| `docker service inspect <svc> --format '{{if .UpdateStatus}}{{.UpdateStatus.State}}{{else}}<absent>{{end}}'` | 🚨 **The real convergence signal.** `updating` / `completed` / `rollback_started` / `rollback_completed` — and **ABSENT** (not empty) if never updated: the unguarded template errors. See the callout below. | ✅ |
| `docker service inspect <svc> --format '{{.UpdateStatus.Message}}'` | Why the rollout ended the way it did — C6a's read `update rolled back due to failure or early termination of task …`. | ✅ |
| `docker service ls` | Current replica counts only — **no history, no update state.** | ✅ |
| `docker service ps <svc> --format '{{.Name}}\t{{.Node}}\t{{.CurrentState}}\t{{.DesiredState}}\t{{.Error}}'` | 🚨 **`Complete` is not a synonym for `Running`, and it is not an error.** A task whose container exited **0** is recorded `Complete`/`Shutdown` — a success. **Under `restart_policy: on-failure` it is never replaced.** See the reboot finding below. | ✅ |
| `docker service inspect <svc> --format '{{.Spec.TaskTemplate.RestartPolicy.Condition}}'` | ⭐ **Read the policy from the SPEC, not the stack file.** The file is what you asked for; the spec is what Swarm is enforcing. | ✅ |

### 🚨 After ANY reboot or maintenance: did every service come back to full strength?

**Measured Aug 18, 2026.** Three VMs were gracefully shut down and restarted. Raft re-formed, all nodes
`Ready`, no failed tasks, no rollback, every health endpoint 200 — and the stack sat at `backend 1/2`,
`frontend 1/3`, `redis 0/1` indefinitely.

| Container's fate on shutdown | Task state | Replaced under `on-failure`? |
|---|---|---|
| **Exited 0** (SIGTERM from a clean stop) | **`Complete`** | ❌ **never** — exit 0 is success |
| **Vanished** | `Failed` — `No such container: …` | ✅ yes |

```bash
# the post-maintenance gate - run it as a check, not a glance
docker stack services <stack> --format '{{.Name}} {{.Replicas}}' \
  | awk '{split($2,a,"/"); if (a[1]!=a[2]) { print "  UNDER-REPLICATED: " $0; bad=1 }} END{exit bad}' \
  && echo "  all services at desired replicas"
# && not || — an earlier revision of this very file had || here, which printed the
# success line ON FAILURE, right under the UNDER-REPLICATED evidence. A gate whose
# green message fires on the red path is this ledger's own false-green lesson applied to itself.
```

> 🚨 **`restart_policy: condition: on-failure` is wrong for every long-running service**, and it reads
> like the cautious choice. `any` is Docker's default. **In production this is a rolling-patch bug:**
> reboot nodes one at a time for kernel updates and each service that exits cleanly comes back short,
> with no alert, until the lost capacity matters. `max_attempts` without a `window` is the same bug by
> another route — after N restarts ever, the task stays dead.
>
> ⭐ **And note the inversion against [§4](#4-what-is-actually-deployed-drift-versions-convergence):**
> there, replica count is *insufficient* because `start-first` and rollback hold it at full. Here it is
> the **only** signal that catches the fault. **Neither works alone; they fail in opposite directions.**

⚠️ **`UpdateStatus` is ABSENT, not empty**, on a service never updated since creation —
`--format '{{.UpdateStatus.State}}'` fails with `map has no entry for key "UpdateStatus"`. Guard with
`{{if .UpdateStatus}}` or tolerate the error. ⭐ **This is the case where suppressing stderr is correct**,
and the contrast with the voided volume wipe is the real rule: **suppress silence you then handle; never
suppress a precondition.**

> 🚨 **Two ways a deploy reports green while broken.** First, `docker stack deploy` exits `0` when the
> manager *accepts* desired state, not when anything runs. Second, **replica count is not convergence**:
> `order: start-first` holds `3/3` right through a rolling replacement, and `failure_action: rollback`
> restores the *old* version at *full* replicas — so a count-only check calls a **rejected deploy a
> success**. Always pair counts with `UpdateStatus`.
>
> ⭐ **Measured while polling:** counts can also read **`4/3`** — more running than desired — for the
> moment `start-first` has both the old and new task up. A poller must treat *any* `current != desired`
> as **pending**, not failed; `deploy_swarm.sh` does.

⚠️ **Still open after the drills:** `UpdateStatus` persists until the next update begins, so a stale
`rollback_completed` could make a checker fail a healthy cluster. C6a proved the *detection* side
(`rollback_started` caught in 1.3 s); the stale-latch side was not isolated. `deploy_swarm.sh` mitigates
by recording the pre-deploy state and comparing, rather than trusting the field absolutely.

### 🚨 Observed, unplanned: `:latest` moved underneath a redeploy (Aug 18, 2026)

A drill redeploy was expected to change *one* thing — the worker count. Printing the resolved digests
showed **all three first-party images had different digests than the Aug 13 run**:

| Service | Aug 13 digest | Aug 18 digest |
|---|---|---|
| `backend` | `fac031dd…` | `b449d6c4…` |
| `frontend` | `ef8cdf13…` | `5507b283…` |
| `postgres` | `18b8bf23…` | `5f76f30b…` |

Nobody asked for that. The stack file says `:latest`, an unrelated CI pipeline pushed new images in
between, and **`docker stack deploy` therefore performed an unannounced application upgrade** — three of
them — while nominally running a controlled experiment.

Two separate lessons, and the second is the one that stings:

1. **Mutable tags mean every redeploy is an upgrade you did not authorise.** A `docker service update
   --force` intended to restart a stuck service will silently ship whatever `:latest` now points at.
   This is why the digest print exists in `deploy_swarm.sh`, and it is the argument for deploying by
   digest — the finding arrived on its own, before the chapter that was going to teach it.
2. ⭐ **It confounded the experiment.** Two variables changed between the Aug 13 observation and the
   Aug 18 result, so the drill's null result cannot yet be attributed to the worker count. **Print the
   digests before scoring any drill**, and if they moved, the comparison is not a comparison.

```bash
# the one-liner that caught it — run it before AND after any drill
for s in backend frontend postgres redis; do
  printf '%-10s %s\n' "$s" \
    "$(docker service inspect capricorn_$s --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}')"
done
```

---

## 4b. Is it READY FOR BUSINESS? (as distinct from "running")

⭐ **Andrew's rule, Aug 18, 2026:** *containers running and ready does not mean the application is ready.*
**Measured, with postgres scaled to 0 and the backend left running: six of seven available checks
passed.** `docker service ps`, `docker stack services`, `restart_policy`, the convergence poll, `/health`
and `/api/v1/banking/health` all said healthy. Only a request that touched the database disagreed.

| Command | Question | Verified? |
|---|---|---|
| `curl -s -o /dev/null -w '%{http_code}' http://<node>:<port><dependency-path>` | ⭐ **The only check in this file that can detect a converged-but-broken deploy.** Must hit a path that **exercises a dependency** — see the warning below. | ✅ |
| `docker exec $(docker ps -q -f name=<svc>\|head -1) python -c "from app.main import app; [print(p) for p in sorted(app.openapi()['paths'])]"` | **How to find a dependency-exercising path when `/openapi.json` is disabled** (`DEBUG=false` hides the docs). Ask the app for its own route table. | ✅ |
| `curl … /api/v1/data/summary` and check `total` > 0 | 🚨 **A status code alone passes an EMPTY database.** The subtler outage: a one-shot startup bootstrap runs before the DB is reachable, never re-runs, the pool then reconnects lazily, and **every endpoint returns 200 with zero rows.** A 500 gets noticed; green dashboards over an empty database do not. | ✅ |

### 🚨 Is the data COMPLETE, or did a fallback path run?

Measured Aug 18, 2026: with 4 uvicorn workers against a freshly initialised database, **3 of the 4 lost a
race to seed it** and the application *caught* the error and substituted a smaller dataset — while
reporting success.

| Command | Question | Verified? |
|---|---|---|
| `docker service logs <svc> 2>&1 \| grep -i "using minimal bootstrap"` | ⭐ **Did a degraded fallback path run?** The row count was correct *and* this fired. A count-based check cannot see it. | ✅ |
| `docker service logs <svc> 2>&1 \| grep -i UniqueViolation \| sed -E 's/^(<svc>\.[0-9]+)\..*/\1/' \| sort \| uniq -c` | ⭐ **How many writers lost, and on which task?** `3 backend.2` and zero on `.1` localises the race to *one task's own workers*, which is a different bug from task-vs-task. | ✅ |
| `docker service logs <svc> 2>&1 \| grep -c "Waiting for application startup"` | **How many worker processes actually started?** `workers × replicas`. Confirms a config change landed before you attribute a result to it. | ✅ |

⭐ **Grep for the fallback, not just the error.** A caught exception followed by a degraded path is
invisible to exit codes, status codes and row counts alike — the three things automation usually checks.

### Reading the application's own source out of the running image

When behaviour is ambiguous, **the image is the ground truth** — source on a workstation may not be what
was built. Measured Aug 18, 2026: this settled a mechanism that two rounds of black-box drilling could
not.

| Command | Question | Verified? |
|---|---|---|
| `docker exec <c> sh -c 'grep -rl "<log string>" /app'` | ⭐ **Start from a log line and find the code that wrote it.** The fastest route from a symptom to its cause. | ✅ |
| `docker exec <c> sh -c 'grep -n "def .*<name>" <file>'` | Locate the function without reading the file. | ✅ |
| `docker exec <c> sh -c 'sed -n "535,575p" <file>'` | Print a specific range once `grep -n` has given you the line numbers. | ✅ |
| `docker exec <c> sh -c 'awk "/<marker>/{f=NR} f&&NR>=f-25&&NR<=f+45" <file>'` | **Print a window around a match** when you do not know the line number yet. | ✅ |
| `docker exec <c> sh -c 'grep -rn "DELETE FROM\|delete(\|ON CONFLICT\|commit\|rollback" <file>'` | ⭐ **Transaction boundaries are where data-loss bugs live.** Finding a `commit()` between a delete and its replacement insert is the whole game. | ✅ |

⚠️ **This works because the container ships its source.** A compiled or minified image gives you nothing,
which is an argument for keeping the source layer in the image for debuggability — and an argument against
it for anyone worried about what a `docker exec` reveals. ⭐ **Note what this means for access control:
anyone in the `docker` group can read the application's source *and* its secrets on any node.**

### 🚨 A row-count gate is only as good as WHICH rows it counts

| Command | Question | Verified? |
|---|---|---|
| `docker exec -i $(docker ps -q -f name=<pg>\|head -1) psql -U <u> -d <db> -c "SELECT table_name, (xpath('/row/c/text()', query_to_xml(format('select count(*) as c from public.%I', table_name), false, true, '')))[1]::text::bigint AS rows FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE' ORDER BY rows DESC;"` | ⭐ **Exact counts for every table in one query**, without naming them. `pg_stat_user_tables.n_live_tup` is an *estimate* and needs `ANALYZE` — do not gate on it. | ✅ |
| `docker exec <pg> ls -la /docker-entrypoint-initdb.d/` | **What does the database contain before any application touches it?** | ✅ |
| `docker exec <pg> sh -c 'grep -ic "insert into" /docker-entrypoint-initdb.d/*.sql'` | ⭐ **Which init scripts seed DATA, not just structure** — the per-file counts separate schema from reference data. | ✅ |

**Measured Aug 18, 2026:** the database holds **1621** rows, of which **939 are tax reference data seeded
by `initdb`** and **682 are written by the application's bootstrap.** The endpoint the smoke gate reads
reports **682** — it counts only application-owned tables.

> 🚨 **Had that endpoint summed all 21 tables, it would report 1621 on a healthy database and 939 on one
> where the bootstrap never ran** — and a floor of 100 would pass a completely unseeded application.
> The gate works because the metric happens to exclude reference data, **which was luck, not design.**
>
> ⭐ **The rule: gate on rows the application itself is responsible for creating.** Reference data
> shipped with the schema is always present, so including it in the metric drowns the signal — the
> larger the reference dataset, the more thoroughly it hides an empty application.

🚨 **Not every endpoint named "health" is a health check.** On this app:

| Endpoint | With the database SCALED TO ZERO |
|---|---|
| `/health` | **200** `{"status":"healthy"}` — a static string, touches nothing |
| `/api/v1/banking/health` | **200** — reports *sub-module* readiness, still never touches the DB |
| `/api/v1/banking/categories` | **500** ✅ the honest one |

⭐ **A `healthcheck:` block pointed at `/health` would pass forever with the database on fire**, and would
look like diligent engineering in the stack file. **Point readiness probes at something that fails when a
dependency fails**, or do not bother writing one.

✅ **Now enforced in `deploy_swarm.sh`** as a post-convergence smoke gate (status + body match, then a
row-count floor), so CI inherits the check instead of reimplementing it. `SMOKE=0` disables it and says
loudly what you gave up.

✅ **Extended Aug 18 evening, after C6b proved a gate only defends the port it calls:** a third gate
asserts every published port — `:5001` must return 200 **and** a body only our bundle serves
(`grep -qiF capricorn`; a stock nginx also answers 200, measured). Same evening the frontend gained a
manifest `healthcheck` with the same discriminator, and **re-running C6b flipped it from silent success
to a 47-second loud rollback with zero user-visible damage** (P32–P34 in the phase record). A gate that
cannot read its instrument now **fails instead of skipping** — a skipped check reported as green was
this file's own false-green pattern.

🚨 **The row floor has to be chosen, not defaulted — and the first version got this wrong.**
`SMOKE_MIN_ROWS` shipped as `1`. But `001_schema.sql` seeds **12 categories by itself**, so a floor of 1
— or of 12 — **passes on a database whose application bootstrap never ran**, which is the exact
false-green the gate was written to catch. Measured Aug 18: a fully bootstrapped database reports
`total=682`; schema-only is ~12. The default is now **100**, and the rule generalises:

> **Pick a number the schema alone cannot reach.** A floor below the schema's own seed data is not a
> weak check, it is a check that cannot fail.

⚠️ **`|| echo 000` after a `curl -w '%{http_code}'` is a trap.** On a refused connection curl writes
`000` *and* exits non-zero, so the fallback fired too and the gate logged **`HTTP 000000`**. Harmless to
the logic, expensive to whoever greps that string out of a CI log at 3am. Use `|| true`, and capture the
body and the status in **one** request — two requests can straddle the moment the app becomes ready and
report a 200 alongside a body from before it was.

---

## 5. Networking and reachability

| Command | Question | Verified? |
|---|---|---|
| `docker network ls` | Which overlays exist; `ingress` plus one per stack network. | ✅ |
| `docker network inspect ingress` | ⭐ **The subnet Swarm chose for you.** Ours took `10.0.0.0/24` out of a default `10.0.0.0/8` — **a silent collision risk on any corporate `10.x` network**, and `docker info` does not show it. | ✅ |
| `docker network inspect <stack>_<net>` | Which tasks are attached, and their overlay IPs. | ⚠️ |
| `curl -s http://<any-node>:<published-port>/` | Proves the **routing mesh**: every node answers on a published port whether or not it runs a task. ⚠️ **So a success proves the CLUSTER is serving, not that this node is healthy.** | ✅ |
| `docker exec <container> nslookup <service>` | Service discovery by name inside an overlay. | ⚠️ |

---

## 6. Secrets and registry auth

| Command | Question | Verified? |
|---|---|---|
| `docker secret ls` | Which secrets exist. | ✅ |
| `docker secret inspect <name>` | Metadata only — **the value is never returned.** Used in `deploy_swarm.sh` as a pre-flight. | ✅ |
| `printf '<value>' \| docker secret create <name> -` | Create one. **`printf`, never `echo`** — `echo` appends a newline that becomes part of the secret, producing auth failures that are invisible everywhere you would look. | ✅ |
| `docker exec $(docker ps -q -f name=<svc>) cat /run/secrets/<name>` | Confirm delivery *inside* a task — secrets arrive as **files** on an in-memory mount. ⭐ **Also the only way to audit a secret's VALUE**, and it caught our written-down `pg_password` being wrong. 🚨 **Which is the security lesson:** the API refuses to return a secret, the node hands it over freely, so **`docker` group membership on a node = read access to every secret scheduled there**, with nothing in any audit trail. | ✅ |
| `docker login <registry> -u <user>` | Interactive, masked prompt. ⚠️ **Do not add `--password-stdin` interactively** — it silently waits on stdin instead of prompting, and looks like a hang. | ✅ |
| `printf '%s' "$TOKEN" \| docker login <registry> -u <user> --password-stdin` | The **scripted** form. Never `-p`, which leaks the token into the process list and shell history. | ✅ |
| `jq -r '.auths\|to_entries[0].value.auth' ~/.docker/config.json \| base64 -d` | 🚨 **Recovers the registry credential in plaintext.** Proves the stored blob is base64 — *an encoding, not encryption*. Docker warns about this on login and the warning is correct. | ✅ |

> 🚨 **The auth finding worth carrying to any job:** `--with-registry-auth` embeds the credential **into
> the service spec in the Raft log**. A node's daemon *never* reads your CLI's `config.json`. Therefore
> **a manager has no more pull privilege than a worker**, and `docker pull` succeeding by hand on a host
> tells you **nothing** about whether a task can pull there — it is the most natural diagnostic
> available and it exercises a different code path than the one failing.

⚠️ **Recorded as untested:** because the credential is a latch rather than a lookup, token expiry should
break *future task reschedules* — silently, weeks later, with every config file still reading correctly
— rather than failing at deploy time.

### 🚨 The secret is PRESENT but WRONG — the case no pre-flight can catch

Measured Aug 18, 2026 (drill D). We rotated `pg_password` without touching the database, expressed the
way a real rotation is: `name: pg_password_v2` under an unchanged `external: true` key, so the mount path
inside the container never changed. **Pre-flight passed. All four services converged. Digests resolved.
The smoke gate was the only thing that objected.**

| Command | Question | Verified? |
|---|---|---|
| `docker service logs <app> --tail 80 \| grep -iE 'password\|authentic'` | ⭐ **The app's side of the mismatch.** Ours: `asyncpg.exceptions.InvalidPasswordError`. | ✅ |
| `docker service logs <db> --tail 40 \| grep -i 'authentication failed'` | 🎯 **The server's side, and the discriminator that matters.** `FATAL: password authentication failed for user …` proves the *server* rejects the value the *client* was given — i.e. the rotation only ever reached one of the two. | ✅ |
| `docker exec <db-cid> cat /run/secrets/<name>` | What the database container actually received. Will show the **new** value while the server still enforces the old one. | ✅ |
| `docker service inspect <svc> --format '{{range .Spec.TaskTemplate.ContainerSpec.Secrets}}{{.SecretName}} -> {{.File.Name}} {{end}}'` | ⭐ **Which cluster secret is this service really using, and at which path?** The only way to see through a `name:` override. | ✅ |

⭐ **Why `POSTGRES_PASSWORD_FILE` does not rotate anything.** The image reads it **only when `initdb`
runs**, i.e. only on an empty data directory. With an existing volume the entrypoint skips
initialisation, so the authority for the credential stays in the database's own catalog. **The secret is
the client's copy; the server's copy lives in the volume.** The real rotation is two steps, in this order:

```sql
ALTER USER <user> WITH PASSWORD '<new>';   -- 1. server first: the old secret keeps working
```
```bash
printf '<new>' | docker secret create <name>_v2 -   # 2. then the client, then redeploy
```

🚨 **Reverse the order and you own an outage between the steps. Do only step 2 and every orchestrator
signal is green while nothing can reach the database.**

⚠️ **Two traps found while running this.** (1) With `name:` in play, the *stack key* and the *cluster
object* differ, so a pre-flight that greps the stack file for secret keys **verifies an object the
deploy will not use.** (2) 🚨 **Do not test a database credential from inside its own container** —
default `pg_hba.conf` in Postgres images carries `host all all 127.0.0.1/32 trust`, so loopback skips
authentication entirely. A **deliberately garbage** password returned `1` for us. Test from another
container, or read the server's log.

```bash
# The discriminator, if a loopback probe ever seems to accept a password:
docker exec <db-cid> sh -c 'PGPASSWORD=total-garbage psql -h 127.0.0.1 -U <user> -d <db> -tAc "select 1"'
docker exec <db-cid> sh -c 'grep -vE "^\s*#|^\s*$" /var/lib/postgresql/data/pg_hba.conf'
```

⭐ **The measurement lesson, general: when two probes of the same fact disagree, at least one is
measuring something else.** Our second probe reported "REJECTED" and had actually failed on
`database "capricorn" does not exist` — it omitted `-d`, and a `cmd && echo WORKS || echo FAILED` idiom
**collapsed every failure mode into one label.** Never let a probe report a cause it did not distinguish.

---

## 7. Making changes (and undoing them)

| Command | Question | Verified? |
|---|---|---|
| `docker stack deploy -c <file> --with-registry-auth <stack>` | Deploy or reconcile. **Declarative: it reconciles the whole stack**, so any service whose *spec* changed is recreated — including specs changed by things you never wrote in the file. | ✅ |
| `docker service scale <svc>=<n>` | Quick replica change. ⚠️ **Drifts from the stack file** — the next deploy reverts it. | ✅ scale-to-0 and back (Drill A); refusal under quorum loss (§9) |
| `docker service update --image <img> <svc>` | Change one service without a stack file. Same drift caveat. | ⚠️ |
| `docker service rollback <svc>` | Return to the previous spec. | ⚠️ |
| `docker node update --availability drain <node>` | ⭐ **The maintenance switch.** Evacuates tasks, accepts no new ones. Reads like a failure state; is the opposite. | ⚠️ |
| `docker node update --availability active <node>` | Put it back in service. | ⚠️ |

> **Blast radius is selective and not predictable from the command.** Adding `--with-registry-auth`
> recreated our three private-registry services and left Docker Hub's `redis:7.2.4-alpine` untouched —
> bouncing a perfectly healthy postgres purely because it shared a registry with the broken ones. A
> third run with an unchanged file recreated nothing at all.

---

## 8. Resource pressure

| Command | Question | Verified? |
|---|---|---|
| `docker system df` | Disk used by images, containers, volumes. Image sprawl fills a node quietly. | ⚠️ |
| `docker stats --no-stream` | Live CPU/memory per **local** container. | ⚠️ |
| `df -h /` | The node's disk. ⚠️ Our 40 GB nodes read **38G** — `/boot` and EFI come out of the same virtual disk. **38G is correct; do not hunt the missing 2 GB.** | ✅ |
| `docker node inspect <node> --format '{{.Description.Resources}}'` | What the scheduler *thinks* the node has. | ⚠️ |

---

## 9. Cluster lifecycle

| Command | Question | Verified? |
|---|---|---|
| `docker swarm init --advertise-addr <ip>` | Form a cluster. Pass the address explicitly on any multi-homed host. | ✅ |
| `docker swarm join-token manager` | 🚨 **The token you want for an HA cluster.** `swarm init` prints the **worker** token and invites you to use it — following that prompt yields a 1-manager cluster that reports 3 nodes and has zero fault tolerance. | ✅ |
| `docker swarm join-token worker` | For nodes that should only run tasks. | ✅ |
| `docker swarm join --token <tok> <manager>:2377` | Join. Idempotent-ish: refuses if already in a swarm, which is correct. | ✅ |
| `docker info \| grep -A5 Swarm` | Autolock state, CA expiry, node address, cluster ID. ⚠️ **Does not show the default address pool** — see §5. | ✅ |
| `docker swarm ca --rotate` | Rotate the cluster CA across all managers. | 🔲 planned drill |
| `docker node promote / demote <node>` | Change roles live. Demoting the last manager is refused. | ⚠️ |
| `docker swarm leave --force` | Remove *this* node. On the last manager, destroys the cluster. | ⚠️ |
| `docker node rm <node>` | Remove a **down** node from the roster. | ⚠️ |

> 🚨 **`CA Configuration: Expiry Duration: 3 months` interacts badly with snapshots.** Certificates
> rotate on a live cluster; a snapshot freezes them. Restore anything older than three months and the
> certs expired while frozen — **it presents as a networking fault and is not one.**

### 🚨 Quorum is gone — what still answers, and what you must not do

Measured Aug 18, 2026 (drill C5) by stopping the daemon on the **leader** and one other manager, leaving
one follower. **The application never missed a request.**

| Command | Behaviour with no quorum | Verified? |
|---|---|---|
| `docker service ls` | 🚨 `rpc error: code = DeadlineExceeded`. **Reads need the leader too** — Swarm serves no stale answers from a follower. | ✅ |
| `docker node ls` | `The swarm does not have a leader. It's possible that too few managers are online.` ⭐ **The clearest error message in Docker; trust it.** | ✅ |
| `docker service scale` / `update` | Refused with the same message. **Verified afterwards that the writes genuinely never landed** (`Replicas` unchanged, label absent) — Raft refused honestly. | ✅ |
| `docker info --format '{{.Swarm.Managers}} {{.Swarm.Nodes}} {{.Swarm.ControlAvailable}}'` | 🚨 **`0 0 true`** — reads as *"the cluster is empty"*, and `ControlAvailable` means "configured as a manager", **not** "management works". Monitoring built on that field reports healthy. | ✅ |
| `docker ps` | ✅ Works. 🎯 **During quorum loss this is your ONLY inventory**, and it is per-node — you must visit each one. | ✅ |
| `curl` the published ports | ✅ `200` with real data throughout. Existing tasks are unmanaged, not stopped. | ✅ |

```bash
# The only correct action. Quorum is arithmetic; nothing else fixes it.
sudo systemctl start docker.service        # on any downed manager
docker node ls                            # confirm a leader exists again
docker service ls --format '{{.Name}}\t{{.Replicas}}'   # confirm full strength returned
```

> 🚨 **Three instincts that convert a fully-serving cluster into a real outage:** restarting Docker on
> the node that still works, rebooting it, or running `docker swarm init --force-new-cluster`. The last
> one is a genuine recovery tool for a **permanently** lost majority and is catastrophic when the other
> managers are merely stopped. **A cluster with no leader is not down; it is serving traffic with the
> steering wheel disconnected.**

⭐ **Also observed twice now: Raft leadership is not sticky.** After recovery the leader was the node that
had *stayed up*, not the one that had been leader before. Do not build any procedure that assumes a
particular node is the leader — ask.

---

## 10. Lab-side (Proxmox) — assumed knowledge, listed for completeness

| Command | Note | Verified? |
|---|---|---|
| `for v in 191 192 193; do qm snapshot $v <name>; done` | ⚠️ **All three together or none.** The Raft log is *distributed* state; rolling one node back to a point the others passed leaves an inconsistent cluster. | ✅ |
| `qm listsnapshot <vmid>` | What rollback points exist. | ✅ |
| `qm rollback <vmid> <name>` | Restore. Again: all three. 🚨 **On ZFS this only works for the NEWEST snapshot** — see the row below. | ✅ |
| `qm resize <vmid> scsi0 40G` | ⚠️ **A resize is not an expansion** — the guest filesystem does not grow until something (cloud-init's `growpart`) grows it. Verify with `df -h`, not `qm config`. | ✅ |
| `zfs list -t snapshot -o name,used,creation -s creation \| grep vm-<vmid>` | **Answers "why did `qm rollback` refuse?"** PVE prints an indented *tree*, but on a `zfspool` the snapshots are a **linear chain** — `zfs rollback` can only return to the newest, and reaching an older one requires destroying everything after it. **Storage-dependent: qcow2 file storage really does branch.** | ✅ |
| `qm delsnapshot <vmid> <name>` | The price of going back more than one step on ZFS. **Take a `vzdump` first if the current state matters.** | ✅ |
| `qm shutdown <vmid> --timeout 90` | ✅ **Graceful — use this, not `qm stop`.** Verified to propagate ACPI → systemd → docker → `SIGTERM`: postgres logged `received fast shutdown request`. `qm stop` is a power cut and risks a torn Raft log. | ✅ |
| `vzdump <vmids> --storage <s> --mode stop --compress zstd --notes-template "why"` | A real recovery point, unlike a snapshot. **~1.2 GB and ~36 s per 40 GB disk** here (91% zeroes). ⚠️ **Excludes snapshots** — restores to a VM with no history. Always pass notes; a nameless archive is undiagnosable in six months. | ✅ |
| `zstd -t <archive>` / `cmp -s <a> <b>` | Verify a dump. ⚠️ **`zstd -t` proves the compressed stream is intact, NOT that the VMA restores** — only a test restore to a spare VMID proves that. `cmp` is the honest check after copying an archive. | ✅ |
| `pvesm status --content backup` / `pvesm list <storage>` | Which backup targets exist, and what is on them. ⚠️ **`active` only means the mountpoint responds** — see the credential trap below. | ✅ |
| `pvesm add cifs <id> … --username .. --password ..` | 🚨 **Pass `--password`; never hand-write the `.pw`.** A hand-made *bare* password file is malformed (see the `od` row) and fails `NT_STATUS_LOGON_FAILURE` — an auth-shaped error for a format problem, which is why it cost 20 minutes. ⚠️ **`pvesm set --password` also needs `--username` in the SAME call**, even when the config already has one, or it warns `no user set` and writes an **empty** password. | ✅ |
| `smbclient -L //<server> -A <authfile>` then `mount -t cifs …` | The discriminator when a CIFS storage will not authenticate — separates "wrong credential" from "PVE is not using it". ⚠️ **Only as good as the authfile you build:** ours wrapped a `.pw` that already contained `password=`, yielding `password=password=…`. **Two tests that share a bad assumption are one test**, and they agreed convincingly. | ✅ |
| `od -c /etc/pve/priv/storage/<id>.pw` | ⭐ **Run this BEFORE reasoning about a credential file.** The file is `password=<value>`+newline — **not** a bare password. ❌ We used `wc -c` = 19 as a proxy for *which* password it held and invented a stale-credential outage that did not exist. **A byte count is not a value.** | ✅ |
| `umount /mnt/pve/<id>` then `pvesm status --storage <id>` | ⭐ **The only real test of a stored credential**, and the true half of the false alarm above. CIFS **never re-authenticates a live mount**, so one that has been up for months proves nothing about whether it can be *re-*established after a reboot. Pair it with a write test — a read-only remount still breaks backups. | ✅ |

---

## 11. Toward `docker-admin.sh`

Andrew's idea, Aug 13, 2026: a single portable script to take to work while learning to investigate
Swarm issues. **Worth building, and the design constraints matter more than the command list.**

### 🎯 The requirement, as Andrew scoped it (Aug 13, 2026)

> *"A command-line tool that will **take inputs** and help me **investigate outages**, and **output
> issues and suggestions** about how to investigate further or fix them. It will be a **read-only**
> tool."*
>
> **Timing: build it at the END of the track**, after the chapter 5 failure drills, with a deliberate
> long design session. Not incrementally, not now.

⭐ **This is a bigger ask than a command wrapper, and it changes what we must collect between now and
then.** A wrapper runs commands and shows you output. **A tool that outputs *issues and suggestions* has
to interpret that output** — which means it needs, for every failure we ever see:

| What to capture | Why the tool needs it |
|---|---|
| **The signal** — the exact string, state, or count that is observable | This is what the tool pattern-matches on. Prose like "it was rejected" is useless; `Rejected` + `access forbidden` is a rule |
| **The interpretation** — what that signal actually means mechanically | The "issue" the tool reports |
| **The discriminator** — what distinguishes this cause from the other causes that produce the same signal | 🚨 **The hard part.** Without it the tool guesses confidently |
| **The next command** — what to run to confirm or rule it out | The "investigate further" output |
| **The fix, and its blast radius** | The "suggestion" output — and the read-only rule means it *prints* the fix, never applies it |

🚨 **So the failure-mode tables in §2 are not documentation of past events — they are the tool's
knowledge base, and they need to be written as decision rules from now on.** A finding recorded only as
narrative prose in a chapter cannot be turned into a rule later without re-deriving it.

⚠️ **The central risk, to design against explicitly: confidently wrong advice during an outage is worse
than no advice.** A tool that says "your registry credential expired" when the real problem is a full
disk will send someone down the wrong path at the worst possible moment. Three mitigations to build in:

1. **Show the evidence that matched.** Never state a conclusion without printing the observed signal it
   was derived from, so the human can reject it in one glance.
2. **Rank by confidence and say so.** "Certain" (the signal is unambiguous), "likely", "possible —
   check this next". Our own C1 experience is the case study: the obvious explanation was wrong, and a
   tool asserting it would have been believed.
3. **Distinguish "I observed this" from "this is commonly caused by".** Same honesty rule as the ✅/⚠️
   markers in this file.

### Non-negotiables

1. 🚨 **Read-only by default.** An investigation tool must be incapable of changing state. Nobody wants
   to discover during an incident that a diagnostic subcommand can drain a node. Anything mutating
   belongs in `deploy_swarm.sh` or nowhere.
2. ⭐ **It MUST print every command before running it.** This is the difference between a tool that
   teaches and a crutch that hides the skill. It also means the tool stays useful on a host where it is
   not installed — you read the output and type the command yourself.
3. **No hardcoded hostnames, IPs, stack names or registries.** If it only works on this lab it is a lab
   script, not something to take to a job.
4. **Single file, pure bash, no dependencies beyond `docker`.** It has to survive `scp` onto a
   locked-down host. `jq` is optional and must degrade gracefully.
5. **Subcommands are named after QUESTIONS, not after Docker nouns.** `docker-admin.sh why-not-running
   <svc>` beats a menu that mirrors the CLI you already have. The value being packaged is *the order of
   the questions* — §1 and §2 of this file — not the existence of the commands.

### Candidate subcommands, drawn from the sections above

| Subcommand | Wraps |
|---|---|
| `health` | §1, in order, stopping at the first thing that looks wrong |
| `why-not-running <svc>` | §2 — task history, errors untruncated, logs, and the failure-mode table as hints |
| `whats-live [<stack>]` | §4 — resolved digests plus `UpdateStatus`, so drift and false-greens surface together |
| `node <node>` | §3 + §8 — what it carries, what it has, whether it is drained |
| `net [<stack>]` | §5 — overlays, subnets, the address-pool collision check |
| `auth <registry>` | §6 — is a credential present, does it decode, is it in the service specs |
| `explain <failure-state>` | Prints the §2 interpretation table. No Docker calls at all |

### ⚠️ The honest caveat about using it at work

Running an unvetted script against someone else's production cluster is a **political and security**
problem before it is a technical one. Constraints 1, 2 and 4 are what make it defensible to a reviewer:
read-only, prints everything it does, and short enough that a skeptical colleague can read the whole
thing in five minutes. **Build it to be reviewed, not just to be run.**

### Status

🔲 **Not built. Deferred to the END of the track by Andrew's decision (Aug 13, 2026)**, to be preceded
by a dedicated long design session. Chapter 5's failure drills produce the diagnostic sequences worth
automating, and automating them before feeling them would package guesses.

**What to do in the meantime — this is the actionable part:**

1. **Every failure we hit gets recorded as a decision rule**, with all five fields from the table above
   — signal, interpretation, discriminator, next command, fix + blast radius. Prose in a chapter is not
   enough; the discriminator in particular is only knowable while the failure is in front of us.
2. **Log the diagnostic sequence, in order, including the dead ends.** The dead ends are what teach the
   tool to rank causes, and they are the first thing forgotten.
3. ⚠️ **Every trap in chapters 3–5 is a rule-generating opportunity** — C2 through C7 each produce a
   distinct signal. That is six rules if we capture them as they fire, or six reconstructions if we
   don't.

#### ✅ Rules harvested as of Aug 18, 2026 — the drills are done, so this is the input the design session gets

| Signal an operator sees | Discriminator that settles it | Section |
|---|---|---|
| `N/N` and the right tag, after a deploy you are unsure about | `UpdateStatus.State` — `rollback_*` means **your change was refused** | §4 |
| Service under-replicated, nothing in a failed state | `CurrentState` shows **`Complete`** + `RestartPolicy.Condition` is `on-failure` | §4 |
| Dataset empty, orchestrator green | `docker volume inspect --format '{{.CreatedAt}}'` — *seconds old* = new empty volume on a new node | §3 |
| All green, requests 500 | The database's own log: `authentication failed` = a present-but-**wrong** secret | §6 |
| Every management command times out, app fine | `docker node ls` says "no leader"; `docker ps` still works | §9 |
| `Name or service not known` for a dependency | `docker service ls --filter name=<dep>` — `0/0` is far likelier than a DNS fault | §2 |
| Digests differ between two deploys nobody changed | Compare `.Spec.TaskTemplate.ContainerSpec.Image` across runs — a mutable tag moved | §4 |
| `UpdateStatus: completed`, smoke gate green — and users report the site is gone | `curl` **every published port** and match the body against something only your app serves — the gate only defends the port it calls | §4b |
| Replicas read `4/3` mid-deploy | Not a fault: `start-first` runs old + new together for a moment. A poller must treat `current != desired` as *pending*, not *failed* — and `4/3` proves counts can exceed desired | §4 |
| `/health` is 200 while the app cannot do business | `/health` tests routing only; a dependency-exercising request (the §4b gate) is the discriminator | §4b |
| Log says `✅ Bootstrap complete`, data is wrong | grep for the **fallback fingerprint** (`using minimal bootstrap`) above the success line — success messages can sit downstream of a caught failure | §5 |
| A drill or check "passed" suspiciously fast | Assert the preconditions it depended on (which file deployed, which host ran it, was the volume really gone) — **a passing check with unasserted preconditions is not evidence** | §0 |

⭐ **One requirement the drills added that was not in the original scope:** the tool must be able to say
**"this looks fine and here is what that does NOT rule out."** Six of the eight false greens in
chapter 6 would pass every check in §1. A tool that only reports problems it can see will be trusted for
the ones it cannot.
