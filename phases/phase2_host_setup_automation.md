# Phase 2: Host Setup Automation

**Status:** ✅ Complete  
**Date:** December 12, 2025

---

## Overview

Created a centralized script server and automated setup scripts to configure new Ubuntu VMs consistently. Any new VM can be fully configured with a single command.

---

## Script Server

### Architecture

- **Host:** DEV machine (Ubuntu 25.10 workstation)
- **IP:** 192.168.1.195
- **Port:** 80
- **Technology:** Docker + nginx:alpine container
- **Location:** `/www/` directory in project root

### Files

```
/www/
├── run_www.sh          # Start/restart the server
├── docker-compose.yml  # Container configuration
├── nginx.conf          # Serves /scripts/ with directory listing
└── scripts/            # All setup scripts
    ├── host_setup.sh       # Master orchestrator
    ├── setup_ssh.sh        # SSH server
    ├── setup_sudo.sh       # Passwordless sudo
    ├── setup_docker.sh     # Docker + Git
    ├── setup_smb_mount.sh  # NAS mount
    ├── setup_desktop.sh    # Desktop configuration (11 steps)
    └── anysphere.gpg       # Cursor apt repo GPG key
```

### Usage

**Start/restart server:**
```bash
cd /mnt/hgfs/VM_SHARE/Cursor_Projects/home-lab-setup/www
./run_www.sh
```

**Access:** http://192.168.1.195/scripts/

---

## Setup Scripts

### Master Script: host_setup.sh

One command to fully configure a new Ubuntu host:

```bash
bash <(curl -s http://192.168.1.195/scripts/host_setup.sh)
```

Runs all scripts in order with confirmation prompt.

---

### Individual Scripts

#### 1. setup_ssh.sh
**Run as:** sudo  
**Purpose:** Enable SSH server for remote management

- Installs openssh-server
- Enables and starts SSH service
- Configures firewall (if UFW active)

#### 2. setup_sudo.sh
**Run as:** sudo  
**Purpose:** Passwordless sudo for agamache

- Creates `/etc/sudoers.d/agamache`
- Sets `NOPASSWD: ALL`
- Validates syntax before applying

#### 3. setup_docker.sh
**Run as:** sudo  
**Purpose:** Docker + Git installation

- Installs Git, configures user.name/email
- Adds official Docker apt repository
- Installs Docker CE + Docker Compose plugin
- Adds user to docker group

**Git config:**
- user.name: Andrew Gamache
- user.email: agamache@gothamtechnologies.com
- defaultBranch: main

#### 4. setup_smb_mount.sh
**Run as:** sudo  
**Purpose:** Mount NAS share permanently

- Installs cifs-utils
- Mounts `//192.168.1.120/NeoCortex/DEV_Projects`
- Mount point: `/mnt/DevShare`
- Creates symlink: `~/DevShare`
- Persists in /etc/fstab

**NAS credentials:**
- Server: 192.168.1.120
- User: fiberoptix
- Password: [See PASSWORDS.md]

#### 5. setup_desktop.sh
**Run as:** user (not sudo)  
**Purpose:** Full desktop environment configuration

**11 Steps:**
1. Set timezone to America/New_York
2. Install CLI tools (curl, wget, htop, vim, jq, net-tools, tree, unzip)
3. Install Google Chrome (via .deb)
4. Install Cursor (via apt - official repo)
5. Set display resolution to 1920x1080
6. Hide Home folder icon on desktop
7. Disable screen lock and screen saver
8. Create "Andrew" terminal profile (200x50, transparent dark)
9. Configure dock icons (Files, Chrome, Firefox, Cursor, Terminal, SysMon, Settings, Editor)
10. Disable login keyring prompt (auto-unlock)
11. Add bash aliases:
    - `godev` → `cd ~/DevShare`
    - `update` → `sudo apt update && sudo apt upgrade -y`

**Cursor Installation Note:**
Official Cursor GPG key URL is broken. Key is hosted locally at:
`http://192.168.1.195/scripts/anysphere.gpg`

---

## Test VM: vm-kubernetes-1

Created a test VM to validate all scripts:

| Property | Value |
|----------|-------|
| Name | vm-kubernetes-1 |
| IP | 192.168.1.180 |
| User | agamache |
| Password | [See PASSWORDS.md] |
| OS | Ubuntu 24.04 Desktop |
| Storage | vm-ephemeral pool |

**All scripts tested and working on this VM.**

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Script server on DEV machine | Central location, easy to update |
| Docker nginx vs Python SimpleHTTP | More robust, auto-restart |
| Cursor via apt (not AppImage) | Proper package management, auto-updates |
| Passwordless sudo | Required for automation |
| GPG key hosted locally | Official URL returns 403 |
| Keyring auto-unlock | Eliminates annoying prompt on desktop VMs |

---

## Future Scripts (When Needed)

| Script | Purpose | When |
|--------|---------|------|
| setup_gitlab.sh | GitLab CE installation | Building GitLab VM |
| setup_runner.sh | GitLab Runner + registration | Building Runner VM |
| setup_sonarqube.sh | SonarQube container | Building SonarQube VM |
| setup_monitoring.sh | Prometheus + Grafana | Building Monitoring VM |
| setup_traefik.sh | Reverse proxy + SSL | Building Traefik VM |
| setup_tailscale.sh | VPN for admin access | When ready for remote access |

---

## Related Files

- `/www/` - Script server directory
- `/proxmox/credentials` - All passwords
- `/proxmox/Home_Lab_Proxmox_Design.md` - VM architecture plan

