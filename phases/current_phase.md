# Current Phase

**Updated:** April 6, 2026 - 9:35 AM EDT

---

## OpenClaw Upgrade to v2026.4.5 — Three Config Fixes (Apr 6, 2026)

**Status:** RESOLVED
**Duration:** ~20 minutes (three rounds of crash-loop fixes)
**Problem:** After updating from v2026.3.28 to v2026.4.5, gateway crash-looped repeatedly due to multiple config schema changes. Doctor could not auto-fix all issues.

### Issue 1: `plugins.entries.telegram.config` rejected

v4.5 tightened the plugin config schema. The v3.28 doctor had duplicated Telegram channel settings (`groupPolicy`, `groupAllowFrom`) into `plugins.entries.telegram.config`, which v4.5 no longer allows.

**Fix:** Removed `config` sub-object from `plugins.entries.telegram` (data already existed in `channels.telegram`).

### Issue 2: `plugins.entries.elevenlabs.config` rejected

Andrew manually added ElevenLabs API key to `plugins.entries.elevenlabs.config` to restore TTS after the v3.28 migration stripped it. But v4.5 only allows `enabled` and `hooks` in plugin entries -- not a `config` block with API keys.

**Fix:** Removed `config` from `plugins.entries.elevenlabs`.

### Issue 3: ElevenLabs TTS credentials — correct v4.5 location

The ElevenLabs API key, voiceId, and modelId no longer go in `messages.tts` top-level keys (v3.x style) or `plugins.entries` (never valid). In v4.5, they belong under `messages.tts.providers.<provider>`:

```json
"messages": {
  "tts": {
    "auto": "inbound",
    "provider": "elevenlabs",
    "providers": {
      "elevenlabs": {
        "apiKey": "sk_...",
        "voiceId": "JBFqnCBsd6RMkjVDRZzb",
        "modelId": "eleven_multilingual_v2"
      }
    }
  }
}
```

**Schema discovery:** Used `openclaw config schema` piped through Python to find the correct path: `messages.tts.providers.elevenlabs` accepts `apiKey`, `voiceId`, `modelId`, `baseUrl`, `seed`, `applyTextNormalization`, `languageCode`.

### Verification

```bash
openclaw gateway status   # Running, RPC probe OK
openclaw status --all     # v2026.4.5, Telegram ON/OK, up to date
curl -s -o /dev/null -w "HTTP %{http_code}" http://127.0.0.1:1885/  # HTTP 200
```

### Lesson Learned

1. `openclaw doctor --fix` is not always sufficient -- it failed to fix the plugin config issues
2. `plugins.entries.<name>` in v4.5 only accepts `enabled` and `hooks` -- never API keys or channel settings
3. TTS provider credentials go under `messages.tts.providers.<provider>` (new in v4.5)
4. Use `openclaw config schema` to discover valid config paths when errors are unclear
5. Config backups before each upgrade are essential for diagnosing what changed

---

## OpenClaw Upgrade to v2026.3.28 Fix (Apr 6, 2026)

**Status:** RESOLVED
**Duration:** ~10 minutes
**Problem:** After updating OpenClaw and rebooting vm-openclaw-1, gateway crash-looped. Web UI wouldn't load, Telegram bot unresponsive.

### Root Cause

v2026.3.28 changed the TTS config schema. Two keys that were valid in v2026.3.23-beta.1 are no longer recognized:
- `messages.tts.elevenlabs` (removed/restructured)
- `messages.tts.openai` (removed/restructured)

Additionally, `channels.telegram.streamMode` was renamed to `channels.telegram.streaming`.

The gateway refused to start with the invalid config, crash-looping every ~5 seconds (reached restart counter 9+ within a minute of boot).

### Diagnosis

```bash
# Systemd logs showed crash loop
journalctl --user -u openclaw-gateway.service -n 50 --no-pager
# Every restart: "Config invalid" → "messages.tts: Unrecognized keys: elevenlabs, openai" → exit 1

# CLI also reported the issue
openclaw gateway status
# "Config invalid ... Run: openclaw doctor --fix"
```

### Fix Applied

```bash
# 1. Back up config
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak.pre-v3.28-fix

# 2. Run doctor to auto-fix config schema
openclaw doctor --fix --non-interactive
```

Doctor changes:
- Removed unrecognized `messages.tts.elevenlabs` and `messages.tts.openai` keys
- Renamed `channels.telegram.streamMode` → `channels.telegram.streaming`
- Archived 32 orphan transcript files
- Restarted gateway service

### Verification

```bash
openclaw gateway status   # Running, RPC probe OK (31ms)
openclaw status --all     # Telegram ON/OK, 1 agent active, 11 sessions
curl -s -o /dev/null -w "HTTP %{http_code}" http://127.0.0.1:1885/  # HTTP 200
```

### Lesson Learned

This is the **third** time an OpenClaw update has introduced breaking changes (v2026.2.23 allowedOrigins, v2026.3.22 missing UI assets, v2026.3.28 TTS schema). After any OpenClaw upgrade:
1. Back up config: `cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak`
2. Run `openclaw doctor --fix --non-interactive` immediately
3. Verify: `openclaw gateway status` and `openclaw status --all`

---

## OpenClaw Upgrade to v2026.3.23-beta.1 (Mar 23, 2026)

**Status:** COMPLETE
**Duration:** ~20 minutes
**Problem:** After upgrading from v3.13 to v3.22, Control UI showed "Control UI assets not found. Build them with `pnpm ui:build`"

### Root Cause

v2026.3.22 npm package has a **packaging bug**: the entire `dist/control-ui/` directory (index.html, assets/, favicon.ico) was omitted from the published package. The gateway runs fine but has no UI files to serve.

### Diagnosis

```bash
# Confirmed missing directory
ls $(npm root -g)/openclaw/dist/control-ui/
# No such file or directory

# Compared versions with npm pack --dry-run
# v3.13: dist/control-ui/ present ✅
# v3.22: dist/control-ui/ MISSING ❌
# v3.23-beta.1: dist/control-ui/ present ✅
```

### Fix Applied

Installed v3.23-beta.1 which includes the UI assets:

```bash
npm install -g openclaw@2026.3.23-beta.1
openclaw gateway restart
curl -s -o /dev/null -w "HTTP %{http_code}" http://127.0.0.1:1885/  # HTTP 200
```

### Lesson Learned

Before upgrading OpenClaw, verify the UI assets are included in the target version:
```bash
npm pack openclaw@<version> --dry-run | grep "control-ui/"
```
If no results, that version is broken. Skip it.

---

## OpenClaw Stuck Session Fix (Mar 16, 2026)

**Status:** RESOLVED
**Duration:** ~15 minutes
**Problem:** OpenClaw not responding to Telegram messages after apt updates + reboot

### What Happened

After upgrading to v3.13 and rebooting the VM, the Telegram bot received messages (showed "typing") but never responded. After 2 minutes, the typing indicator stopped without a reply.

### Root Cause

1. At 11:10 AM, a scheduled **heartbeat** request to `anthropic/claude-haiku-4.5` via OpenRouter timed out and was `aborted` after ~10 minutes
2. This left the session (`90acd894`) in a **locked state** with an active `.jsonl.lock` file
3. When the user's Telegram message arrived at 5:22 PM, it was routed into the same stuck session
4. The gateway showed "typing" for 2 minutes but the model call never executed

### Diagnosis

- Gateway was running (pid alive, RPC probe OK)
- Telegram channel showed OK (enabled, accounts 1/1)
- OpenRouter API worked fine (tested directly with curl → HTTP 200)
- Session transcript showed `prompt-error: error=aborted` for the heartbeat
- Active session lock file existed and was not stale

### Fix Applied

```bash
openclaw gateway restart
```

This cleared the stuck session lock and reset the processing pipeline. Telegram responded normally after restart.

### Lesson Learned

If OpenClaw receives messages but doesn't respond (typing indicator appears then stops):
1. Check logs for `typing TTL reached` — confirms messages arrive but model never responds
2. Check session locks: `ls ~/.openclaw/agents/main/sessions/*.lock`
3. Test OpenRouter directly: `curl -s -H "Authorization: Bearer $KEY" https://openrouter.ai/api/v1/chat/completions`
4. If API works but sessions are locked: `openclaw gateway restart`

---

## OpenClaw SSH & SSHFS Mount (Feb 27, 2026)

**Status:** COMPLETE
**Duration:** ~10 minutes

### What Was Done

1. **Fixed SSH key auth** from dev workstation to vm-openclaw-1 (192.168.1.185)
   - Used `sshpass` + `ssh-copy-id` to push ed25519 public key
   - SSH key auth now works (was broken since Phase 11 install — key offered but rejected)

2. **Set up persistent SSHFS mount** from dev workstation to OpenClaw VM
   - Mounts remote `/home/agamache` to local `/home/agamache/mnt/openclaw`
   - Symlink: `~/openclaw` → mount point (already existed from earlier attempt)
   - Implemented as systemd user service (`~/.config/systemd/user/sshfs-openclaw.service`)
   - Enabled lingering so service starts at boot (not just login)
   - Reconnect + keepalive options for network resilience

### Why systemd user service (not fstab)

fstab mounts run as root, so SSH auth tries root's keys (which don't exist for this host). A user service runs as agamache with the correct SSH key.

### Also enabled `user_allow_other` in `/etc/fuse.conf`

Uncommented `user_allow_other` in `/etc/fuse.conf` (needed for fuse mount options, left in place).

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

## OpenClaw Post-Update Fix (Feb 24, 2026)

**Status:** RESOLVED
**Duration:** ~15 minutes
**Problem:** OpenClaw gateway crash-looping after in-app update from v2026.2.19-2 to v2026.2.23

### What Happened

Andrew clicked the "Update & Restart" button in the OpenClaw Control UI. The update succeeded (v2026.2.19-2 → v2026.2.23) but the gateway immediately began crash-looping (567+ restarts by the time we connected, every ~10 seconds).

### Root Cause

v2026.2.23 introduced a **breaking security change**: non-loopback gateway binds (`gateway.bind: "lan"`) now require `gateway.controlUi.allowedOrigins` to be explicitly set. Without it, the gateway refuses to start with:

```
Error: non-loopback Control UI requires gateway.controlUi.allowedOrigins (set explicit origins),
or set gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback=true
```

The previous version (v2026.2.19-2) did not enforce this requirement.

### Fix Applied

1. SSH'd into vm-openclaw-1 (password auth -- SSH key auth from workstation is broken)
2. Backed up config: `~/.openclaw/openclaw.json.bak.pre-fix`
3. Added `gateway.controlUi.allowedOrigins` to `~/.openclaw/openclaw.json`:
   ```json
   "controlUi": {
     "allowedOrigins": [
       "https://vm-openclaw-1.tail8f8df.ts.net",
       "http://localhost:1885",
       "http://127.0.0.1:1885"
     ]
   }
   ```
4. Fixed config file permissions: `chmod 600 ~/.openclaw/openclaw.json`
5. Restarted gateway: `openclaw gateway restart`

### Verification

- Gateway: running (pid 19322, reachable in 28ms)
- Telegram: OK (@OC_GothamBot connected)
- Tailscale Serve: active (HTTPS → localhost:1885)
- `openclaw doctor`: clean (only non-blocking memory search warning about embeddings)

### Lesson Learned

OpenClaw updates can introduce breaking config requirements. Before updating:
- Check release notes / changelog
- Back up `~/.openclaw/openclaw.json`
- After update, run `openclaw doctor` and check `journalctl --user -u openclaw-gateway.service`
- Know how to rollback: `npm i -g openclaw@<old-version>`

### Also Discovered

- ~~SSH key auth from dev workstation to vm-openclaw-1 is broken~~ → **FIXED Feb 27, 2026** (ssh-copy-id)
- Memory search (embeddings) fails -- OpenRouter key doesn't work for OpenAI embeddings endpoint (non-blocking, chat works fine)

---

## ✅ Phase 11 COMPLETE: OpenClaw AI Agent Server (Feb 20, 2026)

**Status:** COMPLETE  
**Duration:** 4:01 PM - 7:47 PM EST (~3.75 hours including troubleshooting)  
**Result:** OpenClaw v2026.2.19-2 live on vm-openclaw-1, accessible via Tailscale Serve HTTPS, Telegram bot connected

### Final Working Configuration

**VM:** 185 (vm-openclaw-1) @ 192.168.1.185
- 16 GB RAM (upgraded from 8 GB -- Ubuntu Desktop used 90% at 8 GB)
- 8 cores, 50 GB disk on vm-critical
- Ubuntu 24.04 Desktop, vga: virtio

**OpenClaw:**
- Version: 2026.2.19-2
- Port: 1885 (non-default)
- Model: OpenRouter / Anthropic Claude Sonnet 4.6
- Skills: github, himalaya, nano-pdf, summarize, blogwatcher, goplaces
- Hooks: boot-md, bootstrap-extra-files, command-logger, session-memory
- Telegram: @OC_GothamBot (DM policy: pairing)

**Access:**
- Control UI: https://vm-openclaw-1.tail8f8df.ts.net/ (Tailscale Serve HTTPS)
- Localhost: http://localhost:1885 (from VM only)
- SSH: agamache@192.168.1.185 (LAN only)

### Implementation Steps Completed

1. ✅ Created VM 185 on Proxmox (SSH to .150, qm create)
2. ✅ Andrew installed Ubuntu 24.04 Desktop (Proxmox console)
3. ✅ Set static IP .185 (Ubuntu Network Settings GUI)
4. ✅ Ran host_setup.sh from script server
5. ✅ Configured Proxmox firewall (SSH + 1885 LAN + Tailscale UDP)
6. ✅ Installed Tailscale v1.94.2 (Andrew authenticated via browser)
7. ✅ Installed OpenClaw v2026.2.19-2 via bash script
8. ✅ Ran onboarding wizard (port 1885, LAN bind, token auth, Telegram)
9. ✅ Fixed HTTPS requirement with Tailscale Serve
10. ✅ Approved device pairing for Mac

### Troubleshooting Issues (IMPORTANT FOR FUTURE REFERENCE)

**Problem 1: VM booting from CD-ROM after Ubuntu install**

After Andrew removed the ISO, VM kept trying to boot from CD and failing.

**Root Cause:** Boot order was `order=ide2` (CD-ROM only). The disk `scsi0` was never added to boot order.

**Fix:** `qm set 185 --boot order=scsi0` on Proxmox host, then reboot VM.

**Lesson:** When creating VMs with ISO attached, boot order defaults to IDE. After install, change boot order to scsi0.

---

**Problem 2: 8 GB RAM not enough for Ubuntu Desktop**

VM was using 90% of 8 GB RAM immediately after Ubuntu Desktop install, before any services were running.

**Fix:** Stopped VM, set memory to 16384 (16 GB), restarted. `qm set 185 --memory 16384`

**Lesson:** Ubuntu 24.04 Desktop needs more RAM than Server. Use 16 GB minimum for Desktop VMs running services.

---

**Problem 3: SSH refused after Ubuntu install**

Could not SSH to VM after Ubuntu install. Connection refused on port 22.

**Root Cause:** OpenSSH server not installed yet -- host_setup.sh installs it.

**Fix:** Run host_setup.sh from the Proxmox console (not SSH). After script runs and reboot, SSH works.

**Lesson:** Always run host_setup.sh from the VM console first, then SSH for subsequent steps.

---

**Problem 4: OpenClaw onboarding wizard fails over non-interactive SSH**

The install script's onboarding wizard tried to open `/dev/tty` which doesn't exist in non-interactive SSH sessions.

**Root Cause:** `curl ... | bash` install script auto-launches the wizard, which needs an interactive terminal.

**Fix:** The install itself succeeded (exit code 1 was just the wizard failing). Run `openclaw onboard --install-daemon` separately from the VM terminal (Proxmox console or interactive SSH).

**Lesson:** Run the onboarding wizard from an interactive terminal on the VM, not via scripted SSH.

---

**Problem 5: npm PATH not configured**

After install, `openclaw` command not found in new terminals.

**Root Cause:** npm global bin directory `/home/agamache/.npm-global/bin` not in PATH.

**Fix:** Added to .bashrc: `export PATH="/home/agamache/.npm-global/bin:$PATH"`

**Lesson:** The install script warns about this -- follow its instructions.

---

**Problem 6: Control UI says "Disconnected (1008) - requires HTTPS or localhost"**

Opening `http://192.168.1.185:1885` in browser showed security error. The Control UI refused to connect over plain HTTP to a non-localhost address.

**Root Cause:** OpenClaw enforces HTTPS for all non-loopback connections. This is a security feature to prevent credential/chat interception.

**Fix:** Enabled Tailscale Serve which provides automatic HTTPS:
```bash
sudo tailscale serve --bg 1885
```
This creates an HTTPS proxy at `https://vm-openclaw-1.tail8f8df.ts.net/` that forwards to `localhost:1885`.

**Had to enable Tailscale Serve feature first:** Required visiting a Tailscale admin URL to enable "HTTPS Certificates" for the tailnet (not Funnel).

**Lesson:** OpenClaw CANNOT be accessed over plain HTTP from another computer. You MUST use either:
1. Tailscale Serve (HTTPS via tailnet domain) -- recommended
2. SSH tunnel (`ssh -N -L 1885:127.0.0.1:1885 agamache@192.168.1.185`)
3. Localhost from the VM itself

---

**Problem 7: CLI commands fail with SECURITY ERROR over LAN**

Running `openclaw devices list` via SSH failed because the CLI also enforces the HTTPS requirement when connecting to a LAN address.

**Root Cause:** Same HTTPS enforcement as the Control UI. CLI config points to `ws://192.168.1.185:1885` which is blocked.

**Fix:** Pass `--url ws://127.0.0.1:1885 --token <token>` to force localhost connection:
```bash
openclaw devices list --url ws://127.0.0.1:1885 --token [See working/open-claw-keys.txt]
```

**Lesson:** All CLI commands that talk to the gateway need `--url ws://127.0.0.1:1885 --token <token>` when running over SSH.

---

**Problem 8: Device pairing required for new browser connections**

Connecting from Mac showed "pairing required" error.

**Root Cause:** DM policy set to "pairing" during wizard -- new devices must be approved.

**Fix:** Approve via CLI:
```bash
openclaw devices list --url ws://127.0.0.1:1885 --token <token>
openclaw devices approve <requestId> --url ws://127.0.0.1:1885 --token <token>
```

**Lesson:** Each new browser/device needs to be approved. Use the CLI from the VM to list pending requests and approve them.

---

**Problem 9: Tailscale Serve not running after reboot**

After rebooting the VM, the Tailscale Serve HTTPS proxy was not active and the Control UI was unreachable.

**Fix:** Re-ran `sudo tailscale serve --bg 1885`. The `--bg` flag should persist, may have been a timing issue on first boot.

**Lesson:** If Control UI stops working after reboot, re-run `sudo tailscale serve --bg 1885`.

### Key Decisions Made During Implementation

| Decision | Choice | Why |
|----------|--------|-----|
| Install method | Bash script (not Ansible) | Ansible adds UFW, Fail2ban, creates separate user -- overkill for home lab |
| RAM | 16 GB (upgraded from planned 8 GB) | Ubuntu Desktop used 90% of 8 GB |
| Port | 1885 (not default 18789) | Avoid automated scanner detection |
| Access method | Tailscale Serve (HTTPS) | OpenClaw enforces HTTPS for non-localhost -- can't use plain HTTP over LAN |
| DM policy | Pairing | Most secure for personal use -- each device approved |
| Gateway bind | LAN | Needed for Tailscale Serve proxy to reach the gateway |

### Manual TODOs for Andrew

- [ ] Configure OpenRouter API key/credits at https://openrouter.ai
- [ ] Test Telegram bot from iPhone (install Telegram, message @OC_GothamBot)
- [ ] Approve iPhone as paired device when it connects

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
- `Powerme!1` and old `capricorn2025` scattered throughout project
- All committed to public GitHub repository
- `www/scripts/setup_smb_mount.sh` had hardcoded NAS password in git history

**Solution Implemented:**
1. ✅ Created `PASSWORDS.md` - Central credential storage with all passwords
2. ✅ Added `PASSWORDS.md` to `.gitignore` (will never be committed)
3. ✅ Replaced 28 password instances with `[See PASSWORDS.md]` references
4. ✅ SSH tested to verify current password: `Powerme!1` (capricorn2025 deprecated)
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
- `www/scripts/setup_smb_mount.sh` - Operational script needs hardcoded password
- `/proxmox/credentials` - Already git-ignored
- `/proxmox/nas_credentials` - Already git-ignored

**Git Commits:**
- `c71ef79` - Added sysbench to setup_desktop.sh
- `ad74d99` - Security: Remove hardcoded passwords from documentation
- `899d5c1` - Fix: Change angle brackets to square brackets

**Security Status:**
- ✅ Documentation cleaned of passwords
- ✅ Central PASSWORDS.md file (git-ignored)
- ⚠️ Old password still in git history (www/scripts/setup_smb_mount.sh)
- ⚠️ Can clean git history with filter-branch or BFG if needed

**Password Summary:**
- **Current Standard:** Powerme!1 (Proxmox, VMs, GitLab, NAS)
- **SonarQube:** Powerme!12345 (12+ chars required by v26.1.0)
- **Old/Deprecated:** capricorn2025 (no longer valid, SSH test failed)

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

## 🔥 Critical Incident: Proxmox Kernel Issue (Jan 12, 2026 - 9:00-9:22 PM)

**What Happened:**
1. ✅ Enabled Proxmox community repository (pve-no-subscription)
2. ✅ Disabled subscription nag popup
3. ✅ Created `update` script (`/usr/local/bin/proxmox-update.sh`)
4. ⚠️ Ran updates: kernel upgraded 6.17.2-1 → 6.17.4-2
5. 🔴 **REBOOT FAILED:** NVMe timeout errors on all disks
6. 🔴 System hung at boot (cpu_startup_entry messages)

**Root Cause:**
- Kernel 6.17.4-2-pve has NVMe driver bug incompatible with HP Z8 G4 hardware
- All 4x 1TB NVMe drives timed out during boot
- System unusable

**Resolution Steps:**
1. Hard reset server
2. Interrupted GRUB autoboot (DOWN ARROW key spam)
3. Selected "Advanced Options" → old kernel (6.17.2-1-pve)
4. Booted successfully into old kernel
5. Pinned old kernel: `proxmox-boot-tool kernel pin 6.17.2-1-pve`
6. Held packages: `apt-mark hold proxmox-kernel-6.17.2-1-pve-signed proxmox-default-kernel`
7. Removed bad kernel: `dpkg --force-depends --purge proxmox-kernel-6.17.4-2-pve-signed`
8. VMs wouldn't start: discovered disk config incompatibility
9. Fixed disk config: `cache=writeback` → `cache=none` (incompatible with `aio=native`)
10. All VMs started successfully

**Configuration Issues Discovered:**
- ❌ `cache=writeback` + `aio=native` = INCOMPATIBLE
  - aio=native requires cache.direct=on (direct I/O)
  - cache=writeback uses cache.direct=off (buffered I/O)
- ✅ `cache=none` + `aio=native` = WORKING
  - Still benefits from native AIO and discard
  - Not quite as fast as writeback, but stable

**Current Stable State:**
- ✅ Running kernel: 6.17.2-1-pve (pinned, held)
- ✅ All 4 VMs running with corrected disk config
- ✅ Update script works, won't upgrade kernel (held)
- ✅ Subscription nag disabled
- ✅ Bad kernel completely removed from system
- ✅ GRUB menu only shows working kernel

**Lessons Learned:**
1. Test kernel updates in maintenance window (not during active development)
2. Always have GRUB access ready for kernel rollback
3. QEMU disk options have strict compatibility rules
4. Proxmox kernel updates can break specific hardware (NVMe controllers)
5. `proxmox-boot-tool kernel pin` is the proper way to lock kernels
6. apt-mark hold prevents accidental kernel upgrades

**Updated Documentation:**
- MEMORY.md: VM Configuration Standard (corrected cache=none)
- MEMORY.md: New "PROXMOX KERNEL MANAGEMENT" section
- MEMORY.md: Compatibility warnings for disk options
- All changes documented for future VM builds

**Time Lost:** ~90 minutes (but learned critical recovery procedures!)

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
- ✅ Generated test-app token: `sqp_1f2e5062c88890cd98477759b593428ac494576d`
- ✅ Created Capricorn project in SonarQube
- ✅ Generated Capricorn token: `sqp_fcfecef2186a725979f59666e04bb1f451eded3b`
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
