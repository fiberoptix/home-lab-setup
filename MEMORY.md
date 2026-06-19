# Home Lab Project - AI Memory

**Purpose:** Context reload for AI. No humans read this.

---

## CURRENT STATE

- Proxmox running at 192.168.1.150 (HP Z6 G4: single Xeon Platinum 8168 24c/48t, 128GB RAM, ZFS) — **PVE 9.2.3**, kernel **7.0.6-2-pve** (pinned, tested)
- **NOTE:** The Proxmox server is a **Z6 G4** (single CPU, 128GB). The **dev workstation** we work from is a **Z8 G4** (dual Platinum 8168, 256GB). Don't confuse the two.
- **Jun 18, 2026: kernel fully un-stuck.** Went 6.17.2-1 → 6.17.13-13 → **7.0.6-2-pve** (all NVMe-clean), full host upgrade to PVE 9.2.3, all package holds removed. 7.0.6-2 tested via --next-boot, then made permanent and confirmed it boots autonomously (2 reboots clean). 6.17.13-13 kept as fallback. See current_phase.md + phase1b.
- Script server running at http://192.168.1.195/scripts/
- **GitLab CE LIVE at http://192.168.1.181** (root/[See PASSWORDS.md])
- **GitLab Runner LIVE at 192.168.1.182** (gitlab-runner-1, v18.7.2)
- **Container Registry OPERATIONAL** on port 5050
- **CI/CD Pipeline PRODUCTION-READY** - Full automation working!
- **Test app deployed:** http://192.168.1.180:8080 (via pipeline)
- **Capricorn QA:** http://192.168.1.180:5001 (auto-deploy on develop push)
- **Capricorn GCP:** http://capricorn.gothamtechnologies.com (manual deploy on production)
- **GitHub repos:** home-lab-setup + Capricorn (both updated)
- **SonarQube LIVE at http://192.168.1.183:9000** (v26.1.0, admin/[See PASSWORDS.md])
- **Phase 6 COMPLETE:** Both test-app and Capricorn integrated with SonarQube!
- **Phase 7 COMPLETE:** Local WWW Server operational + all documentation updated! (vm-www-1 @ .184)
- **PROD URLs (PRIMARY):** https://cap.gothamtechnologies.com (Capricorn) + https://www.gothamtechnologies.com (splash)
- **GCP Instance (on-demand):** https://capricorn.gothamtechnologies.com (for public demos)
- **Cost Savings:** ~$400/year by replacing GCP hosting
- **README Files:** Both projects direct users to cap.* as primary production URL
- **Phase 11 COMPLETE:** OpenClaw AI Agent Server LIVE (vm-openclaw-1 @ .185, Tailscale Serve, Telegram)
- **`refresh` command on Proxmox:** Parallel update + reboot of all 5 VMs (.180-.184, excluding .185), live status display. See REFRESH SCRIPT section.
- Next: Phase 8 (Monitoring Stack)

---

## IPs & HOSTS

| Host | IP | Status |
|------|-----|--------|
| Proxmox | .150 | ✅ Running |
| QA/K8s | .180 | ✅ Built (vm-kubernetes-1) |
| GitLab | .181 | ✅ LIVE |
| Runner | .182 | ✅ LIVE (gitlab-runner-1) |
| SonarQube | .183 | ✅ LIVE (vm-sonarqube-1, v26.1.0) |
| **WWW** | **.184** | **✅ LIVE (vm-www-1, Traefik, Capricorn PROD, Splash)** |
| **OpenClaw** | **.185** | **✅ LIVE (vm-openclaw-1, AI agent, Tailscale Serve)** |

---

## CREDENTIALS

**File:** `/proxmox/credentials`

- Proxmox: root / [See PASSWORDS.md]
- All VMs: agamache / [See PASSWORDS.md]
- **SSH key auth:** ✅ ed25519 key deployed to ALL VMs (.180-.185) from dev workstation (Feb 27, 2026)
- **GitLab Web: root / [See PASSWORDS.md]**
- **SonarQube Web: admin / [See PASSWORDS.md]**
- NAS (SMB): fiberoptix / [See PASSWORDS.md] @ 192.168.1.120

---

## GITLAB

- **URL:** http://192.168.1.181 (or gitlab.gothamtechnologies.com)
- **Registry:** http://gitlab.gothamtechnologies.com:5050
- **Sign-up:** Disabled
- **Email:** Not configured yet (Gmail SMTP pending)

**Registry Note:** Uses HTTP. Docker needs `insecure-registries` config:
```json
{"insecure-registries": ["gitlab.gothamtechnologies.com:5050"]}
```
`setup_docker.sh` now auto-configures this for new VMs.

---

## GITLAB RUNNER

- **VM:** vm-gitrun-1 @ 192.168.1.182
- **Name:** gitlab-runner-1 (ID #2)
- **Executor:** Docker (docker:24.0)
- **Tags:** docker, linux, build
- **Status:** ✅ Online, runs untagged jobs
- **Config:** `/etc/gitlab-runner/config.toml`

**DIND Note:** Docker-in-Docker (services: docker:dind) fails. Standard jobs work fine.
Use docker socket mount for builds: `volumes = ["/var/run/docker.sock:/var/run/docker.sock"]`

**APT signing key (packages.gitlab.com):**
- Keyring: `/etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg`
- Source list: `/etc/apt/sources.list.d/runner_gitlab-runner.list` (uses `signed-by=`)
- Fingerprint: `F6403F65 44A38863 DAA0B6E0 3F01618A 51312F3F`
- **Current expiration: Feb 6, 2028** (rotated May 23, 2026 after the old copy expired Feb 27, 2026)
- Backup of expired key: `/etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg.bak.20260523`

**Refresh procedure (when EXPKEYSIG appears again ~early 2028):**
```bash
sudo cp /etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg{,.bak.$(date +%Y%m%d)}
curl -fsSL https://packages.gitlab.com/runner/gitlab-runner/gpgkey \
  | sudo gpg --batch --yes --dearmor \
             -o /etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg
sudo apt-get update   # should be clean: no EXPKEYSIG
```

---

## SCRIPT SERVER

**URL:** http://192.168.1.195/scripts/  
**Restart:** `cd www && ./run_www.sh`

**Setup new host:** 
```bash
wget http://192.168.1.195/scripts/host_setup.sh
chmod +x host_setup.sh
./host_setup.sh
```

**Or one-liner:**
```bash
wget http://192.168.1.195/scripts/host_setup.sh && chmod +x host_setup.sh && ./host_setup.sh
```

**Note:** The main script automatically downloads all sub-scripts (setup_ssh.sh, setup_docker.sh, etc.) before running them.

**After reboot:** Run `update` from terminal to apply system updates.

---

## VM CONFIGURATION STANDARD

**Last Updated:** January 14, 2026 (4:30 PM EST)  
**Documentation Verified:** All specs match running production configuration  
**ALL NEW VMs MUST USE THESE SETTINGS:**

### Proxmox VM Settings (qm create/set)
```bash
-cpu host                    # Use host CPU type (best performance)
-numa 0                      # NUMA disabled for single-socket
-onboot 1                    # Auto-start on Proxmox boot
-scsihw virtio-scsi-single   # SCSI controller
-net0 virtio=XX:XX:XX:XX:XX:XX,bridge=vmbr0,firewall=1  # Firewall ENABLED

# Disk configuration (CRITICAL - use all these flags):
-scsi0 POOL:vm-XXX-disk-0,iothread=1,discard=on,cache=none,aio=native,size=XXG

# Explanation:
# - iothread=1       : Dedicated I/O thread (better performance)
# - discard=on       : TRIM support for ZFS space reclamation
# - cache=none       : No cache (required for aio=native compatibility)
# - aio=native       : Native Linux AIO (lower CPU overhead)

# ⚠️ IMPORTANT COMPATIBILITY NOTE:
# cache=writeback + aio=native are INCOMPATIBLE!
# - aio=native requires cache.direct=on (direct I/O)
# - cache=writeback uses cache.direct=off (buffered I/O)
# - Use cache=none with aio=native (working configuration)
# - Or use cache=writeback with aio=threads (default, but higher CPU)
```

### Current VMs (Last verified Feb 20, 2026)
| VM | CPU | RAM | Disk | Storage | Config |
|----|-----|-----|------|---------|--------|
| **181 - GitLab** | 8 cores | 24 GB | 500 GB | vm-critical | ✅ Standard |
| **182 - Runner** | 8 cores | 12 GB | 100 GB | vm-ephemeral | ✅ Standard |
| **183 - SonarQube** | 4 cores | 12 GB | 30 GB | vm-critical | ✅ Standard |
| **184 - WWW** | 8 cores | 8 GB | 50 GB | vm-critical | ✅ Standard |
| **185 - OpenClaw** | 8 cores | 16 GB | 50 GB | vm-critical | ✅ Standard |
| **200 - Kubernetes** | 8 cores | 12 GB | 100 GB | vm-ephemeral | ✅ Standard |

### RAM Allocation Strategy
- **GitLab:** 24 GB (memory-hungry, upgraded from 16 GB)
- **SonarQube:** 12 GB (upgraded from 8 GB for large project scans)
- **Runner:** 12 GB (upgraded from 8 GB)
- **Kubernetes/QA:** 12 GB (upgraded from 8 GB)
- **WWW:** 8 GB (Traefik + Capricorn PROD + splash)
- **OpenClaw:** 16 GB (AI agent gateway + Docker sandboxes, upgraded from 8 GB -- Ubuntu Desktop used 90%)
- **Total Allocated:** 84 GB of 128 GB available (66%)

---

## REFRESH SCRIPT (PROXMOX HOST)

**Purpose:** Update + reboot all 5 home-lab VMs in parallel from the Proxmox host.

- **Location:** `/usr/local/bin/refresh.sh` on Proxmox (192.168.1.150)
- **Source in repo:** `proxmox/build-scripts/refresh.sh`
- **Alias:** `refresh` in `/root/.bashrc` on Proxmox
- **Invocation:** SSH to Proxmox as root, then type `refresh`

**tmux detach/reattach-safe (since Jun 18, 2026):**
- `refresh.sh` self-wraps in a tmux session named `refresh`.
- Type `refresh` with no session running → starts the run in tmux.
- Type `refresh` while a run is active → **re-attaches to the same run** (does NOT re-run).
- Survives the Proxmox web console dropping (e.g. switching to a VM VNC console);
  tmux server is reparented to PID 1, so the update+reboot keeps going.
- After completion the pane is held so you can reconnect and read the summary
  (Enter to close, `Ctrl-b d` to detach).
- `tmux 3.5a` is installed on Proxmox. It was installed via `apt-get download` +
  `dpkg -i` (NOT `apt-get install`) because the held kernel
  (`proxmox-default-kernel`/`proxmox-kernel-6.17`) breaks apt's solver for new
  installs on the Proxmox host. Same workaround applies to future host packages
  until the kernel hold is lifted.
- **Test hook:** `REFRESH_SELFTEST=1 refresh` runs the full machinery but the
  per-VM remote command is just `sleep 45` (no apt, no reboot) — safe to test.

**Lesson from Jun 18:** A `refresh` run was killed mid-flight when the Proxmox
web console was switched to a VM VNC console. The 4 fast VMs had already
rebooted, but GitLab (slow Omnibus reconfigure) finished apt but never got to
`init 6`, so it didn't reboot. tmux wrapping prevents this.

**VMs targeted (parallel):** .180, .181, .182, .183, .184
**Excluded:** .185 (vm-openclaw-1) — managed separately

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
wget http://192.168.1.195/scripts/host_setup.sh
bash host_setup.sh
```
Installs: Docker, SSH keys, passwordless sudo, NAS mount, insecure-registry config, sysbench

---

## PROXMOX KERNEL MANAGEMENT

**Current Status:** June 18, 2026 — on 6.17.13-13-pve, PVE 9.2.3, holds removed

### Active Kernel
- **Running + permanently pinned:** 7.0.6-2-pve ✅ STABLE (PVE 9.2 default; tested
  Jun 18, 2026 via --next-boot, then pinned permanent and confirmed autonomous boot —
  2 clean reboots, 0 NVMe timeouts, all 6 NVMe present behind VMD, ZFS healthy)
- **Fallbacks kept installed:** 6.17.13-13-pve (prior good) and 6.17.2-1-pve. To revert,
  `proxmox-boot-tool kernel pin 6.17.13-13-pve` + `refresh` (console access advised).
- **History on this box:** 6.17.4-2 hung (Jan); ran 6.17.2-1 pinned; Jun 18 → 6.17.13-13
  → 7.0.6-2 (current). All 6.17.9+ / 7.0 kernels are NVMe-clean here.
- **Holds:** NONE ✅ — `proxmox-default-kernel` + `proxmox-kernel-6.17.2-1-pve-signed`
  unheld Jun 18. `apt install` is normal again (dpkg-download workaround no longer needed).
- **Root cause of the recurring solver error** (`proxmox-default-kernel : Depends:
  proxmox-kernel-6.17`, which had blocked tmux + the first full-upgrade attempt): the
  `proxmox-kernel-6.17` **metapackage was not installed**. Installing it (`apt-get
  install proxmox-kernel-6.17`, deps already satisfied) fixed it permanently.
- **History:** 6.17.4-2 hung the box (Jan 12); ran pinned on 6.17.2-1 until Jun 18.
  See `phases/phase1a_*` (failure) and `phases/phase1b_*` (this upgrade + results).

### Status
- systemd 257.13 / libc / QEMU 11 now fully active (host rebooted Jun 18). VMs were
  stopped+started during the kernel test, so they now run on the new QEMU 11 binary too.

### ⚠️ KNOWN ISSUE: Kernel 6.17.4-2-pve
**Problem:** NVMe timeout errors on all disks during boot (HP Z6 G4 + Intel VMD; 6.17 NVMe regression).
**Full incident + rollback write-up:** `phases/phase1a_proxmox_upgrade_fail_rollback.md`
**Safe retry plan (to 6.17.13-13):** `phases/phase1b_proxmox_kernel_upgrade_safe_try.md`

Short version: Jan 12, 2026 the `update` script bumped `6.17.2-1 → 6.17.4-2`; reboot
hung with NVMe timeouts on all drives. Recovered via GRUB → old kernel, then pinned
`6.17.2-1-pve` and held `proxmox-kernel-6.17.2-1-pve-signed` + `proxmox-default-kernel`,
purged the bad kernel.

**Current Protection (as of Jun 18, 2026):**
```bash
# Pinned kernel (always boots this one):
proxmox-boot-tool kernel list
# Shows: Pinned kernel: 7.0.6-2-pve
#   (6.17.13-13-pve and 6.17.2-1-pve also installed as fallbacks)

# Holds: NONE — removed Jun 18, 2026. apt install works normally again.
apt-mark showhold   # (empty)
```

**Update Script:**
- `/usr/local/bin/proxmox-update.sh` created with alias `update`
- Automatically disables subscription nag after each update
- Checks for reboot required
- The **pin** (not holds) is now what controls which kernel boots. A routine
  `apt upgrade` may install newer kernels, but they will NOT boot until explicitly
  `proxmox-boot-tool kernel pin`-ed and tested with console access.

**KERNEL POLICY (post Jun 18, 2026):** Holds are removed; rely on the **boot pin**
instead. The pin is on `7.0.6-2-pve`. Before adopting any future newer kernel, use the
reversible `--next-boot` procedure in
`phases/phase1b_proxmox_kernel_upgrade_safe_try.md` **with physical/console access**,
verify NVMe + ZFS, then make the pin permanent (this is exactly how 6.17.13-13 and
7.0.6-2 were validated).

---

## STORAGE

**Last Verified:** January 14, 2026 (4:35 PM EST)

| Pool | Drives | Type | Size | Usage | Compression | Ratio | Use |
|------|--------|------|------|-------|-------------|-------|-----|
| rpool | 2x WD Blue SN5100 500GB | mirror | 460GB | 10GB (2%) | lz4 ✅ | 1.00x | Proxmox, ISOs |
| vm-critical | 2x Lexar NM620 1TB | mirror | 952GB | 52GB (5%) | lz4 ✅ | 1.58x | GitLab, SonarQube |
| vm-ephemeral | 2x Lexar NM620 1TB | stripe | 1.86TB | 40GB (2%) | lz4 ✅ | 1.63x | Runner, QA |

**Note:** All pools now have lz4 compression enabled. rpool shows 1.00x ratio because existing data is uncompressed (new data will be compressed).

**Drive Serial Numbers:** See `/SYSTEM_VERIFICATION.md` for complete inventory.

---

## PHASES

| # | Name | Status |
|---|------|--------|
| 0-2 | Hardware/Proxmox/Automation | ✅ |
| 1a | Proxmox kernel upgrade failure + rollback (Jan 12) | ✅ RESOLVED (pinned/held) |
| 1b | Proxmox kernel upgrade — safe retry (→6.17.13-13) | ✅ COMPLETE (Jun 18, 2026, running+pinned) |
| 3 | GitLab Server | ✅ VERIFIED |
| 4 | GitLab Runner | ✅ VERIFIED |
| 5 | CI/CD Pipelines | ✅ COMPLETE (QA + GCP both working!) |
| 6 | SonarQube | ✅ COMPLETE (test-app + Capricorn both integrated!) |
| 7 | Local WWW Server | ✅ COMPLETE (vm-www-1 @ .184, cap + www live!) |
| 8 | Monitoring Stack | 🔲 Planned |
| 11 | OpenClaw AI Agent | ✅ COMPLETE (vm-openclaw-1 @ .185, Feb 20, 2026) |

**Phase docs:** `/phases/`

---

## SONARQUBE

- **URL:** http://192.168.1.183:9000
- **Version:** 26.1.0 (community, latest)
- **Login:** admin / [See PASSWORDS.md]
- **Container:** `sonarqube:community` (Docker)
- **Data:** `/opt/sonarqube/data` (persisted)

**Projects:**
- test-app (token: [See PASSWORDS.md])
  - Quality Gate: PASSED ✅
  - 86 lines of code (HTML, Docker)
  - 0 security issues, 0 bugs, 1 maintainability issue
- capricorn (token: [See PASSWORDS.md])
  - Quality Gate: PASSED ✅
  - 28k lines of code (TypeScript, Python)
  - 5 security issues, 144 reliability issues, 490 maintainability issues

**Note:** Upgraded from 9.9.8 → 26.1.0 (required fresh database)

**Pipeline Integration:** Scan stage runs after build/push, before deploy (allow_failure: true)

---

## WWW SERVER (LOCAL PRODUCTION)

- **VM:** vm-www-1 @ 192.168.1.184
- **RAM:** 8 GB | **CPU:** 8 cores | **Disk:** 50 GB (vm-critical)
- **OS:** Ubuntu 24.04 Desktop
- **URLs:** 
  - https://cap.gothamtechnologies.com (Capricorn PROD)
  - https://www.gothamtechnologies.com (Splash page)
  - https://192.168.1.184 (Direct IP access from internal network)
- **Reverse Proxy:** Traefik v3 (ports 80/443/8080)
- **SSL:** Let's Encrypt (HTTP-01 challenge, auto-renewal)
- **DDNS:** bullpup.ddns.net (Verizon G3100 router-managed)
- **DNS:** AWS Route53 CNAMEs → bullpup.ddns.net

### Docker Network Architecture

**Key Learning:** Traefik must be on BOTH networks to route traffic correctly!

```
web (172.18.0.0/16) - Public-facing network
├── traefik (172.18.0.5)
├── splash (172.18.0.2)
├── capricorn-frontend (172.18.0.4)
└── capricorn-backend (172.18.0.3)

capricorn_capricorn-network (172.19.0.0/16) - Internal application network
├── traefik (172.19.0.6) ← MUST be here to reach backend services!
├── capricorn-frontend (172.19.0.5)
├── capricorn-backend (172.19.0.4)
├── postgres (172.19.0.3) ← NOT on web network (security)
└── redis (172.19.0.2) ← NOT on web network (security)
```

**Why two networks:**
- `web` network: Public-facing services (Traefik, frontend, splash)
- `capricorn_capricorn-network`: Application services + database isolation
- Traefik bridges both networks to route traffic
- Databases stay isolated from public network (security best practice)

### Traefik Configuration

**Location:** `/opt/traefik/`

**docker-compose.yml:**
```yaml
services:
  traefik:
    image: traefik:latest
    networks:
      - web
      - capricorn_capricorn-network  # ← CRITICAL: Must join both networks!
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"  # API/dashboard for debugging
```

**traefik.yml:**
- DEBUG logging enabled (helpful for troubleshooting)
- HTTP-01 challenge for Let's Encrypt
- Auto HTTP→HTTPS redirect
- Docker provider with `exposedByDefault: false`

### Capricorn PROD Deployment

**Location:** `/opt/capricorn/`

**Key Features:**
- Images pulled from GitLab Container Registry
- Traefik labels for routing (both hostname and IP)
- Database initialization via mounted SQL scripts
- Persistent volumes for postgres + redis

**Routing:**
- `cap.gothamtechnologies.com` → frontend + backend (/api)
- `192.168.1.184` → frontend + backend (/api) - for internal access

### Security - Proxmox Firewall

**vm-www-1 Firewall Rules:**
- ✅ IN: SSH (22) from 192.168.1.0/24 ONLY
- ✅ IN: HTTP (80) from anywhere
- ✅ IN: HTTPS (443) from anywhere
- ✅ OUT: Allow all (for apt, docker pulls, Let's Encrypt)
- ❌ NO SSH from internet (blocked by source IP filter)

**Router Port Forwarding (Verizon G3100):**
- 80 → 192.168.1.184:80
- 443 → 192.168.1.184:443
- NO port 22 forwarding (SSH internal only)

### Troubleshooting Notes (Jan 22, 2026)

**Problem 1:** HTTPS timeout, but HTTP worked (redirected to HTTPS)

**Root Cause:** Traefik and Capricorn containers on different networks
- Traefik on `web` network (172.18.0.x)
- Capricorn on `capricorn_capricorn-network` (172.19.0.x)
- Traefik logs showed wrong IPs (172.19.0.5 instead of actual container IPs)

**Solution:**
1. Connected Traefik to capricorn network: `docker network connect capricorn_capricorn-network traefik`
2. Updated `/opt/traefik/docker-compose.yml` to include both networks permanently
3. Containers restarted successfully, traffic flowing

**Lesson:** Multi-service applications with their own networks require reverse proxy to join ALL networks!

---

**Problem 2:** Localhost access not working on vm-www-1 itself (10:00 PM)

**Root Cause:** 
- Traefik routing rules only configured for `cap.gothamtechnologies.com` and `192.168.1.184`
- No routing rule for `localhost` hostname
- `/etc/hosts` didn't have domain name entries for local resolution

**Solution:**
1. Added `/etc/hosts` entries for local domain resolution:
   ```
   127.0.0.1 cap.gothamtechnologies.com
   127.0.0.1 www.gothamtechnologies.com
   ```
2. Updated `/opt/capricorn/docker-compose.yml` with localhost routing:
   - Frontend: Added `traefik.http.routers.capricorn-localhost.rule=Host(\`localhost\`)`
   - Backend: Added `traefik.http.routers.capricorn-api-localhost.rule=Host(\`localhost\`) && PathPrefix(\`/api\`)`
3. Restarted containers: `cd /opt/capricorn && sudo docker compose up -d`

**Result:** Now accessible three ways from vm-www-1:
- ✅ https://localhost (self-signed cert, works)
- ✅ https://192.168.1.184 (self-signed cert, works)
- ✅ https://cap.gothamtechnologies.com (Let's Encrypt cert, trusted)

**Lesson:** Always configure localhost routing for services running on the same machine as the reverse proxy!

### GitLab CI/CD Integration

**Pipeline Stages:** build → push → scan → deploy_qa → deploy_prod

**New Deployment Jobs (production branch):**
- `deploy_prod_local` (manual) → vm-www-1 @ 192.168.1.184
- `deploy_prod_gcp` (manual) → Google Cloud Platform (for interviews)

**Deployment Method:**
- SSH to vm-www-1
- Pull latest images from GitLab registry
- `docker compose up -d` in `/opt/capricorn/`

### Cost Savings

- **Before:** GCP hosting ~$30-45/month (~$400/year)
- **After:** Local hosting ~$2-3/month electricity
- **Savings:** ~$400/year 💰

---

## OPENCLAW

- **VM:** vm-openclaw-1 @ 192.168.1.185 (16GB RAM, 8 cores, 50GB vm-critical)
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
- **This is the ONLY VM with Tailscale in the lab**

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
- **Service:** `~/.config/systemd/user/sshfs-openclaw.service` (enabled, lingering)
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

---

## GITHUB

- **Repo:** https://github.com/fiberoptix/home-lab-setup
- **User:** fiberoptix (SSH: ~/.ssh/id_ed25519)
- **Email:** andrew.gamache@gmail.com
- **Credentials:** See `github_credentials.md` (git-ignored)

---

## HOME-LAB-SETUP REPO (this repo) — dual-remote (Capricorn method, NO encryption)

Same model as Capricorn/capricorn-docs: SAFE content → GitHub, EVERYTHING → GitLab.
There is NO git-crypt and NO encryption — safety on GitHub comes purely from .gitignore.

- **GitHub (PUBLIC):** https://github.com/fiberoptix/home-lab-setup — remote `origin` (SSH, id_ed25519).
  Curated showcase. Secrets are .gitignore'd and NEVER reach GitHub. Push with: `git push origin main`.
- **GitLab (PRIVATE):** http://gitlab.gothamtechnologies.com/production/home-lab-setup — remote `gitlab`.
  Full plaintext mirror of the ENTIRE working tree (incl. ignored secrets/binaries).
  Auth = HTTP "wallet" baked into the remote URL in .git/config
  (`http://root:<GitLab root pw — see PASSWORDS.md>@gitlab.gothamtechnologies.com/production/home-lab-setup.git`),
  identical to how Capricorn/capricorn-docs authenticate. No SSH key needed for GitLab.
  The real password lives ONLY in .git/config (never pushed) + PASSWORDS.md (gitignored).
- **Push EVERYTHING to GitLab with `./gl-backup.sh "message"`** — it snapshots the whole working
  tree (tracked + ignored, minus .DS_Store) onto `gitlab/main` via a temp index, WITHOUT touching
  the working tree or the GitHub-bound `main`. Do NOT `git push gitlab main` directly (that only
  sends the curated tree, not the secrets). Always use gl-backup.sh for the full private mirror.
- **No auto-push-to-both.** Pushes are explicit; ALWAYS ASK "GitHub, GitLab, or both?" first.
  See the "GIT REMOTES & COMMIT ROUTING" section in CURSOR_RULES.
- **Ignored-and-therefore-GitHub-safe:** PASSWORDS.md, github_credentials.md, proxmox/credentials,
  proxmox/nas_credentials, /working/, /ddns/, *.pem, *.key, *.crt, .env*  (verify: `git check-ignore <f>`).
- **Branch:** `main` only (docs/scripts repo — no CI/CD or registry like Capricorn).

---

## CAPRICORN PROJECT

- **GitLab:** http://gitlab.gothamtechnologies.com/production/capricorn
- **GitHub:** https://github.com/fiberoptix/capricorn
- **Remotes:** Dual-remote setup (origin=GitHub, gitlab=GitLab)
- **Branches:** develop (QA auto-deploy), production (Local PROD + GCP manual deploy)
- **Production (Local):** https://cap.gothamtechnologies.com (Phase 7 - in progress)
- **Production (GCP):** http://capricorn.gothamtechnologies.com (for interviews)
- **QA (CI/CD):** http://192.168.1.180:5001 ✅ PIPELINE DEPLOYED
- **Local Path:** /home/agamache/DevShare/cursor-projects/unified_ui_DEV_PROD_GCP/capricorn

**Note:** Standard project path is now `unified_ui_DEV_PROD_GCP` (no date suffix)

---

## PASSWORD MANAGEMENT

**PASSWORDS.md** - Central credential storage (git-ignored)
- Contains ALL system passwords and credentials
- All documentation references: [See PASSWORDS.md] (NEVER write real passwords in tracked files)
- Current + deprecated passwords are recorded ONLY in PASSWORDS.md
- Also stored in: `/proxmox/credentials` and `/proxmox/nas_credentials` (git-ignored)

---

## FILES TO READ

1. `PASSWORDS.md` - All credentials
2. `SYSTEM_VERIFICATION.md` - Complete hardware inventory, drive serials, VM configs (Jan 14, 2026)
3. `/phases/current_phase.md` - Current work status
4. `/phases/phase0_hardware.md` - Hardware specs and BIOS settings
5. `/phases/phase1_proxmox.md` - ZFS configuration and best practices
   - `/phases/phase1a_proxmox_upgrade_fail_rollback.md` - Jan 12 kernel failure + rollback
   - `/phases/phase1b_proxmox_kernel_upgrade_safe_try.md` - planned reversible kernel upgrade
6. `/phases/phase5_ci_cd_pipelines.md` ✅ COMPLETE
7. `/phases/phase6_sonarqube.md` ✅ COMPLETE
8. `/phases/phase11_openclaw.md` ✅ COMPLETE
