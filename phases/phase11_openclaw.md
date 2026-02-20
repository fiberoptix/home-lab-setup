# Phase 11: OpenClaw AI Agent Server

**Status:** PLANNING  
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
RAM: 8 GB
CPU: 8 cores (host type)
Disk: 50 GB on vm-critical (mirrored ZFS)
OS: Ubuntu 24.04 Desktop
Network: vmbr0 with firewall=1
Auto-start: Yes (onboot=1)
```

**Proxmox Create Command:**
```bash
qm create 185 --name vm-openclaw-1 --memory 8192 --cores 8 --cpu host --numa 0 \
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
- **LAN (any home computer):** http://192.168.1.185:1885 (Control UI)
- **Remote (Tailscale):** http://tailscale-ip:1885 (Control UI from anywhere)
- **Telegram (iPhone):** Private chat with bot -> OpenClaw Gateway -> AI Provider
- **SSH:** ssh agamache@192.168.1.185 (from LAN only)

---

## Validation Checklist

| Check | Command / Method | Expected Result |
|-------|-----------------|-----------------|
| VM running | Proxmox Web UI | VM 185 status: running |
| SSH access | `ssh agamache@192.168.1.185` | Login successful (from LAN) |
| Tailscale connected | `tailscale status` | Shows as connected |
| OpenClaw service | `openclaw gateway status` | Running |
| Control UI (LAN) | `http://192.168.1.185:1885` | Dashboard loads from any LAN computer |
| Control UI (remote) | `http://tailscale-ip:1885` | Dashboard loads via Tailscale |
| Telegram bot | Send message to bot on iPhone | Bot responds |
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
