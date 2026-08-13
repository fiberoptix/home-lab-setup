# Swarm command ledger

Every command this track actually used, **organised by the question it answers rather than by the
chapter it appeared in.** Chapters teach in the order things were learned; an incident does not
cooperate with that order.

⭐ **This file is the specification for a future `docker-admin.sh`** (Andrew's idea, Aug 13, 2026) — a
portable read-only investigation tool. It is written *as the track runs*, not reconstructed at the end,
because by chapter 5 there will be a hundred commands and no memory of which ones mattered. See
[§11](#11-toward-docker-adminsh) for the design rules that fall out of it.

**Verified?** column:
- ✅ **ran it here** — executed in this lab, output understood
- ⚠️ **standard, not run here** — believed correct, **not** exercised. Do not present as tested.

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
| Task count fine, app broken | 🚨 **No healthcheck.** The process is up and serving garbage. Swarm cannot tell |

---

## 3. Where is it running, and what is on this node?

| Command | Question | Verified? |
|---|---|---|
| `docker node ps <node>` | What tasks is **this node** carrying? The complement of `service ps` — essential before draining anything. | ⚠️ |
| `docker node ps self` | Same for the node you are on. | ⚠️ |
| `docker node inspect <node> --pretty` | Labels, availability, resources, engine version. | ✅ |
| `docker ps` | Containers **on this host only.** ⚠️ A Swarm service is invisible here unless a task happens to be local — the classic "my service is running but `docker ps` is empty" confusion. | ✅ |

---

## 4. What is ACTUALLY deployed? (drift, versions, convergence)

The gap between "what the file says" and "what is running" is where outages live.

| Command | Question | Verified? |
|---|---|---|
| `docker service inspect <svc> --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}'` | ⭐ **The resolved DIGEST, not the tag you asked for.** Swarm pins a tag to a digest at accept time, so this is the only honest answer to "what version is live". | ✅ |
| `docker service inspect <svc> --format '{{.UpdateStatus.State}}'` | 🚨 **The real convergence signal.** `updating` / `completed` / `rollback_started` / `rollback_completed` / empty-if-never-updated. | ✅ |
| `docker service inspect <svc> --format '{{.UpdateStatus.Message}}'` | Why the rollout ended the way it did. | ⚠️ |
| `docker service ls` | Current replica counts only — **no history, no update state.** | ✅ |

> 🚨 **Two ways a deploy reports green while broken.** First, `docker stack deploy` exits `0` when the
> manager *accepts* desired state, not when anything runs. Second, **replica count is not convergence**:
> `order: start-first` holds `3/3` right through a rolling replacement, and `failure_action: rollback`
> restores the *old* version at *full* replicas — so a count-only check calls a **rejected deploy a
> success**. Always pair counts with `UpdateStatus`.

⚠️ **Recorded as untested:** `UpdateStatus` appears to be a *latch* that persists until the next update
begins, so a stale `rollback_completed` could make a checker fail a healthy cluster. To be settled in
chapter 5.

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

---

## 7. Making changes (and undoing them)

| Command | Question | Verified? |
|---|---|---|
| `docker stack deploy -c <file> --with-registry-auth <stack>` | Deploy or reconcile. **Declarative: it reconciles the whole stack**, so any service whose *spec* changed is recreated — including specs changed by things you never wrote in the file. | ✅ |
| `docker service scale <svc>=<n>` | Quick replica change. ⚠️ **Drifts from the stack file** — the next deploy reverts it. | ⚠️ |
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
| `pvesm add cifs <id> --server .. --share .. --subdir .. --username .. --password ..` | 🚨 **`--password` is MANDATORY.** Pre-placing `/etc/pve/priv/storage/<id>.pw` does not work: the connection check authenticates with what the API call carried, so it fails `NT_STATUS_LOGON_FAILURE` **with a perfectly correct file on disk**. Cost 20 minutes because the error names auth, not a missing argument. | ✅ |
| `smbclient -L //<server> -A <authfile>` then `mount -t cifs …` | **The discriminator when a CIFS storage will not authenticate**: it separates "wrong credential" from "PVE is not using the credential". Both succeeded here while `pvesm add` failed — which is what proved the problem was the missing `--password`. | ✅ |
| `wc -c < /etc/pve/priv/storage/<id>.pw` | 🚨 **Found a latent outage with this.** A stale password in a `.pw` file is invisible while the mount stays up, because **CIFS does not re-authenticate a live mount**. The nightly GitLab backup has been succeeding into a mount from June with a credential that no longer works. **A working mount is not evidence of a working credential** — that is only tested at mount time. | ✅ |

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
