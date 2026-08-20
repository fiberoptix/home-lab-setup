# Phase 17 — Jenkins: build the controller, wire it to GitLab, and deploy Capricorn *properly*

**Status:** 📋 **PLAN — AWAITING ANDREW'S APPROVAL. Nothing has been built and nothing destroyed.**
**Created:** August 19, 2026
**Owner:** Andrew
**Track:** `education/jenkins/` (chapter numbering restarts at 01 — see `education/CONVENTIONS.md`)
**Weighting — ⭐ set by Andrew, Aug 19, 2026, and it is not the same as Phase 16's:**

> *"The most important aspects of this track are that we install, configure Jenkins server, we hook it
> up to GitLab and the docker-swarm, and we learn about deploying and fixing bad deployments like we
> did in phase16 with GitLab."*

**So the weight is: install and configure (Parts 1–2) → wire it to GitLab and the Swarm (Parts 3–5) →
deploy, break, and RECOVER (Part 6, the centre of gravity).** Hardening the three insecure things
Phase 16 left behind is still a Phase 17 deliverable — it is the standing charter — but it is **Part 7
and it is not the summit of the phase.** ⚠️ **This is a correction to this plan's first draft**, which
billed the security work as the centre of gravity. Fixing a bad deployment at 3am is the thing the job
will actually ask for.
🙋 **HANDS-ON THROUGHOUT except Part 0.** Andrew runs the commands; the AI explains, checks and writes
— `education/METHOD.md` → "Who does the work". Part 0 is VM plumbing the lab has done a dozen times
and is explicitly AI-drivable under that same table. **Everything from Part 1 onward is the subject.**
📖 **`education/CONVENTIONS.md` and `education/METHOD.md` are MANDATORY reads for this phase**, not
optional. Session 1 drafts chapter 1.

---

## 🎭 The framing — and the one honesty rule that goes with it

⭐ **Andrew's instruction (Aug 19, 2026):** *"Imagine I am already working at the firm and they give us
all the info we need to build the server, including wiring it to GitLab and docker-swarm."*

So this phase is written as an **onboarding build standard**: a spec handed to a new engineer on day
one, rather than a set of choices to deliberate. Three reasons that is the better frame here:

1. **It is how the work actually arrives.** Nobody joins a financial firm and gets asked which CI
   topology they would prefer. You are handed a standard and expected to build to it, understand it,
   and know which parts of it are load-bearing.
2. **Real standards contain inherited compromises you cannot change** — so some of the planted traps
   can live *inside the spec itself*, which is exactly how it feels on the job. This is a better
   teacher than a lab where every choice was ours and therefore defensible.
3. It removes a round of decision-making that was, honestly, ceremony.

### 🚨 The honesty rule this makes non-negotiable

**The AI does not know this firm's actual standard.** Anything written below is either a fact about
Jenkins or an invention. `METHOD.md`'s anti-pattern table already forbids the failure mode — *"a
plausible recitation wearing the authority of something tested"* — and a fabricated "the firm does it
this way" is the purest form of it. So **every item in the build standard carries one of two marks**:

| Mark | Means | How to treat it |
|---|---|---|
| 🔧 **MECHANICS** | How Jenkins actually behaves. True in any shop, and verifiable here. | Rely on it. If we assert it, we test it. |
| 📐 **CONVENTION** | A choice the AI made to stand in for the firm's standard — naming, layout, plugin set, counts. | Scaffolding. **Ask about it on day one**; their answer may differ and that is fine. |

⚠️ **A 📐 item is never described as "what production does".** Where the plan claims a production
practice, it is marked ⚠️ recited or ✅ verified exactly as the Lab-vs-PROD ledger requires.

⚠️ **This framing is a deliberate deviation from `METHOD.md`, which assumes we choose the build.** Per
`CURSOR_RULES` rule 8, if it proves out it gets folded back into `METHOD.md` **in the session it
proves out** — as a named option for a track whose subject is a tool you will inherit rather than
choose. If it turns out to hollow out the learning, that gets written down too.

---

## 🎯 Success — as a sentence

> **Install and configure a Jenkins controller from nothing, wire it to our own GitLab and to the
> Swarm, ship Capricorn from a Jenkinsfile — and then be able to take a BAD deployment and recover
> from it, knowing which instrument answers which question and which green signals are lying.**

⭐ **The recovery half is the point.** Anyone can make a pipeline go green once. The skill that gets
paid for is the one Phase 16 built on the GitLab side: **a deploy has gone wrong, three tools disagree
about whether it is wrong, and you have to decide whether to roll back or fix forward while the app is
serving users.** Phase 16 earned that on GitLab CI. This phase earns it on Jenkins, where the
signals are different — Jenkins reports on its own *job*, and the Swarm reports on the *service*, and
those are not the same question.

Secondary, and genuinely secondary: **fix and *prove* fixed the three insecure things Phase 16
deliberately left broken.** The transferable story there is "we moved a deploy from GitLab CI to
Jenkins and here is what got safer, here is what got worse, and here is how I proved both."

### The charter, and an honest correction to its scope

`MEMORY.md` records the charter agreed at the end of Phase 16:

> ⭐ **PHASE 17 CHARTER agreed:** its success condition is *"every ⚠️ recited row in the Phase 16
> ledger is now ✅ verified"* — host keys pinned, a maskable/keystore credential, an unprivileged agent.

⚠️ **The literal wording is broader than the three examples it names, and broader than this phase.**
There are **six** `⚠️ recited` rows in the Phase 16 ledger, and only three of them are things a CI
system can fix:

| Row | Compromise | Phase 17? |
|---|---|---|
| **L21** | Passphrase-less deploy key in an **unmasked** CI variable | ✅ **In scope** — Jenkins has a real credential store |
| **L22** | `StrictHostKeyChecking=no` on every `ssh`/`scp` in the deploy | ✅ **In scope** — pin the host keys |
| **L12** | One long-lived registry token, embedded in every service spec | 🟡 **Partly** — we can scope a Jenkins-only token and shorten its life; true per-deploy issuance needs a broker we do not have |
| L1 | Registry over plaintext HTTP (`insecure-registries`) | ❌ **Out of scope** — registry/TLS work, not CI. Carried forward. |
| L2 | `Autolock Managers: false` — Raft key on disk in the clear | ❌ **Out of scope** — Swarm control plane. Carried forward. |
| L3 | All three nodes are managers *and* run workloads | ❌ **Out of scope** — cluster shape. Carried forward. |

**Plus the fourth item the charter names but the ledger does not number: the privileged runner.**
Phase 16's runner had far more access than the deploy needed. Jenkins' equivalent is the agent, and
Part 5 gives it the least privilege the deploy can actually work with.

🚨 **So the charter is hereby scoped, on the record, to L21 + L22 + L12(partial) + the agent's
privilege.** L1/L2/L3 stay open and get carried forward rather than quietly dropped — an unscoped
success condition is one that will be declared met by a future session that never read the ledger.

⚠️ **And per Andrew's weighting (above), this charter is Part 7 — a required deliverable, not the
phase's centre.** It is listed this precisely so that "we ran out of time" cannot quietly turn into
"we decided it was done."

---

## 📌 READ THIS FIRST — the pre-flight list

**Andrew asked in Phase 16 that these be talked through at the start of the build session, not
skimmed.** Same here. Four kinds of item, and telling them apart is the whole point.

### 🅐 Open items — and who resolves each

| # | Item | Owner | State |
|---|---|---|---|
| A1 | Does Jenkins get a DNS name or do we work at `http://192.168.1.185:8080`? | 🙋 **Andrew** | ✅ **CLOSED Aug 19 — no DNS. Bookmark the IP.** `http://192.168.1.185:8080/` is also what goes in **Jenkins Location → Jenkins URL**, which is not cosmetic: Jenkins builds webhook and email links from it, and a wrong value produces links that fail while the build succeeds. |
| A2 | Does the web UI get TLS, or stay plain HTTP on the LAN? | 🙋 **Andrew** | ✅ **CLOSED Aug 19 — no TLS in the lab.** Accepted deliberately, and therefore recorded as ledger row **J1** rather than left unsaid. |
| A3 | Jenkins version + install method | *AI, as the standard* | ✅ **CLOSED** — Jenkins **LTS** from the official apt repo. 🔧 |
| A4 | How does Jenkins authenticate to GitLab to *clone*? | *AI, as the standard* | ✅ **CLOSED** — a **read-only per-project GitLab deploy key**, never the root wallet. 🔧 |
| A5 | Controller + agent, or controller only? | *AI, as the standard* | ✅ **CLOSED** — controller with **0 executors** + one agent. 🔧 the split; 📐 the agent lives on the same VM (see Resources). |
| A6 | Which storage pool for the VM disk, and how big? | *AI, closed by measurement* | ✅ **CLOSED Aug 19 — `vm-critical` (mirrored), 60 GB.** Read from VM 185's config before destroying it: OpenClaw sat on `vm-critical` at 50 GB. Jenkins holds credentials and job definitions, so the mirror is right; 60 GB because build workspaces and Docker images are what fill a CI host. |
| A7 | Registry credential for Jenkins: reuse `swarm-lab-pull` or issue a Jenkins-specific one? | *AI, as the standard* | ✅ **CLOSED** — **issue a separate one.** Shared credentials cannot be revoked independently, which is half of L12. |

✅ **A1 + A2 answered Aug 19, 2026: bookmark the IP, no TLS.** Both are reasonable for a LAN lab and
both have consequences that are now written down rather than absorbed silently:

- **No TLS** → the admin password, the session cookie, and every secret rendered into a page cross the
  LAN in cleartext, and a CI controller's session is a credential to *everything it can deploy*. That
  is ledger row **J1**, accepted knowingly. ⭐ **The value of writing it down is that the reader of the
  chapter is on an enterprise platform**, where this same choice is indefensible.
- **No DNS** → ✅ **effectively cosmetic here, and it is cosmetic for one specific reason: the address
  is static.** `.185` is pinned by cloud-init, so the IP is as stable as a name would be. What DNS buys
  is indirection, and indirection only pays when the thing behind it moves.
  ⚠️ **The single condition on which "cosmetic" depends — if that address ever changes, five things
  break at once:** Jenkins' own **Jenkins URL** setting, the GitLab **webhook URL**, the OAuth
  **redirect URI**, the **agent**'s connection back to the controller, and the bookmark. None of them
  discover the new address; each is edited by hand. **A name would make that one edit instead of five.**
  That is the whole argument for DNS, and at one static host it does not pay.
  📖 **In the chapter this is a Lab-vs-PROD *table row*, not a callout** — `CONVENTIONS.md`'s threshold
  is that a callout is earned when the lab choice would be **wrong** in production, not merely
  **smaller**. IP-vs-name is smaller. **J1 (no TLS) is wrong.** Keeping that line straight is what stops
  the callouts becoming wallpaper.

🚨 **Correction to this plan's own first wording of T8.** It was written as a consequence of choosing an
IP over a DNS name. **It is not.** GitLab blocks these requests by **resolved address**, so a hostname
resolving to `192.168.1.185` is blocked identically — DNS would not have avoided it. **T8 is a
consequence of the controller living on a private network at all**, which no naming decision changes.
The trap stands; its cause was misattributed.

### 🅑 Hard rules for this phase

| # | Rule | Why |
|---|---|---|
| B1 | 🚨 **Do not touch, disable or "clean up" the Phase 16 GitLab CI pipeline.** | It is the reference implementation we are comparing against. Andrew chose a separate stack name specifically to keep it alive. |
| B2 | 🚨 **Jenkins deploys the stack `capricorn-jenkins`, never `capricorn`.** | Two CI systems deploying one stack name means each deploy fights the other, and the comparison dies. |
| B3 | **No Jenkins secret, key or `credentials.xml` ever lands in a tracked file.** Verify with `git check-ignore`. | `push_gitlab.sh` stages ignored files too, but `push_github.sh` is what protects us — and it protects by path, so a key in a new path is a key on GitHub. |
| B4 | ⛔ **Never `echo` a credential in a pipeline step "just to check it".** | See trap T1. When we *do* do this, it is on purpose, once, inside the trap. |
| B5 | **Snapshot before every trap and every drill**, named so they sort (`j01-…`). | `METHOD.md`: the snapshot you skip is the one you need. |
| B6 | **The Jenkins admin password goes in `PASSWORDS.md` the moment it exists** — never in the phase file, never in a chapter. | `PASSWORDS.md` is gitignored; this file is not. |
| B7 | **All `vzdump` for this VM goes to the NAS** under `/ProxmoxBackups/vm-jenkins-1/`, never to NVMe. | Standing directive, `CURSOR_RULES` → BACKUP DIRECTIVE. |
| B8 | **Write to the Lab-vs-PROD ledger AT THE MOMENT the shortcut is taken**, and mark it ✅ verified or ⚠️ recited. | Phase 16 banked eight of these before anyone wrote one down. |
| B9 | **Log every diagnostic command as you run it** in `education/jenkins/COMMANDS.md`, indexed by the *question* it answers. | Reconstructing it later is archaeology — proven the hard way on the Swarm track. |

### 🅒 Planted traps — ⛔ DO NOT FIX BEFORE WE HIT THEM

**These are built in on purpose. A trap pre-empted is a lesson deleted.** Each one is a thing a real
Jenkins install gets wrong, and each is left in place until the session that trips on it. 🚨 **The AI
stays quiet while Andrew diagnoses**, per `METHOD.md` → "When something breaks".

| # | Trap | Planted how | What it should teach | Fires in |
|---|---|---|---|---|
| **T1** | **Secret masking is string matching, not taint tracking.** | Nothing to plant — it is how Jenkins works. We print a credential in a transformed form. | Jenkins redacts exact matches of a bound secret. `base64`, a substring, or a value split across lines is **not** redacted. Same class as L21's GitLab masking gap, different mechanism. | Part 2 |
| **T2** | **The agent's `docker` group membership is root on the host.** | Add the agent account to `docker` so builds can build images — the standard fix everyone applies. | `docker run -v /:/host` reads any file on the host, including `/etc/shadow` and Jenkins' own `master.key`. **The agent is not unprivileged just because it is not `root`.** | Part 4 |
| **T3** | **`JENKINS_HOME` is secret zero.** | Store the real deploy key as a Jenkins SSH credential — the correct thing to do. | `credentials.xml` + `secrets/master.key` + `secrets/hudson.util.Secret` decrypt every credential offline. **The NAS backup Andrew asked for is therefore a copy of every secret Jenkins holds.** | Part 8 |
| **T4** | **A webhook with no token means anyone who can reach Jenkins can start a build.** | Configure the GitLab webhook without a secret token first. | "The pipeline ran" is not evidence that GitLab ran it. Triggering identity ≠ triggering source. | Part 3 |
| **T5** | **The workspace persists between builds, and it holds the plaintext mirror.** | Clone `gitlab/main` — which by design contains `PASSWORDS.md`, `github_credentials.md` and `working/`. | GitLab CI got a fresh container per job; **a Jenkins agent workspace is a directory that stays.** Phase 16's open finding gets materially worse, and this one is genuinely new. | Part 3 |
| **T6** | **`sh` in a pipeline hides the exit code of anything mid-pipe.** | Write one deploy step as a pipeline (`… \| grep …`) with no `pipefail`. | The step is green because the *last* command succeeded. **A bad deployment that Jenkins calls a success.** Same shape as the k3s track's `echo`-that-failed-and-exited-0. | Part 6 |
| **T7** | **An authenticated key is not an authorised one.** | Install the pinned, keystore-held deploy key into `authorized_keys` with **no `command=` restriction**. | We will have "fixed" L21 and L22 and still be handing out a **full interactive shell** on all three managers. Authentication and authorisation are different questions, and only one of them was asked. | Part 7 |
| **T8** | **A correctly-configured webhook that silently never arrives.** ✅ **PRECONDITION VERIFIED Aug 19 — this trap CAN fire** (see log entry J-P1). | Point GitLab at `http://192.168.1.185:8080/` without touching its outbound settings. Nothing to plant — ✅ **measured on `.181`: `allow_local_requests_from_web_hooks_and_services = false` and the outbound allow-list is EMPTY.** ⚠️ **Not a DNS consequence: GitLab blocks by RESOLVED ADDRESS, so a hostname would be blocked identically.** | **The failure is at the SENDER**, and Jenkins cannot see it: no build, no error, no log entry on the receiving side. The instrument is GitLab's own webhook delivery log. ⭐ *"Nothing happened"* is a symptom with a location, and this teaches you to look at the other end of the wire. | Part 3 |

⭐ **T7 is the most important trap in the phase**, because it fires *after* we believe we have
hardened the deploy. It is the difference between a security control and the feeling of one.

### 🅓 Inherited findings — known, and out of scope

Carried in from Phase 16 so no session re-derives them or "fixes" them here:

- **The `gitlab/main` plaintext mirror is intentional.** `push_gitlab.sh` exists to put secrets there.
  Do not try to sanitise the branch — the correct move is to control what the *build* does with it
  (T5), not to break the backup.
- **`docker service ps`'s `CURRENT STATE` age is a status stamp, not the task's age.** Cost us a
  half-day invented incident on Aug 19. Read `CreatedAt` / `StartedAt` for age.
- **A stale `rollback_completed` `UpdateStatus` latch clears on the next stack deploy** — measured on
  both sides. Do not treat a stale latch as a live failure.
- **⚠️ Standing hazard, deliberately left in place:** an empty 88-byte `capricorn_redis_data_swarm`
  volume sits on `.193`. If `redis` schedules there it silently attaches an empty cache.
- **The registry token `swarm-lab-pull` expires Dec 31, 2026** and revoking it breaks future task
  reschedules silently rather than at deploy time.
- **L1 / L2 / L3 remain open** (see the charter scoping table). Not this phase.

---

## 📐🔧 The build standard, as handed to you

Every line marked 🔧 MECHANICS (rely on it) or 📐 CONVENTION (ask about it on day one).

### The host

| Item | Spec | Mark |
|---|---|---|
| Name | `vm-jenkins-1`, VMID **185**, `192.168.1.185` | 📐 |
| Base | clone of template **9000** (Ubuntu 24.04 cloud-init), then `host_setup.sh` | 📐 |
| RAM | **8 GB** — controller ~2 GB heap, agent + a Node build in the rest | 📐 |
| vCPU | **4** | 📐 |
| Disk | **≥ 60 GB** — workspaces and Docker images are what fill a build host, not Jenkins itself | 🔧 the reason, 📐 the number |
| UI | **headless, browser-accessed.** No desktop, no `xrdp`. | 🔧 — this is what a real controller is |
| Patching | added to `refresh.sh`; `unattended-upgrades` stays **masked** | 🔧 the reasoning below |
| Backup | `vzdump` → NAS storage `nas-jenkins`, `keep-last=3` | 📐 the retention, 🔧 the necessity |

⭐ **Why `unattended-upgrades` stays masked, and this is 🔧 not 📐:** automatic patching on a build
controller is an **unscheduled restart of the thing that holds your deploy path**, and it will do it
in the middle of a build. Patching a CI host is a windowed, deliberate action — which is exactly what
`refresh.sh` already is. Same reasoning already applied to the Swarm nodes. **`refresh.sh` reboots, so
it runs when the controller is idle.**

### Jenkins itself

| Item | Spec | Mark |
|---|---|---|
| Version | Jenkins **LTS**, official apt repo | 📐 (LTS over weekly is 🔧 for anything you operate) |
| Java | whatever the LTS requires — **verify, do not assume** | 🔧 |
| Executors on the controller | **0** | 🔧 — a build on the controller is a build with access to `JENKINS_HOME` |
| Agents | **one**, label `swarm-deploy` | 📐 the count and label |
| Agent transport | inbound JNLP or SSH — decided in Part 1 by what the topology needs | 🔧 |
| Auth | **local admin as break-glass**, then **GitLab OAuth** for normal use | 📐 the choice, 🔧 the break-glass principle |
| Job type | **Multibranch Pipeline** from a `Jenkinsfile` in the repo | 🔧 — pipeline-as-code is the whole point |
| Plugins | the minimum that works: Pipeline, Git, GitLab, SSH Agent, Credentials Binding, Workspace Cleanup | 📐 |

⭐ **Why a local admin survives after OAuth is wired — and this is 🔧.** Once identity comes from
GitLab, **GitLab being down means nobody can log into Jenkins**, including to deploy the fix. A
break-glass local account is not laziness; it is the reason you can still act during the incident
that took out your identity provider. We will test this by proving we can log in with GitLab
unreachable.

### The delivery path

```
GitLab (.181)                Jenkins (.185)                     Swarm (.191/.192/.193)
  repo ──webhook──▶ controller ──▶ agent ──build──▶ registry
                                        └──ssh(pinned, forced cmd)──▶ docker stack deploy
                                                                      stack: capricorn-jenkins
```

📐 The layout. 🔧 Everything about how the credential and the host key behave along it.

---

## The parts

⚠️ **Eight parts and ~10 chapters is an ESTIMATE, not a contract.** `METHOD.md`: *the schedule is an
estimate; the traps list is the contract.* Parts merge and chapters combine as the work reveals what
actually belongs together — Phase 16 planned seven parts and produced eight chapters that did not map
one-to-one. **What may not quietly shrink is Part 6 and the trap list.**

### Part 0 — the VM (🤖 AI-driven plumbing, assumed in the chapter, not re-taught)

**Step 1 ✅ DONE Aug 19, 2026, 9:1x PM. OpenClaw is destroyed and totally gone.**

Verified *before* destroying, which is why the record is accurate: VMID 185 was `vm-openclaw-1`,
stopped, **12 cores / 16 GB / 50 GB on `vm-critical`** — ⚠️ **not the 8 cores `MEMORY.md` recorded** —
with **no snapshots and no backups on any storage.** Destroyed with `qm destroy 185 --purge 1
--destroy-unreferenced-disks 1`; confirmed the config file, the ZFS volumes and
`/etc/pve/firewall/185.fw` are all gone. **No backup, by Andrew's explicit instruction.** Two side
effects found by looking rather than assuming, both corrected in `MEMORY.md`: **no VM runs Tailscale
any more**, and **only `.184` still has PVE-level firewall rules.** Full record at
[`phase11_openclaw.md`](phase11_openclaw.md) → "CLOSED".

**Remaining steps:**

2. 🅐 **A6 is now answered by measurement:** the replacement goes on **`vm-critical`** (mirrored — this
   host holds credentials and job definitions) at **60 GB**, up from OpenClaw's 50 GB because build
   workspaces and Docker images are what fill a CI host.
3. Clone template 9000 into VMID **185** as `vm-jenkins-1` at `.185`, 8 GB / 4 vCPU / 60 GB.
4. Run `host_setup.sh`; grow the disk from the template's 3.5 GB; install `qemu-guest-agent` so
   `vzdump` can fs-freeze rather than taking a crash-consistent copy; ⭐ **verify from inside the
   guest** (`df -h /`, `free -g`, `nproc`) — `qm config` reports intent, not outcome.
5. **Snapshot `j01-base-clean`.**

**Deliverable:** a clean host, **8 GB and 8 cores net back to the lab**, and the vCPU overcommit gone.

### Part 1 — install Jenkins and make the topology real (🙋 Andrew)

Install LTS, first unlock, the plugin set, controller to 0 executors, attach the agent. **Verify the
split by proving a build cannot run on the controller**, rather than by reading the executor count.

**Snapshot `j02-jenkins-up`.** Chapter 1.

### Part 2 — identity, access, and the first trap (🙋 Andrew)

Local admin → GitLab OAuth → prove break-glass works with GitLab unreachable. Then **T1**: bind a
credential and watch what Jenkins does and does not redact.

Chapter 2. Ledger rows expected here (TLS/A2, session handling).

### Part 3 — wire it to GitLab (🙋 Andrew)

Read-only deploy key, webhook, multibranch pipeline, first `Jenkinsfile` that does nothing but
checkout and print. **T4** (webhook with no token) and **T5** (the workspace that keeps the plaintext
mirror) both fire here.

**Snapshot `j03-gitlab-wired`.** Chapter 3.

### Part 4 — build and push (🙋 Andrew)

Build the Capricorn images on the agent, push to the registry with the Jenkins-specific credential
(A7). **T2** fires here: the `docker` group.

Chapter 4.

### Part 5 — reach the Swarm and deploy Capricorn (🙋 Andrew)

Get a real deploy working end to end, the straightforward way, **before** hardening anything. A working
baseline is what makes every later change measurable.

1. Jenkins reaches the three managers over SSH and runs `docker stack deploy` for
   **`capricorn-jenkins`** (rule B2).
2. Prove the app is actually serving — ⭐ **from the application's own port, not from the Swarm's
   replica count.** Phase 16's whole spine: *one instrument per question.*
3. **Implement the rigorous convergence check deferred from Phase 16** — the `.Version.Index` version
   rather than counting replicas. ⚠️ **`MEMORY.md` explicitly parks this here; it is a Phase 17
   deliverable, not an optional extra**, and Part 6 depends on it, because you cannot study a bad
   deployment with an instrument that cannot tell converged from not-converged.
4. Compare the same deploy across both CI systems — Jenkins vs the surviving Phase 16 GitLab pipeline.
   **This side-by-side is why Andrew chose a separate stack name**, and it is the phase's best
   interview material.

**Snapshot `j04-deploy-working`.** Chapter 5.

### Part 6 — ⭐ BAD DEPLOYMENTS AND HOW TO RECOVER. **This is the centre of gravity.** (🙋 Andrew)

**Andrew's stated priority: "learn about deploying and fixing bad deployments like we did in phase16
with GitLab."** Phase 16 earned that on GitLab CI; the point of doing it again here is that **Jenkins
changes the instruments, not the failures.** Jenkins reports on the *job*; the Swarm reports on the
*service*. A job that succeeded and a service that never converged is the single most common shape of
a real incident, and it is invisible if you only look at the CI system.

**Write the "what to conclude" column BEFORE running each drill** (`METHOD.md` stage 3). Snapshot
first, restore after.

| Drill | The bad deployment | What it teaches / what to conclude |
|---|---|---|
| **D1** | **Deploy a deliberately broken image** (the nginx swap that worked in Phase 16 — 🅓 inherited, known to fail loudly in ~47 s) | Does **Jenkins** report the Swarm's `rollback_started`, or its own successful `stack deploy`? Phase 16 measured **zero user-visible seconds** on this — so *the pipeline is the only place the failure is visible.* |
| **D2** | **A deploy that never converges** (an impossible placement constraint, or `max_replicas_per_node` under-provision) | The deadlock case. `3/3` while nothing is progressing. **Does the pipeline hang, time out, or pass?** This is what the Part 5 convergence check exists for. |
| **D3** | **T6 fires: a green step that deployed nothing** | The `sh` pipe swallows the real exit code. **A bad deployment Jenkins calls a success** — the worst possible combination, and the reason "the build was green" is not evidence. |
| **D4** | **Roll back vs fix forward — decide, then do both** | With the app live, which is correct and why? `docker service rollback`, a re-deploy of the previous tag, and 🅓 **the inherited digest problem: a moving tag means `rollback` may not go where you think.** |
| **D5** | **Restart Jenkins mid-deploy** | `refresh.sh`'s reboot, on purpose. Does a declarative pipeline resume? **What state is the stack left in when the deployer dies mid-flight** — and how do you even find out? |
| **D6** | **Kill the agent during a build** | What the controller reports, and **for how long it keeps reporting something untrue.** |
| **D7** | **GitLab down** | Break-glass login, webhook delivery, what Jenkins queues vs silently drops. Tests the Part 2 claim rather than asserting it. |
| **D8** | **Revoke the deploy key mid-flight** | Does it fail at deploy time where you would notice, or later and silently — the L12 latch shape from Phase 16? |

⭐ **D1–D4 are the required core** (deploy badly, detect it, recover from it). D5–D8 are the operational
half and can be trimmed if time runs short — **but the trim gets written down, not silently taken.**

**Snapshot before each drill.** Chapters 6 and 7.

### Part 7 — harden it: pay the Phase 16 charter (🙋 Andrew)

Required, and deliberately **after** the deployment work rather than before it.

1. **Close L22:** pin the managers' host keys, `StrictHostKeyChecking` at `accept-new` or stricter, and
   **prove the pin rejects a changed key** rather than asserting it does.
2. **Close L21:** the key lives in the Jenkins credential store, bound per-step, never in an env var.
3. **Partially close L12:** a Jenkins-scoped registry credential with a real expiry.
4. **The agent's privilege**, i.e. undo T2's `docker` group with the least privilege the deploy can
   actually work with.
5. **T7 fires:** the key with no `command=` restriction. **Closing it with a forced command is the
   single best story in the phase**, because it lands *after* we already believed the deploy was
   hardened.
6. **Re-run a Part 6 drill afterwards** — hardening that breaks recovery is not hardening.

**Snapshot `j05-hardened`.** Chapter 8.

### Part 8 — operate it (🙋 Andrew, then AI writes)

1. **Backup:** create NAS CIFS storage `nas-jenkins` with `--subdir /ProxmoxBackups/vm-jenkins-1`,
   `keep-last=3`. ⚠️ **Three gotchas already documented — follow them rather than rediscover them:**
   the NAS subdir **must exist first** (PVE will not create it, and cannot create it *through* its own
   storage); the `.pw` file is `password=<value>` **plus a newline**, so pass `--password` and let PVE
   write it; and `pvesm set --password` needs `--username` **in the same call** or it writes an empty
   one.
2. **T3 fires here:** decrypt a credential out of our own backup. The lesson lands hardest when the
   file is yours.
3. ⭐ **Restore test — a backup is not a recovery until it has been restored.** Restore to a throwaway
   VMID, confirm the controller comes up with credentials and jobs intact, delete it. ⚠️ **Phase 13's
   restore test found the clone kept its baked-in `.181` address**, so expect an address collision and
   document what it takes to avoid one.
4. **Patching:** add `.185` to `refresh.sh`'s allow-list; confirm `unattended-upgrades` is masked.
5. **Crib sheet** chapter, as Phase 16's chapter 8 — the one-page version worth having in an incident.
   ⭐ **Weight it toward Part 6:** what to run, in what order, when a deploy has gone bad.
6. `MAKE_MEMORIES`, and fold the framing experiment back into `METHOD.md` if it earned it.

Chapters 9 and 10 (operations, then the crib sheet).

---

## Resources, snapshots, teardown, and what is out of scope

**RAM and CPU ledger — ✅ measured, not projected.** Destroying 185 returned **16 GB and 12 cores**;
Jenkins takes **8 GB and 4 vCPU**, so the lab nets **8 GB and 8 cores**. That puts allocation at
**104 GB of 128 (81%)** and **42 of 48 threads — under-committed on CPU for the first time since the
Swarm build.** Host measured 33 GB free right after the destroy. ⚠️ **There is no dormant VM left to
harvest**; the next reclaim has to come from right-sizing something that is running.

**Snapshot chain:** `j01-base-clean` → `j02-jenkins-up` → `j03-gitlab-wired` → `j04-deploy-working` →
`j05-hardened`, plus **a snapshot before every Part 6 drill** — that part exists to break deployments,
so it is the part where rollback has to be instant. ⚠️ **The Swarm nodes are a distributed system: if a
drill changes cluster state, snapshot all three together or not at all.**

**Teardown at phase end:** the Jenkins deploy key comes out of `authorized_keys` on all three
managers, the Jenkins registry credential is revoked, and the `capricorn-jenkins` stack is removed.
Recorded now, because a phase-scoped credential that outlives its phase is how L21 happened.

### ❌ Out of scope — this is what stops one track becoming three

- **Kubernetes / k3s.** Deferred, deliberately. The firm is not there yet either.
- **Ansible.** Real and worth a phase; it is a *different plane* (OS config) from CI, and mixing them
  is how both get taught badly. **Phase 18 candidate.**
- **GitHub.** Andrew's call, Aug 19: we pull from our own GitLab and do not simulate their GitHub.
- **Shared libraries, Configuration-as-Code (JCasC), multi-agent fleets.** Natural follow-ons; not
  needed to learn how a pipeline reaches a cluster.
- **L1 / L2 / L3** from the Phase 16 ledger — registry TLS, Swarm autolock, cluster shape.
- **Anything inside Capricorn.** `CURSOR_RULES` → PROJECT SCOPE. We deploy it; we do not maintain it.

---

## 📒 Lab vs PROD ledger — Phase 17

Rows are added **at the moment the shortcut is taken** (rule B8), numbered `J1…`, and each is marked
✅ verified or ⚠️ recited. The rest stay empty until the build reaches them — writing them in advance is
how a real compromise turns into invented best practice. **J1 is here already because the decision was
taken on Aug 19, before the build, which is exactly when the honest reason was available.**

| # | Compromise | Why acceptable here | What production does | If you carry the habit | Verified? |
|---|---|---|---|---|---|
| **J1** | 🚨 **The Jenkins web UI is plain HTTP on `192.168.1.185:8080`** — no TLS, no DNS name. Andrew's decision, Aug 19, 2026. | Isolated LAN, single operator, no untrusted device on the segment, and the controller is not reachable from outside. The lab's threat model is an accident, not an adversary on the wire. | TLS terminated at the controller or an ingress in front of it, with a real certificate and HSTS; the CI controller is usually behind SSO on an internal-only hostname. | 🚨 **Every login sends the admin password in cleartext, and the session cookie that follows is a credential to EVERYTHING Jenkins can deploy** — which here means root-equivalent reach into the Swarm. ⚠️ A sniffed CI session is worse than a sniffed app session: it does not just read data, it ships code. | ⚠️ **recited** (the PROD answer is not built here) |

---

## 📓 Execution log

Entries land here as work happens, with `J-P` numbers for findings, as in Phase 16.

### J-P1 — ✅ T8's precondition VERIFIED, and an asymmetry nobody would guess (Aug 19, 2026, ~9:30 PM)

🤖 **AI-executed, read-only, at Andrew's instruction.** Reason for checking a trap's precondition
*before* the trap: **Phase 16's C2 could not fire at all** because leftover state from an earlier
investigation made the race impossible, and nobody had checked. A trap that cannot fire is a deleted
lesson that still looks planned.

Queried `application_settings` on `.181` directly:

```
allow_local_requests_from_web_hooks_and_services | allow_local_requests_from_system_hooks | outbound_local_requests_whitelist
 f                                               | t                                     | {}
```

**Three findings, in ascending order of interest:**

1. ✅ **`false` — so T8 will fire.** GitLab on `.181` will refuse to deliver a project webhook to
   `192.168.1.185`. The trap is real, not recited. ⚠️ **Stated precisely: this is the MEASURED CURRENT
   STATE of our instance, not a claim about GitLab's shipped default.** We did not verify that nobody
   changed it in an earlier phase, only what it is now — which is what Part 3 will actually hit.
2. **The outbound allow-list is EMPTY (`{}`)**, which matters when we come to fix it, because there are
   **two** fixes and they are not equivalent. The global toggle permits local requests from *every*
   webhook and integration in the instance; the allow-list permits exactly one host and port.
   ⭐ **Prefer the allow-list: the broad toggle re-opens an SSRF surface across every integration in
   GitLab to buy connectivity for one host.** ⚠️ *That preference is reasoning, not something we have
   tested — recited.*
3. ⭐ **The genuinely surprising one: the two hook types default differently.** System hooks are
   **allowed** to reach local addresses (`t`) while project webhooks are **blocked** (`f`) — on the same
   instance, same network, same target. **So "GitLab blocks outbound requests to the LAN" is false as a
   general statement.** It depends on which subsystem is asking, and a single sentence in your head
   about "GitLab's egress policy" will mispredict half the cases. This is the same shape as the Swarm
   track's recurring lesson: **the layer that reports is not always the layer that decides.**
