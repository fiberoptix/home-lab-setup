# How to run a track

[`CONVENTIONS.md`](CONVENTIONS.md) is the sibling of this file and answers a different question. It
governs the **artefact** — chapter shape, diagrams, figure legibility, the Word build, the highlight
pass. This file governs the **work that produces the material**: how a subject gets learned well
enough to be worth writing down.

Both sit underneath `CURSOR_RULES`, which owns the project process (write the phase plan, present it,
wait for approval, implement, document). That is administration. This is method.

---

## The rule that matters most

**This is a floor, not a ceiling.** It exists so that a track never starts from a blank page and never
silently drops a stage that turned out to matter. It is not a form to fill in.

**Deviate deliberately whenever the subject calls for it** — then, in the same session, **fold what
worked back into this file.** That last half is the part that gets forgotten, and it is the whole
reason the file exists. Two examples that were invented mid-phase and would otherwise have been lost:

- **The planted-traps table** (Phase 16 🅒) — failures listed *in advance*, with an explicit
  instruction not to fix them before hitting them. Phase 14 ran drills but had no guard against a
  well-meaning later session smoothing the road before anyone tripped on it.
- **Sorting caveats into kinds** (Phase 16 🅐🅑🅒🅓 — open items / hard rules / traps / inherited
  findings). Phase 16's first draft listed five "open questions" that read as five blockers when only
  two needed a human. Kinds, not a flat list.

Both are now stages below. If you invent a third, add it.

---

## The five stages

### 1. Plan — decide what success is, and where you intend to fail

The plan is worth real effort because it is the only stage where you can still choose what you will
learn. Its job is to make the phase *fail on purpose in useful places*.

- State **success as a sentence you could say out loud**, not a task list. Phase 16: "build a Swarm
  from nothing, ship to it from a pipeline, break it several ways, and explain what each failure did
  to the application."
- **List the traps in advance and mark them do-not-fix.** A trap pre-empted is a lesson deleted.
- **Sort the caveats into kinds** so they cannot be confused: what needs a decision, what is a hard
  rule, what is a deliberate trap, what is inherited and out of scope. Say who resolves each, and
  close what you can by *going and looking* rather than by asking.
- Some decisions are **better deferred into the work** — choosing between them *is* the deliverable.
  Phase 16's postgres storage question (pin to a node vs NAS volume) is deferred on purpose.
- Plan the **resources, the snapshot checkpoints, the teardown, and what is out of scope** up front.
  Out-of-scope is not padding; it is what stops a track from quietly becoming three tracks.

### 2. Build — script it, and verify from the inside

- **Write a re-runnable script, not commands typed N times.** Typing them three times is how the
  third node ends up subtly different, and a mysteriously broken third node teaches nothing.
  Make it idempotent so a partial run is repeated, not unpicked.
- **Use the lab's standard tooling** where it exists. Phase 16's nodes got the registry's
  `insecure-registries` config for free from `setup_docker.sh` — the step people do by hand and
  forget on two of three nodes.
- ⭐ **Verify from inside the guest, not from the control plane.** `qm config` said the disk was
  40 GB; only `df -h /` on the node could prove the filesystem had followed. A layer reporting
  success is not the layer that will fail.
- **Prove by test, not by reading config.** A config that says `passwordauthentication yes` and an
  account whose password is locked look identical until you try it.
- **Snapshot at each milestone**, named so they sort. For distributed state, snapshot **all nodes
  together or not at all** — rolling one node back to where the others have moved on is a debugging
  session you did not sign up for.

### 3. Break — drills chosen for consequence, not for drama

- Pick drills by **what they would mean at 3am**, and write the "what to conclude" column *before*
  running them. The single most valuable Phase 16 drill is a rescheduled postgres coming up healthy
  against a brand-new empty database: silent data loss that looks like a clean deploy.
- **Hit the planted traps on purpose**, in the order that makes each one legible.
- **Drill hygiene: wait for the thing to actually be gone before judging.** Checking too fast in
  Phase 14 caught a `Terminating`-but-still-serving broker and produced a write that "should" have
  failed.
- **State honestly what the lab cannot simulate.** Three VMs on one host is *node* failure, not
  *host* failure. Three brokers in one VM was the same caveat. Say it in the chapter.
- Restore after each drill so the next one starts from a known state.

### 4. Investigate — the stage that produces the material

**This is where the value is, and it is the stage a schedule will try to squeeze.** Almost nothing
quotable in track 1 was planned: the sticky partitioner sending 300 unkeyed records to one partition,
the chart's documented anti-affinity override being vestigial, `rpk topic consume -o start:end`
silently returning 0, `Under-replicated` reading 0 during quorum loss because no leader was left to
compute it. None of that is in any tutorial, and all of it came from following a surprise.

- **When something surprises you, stop and chase it.** The surprise is the deliverable.
- **Read the earliest stuck thing, not the loudest broken one.** A Helm hang → pods Pending → PVCs
  Pending → a crash-looping console is one cause and four symptoms.
- **Turn each finding into a habit if you can.** "The override did nothing" became
  `helm template … | grep -A14 affinity` *before* installing anything you are overriding.
- **Prefer the mechanism to the workaround.** Knowing an EndpointSlice is what kube-proxy actually
  reads explains a whole class of blackholed Services.
- **Record output that legitimately varies between runs** as varying — which partition a sticky
  producer picks, the initial leader assignment. A runbook that promises output it cannot deliver
  trains you to distrust it.

### 5. Document — write it after, from what happened

- The **phase file is the working record** (decisions, blockers, what was actually run, what
  surprised you). The **chapter is reader-facing**. Do not merge them.
- Write the chapter **after** the work, following `CONVENTIONS.md`. Only document what was actually
  run; a research-only chapter is allowed but must declare itself in its opening paragraph.
- **Record what a later session must not re-derive**, and what it must not "fix". Both matter.
- Push the durable facts up into `MEMORY.md` so a cold reload gets them without opening the phase
  file.

---

## Anti-patterns

| Don't | Because |
|---|---|
| Pre-empt a planted trap | It turns the phase into a tutorial where nothing fails, which is the failure mode this whole method exists to avoid. |
| Document something you did not run | The material's entire authority is that every command was executed and every output is real. |
| "Fix" a known-and-accepted issue unprompted | Track 1's four sub-10pt figures were **accepted after Andrew printed them**. Re-fixing accepted debt is churn, and it overrides a human decision. |
| Skip a snapshot because the drill "looks safe" | The value of drills comes from rollback being instant. The one you skip is the one you need. |
| Judge the system from the control plane's report | `qm config`, a green deploy, and `docker stack deploy` returning success all report intent, not outcome. |
| Treat investigation as overhead between build and document | It is the stage that produces everything worth reading. |
| Let a schedule decide when a subject is finished | The schedule is an estimate. The traps list is the contract. |

---

## How this file changes

Amend it **in the session where the improvement proved itself**, not later from memory. Add the new
practice to the stage it belongs to, and say in one line what it fixed — the reason a rule exists is
what keeps a future session from deleting it as ceremony.

Conventions about *writing* still go in `CONVENTIONS.md`, never here and never forked into a track.
