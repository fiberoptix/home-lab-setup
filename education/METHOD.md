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

## Who does the work — this is hands-on training

**⭐ Andrew runs the commands. The AI explains, checks, and writes.** This governs all five stages
below and is the single easiest thing to get wrong, because it is always faster for the AI to just do
it. Faster, and worthless: **"only document what you actually ran" is only worth something if *Andrew*
ran it.** If the AI drives, that rule quietly degrades into "only document what was executed", and the
material stops being something he can stand behind in an incident or a conversation.

⚠️ **This was the practice from the start and it went unwritten for two tracks.** Track 1's log records
"ready for the **guided** Part 3" and "Part 3 **hands-on, Andrew driving**", followed by "everything
documented came from something he ran" — but as a diary entry, never as a rule. **Phase 16 Part 1 was
then driven entirely by the AI**, which is exactly how an unwritten practice decays.

### The split: who drives what

| Work | Driver |
|---|---|
| **Anything NEW** — the technology being studied, its failure modes, its tooling | 🙋 **Andrew** |
| **Routine lab plumbing already proven here** — cloning from template 9000, `host_setup.sh`, `qm` resize/snapshot, VM sizing | 🤖 AI may drive |
| **Writing** — chapters, phase files, MEMORY, diagrams, and the scripts as committed artefacts | 🤖 AI |

Track 1 drew this same line: the AI built the VM and installed k3s (Parts 1–2), Andrew drove the
Kubernetes object model onward (Part 3+). **The test is not "is it hard", it is "is this the thing we
are here to learn".** Cloning a VM for the tenth time is not.

### The loop, when Andrew is driving

**One step at a time.** Not a wall of commands.

1. **AI says what we are about to do and why** — the reasoning first, so the command is not a
   magic incantation.
2. **AI gives the command.** One step, or a tight group that only makes sense together.
3. **Andrew runs it and pastes the output.**
4. **AI checks the output and explains what it actually means** — including when it means something
   different from what it appears to mean.
5. Repeat. Snapshot at the milestone.

### When something breaks

🚨 **Let Andrew diagnose it first. The AI stays quiet until asked, or until he is heading somewhere
that will cost real time.** Debugging while confused *is* the job skill; being handed the answer
teaches the fact and skips the skill. This applies doubly to the planted traps, which exist precisely
to be struggled with — the anti-pattern table already forbids pre-empting them, and narrating the
answer the moment they fire is the same mistake one step later.

### Repetition

**Andrew does the first node by hand; the AI does the remaining ones.** He learns it once; the session
is not spent typing the same join command three times. If the repetition is itself the lesson — as
with writing a re-runnable provisioning script — then it is "anything new" and he drives it.

---

## The five stages

### 1. Plan — decide what success is, and where you intend to fail

The plan is worth real effort because it is the only stage where you can still choose what you will
learn. Its job is to make the phase *fail on purpose in useful places*.

- State **success as a sentence you could say out loud**, not a task list. Phase 16: "build a Swarm
  from nothing, ship to it from a pipeline, break it several ways, and explain what each failure did
  to the application."
- **List the traps in advance and mark them do-not-fix.** A trap pre-empted is a lesson deleted.
- ⭐ **VERIFY EACH TRAP'S PRECONDITION before the phase starts — a trap that cannot fire is a lesson
  deleted just as surely as one that was pre-empted, and it is worse because the plan still claims it.**
  Added Aug 19, 2026, after it paid off immediately in Phase 17: one read-only query confirmed GitLab
  would in fact refuse the webhook the trap depends on. ⚠️ **The failure it guards against already
  happened once** — Phase 16's trap C2 (a start-order race) **could not fire at all**, because manual
  `docker pull`s during an earlier investigation had left the state the race needed. Nobody had checked.
  🚨 **Checking a precondition is NOT pre-empting the trap.** Knowing a switch exists is not the same as
  having the thing work, and the diagnosis still has to be earned when it fires. The test: *does knowing
  this let me skip the debugging?* If no, check it. **And it pays twice** — Phase 17's check turned up an
  unrelated finding (the same product blocks one hook type and permits another) that no tutorial states.
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
- ⭐ **Test the ZERO-TO-SIXTY path, not just the incremental one** (Andrew, Aug 13 — "I would normally
  try that 0-60 approach"). A deploy onto a system that already holds state is a *different test* from
  a deploy onto nothing, and the incremental one hides failures the from-scratch one exposes. Phase 16
  hit this twice in ten minutes: manual `docker pull`s during investigation left two of three images
  cached, so trap C1 half-succeeded instead of failing cleanly; and postgres surviving that partial
  deploy meant trap C2's start-order race **could not fire at all**. ⚠️ **The commands you run while
  investigating change the state of the thing you later test.** When a trap depends on a cold start,
  tear the stack down and deploy from nothing — and note in the phase file which findings came from a
  contaminated run.
- **Snapshot at each milestone**, named so they sort. For distributed state, snapshot **all nodes
  together or not at all** — rolling one node back to where the others have moved on is a debugging
  session you did not sign up for.
- ⭐ **Keep a "Lab vs PROD" ledger in the phase file, and write to it AT THE MOMENT you take the
  shortcut.** Every lab makes compromises an enterprise platform would not accept — plaintext
  registries, secrets readable on disk, managers that also run workloads, patching switched off.
  **Record what you did, why it is acceptable here, what production does instead, and what breaks if
  the habit follows you.** Do it in the moment: the honest reason is freshest then, and reconstructing
  it at write-up time is how a real compromise turns into invented best practice. The chapter callout
  is drawn from this ledger — format and threshold live in `CONVENTIONS.md` → "Lab vs PROD callouts".
  ⚠️ **Mark which prescriptions were verified and which are recited.** Added Aug 13 after Phase 16
  Part 2 banked eight of these before anyone had written one down.

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

⭐ **Log every diagnostic command AS YOU RUN IT, in a track-level `COMMANDS.md`, indexed by the QUESTION
it answers** (Andrew's idea, Aug 13, 2026 — introduced on the `docker-swarm` track). Three reasons this
cannot wait until the Document stage:

1. **Chapters teach in the order things were learned. An incident does not cooperate with that order.**
   The transferable skill is *which question to ask second*, and that ordering is invisible once the
   commands are scattered across five chapters in narrative sequence.
2. **Reconstructing it later is archaeology.** By the last chapter there are a hundred commands and no
   memory of which mattered. ⚠️ **This was already proven the hard way:** chapters 1 and 2 of the swarm
   track were written without it, and `docker service ps` — *the* command that disproved our wrong
   theory about registry auth — did not appear in either chapter's command list.
3. **It becomes the specification for tooling.** A read-only investigation script is only worth building
   from sequences you have actually felt. Build it before that and you package guesses.

Mark each entry **✅ ran it here** or **⚠️ standard, not run here**. The same honesty rule as Lab-vs-PROD
callouts: a command nobody executed must not wear the authority of one that was.

### 5. Document — write it after, from what happened

- The **phase file is the working record** (decisions, blockers, what was actually run, what
  surprised you). The **chapter is reader-facing**. Do not merge them.
- ⭐ **Scope the chapter to the subject, not to the keystrokes.** Routine lab plumbing already proven
  here — cloning from template 9000, `host_setup.sh`, `qm` snapshots — is **assumed, not re-taught**.
  But the infrastructure **as it pertains to this build**, and above all the **what and why**, belongs
  in the chapter: why three nodes and not two, why all managers, why `vm-ephemeral`, why the 3.5 GB
  template disk had to grow. See `CONVENTIONS.md` → "What belongs in a chapter".
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
| **Drive the build yourself when the point was for Andrew to learn it** | Always faster, and it hollows out the material: "only document what you actually ran" means nothing if the AI ran it. Phase 16 Part 1 was lost this way. |
| **Narrate the answer the moment a trap fires** | Same mistake as pre-empting it, one step later. Let him diagnose; debugging while confused is the skill. |
| Re-teach routine lab plumbing in a chapter | It buries the subject. Assume what the lab has proven before; explain what and why *this* build needed. |
| **Let a lab shortcut go unrecorded** | The reader is doing this on an enterprise platform. An unnamed shortcut is one they will carry into production believing it is the normal way. |
| **State "in production you would…" without saying whether you verified it** | It is the one way the Lab-vs-PROD callout can actively mislead: a plausible recitation wearing the authority of something tested. |
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
