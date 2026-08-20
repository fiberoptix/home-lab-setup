# Phase 2: Host Setup Automation

**Status:** ✅ Complete  
**Date:** December 12, 2025  
**Amended:** August 20, 2026 — added `setup_cockpit.sh` to the standard build (see below)

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
    ├── setup_cockpit.sh    # Cockpit web admin on :9090
    ├── setup_docker.sh     # Docker + Git
    ├── setup_smb_mount.sh  # NAS mount
    ├── setup_desktop.sh    # Desktop configuration (11 steps)
    └── anysphere.gpg       # Cursor apt repo GPG key
```

### Usage

**Start/restart server:**
```bash
cd /mnt/DevShare/cursor-projects/home-lab-setup/www
./run_www.sh
```

Editing a script in `www/scripts/` publishes it immediately — nginx serves the
directory straight off disk, so there is no rebuild step. But a VM you already built
keeps whatever it downloaded at build time. Changing a script here changes *future*
builds only.

**Access:** http://192.168.1.195/scripts/

---

## Setup Scripts

### Master Script: host_setup.sh

One command to fully configure a new Ubuntu host:

```bash
bash <(curl -s http://192.168.1.195/scripts/host_setup.sh)
```

Downloads everything first, shows what it got, prompts once, then runs in this order:

| Phase | Script | Gives you |
|-------|--------|-----------|
| 1 Base | `setup_ssh.sh` | SSH in |
| 1 Base | `setup_sudo.sh` | Passwordless sudo |
| 1 Base | `setup_cockpit.sh` | Web admin on :9090 |
| 2 Tools | `setup_docker.sh` | Docker + Git |
| 3 Storage | `setup_smb_mount.sh` | `~/DevShare` NAS mount |
| 4 Desktop | `setup_desktop.sh` | Skipped automatically on headless hosts |

Cockpit sits in Phase 1 with SSH and sudo because it is an *access* method, not a
tool. If a later phase wedges the box, Cockpit is already up and is a second way in.

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

#### 3. setup_cockpit.sh
**Run as:** sudo
**Purpose:** Cockpit web admin UI at `https://<host>:9090`
**Added:** August 20, 2026 — standard on every Ubuntu server from here on

Gives a browser view of services, logs, storage, users, updates and a root terminal,
on a headless box, without installing a desktop.

- Detects whether NetworkManager is active on the host
- Installs an explicit package list chosen for that answer
- **Simulates the install first and aborts if `network-manager` would appear unexpectedly**
- Enables `cockpit.socket` and confirms something is listening on 9090
- Warns if the login user has no password or no sudo

**THE TRAP — never run `apt install cockpit` on a server VM.**
The `cockpit` metapackage *Recommends* `cockpit-networkmanager`, which drags in
`network-manager` itself along with `dnsmasq-base`, `ppp`, `pptp-linux` and
`wpasupplicant`. Our server VMs run netplan + systemd-networkd. Installing
NetworkManager onto a box whose interfaces are already managed by something else
risks losing the network on a machine we only reach over SSH.

Measured on a swarm node, Aug 20 2026:

| Install | Packages added | Pulls network-manager? |
|---------|---------------|------------------------|
| `apt install cockpit` | 35 | **YES** (+ dnsmasq-base, ppp, pptp-linux, wpasupplicant) |
| Our explicit list | 19 | No |

**The safe list:**
```
cockpit-ws cockpit-bridge cockpit-system cockpit-storaged cockpit-packagekit
```
`cockpit-networkmanager` is added **only** when NetworkManager is already the active
network stack — i.e. desktop builds, where the module manages what is already in
charge and is genuinely useful.

**Gotchas:**
- Cockpit authenticates through **PAM**, so it needs a real system password. A
  key-only account cannot log in even though SSH works fine.
- The TLS cert is self-signed. The **Cursor built-in browser cannot open it** —
  `ERR_CERT_AUTHORITY_INVALID` with no bypass offered. Use Chrome or Firefox.
- To verify auth without a browser, hit `/cockpit/login`, not `/login`. `/login`
  serves the HTML page and returns 200 for a good *and* a bad password, so it proves
  nothing. `/cockpit/login` returns a `csrf-token` on success.
- Socket-activated: `cockpit-ws` only starts on connect, so idle cost is ~zero.

#### 4. setup_docker.sh
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

#### 5. setup_smb_mount.sh
**Run as:** sudo  
**Purpose:** Mount NAS share permanently

- Installs cifs-utils
- Mounts `//192.168.1.120/NeoCortex/DEV_Projects`
- Mount point: `/mnt/DevShare`
- Creates symlink: `~/DevShare`
- Persists in /etc/fstab with `_netdev,nofail`

**`nofail` (added Aug 20, 2026).** The script wrote `_netdev` but not `nofail` until
now. Without `nofail` the generated unit is `RequiredBy=remote-fs.target`, so an
unreachable NAS fails the mount, fails `remote-fs.target` with it, stalls boot for the
mount timeout and leaves a permanently failed unit. With `nofail` it is only
`WantedBy=` — it still mounts at boot, it just cannot hold boot up.

⚠️ **Correcting an overstatement made earlier the same day.** This was first written up
here as "drops to an emergency console, no network, no SSH." **That is wrong**, and the
lab disproves it: `_netdev` already keeps these entries out of `local-fs.target`, and
`.184` failed this exact mount at *every* boot from July 9 onward while still coming up
with networking and SSH fine. The emergency-console behaviour belongs to network mounts
written **without** `_netdev`. The real cost here is a bounded boot delay (11 s measured
on `.184`, up to ~90 s on a timeout) plus a permanently failed unit. Worth fixing,
**not** the catastrophe first claimed. 🧠 The failure mode was believing a plausible
mechanism instead of checking the one host already running the experiment.

Swept across the whole lab on Aug 20, 2026: **all 9 VMs plus the dev workstation** now
show `RequiredBy=` empty.

##### 🚫 Prod-local hosts must NOT mount the NAS

🙋 **Andrew's rule:** *"184 should NOT mount the NAS! It's prod-local."* `.184`
(`vm-www-1`) is the internet-facing DMZ box. Phase 12 gave it
`OUT DROP -dest 192.168.1.0/24` — **no pivot to the internal LAN** — so the NAS is
unreachable from it *by design*.

**What we found there on Aug 20, 2026.** The standard build had given `.184` the NAS
fstab entry anyway. It had been failing at every boot since **July 9**, and — worse
than the noise — it left **`/root/.smbcredentials` sitting on the internet-facing
host** for a share it is forbidden to reach. Removed: fstab line, mount unit,
`/mnt/DevShare`, and the credentials file. `.184` now reports **zero failed units**.

⭐ **The security point, which is the real lesson: a build standard applied uniformly
will plant credentials on hosts your network design deliberately isolates.** The
firewall was doing its job perfectly; the *builder* was the leak. Blanket automation
and a tiered network are in tension, and the automation has to know about the tiers.

**Two guards now enforce this, belt and braces:**

| Guard | Behaviour |
|---|---|
| `bash host_setup.sh --no-nas` | Skips the NAS step outright. The deliberate choice for a known prod-local host. |
| Reachability pre-check in `setup_smb_mount.sh` | Tests `<nas>:445` first and **refuses** to write an fstab entry or credentials if it cannot connect. Catches the case where nobody remembered the flag. |

The pre-check is the one that matters, because it would have prevented the `.184`
situation with no operator knowledge at all. Verified by running the script **on `.184`
itself**: it refused, wrote nothing, and left the host clean.

⚠️ **`SKIP_NAS=1 sudo -E …` does not work on these boxes.** sudo is built with
`env_reset`; it prints *"preserving the entire environment is not supported"* and
silently drops the variable — the script then runs in full. Put the assignment
**after** sudo: `sudo SKIP_NAS=1 bash ./setup_smb_mount.sh`.

**NAS credentials:**
- Server: 192.168.1.120
- User: fiberoptix
- Password: [See PASSWORDS.md]

#### 6. setup_desktop.sh
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

> **Naming update, Aug 2026.** This VM never ran Kubernetes and its VMID (200) never
> matched its IP (.180). It was cloned to **VMID 180, `vm-docker-qa-1`** on Aug 20,
> 2026 and is now the Capricorn QA deploy target. The old name above is left in place
> as the historical record of what was tested in Dec 2025.

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
| Cockpit on every server (Aug 2026) | Browser-based admin on headless boxes without installing a desktop |
| Explicit Cockpit packages, never the metapackage | The metapackage Recommends NetworkManager, which fights netplan/systemd-networkd |
| The script simulates before it installs | A comment saying "don't pull NetworkManager" gets ignored; a script that refuses to proceed does not |
| `nofail` on the NAS fstab entry (Aug 2026) | A NAS outage must not strand a headless VM at an emergency console |

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

