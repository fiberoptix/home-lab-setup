# Jenkins

A CI/CD controller built from nothing, wired to a **real GitLab** and made to deploy a **real
application** onto a **real three-node Docker Swarm** — and then made to fail, so the failures can be
diagnosed rather than described.

The framing is what makes this track different from most Jenkins material. This lab **already has a
working pipeline**: GitLab CI builds Capricorn, scans it, and deploys it to the Swarm, and
[track 2](../docker-swarm/README.md) is the record of building and breaking that. So Jenkins is not
being learned in a vacuum against a toy `hello-world` job — it is a **second implementation of a
delivery path whose first implementation you can already operate**, aimed at the same registry and
the same three nodes. Every Jenkins concept therefore arrives with a question attached: *how did
GitLab do this, and why does Jenkins do it differently?*

The two pipelines run **side by side and stay that way.** Jenkins deploys the stack
`capricorn-jenkins`; the GitLab pipeline keeps deploying `capricorn`. Neither is torn down for the
other, because the comparison is the point.

**Working record:** [`phases/phase17_jenkins.md`](../../phases/phase17_jenkins.md) — the plan, the
open decisions and how they were settled, the traps deliberately left in place, and the numbered
findings (`J-P1…`) as they happened.

---

## A framing you should know about before you read

This track is written as though **a firm handed over a build standard** and the work is to implement
it, question it, and record where it turns out to be wrong. That device is deliberate — it is closer
to a first week on a real platform than a greenfield tutorial is.

🚨 **It also creates a hazard that the phase file manages explicitly.** Every specification line in
the plan is marked either 🔧 **MECHANICS** (how Jenkins actually works — rely on it) or 📐
**CONVENTION** (an AI invention standing in for a firm's house style). **Nothing marked 📐 should ever
be quoted as "how a real firm does it."** Every chapter so far contains a worked example of why the
distinction matters. In Chapter 1 the standard's own plugin list omitted a plugin that the standard's
own agent requirement depends on. In Chapter 2 the standard specified a break-glass account that
**Jenkins' mechanics make impossible** — a 📐 convention written in confident prose, resting on a 🔧
mechanic nobody had checked. In Chapter 3 it happened a **third** time: the standard required a
webhook trigger, and **no plugin on its own list can provide one for the job type it also specified.**
🚨 **None of the three announced itself; all three had to be measured.**

---

## Chapters

**Prerequisites:** comfort with a terminal, Docker, and the idea of a build pipeline. The
[Docker Swarm track](../docker-swarm/README.md) is genuinely useful here — the deploy target and the
comparison both come from it — but it is not required for Chapter 1.

| # | Chapter | Covers | Status |
|---|---|---|---|
| 01 | [The controller and the agent](chapter01_the_controller_and_the_agent.md) | Why the controller runs zero builds; **three sources that disagreed about the install** — an expired signing key whose unversioned filename is the *oldest*, and a package that does not declare Java and so installs cleanly and cannot start; six plugin choices that became 73 plugins, and the plugin whose name says it does the thing it does not do; SSH vs inbound agents and which failure modes each buys; ⭐ **proving the split with a build that could not run**; the two privilege planes, and what the agent can still read | ✅ Written |
| 02 | [Identity, authorization, and break-glass](chapter02_identity_authorization_breakglass.md) | Two questions — *who are you* and *what may you do* — answered by **two slots that each hold exactly one value**, and the fallback that therefore does not exist; the build standard's own break-glass plan, and why it was wrong; ⭐ **a lockout drill that could not fire, twice**, and a save that succeeded at something that never happened; why the lockout moved to upgrade time; the break-glass runbook, ⚠️ **written and not rehearsed**, and why the internet's version of it is the destructive one; the **third** privilege plane, which none of this touches | ✅ Written |
| 03 | [Wiring it to GitLab](chapter03_wiring_it_to_gitlab.md) | 📋 **The eight-step build procedure**, each step with its confirmation and its tripping points: a read-only deploy key **proved read-only somewhere other than the checkbox**, and when a scoped credential buys nothing at all; host keys pinned from the server's own disk, and why `ssh-keyscan` is not a pin; Script Path vs a fixed root, and what Jenkins moves out of the repo; the access token the endpoint requires, and ⚠️ **the identically-named GitLab field that does nothing**; letting GitLab reach the LAN with the narrow fix rather than the blunt one; ⚠️ **what a `git checkout` copies onto disk** — including the second copy on the controller; ⭐ **and the verification habit**: which surface to believe when a screen and the system disagree | ✅ Written |

Chapters are written after the work they describe, so this table fills in **behind** the build rather
than ahead of it. The remaining arc — deploying to the Swarm, building and pushing images, then a run
of deliberate bad deployments and recoveries, then hardening and operations — is planned in the phase
file. ⚠️ **The chapter count there is an estimate and not a contract**; Phase 16 planned
seven parts and produced eight chapters that did not map one-to-one.

🙋 **Andrew ran every command in this track at the keyboard**, one step at a time, including the whole
of Chapter 1. 🤖 **The read-only verification is the AI's** — querying Jenkins' own REST API for
plugin lists and node state, and checking file modes and process ownership over SSH. That division is
stated where it appears. It matters because a claim checked against `/api/json` is stronger than the
same claim read off a web page, and weaker than one the operator confirmed by hand.

---

## The lab this is written on

| | |
|---|---|
| Controller | `vm-jenkins-1` (VM 185) at `192.168.1.185`, bookmarked — **no DNS name** |
| Resources | 4 vCPU, 8 GB RAM, 60 GB on the mirrored `vm-critical` pool (58 G usable) |
| Built from | Proxmox template 9000 (`tmpl-ubuntu-2404-cloudinit`), Ubuntu 24.04 LTS |
| Jenkins | **2.568.2 LTS**, official `pkg.jenkins.io/debian-stable` apt repo |
| Java | **OpenJDK 21.0.11** headless — chosen from Jenkins' support table, not from the package's `Depends` |
| Agent | one, label `swarm-deploy`, SSH-launched as OS user `jenkins-agent` **on the controller's own VM** |
| Deploy target | the three-manager Swarm at `192.168.1.191–193`, stack `capricorn-jenkins` |
| Source + registry | the GitLab at `192.168.1.181` |

⚠️ **Two honest limitations, stated up front rather than discovered later.**

**The agent is not on its own host.** It runs as a separate unprivileged user on the controller's VM,
which makes the *privilege* boundary real and kernel-enforced but leaves the *isolation* boundary
imaginary — same kernel, same disk, same CPU. A build that fills the disk takes the controller with
it. This is ledger row **J2** and Chapter 1 §7 works through what it does and does not buy.

**The web UI is plain HTTP.** No TLS, on the operator's decision. That is ledger row **J1**, and it is
a real compromise rather than a cosmetic one: a CI session cookie is a credential to everything the
CI system can deploy.

---

## The Lab-vs-PROD ledger, in one place

Every chapter marks the places where this lab's configuration would be **wrong** in production — not
merely smaller — using the callout format in [`../CONVENTIONS.md`](../CONVENTIONS.md). The full ledger
with consequences lives in the [phase file](../../phases/phase17_jenkins.md) (search *"Lab vs PROD
ledger"*); this index maps each row to where it is taught.

| Row | Compromise | Taught in |
|---|---|---|
| **J1** | The Jenkins web UI is plain HTTP — password and session cookie cross the LAN in cleartext | Chapter 1 §2, and again in Chapter 3 §5 where the trigger token rides in a cleartext **URL** |
| **J2** | The build agent is the controller's own VM — privilege boundary real, isolation boundary absent | Chapter 1 §7 |
| **J4** | One long-lived agent whose **workspace persists between builds** — the concrete difference from Phase 16's fresh container per job | Chapter 3 §6 |
| **J5** | Jenkins' own user database is the security realm — no central identity, and therefore no central offboarding | Chapter 2 §2 |
| **J6** | The break-glass procedure is recorded and has never been rehearsed | Chapter 2 §6 |
| **J7** | Git host keys are **pinned by hand**, which is a real pin and does not scale | Chapter 3 §3 |
| **J8** | 🚨 The repository Jenkins clones **contains plaintext credentials**, so every clone is a copy of the vault | Chapter 3 §6 |

---

## Track layout

```
education/jenkins/
├── README.md          this file
├── chapterNN_*.md     chapters, numbering restarts at 01 per track
├── diagrams/          Graphviz .dot sources — the editable originals
├── images/            rendered .png — generated, never edited by hand
├── docx/              Word builds — generated, never edited by hand
└── scratch/           GITIGNORED — command scratchpads, anchor lists
```
