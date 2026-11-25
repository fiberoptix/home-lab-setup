# refresh.sh (Proxmox host) and the parallel VM refresh

Topic reference (not tied to one phase). Loaded ON TOUCH via `phases/INDEX.md`. Blocks below are copied VERBATIM from `MEMORY.md` as of tag `pre-memory-diet` (Nov 24, 2026).

---

## COPIED VERBATIM FROM `MEMORY.md` @ `pre-memory-diet` (lines 1105–1106) — Nov 24, 2026 (memory-diet, copy-first) — CURRENT STATE: refresh command

- **`refresh` command on Proxmox:** Parallel update + reboot of **7 VMs (.180–.185 and .187)**, live status display. ✅ **`.187` (Rancher/K3s) ADDED Oct 27, 2026 — repo and deployed copies md5-matched (`a3277fad…`), old copy at `/root/refresh.sh.pre-2026-10-27`.** See REFRESH SCRIPT section. ✅ **`.185` (Jenkins) was ADDED Aug 20, 2026 — verified live in `/usr/local/bin/refresh.sh` on Aug 26** (the `VMS=()` array lists .180 through .185). This line previously said "5 VMs (.180-.184)" and described the Jenkins addition as still pending. ⚠️ **`.186` and the Swarm nodes `.191–.193` are deliberately NOT in the array** and are never patched by `refresh` — they must be updated by hand. And `unattended-upgrades` stays masked on Jenkins on purpose, so `refresh` is the only patching path for a host that must not restart mid-build.
- Next: Phase 8 (Monitoring Stack)

---

## COPIED VERBATIM FROM `MEMORY.md` @ `pre-memory-diet` (lines 2097–2211) — Nov 24, 2026 (memory-diet, copy-first) — REFRESH SCRIPT

## REFRESH SCRIPT (PROXMOX HOST)

**Purpose:** Update + reboot all 5 home-lab VMs in parallel from the Proxmox host.

- **Location:** `/usr/local/bin/refresh.sh` on Proxmox (192.168.1.150)
- **Source in repo:** `proxmox/build-scripts/refresh.sh`
- **Alias:** `refresh` in `/root/.bashrc` on Proxmox
- **Invocation:** SSH to Proxmox as root, then type `refresh`
- 🚨 **The deployed copy LAGGED the repo** (found Sep 28, 2026): the Aug 20 PATCHING POLICY header was
  committed but never deployed. Code was identical; synced Sep 28 (old copy kept at
  `/root/refresh.sh.pre-2026-09-28`). ⭐ **After any edit, `md5sum` both copies.**
- ⛔ **Never add `.201`–`.205`** — it reboots every target at once (unconditional `sudo init 6`).

**tmux detach/reattach-safe (since Jun 18, 2026):**
- `refresh.sh` self-wraps in a tmux session named `refresh`.
- Type `refresh` with no session running → starts the run in tmux.
- Type `refresh` while a run is active → **re-attaches to the same run** (does NOT re-run).
- Survives the Proxmox web console dropping (e.g. switching to a VM VNC console);
  tmux server is reparented to PID 1, so the update+reboot keeps going.
- After completion the pane is held so you can reconnect and read the summary
  (Enter to close, `Ctrl-b d` to detach).
- `tmux 3.5a` is installed on Proxmox. It was installed via `apt-get download` +
  `dpkg -i` (NOT `apt-get install`) — the three debs were `tmux`, `libevent-core-2.1-7t64` and
  `libjemalloc2` — because the held kernel
  (`proxmox-default-kernel`/`proxmox-kernel-6.17`) breaks apt's solver for new
  installs on the Proxmox host. Same workaround applies to future host packages
  until the kernel hold is lifted. ✅ **Lifted:** `apt-mark showhold` is empty on Sep 28, 2026 and
  `apt-get -s full-upgrade` resolves cleanly (172 upgraded, 3 new) — the pin, not a hold, controls
  the kernel now.
- **Test hook:** `REFRESH_SELFTEST=1 refresh` runs the full machinery but the
  per-VM remote command is just `sleep 45` (no apt, no reboot) — safe to test.

🚑 **IF A `refresh` RUN DIES MID-FLIGHT AND A VM UPGRADED BUT NEVER REBOOTED — how to finish it safely**
(promoted from the Jun 18, 2026 build record; **GitLab is the one this happens to**, because its Omnibus
reconfigure runs 6–15 min while the others finish in ~2). ⛔ **Do not just `init 6` it.** Confirm it is
genuinely idle first, or you interrupt a reconfigure or a database migration:
1. **`dpkg` lock free**, and no `apt` / `dpkg` / `gitlab-ctl` processes still running.
2. **Sidekiq drained to 0** jobs.
3. **No active background migrations.**
4. Then `ssh agamache@.181 'sudo init 6'`, and after it returns check **all services `run:`** and
   **`/-/readiness` → HTTP 200**.
⭐ **The apt half completing is not the run completing.** On Jun 18 GitLab's `term.log` ended cleanly at
18:06:42 and its uptime still read 14 days — **a successful upgrade that never rebooted looks like success
from the log and like a failure from `uptime`.**

**Lesson from Jun 18:** A `refresh` run was killed mid-flight when the Proxmox
web console was switched to a VM VNC console. The 4 fast VMs had already
rebooted, but GitLab (slow Omnibus reconfigure) finished apt but never got to
`init 6`, so it didn't reboot. tmux wrapping prevents this.

**VMs targeted (parallel):** .180, .181, .182, .183, .184
**Excluded:** ~~.185 (vm-openclaw-1) — managed separately~~ → ⛔ **that VM is gone (Aug 19, 2026).**
🔲 **Phase 17 TODO: add `.185` back as `vm-jenkins-1`, this time as an INCLUDED host.**

**What it does on each VM:**
1. Records pre-update `/proc/uptime` (baseline for reboot detection)
2. SSHes as `agamache` (key auth, no password)
3. Runs `apt-get update && apt-get upgrade` non-interactively
   (`DEBIAN_FRONTEND=noninteractive`, `--force-confdef`/`--force-confold` to keep existing config files, passwordless sudo)
4. On success (`&&`) runs `sudo init 6` to reboot

**Live status display** (redraws every 30s, with countdown in between):

| State    | Meaning                                                                  |
|----------|--------------------------------------------------------------------------|
| RUNNING  | SSH session active, apt is working                                       |
| SHUTDOWN | SSH ended (init 6 fired) but VM still reachable (mid-shutdown, <180s)    |
| BOOTING  | SSH ended, host unreachable (reboot in progress)                         |
| DONE     | Host back online with fresh uptime (reboot complete)                     |
| FAILED   | SSH ended; host stayed up with unchanged uptime past 180s grace          |

**Per-VM logs:** `/tmp/refresh-<ip>.log` on Proxmox (overwritten each run)

**SSH from Proxmox root to VMs:**
- Dev workstation's `~/.ssh/id_ed25519` keypair was copied to Proxmox `/root/.ssh/` (Option B from May 23, 2026 setup)
- Same key is in `agamache@<vm>:~/.ssh/authorized_keys` on all VMs (deployed Feb 27, 2026)
- `/root/.ssh/known_hosts` pre-populated for .180–.184

**Reboot detection trick:** `init 6` exits SSH with ambiguous exit code (often 0) and the VM stays reachable for ~5-90s before sshd dies. Don't rely on ssh exit code — compare `/proc/uptime` before vs after.
⭐ **That ambiguity is WHY the 180s grace window exists** (promoted from the May 23, 2026 build record):
`init 6` returns 0 while shutdown proceeds asynchronously, so a naive check sees "still reachable with the
old uptime" and calls it `FAILED` when it is merely mid-shutdown. **The grace window is not politeness, it
is the only way to distinguish a slow shutdown from a genuine apt failure that never rebooted.**
🚨 **And do not "simplify" the sentinel files back into a `wait` loop.** The first draft used
`for vm in "${!PIDS[@]}"; do wait ...; done`, and **bash iterates an associative array in HASH order, not
completion order** — so fast VMs' `[DONE]` lines could not print until GitLab's 9-minute run finished, and
the display looked hung. Each subshell now drops a **sentinel file** and the poll loop computes every VM's
state independently. ⭐ **The general rule: bash associative-array iteration order is arbitrary — never use
it to sequence work or output.**

**Created:** May 23, 2026 (this session, see `phases/current_phase.md`)

### Storage Pool Selection
- **vm-critical (mirror):** GitLab, SonarQube, Monitoring (data persistence)
- **vm-ephemeral (stripe):** Runner, QA Host (disposable/rebuildable)

### ZFS Pool Creation (NEW POOLS)
**ALWAYS enable lz4 compression on new pools:**
```bash
# Create pool (mirror or stripe)
zpool create <pool-name> [mirror] /dev/<disk1> /dev/<disk2>
# Enable compression (REQUIRED)
zfs set compression=lz4 <pool-name>
```

### Guest OS Setup
After VM creation, run setup script:
```bash
wget http://192.168.1.195/ubuntu/host_setup.sh
bash host_setup.sh
```
Installs: Docker, SSH keys, passwordless sudo, NAS mount, insecure-registry config, sysbench

---
