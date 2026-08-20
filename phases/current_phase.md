# Current Phase

**Updated:** August 20, 2026 - 5:10 PM EDT

📉 **MEMORY.md SHRANK for the first time on record: 2414 → 2099** (Aug 20). The closed Phase 14
k3s/Redpanda block (331 lines, 14 % of an always-loaded file, subject explicitly out of scope) was
**copied verbatim** into `phase14_k8s_redpanda_poc.md` and verified line-by-line — **0 removed lines
missing** — before a single line was deleted. **44 distinctive strings existed only in the MEMORY
copy**, so summarising would have destroyed them.

📉 **This file was trimmed 3797 → 2067 lines on Aug 20** by demoting three closed-phase blocks
(Phase 16 handoffs → `phase16`, Phase 14 closing record → `phase14`, OpenClaw logs → `phase11`).
**Nothing was summarised or deleted — each block was copied verbatim and verified line-by-line before
removal.** Details in `MEMORY.md` → PHASE INDEX footer.

---

## 🔵 PHASE 17 PARTS 0 + 1 — Jenkins is up (Aug 20, 2026, ~1:00–2:30 PM EDT) ✅ DONE

🙋 **Andrew: "I'd like to go step-by-step with you building it so I understand all the pieces. I'd
like to run all the commands myself."** He did — every command, including the VM build. The AI's
contribution was instruction, live diagnosis, and **read-only verification** (Jenkins' REST API for
plugin/node state, `ps` and file modes over SSH). That division is stated in the track README too,
because a claim checked against `/api/json` outranks the same claim read off a web page.

**Working protocol agreed at the start and honoured throughout** (recorded as P1 in the phase file):
Part 0 is hands-on but earns **no chapter**; when a trap is near the AI says *"there's a trap coming
— what do you think it is?"* without revealing it; **build-process improvements get fixed live**
rather than logged for later; session scope was Part 0 + Part 1.

**What was built.** VM 185 `vm-jenkins-1` from template 9000 (4 vCPU, 8 GB, 60 GB on `vm-critical`),
then Jenkins **2.568.2 LTS** on **OpenJDK 21**, controller at **0 executors**, one SSH agent as OS
user `jenkins-agent`, label `swarm-deploy`, host key pinned, private key deleted from the host so it
exists only in Jenkins' credential store. Snapshot **`j02-jenkins-up`** taken (VM shut down for it)
and `.185` restarted clean.

**Findings — full detail in `phase17_jenkins.md`, do not duplicate it here:**

| # | What |
|---|---|
| **J-P2** | Part 0. Template clone ≠ live-VM clone: fresh `smbios1` UUID means cloud-init personalises it, and new host keys on a **reused address** caused a `known_hosts` mismatch. Also the first end-to-end test of the Cockpit + `nofail` build-script changes — **both passed** |
| **J-P3** | The apt install misleads twice: the **unversioned key filename is the OLDEST key** (dead since 2023), and the `jenkins` package **declares no Java dependency**, so it installs cleanly and cannot start |
| **J-P4** | Six deliberate plugin choices → **73 installed plugins**; and `ssh-agent` ≠ `ssh-slaves`, so the build standard's own list omitted the plugin its own topology needs |
| **J-P5** | The split, **proved with a queued build before the agent existed**. Plus: the agent can read `credentials.xml`, and `Running as SYSTEM` is a second privilege plane |

**Two decisions closed on the record.** Agent transport = **SSH**, argued from lifecycle ownership
(with SSH the controller can restart a dead agent; with JNLP it can only wait) rather than from
convenience — ledger row **J2** covers the cost of co-locating it. And patching policy: every VM's
`unattended-upgrades` and `apt-daily*` timers are **masked**, with `refresh.sh` the only path,
`.185` added to it.

📖 **Education track 3 opened** — `education/jenkins/README.md` + chapter 1, figure `figcheck`-clean
at 10.2 pt, highlighted to 20.1 % at drafting time, DOCX built, and the track indexed in
`education/README.md`. ⚠️ **There is deliberately no chapter 0** — Part 0 is the "assume it" plumbing
`CONVENTIONS.md` tells you to cut.

---

## 🩹 LAB-WIDE `nofail` SWEEP + a security find on .184 (Aug 20, 2026, ~12:38–12:50 PM EDT) ✅ DONE

🙋 **Andrew: "let's fix the nas issue on all current VMs."** Then, mid-sweep:
**"184 should NOT mount the NAS! It's prod-local."**

**Done: all 9 VMs + this dev workstation now show `RequiredBy=` empty.**

| Host | Before | After |
|---|---|---|
| .180 qa, .181 gitlab, .182 runner, .183 sonar, .186 redpanda, .191–.193 swarm, .195 dev | `RequiredBy=[remote-fs.target]` (.180 already fixed) | `RequiredBy=[]`, `WantedBy=[remote-fs.target]`, mounts untouched |
| **.184 www** | had the mount **and** it had been **failing every boot since July 9** | 🚫 **entry removed entirely** — see below |

**Method** (`working/fix_nofail.sh`, re-runnable): back up fstab → edit only the one CIFS line →
restore automatically if the edit doesn't verify → `daemon-reload` → assert `RequiredBy=` empty →
assert the live mount survived. Canaried on **.193** (least critical) and the swarm was re-checked
before touching anything else; **.181 GitLab went last-but-one and the dev box last.**
⭐ **The raw `sed` is NOT idempotent** — run twice it appends `nofail,nofail`. The script's
"already has nofail?" pre-check is what makes it safe, and a throwaway test caught that before it
ever touched a host.

### 🚫 The .184 find — a build standard leaking credentials into the DMZ

`.184` is the internet-facing PROD box. Phase 12 gave it `OUT DROP -dest 192.168.1.0/24`, so the NAS
is unreachable **by design** — confirmed: ping 100% loss, 445 blocked. Yet the standard build had
given it the NAS fstab entry, which had been failing at **every boot since July 9**, and — the part
that actually matters — had left **`/root/.smbcredentials` on the internet-facing host** for a share
it is forbidden to touch.

Removed: fstab line, mount unit, `/mnt/DevShare`, credentials file. Verified nothing referenced the
path (no container bind-mounts; only stale Cursor logs from January). **PROD re-checked after:
all 6 containers up, :80 → 301, :443 answering. Zero failed units.**

⭐ **The lesson: a uniform build standard will plant credentials on exactly the hosts your network
design isolates.** The firewall did its job perfectly; the **builder** was the leak.

**Two guards added so a rebuild cannot recreate it:**
- `bash host_setup.sh --no-nas` — deliberate skip for a prod-local host.
- **`setup_smb_mount.sh` now pre-checks `<nas>:445` and refuses** to write fstab or credentials if it
  cannot connect. ⭐ The better of the two, because it needs nobody to remember anything.
  **Proven by running it on .184 itself:** refused, wrote nothing, host stayed clean.

⚠️ **Gotcha found by testing:** `SKIP_NAS=1 sudo -E …` **does not work** — sudo has `env_reset`, warns
*"preserving the entire environment is not supported"*, and silently drops the variable, so the script
ran in full on the dev box. Harmless there (everything already existed), but the documented invocation
was wrong and is now `sudo SKIP_NAS=1 bash ./setup_smb_mount.sh`. 🧠 **Testing the happy path is not
testing the guard.**

### ⚠️ CORRECTION — we overstated what missing `nofail` costs

Earlier today this was written up as *"drops to an emergency console, no network, no SSH."* **That is
wrong**, and `.184` disproves it from inside our own lab: it failed this mount at every boot for six
weeks and came up fine each time. `_netdev` already keeps these entries out of `local-fs.target`; the
emergency-console behaviour belongs to network mounts written **without** `_netdev`. Real cost of
`_netdev` without `nofail`: a **bounded boot delay** (11 s measured, ~90 s worst case) and a
permanently failed unit. Worth fixing — not a catastrophe. 🧠 **A plausible mechanism was asserted
instead of checked, while the host running the experiment sat one `systemctl status` away.**
Corrected in `MEMORY.md`, the phase-2 doc, and the script comments.

⚠️ **Still unverified:** template **9000** has not been checked for a NAS fstab entry (it is stopped,
and checking means booting a clone). Any VM cloned from it runs the fixed `host_setup.sh` anyway.
👉 Check it during Phase 17 Part 0, when a clone is being made regardless.

---

## 🔧 BUILD STANDARD CHANGED — Cockpit is now on every Ubuntu server (Aug 20, 2026, ~12:25–12:40 PM EDT) ✅ DONE

🙋 **Andrew's call:** *"I think we should make this part of every new ubuntu server we build… make sure
we do it the safe way like you said."* Triggered by installing Cockpit by hand on `.186` earlier today.

**What changed — three files, all in the build path:**

| File | Change |
|---|---|
| `www/scripts/setup_cockpit.sh` | 🆕 **NEW.** Installs Cockpit; detects the network stack; **simulates the install and exits 1 if `network-manager` would appear** |
| `www/scripts/host_setup.sh` | Downloads and runs it in **Phase 1**, next to SSH and sudo |
| `www/scripts/setup_smb_mount.sh` | 🩹 **Unrelated bug found and fixed:** fstab got `_netdev` but **not `nofail`** |

⭐ **The design decision worth remembering: the script enforces the rule instead of documenting it.**
The obvious implementation was "write down the safe package list and trust future-us to use it." That
fails the first time someone in a hurry types `apt install cockpit`. Instead `setup_cockpit.sh` runs
`apt-get install -s`, greps the result, and **refuses to continue** if NetworkManager shows up on a
host that does not already use it. It also *adds* `cockpit-networkmanager` on hosts where
NetworkManager **is** active (desktop builds), so the rule is "match the host", not "never install it".

**Measured, not assumed** (dry run on swarm node .191, which has no Cockpit):

| Install | Packages added | Pulls network-manager? |
|---|---|---|
| `apt install cockpit` | **35** | **YES** + `dnsmasq-base`, `ppp`, `pptp-linux`, `wpasupplicant`, `wireless-regdb` |
| Our explicit list | **19** | No |

🩹 **The `nofail` find.** Chasing "where do we document server builds" led into `setup_smb_mount.sh`,
which wrote `_netdev` **without `nofail`** — so every VM ever built by the standard script carried it.
Fixed at the source, then **swept the whole lab (see the next block).** 🧠 **The lesson: when a per-VM
fix works, immediately ask whether the builder has the same bug.** Fixing the VM fixes one VM; fixing
the script fixes every future one.

**Verified:**
- `bash -n` clean on both scripts.
- Re-ran `setup_cockpit.sh` **on .186 where Cockpit already exists** — correctly reported "already
  installed, nothing to add", left the network stack alone, confirmed :9090 listening. **Idempotent.**
- Both scripts serve HTTP 200 from `http://192.168.1.195/scripts/`, and the served copies contain the
  guard and the `nofail` option — so a build started right now would pick them up.

**Not yet proven:** no VM has been built end-to-end with the new `host_setup.sh`. 👉 **Phase 17 Part 0
(the Jenkins VM) is the first real test**, and Part 0 now says so explicitly.

---

## 🔧 UNPLANNED INTERRUPT — QA server re-numbered 200 → 180 (Aug 20, 2026, ~11:25–11:40 AM EDT) ✅ DONE

🤖 **AI-executed infrastructure plumbing, Andrew approved the 8-step plan and said "go ahead."**

**What and why.** The QA box was **VMID 200, hostname `vm-kubernetes-1`, IP `.180`** — a VMID that didn't
match its IP and a hostname advertising Kubernetes it has never run (it runs **Capricorn QA on plain
`docker compose`**, not even Swarm). It is now **VMID 180, `vm-docker-qa-1`, `.180`**, matching the
`18x → .18x` convention every other VM follows. 🚨 **Proxmox cannot re-number a VM in place — "renumbering"
is always a clone**, which is why this was a copy-and-validate job rather than an edit.

**The old VM 200 is STOPPED with `onboot 0`, deliberately kept as the rollback until ~Sept 3, 2026,
then destroy.** It costs disk only; a stopped VM reserves no RAM or CPU.

⚠️ **Two hazards found before starting, both real:**

1. **The CIFS mount in `/etc/fstab` had no `nofail`** — an unreachable NAS could hang boot. Fixed on the
   original before cloning, so both VMs carry the fix. **Proof it worked is not the fstab line, it's
   the generated unit:** `systemctl show mnt-DevShare.mount` went to **`RequiredBy=` empty,
   `WantedBy=remote-fs.target`** — a *want*, not a *requirement*, so a dead NAS can no longer block boot.
2. **No cloud-init drive on this VM, so the IP is static inside the guest** — the clone claims `.180`
   too. **`onboot 0` on VM 200 is therefore load-bearing, not tidiness**: without it a host reboot
   starts both and they fight over the address.

🚨 **The snapshot outlives the fix: `pre-clone-20260820` still records `onboot: 1`.** Rolling VM 200 back
during the validation window **re-arms autostart** and re-creates the IP collision. `qm config 200`
shows the live value; `qm config 200 --snapshot <name>` shows the snapshot's — they differ, and reading
the raw `200.conf` shows *both* pairs, which is easy to misread.

**Three things that did NOT break, each worth knowing:**

| Survived | Why |
|---|---|
| **Networking, despite a new MAC** | The clone got `BC:24:11:20:08:8B` (was `…DB:8D:CD`). Netplan here matches on **interface name `ens18`**, not MAC, so `.180` came straight back. Had it matched on MAC the box would have booted deaf — the escape hatch was **`agent: enabled=1`**, since `qm guest exec` runs over virtio-serial and needs no network at all |
| **SSH from the dev box** | A clone keeps the **same host keys**, and the IP didn't change, so `known_hosts` needed no clearing |
| **`refresh.sh`** | It targets hosts **by IP, not VMID**, so re-numbering was invisible to it. Only its comment block was wrong |

**Verified after a deliberate cold stop/start** (not just after the clone boot): hostname persisted, NAS
auto-mounted, **zero failed systemd units**, all four `capricorn-*` containers up on their own restart
policies, `:5001` and `:5002` both **HTTP 200** from off-box. Snapshot **`q01-cloned-verified`** taken.
Docker's restart policies brought the stack back with no intervention.

✅ **CLONE ACCEPTED — Andrew re-ran the last Capricorn QA deployment from GitLab and it worked.** So the
**stored CI credentials still authenticate against the renamed host**, and **key-based SSH from the dev
box still works with no password**. That closes the migration: nothing in the pipeline referenced the
VMID or the hostname, only `192.168.1.180`. ✅ Independently swept — **no `/etc/hosts`, `~/.ssh/config`
or `known_hosts` entry on `.181`–`.184` or the dev box ever named `vm-kubernetes-1`.** Everything in
this lab addresses that box by IP, which is exactly why a re-number was cheap.

🚨 **AUTOSTART LOCKED DOWN (Andrew, same session): only 180, 181, 182, 183, 184 come back after a host
reboot.** **186 and 191/192/193 were all `onboot 1` and are now `onboot 0`** — they were quietly
starting themselves. ⚠️ **This means the Docker Swarm is DOWN after any host reboot**, so
`qm start 191 192 193` becomes a **prerequisite for Phase 17's Jenkins→Swarm deploys**, not an
afterthought. **Boot order also set** — GitLab first with a 60 s head start, then 182/183, then 180/184.
Both recorded in `MEMORY.md` → *AUTOSTART POLICY*. ✅ Verified **no HA resources and no cluster**, so
`onboot` is the only thing that can start a guest.

📸 **Snapshot `q02-qa-deploy-verified` taken OFFLINE** (VM shut down first, so disk state is consistent
by construction rather than by fs-freeze). It captures the accepted post-migration baseline: GitLab
deploy re-run successfully, `onboot=1`, `startup order=3`. ✅ **Unlike VM 200's snapshot, this one
records the CORRECT `onboot` value**, so rolling back to it is safe. VM 180 was restarted and
re-verified afterwards: no failed units, NAS mounted, four containers up, `:5001`/`:5002` HTTP 200.

🖼️ **Fixed the one stale reference outside the docs: `education/k8s-k3s-redpanda/diagrams/ch01_fig1_stack.dot`**
labelled a box `VM 200 / QA/k8s / .180`. Now `VM 180 / QA / .180` — **the "k8s" label was always wrong
and actively undercut that chapter**, whose whole point is that VM 186 is the only k3s box. PNG
re-rendered and **chapter 1's `.docx` rebuilt; the other six were left alone, so no rebuild noise.**
⚠️ **Known and accepted limitation:** the figure still omits 191–193 (built Aug 13, after the chapter)
and 185. It depicts the lab as of the k3s track and is not a live inventory.

📌 **RULING — VM 180 gets NO backup. Built, proven, then removed the same hour on Andrew's
instruction.** The AI created `nas-docker-qa` + a nightly job and proved it with a real run (live
`snapshot`, **2m20s, 10.66 GB**, `gmail-smtp` notification, artifact confirmed on the NAS). Andrew:
*"VM180 does not need backups. Remove the one you added."* **All of it is gone** — job, archive,
storage, credential file, local mountpoint, and the NAS folder. Verified: one storage list, one job
(`gitlab-nightly`), four `.pw` files. ⭐ **The reasoning generalises and is the part to keep: QA is
rebuilt by GitLab CI on every deploy, so it is a deploy target, not a data store. Only irreplaceable
state earns a backup.** 🚨 **Do not re-add it as a "helpful" gap-fill.**

📊 **Two things worth keeping from the exercise anyway.** Sizing: **80% of that 100 GB disk was zeros
and was sparse-skipped**, so archive size tracks *used* data, not provisioned size. And teardown:
`pvesm free` clears the archive but **PVE's `dump/` subdir survives and the CIFS dentry cache lies
about it** — `ls`/`find` showed a `dump` directory that `stat`/`rmdir` said did not exist and `rm -rf`
refused as *"Directory not empty."* **A fresh mount with `noserverino` fixed it instantly.** A deleted
folder may still enumerate as `d????????? ? ?`; `test -d` is the honest check. Full note in
`proxmox/Home_Lab_Proxmox_Storage.md`.

🚨 **The wider coverage gap is REAL and still open, and 180 is now deliberately part of it.** The lab has
**exactly one scheduled job** (`gitlab-nightly`, 181). Swarm nodes 191–193 have NAS storages but only
**one hand-made dump each from Aug 13, no schedule**; **180, 184, and 186 have nothing.** ⚠️ **Don't
infer coverage from `pvesm status` — read `/etc/pve/jobs.cfg`.** ⭐ **184 is the one that should still
bother us**: unlike QA it runs Capricorn **PROD** and the public site, so the "rebuildable" argument
that justifies skipping 180 does **not** cover it. **Andrew's call, not raised as urgent.**

🔁 **REPEATED A DOCUMENTED MISTAKE — worth reading, because the trap caught two different sessions.**
Four manual `mount -t cifs` attempts from `.150` all returned **error(13) Permission denied**, *including
the exact path `nas-gitlab` already mounts successfully*. The AI first concluded the credential in
`PASSWORDS.md` was stale. **It is not.** 🚨 **`/etc/pve/priv/storage/<id>.pw` contains `password=<value>`
plus a newline, NOT a bare password** — so its 19 bytes are `password=Powerme!1`, and passing
`$(cat …pw)` as the password sends the literal string `password=Powerme!1`. **`MEMORY.md` already
warned about this** (same sub-bullet, from a Jul 2026 session that made the identical error and had to
retract a fake "credential outage"). ⭐ **The lesson that didn't stick the first time: a byte count is not
a value.** Reading the existing note before probing would have saved all four attempts.

⚠️ **Attempts were stopped at four deliberately** — Synology-style auto-block trips around five failures
and would blackhole the Proxmox host's IP, killing the nightly GitLab backup and every guest's
`/mnt/DevShare`. ✅ **No harm done — re-verified afterwards:** all four NAS storages `active`,
`pvesm list nas-gitlab` works, a write-and-delete into it succeeded, and `.180`/`.181` still have
`/mnt/DevShare` mounted.

**Docs updated:** `MEMORY.md` (4 places), `README.md` (also corrected OpenClaw from "retired" to
destroyed), `refresh.sh` comment — **and re-deployed to `/usr/local/bin/refresh.sh`, which was
byte-identical to the repo copy beforehand and is again now.** `SYSTEM_VERIFICATION.md` was **banner-ed
as a stale historical snapshot rather than edited** — it is a dated Jan 14, 2026 report, and it is
missing five VMs and understates GitLab's RAM. Historical phase files 2/4/5/7 left untouched.

---

## ▶️ RESUME HERE — 🔵 PHASE 17 (JENKINS): **Parts 0, 1 and 2 are DONE (Aug 20, 2026). Next is Part 3 — wire it to GitLab.**

🔻 **AND THE DELIVERY MODEL WAS REPLANNED at ~4:30 PM (log entry J-P7) — read that before Part 3.**
Parts **4 and 5 are swapped** (deploy now precedes build), and there are two new hard rules, **B10**
(registry write scope) and **B11** (SHA tags). Nothing was built during the replan; it was all
discussion, and it changed the plan enough that acting on the pre-4 PM version would be wrong.

**Read `phases/phase17_jenkins.md` before touching anything Jenkins-related.** Where things stand:

⛔ **ALREADY DONE AND IRREVERSIBLE — VM 185 `vm-openclaw-1` is destroyed.** Andrew ordered it killed
with **no backup** (declined on purpose) and none existed; no snapshot had ever been taken. Verified
gone: config file, ZFS volumes, and `/etc/pve/firewall/185.fw`. **Do not look for a way to restore it —
there isn't one, and that was the decision.** Full record: `phase11_openclaw.md` → "CLOSED". It gave
back **16 GB and 12 cores** (⚠️ the resource table had said 8 cores). Two facts it invalidated, both
corrected in `MEMORY.md`: **no VM runs Tailscale any more**, and **only `.184` still has PVE firewall
rules.**

✅ **A1 and A2 both answered Aug 19: no DNS — bookmark `http://192.168.1.185:8080/` — and no TLS in the
lab.** Nothing in the plan is open now.

- **No TLS is ledger row J1**, accepted knowingly. It is a real compromise: the session cookie of a CI
  controller is a credential to everything it can deploy.
- **No DNS is cosmetic — because the address is static.** The one caveat: if `.185` ever moves, five
  things need hand-editing (Jenkins URL, webhook URL, agent config, bookmark — the OAuth redirect is
  gone now that A8 killed OAuth). In the
  chapter it is a Lab-vs-PROD **table row**, not a callout — smaller, not wrong.
- 🚨 **Trap T8 is NOT a consequence of skipping DNS**, though this file said so for one revision.
  **GitLab blocks webhooks by RESOLVED ADDRESS**, so a hostname pointing at `192.168.1.185` is blocked
  identically. T8 exists because the controller is on a private network at all.
- ✅ **T8's precondition is now VERIFIED (🤖 AI-executed, read-only) — the trap CAN fire.** Measured on
  `.181`: `allow_local_requests_from_web_hooks_and_services = false`, allow-list empty. Checked because
  **Phase 16's C2 could not fire at all** and nobody had looked. ⭐ **Bonus finding worth keeping:
  system hooks are ALLOWED to reach local addresses while project webhooks are BLOCKED — same instance,
  same target.** So "GitLab blocks outbound LAN requests" is false as a general statement; it depends on
  which subsystem asks. Full detail: `phase17_jenkins.md` → log entry **J-P1**.

~~🔲 **NEXT ACTION — Part 0, steps 2–5.**~~ ✅ **SUPERSEDED Aug 20 — Parts 0 and 1 are both complete.**
🙋 **Andrew ran every command himself**, one step at a time, at his request.

**Where Jenkins actually is right now** (all verified against the API and `ps`, not read off a screen):

| | |
|---|---|
| Jenkins | **2.568.2 LTS** on Java **21.0.11**, `http://192.168.1.185:8080/` (URL saved correctly) |
| Login | local admin `agamache` — credentials in `PASSWORDS.md`. ⛔ **NOT a "break-glass account"** — that phrasing was wrong and is corrected in J-P6. Real break-glass is **root on the host** editing `config.xml` with Jenkins **stopped first** |
| Authorization | ✅ **matrix-based since Part 2**: `agamache → Overall/Administer`, `authenticated → Overall/Read`. The wizard's "any authenticated user has full control" default is closed |
| Executors | controller **0**, node `jenkins-agent-1` **2**, label `swarm-deploy` |
| Agent | SSH → `127.0.0.1` as OS user `jenkins-agent` (no sudo, no extra groups), host key **pinned**, private key **only** in the Jenkins credential store |
| Plugins | 73 installed from **6** deliberate choices, plus `ssh-slaves` added by hand |

📓 Findings written up as **J-P3** (expired apt key + undeclared Java dependency), **J-P4** (the plugin
list problem), **J-P5** (the split, and what the agent can still read). New ledger row **J2**
(agent co-located with the controller). A5's transport question is closed in the plan.

🔲 **NEXT ACTIONS, in order:**

1. ✅ **Snapshot `j02-jenkins-up` taken** (VM shut down for it, restarted clean).
2. ✅ **Chapter 1 and the track README are written** (`education/jenkins/`), figure rendered and
   `figcheck`-clean, DOCX built. ⚠️ **The track is now indexed in `education/README.md` as track 3**,
   so a future session should update that row as chapters land.
3. ✅ **Part 2 DONE and RESHAPED — see J-P6.** 🔻 **OAuth was DROPPED for good (decision A8)**, because
   Andrew's firm uses GitHub and because coupling the login to GitLab puts an instrument inside the
   system Part 6 exists to break. Auth is now **local accounts + matrix authorization**
   (`agamache → Administer`, `authenticated → Overall/Read`). Two attempts to lock ourselves out both
   **failed by design** — matrix-auth pre-seeds and then silently restores your own `Administer`,
   with no UI warning and nothing in the log. 📕 The **break-glass runbook is written but ⚠️ NOT
   rehearsed**; it is marked `recited`, not `verified`.
4. ✅ **DELIVERY MODEL REPLANNED (J-P7, ~4:00–4:35 PM) — discussion only, nothing built.** Andrew's
   correction started it: this lab has **three** delivery paths, not two. `production/capricorn`'s own
   pipeline ships the real app to QA `.180` and PROD `.184`; this repo's `.gitlab-ci.yml` is the Phase
   16 exercise; Jenkins is the third. **The registry-overwrite hazard is invisible until you count
   three.** Decisions **A9/A10/A11** closed, rules **B10/B11** added, ledger rows **J3/J4** written,
   and **Parts 4 and 5 swapped.**
5. ▶️ **NEXT — Part 3: wire it to GitLab.** Read-only deploy key, webhook, multibranch pipeline with
   **Script Path `education/jenkins/Jenkinsfile`**, and a first `Jenkinsfile` that only checks out and
   prints. Traps **T4** (webhook with no token), **T5** (the workspace that keeps the plaintext mirror)
   and **T1** (moved down from Part 2 — masking needs a pipeline to fire in) all fire here.
   ⚠️ **T8 is also waiting:** GitLab blocks webhooks to private addresses by resolved address —
   **verified true on `.181` (J-P1), so it WILL fire.** Snapshot `j03-gitlab-wired`.
6. 🔲 **Then Part 4 — DEPLOY (this used to be Part 5).** Reuse
   `education/docker-swarm/scripts/deploy_swarm.sh` **unchanged** with `STACK=capricorn-jenkins`,
   against the **existing `:latest` images**, so the only variable versus Phase 16 is the CI system.
   ⚠️ **Needs `education/jenkins/manifests/capricorn-jenkins.stack.yml` on ports 5011/5012** — the
   Phase 16 manifest's 5001/5002 are `mode: ingress` and two stacks cannot share them.
7. 🔲 **Then Part 5 — BUILD AND PUSH (this used to be Part 4).** ✅ **Step 1 is ALREADY DONE — built
   early on Aug 20, harmlessly, because a namespace produces no artifacts.** Group **`lab`** and
   project **`lab/capricorn-swarm`** exist; push target is
   `gitlab.gothamtechnologies.com:5050/lab/capricorn-swarm/<image>`; group deploy token
   `jenkins-lab-push` is in `PASSWORDS.md`, **expires 2026-12-31**.
   ✅ **B10 is PROVEN, not recited (J-P8)** — measured at the registry's auth service: `push,pull` on
   `lab/`, **`pull` only** on `production/capricorn`. ⚠️ **The `pull` is not a scope leak:
   `production/capricorn` is an INTERNAL project, so every authenticated identity can read it —
   a token scope grants, it does not fence.**
   ⏳ **Still owed here:** the end-to-end `docker push` denial, `insecure-registries` for
   `gitlab.gothamtechnologies.com:5050` on `.185` (**it is not set — the push will fail without it**),
   SHA tagging (B11), the two-job split, a registry cleanup policy, and **T2** (the `docker` group).
   📌 **Diarised hazard:** `jenkins-lab-push` and `swarm-lab-pull` **expire at the same instant**
   (2026-12-31 05:00 UTC). Jenkins will fail loudly at build time; the Swarm fails **silently at the
   next task reschedule**. Correlated expiry = two variables changing at once.

🚨 **The one rule that escapes the lab if you get it wrong: B10.** Everything else in this phase fails
locally. Pushing a Jenkins-built image over `production/capricorn/<svc>:latest` reaches **PROD `.184`**
on the next pull.

⚠️ **Do not "fix" what looks unfinished.** `passwordauthentication yes` on `.185`'s sshd, the
world-readable `credentials.xml`, and the agent's lack of Docker access are all **Part 4/7 material or
deliberate** — see the trap table before touching any of them.

📌 **Everything the build needs, and what it costs to skip each one** (verified Aug 19, 9:40 PM — do not
re-probe, just use them):

| Need | Where / value | Cost of not reading it |
|---|---|---|
| The clone recipe | `MEMORY.md` → **CLOUD-INIT TEMPLATE (VM 9000)** | 🚨 **The template disk is 3.5 GB, so `qm resize` is MANDATORY**, and the filesystem only follows if cloud-init's `growpart` fires. **Verify `df -h /` from inside the guest.** If it silently doesn't fire, the VM dies on its first big `docker pull` with an error about *image layers*, not disk space — a genuinely confusing 20 minutes |
| `host_setup.sh` | `wget http://192.168.1.195/scripts/host_setup.sh` → ✅ **HTTP 200, served right now** | The script server is **this dev box**; if it is ever down, start it with `cd www && ./run_www.sh`. It auto-downloads its own sub-scripts (`setup_ssh.sh`, `setup_docker.sh`) |
| Proxmox access | ✅ **`ssh root@192.168.1.150` works keyless from this box** | Don't go hunting in `PASSWORDS.md`; it is not needed for this |
| GitLab access | ✅ **`ssh agamache@192.168.1.181` works keyless, and `sudo` is passwordless there** | Needed in Part 3; `sudo gitlab-psql` is how J-P1 was measured |
| ⛔ Do NOT | look for VM 185 to destroy | **It is already gone.** Part 0 step 1 is DONE |

⭐ **The weighting is Andrew's and differs from Phase 16 — do not silently restore the first draft's
ordering.** *"The most important aspects are that we install, configure Jenkins, we hook it up to
GitLab and the docker-swarm, and we learn about deploying and fixing bad deployments like we did in
phase16 with GitLab."* So **Part 6 (bad deployments and recovery) is the centre of gravity**, and the
Phase 16 hardening charter is **Part 7 — required, but secondary**. The charter is also **scoped on the
record** to L21 + L22 + L12(partial) + agent privilege; its literal wording ("every recited row")
covers six rows, three of which are registry/Swarm work Jenkins cannot fix.

🎭 **The phase runs as a firm-supplied build standard**, at Andrew's request — as if the employer handed
over the spec. 🚨 **The AI does not know their real standard**, so every line is marked 🔧 **MECHANICS**
(true of Jenkins anywhere, and we test it) or 📐 **CONVENTION** (an AI invention standing in for the
firm). **Never quote a 📐 item as "what their firm does."** This is a deliberate deviation from
`METHOD.md` and gets folded back in only if it proves out.

🅒 **Eight planted traps, T1–T8, ⛔ do-not-fix before they fire.** The one worth knowing in advance:
**T7 fires *after* the deploy looks hardened** — the pinned, keystore-held key still has no `command=`
restriction, so it grants a full interactive shell on all three managers.

🚨 **Hard rule B2: Jenkins deploys the stack `capricorn-jenkins`, NEVER `capricorn`.** The Phase 16
GitLab pipeline stays alive and untouched as the comparison — that is why Andrew chose a separate name.

---

## 🟢 PREVIOUS — PHASE 16 CLOSED (Aug 19, 2026). Nothing outstanding.

**Phase 16 (Docker Swarm) is DONE: all 7 parts, all 7 planted traps, 8 chapters.** Part 7 closed on
Aug 19 as `education/docker-swarm/chapter08_swarm_vs_kubernetes.md` — the Swarm↔Kubernetes crib sheet
the whole two-track comparison was for.

**What chapter 8 is, in one line:** every claim carries a provenance mark — **S** (measured on the
three-node Swarm), **K** (measured on single-node k3s), 🤖 (measured only in AI-executed chapter 7), or
⚠️ **recited** (neither lab ran it, so it must never be quoted as experience). ⭐ **Reuse that device
for any future cross-track writing;** without it a synthesis chapter launders textbook claims into
apparent experience. Its two non-obvious conclusions: **the PVC abstraction is not what protects your
data** (the k3s lab's `local-path` strands it on the same nail as a Swarm named volume — the value is
the driver ecosystem, not the object), and **Swarm's digest-pinning default is the safer of the two
image models**, which is the opposite of the usual narrative. It also caught one flattering falsehood
in its own first draft (see the phase file, Part 7 → C1): "encrypted Raft log by default" is **wrong**,
and chapter 1's own Lab-vs-PROD callout says so.

⚠️ **What is actually left — and the claim that was wrong here for a day:**

1. 🚨 **Drill D is NOT outstanding. It ran Aug 18** (P30 ✅ smoke gate is the only thing that catches a
   rotated secret, P31 ✅ Postgres keeps the old password, plus the `pg_hba.conf` `trust` discovery and
   chapter 5's row D). **This block said "outlined but never run" until Aug 19 and the `MAKE_MEMORIES`
   pass that evening repeated it into `MEMORY.md` as the phase's only open item.** The cause: the
   drill's planning entry in the phase file still had an unticked `🔲` box, and the summaries were
   edited without being diffed against the results 1,900 lines below. ⭐ **Re-read what you summarise.**
2. ✅ **MEASURED AND CLOSED Aug 19, 7:55 PM — the `redis` divergent-volume question. 🤖 AI-executed,
   read-only, at Andrew's instruction.** The hypothesis was **refuted**: `.191` has never held a redis
   volume, and the two volumes that do exist (`.192` Aug 13, `.193` Aug 18 19:06:56) are **trap C3's
   deliberate residue** — the numbers match C3's own write-up. `.192` holds `c3:canary` + `c3:counter`
   (155 b, AOF generation 2); `.193` is **88 b with zero keys** (AOF generation 1, a fresh start). The
   live task has run since Aug 18 with `RestartCount 0`. Nothing was lost.
   🚨 **The real finding is why the question existed: `docker service ps`'s `CURRENT STATE` age is the
   last time the MANAGER STAMPED the task's status, not the task's age.** Task `CreatedAt` Aug 18
   23:14:24 UTC vs `Status.Timestamp` Aug 19 16:11:15 UTC — 20 hours apart, and it is the *stamp* that
   renders as "Running 8 hours ago". The stamp moves on control-plane churn, so **a day-old task can
   look freshly rescheduled.** Clock skew was excluded by measurement (all three nodes NTP-synced, agreed
   within 1 s). Now in `COMMANDS.md` as its own section, with the commands that answer each question.
   ⚠️ **Standing hazard left in place, not fixed:** the empty 88-byte volume still sits on `.193`, so
   `redis` scheduling there would silently attach an empty cache. Removing it is destructive and it is
   C3's evidence — Andrew's call, not a cleanup step.
3. **Deferred to Phase 17 on purpose:** the rigorous convergence check that compares each service's
   `.Version.Index` across a deploy instead of trusting the settle delay. Recorded as a mitigation, not
   a proof.

✅ **DONE the same evening — the highlight programme, both tracks (Aug 19, ~5:30–6:30 PM).** Andrew
raised the target to **20 %** after a trial he judged from the printed page, not the number. **All 15
chapters now sit at 19.5–21.2 %** (Swarm ch1/2/4/5/6 were at 2.3–3.6 %, i.e. 5–6 marks each; the k3s
track was at 12.6–14.9 %). Full before/after table and method: **`phases/phase15_education_program.md`
§8** — that section is the one to read before any future highlight work, for two reasons:

- ⭐ **Measure density PER SECTION, not per chapter.** k3s ch3 read 14 % overall while §5/§7/§8 sat at
  7.2/6.2/4.9 % — drafting-time marks cluster where the argument is and skip walkthroughs. A list aimed
  at the chapter average would have pushed the dense sections past 30 % and left the thin ones alone.
- 🚨 **A mark that swallows one half of a `**bold**` pair renders the asterisks LITERALLY in the
  `.docx`.** 15 marks were doing this across both tracks. `education/tools/highlight.py` now **refuses**
  that, and also refuses a mark opening inside an already-open mark (which had nested one in k3s ch4).
  ⭐ The Markdown passed every check that existed; the defect existed **only in the built artefact** —
  so verify the artefact (`unzip -p x.docx word/document.xml`, grep for literal `**`), not the source.
  ⚠️ The old blanket rule "never re-run `highlight.py` on a highlighted file" applies only to re-running
  the **same** list; a **top-up with a list of only-unmarked phrases is now the normal workflow.**

✅ **Cluster state at handoff: HEALTHY, and re-verified AFTER C7's cleanup** — not assumed. All three
`Leader/Reachable/Reachable`, raft churn `0`, services `2/2 3/3 1/1 1/1`, all three smoke gates green at
`total=682` (**identical to the pre-C7 baseline**), `docker stack ls` shows `capricorn` only.

⚠️ **OBSERVED, not caused by C7, and NOT "fixed": `docker-swarm-3` hosts ZERO Capricorn tasks.**
Placement is `swarm-1: 4, swarm-2: 3, swarm-3: 0`, with task ages of 2–5 hours — so this predates the
C7 session and dates from `qm stop 193` during the P48/P50 tests. ⭐ **Swarm does not rebalance when a
node comes back.** Every service still reads its desired count, so **`2/2 3/3 1/1 1/1` is true while a
third of the cluster sits idle** — the same family as chapter 5's "reboot that silently cost three
replicas". 🙋 **Left alone deliberately:** the only remedy is `docker service update --force`, which
restarts tasks (and, per C7 P55, restarts them on the *pinned* image) — that is Andrew's call, not a
cleanup step. **Chapter 5 / Part 7 material: capacity is not replica count.**

⭐ **`s07-c4-fixed-verified` taken on all three nodes** (rule B3) before C7 started. **It is the first
snapshot in the chain that contains the C4 fix** — `s06` predates it, which was a standing rollback hazard.

✅ **CORRECTED — the previous handoff claimed "`.191` still holds the PRE-FIX `deploy_swarm.sh`". That is
FALSE as of Aug 19 4:15 PM:** the node's copy and the repo copy are **md5-identical** (`0bf970b7`), and the
P4-F8 advisory string is present on the node. ⚠️ **A recorded claim about live state went stale within
hours, and the fix was to go and look** (`md5sum` on both sides) rather than to trust the handoff. Same
failure family as the P48 row that stayed "NOT TESTED" for hours after passing.

### ✅ CLOSED — trap C7, and the trap could not fire (🤖 AI-EXECUTED, 4:10–4:50 PM)

🤖 **Andrew's written instruction, 4:07 PM: run it and document it without him.** So C7 is the ONE part of
this track the AI drove. **Declared in chapter 7's opening, in the track README, and in `MEMORY.md`** —
`CURSOR_RULES` rule 3 and `METHOD.md` → "Who does the work" both apply, and the material is deliberately
marked **weaker** than the six chapters Andrew drove.

**The planted trap was unfireable** (P60 ✅): `docker stack deploy` re-resolves by default, so the spec
followed the moved tag every time. **But "I pushed a fix and prod is still running the old code" happened
twice anyway**, by mechanisms the plan never considered:

- 🚨 **The deadlock (unplanned, the session's best finding).** `order: start-first` + `max_replicas_per_node: 1`
  + `replicas == node count` **cannot make progress** — the replacement task has nowhere to go. Sat
  `updating` / `update in progress` for **4.5+ minutes** at a healthy-looking `3/3` while serving the old
  build. ⭐ **Exact mirror of C6a**, which read `4/3` because the cap was unset. ⚠️ Capricorn is NOT exposed
  (all four services measured at `maxPerNode=0`).
- **`docker service update --force` restarts the OLD build and prints `converged`** (P55 ✅). This also
  **corrected a FALSE claim in `COMMANDS.md`**, which said `--force` would ship whatever `:latest` points at.
- 🚨 **Two builds served from one URL** (P58 ✅): a registry blip during a deploy **strips the digest**
  (P57 ✅), after which each node resolves alone. Measured `3/3`, `UpdateStatus: completed`, and **10 of 30
  requests served v3 while 20 served v4**.
- **P56 ❌ REFUTED:** `--resolve-image never` **preserves** the pin. ⭐ A pin is stripped by a resolution
  that is **attempted and fails**, never by one that is skipped.
- **P59 ✅** the protective face: with the pin intact, a killed task's replacement came up **v4, not the v5
  in the registry**. Same mechanism as P55, opposite consequence.

**Scored P54–P61 (2 wrong, and the wrong ones taught more), 10 findings C7-F1–F10, ledger L23.** Cleanup
done and verified: stack/images/rig/`/etc/hosts` removed, `.191`'s registry credential **restored and
confirmed to belong to `swarm-lab-pull`** (root login had overwritten it — one credential per registry host
per node), and the throwaway GitLab container repository **destroyed** (0 remaining).
Raw evidence: `education/docker-swarm/scratch/c7_evidence.txt`; rig in `scratch/c7/`.

### ✅ CLOSED — the C4 fix is verified, not recited (P48 + P50, 2:40–2:48 PM)

Both previously-unexecuted paths have now run against a genuinely degraded cluster (`qm stop 193`, chosen
because it hosts no pinned service, so the app stayed healthy and the variable stayed isolated):

- **P48 ✅ precondition.** Pipeline failed in **3 s** naming `docker-swarm-3(Down/Active)`, vs **5 min 10 s**
  and a *wrong* answer pre-fix. `docker login` never ran — a refused deploy touches no credential.
- **P50 ✅ counting**, through `ALLOW_DEGRADED=1` by hand on `.191`, phantoms confirmed present **first**
  (`backend 3/2`, `frontend 5/3` — one ghost and two, reconciling exactly against task placement):
  `all services converged`, all three smoke gates, `total=682`.

🚨 **Two findings worth carrying, both bigger than the bug.** (1) **The precondition made the counting fix
unreachable** — it halts upstream of the poll in exactly the scenario the poll was written for; ⭐ *an early
guard can render a downstream path untestable*, which is the better reason the escape hatch exists.
(2) **The old logic would have spent 300 s reporting a FAILED DEPLOY on a demonstrably healthy application**
— the smoke gates in the same run are the ground truth. A false red, in our own tooling, for a day.
⭐ **Our poll now disagrees with `docker service ls` on purpose and is right to** (`3/2`/`5/3` vs `2/2`/`3/3`):
`Replicas` counts tasks Swarm cannot confirm dead; we count tasks Swarm still wants alive.

Raw logs: `scratch/c4_job_log_p48_degraded.txt`, `scratch/p50_allow_degraded_converged.txt`.

### ✅ CHAPTER 3 IS COMPLETE (3:2x PM) — incident written up, figure 2, highlight pass, docx

- **§7 retitled** "One node, three lies: a false count, a broken checker, and a deposed leader" — the old
  title stopped describing the section once the restart incident went in. Four new subsections cover the
  blind spot, the term/index mechanism, why doing nothing was right, and the advisory fix.
- **Figure 2** `ch03_fig2_term_inflation` — the disruption loop. ⚠️ **Sizing is not free-form:** `figcheck.py`
  enforces ≥10pt rasterised, and the build scales every figure to the 7in box, so **raw aspect ratio sets
  the font size**. One column = 8.7in tall (overflows); one row = 18in wide (4.2pt); two pairs on shared
  ranks = 9.0pt (rejected). One shared rank landed it at **12.5pt**. All 8 track figures now pass.
- **Highlight pass DONE** — 113 marks, **16.7%** of prose. Anchors: `scratch/ch03_anchors.py`.
  ⚠️ **Never re-run `highlight.py` on this file.** A first pass hit 22.9% because anchors were whole
  sentences; ⭐ *marking a whole sentence defeats the purpose — if everything is marked, nothing is*, so
  they were cut to the operative clause. Multi-line anchors work (the markdown is hard-wrapped).
- **docx rebuilt** and verified inside the zip: 249 `Key` runs, both figures embedded, footer present,
  **zero literal `custom-style` leakage** into body text.
- **Corrections made in the same pass:** a stale `(§6)` cross-reference that should have been `(§7)`, and
  `COMMANDS.md`'s claim that the "swarm does not have a leader" message can be trusted — today it appeared
  with **quorum fully intact**, so §9 now has a subsection on diagnosing it from a *different* node.

### 🔲 Found while doing this: the Swarm track never got a real highlight pass

| Track | Marks per chapter |
|---|---|
| `k8s-k3s-redpanda` | 33, 38, 39, 42, 45, 45, 103 — a real ~15% pass |
| `docker-swarm` | **5, 5, 6, 6, 5** (ch1, 2, 4, 5, 6) — incidental marks only, not a pass |
| `docker-swarm` ch3 | **113** ✅ (done today) |

⭐ Chapter 3 is now the only Swarm chapter that can be revised from its marks. The other five need anchor
lists (~40 each). Not urgent, but it is an inconsistency inside one printed track, and the anchor lists live
in gitignored `scratch/`, so they are not recoverable from a clone — see the accepted debt note in
`CONVENTIONS.md`.

### 🔲 Also open, smaller

- **Unmeasured: did unpinned `redis` silently lose its volume during the C4 outage?** In the 2:07 PM dump
  `capricorn_redis.1` was `Running` on `docker-swarm-2`, started ~2h earlier, i.e. right at the outage. If
  it was on `.191` before, it rescheduled onto `.192` against a **fresh empty local volume** — trap C3's
  mechanism, occurring for real, unnoticed, inside a different drill — and **two divergent volumes now
  exist**. Check: `docker volume ls` on both nodes, `redis-cli DBSIZE`. **Do not write it up until
  measured.**
- **Untested by design:** the rigorous settle-delay variant (compare each service's `.Version.Index`
  across the deploy, trust `UpdateStatus` only for services whose index moved). → Phase 17.
- **No snapshot was taken today.** Andrew declined `s07-c4-fixed`; the chain is still `s01→s06`. `s06`
  predates the C4 fix, so rolling back loses it.
- 🔲 **Unchanged from before:** **GitHub push held** (chapters unreviewed + the redaction question below);
  the two app-repo findings (bootstrap committed-delete; unauthenticated destructive endpoint —
  `working/`); **Part 7 Swarm↔K8s crib sheet** (now the last substantive Phase 16 item);
  `docker-admin.sh` design session (COMMANDS.md §11 is its spec).

⚠️ **Decision deferred, do not lose it:** L19/L20/D6 (and now L21/L22) in
`phases/phase16_docker_swarm.md` describe a working attack path on the lab in tracked, GitHub-bound files.
Andrew's call (Aug 19) was **"deal with it at GitHub-push time, in one review pass with the chapters."**
`push_github.sh` cannot catch this — its gates look for key blocks and passwords-in-URLs, not prose.
**No secret VALUES are in tracked files.**

**Lab state (verified by the 2:14 PM pipeline, from the cluster):** all three nodes up, stack
`2/2 3/3 1/1 1/1`, **682 rows**, all three smoke gates green. `.191` was stopped and restarted today, so
**the leader has moved — do not assume `docker-swarm-1`** (it went to `.193` during the outage; leadership
is not sticky, now observed four times). `/home/agamache/swarm-ci/{scripts,manifests}` exists on `.191`
**and `.192`** (both have been deploy targets). Old temp files `/tmp/capricorn.c6*.yml`,
`/tmp/c6b_probe.log` on swarm-1 are harmless, but `STACK_FILE` must be unset for a normal deploy.

---

## 🎉 ANDREW GOT THE JOB (Aug 12, 2026)

The interviews happened **Aug 6 and Aug 7** and the outcome was an offer: **SRE / DevOps on an order
management system at a financial institution.** Phase 14 was built to prepare for exactly those two days, so
**Phase 14 is CLOSED — goal met.** Nothing in it is half-finished; all 7 chapters were written,
audited, highlighted, built to `.docx` and committed, and the highlighting was **visually confirmed
good in Word by Andrew on Aug 12**, which closes the last open verification item.

**What changes:** the education material is no longer interview prep with a deadline. It is
onboarding prep for a job he now holds, which means **depth on the real stack** rather than breadth
before a panel.

✅ **RESOLVED Aug 13 — the real stack has landed.** Andrew wrote it down in
**`education/fin_tech_stack.txt`**, now the tracked source of truth for the study backlog. Focus is
**DevOps as it applies to an OMS / platform including portfolio and risk management tools**, and the
**Q3–4 2026 study list, in its stated priority order**, is: **Kubernetes; Redpanda + Redpanda Connect;
Docker Swarm; Jenkins; OpenSearch + OpenSearch Dashboards (logging/alerting); Prometheus + Grafana
(metrics/alerting); Redpanda Connect + Debezium CDC; MongoDB + Postgres; SAML/OIDC integration
(authentik as a self-hosted OIDC provider); Ansible.**

Three consequences:
- **Track 1 and track 2 are both confirmed on the list** (Kubernetes/Redpanda, Docker Swarm), so
  neither was wasted. **Jenkins is explicitly named**, which upgrades Phase 17 from provisional.
- ⭐ **ROADMAP RULE (Andrew, Aug 13): new phases work through `fin_tech_stack.txt` STEP-BY-STEP, in
  its stated order.** The list is the backlog — do not invent a curriculum or re-derive priorities.
  After Swarm, that means **Jenkins**, then OpenSearch, Prometheus/Grafana, Redpanda Connect +
  Debezium CDC, MongoDB/Postgres, SAML/OIDC (authentik), Ansible.
- ✅ **Chapter 7 of track 1 was RIGHT — leave it exactly as it is (Andrew, Aug 13).** Its six areas
  came from the job description and **are genuinely in the target stack**; they are simply **not what
  was suggested as the first focus.** The four that do not appear on the study list — **Cloudflare
  edge, Symantec PAM, Vault, PKI/cert-manager** — are **real and correctly documented, just lower
  priority.** ⚠️ **Do NOT rework, retract or reconcile away chapter 7**, and do not treat
  `phase15_education_program.md` §4 as having aimed at the wrong target. It was a straw man in the
  sense that it was unconfirmed, not in the sense that it was wrong. **Sequencing now comes from the
  study list; coverage from §4 and chapter 7 still stands.**

### 🚨 De-identification — a standing rule, learned the hard way on Aug 13

The first draft of that file named an **employer, a start date and who suggested the list**, and the
first fix was to **gitignore it**. That fix was wrong twice over:

1. **The facts had already been copied into `MEMORY.md` and `current_phase.md`** — both **tracked and
   public** — specifically so a cold reload would not need the ignored file. Ignoring the file did
   nothing about the copies. This was caught only because the GitHub dry-run output was read carefully;
   **all four of `push_github.sh`'s gates passed, because they look for credentials.**
2. **An ignored file makes a fresh clone miss the roadmap MEMORY points at**, which is the same trap as
   telling a reader to run something out of a gitignored `scratch/`.

**Andrew's fix, applied the same day and the one to copy in future:** de-identify the *content* rather
than hide the file. Generic title, generic framing, a neutral filename, then **track it normally.**
Also applied repo-wide the same day: the **industry term was genericised to "financial institution"**
in 7 places across `MEMORY.md`, `current_phase.md`, `phase14`, and **track 1 chapter 1 — whose
committed `.docx` was rebuilt**, since the Word builds are binaries and a text edit does not reach
them. ("Order management system" was explicitly kept.) History was **not** rewritten for the
already-public files; nothing carrying the employer name ever reached GitHub.

🚨 **Never put an employer name, a start date or "my boss" into a tracked file. The push gates protect
against secrets, not against private.**

---

## 🔵 ACTIVE: Phase 16 — Docker Swarm (education track 2)

**Full plan + implementation log: `phases/phase16_docker_swarm.md`.**

### ✅ Part 1 COMPLETE (Aug 13, 2026, 12:12–12:26 PM EDT)

Three nodes exist and are ready for `swarm init`:

| VMID | Name | IP | Spec | State |
|---|---|---|---|---|
| 191 | `docker-swarm-1` | 192.168.1.191 | 2 vCPU / 4 GB / 40 GB `vm-ephemeral` | running, `onboot=1`, Swarm inactive |
| 192 | `docker-swarm-2` | 192.168.1.192 | 2 vCPU / 4 GB / 40 GB `vm-ephemeral` | running, `onboot=1`, Swarm inactive |
| 193 | `docker-swarm-3` | 192.168.1.193 | 2 vCPU / 4 GB / 40 GB `vm-ephemeral` | running, `onboot=1`, Swarm inactive |

Docker **29.7.2** / Compose **v5.4.0**, Ubuntu 24.04 LTS from template 9000. All three snapshotted
**`s01-base-clean`**, taken hot and together (~1.6 s each, guest-agent freeze/thaw, nothing stopped).

**Built by two committed idempotent scripts**, not by typing commands three times —
`education/docker-swarm/scripts/provision_nodes.sh` (runs on the pve host) and `post_setup.sh` (runs
on each node). Three full clones took **38 seconds**; personalization ran on all three **in parallel**
in ~3 minutes.

**Pre-flight decisions taken:** **A5 closed** — the stack file and scripts live in
`education/docker-swarm/{manifests,scripts}/`, keeping the track self-contained per `CONVENTIONS.md`
and setting the pattern later tracks copy. **A2 deferred to Part 4** (whether this repo gains a
`.gitlab-ci.yml`), because it is really one decision together with the `workflow: rules:` guard that
stops every `push_gitlab.sh` backup from spawning a pipeline. **A3 stays deferred into Part 5** by
design. **Nothing blocks Part 2.**

**What was worth learning in an otherwise smooth build:**
- ✅ **`growpart` ran** — the plan's loudest warning was a non-event. ⚠️ But **`df -h /` reads 38G, not
  40G**: `sda15` (106M EFI) and `sda16` (913M `/boot`) come out of the 40 GB virtual disk. **38G is
  correct — do not go hunting the missing 2 GB.**
- ⚠️ **`host_setup.sh` really does install Chrome + Cursor on a headless node, and now we know why:**
  it runs the desktop branch if it finds `gnome-shell` **or `gsettings`**, and the Ubuntu 24.04 cloud
  image ships `gsettings`. The log even says "Desktop environment detected". Purging took each node
  from **4.4 GB to 2.2 GB used** — the ~1.8 GB the plan predicted. Apply this to every future clone.
- ✅ **`refresh.sh` needed no edit.** It targets an explicit allow-list (`.180`–`.184`), so new VMs are
  excluded by construction. The guest half still mattered: `unattended-upgrades`, `apt-daily` and
  `apt-daily-upgrade` are **masked** on all three (B4).
- ✅ **Nothing obstructs Swarm's ports.** `/etc/pve/firewall/` holds only `184.fw`, `185.fw` and
  `cluster.fw` — there is **no `19x.fw`**, so the guest firewall is off despite `firewall=1` on the
  NIC, and `2377`/`7946`/`4789` are clear. ⚠️ Adding a `19x.fw` later without those three rules
  **breaks the cluster silently.**
- ✅ **The registry config came free from the standard script**, which was the whole argument for using
  it: `insecure-registries` is in `/etc/docker/daemon.json` on all three, and `/v2/` answers **401**
  from `.191` (up, requiring auth).
- ✅ **No backup job sweeps them in** — `/etc/pve/jobs.cfg` has one job, scoped to `vmid 181`.
  Consistent with "backups: none, snapshots instead" for rebuildable VMs.

### ⬜ Next: Part 2 — form the cluster

`docker swarm init --advertise-addr 192.168.1.191`, join `.192`/`.193` as managers, confirm one
`Leader` + two `Reachable`, then `s02-swarm-up` on all three together (B3). After that, chapter 1
can be drafted, since it covers Parts 1–2 and half of it has now actually been run.

---

## ✅ Phase 15 — The Education Program (multi-track study repo)

**Full plan: `phases/phase15_education_program.md`.**

✅ **Its last open item closed Aug 13:** the `docker-swarm` row is now in `education/README.md`'s track
table, and `education/docker-swarm/README.md` exists, because the folder it was waiting on was created
by Phase 16 Part 1. ⚠️ **`build_docx.py --list` still shows only `k8s-k3s-redpanda`, and that is
correct** — a track only registers once it holds `chapterNN_*.md` files, and track 2 has none yet.

### ⭐ NEW Aug 13 — the learning method is finally written down: `education/METHOD.md`

Andrew's question was the right one: *are you following the same steps for every new subject, and did
you write yourself instructions for it?* **The honest answer was no.** `CONVENTIONS.md` is the
**writing** standard and `CURSOR_RULES` holds the **project** process (plan → approve → implement →
document). The actual learning loop — build it, break it, write from the wreckage — **existed nowhere**
and survived only as a *shape copied by imitation* from `phase14` into `phase16`. That is precisely how
a method drifts, and it was already visible: **two genuine improvements were invented mid-Phase-16 and
were not captured anywhere** — the **planted-traps table** (🅒, failures listed in advance and marked
do-not-fix) and **sorting caveats into four kinds** (🅐🅑🅒🅓, because the first draft's five "open
questions" read as five blockers when only two needed a human).

**`education/METHOD.md` is now the sibling of `CONVENTIONS.md`:** *how to run a track* beside *how to
write a track*. Five stages — **plan** (declare the traps up front), **build** (scripted, re-runnable,
**verified from inside the guest**), **break** (drills chosen for what they mean at 3am), **investigate**
(**the surprises ARE the deliverable** — almost nothing quotable in track 1 was planned), **document** —
plus an anti-patterns table.

⭐ **Andrew's explicit framing: a proven method, but a FLOOR NOT A CEILING.** Room to develop new or
topic-specific ideas and run with them, exactly like the two Phase 16 improvements. So the amendment
duty is the **first** rule in the file, not a footnote: **deviate deliberately, then fold what worked
back in during the same session.** An improvement that is not written down is lost.

### 🚨 THIS IS HANDS-ON TRAINING — ANDREW RUNS THE COMMANDS (added Aug 13, same session)

Andrew caught the omission immediately: *"before, you told me what to do and then I did it by hand so
I could learn and you would check — is that verbiage in the METHOD file?"* **It was not.** And the
proof of why that matters was sitting right there: **Phase 16 Part 1 had just been driven entirely by
the AI. Andrew typed nothing.**

⚠️ The practice was never invented — it was always how track 1 worked. `phase14`'s log says
"ready for the **guided** Part 3", then "Part 3 **hands-on, Andrew driving**", then "everything
documented came from something he ran". **But it lived only as a diary entry, never as a rule** — the
identical decay that nearly lost the planted-traps table. Written up now as
`education/METHOD.md` → **"Who does the work"**, a section that governs all five stages.

**Why it is not ceremony:** *"only document what Andrew actually ran" is worthless if the AI ran it.*
It silently becomes "only document what was executed", and the material stops being something he can
stand behind in an incident or an interview.

**The split** — the test is *"is this what we are here to learn"*, not *"is this hard"*:

| Work | Driver |
|---|---|
| Anything **NEW** — the technology being studied and its failure modes | 🙋 **Andrew** |
| Routine plumbing the lab has proven — template-9000 clones, `host_setup.sh`, `qm` resize/snapshot | 🤖 AI may drive |
| Writing — chapters, phase files, MEMORY, diagrams, committed scripts | 🤖 AI |

Track 1 drew this exact line, which is why **Part 1 being AI-driven was defensible** (cloning a VM for
the tenth time) — but **Part 2 is where it must switch, and it will.**

**The loop:** AI says what and why → **ONE** command → Andrew runs it and pastes output → AI checks it
and explains what it actually means → repeat → snapshot at the milestone. Not a wall of commands.

🚨 **When something breaks, Andrew diagnoses FIRST and the AI stays quiet** until asked, or until he is
burning real time. Debugging while confused *is* the job skill. This matters most for the **seven
planted traps** — narrating the answer the moment one fires is the same mistake as pre-empting it, one
step later.

**Repetition:** Andrew does the first node by hand, the AI does the other two — unless the repetition
*is* the lesson (writing the re-runnable script), which makes it his.

**Chapter scope, settled at the same time** (`CONVENTIONS.md` → "What belongs in a chapter"): routine
lab plumbing is **assumed, not re-taught**; what belongs is the infrastructure *as it pertains to this
build* plus the **what and why** — why three nodes, why all managers, why `vm-ephemeral`, why the
3.5 GB template disk had to grow. The test: *would this still be worth reading by someone who already
runs the lab?*

✅ **No `CURSOR_RULES` change was needed** — rule 1b already says to read and follow `METHOD.md`, so
the protocol is covered transitively.

### 🔓 `CURSOR_RULES` edited a SECOND time (Aug 13) — authorised in writing, still not precedent

Andrew authorised this edit explicitly and in writing, to wire `METHOD.md` in. **225 → 239 lines,
exactly one line removed** (old rule 2, deliberately rewritten). Changes: **checklist item 2g**
(METHOD is mandatory before starting or running a track), **METHOD.md added to the education file
list**, **new rule 1b**, **rule 2 widened** (conventions → `CONVENTIONS.md`, working practices →
`METHOD.md`, neither ever forked into a track), and **new rule 8** (floor not ceiling + fold-back
duty). The `RULES:` list now runs **1, 1b, 2–8** — `1b` deliberately avoids renumbering rules that
other documents reference.

⚠️ **Method note for the next time this file must change:** it was done as **one atomic Python pass
that asserted every anchor matched exactly once and that Andrew's own lines survived**, then verified
from the shell (`wc -l`, `md5sum`, `git diff | rg '^-'`). **Do it that way** — incremental edits to
`CURSOR_RULES` on this CIFS mount corrupted it twice on Aug 12.

`education/` was written flat for one subject on one deadline. With the job won and a whole stack to
learn, it had to stop being *a book* and become *a shelf*. Phase 15 is that conversion — framework
and doc reconciliation only, **no new study content**.

### ✅ Done (Aug 12)

- **Track 1 moved to `education/k8s-k3s-redpanda/`** — 67 `git mv`s, history preserved
  (`git log --follow` still reaches Jul 27). Chapters, `app/`, `diagrams/`, `images/`, `manifests/`,
  `docx/` and the ignored `scratch/` all travelled together.
- **`.gitignore` generalised** to `education/*/scratch/`, so every future track's scratch is ignored
  automatically. Verified with `git check-ignore -v`.
- **Tooling made shared and track-aware.** `education/tools/` stays at the top of the shelf;
  `build_docx.py` and `figcheck.py` now take the **track as their first argument**, and
  `build_docx.py --list` enumerates tracks. `figcheck.py` was **promoted out of the gitignored
  `scratch/`** so a fresh clone can actually run the command the docs describe.
  - **Regression check passed:** rebuilt all 7 chapters and compared the inner `word/document.xml`
    against `git show HEAD:` — **byte-identical in all seven.** The committed binaries were then
    restored so the commit stays a pure rename instead of 7 files of zip-timestamp noise.
- **The shelf documents written:** `education/README.md` is now the hub (track table + how to start a
  track), and `education/CONVENTIONS.md` holds every *how to write* rule so future tracks inherit
  them instead of copying them.
- **The emailed GitHub links preserved.** `education/README.md` stayed at its original path, and
  `education/docx/README.md` is a stub pointing at the track's builds, so
  `…/tree/main/education/docx` resolves instead of 404ing. Both URLs went to the hiring team Aug 5.
- **Track 1's README corrected** — it had listed chapter 7 as "Schema Registry 🔲 Planned" when
  chapter 7 was actually written as *the rest of the platform*. Schema Registry is now chapter 8.
- **Root `README.md` now documents `education/`** — it previously never mentioned it at all, which
  meant the repo's public face omitted the piece good enough to send to an employer.
- **Paths reconciled** across `MEMORY.md`, `current_phase.md`, `phase14_k8s_redpanda_poc.md`,
  chapters 1 and 6, and `seed-topics-job.yaml`.

### 🐛 Found while doing it — then closed as acceptable

**4 of 19 figures are below the 10 pt floor** Andrew set: `ch02_fig1_ownership` (9.7),
`ch03_fig1_partitions` (9.9), `ch05_fig1_assignment` (10.0 borderline) and `ch05_fig2_skew` (9.4), so
`figcheck.py` exits 1. Pre-existing; it only surfaced because promoting `figcheck.py` out of the
gitignored `scratch/` meant actually running it.

✅ **Resolved by real-world test, not by code: Andrew rendered and PRINTED all seven chapters on
Aug 12 and confirmed they look and print correctly.** So the 10 pt floor is a conservative guide
rather than a hard requirement, and these four stay as they are. **Do not "fix" the non-zero
`figcheck` exit on track 1** — treat it as known and apply the check to *new* figures only. If they
are ever revisited, the fix is a narrower diagram, never a bigger `fontsize`.

### 📐 Conventions are now a file, and it is authoritative

`education/CONVENTIONS.md` holds every *how to write* rule — chapter shape, the "only document what
Andrew actually ran" rule, the Graphviz gotchas, figure legibility, the Word build and the highlight
pass. **Read it before writing or editing any study material, and change conventions there rather
than forking them into a track.**

✅ **Wired into `CURSOR_RULES` on Aug 12.** Andrew gave **explicit one-time authorisation** to edit
that file (it normally forbids AI edits outright — the authorisation note now sits under the
never-edit line, and it is **not precedent**). Three changes:
1. **`PROJECT SCOPE` rewritten to Andrew's definition:** the repo owns **two** things — the Proxmox
   layer **and educational R&D done inside it**. "Application layer" means Capricorn and other real
   apps on the lab. The old text said "INFRASTRUCTURE layer ONLY", which left `/education` unclaimed.
2. **Checklist item 2f** — `CONVENTIONS.md` is a mandatory read for education sessions.
3. **New `=== EDUCATION PROGRAM (/education) ===` section** with 7 rules (conventions first, don't
   fork them, only document what was run, tracks self-contained, nothing from `scratch/`, one phase
   file per track, operational weighting).

### ⚠️ The repo is on a CIFS share and the editor cache lies — VERIFY EDITS FROM THE SHELL

Editing `CURSOR_RULES` produced **two silent corruptions**: a truncated paragraph and a stray line
(`EW instructs you to- CONFIRM that you will edi`) that had never existed in the file. Read-backs
returned stale content that concealed both, once showing a completely different region of the file
than `rg` showed for the same path, and the IDE reported 160 lines while disk had 204.

Both were caught by auditing removals (`git diff <file> | rg '^-'`) and verified with `wc -l` /
`md5sum` / `rg -c`. **Do that after every edit to an important file here.** And if Andrew has a file
open whose line count disagrees with disk, he must reopen it before saving — a stale buffer will
overwrite good work. Full rules at the top of `MEMORY.md`.

### 🔧 Also done this session — push tooling (Aug 12, 4:00–4:25 PM)

Andrew's idea: symmetrical scripts for both remotes, instructed by `CURSOR_RULES`, so pushing is
never a hand-typed `git push`. See the two script sections below for detail.
- **`push_github.sh` NEW** — fails closed on four gates before touching the public remote.
- **`gl-backup.sh` → `push_gitlab.sh`** (`git mv`, history preserved). Old name is gone on purpose;
  a stale call errors loudly rather than half-working. Added a github.com guard and `--dry-run`.
- **Snapshot auto-stamping** — closed a long-standing context leak; see the GitLab mirror section.
- `CURSOR_RULES` now opens that section with "ALWAYS PUSH WITH THE SCRIPTS. NEVER run a raw
  `git push`", and rules 2–5 were rewritten around them.

### 🔻 Also done this session — VM 186 right-sized (Aug 12, ~5:15 PM)

Andrew's question was the right one: *did we over-commit Redpanda for R&D?* Yes, and by a lot.
VM 186 held **32 GB / 16 vCPU** because the Phase 14 plan sized it for **OpenSearch**, which was
never installed (Part 5 was cut for time). Nine days of running measured **3.0 GB and ~1% CPU**.

**Now 16 GB / 8 vCPU**, which returns **16 GB and 8 threads** to the host for the Phase 15 study
clusters — the exact headroom the Docker Swarm / MongoDB tracks will need on a single physical box.

- **The floor is pod *requests*, not usage.** Kubernetes schedules on requests, and these pods
  reserve **7.7 GB / 3.25 cores** (three brokers at `1` core + `2560Mi` each). 16 GB / 8 vCPU keeps
  requests at **50% RAM / 41% CPU** and still leaves room to add OpenSearch later.
- **Redpanda needed no re-tuning.** Each broker's Seastar arena is sized from its *container* limit,
  not host RAM, so the brokers could not notice the change.
- **A CPU/RAM change needs a full stop, not a reboot** — `qm shutdown` (35 s, graceful via guest
  agent) → `qm set --cores 8 --memory 16384` → `qm start`. ⚠️ `qm set` on a *running* VM succeeds
  silently and only stages the change, which looks like success.
- **Verified:** 8 cores / 15 Gi in guest, node `Ready`, **all 12 pods Running**,
  `rpk cluster health` **`Healthy: true`** with 0 leaderless and 0 under-replicated, all 4 topics
  intact at RF 3, group `position-keeper` **Stable**, no OOM kills, and the Part 6 ledger on the PVC
  still sums to **exactly 800,000 shares across 2000 orders**. Host assigned RAM 100 GB → **84 GB**.

**Two pre-existing issues found while verifying** (both documented in the phase 14 file):
1. **All topic data has aged out** — default `retention.ms` is 7 days and the events were seeded
   Aug 3. Every partition now has `LOG-START == LOG-END`. **Re-seed before any chapter 8+ work.**
   This also explains a scary-looking `TOTAL-LAG 1665` on `orders-v2` p5: its committed offset of 0
   fell below the log start, so the consumer reset its *position* to the end but has nothing left to
   process and therefore never commits. Not data loss — the ledger proves it.
2. **The Redpanda trial licence expires ~Aug 25, 2026**, with `partition_auto_balancing_continuous`
   and `core_balancing_continuous` in use from chart defaults. Decide to disable or licence.

### 🔑 Also done this session — SSH access fixed properly (Aug 12, ~5:35 PM)

The resize work was slowed by an access problem that turned out to be two different things:

- **VM 186 never needed keys.** `ssh andrew@192.168.1.186` fails, `ssh agamache@192.168.1.186`
  works and always has — cloud-init injected the workstation key on Jul 25. **Every VM in this lab
  logs in as `agamache`.** `Permission denied (publickey,password)` from a wrong *username* is
  indistinguishable from a missing key, which is what sent the earlier attempt down a dead end.
  `kubectl`, `rpk`, `~/.kube/config` and passwordless `sudo` are all ready on that connection.
- **The Proxmox host genuinely lacked the key**, so `qm` work needed the PASSWORDS.md password over
  `sshpass`. **Fixed:** the workstation ED25519 key now lives in **`/root/.ssh/authorized_keys2`**.
  - Deliberately *not* `authorized_keys` — that is a symlink to `/etc/pve/priv/authorized_keys`,
    which PVE owns and rewrites, and which holds only the cluster's `root@pve` key.
  - `sshd -T` already lists `.ssh/authorized_keys2`, so **no sshd edit and no restart** were needed,
    and PVE will never clobber it.
  - Proven with `-o PasswordAuthentication=no` so a silent password fallback could not fake success.
    `sshd` left untouched (`permitrootlogin yes`, `passwordauthentication yes` still available).

Both facts are now in `MEMORY.md` under CREDENTIALS, where the old text claimed keys covered
".180-.185" and said nothing about the username or the host.

**Then audited the whole fleet against Andrew's stated policy** — key auth from the dev box to
everything with password fallback, and password-only from a remote laptop. **It already holds**;
there was nothing left to build after the host key went in. Full matrix in `MEMORY.md` →
CREDENTIALS → "SSH ACCESS MATRIX". Verified rather than read off config:

- Key auth ✅ to all 7 live hosts (.150 + six VMs; .185 is powered off by design).
- Password-only logins ✅ tested with `-o PubkeyAuthentication=no` on .150, .181, .184, .186. A
  config that says `passwordauthentication yes` and an account with a locked password look identical
  until you actually try one.
- **Remote works because the pve host is a Tailscale subnet router** advertising an approved
  `192.168.1.0/24` — no Tailscale needed on each VM.
- ⚠️ **Subnet routing SNATs (`NoSNAT: false`), so remote traffic reaches the VMs as `192.168.1.150`.**
  That is *why* hardened `.184` (policy_in DROP, SSH from only .182/.195/.150) is reachable remotely
  at all. It also means **VM auth logs cannot distinguish a remote login from a host login** — don't
  build fail2ban or audit rules on VM-side source IPs. Confirmed by SSHing pve → all six live VMs,
  the same post-SNAT path.
- ⚠️ **This dev box is not on the tailnet.** The tailnet's `agamache-z8g4` is the *Windows Z8 host*;
  the dev box is the VMware guest inside it.

**Written up as a runbook: `MEMORY.md` → "REMOTE LAB MANAGEMENT (laptop, outside the house)".**
Andrew's question was whether he could manage the lab from a laptop while away by cloning the repo
for the passwords file. **Yes — verified end to end**, with three things that matter:

1. ⚠️ **Clone GitLab, not GitHub.** `PASSWORDS.md` is gitignored, so GitHub's `main` has **no**
   credentials; the GitLab mirror is the only source. DNS needs no setup — public DNS resolves
   `gitlab.gothamtechnologies.com` to `192.168.1.181`, reachable via the subnet route. The
   `git-upload-pack` endpoint returned HTTP 200 with root credentials (401 without) from a post-SNAT
   source, so the whole path is proven.
2. ⚠️ **GitHub pushes will not work from the laptop** — `origin` is SSH and no private key is (or
   should be) in the repo, and there is no PAT in `github_credentials.md`. GitLab pushes do work.
3. ⚠️ **`.150` is a single point of failure with no out-of-band console.** One subnet router, no
   backup path: a bridge or firewall mistake on the host while remote is unrecoverable until Andrew
   is physically home. `tailscaled` is enabled at boot and the node key has no expiry, which covers
   reboots and long absences but not self-inflicted network breakage.

Also noted: the clone puts the GitLab root password in `.git/config` and `PASSWORDS.md` in plaintext
on the laptop, so full-disk encryption is load-bearing and the clone should be deleted after a trip.

**Andrew then added a second route, which is the better one and changes the risk picture.** Rather
than cloning credentials to the laptop, tailnet *into the workstation* and drive the pve GUI from
there — the dev box already has the keys and the repo, so **nothing sensitive leaves the LAN.**
- ⚠️ **Precision matters here: the dev box is not a tailnet node.** Tailscale is **not installed** on
  it (verified — no binary, no `tailscaled`, no `tailscale0`). The entry point is **`agamache-z8g4`,
  the Windows Z8 host** (`100.70.244.97` / LAN `.115`), with **RDP :3389 verified open**; the dev box
  is the VMware guest one hop further in.
- ✅ **This retires the single-point-of-failure worry for remote *entry*.** The Windows Z8 is its own
  independent tailnet node, so if `.150`'s `tailscaled` dies or stops advertising the subnet route,
  Route B still reaches the lab over the LAN. Keep the Z8 powered on and RDP-reachable when away.
  What it does *not* fix: breaking the pve host's own bridge or firewall remotely is still
  unrecoverable, because there is no out-of-band console.
- Corrected a wrong assumption while writing this up: `/mnt/DevShare` is **`//192.168.1.120`** (the
  NAS), *not* the Windows host — so this route depends on `.120` being up too.

⚠️ **Audit-regex correction for the CIFS check:** `git diff <file> | rg '^-[^-]'` **silently hides
removed Markdown bullets**, because a deleted `- item` appears as `-- item`. Use plain
`git diff | rg '^-' | rg -v '^--- '` instead. The earlier form under-reported this session's
removals by two lines (both intentional, re-audited clean).

### 🐳 Also done this session — the employer's stack is known, and Phase 16 is planned (Aug 12, ~6:30 PM)

**The O1 blocker is closed.** Andrew's description of the new employer's platform:

- Role is **DevOps/SRE, with DevOps first**. Job already accepted.
- Their platform, as far as he knows it today: **GitHub** (source), **Jenkins** (CI),
  **Docker Swarm** (orchestration). Jenkins may need building in the lab later; for now we stay on
  GitLab.

⚠️ **The uncomfortable implication, and why it changed the plan:** our lab is GitLab + GitLab CI, so
the *pipeline glue* is the one part of a Swarm phase that would **not** transfer — it would be written
in a syntax the employer does not use. Fix baked into the plan: **the deploy logic goes in a shell
script (`deploy_swarm.sh`) and the CI file is a thin wrapper that calls it.** GitLab CI calls it now;
a Jenkinsfile calls it later for roughly the same number of lines. Deploy logic is the durable part;
CI products are interchangeable.

**`phases/phase16_docker_swarm.md` written (508 lines) — plan only, nothing built.** Three managers at
`.191/.192/.193` from template 9000, 2 vCPU / 4 GB each (**exactly the 16 GB VM 186 gave back this
afternoon**), running Capricorn from the existing registry images.

**Two of the five open questions were answered by going and looking rather than by asking Andrew:**

- **O3 — is Capricorn stateful? Yes.** Inspected the live PROD stack on `.184`: four services
  (frontend, backend, postgres, redis), named volumes `postgres_data_prod` / `redis_data_prod`, plus a
  bind mount `./database/init` for schema init. This upgraded Part 5 from a paragraph to the best
  exercise in the phase, because **a Swarm named volume is node-local**: reschedule postgres and it
  comes up against a *new empty volume*, reports healthy, and has no data. Silent data loss that looks
  like a clean deploy. Added as drill 6.
- **O2 — where the deploy job lives.** Confirmed this repo is a GitLab project (`production/home-lab-setup`)
  with **no `.gitlab-ci.yml` today**, so the lab can own its whole deploy path here and
  **Capricorn's pipeline is never touched.** That keeps the standing rule intact: breaking the lab
  cluster must not be able to break `deploy_qa` (fires on every `develop` push) or `deploy_prod_local`.

⚠️ **Drift found in passing, worth remembering:** `/opt/capricorn/docker-compose.yml` on `.184`
declares `postgres:15.5-alpine`, but the **running container is the custom
`production/capricorn/postgres:latest`**. The file on disk does not describe what is deployed — so
"just redeploy from the compose file" would quietly change the database image on PROD. Recorded in the
phase plan; **not** fixed here, since Capricorn is application layer.

⚠️ **Deferred into Part 4 rather than blocking the phase:** whether the `.182` runner is even visible
to the `home-lab-setup` project, or is scoped to Capricorn. Also noted: adding a CI file to this repo
means `push_gitlab.sh` backups would start spawning pipelines, so the job needs a `workflow: rules:`
guard.

Other decisions: 3 managers (not 2+1), track name `education/docker-swarm/`, **fresh empty database**
in the lab with its own volume names — no PROD dump, no shared volumes. Jenkins is explicitly out of
scope as a possible Phase 17.

🚪 **AGREED OPENER FOR THE NEXT SESSION.** Andrew will say something close to *"Action @CURSOR_RULES,
the phase16 plan is approved, let's start Part 1."* Interpret that as: run the startup checklist, read
`phases/phase16_docker_swarm.md` **and `education/CONVENTIONS.md`** (chapter 1 gets drafted, so 2f
applies), then **walk the pre-flight §🅐 items — A2 and A5 — before cloning any VM.** That phrasing
also satisfies the MANDATORY PHASE PROCESS approval gate (step 3); do not ask for approval a second
time. **`phases/phase15_education_program.md` is *not* required reading to start Phase 16** — Phase 16
is self-contained, and phase15 §4's track list is the known-stale straw man.

📌 **Andrew's ask, and a good one:** the caveats had been raised in chat and scattered through 500
lines of plan, which is useless to a re-read weeks later. They are now consolidated into a
**pre-flight list at the top of `phase16_docker_swarm.md`**, sorted into four kinds so they cannot be
confused: **🅐 open items** (only **two** now need Andrew), **🅑 7 hard rules**, **🅒 7 deliberately
planted traps that must NOT be fixed in advance** (pre-empting them turns the phase into a tutorial),
and **🅓 3 inherited findings** recorded but out of scope. **Walk §🅐 with Andrew at the start of the
build session** — that is the agreed entry point for this phase.

### 🔍 Review pass over phase15 + phase16 (Aug 12, ~9:15–9:45 PM) — found a credential leak path

Andrew asked for a critical review of both phase docs. Seven real gaps in phase16, six staleness
problems in phase15. The one that mattered:

🚨 **Phase 16 as written could have put a PROD database password into a repo with a public GitHub
remote.** Capricorn's compose on `.184` has **no `.env`** — `POSTGRES_USER`, `POSTGRES_PASSWORD`,
`POSTGRES_DB` and a password-bearing `DATABASE_URL` are **inline, in plaintext, in the file**. The plan
said "write our own stack file referencing the same images" and never said where configuration comes
from, and the obvious implementation is to start from `.184`'s compose. ⚠️ **`push_github.sh` would
probably catch the `DATABASE_URL`** (its URL-with-embedded-password gate) **but would NOT catch a bare
`POSTGRES_PASSWORD=` line** — so the existing protection is partial and accidental. Now hard rule B7,
finding D3, and a Part 3 section that does it properly with **`docker secret`**.

Also added, all previously absent: **Docker secrets/configs** (zero mentions in a 600-line Swarm plan
— both the fix above and a curriculum gap, since they are the direct analogue of k8s Secrets and
ConfigMaps); **image resolution** (a Swarm service stores a **digest**, not a tag, so `:latest` does
not float the way compose taught you — now trap C7 and drill 9); **the deploy token was being passed
as an inline env assignment on the `ssh` command line**, visible in `ps` on the manager, now piped over
stdin, with an honest note that the HTTP registry sends it in clear anyway; and **`df -h /` added to
Part 1's verification** — template 9000's disk is only **3584M**, so if cloud-init's `growpart` does
not fire you get a 3.5 GB root that dies on the first image pull, with an error about layers rather
than about disk.

**Phase 15 was stale rather than wrong.** Its header still claimed "nothing is committed yet" (it went
in with `104a1e0`); all 23 task checkboxes were unticked despite §5c narrating the work as done; §1 was
titled "where things stand today" while describing the pre-move tree; and the validation table listed
`figcheck.py … exits 0` when §5c records it exiting **1** on four accepted sub-10pt figures — a future
reader would have read that as a regression. All corrected, with the `tools/` row marked `[~]` because
that move turned out to be unnecessary rather than done.

⚠️ **The substantive phase15 fix is §4.** The six job-description tracks are **not refuted** by
Andrew's answer — they are all *platform services* (MongoDB, observability, Vault, IAM, edge) while
GitHub/Jenkins/Swarm are *delivery tooling*. **Orthogonal, not competing.** What was wrong was the
**ordering**: it recommended observability → mongodb, and none of the three tools Andrew actually named
appeared anywhere. Revised order is **`docker-swarm` → `jenkins` → `observability` → `mongodb` → the
rest as reading**, and `jenkins` is now a provisional track row. O1 is marked **closed but partial** —
he said "what I know about their platform", so the platform-service half is still unconfirmed and
should be re-asked once he is inside.

### ⏭️ Next

1. ✅ **Done — the real stack is known** (GitHub + Jenkins + Docker Swarm; DevOps-first SRE role).
2. Fix the track list in `phases/phase15_education_program.md` §4 against that stack — Swarm is now
   confirmed track 2, and **Jenkins is a strong candidate for track 3**.
3. ✅ **Done — `phases/phase16_docker_swarm.md` written and awaiting Andrew's go-ahead** before any VM
   is cloned. **Agreed model: one phase file per track**, with the track README staying a
   reader-facing index and the phase file holding the working record.
4. Track 1's own chapters 8–10 (Schema Registry, OpenSearch + Fluent Bit, failure drills) remain
   planned and unblocked — the cluster is still at snapshot `s05-app-running`, now on 16 GB / 8 vCPU.
   ⚠️ **Re-seed the topics first** (7-day retention aged all events out on ~Aug 10), and note that
   OpenSearch still fits in 16 GB if chapter 9 goes ahead.
5. ⏳ **Time-boxed, not optional: the Redpanda trial licence expires ~Aug 25, 2026** (found Aug 12).
   `partition_auto_balancing_continuous` + `core_balancing_continuous` are in use from chart defaults.
   Decide to disable them or request a licence. Expiry on a rig this size should not be disruptive,
   but it should not be a surprise either — and it would make a good chapter-10 failure drill.
6. Cosmetic-only, low priority: the 4 figures at 9.4–9.9 pt. **Andrew confirmed print quality is
   fine**, so this is optional forever unless a reprint looks wrong.
7. **Infra follow-ups raised and deliberately deferred on Aug 12** (offered, Andrew chose docs only):
   - **GitHub pushes are impossible from the laptop** — `origin` is SSH and no PAT exists. Fix would
     be registering the laptop's key or switching to HTTPS + token.
   - **No out-of-band console for `.150`.** Route B (RDP to the Windows Z8) covers *entry* if the
     host's `tailscaled` fails, but a broken bridge/firewall on `.150` is still unrecoverable remotely.
   - **Tailscale on the dev box** would make it a direct tailnet node and drop the RDP hop.
8. Measure RAM/CPU headroom on the other VMs (GitLab 24 GB, SonarQube 12 GB) the way 186 was measured
   — 186 gave back 16 GB and 8 threads, and the Phase 15 study clusters will want more.

---

## ✅ qemu-guest-agent rolled out to all 5 live VMs (July 9, 1:20–1:28 PM)

Follow-up to the restore-drill finding (181 had no agent). For **181, 182, 183, 184, 200**:
- Installed + enabled `qemu-guest-agent` (Ubuntu pkg 1:8.2.2) inside each guest.
- `qm set <id> --agent enabled=1` on the host, then **graceful stop/start of each VM**
  (runner verified idle first; GitLab last). Total blip ~1 min/VM; GitLab ~3 min (Puma warmup).
- **All 5 answer `qm agent ping`** ✅ — PVE UI now shows guest IPs, clean shutdowns work,
  snapshot/backup fs-freeze available, future drills can verify via agent.
- Bonus: the stop/start cycled every VM onto the **new QEMU 11.0.2 binary** from this
  morning's PVE 9.2.4 upgrade (verified `running-qemu: 11.0.2` on all 5) — that loose end is closed.
- Post-checks: GitLab 200, public site https 200, QA 200, SonarQube 200, runner active.
- VM 185 (dormant OpenClaw) untouched — add the agent if it's ever revived. ⛔ **Never revived; destroyed
  Aug 19, 2026. The agent is now a Part 0 step for the Jenkins VM that replaces it.**

---

## ✅ GitLab backup test-restore drill — PASSED (July 9, 1:08–1:20 PM)

Proved the nightly vzdump of VM 181 restores to a **fully working GitLab** (full procedure
+ findings in `phases/phase13_fable_proxmox_audit.md`, bottom section):
- `qmrestore` last night's backup → VMID 999 on vm-ephemeral (`--unique`): 2m17s, 0 errors.
- Isolation: NIC on a **host-only bridge vmbr999** (no physical port) + /32 route — clone
  runs with its baked-in .181 IP but can't touch the LAN; live GitLab unaffected (200 whole time).
- Verified: 16/16 gitlab-ctl services up, sign-in 200, DB intact (4 users, 5 projects,
  correct timestamps), **git clone of capricorn from the clone: 306 files, HEAD 92dc5fb** ✅.
- Teardown clean: VM 999 + bridge destroyed, vm-ephemeral back to 203G.
- Finding: VM 181 lacks qemu-guest-agent → install during future guest-internals phase.
- Repeat ~quarterly or after major GitLab upgrades.

---

## ✅ Phase 13 (final): Maintenance window — SNC off + kernel 7.0.14-4 adopted (July 9, 12:48–12:56 PM)

1. **SNC disabled in BIOS** (Andrew at console, F10 → "Sub-NUMA Clustering" → Disable) and
   **kernel 7.0.14-4-pve pin-tested via `--next-boot` in the same reboot.** Booted clean
   first try: **NUMA now 1 flat node / 128GB**, all 6 NVMe behind VMD, 0 NVMe errors, pools
   ONLINE, 5 VMs auto-started, public site 200. Slot 5 Bifurcation x4x4x4x4 + VROC untouched
   (confirmed: bifurcation, NOT SNC, drives the quad-NVMe card).
2. **7.0.14-4-pve made the PERMANENT pin** (was 7.0.6-2 since Jun 18). Fallbacks on ESPs:
   7.0.6-2 + 6.17.13-x. PERF-4 closed → **every audit fix Andrew approved is now done.**
3. **Subscription nag re-disabled:** widget-toolkit 5.2.6 (from today's upgrade) changed the
   code, killing the old sed patch in `/usr/local/bin/proxmox-update.sh`. Patched the live
   `proxmoxlib.js` (subscription check → `false`; backup `proxmoxlib.js.bak-nag-20260709`)
   AND rewrote the update-script line with the new perl pattern (idempotent, verified).

---

## ✅ Phase 13 (continued): Afternoon Session — BIOS checks, ashift rebuild, Z8 tuning (July 9)

**Everything below is also in `phases/phase13_fable_proxmox_audit.md` (findings + implementation log).**

### Done (11:53 AM – 12:35 PM)
1. **AMT verified DISABLED — no BIOS visit needed.** Discovered HP exposes all 280 BIOS
   settings read-only via `/sys/class/firmware-attributes/hp-bioscfg/attributes/` on the
   Proxmox host. "Intel AMT" = Disable, "ME Firmware Mode" = "AMT Disabled". Cross-checked:
   all AMT ports (623/664/5900/16992-16995) closed from LAN. SEC-5 closed.
   ⚡ REMEMBER: this sysfs path reads any BIOS setting on HP boxes without rebooting.
2. **SNC confirmed "Enable" at BIOS level** (same sysfs). Changing it still needs the console.
3. **vm-ephemeral rebuilt ashift=9 → 12** (PERF-2 closed). Procedure (~10 min total downtime):
   `qm shutdown 182 200` → `qm move-disk` both scsi0 → vm-critical (--delete) →
   `zpool destroy vm-ephemeral` → `zpool create -o ashift=12` on same 2 NM620s (by-id,
   serials …863 + …887, stripe) → `zfs set compression=lz4` → move disks back → start VMs.
   Verified: zdb ashift=12 both vdevs; runner buildx + QA Capricorn stack healthy.
   NOTE: NM620 only exposes 512B LBA (no 4Kn) — ashift MUST be set at pool creation.
4. **Z8 dev-workstation VM tuned (side quest, recorded in phase13 addendum):** 32 → 24 vCPUs
   as **2 sockets x 12**. sysbench: 898 → 996 ev/s per thread (93% scaling eff., was 83%),
   thread spread ±11.5% → ±4.3%. **Andrew's find: 2x12 → Windows schedules VM on idle PROC1;
   1x24 → co-located with Windows on PROC0. Keep 2x12** (VM owns a whole physical socket).

### Andrew's decisions this session
- **❎ WON'T-FIX:** vzdump jobs for 183/184 (rebuildable; WWW=vanity demo, Sonar barely used).
  GitLab 181 remains the only backed-up VM (it's the only one with irreplaceable data).
- ~~**VM 185 (OpenClaw): leave dormant** — don't destroy, don't start.~~ ⛔ **OBSOLETE — Andrew reversed
  this on Aug 19, 2026 and the VM was destroyed. Historical directive; do not act on it.**
- **host.fw: HOLD** (was already pending BIOS/ashift; now explicitly deferred with SEC-1/2).

### Remaining open items (all optional)
- ~~Console visit combo (SNC + kernel pin-test)~~ ✅ DONE 12:48 PM — see section above.
- ~~Test-restore drill of GitLab backup~~ ✅ PASSED 1:20 PM — see section above.
- Optional hardware: 2x32GB DDR4-2666 ECC RDIMMs → 6/6 memory channels (+bandwidth, →192GB).
- Deferred security items: SEC-1 (SSH key-only), SEC-2 (TOTP), host.fw.
- tailscaled NetInfo log noise (G3100 UPnP flapping) — ignore, or add
  TS_DEBUG_DISABLE_PORTMAPPER override; Andrew hasn't picked.
- Delete VM 184 snapshot `pre_phase12_firewall` once Phase 12 is trusted (~mid-July).

### Blockers
None.

---

## ✅ Phase 13: Proxmox Host Audit + Same-Day Fixes (July 9, 2026)

**Status:** Audit COMPLETE + all approved quick wins IMPLEMENTED. Full record (25 findings,
severity ratings, implementation log, rollback notes): `phases/phase13_fable_proxmox_audit.md`.
**Scope was host-only** (hardware/OS/PVE config); VM guest internals deferred to a later phase.

**Overall audit verdict:** host healthy — pools ONLINE 0 errors, NVMe 0–1% wear, no failed
units, kernel-pin policy working, Phase 12 rules live as documented.

### Done this session (chronological)
1. **Diag tools installed** (approved): nvme-cli, numactl, lm-sensors; coretemp persisted
   (`/etc/modules-load.d/coretemp.conf`). CPU pkg 51°C, all thermals healthy.
2. **Email alerting LIVE (was the #1 finding — every alert dead-ended before):**
   - PVE: endpoint `gmail-smtp` (smtp.gmail.com:587 STARTTLS, app pw in PASSWORDS.md),
     `default-matcher` → gmail-smtp. Covers vzdump + PVE alerts.
   - postfix: relayhost + SASL + root→gmail alias + ipv4 preference. Covers ZED/smartd/cron.
   - BOTH test mails confirmed received by Andrew. libsasl2-modules installed.
3. **Stale bookworm apt entries removed** (sources.list emptied; backup
   `/root/sources.list.bak-20260709`); apt verified clean.
4. **Full upgrade → PVE 9.2.4**, 0 pending. New kernels 7.0.14-4 + 6.17.13-15 landed on ESPs
   but **pin 7.0.6-2-pve verified intact** (won't boot until pin-tested). VMs stayed up;
   running VMs keep old QEMU binary until next stop/start.
5. **rpcbind + nfs-client disabled** — port 111 closed. NAS backup is CIFS → unaffected.
6. **ARC cap 8G → 16G** (runtime sysfs + zfs.conf + initramfs; backup /root/zfs.conf.bak-20260709).
7. **zpool upgrade** rpool/vm-critical/vm-ephemeral (block_cloning_endian, physical_rewrite).
8. **Deleted VM200 snapshot** `Generic-Host-Config` (+5.1G). Kept 184's `pre_phase12_firewall`
   deliberately until Phase 12 confidence window closes (delete in ~1-2 weeks).

### Decisions (Andrew)
- **⏸️ SEC-1 (SSH key-only on host) + SEC-2 (web UI TOTP) DEFERRED** — home lab in apartment,
  LAN-only, perimeter just locked down (Phase 12). Revisit later. Host SSH still root+password.
- Committing/pushing everything is ON HOLD (uncommitted: Phase 12 docs, phase13, MEMORY updates).

### Key discoveries for future work
- **vm-ephemeral pool is ashift=9** (zdb-verified; NM620 drives are 512B-LBA-only so fix =
  rebuild pool with `-o ashift=12`, ~1h Runner+QA downtime; vm-critical/rpool are correct at 12).
- **SNC enabled in BIOS** → 2 NUMA nodes (64.1+64.5 GB, distance 10/11); recommend disabling
  at next BIOS visit. Only **4/6 memory channels** populated (2x32GB more = +bandwidth +192GB).
- **Host runs Tailscale** (100.108.209.77) — was undocumented. **Idle Quadro P2000** on nouveau.
- **AMT unverified** — NIC literally named "amt" (I219-LM shared with Intel AMT); check MEBx
  at next BIOS visit.
- Fallback kernel 6.17.2-1 NO LONGER on ESPs (only 6.17.13-x, 7.0.x).

### Next steps (in rough priority)
1. vzdump jobs for VMs 183 + 184 (per phase8 recipe, stagger 02:30/03:00) + one test restore.
2. VM 185 (OpenClaw, retired) destroy decision → final backup then `qm destroy` (+51G freed).
3. Maintenance-window batch (console access): verify AMT off + disable SNC in BIOS →
   pin-test kernel 7.0.14-4 (--next-boot) → rebuild vm-ephemeral ashift=12 → optional host.fw.
4. Phase 8 monitoring stack (Prometheus/Grafana) — sensors now feed it.
5. Git commit/push when Andrew lifts the hold.

### Blockers
None. Host SSH access for automation = root + password (sshpass; PASSWORDS.md) — workstation
pubkey is NOT on the host (deliberate, SEC-1 deferred).

---

## ✅ DONE — Phase 12: Network Perimeter Lockdown (.184 as DMZ) — IMPLEMENTED July 8, 2026

**Status:** ✅ Implemented + validated. Full record: `phases/phase12_network_segmentation.md`.

**What's live (July 8):**
1. **Router:** public VNC/ARD to .200 deleted (Mac-mini = Tailscale-only). 80/443→.184 kept;
   Plex + Tailscale UPnP holes kept; .100 = Verizon ARRIS gear, left alone; UPnP stays enabled.
2. **Capricorn deploy = push:** runner (.182) pulls the images and streams them into .184 via
   `docker save | ssh docker load`; .184 never contacts the registry (.181:5050). On both
   `production` (e0f3057) and `develop` (9e5d2dc). Live-tested — pipeline #137 job #722 green.
3. **.184 inbound-only via Proxmox firewall** (`/etc/pve/firewall/184.fw`, datacenter fw
   enabled via new `cluster.fw`): IN DROP except 80/443 (any) + SSH from .182/.195/.150 + LAN
   ICMP; OUT allows gateway .1 + internet, DROPs all RFC1918. Other VMs unaffected (no .fw files).
   Rollback: `/root/184.fw.bak-20260708` on pve + VM snapshot `pre_phase12_firewall`.

**Validated:** .184 cannot reach .180/.181/.183/.150; internet + DNS from .184 fine; public
sites 200; admin (.195) + runner (.182) SSH in OK; .181→.184:22 blocked; :8080 blocked from LAN.
**.195 is a static IP** (Andrew confirmed) so the SSH allowlist won't go stale.

**Remaining (minor, optional):** off-LAN scan of the WAN IP to confirm only 80/443 answer.
**Next security work lives in Capricorn:** `unified_ui_DEV_PROD_GCP/project/phases/phase22*`
(the public app has no auth — app-layer hardening is now the weakest link).

**Where it came from:** a security review of the Capricorn app (other project,
`unified_ui_DEV_PROD_GCP`, `project/phases/phase22*`). While validating exposure I tested from
.184 itself and found the flat LAN lets the public-facing box reach everything private.

**Verified July 1, 2026 (probes run ON .184):**
- Network is flat: single `vmbr0`, `192.168.1.0/24`, no VLANs. Only .185 uses Tailscale.
- .184 (public, Traefik + Capricorn PROD) can reach **.180:5001/5002 (QA — REAL financial data,
  app has NO auth), .181:80/5050 (GitLab + registry), .183:9000 (Sonar)**. Pulled a real QA
  transaction from .184 with plain `curl` (total_count 4686).
- Router forwards only 80/443→.184, no :22 (per MEMORY — still VERIFY the G3100 table).
- .184 listeners: 80/443/22 + :8080 (Traefik dashboard, LAN-only, not public — bind to localhost).

**Andrew's model (decided this session):**
1. Public reaches ONLY .184:80/443. Nothing else public.
2. Internal LAN stays FLAT — everything-to-everything. NO internal micro-segmentation.
3. .184 does NOT need to reach any internal host → make it **inbound-only (DMZ)**.

**The one blocker to a pure DMZ:** `deploy_prod_local` in Capricorn's `.gitlab-ci.yml` currently
has .184 `docker login` + `docker pull` from the GitLab registry (.181:5050). Fix = switch to
**push** (runner does `docker save … | ssh agamache@.184 "docker load"`), removing .184's only
internal-outbound need. **This edit is in the Capricorn project — do it FIRST**, then this phase's
firewall change won't break deploys.

**Plan (see phase12 for full detail):**
1. Verify/tighten router: only 80/443 → .184.
2. (Capricorn) deploy push-not-pull.
3. Firewall .184: IN 80/443 any + SSH from .182/.195/.150; OUT internet + gateway .1 only;
   **DROP OUT to other 192.168.1.x VMs**. Snapshot + console access first (don't lock out SSH).
4. Optional: bind Traefik :8080 to localhost. Leave all other VMs unchanged (flat).

**⏳ DECISIONS AWAITED from Andrew:**
- Deploy method: `docker save|load` push (pure DMZ) vs keep .184 pulling + allow only .184→.181:5050?
- .184's DNS resolver (router .1 vs internal DNS VM) — needed so OUT rules don't break name resolution.
- Bind/keep Traefik :8080 dashboard?
- Order confirm: Capricorn deploy change first, then .184 firewall.

---

## GitLab VM backups → NAS (June 18, 2026, night) — Phase 8

**Status:** OPERATIONAL ✅  (details: phases/phase8_backups.md)
**What:** Set up nightly whole-VM backups of GitLab (VM 181) to the NAS for disaster recovery
(the ZFS mirror is not a backup; GitLab holds private-only data).

- NAS layout (NeoCortex 192.168.1.120, SMB only): `ProxmoxBackups/<hostname>/dump/...` —
  per-host subfolder so multiple servers can live under one `ProxmoxBackups`. GitLab →
  `ProxmoxBackups/vm-gitlab-1/`. Attached as Proxmox CIFS storage **`nas-gitlab`** (one storage
  per host, since a storage = one `dump/`).
- Created scheduled job **`gitlab-nightly`**: VM 181, storage nas-gitlab, **02:00 EDT** daily,
  **snapshot** mode (no downtime), **zstd**, **keep-last=7**.
- Seed backup verified: 500 GiB scanned (91% sparse) → **15.3 GB** archive, ~6 min, registered.
- Crash-consistent for now (guest agent not installed; safe for Postgres, and 2 AM is idle).
  App-consistent = enable QEMU guest agent + 1 reboot (deferred).
- Adding another server = mkdir `ProxmoxBackups/<host>` + per-host `nas-<host>` storage + job
  (see phases/phase8_backups.md).
- TODO: one proof-of-life test restore (VMID 999, isolated NIC).

---

## Dual-remote (GitHub-safe / GitLab-full) + secret scrub (June 18, 2026, night)

**Status:** COMPLETE ✅
**What:** Established the same dual-remote model as the Capricorn project
(unified_ui_DEV_PROD_GCP): SAFE/curated content → public GitHub, EVERYTHING (incl.
secrets, plaintext) → private GitLab. NO git-crypt / NO encryption.

### Remotes
- `origin` → GitHub (PUBLIC): `git@github.com:fiberoptix/home-lab-setup.git` (SSH). Curated;
  secrets `.gitignore`'d so they NEVER reach it. Update with **`./push_github.sh`**.
- `gitlab` → GitLab (PRIVATE): `http://root:<pw>@gitlab.gothamtechnologies.com/production/home-lab-setup.git`.
  HTTP "wallet" auth (pw baked into URL in `.git/config`, same as Capricorn/capricorn-docs).
  Full plaintext mirror, pushed with **`./push_gitlab.sh "msg"`**.

> ⚠️ **Renamed Aug 12, 2026: `gl-backup.sh` → `push_gitlab.sh`**, and a new `push_github.sh` was
> added. Push only via the scripts, never a raw `git push`. Everything below describing
> "gl-backup.sh" is the same code under the new name.

### push_gitlab.sh (repo root — formerly gl-backup.sh)
- Snapshots the ENTIRE working tree (tracked + ignored, minus `.DS_Store`) onto `gitlab/main`
  via a temp index — does NOT touch the working tree, real index, or the GitHub-bound `main`.
- Force-includes ignored files (PASSWORDS.md, github_credentials.md, proxmox/credentials,
  nas_credentials, /working/, /ddns/, vmware/*.zip, www/scripts/smb_credentials).
- Handles nested git repos (working/openclaw-ansible) by moving their `.git` to an external
  holding dir during the add, so their WORKING FILES are captured (not empty gitlinks) and
  their `.git` internals are NOT. Always restored.
- GitLab mirror = 98 files; GitHub = ~42 files. (As of Aug 12, 2026 the GitLab snapshot is 208
  files — the education program and its images account for most of the growth.)

### push_github.sh (repo root — new Aug 12, 2026)
- Pushes the curated tree to `origin/main`, and **fails closed**: nothing is pushed unless all four
  gates pass. Gates: (1) `origin` really is GitHub and we are on `main`; (2) no TRACKED file has a
  secret-looking name; (3) every known sensitive path that exists on disk is still gitignored;
  (4) the outgoing diff contains no private-key blocks, no URL with an embedded password, and no AWS
  keys. Then it lists the commits about to become public and demands a typed `yes`.
- **Why it exists:** GitHub has no encryption, so `.gitignore` was the only guard and "verify before
  pushing" was a convention a human or an agent could skip. This makes it enforced.
- ⚠️ **`--yes` is required for non-interactive use; without a TTY it refuses rather than assuming.**
- Content scanning deliberately uses only high-confidence patterns, so the *word* "password" in
  documentation does not trip it. The credentialed-URL check is the one that would catch the GitLab
  wallet (`http://root:<pw>@...`) being committed to a tracked file.
- **Proven, not assumed:** staging a fake `_gatetest.key` made it block, name the file and exit 1
  without pushing; repo state was byte-identical after cleanup.

### What the GitLab mirror preserves — and the context leak we closed

`gitlab/main` and `main` are **fully disjoint** (`git merge-base` finds nothing in common):
**82 real commits on `main` against 22 snapshots on `gitlab/main`.** The mirror keeps every *file*
perfectly and history only coarsely — though it is a genuine commit chain, so diffs between snapshots
work fine.

The leak was that a snapshot could not be tied back to the real history, and when the message
argument was forgotten the snapshot was labelled only `Full snapshot 2026-08-03 17:44:28 EDT` — tree
intact, reason gone. Two of the existing 22 look like that.

✅ **Closed:** `push_gitlab.sh` now auto-stamps. Default is
`Snapshot <ts> — main @ <sha>[+dirty]: <HEAD subject>`, and a message you pass gets
`[main @ <sha>]` appended. **`+dirty` flags a snapshot containing work in no commit at all**, which
is exactly when the SHA alone would mislead. Nothing is lost on the GitHub side — `push_github.sh`
never authors a commit, so real commit messages are untouched.

### Security scrub (CRITICAL — was a real leak)
- Found the master password (Proxmox/VMs/GitLab/NAS), the SonarQube admin password, an old
  deprecated password, and two SonarQube project tokens committed to PUBLIC GitHub (current
  files AND history) in MEMORY.md, phases/current_phase.md, www/scripts/setup_smb_mount.sh.
  (Actual values intentionally NOT repeated here — see PASSWORDS.md.)
- Scrubbed all of them from tracked files → `[See PASSWORDS.md]`. Real values live ONLY in
  PASSWORDS.md (gitignored → GitLab mirror) + `.git/config` wallet.
- Purged from ALL 54 commits with `git filter-repo --replace-text`, force-pushed GitHub
  (`546b85a`→`24cda0c`). Pre-rewrite safety bundle: `/tmp/home-lab-setup-prefilter-*.bundle`.
- User chose NOT to rotate the password. CAVEAT: GitHub may retain orphaned commits by SHA
  until GC; true fix would be rotation. (Offer remains open.)
- git-crypt setup that was started earlier was fully reverted (no `.gitattributes`, filters
  stripped, key removed).

### setup_smb_mount.sh password handling
- No longer hardcodes the SMB pw. Resolves it: `SMB_PASSWORD` env var → `www/scripts/smb_credentials`
  (gitignored; present on GitLab mirror so a LAN clone "just works") → interactive prompt.
- `www/scripts/smb_credentials` holds `SMB_PASSWORD='...'`, gitignored (rule in .gitignore),
  included on GitLab via gl-backup. NEVER on GitHub.

**Commits this session:** `24cda0c` (scrub + dual-remote + gl-backup), `db88fed` (smb_credentials
file wiring). GitLab snapshots: `f65cf2a` (initial full mirror), `087fc5b` (+ smb_credentials).

---

## Tested + adopted kernel 7.0.6-2-pve (June 18, 2026, later)

**Status:** COMPLETE ✅
**What:** After the PVE 9.2 upgrade pulled in `7.0.6-2-pve`, tested it with the same
reversible `--next-boot` procedure, then adopted it permanently.

- Shut down VMs → `kernel pin 7.0.6-2-pve --next-boot` → refresh → reboot.
- **Booted clean on 7.0.6-2** (permanent pin still 6.17.13-13 as auto-revert at that point):
  ZFS healthy, all 6 NVMe present behind VMD, **0 NVMe timeouts**, systemd running, VMs up.
- Made `7.0.6-2-pve` the **permanent pin** + refresh → **rebooted again to confirm it
  boots autonomously** (no next-boot crutch). Came back clean on 7.0.6-2, all 6 VMs up.
- **2 clean reboots total on 7.0.6-2.** `6.17.13-13` + `6.17.2-1` kept installed as fallbacks.
- Note: VM 185 (openclaw, `onboot=1`) auto-started slowly on the first 7.0.6-2 boot
  (had to `qm start 185`); on the confirmation reboot it auto-started fine. Minor timing,
  not kernel-related.

**Now running:** PVE 9.2.3, kernel **7.0.6-2-pve** (pinned). Revert if ever needed:
`proxmox-boot-tool kernel pin 6.17.13-13-pve && proxmox-boot-tool refresh` (console advised).

---

## Proxmox kernel upgrade 6.17.13-13 + PVE 9.1→9.2 + holds removed (June 18, 2026)

**Status:** COMPLETE ✅ (superseded same day by 7.0.6-2 adoption above)
**What:** Successfully escaped the pinned/held kernel state. Upgraded the Proxmox
host kernel into the 6.17 series again (the one that hung in Jan was 6.17.4-2; the
fix landed in 6.17.9+), brought the whole host current to PVE 9.2, and removed all
package holds so `apt` is normal again.

### Sequence (all with VMs gracefully shut down + physical console available)

1. **Graceful VM shutdown** — `qm shutdown` all 5 running guests, confirmed `stopped`.
2. **Installed `6.17.13-13-pve`** via dpkg-download (apt solver still blocked by the
   held `proxmox-default-kernel`). Set `proxmox-boot-tool kernel pin … --next-boot`
   (one-shot) so a failed boot would auto-revert to the permanently-pinned 6.17.2-1.
   `proxmox-boot-tool refresh` to write ESPs.
3. **Rebooted → booted clean on 6.17.13-13.** Verified: `zpool status -x` healthy,
   all 6 NVMe present behind VMD, **0 NVMe timeout/error lines**, `systemctl
   is-system-running` = running, all VMs auto-started (`onboot=1`). The Jan NVMe
   regression is GONE on this kernel.
4. **Made the pin permanent** (`kernel pin 6.17.13-13-pve` + `refresh`). Kept
   6.17.2-1 installed as fallback.
5. **Unheld** `proxmox-default-kernel` + `proxmox-kernel-6.17.2-1-pve-signed`.
6. **Full `apt full-upgrade`** → had to install the `proxmox-kernel-6.17` metapackage
   first (it was missing — that's the root of the recurring `proxmox-default-kernel
   : Depends: proxmox-kernel-6.17` solver error that also blocked tmux earlier). With
   the meta installed, the full upgrade ran clean: **PVE 9.1.4 → 9.2.3** (pve-manager
   9.2.3, qemu-kvm 11.0, ZFS 2.4.2, systemd 257.13, new shim/systemd-boot, ~160 pkgs).

### Current state

- **Running + permanently pinned:** `6.17.13-13-pve`
- **PVE:** 9.2.3 (`pveversion`)
- **Holds:** NONE (apt fully normal — the dpkg-download workaround is no longer needed)
- **Kernel images on disk:** `6.17.2-1` (old fallback), `6.17.13-13` (pinned/running),
  `7.0.6-2` (NEW PVE 9.2 default — installed but **NOT pinned, will not boot**)
- All 6 VMs running, ZFS healthy.

### ⚠️ Important for next time

- A new kernel **`7.0.6-2-pve`** was pulled in by PVE 9.2 as the new default. We are
  **deliberately NOT booting it** — the explicit pin on 6.17.13-13 controls boot
  regardless. If/when we want it, repeat the `--next-boot` dance (test, then make
  permanent) — same procedure as `phase1b`. Do this with console access.
- A **host reboot is recommended** to fully activate systemd 257.13 / libc / QEMU 11.
  It will safely boot back into pinned `6.17.13-13`. (Deferred — would restart VMs.)
- Running VMs still hold the **old QEMU 10.x binary** until each is stopped/started.

See `phases/phase1b_proxmox_kernel_upgrade_safe_try.md` for the full procedure + results table.

---

## `refresh` made detach/reattach-safe with tmux (June 18, 2026)

**Status:** COMPLETE
**What:** Wrapped the `refresh` command in tmux so a disconnected Proxmox web
console no longer kills an in-flight update+reboot run, and so the live status
screen can be re-attached after switching away.

### The problem (observed today)

Ran `refresh`; the 4 fast VMs (.180, .182, .183, .184) updated and rebooted and
showed `DONE` within ~5 min. GitLab (.181) is the slow one (Omnibus reconfigure
~6-15 min). While GitLab was still reconfiguring, the user switched the Proxmox
web UI from the **node Shell** to a **VM VNC console**. That tore down the node
Shell's websocket → `SIGHUP` → killed `refresh.sh` **and its child SSH session
to GitLab** before the final `sudo init 6` could fire.

Result: GitLab finished its apt upgrade (clean, `term.log` ended 18:06:42) but
**never rebooted** (uptime stayed at 14 days). Verified GitLab was idle
(dpkg lock free, no apt/dpkg/gitlab-ctl procs, Sidekiq drained to 0, no active
background migrations), then rebooted it manually from Proxmox
(`ssh agamache@.181 'sudo init 6'`). Came back healthy (all services `run:`,
`/-/readiness` → HTTP 200). All 5 VMs now updated **and** rebooted.

### The fix: tmux self-wrap in refresh.sh

`refresh.sh` now wraps itself in a tmux session named `refresh` (only when on a
terminal, not already inside tmux, and tmux is installed):

- **No existing session** → starts the run in a new tmux session `refresh`.
- **Session already exists** → `exec tmux attach-session` (re-attaches to the
  SAME running process; does NOT start a second run).
- After the run ends, the pane is held (`read`) so a reconnecting user can read
  the final summary (Enter to close, `Ctrl-b d` to detach anytime).
- Non-interactive callers (no tty, e.g. cron) fall through and run directly.
  Per-VM logs in `/tmp/refresh-<ip>.log` are written either way.

Because tmux's server is reparented to PID 1, the run survives the web console
dropping. So the workflow the user wanted now holds: type `refresh` → switch to
a VM VNC console → come back to the node Shell → type `refresh` → land back on
the **same** live status screen, still updating.

### tmux install note (kernel-hold gotcha)

`apt-get install tmux` was **blocked** by a pre-existing unmet dependency on the
Proxmox host: `proxmox-default-kernel : Depends: proxmox-kernel-6.17` (held back
per the kernel-pin policy — NVMe boot issue). Did **NOT** run
`apt --fix-broken install` (would pull a new kernel). Instead installed tmux
safely via dpkg with downloaded debs (deps already present), kernel untouched:
```bash
cd /tmp && apt-get download tmux libevent-core-2.1-7t64 libjemalloc2
dpkg -i tmux*.deb libevent-core*.deb libjemalloc2*.deb   # tmux 3.5a
```
**Pre-existing issue to flag:** the held kernel leaves apt's solver unable to do
normal `apt-get install` of new packages on the Proxmox host. Future package
installs there may need the dpkg-download workaround until the kernel hold is
lifted (Proxmox 6.17.5+ with NVMe fix).

### Validation (non-destructive)

Added a `REFRESH_SELFTEST=1` hook that swaps the per-VM remote command for a
harmless `sleep 45` (no apt, no `init 6`). Used it to prove, without touching
the VMs:
1. Script creates the `refresh` tmux session and runs the live display.
2. Killing the launching console (SIGHUP) leaves the session + run alive.
3. Re-invoking `refresh` attaches to the same session (still 1 session, still 5
   VM SSH sessions — not 10, i.e. no second run).

### Files

- `proxmox/build-scripts/refresh.sh` — added tmux self-wrap + selftest hook
- Deployed to Proxmox `/usr/local/bin/refresh.sh` (md5 matches repo)
- `tmux 3.5a` installed on Proxmox; `refresh` alias unchanged (script self-wraps)

---

## Parallel VM Refresh Script + GitLab Runner GPG Key Fix (May 23, 2026)

**Status:** COMPLETE
**Duration:** ~50 minutes (5:49 PM – 6:35 PM EDT)
**What:** Created `refresh.sh` on Proxmox to update + reboot all 5 home-lab VMs in parallel with live status display. Also fixed expired GitLab Runner apt signing key on .182.

### refresh.sh — Parallel VM Refresh

**Where it lives:**
- Repo: `proxmox/build-scripts/refresh.sh`
- Proxmox: `/usr/local/bin/refresh.sh` (deployed via scp)
- Alias: `refresh` in `/root/.bashrc` (just type `refresh` as root)

**VMs targeted (parallel):** .180, .181, .182, .183, .184
**Explicitly excluded:** .185 (vm-openclaw-1) — managed separately

**What it does on each VM:**
1. Pre-flight: records each VM's `/proc/uptime` (baseline for reboot detection)
2. SSH as `agamache` (key auth, no password)
3. `apt-get update && apt-get upgrade` non-interactively (`DEBIAN_FRONTEND=noninteractive`, `--force-confdef`/`--force-confold`, passwordless sudo)
4. On success (`&&`) → `sudo init 6`

**Live status (redraws every 30s with countdown between ticks):**

| State    | Meaning                                                                |
|----------|------------------------------------------------------------------------|
| RUNNING  | SSH session active, apt working                                        |
| SHUTDOWN | SSH ended (init 6 fired) but VM still reachable (<180s grace)          |
| BOOTING  | SSH ended, host unreachable (reboot in progress)                       |
| DONE     | Host back online with fresh uptime                                     |
| FAILED   | SSH ended; host stayed up with unchanged uptime past 180s grace        |

**Per-VM logs:** `/tmp/refresh-<ip>.log` on Proxmox

### SSH Key Setup (Option B chosen)

- Copied dev workstation's `~/.ssh/id_ed25519`/`.pub` to Proxmox `/root/.ssh/` (chmod 600/644)
- Same key already in `agamache@<vm>:~/.ssh/authorized_keys` (deployed Feb 27, 2026)
- Pre-populated `/root/.ssh/known_hosts` on Proxmox for .180–.184 via `ssh-keyscan`
- Verified: `root@pve → agamache@<each VM>` works key-only, passwordless `sudo -n` confirmed

### Bugs Found and Fixed During Development

**Bug 1: Wait loop blocked on hash-order, not completion order**
First draft used `for vm in "${!PIDS[@]}"; do wait ...; done` which iterates the associative array in bash hash-table order. Fast VMs were "stuck" behind slow ones in the display (GitLab took ~9 min while others took ~2 min, but their `[DONE]` lines couldn't print until GitLab's wait completed). Fixed by switching to **sentinel files** written by each subshell after its ssh exits, plus a polling loop that computes each VM's state independently each tick.

**Bug 2: Premature FAILED during VM shutdown window**
`sudo init 6` returns 0 immediately while shutdown proceeds asynchronously. SSH exits, but the VM is still reachable for ~5–90s before sshd dies. Initial detection logic saw `up >= PRE_UPTIME` and flagged FAILED — incorrectly. Fixed by adding a **180s grace window**: between sentinel-creation and grace expiry, the state is `SHUTDOWN` (not terminal). Only after 180s of "still reachable with old uptime" does it become `FAILED` (real apt failure with no reboot).

### GitLab Runner GPG Key Rotation (.182)

**Problem:** During refresh, `.182` emitted:
```
W: GPG error: ... EXPKEYSIG 3F01618A51312F3F GitLab B.V. (package repository signing key)
```

**Root cause:** Same key fingerprint, but the on-disk copy had `[expired: 2026-02-27]`. GitLab/packagecloud rotated the same keypair forward; the current upstream key expires **Feb 6, 2028**.

**Fix:**
```bash
sudo cp /etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg{,.bak.20260523}
curl -fsSL https://packages.gitlab.com/runner/gitlab-runner/gpgkey \
  | sudo gpg --batch --yes --dearmor \
             -o /etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg
sudo apt-get update   # confirmed clean
```

Fingerprint unchanged: `F6403F65 44A38863 DAA0B6E0 3F01618A 51312F3F`
Next rotation: before Feb 6, 2028

### Verified Both Refresh Runs Succeeded

| Run | All 5 VMs uptime after | systemd is-system-running |
|-----|------------------------|---------------------------|
| 1st (17:58–18:09) | 5–6 min (1 min for .181 due to GitLab Omnibus reconfigure) | running |
| 2nd (18:30–18:33) | 1–2 min (faster, no GitLab Omnibus update) | running |

### Lessons Learned

1. **`init 6` exit code is ambiguous** — often returns 0 because the SSH client reads the success status before the connection drops. Use uptime delta to confirm reboot, not exit code.
2. **Bash associative-array iteration is hash-order** — never rely on it for ordered work; use sentinel files / `wait -n` instead.
3. **GitLab Omnibus reconfigure is slow** (~6–15 min) because it walks hundreds of chef recipes (puma, sidekiq, gitaly, postgres, registry, prometheus, alertmanager). Other Ubuntu VMs finish in ~2 min.
4. **Packagecloud-style apt repos** (GitLab Runner, etc.) can re-issue the same keypair with a new expiration. Refresh by re-downloading from `packages.gitlab.com/.../gpgkey` and re-dearmoring into `/etc/apt/keyrings/` — no source list changes needed.

---

## SSH Key Auth + Cursor Sandbox Script Deployed to All VMs (Feb 27, 2026)

**Status:** COMPLETE
**Duration:** ~5 minutes

### What Was Done

1. **Deployed `fix_cursor_sandbox.sh`** to all 6 VMs (.180-.185)
   - Script fixes Cursor terminal sandbox on Ubuntu with kernel >= 6.2
   - Installs uidmap, sets capabilities on cursorsandbox binary, creates AppArmor profiles
   - Copied to `~/fix_cursor_sandbox.sh` on each VM

2. **Pushed SSH ed25519 key** to all 5 remaining VMs (.180-.184)
   - Used `sshpass` + `ssh-copy-id` (same method as .185 fix earlier)
   - All 6 VMs now have passwordless SSH key auth from dev workstation
   - No more `sshpass` needed for any VM

### VMs Updated

| VM | IP | SSH Key | Script |
|----|-----|---------|--------|
| vm-kubernetes-1 | .180 | ✅ | ✅ |
| vm-gitlab-1 | .181 | ✅ | ✅ |
| vm-gitrun-1 | .182 | ✅ | ✅ |
| vm-sonarqube-1 | .183 | ✅ | ✅ |
| vm-www-1 | .184 | ✅ | ✅ |
| vm-openclaw-1 | .185 | ✅ (earlier) | ✅ |

---

## ✅ Phase 7 COMPLETE: Local WWW/Production Server (Jan 22, 2026)

**Status:** COMPLETE 🎉🎉🎉  
**Duration:** 5:30 PM - 10:00 PM EST (~4.5 hours total)  
**Result:** Capricorn PROD + Splash page live, fully functional, localhost access configured, and all documentation updated. Primary production URL is cap.gothamtechnologies.com

### Final Working Configuration

**Services Running on vm-www-1 (192.168.1.184):**
- ✅ Traefik reverse proxy (ports 80/443/8080)
- ✅ Capricorn frontend (gitlab registry)
- ✅ Capricorn backend (gitlab registry)
- ✅ PostgreSQL (Capricorn database)
- ✅ Redis (Capricorn cache)
- ✅ Splash page (nginx)

**URLs Operational:**
- ✅ https://cap.gothamtechnologies.com (Capricorn PROD)
- ✅ https://www.gothamtechnologies.com (Splash page)
- ✅ https://192.168.1.184 (Direct IP access from internal network)
- ✅ Valid Let's Encrypt SSL certificates (auto-renewal)

### Critical Issue Resolved: Docker Networking

**Problem (8:00 PM):**
- HTTP worked, HTTPS timed out with "Gateway timeout"
- User tested from workstation, laptop, vm-www-1 itself - all failed
- Traefik logs showed it was trying to route to wrong IPs

**Root Cause:**
- Capricorn containers created their own network: `capricorn_capricorn-network` (172.19.0.0/16)
- Traefik was only on `web` network (172.18.0.0/16)
- Traefik couldn't reach backend services because they were on different network
- Traefik logs showed: "Creating server URL=http://172.19.0.5:80" (unreachable)

**Solution (8:40 PM):**
1. Connected Traefik to capricorn network: `docker network connect capricorn_capricorn-network traefik`
2. Updated `/opt/traefik/docker-compose.yml` to include both networks permanently:
   ```yaml
   networks:
     - web
     - capricorn_capricorn-network
   ```
3. Both services immediately started working!

**Architecture Decision:**
- Keep multi-network setup (security benefit)
- Postgres + Redis isolated on capricorn network only
- Traefik bridges both networks
- Frontend/Backend on both networks (can talk to DB and receive traffic)

### Implementation Summary

**Tasks Completed:**
1. ✅ Created VM 184 (vm-www-1, 8GB RAM, 8 cores, 50GB disk)
2. ✅ Installed Ubuntu 24.04 Desktop with static IP
3. ✅ Ran host_setup.sh (Docker, SSH, sudo, git, registry config)
4. ✅ Configured Proxmox firewall (SSH internal only, 80/443 open)
5. ✅ Installed Traefik with Let's Encrypt HTTP-01 challenge
6. ✅ Created splash page (nginx + custom HTML)
7. ✅ Andrew configured Verizon G3100 port forwarding (80, 443)
8. ✅ Verified NoIP DDNS (bullpup.ddns.net)
9. ✅ Andrew created Route53 CNAMEs (cap, www → bullpup.ddns.net)
10. ✅ Let's Encrypt certificates obtained automatically
11. ✅ Updated GitLab CI/CD pipeline (new deploy_prod_local job)
12. ✅ Deployed Capricorn via docker-compose (registry images)
13. ✅ Fixed database initialization (copied SQL scripts)
14. ✅ Resolved NAT hairpinning (added /etc/hosts entry)
15. ✅ Added IP-based routing (direct access via 192.168.1.184)
16. ✅ **FIXED Docker networking** (Traefik on both networks)
17. ✅ Full end-to-end testing (external + internal access)
18. ✅ **FIXED HTTPS mixed content** (frontend API auto-detection)
19. ✅ **Updated README files** (both projects direct users to cap.* primary URL)
20. ✅ **Configured localhost access** (routing rules + /etc/hosts for vm-www-1)

**Cost Savings:** ~$400/year by replacing GCP hosting!

### Post-Deployment Bug Fix: HTTPS Mixed Content (9:00 PM - 9:18 PM)

**Problem Discovered:**
- User attempted to import demo data → failed silently
- Browser console showed "Mixed Content" security errors
- All API calls from HTTPS page to HTTP backend blocked by browser

**Root Cause:**
- Frontend hardcoded `http://hostname:5002` for API URL
- HTTPS page (cap.gothamtechnologies.com) calling HTTP API blocked by browser security
- Vite environment variables are build-time, not runtime (setting at container runtime didn't work)

**Solution Implemented:**
- Updated `frontend/src/config/api.ts` to auto-detect protocol
- HTTPS page → use `https://hostname/api` (via Traefik)
- HTTP page → use `http://hostname:5002` (direct, DEV/QA)
- Single code change, single image works for ALL environments

**Deployment:**
- Commit `c83fe2f` pushed to develop → QA auto-deploy (verified HTTP still works)
- Merged develop → production
- Deployed via GitLab `deploy_prod_local` button
- **Result:** All API calls working, data import functional ✅

**Impact:**
- ✅ PROD-Local: FIXED
- ✅ DEV/QA: UNCHANGED  
- ✅ GCP: UNCHANGED
- ✅ Future: Automatic, no ongoing maintenance

### Final Documentation Updates: README Files (9:20 PM - 9:31 PM)

**Task:** Update public-facing documentation to direct users to local production

**Changes Made:**

**Home Lab Setup README (3 commits):**
1. `95f0dda` - Point to cap.* as primary production URL
   - Project overview: Added "Live Demo (PROD-Local)" with cap.*
   - Applications section: Separated PROD-Local (primary) and GCP (on-demand)
   - Target application: Clarified primary vs backup
2. `218110b` - Changed "GCP Backup" to "GCP Instance"
   - Wording: "GCP Instance" (not "Backup")
   - Purpose: "available on-demand for public demos" (not "interviews")

**Capricorn Project README (2 commits):**
1. `2b64657` - Emphasize cap.* as primary, GCP on-demand only
   - Added warning: "Not always running - deployed on-demand"
   - Added note: "For testing, please use cap.* (always available)"
   - Merged to both develop and production branches

**Result:**
- ✅ Both README files direct users to https://cap.gothamtechnologies.com
- ✅ GCP clearly marked as on-demand for public demos
- ✅ All public documentation consistent across projects
- ✅ GitHub users will find the always-available production instance

**Why This Matters:**
- Users testing Capricorn won't hit a "not available" GCP instance
- Clear messaging: Local is primary, GCP is supplemental
- Cost transparency: Demonstrates local hosting benefits
- Professional presentation: Always-available demo shows reliability

### Localhost Access Fix (10:00 PM - 10:05 PM)

**Problem:**
- User couldn't access app from Chrome on vm-www-1 using localhost or 192.168.1.184
- HTTP worked but HTTPS returned 404 or timed out

**Root Cause:**
- Traefik routing rules only configured for `cap.gothamtechnologies.com` and `192.168.1.184`
- No `Host(\`localhost\`)` routing rule
- `/etc/hosts` missing domain name entries for local trusted certificate access

**Solution Applied:**
1. Added domain names to `/etc/hosts`:
   ```
   127.0.0.1 cap.gothamtechnologies.com
   127.0.0.1 www.gothamtechnologies.com
   ```
2. Updated `/opt/capricorn/docker-compose.yml` with localhost routing labels:
   - Frontend: Added `Host(\`localhost\`)` router
   - Backend: Added `Host(\`localhost\`) && PathPrefix(\`/api\`)` router
3. Restarted containers: `sudo docker compose up -d`

**Result:**
- ✅ https://localhost (works with self-signed cert warning)
- ✅ https://192.168.1.184 (works with self-signed cert warning)
- ✅ https://cap.gothamtechnologies.com (works with Let's Encrypt trusted cert)

**Recommended:** Use domain name on vm-www-1 for trusted certificate without browser warnings.

**Time:** ~5 minutes

---

## 🌐 Phase 7 Implementation: Local WWW/Production Server (Jan 22, 2026) - ARCHIVED

**What:** Replace expensive GCP hosting with local production server

**Goal:** 
- Host Capricorn PROD locally at cap.gothamtechnologies.com
- Host splash page at www.gothamtechnologies.com
- Keep GCP (capricorn.gothamtechnologies.com) for interview demos only
- Save ~$30-45/month in GCP costs

**Phase 7 Plan:** `/phases/phase7_local_www.md`

**Key Decisions:**
| Decision | Choice |
|----------|--------|
| VM | vm-www-1 @ 192.168.1.184 (8GB RAM, 8 cores, 50GB vm-critical) |
| Reverse Proxy | Traefik on same VM (not separate) |
| SSL Method | HTTP-01 (Let's Encrypt, no AWS creds needed) |
| Dynamic DNS | NoIP hostname: bullpup.ddns.net (router-managed) |
| Router | Verizon G3100, ports 80/443 forwarded |
| Network Isolation | Proxmox firewall (SSH internal only, no external) |
| Pipeline | Two manual buttons: "Deploy to Local PROD" + "Deploy to GCP PROD" |

**DNS Layout:**
- cap.gothamtechnologies.com → CNAME → bullpup.ddns.net (local)
- www.gothamtechnologies.com → CNAME → bullpup.ddns.net (local)
- capricorn.gothamtechnologies.com → A → GCP IP (unchanged, interviews)

**Implementation Progress (Jan 22, 2026 - 5:30 PM onwards):**

| Step | Task | Status |
|------|------|--------|
| 1 | Create VM in Proxmox | ✅ DONE (VM 184 created) |
| 2 | Run host_setup.sh | ✅ DONE (running updates) |
| 3 | Configure Proxmox firewall | 🔲 Next |
| 4 | Install Traefik + Docker network | 🔲 |
| 5 | Deploy splash page | 🔲 |
| 6 | Configure G3100 port forwarding | 🔲 Andrew |
| 7 | Verify NoIP DDNS | ✅ DONE (bullpup.ddns.net = 108.6.178.182) |
| 8 | Configure Route53 CNAMEs | 🔲 Andrew |
| 9 | Test SSL certificates | 🔲 |
| 10 | Update GitLab CI/CD pipeline | 🔲 |
| 11 | Copy SSH key from runner | 🔲 |
| 12 | Deploy Capricorn via pipeline | 🔲 |
| 13 | End-to-end testing | 🔲 |

**VM Created:**
- VMID: 184
- Name: vm-www-1
- IP: 192.168.1.184
- RAM: 8GB, CPU: 8 cores
- Disk: 50GB on vm-critical (mirrored)
- OS: Ubuntu 24.04 Desktop

**Git Commits:**
- `46846d7` - Enhance setup_desktop.sh: file manager preferences + sysbench fix
- `92c389a` - Phase 7 planning: Local WWW server to replace GCP hosting

---

## 📋 Documentation Verification & Standardization (Jan 14, 2026 - 3:15-4:30 PM)

**What:** Verified actual Proxmox configuration matches documentation, updated all phase files with real hardware specs

**Problem:** Phase files had generic hardware info, drive serials not documented, startup procedure unclear

**Solution Implemented:**
1. ✅ Updated CURSOR_RULES with comprehensive Git Status Check procedure
2. ✅ SSH verified actual Proxmox configuration (storage, VMs, drives, kernel)
3. ✅ Updated phase0_hardware.md with real specs:
   - WD Blue SN5100 500GB boot drives (not generic)
   - Complete drive serial numbers for all 6 drives
   - Detailed BIOS settings table with menu locations
4. ✅ Updated phase1_proxmox.md with accurate config:
   - Real ZFS pool sizes and usage statistics
   - Documented compression settings (rpool=OFF is mistake, should be lz4)
   - Added ZFS management commands section
   - Added backup strategy section
   - Added best practices for creating new pools
5. ✅ Created SYSTEM_VERIFICATION.md:
   - Complete drive inventory with serial numbers
   - VM specifications with actual disk configurations
   - Health check schedule
   - Commands for future VM creation
6. ✅ Changed CURSOR_RULES startup reading order:
   - Now reads phase files first (reality) instead of old planning docs
   - Design.md optional for architecture philosophy

**Key Findings:**
- Boot drives: WD Blue SN5100 500GB (serials: 25434V801543, 25434V802501)
- VM drives: All Lexar NM620 1TB with serials documented
- rpool compression: OFF (mistake - should be lz4)
- vm-critical: 52GB used (58%) - mostly GitLab's 500GB disk
- vm-ephemeral: 40GB used (2%)
- All VMs using correct disk config: `aio=native,cache=none,discard=on,iothread=1`

**Why This Matters:**
- Documentation now accurately reflects production configuration
- Future VM creation will use correct settings
- Drive serial numbers documented for emergency replacement
- ZFS best practices clearly documented (always use lz4 compression)

**Git Commits (Session Total):**
- `f47a3f7` - Update CURSOR_RULES: Git Status Check procedure
- `577717d` - Verify and update documentation (5 files, +409 lines)
- `85e225b` - Update memory files
- `6fecdf3` - Fix: Enable lz4 compression on rpool

**Time:** ~90 minutes (documentation + compression fix)

**✅ Configuration Fix Applied:**
- Enabled lz4 compression on rpool (was OFF due to install mistake)
- All three ZFS pools now properly configured with lz4
- Compression ratios: rpool 1.00x, vm-critical 1.58x, vm-ephemeral 1.63x
- Existing 10GB on rpool remains uncompressed (by design, no issues)
- All future data will be compressed (20-40% space savings)

---

## ✅ COMPLETE: Phase 6 - SonarQube Code Quality Integration

**Status:** COMPLETE - Both test-app and Capricorn integrated!
**Infrastructure:** VM .183 (8GB RAM, 30GB vm-critical, 4 CPU) - optimized
**SonarQube:** v26.1.0 operational at http://192.168.1.183:9000
**Next:** Phase 7 (Monitoring) or Phase 8 (Traefik+SSL)

---

## 🔐 Password Security Cleanup (Jan 13, 2026 - 3:40-7:07 PM)

**What:** Removed hardcoded passwords from all documentation and centralized in git-ignored file

**Problem Identified:**
- Passwords hardcoded in 10+ documentation files
- The standard password and an old deprecated one were scattered throughout project
- All committed to public GitHub repository
- `www/scripts/setup_smb_mount.sh` had hardcoded NAS password in git history

**Solution Implemented:**
1. ✅ Created `PASSWORDS.md` - Central credential storage with all passwords
2. ✅ Added `PASSWORDS.md` to `.gitignore` (will never be committed)
3. ✅ Replaced 28 password instances with `[See PASSWORDS.md]` references
4. ✅ SSH tested to verify current password (value in PASSWORDS.md; old one deprecated)
5. ✅ Fixed markdown display issue (angle brackets → square brackets)

**Files Updated (28 replacements across 10 files):**
- MEMORY.md (8 instances)
- CURSOR_RULES (3 instances)
- phases/current_phase.md (1 instance)
- phases/phase6_sonarqube.md (6 instances)
- phases/phase5_ci_cd_pipelines.md (2 instances)
- phases/phase3_gitlab_server.md (1 instance)
- phases/phase2_host_setup_automation.md (2 instances)
- phases/phase1_proxmox.md (1 instance)
- proxmox/Home_Lab_Proxmox_Build_Plan.md (2 instances)
- proxmox/Home_Lab_Proxmox_Install.md (2 instances)

**Files Intentionally Left Unchanged:**
- `/proxmox/credentials` - Already git-ignored
- `/proxmox/nas_credentials` - Already git-ignored
(Note: `www/scripts/setup_smb_mount.sh` was later updated to read the password from the
 SMB_PASSWORD env var / prompt instead of hardcoding it — see the dual-remote cleanup below.)

**Git Commits:**
- `c71ef79` - Added sysbench to setup_desktop.sh
- `ad74d99` - Security: Remove hardcoded passwords from documentation
- `899d5c1` - Fix: Change angle brackets to square brackets

**Security Status:**
- ✅ Documentation cleaned of passwords
- ✅ Central PASSWORDS.md file (git-ignored)
- ✅ Git history later purged of all passwords/tokens (see dual-remote cleanup below)

**Password Summary:**
- **Current Standard:** [See PASSWORDS.md] (Proxmox, VMs, GitLab, NAS)
- **SonarQube:** [See PASSWORDS.md] (12+ chars required by v26.1.0)
- **Old/Deprecated:** [See PASSWORDS.md] (no longer valid, SSH test failed)

---

## 🎯 Infrastructure Optimization (Jan 12, 2026 - 9:00-9:30 PM)

**What:** Standardized and optimized all 4 VMs for performance and reliability

**Resource Reallocation:**
- GitLab: 16 GB (no change - keep high)
- Runner: 16 GB → **8 GB** (over-provisioned, saves 8 GB)
- SonarQube: 6 GB → **8 GB** (improves scan performance for 28k LOC projects)
- Kubernetes: 16 GB → **8 GB** (only using 2.6 GB with Capricorn running)
- **Total:** 54 GB → 40 GB allocated (14 GB freed, 86 GB available)

**Standardized Configuration (Applied to All VMs):**
1. ✅ CPU type: `host` (was mixed x86-64-v2-AES and host)
2. ✅ Firewall: Enabled on all (SonarQube was missing it)
3. ✅ Auto-start: Enabled on all (only SonarQube had it)
4. ✅ ISO unmount: Removed Desktop ISO from SonarQube
5. ✅ Disk optimizations:
   - `discard=on` - TRIM for ZFS space reclamation
   - `cache=writeback` - 10-30% faster disk writes
   - `aio=native` - Lower CPU overhead, better I/O performance

**Performance Impact:**
- Disk write speed: 10-30% improvement
- CPU overhead: 5-10% reduction
- ZFS efficiency: Better space management
- System reliability: Auto-recovery after Proxmox reboot

**Guest OS Standardization:**
- ✅ `sysbench` installed on all VMs
- ✅ Bash alias added: `sysbench` → runs CPU benchmark with all cores
- ✅ Updated `setup_desktop.sh` to include sysbench for future VMs

**Why This Matters:**
- All future VMs will be built with this standard configuration
- Documented in MEMORY.md "VM CONFIGURATION STANDARD" section
- Ensures consistency, performance, and reliability across the infrastructure

---

## 🔥 Critical Incident: Proxmox Kernel Issue (Jan 12, 2026)

**Moved.** Full write-up of the failed `6.17.2-1 → 6.17.4-2` upgrade, NVMe-timeout
boot failure, and rollback now lives in
**`phases/phase1a_proxmox_upgrade_fail_rollback.md`**. The forward-looking safe-retry
plan is in **`phases/phase1b_proxmox_kernel_upgrade_safe_try.md`**.

---

## ✅ COMPLETE: Phase 5 - CI/CD Pipelines (QA + GCP Both Working!)

**Infrastructure:** Production-ready with full automation (QA + GCP)
**Status:** Phases 0-5 complete, automated deployments to QA and GCP operational

---

## ✅ Completed This Session (Jan 12-13, 2026)

**Phase 6 Planning (5:00 PM - 5:56 PM):**
- Created comprehensive `/phases/phase6_sonarqube.md` plan
- VM specs: .183, 6GB RAM, 30GB disk on vm-critical (rpool2)

**Phase 6 Implementation (6:00 PM - 9:00 PM):**
- ✅ Created vm-sonarqube-1 (192.168.1.183, 6GB RAM, 30GB vm-critical, 4 CPU)
- ✅ Ran host_setup.sh (Docker, SSH, sudo, NAS, registry config)
- ✅ Installed SonarQube container (Docker)
- ✅ **UPGRADED:** 9.9.8 (lts-community) → 26.1.0 (community latest)
  - Old version showed "no longer active" warning
  - Had to wipe database (incompatible formats)
  - Changed Docker tag from `sonarqube:lts-community` to `sonarqube:community`
- ✅ Changed admin password: [See PASSWORDS.md] (12 chars required in new version)
- ✅ Created test-app project in SonarQube
- ✅ Generated test-app token: [See PASSWORDS.md]
- ✅ Created Capricorn project in SonarQube
- ✅ Generated Capricorn token: [See PASSWORDS.md]
- ✅ Added CI/CD variables to GitLab (SONAR_HOST, SONAR_TOKEN)
- ✅ Fixed variable naming issues (SONAR_ → SONAR_HOST)
- ✅ Updated token after database wipe
- ✅ Added scan stage to test-app/.gitlab-ci.yml
- ✅ Added scan stage to Capricorn/.gitlab-ci.yml (develop branch)
- ✅ **BOTH PIPELINES WORKING:** Scans complete, Quality Gates PASSED!

**Results:**
- test-app: 86 LOC, 0 bugs, 0 security issues ✨
- Capricorn: 28k LOC, Quality Gate PASSED (5 security, 144 reliability, 490 maintainability issues identified)

---

## ✅ Completed Previous Session (Jan 11, 2026 - Morning Session)

**GitHub Repository Setup (9:00 AM):**
- Published home-lab-setup to GitHub
- Created comprehensive README with hardware specs
- Multiple refinements (hardware cost, Z8 G4, rpool naming)
- 8 commits total to GitHub

**Phase 5 - Test App CI/CD (10:00 AM - 11:30 AM):**
- Created test-app (nginx + animated HTML splash page)
- Built 3-stage pipeline: build → push → deploy
- Fixed Docker API version (docker:27 not docker:24.0)
- Configured CI/CD variables in GitLab
- Setup SSH keys for deployment
- **SUCCESS:** http://192.168.1.180:8080 deployed via pipeline!

**Capricorn CI/CD Integration (11:45 AM - 1:35 PM):**
- Setup dual-remote configuration (GitHub + GitLab)
- Created "production" group in GitLab
- Established branch strategy (develop → QA, production → GCP)
- **CRITICAL REFACTORING:** Renamed all "prod" → "qa" for clarity
  - run-prod.sh → run-qa.sh
  - docker-compose.prod.yml → docker-compose.qa.yml
  - Dockerfile.*.prod → Dockerfile.*.qa
  - Updated all text: "PROD Environment" → "QA Environment (192.168.1.180)"
- Fixed .gitignore blocking lib/ directories (4 missing API files!)
- Created docker-compose.qa.deploy.yml (registry-based deployment)
- Built Capricorn .gitlab-ci.yml pipeline (QA + GCP stages)
- Fixed SSH key loading in pipeline
- **SUCCESS QA:** Capricorn auto-deploys to http://192.168.1.180:5001
- **SUCCESS GCP:** Capricorn deploys to http://capricorn.gothamtechnologies.com
- Added GCP deployment stage (manual trigger on production branch)
- Installed all tools in pipeline: terraform, gcloud, kubectl, docker buildx
- Fixed service account key file creation
- Added git to prerequisites (removes buildx warning)

**Issues Resolved:**
1. Docker API version mismatch (docker:24.0 → docker:27)
2. Registry authentication (CI/CD variables)
3. SSH key deployment (runner to QA host)
4. YAML script syntax (nested strings)
5. Missing lib/api-client.ts files (.gitignore blocking lib/)
6. SSH key format in CI/CD variable
7. Naming confusion (PROD → QA refactoring)
8. Build stages not running on production branch
9. Tool installation (terraform, gcloud, kubectl in Alpine)
10. Service account key file creation from variable
11. Git missing for docker buildx metadata

---

## Key Achievements

**Complete CI/CD Infrastructure:**
- ✅ GitLab Server verified (git push/pull, Container Registry)
- ✅ GitLab Runner verified (Docker builds, registry push, SSH deploy)
- ✅ Test app pipeline working (validation complete)
- ✅ **Capricorn pipeline working** (production application deployed!)

**Deployment Clarity Established:**
- **DEV** = Local workstation development
- **QA** = vm-kubernetes-1 @ 192.168.1.180 (automated CI/CD)
- **GCP** = Google Cloud Platform (real production)

---

## Previous Sessions

**January 8, 2026:**
- GitHub repository setup and published
- Updated hardware specs and documentation

**December 13, 2025:**
- GitLab Runner (gitlab-runner-1) installed @ 192.168.1.182
- Docker executor configured with socket mount
- Test pipeline verified (standard jobs work, DIND needs work)

---

## Next Steps

**Phase 7 Options:**
- **Option A:** Monitoring Stack (Prometheus + Grafana)
  - System metrics, application monitoring, dashboards
- **Option B:** Traefik + SSL (public HTTPS access)
  - Reverse proxy, automatic SSL certificates

**Future Work:**
- Gmail SMTP: Email notifications for GitLab (low priority)
- Review SonarQube findings and improve code quality
- Consider setting `allow_failure: false` for quality gates

---

## Quick Reference

| VM | IP | Status |
|----|-----|--------|
| QA/K8s | .180 | ✅ |
| GitLab | .181 | ✅ LIVE |
| Runner | .182 | ✅ LIVE |
| SonarQube | .183 | ✅ LIVE (v26.1.0) |

---

## Blockers

None. Phase 6 complete, ready for Phase 7!
