# Phase 17 — Jenkins: build the controller, wire it to GitLab, and deploy Capricorn *properly*

**Status:** 🔵 **IN PROGRESS — Parts 0, 1 and 2 are DONE (Aug 20, 2026). Next is Part 3.**
⚠️ **Parts 4 and 5 were SWAPPED on Aug 20 (deploy now precedes build) — read J-P7 before restoring any
earlier ordering.**
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
🙋 **HANDS-ON THROUGHOUT — INCLUDING Part 0.** Andrew runs every command; the AI explains, checks and
writes — `education/METHOD.md` → "Who does the work".
📖 **`education/CONVENTIONS.md` and `education/METHOD.md` are MANDATORY reads for this phase**, not
optional.

### 🤝 Working protocol — settled by Andrew, Aug 20, 2026, before the first command

| # | Decision | Consequence |
|---|---|---|
| **P1** | **Part 0 is hands-on but does NOT become a chapter.** | Changed from the original plan (which had it AI-driven and assumed). Andrew runs it to audit the build process; the education track still opens at the Jenkins install. **Findings go in the execution log, not a chapter.** |
| **P2** | ⭐ **Trap protocol — Andrew's own third option, better than either offered.** When a trap is about to fire the AI says *"there's a trap coming up — what do you think it could be?"* Andrew predicts and/or checks, answers, **then** we walk into it. | Keeps the diagnosis Andrew's work (METHOD.md's requirement) while beating pure silence: **a prediction made out loud before the failure is falsifiable, so the lesson lands whether he is right or wrong.** ⚠️ **The AI must not reveal the trap in the question** — the prompt names no symptom, file or component. 🧾 **Fold into `METHOD.md` if it proves out** (`CURSOR_RULES` rule 8). |
| **P3** | **Build-process improvements get fixed LIVE**, not deferred. | The Jenkins VM is built with the *improved* process, so it is the first host to benefit. ⚠️ **Cost, accepted knowingly: this VM is then no longer a clean test of what the scripts did at 12:00 today** — so each live fix is logged as it is made, or we lose the ability to say which behaviour came from where. |
| **P4** | **Session target: Part 0 + Part 1** — VM built and Jenkins reachable in a browser. | |

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
**Part 7** gives it the least privilege the deploy can actually work with — *after* Part 5's T2
deliberately over-grants it.

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
| A7 | Registry credential for Jenkins: reuse `swarm-lab-pull` or issue a Jenkins-specific one? | *AI, as the standard* | ✅ **CLOSED** — **issue a separate one.** Shared credentials cannot be revoked independently, which is half of L12. ⚠️ **AMENDED Aug 20 (A9):** it is no longer a *pull* credential. Jenkins now **pushes**, so it needs write on `lab/` and **must have no access to `production/` at all** — see B10. |
| A8 | Does Jenkins login use an external identity provider? | 🙋 **Andrew** | 🔻 **CLOSED Aug 20 — NO OAuth, ever, not "later".** Written up in **J-P6**. Auth is local accounts + matrix authorization. |
| **A9** | **Who builds the container images, and where do they go?** | 🙋 **Andrew + AI, Aug 20** | ✅ **CLOSED — the Jenkins agent builds them and pushes to a NEW GitLab group `lab`, project `capricorn-swarm`.** Reasoning below. |
| **A10** | **Where does the `Jenkinsfile` live?** | 🙋 **Andrew** | ✅ **CLOSED — `education/jenkins/Jenkinsfile`, inside `production/home-lab-setup`.** One pipeline per education track, each in its own track folder. **Not** the repo root. |
| **A11** | **Does this repo's Phase 16 `.gitlab-ci.yml` get deleted once Jenkins works?** | 🙋 **Andrew** | ✅ **CLOSED — NO. Neutered, never deleted.** See B1, now amended. |

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

### 🅐➋ A9–A11 — the delivery model, settled Aug 20, 2026 before Part 3 (see J-P7)

⭐ **Andrew's framing, and it is the reason the model changed:** *"Based on Tech/Finance industry
standards, we should try to build a system that's likely very similar to what my new job will have."*
His new firm is a **GitHub Enterprise Server** shop that stores artifacts in **Artifactory**. So the
question stopped being "what is convenient here" and became "what shape will he recognise in
September".

🔧 **The mechanic that decides it: a source host never builds anything.** GHES, like GitLab-the-server,
is a git server plus a webhook emitter plus a place to receive commit statuses. **The thing that builds
is always a runner or an agent.** So in a Jenkins shop the answer is always *the Jenkins agent builds
and pushes*, and GHES only holds the code and fires the trigger. ⚠️ **The one thing to confirm on day
one:** some shops run GitHub Actions on self-hosted runners for build/test and keep Jenkins for deploy
only. That hybrid is real and changes what the Jenkins jobs contain — **ask, do not assume.**

📐 **The approximation we are building, and why each substitution is honest:**

| Their stack (probable) | Ours | Is the swap faithful? |
|---|---|---|
| GitHub Enterprise Server | GitLab on `.181` | ✅ Both are self-hosted git + webhooks + deploy keys. The *failure modes* transfer; only the UI does not. |
| Artifactory | **GitLab Container Registry** (already running, no new VM) | ✅ Both are OCI registries behind auth. Swapping later is **a hostname and a credential**, not a redesign. |
| Ephemeral build agents | one long-lived agent on the controller's VM | ⚠️ **Not faithful — ledger rows J2 and J4.** |
| Immutable SHA tags | **immutable SHA tags** (rule B11) | ✅ Deliberately copied, because it is the single biggest hobby-vs-enterprise difference. |

⭐ **Two-pipeline promotion, not one job that does everything.** A build job produces
`lab/capricorn-swarm/<svc>:<git-sha>`; a **separate** deploy job takes a tag as a parameter and
promotes it. **The reason is rollback:** promoting an older tag is a deploy, whereas a
build-and-deploy job can only roll back by rebuilding — which is exactly what you cannot afford at
2 a.m. when the thing you need to get back to is the artifact that already worked.

🚨 **A9's dangerous half, and it is why B10 exists.** Capricorn's real pipeline pushes
`production/capricorn/<svc>:latest`, and **QA `.180` and PROD `.184` pull exactly that tag.** A Jenkins
build of Capricorn source pushing to the natural-looking path would **silently overwrite the image the
real deploys consume** — the same shape as deploying to the `capricorn` stack instead of
`capricorn-jenkins`, but worse, because it reaches PROD on the next pull rather than staying inside the
lab. ⭐ **So the separation is enforced with a token scope, not with discipline: the bad push must be a
403, not a rule someone remembers.** The registry itself will not help — it is passive, records nothing
about which CI system pushed, and GitLab pipelines behave no differently because Jenkins wrote a tag.

📌 **A10 — why the `Jenkinsfile` stays in `education/jenkins/` even though `lab/capricorn-swarm` looks
like a tidier home.** Andrew's rule is one pipeline per track, in the track's own folder, because the
education series will grow to many of them. 🔧 **Jenkins supports this natively** — every job has its
own **Script Path**, so N tracks means N `Jenkinsfile`s and nothing at the repo root. ⚠️ **GitLab does
not**: a project gets **exactly one** CI entrypoint, so if several tracks ever need GitLab pipelines the
root file has to become a thin `include:` router. **That asymmetry is itself chapter material.**
🚨 **And the load-bearing reason: moving the `Jenkinsfile` out of `home-lab-setup` would DELETE TRAP
T5**, which requires the job to clone the plaintext `gitlab/main` mirror. A refactor that quietly
removes a planted trap is precisely what section 🅒 exists to prevent.

### 🅑 Hard rules for this phase

| # | Rule | Why |
|---|---|---|
| B1 | 🚨 **Do not touch, disable or "clean up" the Phase 16 GitLab CI pipeline.** ⭐ **AMENDED Aug 20 (A11): when Andrew eventually wants it to stop firing, NEUTER it — a `workflow:` rule that matches only a manually-started pipeline — never `git rm` it.** | It is the reference implementation we are comparing against. Andrew chose a separate stack name specifically to keep it alive. **A deleted pipeline is readable in git history but cannot be RUN**, so every later claim of the form "Jenkins does this differently" becomes unfalsifiable. The control has to stay executable. |
| **B10** | 🚨🚨 **Jenkins NEVER pushes an image into `production/*`. Its registry credential is scoped to `lab/` and must have NO write access to the Capricorn project at all.** Verify by *attempting* a push to `production/capricorn` once and confirming a **403** — B8 rigour: prove the boundary, do not configure it and assume. | Capricorn's real pipeline publishes `production/capricorn/<svc>:latest` and **QA `.180` and PROD `.184` pull that exact tag.** An overwrite here does not stay in the lab; it ships to production on the next pull. **This is the highest-blast-radius mistake available in this phase.** |
| **B11** | **Every Jenkins-built image is tagged with the git SHA. Never `:latest`, never a moving tag.** The deploy job takes the tag as a **parameter**. | 🅓 Phase 16 already banked the inherited digest problem — *a moving tag means `docker service rollback` may not go where you think.* SHA tags also make collisions impossible inside `lab/`, and they are what makes D4's roll-back-vs-fix-forward drill a real decision instead of a rebuild. |
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
| **T2** | **The agent's `docker` group membership is root on the host.** | Add the agent account to `docker` so builds can build images — the standard fix everyone applies. | `docker run -v /:/host` reads any file on the host, including `/etc/shadow` and Jenkins' own `master.key`. **The agent is not unprivileged just because it is not `root`.** | **Part 5** ⚠️ *(was Part 4 — the parts were swapped Aug 20, see J-P7)* |
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
| Admin UI | **Cockpit on `:9090`**, installed by `host_setup.sh` as of Aug 20, 2026 | 📐 |
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
| Agent transport | ✅ **CLOSED Aug 20 — SSH** (controller → `127.0.0.1` as user `jenkins-agent`; needs the **SSH Build Agents** / `ssh-slaves` plugin). Ledger row **J2**. | 🔧 |
| Auth | 🔻 **REWRITTEN Aug 20 (A8).** ~~local admin as break-glass, then GitLab OAuth~~ → **local accounts + matrix authorization, no external IdP.** Break-glass is **root on the host**, not an account. | 📐 the choice, 🔧 the break-glass mechanic |
| Registry | **GitLab Container Registry**, group `lab`, project `capricorn-swarm` — standing in for Artifactory | 📐 the names, 🔧 the "an OCI registry is an OCI registry" substitution |
| Image tags | **git SHA, immutable** (rule B11) | 🔧 |
| Pipeline layout | **two jobs — build/push, then a parameterised deploy that promotes a tag** | 🔧 — this is what buys rollback |
| Job type | **Multibranch Pipeline** from a `Jenkinsfile` in the repo | 🔧 — pipeline-as-code is the whole point |
| Plugins | the minimum that works: Pipeline, Git, GitLab, SSH Agent, Credentials Binding, Workspace Cleanup — **plus SSH Build Agents (`ssh-slaves`), added Aug 20; the wizard list does not offer it and it is NOT the same plugin as "SSH Agent"** (see J-P4) | 📐 |

🚨 **CORRECTION — this section previously argued that "a local admin survives after OAuth is wired,
because GitLab being down would otherwise lock everyone out." THAT WAS WRONG on the mechanics, and it
is worth keeping the correction visible rather than deleting the claim.** Jenkins has **exactly one
security realm at a time**, so an OAuth realm *replaces* the local user database — the local admin
could not have logged in at all. **Real break-glass on any Jenkins is root on the host**: stop the
service, edit `JENKINS_HOME/config.xml`, restart. ⚠️ **Stop it FIRST — Jenkins rewrites `config.xml`
on shutdown and will erase your edit.** Full runbook and the targeted-vs-blunt distinction: **J-P6**.

### The delivery path — 🔻 REVISED Aug 20, 2026 (A9/A10)

```
production/home-lab-setup ─────┐                Jenkins (.185)
  education/jenkins/Jenkinsfile │  webhook   ┌── controller (0 executors)
  education/jenkins/manifests/  ├──────────▶ │
production/capricorn ──────────┘             └── agent  jenkins-agent-1  [swarm-deploy]
  application source (READ-ONLY deploy key)         │
                                                    │ 1. build images
                                                    ▼
                             lab/capricorn-swarm/<svc>:<git-sha>     ◀── write scope: lab/ ONLY
                             (GitLab registry, .181)                     🚨 B10: never production/*
                                                    │
                                                    │ 2. deploy job promotes a TAG (parameter)
                                                    ▼
                     ssh (pinned, forced cmd) ──▶ Swarm .191/.192/.193
                                                  stack: capricorn-jenkins   🚨 B2
```

📐 The names and the layout. 🔧 The two-job split, the SHA tags, the write-scope boundary, and
everything about how the credential and the host key behave along the path.

⚠️ **Note what does NOT appear on this diagram: `production/capricorn`'s own pipeline.** It keeps
running, keeps publishing `:latest`, and keeps deploying the real app to `.180` and `.184`. **Three
delivery paths now coexist in this lab and none of them may touch another's artifacts** — that is what
B1, B2 and B10 exist to hold apart.

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
   ⭐ **This is the first VM built since Cockpit and the `nofail` fstab fix went into the build
   scripts (Aug 20, 2026), so Part 0 doubles as their first end-to-end test.** Confirm both landed:
   `https://192.168.1.185:9090/` answers, and `systemctl show mnt-DevShare.mount -p RequiredBy`
   comes back **empty**. A headless controller is exactly the box where a second way in earns its keep.
5. **Snapshot `j01-base-clean`.**

**Deliverable:** a clean host, **8 GB and 8 cores net back to the lab**, and the vCPU overcommit gone.

### Part 1 — install Jenkins and make the topology real (🙋 Andrew) — ✅ **DONE Aug 20, 2026**

Install LTS, first unlock, the plugin set, controller to 0 executors, attach the agent. **Verify the
split by proving a build cannot run on the controller**, rather than by reading the executor count.

✅ Done and written up in **J-P3** (apt key + Java), **J-P4** (plugin set; `ssh-slaves` was missing
from the standard's own list) and **J-P5** (the split, proved with a queued build before the agent
existed). Transport settled as **SSH → `127.0.0.1` as `jenkins-agent`**, ledger row **J2** for the
co-location cost.

📖 **Chapter 1 written Aug 20** — [`education/jenkins/chapter01_the_controller_and_the_agent.md`](../education/jenkins/chapter01_the_controller_and_the_agent.md),
plus the track [`README.md`](../education/jenkins/README.md) and figure `ch01_fig1_controller_agent`
(10.2 pt on page, passes `figcheck`). Highlighted to **20.1 %** at drafting time, every prose section
18–22 %. DOCX built.

⏳ **Snapshot `j02-jenkins-up` still outstanding.**

### Part 2 — identity, access, and the first trap (🙋 Andrew) — 🔻 **RESHAPED + DONE Aug 20, 2026**

~~Local admin → GitLab OAuth → prove break-glass works with GitLab unreachable.~~ ⛔ **OAuth dropped
(decision A8)** — Andrew's firm uses GitHub, and coupling Jenkins login to GitLab would have put an
instrument inside the system Part 6 exists to break. Replaced with **matrix authorization + a
deliberate lockout attempt**, which failed to lock us out and taught more for it. Written up as
**J-P6**, including the ⚠️ **unrehearsed** break-glass runbook and the targeted-vs-blunt recovery
distinction.

⏳ **Still owed from Part 2: T1** — bind a credential and watch what Jenkins does and does not redact.
It was always the part of Part 2 about *deployment safety* rather than identity, and it needs a
pipeline to fire in, so **it moves into Part 3** where the first `Jenkinsfile` appears.

Chapter 2. Ledger rows expected here (TLS/A2, session handling).

### Part 3 — wire it to GitLab (🙋 Andrew)

Read-only deploy key, webhook, multibranch pipeline pointed at **Script Path
`education/jenkins/Jenkinsfile`** (A10), and a first `Jenkinsfile` that does nothing but checkout and
print. **T4** (webhook with no token), **T5** (the workspace that keeps the plaintext mirror) and
**T8** (the webhook GitLab refuses to send — precondition ✅ verified in J-P1) all fire here, plus
**T1**, moved down from Part 2 because credential masking needs a pipeline to fire in.

**Snapshot `j03-gitlab-wired`.** Chapter 3.

### Part 4 — reach the Swarm and deploy Capricorn (🙋 Andrew) — 🔻 **MOVED AHEAD OF BUILD, Aug 20**

⚠️ **This part and the next were SWAPPED on Aug 20, 2026 (J-P7). Do not restore the original order
without reading why.** Build-and-push used to come first. It now comes second, because **Part 4's
whole payoff is the side-by-side against the Phase 16 GitLab pipeline, and that comparison is only
valid while both systems deploy the SAME artifacts.** If Jenkins were already building its own
SHA-tagged images, the two pipelines would be shipping different bytes and any difference in outcome
would have two candidate causes. ⭐ *One instrument per question*, applied to the experiment itself.

So Part 4 deploys **the existing `production/capricorn/*:latest` images** — the identical inputs
Phase 16 used — and changes exactly one variable: the CI system.

1. Jenkins reaches the three managers over SSH and runs `docker stack deploy` for
   **`capricorn-jenkins`** (rule B2).
2. ⭐ **Reuse `education/docker-swarm/scripts/deploy_swarm.sh` UNCHANGED**, passing
   `STACK=capricorn-jenkins`. The script is already fully parameterised (`STACK="${STACK:-capricorn}"`,
   `STACK_FILE`, `REGISTRY`, all the `SMOKE_*` knobs), so **nothing needs to be written or copied.**
   🚨 **This is the control.** Phase 16's finding **P38** measured that the GitLab wrapper contributed
   *zero* deploy logic — the script did all of it. Holding the script byte-identical across both
   pipelines is what makes "Jenkins behaves differently here" a statement about Jenkins.
   ⚠️ **Expect a loud `==> NON-DEFAULT STACK FILE` banner on every run.** The script prints it whenever
   `STACK_FILE` is overridden, which we do deliberately every time. **It is the script asserting the
   override was intentional — not a fault, and not something to silence.**
3. 🚨 **A new manifest IS required, and for a mechanical reason rather than tidiness.**
   `capricorn.stack.yml` publishes **5001** (frontend) and **5002** (backend) in `mode: ingress`, and
   **two stacks cannot publish the same ingress ports on one Swarm.** So
   `education/jenkins/manifests/capricorn-jenkins.stack.yml` gets **5011/5012**. ✅ Named volumes and
   the overlay network are already namespaced per stack, so those do not collide — **ports are the
   only conflict.**
4. Prove the app is actually serving — ⭐ **from the application's own port, not from the Swarm's
   replica count.** Phase 16's whole spine: *one instrument per question.*
5. **Implement the rigorous convergence check deferred from Phase 16** — the `.Version.Index` version
   rather than counting replicas. ⚠️ **`MEMORY.md` explicitly parks this here; it is a Phase 17
   deliverable, not an optional extra**, and Part 6 depends on it, because you cannot study a bad
   deployment with an instrument that cannot tell converged from not-converged.
6. Compare the same deploy across both CI systems — Jenkins vs the surviving Phase 16 GitLab pipeline.
   **This side-by-side is why Andrew chose a separate stack name**, and it is the phase's best
   interview material.

📖 **Expected finding, to be written up rather than assumed:** `education/jenkins/` should end up with
`manifests/` and chapters and **nothing at all in `scripts/`**. If we find ourselves writing a
Jenkins-flavoured deploy script, that is a signal we have started re-implementing rather than
comparing.

**Snapshot `j04-deploy-working`.** Chapter 4.

### Part 5 — build and push (🙋 Andrew) — 🔻 **MOVED AFTER DEPLOY, Aug 20**

Only now does Jenkins start producing its own artifacts, which is also when the lab stops being a
copy of Phase 16 and starts being the shape of Andrew's next job (A9).

1. **Create the GitLab group `lab` and the project `lab/capricorn-swarm`**, with a Jenkins token
   scoped to write there and **nowhere else**.
2. 🚨 **Prove B10 before trusting it:** attempt one push to `production/capricorn` and confirm a
   **403**. A scope you have not tested is a scope you are reciting.
3. Build the Capricorn images on the agent from a **read-only** clone of `production/capricorn`, tag
   them with the **git SHA** (B11), push to `lab/capricorn-swarm`.
4. Split the pipeline in two: a build job, and a **parameterised deploy job that promotes a tag**.
   Re-point the Part 4 deploy at the new tag and confirm the app still serves.
5. Set a **registry cleanup policy** on `lab/capricorn-swarm` — SHA tags accumulate forever and the
   registry's disk lives on the GitLab VM at `.181`, which also holds the nightly 14 GB backup.
6. **T2 fires here:** adding the agent to the `docker` group is the standard fix for "the build cannot
   reach the socket", and it is equivalent to granting root on the controller's own VM.

Chapter 5.

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
| **D2** | **A deploy that never converges** (an impossible placement constraint, or `max_replicas_per_node` under-provision) | The deadlock case. `3/3` while nothing is progressing. **Does the pipeline hang, time out, or pass?** This is what the **Part 4** convergence check exists for. |
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
   - ✅ **Working recipe for the subdir, proven end-to-end Aug 20, 2026** (built for VM 180, then torn
     down — see below) — mount the *parent* by hand, `mkdir`, unmount, then add the storage:
     ```bash
     mkdir -p /tmp/nasroot
     mount -t cifs //192.168.1.120/NeoCortex/ProxmoxBackups /tmp/nasroot \
       -o username=fiberoptix,password='<the 9-char password from PASSWORDS.md>'
     mkdir -p /tmp/nasroot/vm-jenkins-1 && umount /tmp/nasroot && rmdir /tmp/nasroot
     ```
     🚨 **Type the real password — do NOT feed it `$(cat /etc/pve/priv/storage/<id>.pw)`.** That file
     is `password=<value>`, so you would send the literal string `password=…` and get
     **`mount error(13) Permission denied`**, which looks exactly like a NAS permissions problem and
     is not. **Two separate sessions have now lost time to this.** ⚠️ **Stop after 3–4 failed
     attempts** — Synology-style auto-block trips near five and would blackhole the Proxmox host's IP,
     taking out the nightly GitLab backup and every guest's `/mnt/DevShare`.
   - ⚠️ **Stagger the schedule.** `gitlab-nightly` is the only other job (02:00, ~14 GB), so **give
     Jenkins 03:00.** And note **a defined storage is not a scheduled job** — read `/etc/pve/jobs.cfg`
     for real coverage, not `pvesm status`.
   - 📊 **Expect roughly 10 GB / ~2.5 min** for a 60–100 GB disk with ~15 GB used; vzdump
     sparse-skips zeros, so size tracks *used* data.
   - 🎯 **Be ready to justify why Jenkins gets a backup when QA does not.** Andrew removed VM 180's
     backup on Aug 20 with the rule *QA is rebuilt by CI, so it is a deploy target, not a data store.*
     **Jenkins is the opposite case and that is the whole point of B7:** `JENKINS_HOME` holds
     credentials, job history and `master.key` — **state no pipeline can regenerate.** ⭐ The lesson
     for the chapter is the *test*, not the list: **back up what cannot be rebuilt.**
   - ⚠️ **Teardown gotcha if a backup storage ever has to be removed:** `pvesm free` clears the
     archive but PVE's `dump/` subdir remains, and the **CIFS dentry cache misreports it** —
     `rm -rf` fails *"Directory not empty"* while `stat` says it does not exist. **A fresh mount with
     `noserverino` clears it.** Recorded in `proxmox/Home_Lab_Proxmox_Storage.md`.
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
- **GitHub.** Andrew's call, Aug 19, reaffirmed Aug 20: we pull from our own GitLab and do not simulate
  their GitHub. ⭐ **Cheap to say why it costs nothing:** GHES and GitLab play the *same architectural
  role* — a git server that emits webhooks and holds deploy keys, with **no build capacity of its own**
  (J-P7). What transfers is the pipeline shape and the failure modes; only the UI differs. **Andrew
  learns their GitHub at the firm next month** — his call, and the right one.
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
| **J4** | **One long-lived build agent, reused by every build.** Workspaces persist, `~/.docker/config.json` persists, and once Part 5 grants the `docker` group the local image cache and the registry push credential persist too. Decided Aug 20, 2026 with A9. | It is the only agent the lab has, and its persistence is *load-bearing for the teaching* — **trap T5 exists precisely because the workspace survives between builds**, which is the concrete difference from Phase 16's fresh-container-per-job runner. | **Ephemeral agents: a fresh container or VM per build**, destroyed afterwards, via the Kubernetes or Docker plugins. The credential is injected for the life of one build and dies with it. | 🚨 **A persistent agent that can push to a registry ACCUMULATES secrets and build residue**, so a single compromised build contaminates every later one. ⚠️ **Do not carry the assumption that a clean `git checkout` means a clean workspace** — it does not remove untracked files unless you make it. | ⚠️ **recited** (no ephemeral agent is built here) |
| **J3** | **The GitLab Container Registry stands in for Artifactory**, and it runs on `.181` — **the same VM as the git server**, over plain HTTP (🅓 inherited L1). Decided Aug 20, 2026 (A9). | Andrew's firm uses Artifactory, but **both are OCI registries behind auth**, so the pipeline mechanics — login, tag, push, pull-on-deploy, cleanup policy — are identical. Standing one up on its own VM would have cost a VM and taught nothing new. ✅ **The swap is a hostname and a credential.** | A dedicated artifact store on its own infrastructure (Artifactory, Harbor, Nexus, ECR/ACR), TLS everywhere, with retention, vulnerability scanning and provenance/signing attached to it. | ⚠️ **Co-locating the registry with the git server means one VM failure takes out BOTH your source of truth and every artifact you would rebuild it from** — and `.181` also holds the only nightly backup job. ⚠️ Also: **no image scanning and no signing anywhere in this pipeline.** A firm in finance will have both, and they are the two things this lab most conspicuously lacks. | ⚠️ **recited** (the PROD answer is not built here) |
| **J2** | **The build agent is the controller's own VM.** Jenkins SSHes to `127.0.0.1` as a separate `jenkins-agent` OS user, so the *privilege* boundary is real (different UID, kernel-enforced, cannot read `JENKINS_HOME/secrets/`) but the *isolation* boundary is not: same kernel, same disk, same 4 vCPU / 8 GB. Decided Aug 20, 2026 in Part 1. | One VM's worth of RAM was what the fleet had spare, and the Jenkins-side configuration is byte-for-byte what a remote host would need — only the hostname field differs. Nothing in Parts 1–6 depends on the hosts being distinct. | Agents live on their own hosts, precisely so that whatever privilege a build needs in order to build images does **not** land on the machine holding every credential the CI system owns. Firms with a dozen static build hosts SSH-launch them individually; ephemeral fleets use the Kubernetes/Docker plugins and get a fresh, disposable agent per build. | ⚠️ **The co-location makes the agent's privilege sharper here than in production, not softer** — the host it can reach is the controller. Also: a build that fills the disk or pins the CPU takes the controller down with it, so "the agent is unhealthy" and "Jenkins is unhealthy" are the same event in this lab and are two different events at a firm. Do not carry the reassurance that a compromised agent is contained. | ⚠️ **recited** (a second agent host is not built here) |
| **J1** | 🚨 **The Jenkins web UI is plain HTTP on `192.168.1.185:8080`** — no TLS, no DNS name. Andrew's decision, Aug 19, 2026. | Isolated LAN, single operator, no untrusted device on the segment, and the controller is not reachable from outside. The lab's threat model is an accident, not an adversary on the wire. | TLS terminated at the controller or an ingress in front of it, with a real certificate and HSTS; the CI controller is usually behind SSO on an internal-only hostname. | 🚨 **Every login sends the admin password in cleartext, and the session cookie that follows is a credential to EVERYTHING Jenkins can deploy** — which here means root-equivalent reach into the Swarm. ⚠️ A sniffed CI session is worse than a sniffed app session: it does not just read data, it ships code. | ⚠️ **recited** (the PROD answer is not built here) |

---

## 📓 Execution log

Entries land here as work happens, with `J-P` numbers for findings, as in Phase 16.

### J-P7 — 🔻 THE DELIVERY MODEL REPLANNED, before a single Part 3 command (Aug 20, 2026, ~4:00–4:35 PM)

🗣️ **Discussion only — nothing was built.** It began as a narrow question (*"do the pipeline files go
in `/jenkins` or in the repo root?"*) and ended up **swapping two parts and adding three hard rules**,
which is the argument for having the conversation before the deploy key rather than after the first
green build.

**What Andrew corrected, and it was the load-bearing correction:** the AI had been treating this as a
two-way comparison. It is **three-way**. `production/capricorn` has its own pipeline deploying the real
application to QA `.180` and PROD `.184`; this repo's `.gitlab-ci.yml` is the Phase 16 *exercise*;
Jenkins is a third. **Only after that was said out loud did the registry-overwrite hazard (B10) become
visible** — it is invisible if you think there are only two systems.

| Decision | Outcome |
|---|---|
| **A9** — who builds, where images go | Jenkins agent builds; images to **`lab/capricorn-swarm`** (new group), **never** `production/*` |
| **A10** — `Jenkinsfile` location | `education/jenkins/Jenkinsfile`, one per track, **not** the repo root |
| **A11** — this repo's `.gitlab-ci.yml` | **Neuter it eventually, never delete it** — B1 amended |
| **Part order** | **Parts 4 and 5 SWAPPED**: deploy first, build second |
| **New rules** | **B10** (registry write scope), **B11** (SHA tags), ledger **J3** and **J4** |

⭐ **Finding 1 — a source host never builds anything, and that answers the GHES question cleanly.**
Andrew asked whether GitHub Enterprise Server or the Jenkins agents build the containers at his new
job. **Neither half of the question is quite right: GHES has no build capacity at all.** It is a git
server, a webhook emitter and a place to receive commit statuses — architecturally the same role
GitLab-the-server plays next to GitLab Runner. **In a Jenkins shop the agents always build.**
⚠️ **The one genuine uncertainty to resolve on day one:** GitHub Actions on self-hosted runners for
build/test, with Jenkins kept for deploy only, is a real and common hybrid.

⭐ **Finding 2 — the reason to move deploy ahead of build is experimental, not logistical.**
Part 4 exists to compare Jenkins against the surviving Phase 16 pipeline. Phase 16's **P38** already
measured that the GitLab wrapper added **zero** deploy logic. So if Jenkins runs the *same*
`deploy_swarm.sh` against the *same* `:latest` images, the CI system is the only variable and the
comparison means something. Build first, and the two pipelines ship different bytes.
🧠 **This is *one instrument per question* applied to the experimental design rather than to a
diagnosis** — a new use of the phase's own spine, and worth noticing as such.

⭐ **Finding 3 — `deploy_swarm.sh` needs no changes at all, and the manifest needs one for a hard
mechanical reason.** Read rather than assumed: the script is already parameterised
(`STACK="${STACK:-capricorn}"` plus `STACK_FILE`, `REGISTRY`, `SMOKE_*`), so Jenkins reuses it
verbatim. But `capricorn.stack.yml` publishes **5001/5002 in `mode: ingress`**, and **two stacks cannot
publish the same ingress ports**, so a separate manifest at 5011/5012 is *required* — not a
housekeeping preference. ✅ Volumes and the overlay network are namespaced per stack; **ports are the
only collision.** The prediction to test in Part 4: `education/jenkins/scripts/` should stay **empty**.

🚨 **Finding 4 — the highest-blast-radius mistake in the phase was one obvious step away.** Building
Capricorn source and pushing to the natural-looking path would overwrite
`production/capricorn/<svc>:latest`, **which QA and PROD pull.** The lab would have shipped to
production. ⭐ **The fix is a token scope, not a rule** — B10 requires *demonstrating* the 403 rather
than configuring the scope and believing it. ✅ Confirmed harmless in the other direction: the registry
is passive, records nothing about who pushed, and GitLab pipelines are unaffected by Jenkins writing
tags. **The danger was never "confusing GitLab"; it was overwriting a tag.**

⭐ **Finding 5 — Jenkins and GitLab differ on per-track pipelines, and it is a real asymmetry.**
Jenkins gives **every job its own Script Path**, so N tracks means N `Jenkinsfile`s in N folders.
**GitLab allows exactly one CI entrypoint per project**, so the same layout would need the root file
to become an `include:` router. Andrew's "one pipeline per track folder" rule is therefore *natively*
supported by one tool and *worked around* in the other.

🚨 **And the near-miss worth recording: A10 was nearly decided on aesthetics, and it would have
deleted a planted trap.** Moving the `Jenkinsfile` into `lab/capricorn-swarm` looked tidier, but **T5
requires the job to clone the plaintext `gitlab/main` mirror**, so the refactor would have removed the
trap without anyone noticing it was gone. ⭐ **A trap deleted by a refactor leaves no error — the plan
still lists it, and a future session ticks it off having never been able to hit it.** Section 🅒 says
do not *fix* a trap early; this adds: **check whether a structural change silently disarms one.**
📌 Phase 16's **C2 could not fire and nobody had checked** — same failure, different cause.

**Andrew's standing policy, set in the same conversation:** **Jenkins runs the education pipelines;
GitLab CI runs the real applications.** Rationale in his words — *"that way we do not pollute our real
GitLab environment."* ⚠️ **This does NOT make Jenkins GitLab-free**, and the distinction matters for
Part 6: Jenkins still clones from GitLab and is still triggered by a GitLab webhook. The boundary is
drawn at the **pipeline engine**, not at GitLab. **T1/T4/T5/T8 all live on the surviving link.**

### J-P6 — 🔻 PART 2 RESHAPED: OAuth dropped, and the lockout drill that could not fire (Aug 20, 2026, ~3:30–3:45 PM)

**🅐 A8 — CLOSED by Andrew: no OAuth in this lab.** Two reasons, and the second is the stronger one:

1. **His firm uses GitHub, not GitLab.** GitLab's app-registration flow and its group-mapping
   semantics transfer to nothing he will touch. What *does* transfer is the Jenkins mechanic — one
   realm, no form fallback, filesystem recovery — and that is learnable without any IdP.
2. 🚨 **Coupling Jenkins login to GitLab during a phase whose Part 6 deliberately breaks the
   Jenkins↔GitLab path violates *one instrument per question*.** A failed drill would have had two
   candidate causes, and one of them would have locked us out of the instrument.

⭐ **Worth keeping as a planning lesson: the transferable part of an integration is usually the
FAILURE MODE, not the vendor.** Re-pointing the identity provider cost nothing because the lesson was
never about GitLab.

**What replaced it: try to lock yourself out on purpose. It did not work, twice, and that is the finding.**

📌 **Third name collision in two days** — `matrix-project` (already installed; multi-configuration
*jobs*) is not **`matrix-auth`** (Matrix Authorization Strategy). After `ssh-agent`/`ssh-slaves` and
`gitlab-plugin`/`gitlab-oauth`, **assume any Jenkins plugin name is ambiguous until you have checked
the short name.**

| Attempt | Expected | Observed |
|---|---|---|
| Switch to Matrix-based security, grant only `authenticated: Overall/Read` | locked out | ✅ still admin — **the plugin had pre-seeded `USER:…Administer:agamache`**, which Andrew did not add |
| Delete the `agamache` row in the UI and save | locked out | ✅ still admin — the row **came back** |

🚨 **How the second refusal presents is the phase's spine appearing inside a safety feature.** The
form accepted the deletion and showed the row gone. The save **succeeded and genuinely rewrote the
file** (`config.xml` mtime `15:40:13`). The permission was still there afterwards. And there was **no
warning in the UI and no line in `journalctl -u jenkins`.** Three layers reported success at
something that never happened. ⭐ **A benevolent silent override is still a silent override — anyone
trying to learn their own permission model from that screen was just misinformed by it.**

✅ **Intentional, and documented.** matrix-auth's README: *"It is not possible to remove access …
from Jenkins administrators."* Jenkins' Jira carries an epic named **"Matrix Auth: Accidental
lockouts"** (JENKINS-10871, JENKINS-46832 — both **Resolved**).

⚠️ **So the folklore is stale, and the real lockout moved.** Current reports of matrix-auth lockouts
are **plugin-upgrade incompatibilities** — matrix-auth 3.0 changed its SID format, `role-strategy`
was not yet compatible, and admins lost their own rights *on restart*. **You can no longer lock
yourself out by clicking; you can still do it by upgrading.** That lands directly on **J-P4**: 73
plugins from 6 choices, and the 67 you did not pick are the ones whose interdependencies you cannot
enumerate.

✅ **Banked anyway: authorization is now real.** `agamache → Overall/Administer`,
`authenticated → Overall/Read`. This closes the wizard default flagged in Chapter 1 §2 — it is no
longer true that anyone who authenticates has full control of the deploy path.

#### 📕 BREAK-GLASS RUNBOOK — ⚠️ **WRITTEN, NOT REHEARSED** (Andrew chose to record and move to Part 3)

🚨 **Recorded as `⚠️ recited`, not `✅ verified`.** Nobody has run this on `.185`. Treat it as a
starting point under pressure, not as a proven procedure — that distinction is exactly what the
Lab-vs-PROD ledger exists to keep honest.

```bash
sudo cp -a /var/lib/jenkins/config.xml /var/lib/jenkins/config.xml.known-good
sudo systemctl stop jenkins     # ⚠️ MUST be first: Jenkins rewrites config.xml on shutdown and will erase your edit
# ... edit /var/lib/jenkins/config.xml ...
sudo systemctl start jenkins
```

⭐ **Choose the SMALLEST fix that matches what is actually broken:**

| What broke | Fix | Exposure while you work |
|---|---|---|
| **Authorization only** (matrix misconfigured, rights removed) | replace the `<authorizationStrategy>` block with `FullControlOnceLoggedInAuthorizationStrategy` | **none — login still required** |
| **The realm** (IdP dead, LDAP unreachable, plugin broken) | the recited recipe: `<useSecurity>false</useSecurity>` + delete `<securityRealm>` *and* `<authorizationStrategy>` | 🚨 **Jenkins fully unauthenticated, on plain HTTP, until you finish** |

🚨 **Every guide on the internet gives you the second one.** It works for both cases, which is why it
propagates, and on this box it would hand out unauthenticated admin over cleartext HTTP for the
duration. **Same shape as Phase 16's `docker swarm leave --force`: the universally-recommended
remediation is more destructive than the situation requires.** Diagnose which layer failed *before*
picking the tool.

⭐ **And the deeper point about break-glass on Jenkins:** it is **root on the host**, not an account.
So the set of people who can recover Jenkins from an auth failure is exactly the set who can already
read `JENKINS_HOME` — the **J-P5** boundary arrived at from the opposite direction.

### J-P5 — ✅ PART 1 DONE: the controller/agent split, proved rather than configured (Aug 20, 2026, ~1:55–2:10 PM)

🙋 **Andrew ran every command.** End state: controller `0` executors and online, node
`jenkins-agent-1` online, `2` executors, label `swarm-deploy`, launched over SSH to `127.0.0.1` as OS
user `jenkins-agent`.

⭐ **The method is the finding: prove the negative before you build the positive.**

1. Controller executors → `0`.
2. Create a throwaway freestyle job `zz-executor-proof` and run it **with no agent yet.** It parks in
   the Build Queue and never starts.
3. *Then* install `ssh-slaves`, create the account, attach the node.
4. Run **the same job again, unchanged.** It runs:
   `Building remotely on jenkins-agent-1 (swarm-deploy) in workspace /home/jenkins-agent/agent/workspace/...`

Reading `0` in a config field tells you what Jenkins was *told*. A job stuck in the queue tells you
what Jenkins will *do*. Steps 2 and 4 are the same job with different infrastructure, so the change
in outcome has exactly one possible cause. **The queued build is the evidence; the config field is
only a claim.**

**Account created with nothing:**

```bash
sudo useradd -m -d /home/jenkins-agent -s /bin/bash jenkins-agent   # password locked by default
```

`uid=1001(jenkins-agent) groups=1001(jenkins-agent)` — no sudo, no supplementary groups. Whatever it
later needs must be granted for a stated reason, not inherited from a convenient creation command.

**The key lives in one place only.** Generated on the host, public half into `authorized_keys`,
private half pasted into the Jenkins credential store, then **deleted from the host** — after which
`/home/jenkins-agent/.ssh/` holds `authorized_keys` and nothing else. Host key **pinned** via
*Manually provided key Verification Strategy* rather than "Non verifying", which pays off Phase 16's
**L21** instead of reciting it.

**The boundary is kernel-enforced, and was tested, not assumed:**

```
$ ps -o user:14,pid,cmd -C java
jenkins        10793  /usr/bin/java ... -jar /usr/share/java/jenkins.war --httpPort=8080
jenkins-agent  11507  java -jar remoting.jar

$ sudo -u jenkins-agent cat /var/lib/jenkins/secrets/master.key
  permission denied
```

⚠️ **But the agent CAN read most of `JENKINS_HOME`, and the protection is exactly one directory deep.**

| Path | Mode | Agent can read? |
|---|---|---|
| `/var/lib/jenkins/` | `755` | yes |
| `config.xml`, `secret.key`, `credentials.xml` | `644` | **yes** — including the new SSH credential as `{AQAAABAA…}` ciphertext |
| `identity.key.enc` | `600` | no |
| `secrets/` (holds `master.key`, `hudson.util.Secret`) | `700` | **no** |

So the ciphertext is world-readable to every local account and only the key material is protected —
by a single directory's mode bits, with nothing behind it. `master.key` is itself `644`; it is safe
solely because of the `700` on its parent. **One layer, not two.**

🚨 **Two privilege planes, and hardening one says nothing about the other.** The build log opened with
`Running as SYSTEM` while the OS process ran as unprivileged `jenkins-agent`. `SYSTEM` is Jenkins'
full-permission *internal* identity, so a pipeline can act through Jenkins' own APIs in ways the Unix
account could never act directly. Relevant to Part 7: an "unprivileged agent" is a statement about
one plane only.

### J-P4 — 🔧 The wizard's "minimum" is 73 plugins, and one of them is not the plugin you think (Aug 20, 2026, ~1:45 PM)

Andrew took **"Select plugins to install"** over "Install suggested", and picked exactly the six the
build standard names. Verified afterwards against the API rather than the screen:

```bash
curl -s -u <user>:<pass> http://192.168.1.185:8080/pluginManager/api/json?depth=1
```

All six are present — `workflow-aggregator`, `git`, `gitlab-plugin`, `ssh-agent`,
`credentials-binding`, `ws-cleanup`. **GitLab and SSH Agent DID appear in the wizard's curated list**,
which the plan had flagged as uncertain; no post-install hunting was needed.

⭐ **But the total is 73 plugins, not 6.** The other 67 are transitive dependencies the wizard resolved
silently. The honest claim for a "minimal" install is therefore **minimal in deliberate decisions, not
in installed artifacts** — the difference from "suggested" is real (you can name why each of your six
is there) but it is not a smaller attack surface by two-thirds, and saying so would be a lie a chapter
would carry.

🚨 **"SSH Agent" is not the plugin that launches agents over SSH.** Two plugins with near-identical
names doing unrelated jobs:

| Plugin | Short name | What it actually does |
|---|---|---|
| **SSH Agent** | `ssh-agent` | the `sshagent { }` **pipeline step** — forwards a key *into* a running build so the build can `git clone` / `scp` |
| **SSH Build Agents** | `ssh-slaves` | **launches an agent** by SSHing to a host, copying `remoting.jar`, and running it |

The wizard offered the first and not the second, and the build standard's plugin list named only the
first — so following the standard to the letter left the controller **unable to attach the SSH agent
the same standard requires**. Caught before it cost anything, by checking the installed short names
against what the Part 1 task actually needs. **Generalizable: a plugin list is not a capability list.**

### J-P3 — 🔧 Two ways the Jenkins apt install misleads you (Aug 20, 2026, ~1:28–1:35 PM)

Both found by **verifying instead of reciting**, which is the A3/Java line of the build standard doing
its job. Both are 🔧 MECHANICS.

**1. The signing key you will be told to use is EXPIRED, and the "obvious" one is worse.**
`apt update` failed with `NO_PUBKEY 7198F4B714ABFC68`. The downloaded key was **valid, correctly
placed, correctly permissioned — and the wrong key.**

| URL | Key ID | State |
|---|---|---|
| `jenkins.io.key` — the unversioned, "default-looking" name | `FCEF32E745F2C3D5` | **expired 2023-03-30** |
| `jenkins.io-2023.key` — what nearly every guide still says | `…5BA31D57EF5975CA` | **expired 2026-03-26** |
| **`jenkins.io-2026.key`** | **`7198F4B714ABFC68`** | ✅ current, expires 2028-12-21 |

⭐ **The unversioned filename is the OLDEST**, dead three years. And the failure is quiet: `wget`
returns 0, the file *is* a real PGP key, nothing looks wrong until apt refuses the repo.
⭐ **The verification loop that settles it: apt names the key ID it wants in the `NO_PUBKEY` line —
match that against `gpg --show-keys` on what you installed. Never trust the filename.**
⚠️ **Any host built between Mar 26 and Aug 20, 2026 following the standard instructions hits this.**
📌 **Diarise: `7198F4B714ABFC68` expires 2028-12-21**, and when it does, `apt update` breaks silently
on every host holding it. Part 8 material.

**2. 🚨 The `jenkins` package DOES NOT DEPEND ON JAVA, and the version everyone quotes is now wrong.**

```
Version: 2.568.2
Depends: adduser, lsb-base (>= 3.2-14), net-tools, sysvinit-utils (>= 2.88dsf-50)
```

No Java in `Depends`, **and none in `Recommends` or `Suggests` either** — checked. Watch it vanish in
the version history: `≤ 2.107` declared `default-jre-headless (>= 2:1.8) | java8-runtime-headless`;
from ~`2.332` onward it is simply gone. **So `apt-get install jenkins` succeeds and the service then
fails to start.** ⭐ **The package metadata under-declares its own hard requirement**, which means
"verify with `Depends`" — the technique the build standard asked for — *cannot answer this question
either*. The authority is Jenkins' Java Support Policy page, not the package.

⚠️ **And the recited answer is stale.** "Jenkins needs Java 17 or 21" is everywhere and is **wrong for
2.568.2**:

| Supported Java | From LTS |
|---|---|
| Java 17, 21, or 25 | 2.541.1 (Jan 2026) |
| **Java 21 or Java 25** | **2.555.1 (Apr 2026)** ← our 2.568.2 is past this |

Jenkins: *"If you install an unsupported Java version, your Jenkins controller will not run."*
**Chose `openjdk-21-jre-headless`** — supported *and* the one Jenkins says it full-tests. (Their page
is mildly self-contradictory: the test-flow paragraph still names 17, which their own table rules out
for our version. **The support table is normative; the prose is stale.**)

🧠 **The transferable lesson, and it is the phase's spine again:** *the layer that reports is not the
layer that decides.* Here **three** sources disagreed — the filename, the package metadata, and the
documentation prose — and only one of each pair was authoritative.

### J-P2 — Part 0: the VM, and three findings the build audit paid for (Aug 20, 2026, ~1:00–1:20 PM)

🙋 **Andrew ran every command** (protocol P1). VM 185 `vm-jenkins-1` is up at `.185`: 4 vCPU, 8 GB,
58 G usable, `onboot 1` + `startup order=4`, zero failed units.

**Clone notes worth keeping:**
- `--full --storage vm-critical` moved **both** volumes — `scsi0` *and* the cloud-init drive. Nothing
  stranded on `vm-ephemeral`.
- ⭐ **The clone got a fresh `smbios1` UUID, and that UUID is cloud-init's instance identity.** Because
  it changed, first boot was treated as a new instance, so the hostname (from `--name`) and the static
  IP were actually applied. **This is the precise difference from yesterday's QA clone**, which had no
  cloud-init drive at all and therefore carried `.180` baked into the guest's netplan — hence the
  hostname surgery and the IP-collision hazard there. *Template clone = personalised; live-VM clone =
  duplicated.*
- ⭐ **First SSH failed on a host-key mismatch, and the reason generalises:** `.185` is a **reused
  address** (OpenClaw lived there), and a template clone generates **new** host keys on first boot.
  Yesterday's clone-of-a-running-VM *kept* its host keys, so `.180` needed no `known_hosts` edit.
  **Same word "clone", opposite outcome.**
- ✅ `growpart` fired — `df -h /` shows 58 G, so the filesystem followed the virtual disk. Verified from
  inside the guest, per the standing rule.
- **Interface is `eth0`**, while `.180`/`.184` use `ens18` — confirms the fleet is *not* uniform here.

**✅ First end-to-end test of both build-script changes made earlier today — both passed on a real
build, not a simulation:**
- **Cockpit:** socket enabled, listening on 9090, 5 packages, **`network-manager` count = 0**, NM
  inactive. The refuse-if-NetworkManager guard held on a genuine install.
- **`nofail`:** written automatically; `RequiredBy=[]`, `WantedBy=[remote-fs.target]`, mounted.

#### 🚨 Finding 1 — the NAS password was being served over unauthenticated HTTP

`http://192.168.1.195/scripts/smb_credentials` returned **HTTP 200 to anyone on the LAN**, and the
`autoindex` directory listing advertised it by name. ✅ The file **is** gitignored, so it never reached
GitHub — that control worked. But the exposure bought **nothing**: `host_setup.sh` does not download
it; it is only read when it happens to sit beside the script in a local repo clone.
**Fixed live (protocol P3)** with an exact-match `deny all` in `www/nginx.conf`.
⭐ **Same shape as the `.184` finding earlier the same day: the build/distribution system leaking a
credential wider than the design intended, while the control everyone watches (gitignore) worked
perfectly.** Two in one day is a pattern, not a coincidence — **audit the distribution path, not just
the repo.**

#### 🚨 Finding 2 — `unattended-upgrades` is NOT the fleet convention this plan claimed

The build standard says auto-patching stays masked and that the "same reasoning [was] already applied
to the Swarm nodes." ⚠️ **True of the Swarm nodes and nowhere else.** Measured across the fleet:

| State | Hosts |
|---|---|
| **masked** | `docker-swarm-1/2/3` |
| **disabled** | `.186` |
| **enabled** | `.181` GitLab, `.182` runner, `.183` SonarQube, `.184` WWW, and `.185` as built |

**Three different states across nine hosts is not a convention; it is an accident.** 🧠 And the
uncomfortable part: the boxes where an unscheduled restart hurts most — **GitLab and the runner, the
whole deploy path** — are in the `enabled` group. Logged as an open question, deliberately **not**
fixed mid-build.

⭐ **How the Swarm nodes actually did it, and the trap inside it:** they masked **three** units —
`unattended-upgrades.service`, `apt-daily.timer`, `apt-daily-upgrade.timer` — and **left
`/etc/apt/apt.conf.d/20auto-upgrades` saying `Unattended-Upgrade "1"`.** So **reading the config file
tells you auto-patching is ON when it is off.** The timers decide; the config only describes.
*The layer that reports is not the layer that decides* — the phase's recurring lesson, found in Part 0.

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
