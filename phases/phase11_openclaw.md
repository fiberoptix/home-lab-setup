# Phase 11: OpenClaw AI Agent Server

**Status:** ⛔ **RETIRED AND DESTROYED — August 19, 2026.** Built and completed Feb 20, 2026; ran until
it was retired; **the VM was killed and removed on Aug 19, 2026 and is totally gone.** See the
**"CLOSED" section at the end of this file** for the evidence. Everything
below documents a machine that no longer exists — read it as history, not as configuration.
**Nothing here is reachable.**  
**Depends On:** Phase 2 (Host Setup Automation), Phase 7 (WWW/Script Server)  
**Goal:** Deploy a self-hosted OpenClaw AI agent server with Tailscale VPN access and Telegram integration

---

## Overview

OpenClaw is an open-source AI agent framework (154K+ GitHub stars) that provides:
- A **Gateway** server with web-based **Control UI** (port 18789)
- Multi-channel messaging (Telegram, WhatsApp, Discord, Signal)
- Docker-based **agent sandboxing** for isolated tool execution
- Configurable AI provider backends (OpenRouter, OpenAI, Anthropic, etc.)

The gateway runs directly on the host via Node.js 22+ (not in Docker). Agent tool execution uses Docker containers for sandboxed isolation.

**Key URLs:**
- OpenClaw Docs: https://docs.openclaw.ai
- OpenClaw Repo: https://github.com/openclaw/openclaw

**Reference:** Ansible playbook downloaded to `working/openclaw-ansible/` for reference only (not used for install).

---

## VM Specifications (vm-openclaw-1)

```
VMID: 185
Name: vm-openclaw-1
IP: 192.168.1.185 (static)
RAM: 16 GB (upgraded from 8 GB -- Ubuntu Desktop used 90% at 8 GB)
CPU: 8 cores (host type)
Disk: 50 GB on vm-critical (mirrored ZFS)
OS: Ubuntu 24.04 Desktop
Network: vmbr0 with firewall=1
Auto-start: Yes (onboot=1)
```

**Proxmox Create Command:**
```bash
qm create 185 --name vm-openclaw-1 --memory 16384 --cores 8 --cpu host --numa 0 \
  --onboot 1 --scsihw virtio-scsi-single --net0 virtio,bridge=vmbr0,firewall=1 \
  --scsi0 vm-critical:0,iothread=1,discard=on,cache=none,aio=native,size=50G
```

---

## Implementation Plan

### Step 1: Create VM in Proxmox (SSH to 192.168.1.150)

1. SSH to Proxmox host
2. Run the `qm create` command above
3. Attach Ubuntu 24.04 Desktop ISO
4. Start VM and install Ubuntu Desktop
5. During install: set hostname `vm-openclaw-1`, user `agamache`, password `[See PASSWORDS.md]`
6. After install: configure static IP 192.168.1.185

**Static IP Configuration** (`/etc/netplan/01-static.yaml`):
```yaml
network:
  version: 2
  ethernets:
    ens18:
      dhcp4: no
      addresses: [192.168.1.185/24]
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
```

### Step 2: Run Host Setup Scripts (from VM)

Same process as all other VMs -- download and run from script server:

```bash
wget http://192.168.1.195/scripts/host_setup.sh
chmod +x host_setup.sh
./host_setup.sh
```

This installs: Docker, SSH keys, passwordless sudo, NAS mount, insecure-registry config, sysbench.

Reboot after setup, then run `update` to apply system updates.

### Step 3: Configure Proxmox Firewall

**Firewall rules for vm-openclaw-1 (via Proxmox Web UI or CLI):**

| Direction | Action | Protocol | Port | Source | Purpose |
|-----------|--------|----------|------|--------|---------|
| IN | ACCEPT | TCP | 22 | 192.168.1.0/24 | SSH (LAN only) |
| IN | ACCEPT | TCP | 1885 | 192.168.1.0/24 | OpenClaw Control UI (LAN only) |
| IN | ACCEPT | UDP | 41641 | 0.0.0.0/0 | Tailscale WireGuard |
| OUT | ACCEPT | * | * | * | All outbound (apt, docker, Tailscale, AI APIs) |

Control UI is accessible from the LAN at `http://192.168.1.185:1885` and remotely via Tailscale. Port 1885 is used instead of the default 18789 to avoid automated scanners targeting known OpenClaw instances.

### Step 4: Install Tailscale

Tailscale provides secure remote access to the OpenClaw Control UI from outside the home network. This is the **only VM in the lab with Tailscale**.

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Enable and start the service
sudo systemctl enable --now tailscaled

# Authenticate (opens a URL -- Andrew logs in manually via browser)
sudo tailscale up

# Verify
tailscale ip -4
tailscale status
```

**Manual Step:** Andrew registers the device on the Tailscale admin console (https://login.tailscale.com/admin/machines).

After Tailscale is up, OpenClaw's Control UI will also be accessible at:
- `http://<tailscale-ip>:18789` (from any device on Andrew's Tailscale network, anywhere)

### Step 5: Install OpenClaw (Bash Script)

Simple install using the official installer script. Installs Node.js 22 (if needed) and the OpenClaw CLI globally.

```bash
# Install OpenClaw
curl -fsSL https://openclaw.ai/install.sh | bash
```

The script will:
1. Detect/install Node.js 22+ if missing
2. Install OpenClaw CLI globally via npm
3. Launch the onboarding wizard automatically

### Step 6: Run Onboarding Wizard

If the wizard didn't launch automatically, run it manually:

```bash
openclaw onboard --install-daemon
```

The wizard will prompt for:
1. **Auth token** -- generates a 256-bit token for Control UI access
2. **AI provider** -- skip for now (OpenRouter setup is a manual TODO)
3. **Gateway settings** -- change port to **1885** (default is 18789)
4. **Channel setup** -- skip for now (Telegram configured in Step 7)

The `--install-daemon` flag installs a systemd service so OpenClaw auto-starts on boot.

**Verify installation:**
```bash
# Check service status
openclaw gateway status

# Open Control UI in browser
openclaw dashboard

# Or access directly from any LAN computer:
# http://192.168.1.185:1885
```

### Step 7: Configure Telegram Channel

**Prerequisites:** Create a Telegram bot via @BotFather on Telegram.

1. Open Telegram on iPhone, search for `@BotFather`
2. Send `/newbot`
3. Choose a name (e.g., "OpenClaw Agent") and username (e.g., `openclaw_gotham_bot`)
4. BotFather provides a **bot token** (format: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)

**Add Telegram channel to OpenClaw:**
```bash
openclaw channels add --channel telegram --token "<bot-token-from-botfather>"
```

**Usage:**
- Open Telegram on iPhone
- Start a private chat with the bot
- Messages route through OpenClaw gateway to the AI provider

### Step 8: Manual TODO -- Configure OpenRouter (Andrew)

OpenRouter (https://openrouter.ai) is an API aggregator providing access to multiple LLMs (Claude, GPT-4, Gemini, etc.) through a single API key.

- [ ] Create OpenRouter account at https://openrouter.ai
- [ ] Add credits / payment method
- [ ] Generate API key
- [ ] Configure in OpenClaw: `openclaw configure` (set provider to OpenRouter)
- [ ] Test via Telegram or Control UI

**Reference:** See `/working/open-router.txt` for any notes already captured.

---

## Proxmox Firewall Rules (CLI Reference)

```bash
# SSH to Proxmox
ssh root@192.168.1.150

# Add firewall rules for VM 185
cat >> /etc/pve/firewall/185.fw << 'EOF'
[RULES]
IN ACCEPT -source 192.168.1.0/24 -p tcp -dport 22 -log nolog
IN ACCEPT -source 192.168.1.0/24 -p tcp -dport 1885 -log nolog
IN ACCEPT -p udp -dport 41641 -log nolog
EOF

# Enable firewall for the VM
pvesh set /nodes/pve/qemu/185/firewall/options --enable 1
```

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│  vm-openclaw-1 (192.168.1.185)                               │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  OpenClaw Gateway (Node.js, port 1885)                  │ │
│  │  ├── Control UI (web dashboard)                         │ │
│  │  ├── Telegram Bot Channel                               │ │
│  │  └── OpenRouter API (outbound HTTPS)                    │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  Docker (agent sandboxes)                               │ │
│  │  ├── openclaw-sandbox:bookworm-slim                     │ │
│  │  └── Per-agent isolated containers                      │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  Tailscale VPN (remote access from outside home)        │ │
│  │  └── Control UI at tailscale-ip:1885                    │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  Proxmox Firewall: SSH + Control UI :1885 (LAN) + Tailscale │
└──────────────────────────────────────────────────────────────┘
```

**Access Methods:**
- **Control UI (HTTPS):** https://vm-openclaw-1.tail8f8df.ts.net/ (via Tailscale Serve -- primary method)
- **Control UI (localhost):** http://localhost:1885 (from VM only)
- **Telegram (iPhone):** Private chat with @OC_GothamBot -> OpenClaw Gateway -> AI Provider
- **SSH:** ssh agamache@192.168.1.185 (from LAN only)

**NOTE:** Plain HTTP to LAN IP (http://192.168.1.185:1885) does NOT work -- OpenClaw enforces HTTPS for non-loopback connections.

---

## Validation Checklist

| Check | Command / Method | Expected Result |
|-------|-----------------|-----------------|
| VM running | Proxmox Web UI | VM 185 status: running |
| SSH access | `ssh agamache@192.168.1.185` | Login successful (from LAN) |
| Tailscale connected | `tailscale status` | Shows as connected |
| Tailscale Serve | `sudo tailscale serve status` | HTTPS proxy → localhost:1885 |
| OpenClaw service | `openclaw gateway status` | Running, RPC probe OK |
| Control UI (HTTPS) | `https://vm-openclaw-1.tail8f8df.ts.net/` | Dashboard loads via Tailscale Serve |
| Control UI (localhost) | `http://localhost:1885` (from VM) | Dashboard loads |
| Telegram bot | Send message to @OC_GothamBot | Bot responds |
| Agent sandbox | Run a tool via chat | Docker container created |

---

## Estimated Time

| Task | Estimate |
|------|----------|
| Create VM + Install Ubuntu | 20 min |
| Run host_setup.sh + reboot + updates | 15 min |
| Configure Proxmox firewall | 5 min |
| Install Tailscale + register | 10 min |
| Install OpenClaw (bash script) | 5 min |
| Onboarding wizard + Telegram bot setup | 15 min |
| Validation + testing | 10 min |
| **Total** | **~80 min** |

---

## Files Modified

- `phases/phase11_openclaw.md` (this file)
- `phases/current_phase.md` (update current phase)
- `MEMORY.md` (add OpenClaw VM entry)
- `README.md` (add VM to infrastructure table)
- `working/openclaw-ansible/` (reference only -- not used for install)

---

## Risk Notes

1. **Security exposure** -- In Jan 2026, 42,665 exposed OpenClaw instances were found vulnerable. Our setup mitigates this: Control UI is LAN-only via Proxmox firewall, remote access via Tailscale only, and no ports are forwarded on the router.
2. **No UFW** -- Unlike the Ansible method, the bash script does not install UFW. We rely on Proxmox firewall only, which is consistent with all other VMs in the lab.
3. **OpenClaw runs as `agamache`** -- Unlike the Ansible method which creates a dedicated `openclaw` user, the bash script installs under the current user. This is simpler but means OpenClaw has the same permissions as your login user.
4. **Docker already installed** -- host_setup.sh installs Docker before OpenClaw. OpenClaw expects Docker for agent sandboxing, so this works in our favor -- no conflict.

---

## Reference: Ansible Playbook

The Ansible playbook is saved at `working/openclaw-ansible/` for reference. It includes additional hardening that could be cherry-picked later if desired:
- Dedicated `openclaw` system user (unprivileged)
- Systemd hardening (NoNewPrivileges, PrivateTmp, ProtectSystem)
- UFW firewall + Fail2ban
- Unattended security upgrades
- Docker DOCKER-USER iptables chain (prevents container port exposure)

To review: `cat working/openclaw-ansible/playbook.yml`

---

## Known Issues & Upgrade Notes

### v2026.2.23: Breaking `allowedOrigins` requirement

Non-loopback gateway binds (`gateway.bind: "lan"`) now require `gateway.controlUi.allowedOrigins`. Without it, the gateway crash-loops. See `current_phase.md` (Feb 24 entry) for full details.

### v2026.3.22: Missing Control UI assets (packaging bug)

The npm package for v3.22 omits the entire `dist/control-ui/` directory. The gateway runs but the Control UI shows "Control UI assets not found. Build them with `pnpm ui:build`." The `pnpm ui:build` command does not work on installed packages -- it's for development only.

**Workaround:** Skip v3.22 entirely. Use v3.13 (stable) or v3.23+ which include the assets.

**Verify before upgrading:** `npm pack openclaw@<version> --dry-run | grep control-ui/`

### Stuck sessions after reboot (observed Mar 16, 2026)

After VM reboot, scheduled heartbeats can timeout and leave session locks that prevent new messages from being processed. Symptoms: Telegram shows "typing" then stops after 2 minutes with no response.

**Fix:** `openclaw gateway restart` (clears session locks)

**Diagnose:**
- Check logs for `typing TTL reached` 
- Check for lock files: `ls ~/.openclaw/agents/main/sessions/*.lock`
- If OpenRouter API works but sessions are locked, restart the gateway

### v2026.3.28: TTS config schema change (observed Apr 6, 2026)

After updating to v3.28 and rebooting, the gateway crash-looped (exit 1, restart every ~5 seconds). Config validation rejects keys that were valid in v3.23.

**Removed/restructured keys:**
- `messages.tts.elevenlabs`
- `messages.tts.openai`

**Renamed keys:**
- `channels.telegram.streamMode` → `channels.telegram.streaming`

**Fix:** `openclaw doctor --fix --non-interactive` (auto-migrates config, restarts gateway)

### v2026.4.5: Plugin config and TTS schema overhaul (observed Apr 6, 2026)

Three separate crash-loop issues after upgrading from v3.28 to v4.5:

**1. `plugins.entries.telegram.config` rejected**
- Doctor v3.28 had duplicated channel settings into the plugin entry
- v4.5 only allows `enabled` and `hooks` in `plugins.entries.<name>` -- no `config` block
- Fix: Remove `config` from `plugins.entries.telegram`

**2. `plugins.entries.elevenlabs.config` rejected**
- Same schema tightening; API keys don't go in plugin entries
- Fix: Remove `config` from `plugins.entries.elevenlabs`

**3. ElevenLabs TTS credentials moved**
- Old location (v3.x): `messages.tts.elevenlabs.apiKey` (top-level under tts)
- Invalid location: `plugins.entries.elevenlabs.config.apiKey`
- **Correct v4.5 location:** `messages.tts.providers.elevenlabs`

```json
"messages": {
  "tts": {
    "provider": "elevenlabs",
    "providers": {
      "elevenlabs": {
        "apiKey": "sk_...",
        "voiceId": "...",
        "modelId": "eleven_multilingual_v2"
      }
    }
  }
}
```

**Doctor could NOT auto-fix any of these.** Use `openclaw config schema` to discover valid paths.

### General upgrade advice

OpenClaw has broken config compatibility on **4 out of 5 upgrades** in this lab (v2026.2.23, v3.22, v3.28, v4.5). Always:
1. Back up config: `cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak`
2. Run `openclaw doctor --fix --non-interactive`
3. If doctor fails, check: `journalctl --user -u openclaw-gateway.service -n 20 --no-pager`
4. Inspect config and remove/restructure keys flagged in the error
5. Use `openclaw config schema` piped to grep/python to find where keys moved
6. Verify: `openclaw gateway status` and `openclaw status --all`

---

## ⛔ CLOSED — VM killed and removed, August 19, 2026

**We killed it and it's totally gone.**

Andrew ordered VM 185 destroyed to make room for the Phase 17 Jenkins build, and **explicitly declined
a backup**. It was executed the same evening:

```
qm destroy 185 --purge 1 --destroy-unreferenced-disks 1
```

**Verified gone**, not assumed gone:

| Check | Result |
|---|---|
| `qm status 185` | `Configuration file 'nodes/pve/qemu-server/185.conf' does not exist` |
| ZFS volumes on `vm-critical` | none matching `185` |
| `/etc/pve/firewall/185.fw` | removed — ✅ **`--purge` deletes the firewall config with the VM** |
| Backups on any storage | **none existed** on `local`, `nas-gitlab`, or `nas-docker-swarm-1/2/3` |
| Snapshots | **none had ever been taken** |

⚠️ **This is irreversible and was chosen to be.** No backup, no snapshot, no archive anywhere. If
OpenClaw is ever wanted again it is a rebuild from this file, not a restore.

**What the lab got back:** 16 GB of RAM and **12 cores** — ⚠️ note the resource table in `MEMORY.md`
had recorded **8** cores, so the real reclaim was larger than the paper one. Removing it also ended
the 1.04:1 vCPU overcommit the lab had carried since the Swarm build.

**Two facts elsewhere that this invalidated**, both corrected in `MEMORY.md` the same evening:

- **`.185` was the only VM running Tailscale.** With it gone, **no VM runs Tailscale** — remote access
  now depends entirely on the subnet route advertised by the pve host.
- **`.185` was one of only two VMs with PVE-level firewall rules.** Now only `.184` has any.

**VMID 185 and `192.168.1.185` are reassigned** to `vm-jenkins-1` — see
[`phase17_jenkins.md`](phase17_jenkins.md).

---

## 📦 OPERATIONAL LOG — demoted from `current_phase.md` on Aug 20, 2026

⛔ **The VM these describe no longer exists** — `vm-openclaw-1` was destroyed Aug 19, 2026 (see the
CLOSED section above). **Nothing here is actionable.** It is kept because it is the only record of how
the agent was actually run and repaired over six months, and because the upgrade write-ups show a
recurring shape worth recognising elsewhere: **an upgrade that silently resets config files, so the
service starts clean and the customisation is what breaks.**

⚠️ **VMID 185 and `.185` now belong to `vm-jenkins-1` (Phase 17).** Any `.185` reference below means
OpenClaw, not Jenkins. Ordered newest first (Apr 2026) to oldest (Feb 2026).

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


## 📦 DEMOTED VERBATIM FROM `MEMORY.md` — Aug 20, 2026

⛔ **The VM is destroyed; nothing below is live.** This was the 151-line OpenClaw section of
`MEMORY.md`, moved here unchanged during a MAKE_MEMORIES demotion — a destroyed VM should not hold
6 % of the always-loaded memory file. **Copied verbatim and diffed before removal, not summarised**,
because three facts existed ONLY there and nowhere in this phase file: the Google Places API key
location, the `pre-elevenlabs-fix` config backup, and the Tailscale IP `100.119.212.71`.

⚠️ **Read it as a 2026 snapshot, not as instructions.** Its own internal "Status: ✅ LIVE" and the
`~~strikethrough~~` corrections are preserved as they were written; editing them would have made the
copy unverifiable against the original.

## OPENCLAW — ⛔ DEAD. VM DESTROYED Aug 19, 2026.

⛔ **`vm-openclaw-1` was killed and removed on Aug 19, 2026 on Andrew's instruction. It is totally
gone** — `qm destroy 185 --purge`, no backup taken (declined on purpose), no snapshot had ever been
made, no ZFS volumes left behind, firewall config purged with it. **Nothing below is reachable.**
Everything in this section is kept as a historical record of what was built and why it was retired;
**do not treat any address, port, token or URL here as live.** VMID 185 and `192.168.1.185` now belong
to **Jenkins** — see `phases/phase17_jenkins.md`.

- **VM:** ~~vm-openclaw-1 @ 192.168.1.185~~ (16GB RAM, **12 cores** — the "8 cores" recorded elsewhere
  was wrong, measured from `qm config` at destroy time — 50GB vm-critical)
- **OS:** Ubuntu 24.04 Desktop
- **Version:** 2026.4.5 (updated Apr 6, 2026; prior: 3.13 → 3.22 → 3.23-beta.1 → 3.28 → 4.5)
- **Install Method:** Bash script (`curl -fsSL https://openclaw.ai/install.sh | bash`)
- **Gateway Port:** 1885 (non-default to avoid scanner detection; default is 18789)
- **Gateway Bind:** LAN (0.0.0.0)
- **Gateway Auth:** Token [See working/open-claw-keys.txt]
- **AI Model:** OpenRouter / Anthropic Claude Sonnet 4.6
- **Status:** ✅ LIVE

**Access:**
- **Control UI (HTTPS):** https://vm-openclaw-1.tail8f8df.ts.net/ (via Tailscale Serve)
- **Control UI (localhost):** http://localhost:1885 (from VM only)
- **Telegram Bot:** @OC_GothamBot (DM policy: pairing required)
- **SSH:** ssh agamache@192.168.1.185 (from LAN only)

**Tailscale:**
- **Tailscale IP:** 100.119.212.71
- **Tailscale Serve:** HTTPS proxy on port 443 → localhost:1885
- ~~This is the ONLY VM with Tailscale in the lab~~ **CORRECTION (Jul 9, 2026): the Proxmox
  HOST also runs Tailscale** (tailscaled active on pve, 100.108.209.77). .185 remains the only *VM* with it.

**CRITICAL: Control UI requires HTTPS or localhost!**
- Plain HTTP to LAN IP (http://192.168.1.185:1885) will NOT work -- OpenClaw blocks it
- Must use Tailscale Serve (HTTPS) or access from VM itself (localhost)
- Tailscale Serve provides auto-managed TLS certs via the tailnet domain

**CRITICAL: allowedOrigins required since v2026.2.23!**
- Non-loopback bind (`gateway.bind: "lan"`) now requires `gateway.controlUi.allowedOrigins`
- Without it, the gateway refuses to start (crash loop, exit 1)
- Current config has: `["https://vm-openclaw-1.tail8f8df.ts.net", "http://localhost:1885", "http://127.0.0.1:1885"]`
- If updating OpenClaw in the future, check release notes for similar breaking security changes

**Services (all auto-start on boot):**
- `openclaw-gateway.service` (systemd user service, enabled, lingering)
- `tailscaled.service` (systemd service, enabled)
- Tailscale Serve (persistent via --bg flag)

**Config:** `~/.openclaw/openclaw.json` on vm-openclaw-1 (permissions: 600)
**Config backups on VM:**
- `~/.openclaw/openclaw.json.bak` (auto-created by doctor)
- `~/.openclaw/openclaw.json.bak.pre-fix` (pre-v2026.2.23 fix)
- `~/.openclaw/openclaw.json.bak.pre-v3.28-fix` (pre-v3.28 fix, Apr 6 2026)
- `~/.openclaw/openclaw.json.bak.pre-v4.5-fix` (pre-v4.5 fix, Apr 6 2026)
- `~/.openclaw/openclaw.json.bak.pre-elevenlabs-fix` (pre-ElevenLabs fix, Apr 6 2026)

**TTS (ElevenLabs) — v4.5 config location:**
- Provider credentials go in `messages.tts.providers.elevenlabs` (NOT `plugins.entries` or top-level `messages.tts`)
- Valid keys: `apiKey`, `voiceId`, `modelId`, `baseUrl`, `seed`, `applyTextNormalization`, `languageCode`
**Logs:** `/tmp/openclaw/openclaw-YYYY-MM-DD.log`
**npm global bin:** `/home/agamache/.npm-global/bin` (added to PATH in .bashrc)

**Installed Skills:** github, himalaya (email), nano-pdf, summarize, blogwatcher, goplaces
**Google Places API Key:** configured in openclaw.json

**Proxmox Firewall (VM 185):**
- IN: SSH (22/tcp) from 192.168.1.0/24
- IN: OpenClaw Control UI (1885/tcp) from 192.168.1.0/24
- IN: Tailscale (41641/udp) from anywhere
- OUT: Allow all
- Default IN policy: DROP

**CLI Commands (must use localhost due to HTTPS enforcement):**
```bash
export PATH=/home/agamache/.npm-global/bin:$PATH
openclaw devices list --url ws://127.0.0.1:1885 --token [See working/open-claw-keys.txt]
openclaw devices approve <requestId> --url ws://127.0.0.1:1885 --token [See working/open-claw-keys.txt]
openclaw gateway status
openclaw gateway restart
openclaw doctor --non-interactive
openclaw status --all
sudo tailscale serve --bg 1885
```

**Update procedure (safe):**
```bash
# 1. Back up config FIRST
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak.pre-update

# 2. Update (pick one)
curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard
# Or: npm update
npm i -g openclaw@latest

# 3. Try doctor first (may not fix everything)
openclaw doctor --fix --non-interactive

# 4. Check if gateway started
openclaw gateway status

# 5. If still crash-looping, check the error and fix config manually:
journalctl --user -u openclaw-gateway.service -n 20 --no-pager
# Then edit ~/.openclaw/openclaw.json to remove offending keys
# Then: openclaw gateway restart

# 6. Final verification
openclaw status --all
```

**Rollback (if update breaks things):**
```bash
npm i -g openclaw@<version>   # e.g. openclaw@2026.2.19-2
openclaw doctor
openclaw gateway restart
```

**Reference:** Ansible playbook at `working/openclaw-ansible/` (not used, kept for reference)
**Phase Plan:** `phases/phase11_openclaw.md`

**SSH:** Key auth from dev workstation ✅ FIXED (Feb 27, 2026 — `ssh-copy-id` via sshpass, same as all other VMs)

**SSHFS Mount (Dev Workstation → OpenClaw):**
- **Mount point:** `/home/agamache/mnt/openclaw` (mounts remote `/home/agamache`)
- **Symlink:** `~/openclaw` → `/home/agamache/mnt/openclaw`
- **Service:** `~/.config/systemd/user/sshfs-openclaw.service` — **DISABLED Jul 25, 2026**
  (VM 185 retired; it was failing + retrying every 100s forever and was the only journal noise
  on the workstation). Unit file left in place — `systemctl --user enable --now sshfs-openclaw`
  to revive if OpenClaw ever comes back.
- **Persistence:** Survives reboot (systemd user service + linger enabled)
- **Options:** reconnect, ServerAliveInterval=15, ServerAliveCountMax=3
- **Manage:** `systemctl --user {status|start|stop|restart} sshfs-openclaw`
- **Why user service not fstab:** fstab mounts run as root (wrong SSH keys); user service runs as agamache

**⚠️ KNOWN BUG: Skip v2026.3.22!**
- npm package is missing `dist/control-ui/` directory (packaging bug)
- Control UI shows "assets not found" error
- v3.13 and v3.23+ both have the UI assets; v3.22 does not
- Verify before upgrading: `npm pack openclaw@<version> --dry-run | grep control-ui/`

**⚠️ POST-UPGRADE: Always run doctor, then verify manually!**
- v2026.3.28: Changed TTS config schema, renamed `streamMode` → `streaming`
- v2026.4.5: Tightened plugin entries (only `enabled`/`hooks` allowed); moved TTS creds to `messages.tts.providers.<name>`
- Doctor FAILED to auto-fix plugin config issues in v4.5
- Gateway crash-loops if config has unrecognized keys
- **After ANY upgrade:** back up config, run `openclaw doctor --fix --non-interactive`, then `openclaw gateway status`
- **If doctor fails:** check `journalctl --user -u openclaw-gateway.service -n 20`, inspect config, remove offending keys
- **Schema discovery:** `openclaw config schema | python3 -c "import sys,json; ..."` to find where keys moved

**Manual TODOs:**
- [x] Configure OpenRouter API key/credits (done, working as of Mar 2026)
- [ ] Test Telegram bot from iPhone
