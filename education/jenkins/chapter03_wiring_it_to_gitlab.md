# Jenkins · Chapter 3 — Wiring It to GitLab

> **Series:** Home-Lab Education · Phase 17 (Jenkins)
> **Built and verified:** August 20, 2026 on VM 185 (`192.168.1.185`) against GitLab 19.2.1 on
> `192.168.1.181`
> **Versions at time of writing:** Jenkins 2.568.2 LTS on Jetty 12.1.8 · `git` plugin 5.10.1 ·
> `gitlab-plugin` 1.9.16 · `workflow-multibranch` 841.vec5b\_9e1806ec
> **Assumed, not re-taught:** [Chapter 1](chapter01_the_controller_and_the_agent.md) (the
> controller/agent split, `JENKINS_HOME`) and [Chapter 2](chapter02_identity_authorization_breakglass.md)
> (the realm and the strategy).
> **Read this before:** Chapter 4 (the first deploy onto the Swarm)

---

## What this chapter covers

**This is the build procedure**, [in the order it should be done]{custom-style="Key"}, ending with a working integration:
`git push` to GitLab, Jenkins builds, nobody watching.

Eight steps. Each one says what to do, **how to confirm it actually took effect**, and where the
tripping points are. ⚠️ **The tripping points are marked where they occur rather than collected at the
end**, because [a warning is only useful at the moment you could still act on it]{custom-style="Key"}.
Several cost real time on the first build, and all of them are the kind that [produce no error until
much later]{custom-style="Key"}, when the cause is no longer obvious.

Two sections at the end are not steps. **§11 is a warning about what a `git checkout` copies onto
disk** — [read it before you point CI at any repository]{custom-style="Key"}. **§12 is the verification habit** that
underpins every "confirm it took effect" line in the walkthrough.

---

## 1. The shape of it: two links, not one

![Figure 1 — the two links, which share nothing but the two hosts](images/ch03_fig1_two_links.png)

Connecting CI to a git server sounds like one task. **It is two**, and getting this straight before
you start [saves the most confusing class of failure later]{custom-style="Key"}.

| | Link 1 — **clone** | Link 2 — **trigger** |
|---|---|---|
| Who dials | **Jenkins** → GitLab | **GitLab** → Jenkins |
| Protocol | SSH, port 22 | HTTP, port 8080 |
| Credential | read-only deploy key | access token in the query string |
| Set up in | steps 1–3 | steps 5–7 |
| Watch out for | unknown host key | GitLab's local-network block; the missing token |

[The two links share the two hostnames and nothing else]{custom-style="Key"} — different direction,
different protocol, different credential, different failure mode.

⭐ **Why this framing earns its place: "wire A to B" is how the task gets written down, and
[the phrasing hides the second half]{custom-style="Key"}.** A working clone tells you nothing about
whether pushes trigger anything, and a delivered webhook tells you nothing about whether the clone
will succeed. 🚨 **An integration that clones but never triggers looks healthy in every screen you
would think to check** — the job exists, the credential works, manual builds pass — and
[simply never builds anything new]{custom-style="Key"}.

**So do them in order, and [prove each one separately]{custom-style="Key"}.** Steps 1–4 [give you a job that builds when you]{custom-style="Key"}
click. Steps 5–8 make it build when someone pushes.

---

## 2. What you need before you start

- **A Jenkins controller with a working agent** (Chapter 1) and an admin login (Chapter 2). The
  builds in this chapter [run on the agent, not the controller]{custom-style="Key"}.
- **Admin on the GitLab instance.** Step 7 changes an instance-wide network setting, which
  [a project owner cannot reach]{custom-style="Key"}.
- **A decision about where the `Jenkinsfile` lives.** Ours is `education/jenkins/Jenkinsfile`, not the
  repository root; §5 explains [why that choice is available in Jenkins]{custom-style="Key"} and what it costs.
- **Shell access to the GitLab server.** Not strictly required, but ⭐ **two of the confirmation steps
  below are [much easier against `gitlab-psql`]{custom-style="Key"}** than against the web UI, and step 2 wants a file off
  that host's disk.

---

## 3. Step 1 — Create a read-only deploy key

Jenkins authenticates to GitLab with a **per-project read-only deploy key**,
[never an account credential]{custom-style="Key"}. [A deploy key is scoped to one repository]{custom-style="Key"}, belongs
to no person, and [survives anyone leaving]{custom-style="Key"} without granting anything else.

Generate it on the Jenkins host, unencrypted, since [Jenkins must use it without a passphrase]{custom-style="Key"}:

```bash
ssh-keygen -t ed25519 -f /tmp/jenkins_gitlab_ed25519 -N '' -C 'jenkins-185-readonly'
cat /tmp/jenkins_gitlab_ed25519.pub
```

**Then, in this order:**

1. **GitLab** → project → *Settings → Repository → Deploy keys → Expand → Add new key.*
   Paste the **public** half. ⚠️ **Leave "Grant write permissions" unticked.**
2. **Jenkins** → *Manage Jenkins → Credentials → System → Global* → *Add Credentials* →
   kind **SSH Username with private key**, username **`git`**, ID `gitlab-home-lab-setup-readonly`.
3. **Only once the Jenkins credential is [saved and visible in the list]{custom-style="Key"}**, shred the private key:
   `shred -u /tmp/jenkins_gitlab_ed25519*`

> ⚠️ **Three tripping points, all of which cost us time.**
>
> **Paste the whole public-key line.** It is `ssh-ed25519 AAAAC3Nza… comment` — prefix, body and
> comment. [Pasting only the base64 body looks right and is rejected]{custom-style="Key"} as malformed.
>
> **In Jenkins, click "Enter directly" before pasting the private key.** The text area does not appear
> until you do, and it is easy to submit the form having pasted nothing.
>
> 🚨 **Do not delete the private key from the host until the credential is confirmed saved.** We
> shredded first, the credential had not saved, and [the keypair had to be regenerated and
> re-registered]{custom-style="Key"} from the beginning.

### Confirm it took effect

The checkbox is a rendering; **[the enforcement is a column in GitLab's database]{custom-style="Key"}.** Ask that instead:

```bash
sudo gitlab-psql -xc "select k.id, k.title, dk.can_push
  from keys k join deploy_keys_projects dk on dk.deploy_key_id = k.id
  where dk.project_id = <id>;"
```

```
id | title                 | can_push
 3 | jenkins-185-readonly  | f
```

✅ **`can_push = f` is the fact you wanted.** [It is the same question the server asks at push
time]{custom-style="Key"}, which is what makes it worth more than the form you just submitted.

### ⚠️ A scoped key is only a control if the repository was closed

`production/home-lab-setup` is `visibility_level = 0` — **PRIVATE** — so the key is genuinely what
gets Jenkins in.

That is worth checking rather than assuming. A GitLab project set to **INTERNAL** is readable by
[every authenticated identity on the instance]{custom-style="Key"}; another project in this same lab
is exactly that. Against an internal repository the carefully-scoped deploy key would be
[decoration on an already-open door]{custom-style="Key"}.

🚨 **"We used a scoped credential" is a security statement only if the resource was closed to begin
with.** Check the object's visibility first — [a scope grants access, it does not fence it]{custom-style="Key"}.

---

## 4. Step 2 — Pin GitLab's SSH host keys

Jenkins verifies the git server's host key and **[will refuse to connect to a server it cannot]{custom-style="Key"}
identify.** If you skip this step, the first scan ends here:

```
No ED25519 host key is known for gitlab.gothamtechnologies.com and you have requested strict checking.
Host key verification failed.
```

✅ **That is Jenkins working correctly**, [not a bug to route around]{custom-style="Key"}. Give it the keys.

**Read them from the GitLab server's own disk**, [over a session you already trust]{custom-style="Key"}:

```bash
# on the GitLab host
for f in /etc/ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_rsa_key.pub; do
  awk '{print "gitlab.gothamtechnologies.com,192.168.1.181 " $1 " " $2}' "$f"
done
```

Paste the result into **Manage Jenkins → Security → Git Host Key Verification Configuration**,
strategy **Manually provided keys**:

```
gitlab.gothamtechnologies.com,192.168.1.181 ssh-ed25519 AAAAC3Nza…
gitlab.gothamtechnologies.com,192.168.1.181 ssh-rsa     AAAAB3Nza…
```

⚠️ **Pin both key types, and include the IP as an alias.** The same server reached by address rather
than by name is [a different entry as far as SSH is concerned]{custom-style="Key"}, and a job
configured with an IP [will fail against a name-only pin]{custom-style="Key"}.

### Confirm it took effect

```bash
sudo grep -o 'ManuallyProvidedKeyVerificationStrategy' \
  /var/lib/jenkins/org.jenkinsci.plugins.gitclient.GitHostKeyVerificationConfiguration.xml
```

### ⭐ Where the keys came from is the point of the exercise

They were read from the server's own filesystem over an already-trusted channel — **not fetched from
the host we were trying to authenticate.**

`ssh-keyscan` is the reflex here, and it is [asking the unidentified machine to vouch for
itself]{custom-style="Key"}. If something is impersonating that address, `ssh-keyscan` returns the
impostor's [key and you pin it]{custom-style="Key"}. **That is trust-on-first-use with more steps.**
[Reading the file over a channel you already trust]{custom-style="Key"} is what makes this a pin
rather than a ritual.

### ⭐ Worth noticing: Jenkins' default is stricter than most hand-written scripts

Phase 16's deploy script reached the Swarm with `StrictHostKeyChecking=no` — same lab, same operator,
same month — and [would have connected to anything answering on port 22]{custom-style="Key"}.

The difference is structural rather than a matter of care: **[a default fails closed for
everyone]{custom-style="Key"}, whereas a flag pasted into a script fails open for whoever pasted it.**
⭐ **Which way a tool behaves when you have not configured it** is worth establishing early for
anything you depend on — it is the behaviour you will get [on the day nobody remembers to configure it]{custom-style="Key"}.

> **Lab vs PROD — pinning by hand does not scale, and the failure mode is not what you expect.**
> *In the lab:* two host keys pasted into a text box, for one git server that will not change.
> *Why it's acceptable here:* one server, one operator, and the keys came off that server's own disk
> over a trusted channel. *In production:* known-hosts material is distributed by configuration
> management, or host keys are signed by an internal CA, so a rebuilt server is trusted automatically
> and a *substituted* one still is not. *If you carry the habit:* ⚠️ **manually-pinned keys rot
> silently.** When the git server is rebuilt, every Jenkins fails closed at once —
> [correct behaviour that is indistinguishable from an outage]{custom-style="Key"} — and the pressure
> in that moment is to turn verification off "temporarily". 🚨 **That is how a pin becomes permanently
> absent.**

---

## 5. Step 3 — Create the Multibranch Pipeline job

*New Item → Multibranch Pipeline.* Add a **Git** branch source (not "GitLab", and not GitHub):

| Field | Value |
|---|---|
| Project Repository | `git@gitlab.gothamtechnologies.com:production/home-lab-setup.git` |
| Credentials | `gitlab-home-lab-setup-readonly` |
| Build Configuration → Script Path | `education/jenkins/Jenkinsfile` |

**The Script Path is the interesting field**, and it is a genuine structural difference from GitLab CI:

| | GitLab CI | Jenkins Multibranch |
|---|---|---|
| Pipeline definition | `.gitlab-ci.yml` **at the repo root** | any path, set **per job** |
| Pipelines per project | one entrypoint | as many as you create jobs |

That decided where this track's pipelines live. The repository will eventually hold several education
tracks, each wanting its own pipeline, and [Jenkins supports that natively because every job carries
its own Script Path]{custom-style="Key"}. The same arrangement in GitLab turns the root
`.gitlab-ci.yml` into an `include:` router that every track has to edit —
[a shared file that is a merge conflict waiting to happen]{custom-style="Key"}.

⚠️ **There is a real cost, and it is worth knowing before you like this too much.** GitLab's single
entrypoint means *the repository has a pipeline*, discoverable by anyone who clones it. With Jenkins,
[the mapping from repo to pipeline lives in Jenkins]{custom-style="Key"}, so **the repository alone no
longer tells you what CI does with it.**

### Branch indexing is not a build

A multibranch job does two distinct kinds of work. Keeping them separate matters here and matters
much more in §11:

- **Branch indexing** — the **controller** lists the remote's branches, looks for the Script Path in
  each, and decides which branches deserve jobs.
- **The build** — the **agent** checks out the code and runs the pipeline.

[Indexing is scheduling work, so the controller does it]{custom-style="Key"} regardless of how many
executors it has. This is also where workspace names come from: builds land in `home-lab-setup_main`,
[the job name and the branch]{custom-style="Key"}, because one multibranch job can have many branches
building at once.

### Confirm it took effect

*Scan Multibranch Pipeline Now*, then read the log for these two lines:

```
‘education/jenkins/Jenkinsfile’ found
Met criteria
```

✅ That is [the Script Path resolving against a real branch]{custom-style="Key"}. [A build should schedule itself]{custom-style="Key"}
immediately.

---

## 6. Step 4 — Write a `Jenkinsfile` that reports honestly

The first pipeline does nothing but check out and print. Its job is to prove the plumbing, so
**[make it print facts you can check]{custom-style="Key"}.**

```groovy
stage('Report where this ran') {
    steps {
        echo "branch:     ${env.BRANCH_NAME}"
        sh '''
            set -eu
            echo "host:       $(hostname)"
            echo "os identity:$(id)"
            echo "workspace:  ${WORKSPACE}"
            echo "commit:     $(git rev-parse HEAD)"
            echo "remote:     $(git remote get-url origin)"
        '''
    }
}
```

⚠️ **Use `env.BRANCH_NAME` for the branch, not `git rev-parse --abbrev-ref HEAD`.** Jenkins checks out
by commit SHA, so the working copy is **detached** and [git answers the literal string]{custom-style="Key"} `HEAD`.
`BRANCH_NAME` comes from the multibranch job rather than from the workspace, and
[it is the value that is actually correct]{custom-style="Key"}.

⭐ **The general form of that mistake is worth more than the fix.** Our original line carried a guard
against the command *failing* — and the guard never triggered, because
**[the command succeeded and returned something useless]{custom-style="Key"}.** 🚨 **A fallback on
error does not protect you from a confidently wrong answer**, which is the harder failure to notice
because nothing anywhere is red.

[Keeping both lines in the output]{custom-style="Key"} is the honest choice, and it shows the next reader why:

```
branch:     main            <- env.BRANCH_NAME, from the job
git says:   HEAD            <- the workspace itself
```

---

## 7. Step 5 — Generate a `notifyCommit` access token

GitLab will call Jenkins at the git plugin's `notifyCommit` endpoint, which means *"this repository
changed, go and look."* **Current versions require a token**, [so make one first]{custom-style="Key"}:

*Manage Jenkins → Security →* **Git plugin notifyCommit access tokens** *→ Add new token* → name it
after the caller, e.g. `gitlab-home-lab-setup`.

🚨 **Copy the value now. [Jenkins stores only a SHA-256 hash]{custom-style="Key"}** and
[will never show it to you again]{custom-style="Key"}. Put it wherever your credentials live.

> ⚠️ **If you are following an older guide, this is where it will diverge.** Guides written before the
> requirement landed show a bare `notifyCommit` URL with no token, and against a current plugin that
> returns:
>
> ```
> HTTP ERROR 401 An access token is required. Please refer to Git plugin documentation
> (https://plugins.jenkins.io/git/#plugin-content-push-notification-from-repository) for details.
> ```
>
> ✅ **That is correct behaviour, and [the error even names the page that explains the
> fix]{custom-style="Key"}.** ⛔ **Do not "solve" it by setting
> `hudson.plugins.git.GitStatus.NOTIFY_COMMIT_ACCESS_CONTROL=disabled`.** The plugin's own
> documentation calls that insecure; it reopens the endpoint to
> [anything that can reach the port]{custom-style="Key"}.
>
> ⭐ **The transferable habit: check what your version does rather than what the guides say it does.**
> Defaults get tightened over time, and [a warning that was true in 2019 may describe a setting that no
> longer exists]{custom-style="Key"}. Reciting it feels like diligence and displaces measurement.

---

## 8. Step 6 — Create the webhook in GitLab

*Project → Settings → Webhooks → Add new webhook.*

| Field | Value |
|---|---|
| **URL** | `http://192.168.1.185:8080/git/notifyCommit?url=git@gitlab.gothamtechnologies.com:production/home-lab-setup.git&token=<token>` |
| **Secret token** | ⛔ **leave blank — see below** |
| Trigger | Push events |

[Two parameters, both required]{custom-style="Key"}: `url` identifies which repository changed **exactly as the job's
remote is written**, and `token` is the value from step 5.

### ⚠️ The "Secret token" field is a different thing with the same name

| Field | Sent as | Read by |
|---|---|---|
| GitLab webhook **Secret token** | `X-Gitlab-Token` **header** | ⛔ nothing here — `notifyCommit` never reads headers |
| Git plugin **access token** | `token` **query parameter** | ✅ the git plugin |

🚨 **Stating it in prose, because it is too important to leave in a table cell: filling in GitLab's
Secret token field secures nothing while looking exactly like securing something.**
[A control that appears engaged and is not]{custom-style="Key"} is worse than an obviously absent one,
because **it stops you looking further.** [Leave it blank and write down]{custom-style="Key"} *why* it is blank, or someone
will helpfully fill it in.

⭐ This is the third pair of similarly-named, unrelated things in this track, after
`ssh-agent`/`ssh-slaves` and `matrix-project`/`matrix-auth`. **A good working rule:
[assume two similar names in this stack are unrelated until checked]{custom-style="Key"}.**

### ⚠️ Do not use the GitLab plugin's endpoint for a multibranch job

The intuitive target is `POST /project/<job>`, provided by `gitlab-plugin`. For a Multibranch
Pipeline it returns **404** — and so does a job name that does not exist.
[The two responses are identical]{custom-style="Key"}.

The reason is that the plugin's trigger is a **job-level** feature and a multibranch job is a
**folder**, so the endpoint is never registered. 🚨 **A 404 meaning "wrong plugin for this job type"
[is indistinguishable from a 404 meaning you typed the name wrong]{custom-style="Key"}**, and
[the typo is the explanation you will chase]{custom-style="Key"} because it is likelier in general.
The git plugin's `notifyCommit` is the route that works.

### Confirm it took effect

⚠️ **Do not verify a webhook by re-opening the edit form.** We pasted the URL, saved, reopened the
form, read the correct value back — and **nothing had been stored.** The save had been rejected, and
[a rejected form redisplays what you typed]{custom-style="Key"} rather than what was kept.

[Check the **list view**, or ask the database]{custom-style="Key"}:

```bash
sudo gitlab-psql -xc "select id, url, created_at, updated_at from public.web_hooks;"
```

✅ **`updated_at` later than `created_at` means an edit actually landed.** If they are identical after
you have saved a change, [the save did not happen]{custom-style="Key"}.

---

## 9. Step 7 — Let GitLab reach Jenkins on the local network

By default GitLab **refuses to send webhooks to private addresses**, [and says so when you save]{custom-style="Key"}:

```
Url is blocked: Requests to the local network are not allowed
```

✅ **This is the kind of failure to wish for** — [loud, immediate, and in front of the person who
caused it]{custom-style="Key"}, [before any request left the server]{custom-style="Key"}.

**The narrow fix**, as instance admin: *Admin Area → Settings → Network → Outbound requests* →
**"Local IP addresses and domain names that hooks and integrations can access"** → add:

```
192.168.1.185:8080
```

⛔ **Do not tick "Allow requests to the local network from webhooks and integrations."** That is the
blunt instrument most guides reach for, and it opens [every service on every host on the
LAN]{custom-style="Key"} to anything GitLab can be persuaded to call. **The allow-list entry grants
one host, on one port**, which is all you need.

⚠️ **Include the port.** An entry of `192.168.1.185` alone does not cover `192.168.1.185:8080`.

### Confirm it took effect

```bash
sudo gitlab-psql -xc "select allow_local_requests_from_web_hooks_and_services,
  outbound_local_requests_whitelist from application_settings order by id desc limit 1;"
```

```
allow_local_requests_from_web_hooks_and_services | f
outbound_local_requests_whitelist                | {192.168.1.185:8080}
```

✅ **The flag is still `f` and the allow-list has exactly one entry.** That pair is the outcome you
want: [the general block intact, one exception made deliberately]{custom-style="Key"}.

### ⚠️ Two caveats about this setting, because it is not as general as it sounds

**System hooks are governed separately** — `allow_local_requests_from_system_hooks` defaults to
**true** while the webhook flag defaults to false. So [a system hook to a LAN address works while a
project webhook to the same address is refused]{custom-style="Key"}.

**And GitLab will deliver to its own address regardless.** We saw a project webhook reach
`192.168.1.181` — equally private — with the flag off and the allow-list empty, then refuse
`192.168.1.185`. ⚠️ *Inferred rather than proven from source: the blocker exempts the instance's own
address.*

⭐ **So "GitLab blocks outbound LAN requests" is wrong in two independent ways.**
[It depends on which subsystem asks and which local address you name]{custom-style="Key"} — a summary
at that level of generality is **not a fact about the system**, and it is the kind of half-truth that
sends you looking in the wrong place at 3am.

---

## 10. Step 8 — Prove it end to end, then snapshot

**Use the Test button first**, then do a real push. [They prove different things]{custom-style="Key"}.

### Reading the Test response carefully

A successful delivery returns **HTTP 200** with a body that begins with a line that reads like
failure:

```
No git jobs using repository: git@gitlab…home-lab-setup.git and branches:
Scheduled indexing of home-lab-setup
```

⚠️ **[The first line is about classic freestyle jobs]{custom-style="Key"} using *Poll SCM*, of which this instance has
none.** **The second line is the one that matters.** 🚨 [Stopping at line one would have you debugging
a working system]{custom-style="Key"} — and line one is exactly where you stop, because it comes
first and it sounds negative.

### Then push something, because that is the only complete proof

The Test button [exercises the URL, the token and the network path]{custom-style="Key"}. **It does not prove that a real
push emits the hook** — that depends on the trigger being enabled for push events on the branch you
care about. [Only a genuine commit tests the whole chain]{custom-style="Key"}.

| Build | Cause | Result |
|---|---|---|
| #1 | manual scan | SUCCESS |
| #2 | webhook Test button | SUCCESS |
| #3 | **a real `git push`** | SUCCESS |
| #4 | another push, hours later | SUCCESS |

### ⚠️ Jenkins does not record that GitLab was the caller

The build cause reads **`Branch indexing`**. From inside Jenkins, a genuine push, the Test button and
anyone else holding the token are [indistinguishable from one another]{custom-style="Key"}.

🚨 **The token authenticates the request, not the sender**, so **["the pipeline ran" is not evidence
of who ran it]{custom-style="Key"}.** [Worth knowing before you rely on build history]{custom-style="Key"} as an audit
trail.

> **Lab vs PROD — the trigger token crosses the LAN in a cleartext URL.** *In the lab:* the token is a
> query parameter on `http://`, by the same decision that left the Jenkins UI without TLS. *Why it's
> acceptable here:* isolated segment, single operator, and the token's reach is *"can cause a branch
> scan"* rather than *"can deploy"* — Jenkins decides what to build, the caller does not.
> *In production:* TLS end to end, with the trigger secret in a **header** so it stays out of logs and
> referrers. *If you carry the habit:* 🚨 **a secret in a URL is a secret in a log** — it lands in the
> stored webhook config, the delivery log, the request line, and every proxy log on the path. ⚠️ And
> once a pipeline deploys, which ours does from Chapter 4, [whoever can trigger it can ship
> code]{custom-style="Key"} on your CI system's authority. *(The header-based comparison is recited;
> nothing in this lab terminates TLS.)*

### Snapshot

With four green builds, [shut the VM down and snapshot it]{custom-style="Key"} — ours is `j03-gitlab-wired`. ⭐ **Snapshot
after a verified working state, never after a change you have not yet proven**, or you have preserved
[a state you cannot vouch for]{custom-style="Key"}.

---

## 11. Know what the checkout copies onto disk

![Figure 2 — two copies of the repository, neither of them intended as a place to keep secrets](images/ch03_fig2_what_checkout_left.png)

**Read this before pointing CI at any repository.** It is not a Jenkins flaw and there is no setting
that fixes it; [it is a consequence of what a clone is]{custom-style="Key"}.

The credential work in steps 1–2 was careful: read-only key, one project, host key pinned, private
half deleted from disk. **[All of it governs how Jenkins authenticates]{custom-style="Key"}. None of it governs what the
clone then contains.** After the first build:

| Where | What | Mode |
|---|---|---|
| Agent workspace | `PASSWORDS.md` (16,781 B), `github_credentials.md` (3,233 B), **57 files under `working/`** including a live 476-byte SSH private key | `664` |
| Controller cache | `/var/lib/jenkins/caches/git-8444…`, **31 MB**, the same objects | `755` |

⭐ **The sentence worth keeping, since a table row is easy to skim:
[access control on the pipeline is irrelevant when the artefact it clones is the
vault]{custom-style="Key"}.** Any `Jenkinsfile`, on any branch, can now read a private key Jenkins was
never asked to grant it.

### The controller has a copy too, and that surprises people

Chapter 1 proved the controller runs no builds — zero executors, and a job that queues forever. That
proof was sound. **The conclusion drawn from it was [wider than the evidence]{custom-style="Key"}:**
[branch indexing is not a build]{custom-style="Key"}, so the controller clones the repository itself
in order to look for the `Jenkinsfile`.

🚨 **[A boundary verified against one class of work says nothing about another]{custom-style="Key"}.**
"X cannot happen here" is only true for the mechanism you tested. **Ask what other kinds of work the
component still does** — [a rule proven against TCP says nothing about UDP]{custom-style="Key"}, and a
read-only mount proven against one writer says nothing about the next.

### Be precise about who can read it

Overstating this teaches the wrong lesson. The files are `664`, **but `/home/jenkins-agent` is `750`**,
so the readers are `jenkins-agent` and root — [not every local account on the box]{custom-style="Key"}.
The controller's cache is likewise gated by needing the `jenkins` uid.

✅ **The parent directory is doing the work**, which is [exactly the mechanic that protects `master.key`
in Chapter 1 §7]{custom-style="Key"}, here working in our favour. **Same one-directory-deep structure,
opposite outcome** — the mechanic is neutral and only the mode bits decide.

### It is a live mirror, not a one-time copy

`PASSWORDS.md` measured 14,854 bytes after the first build and **16,781** a few hours later, because a
documentation commit was pushed and [the workspace re-checked out]{custom-style="Key"}.

⚠️ **The access token from step 5 was written into that file and was in both copies within the hour.**
⭐ **This is the part to internalise: it is not a stale artefact of one careless checkout.**
[Every future credential committed to that repository arrives here automatically]{custom-style="Key"},
without anyone deciding it should.

### ⚠️ The obvious fix does not work

`cleanWs()` empties the workspace between builds, but [the next checkout recreates every
file]{custom-style="Key"}, and it does **nothing whatever** to the controller's cache.

**[The fixes that do work are structural]{custom-style="Key"}:** a **narrow checkout** (`sparse-checkout`, or a
`Jenkinsfile` that fetches only what it needs), **a repository that does not contain secrets**, or
**ephemeral agents** that are destroyed after each build.

⭐ Worth contrasting with Phase 16: GitLab CI ran each job in a **fresh container**, so secrets existed
for the life of the job and died with it. [A Jenkins agent workspace is a directory that
stays]{custom-style="Key"} — which is deliberate, since not re-cloning 50 MB per build is why it is
fast. **[The persistence you chose for speed]{custom-style="Key"} is the persistence that keeps the secrets.**

> **Lab vs PROD — the repository being cloned contains plaintext credentials.** *In the lab:*
> `PASSWORDS.md` and a live private key are committed to the private GitLab mirror on purpose, so the
> whole lab is reproducible from one clone. *Why it's acceptable here:* the repo is PRIVATE, the
> mirror never reaches the public GitHub remote, and the credentials are lab-only by rule.
> *In production:* secrets live in a secret manager and the repository holds **references**; CI
> fetches them at run time, scoped to the job, so a clone is worth nothing on its own.
> *If you carry the habit:* 🚨 **every system that clones the repo becomes a copy of the vault** — CI
> agents, developer laptops, backups, and [the controller cache nobody knew existed]{custom-style="Key"}.
> ⚠️ **It also makes `JENKINS_HOME` more valuable than Chapter 1 described:** it now holds a plaintext
> key beside the encrypted credential store, so **[a stolen backup no longer needs `master.key` to be
> worth having]{custom-style="Key"}.**

---

## 12. The verification habit behind every "confirm it took effect"

Each step above ends by checking something other than the screen used to make the change. That is
deliberate, and it is the most portable thing in the chapter.

**Four times during this build, a surface reported something that was not the case.** None produced an
error at the moment it misled:

| What it said | What was true | What settled it |
|---|---|---|
| *"Hook executed successfully but returned HTTP 422"* | The URL still pointed at **GitLab itself**; Jenkins never saw the request | `Server: nginx` and `X-Gitlab-Meta` in the response headers |
| The edit form redisplayed the corrected URL after saving | **The save was rejected**; the stored URL was unchanged | `updated_at` still equal to `created_at` |
| A 404 from the GitLab plugin's endpoint | Wrong plugin for this job type, not a typo | The same 404 for a job name that does not exist |
| *"No git jobs using repository…"* | Indexing **was** scheduled, on the very next line | The build appearing seconds later |

The first is worth dwelling on. A webhook pointed at the wrong host still returns a **plausible
error** — the wrong machine was a real server that produced a polished rejection page — and
[a plausible error sends you to debug the innocent machine]{custom-style="Key"}. One line of headers
settled it, because **Jenkins runs on Jetty and GitLab fronts with nginx.**

⭐ **The rule that ties all four together: [prefer the surface generated by the thing that enforces the
rule]{custom-style="Key"}.** `can_push` in the database over the checkbox. `updated_at` over the form.
Response headers over the rendered error page. A build appearing over a success message. **Every one
of those [cost a minute to check and would have cost an hour to assume]{custom-style="Key"}.**

---

## 13. Commands to know by heart

```bash
# --- which machine actually answered? ---
curl -s -D - -o /dev/null <url> | grep -iE '^(HTTP|Server|X-Gitlab-Meta)'
# Server: nginx + X-Gitlab-Meta  -> GitLab.   Powered by Jetty -> Jenkins.

# --- GitLab side, asked of the database rather than the UI ---
sudo gitlab-psql -xc "select id,title,can_push,project_id from keys k
  join deploy_keys_projects dk on dk.deploy_key_id=k.id where dk.project_id=<id>;"
sudo gitlab-psql -xc "select id,url,created_at,updated_at from public.web_hooks;"   # did the save land?
sudo gitlab-psql -xc "select created_at,url,response_status,response_body
  from public.web_hook_logs_daily order by created_at desc limit 1;"
sudo gitlab-psql -xc "select allow_local_requests_from_web_hooks_and_services,
  allow_local_requests_from_system_hooks, outbound_local_requests_whitelist
  from application_settings order by id desc limit 1;"

# --- Jenkins side ---
curl -s -u <user>:<pass> 'http://<host>:8080/job/<job>/job/<branch>/api/json?depth=2'   # builds + causes
curl -s -u <user>:<pass> 'http://<host>:8080/job/<job>/job/<branch>/lastBuild/consoleText'
sudo grep -oE '<(scriptPath|remote|credentialsId)>[^<]*' /var/lib/jenkins/jobs/<job>/config.xml
sudo cat /var/lib/jenkins/hudson.plugins.git.ApiTokenPropertyConfiguration.xml   # names + hashes only

# --- what the checkout put on disk ---
sudo du -sh /var/lib/jenkins/caches/*                     # the controller's copy
sudo stat -c '%a %U:%G %n' /home/jenkins-agent            # the directory doing the gating
```

⭐ **Reach for GitLab's delivery log before you touch Jenkins.** It records the URL called, the status,
the headers and the body. [Most webhook debugging ends there]{custom-style="Key"}, and starting at the
other end means [diagnosing a machine that may not have been involved]{custom-style="Key"}.

---

## 14. Glossary

| Term | Meaning |
|---|---|
| **Deploy key** | An SSH key granting access to **one repository**. `can_push` decides read vs write; verify it in the database |
| **Branch indexing** | A multibranch job listing remote branches and looking for its Script Path. Done by the **controller**, and **not a build** |
| **Script Path** | Where in the repo a job's `Jenkinsfile` lives. Per-job in Jenkins; fixed at the root in GitLab CI |
| **`notifyCommit`** | The git plugin's endpoint for "the repo changed, go look". Requires a `token` query parameter |
| **notifyCommit access token** | Generated in *Manage Jenkins → Security*, stored **SHA-256 hashed**. Unrelated to GitLab's Secret token |
| **GitLab Secret token** | Sent as the `X-Gitlab-Token` **header**. ⛔ Never read by `notifyCommit` — leave it blank |
| **Host key pinning** | Recording the server's key **in advance, from a trusted channel**, so an unexpected one fails closed |
| **`ManuallyProvided…Strategy`** | Jenkins' pinned-key verification mode, as opposed to *Known hosts file* or *Non verifying* |
| **Outbound allow-list** | GitLab's list of local `host:port` targets hooks may reach. Much narrower than the global "allow local network" toggle |
| **INTERNAL visibility** | GitLab: readable by **any authenticated user** on the instance. A scoped credential adds nothing against it |
| **`cleanWs()`** | Empties the workspace between builds. ⚠️ Does not stop the next checkout recreating it, and never touches the controller cache |
| **Detached HEAD** | What Jenkins leaves the workspace in, having checked out a SHA. Why `git rev-parse --abbrev-ref HEAD` returns `HEAD` |

---

## 15. Check yourself

Answer these out loud. Section references, not answers — reconstructing is the exercise.

1. "Jenkins is wired to GitLab." Name the two links, and say what still appears healthy if only one of
   them works. (§1)
2. You made a deploy key read-only. Where do you confirm it, and why not the checkbox? (§3)
3. Under what condition does a correctly-scoped read-only deploy key buy you nothing at all? (§3)
4. Jenkins refuses to clone because the host key is unknown. Why is `ssh-keyscan` the wrong way to fix
   it, and what is the right one? (§4)
5. Your controller runs zero executors. Name something it still clones, and the general form of the
   mistake in assuming it does not. (§5, §11)
6. Your pipeline prints `branch: HEAD`. What happened, and why did the error guard not catch it? (§6)
7. GitLab's webhook form has a Secret token field and Jenkins wants a token. Are they the same, and
   what does filling in the wrong one cost you? (§8)
8. A webhook to another host on the LAN is refused. Name the narrow fix and the blunt one, and say
   what the blunt one exposes. (§9)
9. The webhook Test button reports success. What has that proven, and what has it not? (§10)
10. `cleanWs()` is proposed to clear secrets from the workspace. Give the two separate reasons it does
    not work. (§11)
11. You typed a value into a form, saved it, and read it back correctly. Name a circumstance in which
    it was never stored, and the surface you should have checked instead. (§8, §12)
