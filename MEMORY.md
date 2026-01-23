# Home Lab Project - AI Memory

**Purpose:** Context reload for AI. No humans read this.

---

## CURRENT STATE

- Proxmox running at 192.168.1.150 (HP Z8 G4: Dual Xeon, 256GB RAM, ZFS)
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
- **Phase 7 COMPLETE:** Local WWW Server operational! (vm-www-1 @ .184)
- **PROD URLs:** https://cap.gothamtechnologies.com (Capricorn) + https://www.gothamtechnologies.com (splash)
- **Cost Savings:** ~$400/year by replacing GCP hosting
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

---

## CREDENTIALS

**File:** `/proxmox/credentials`

- Proxmox: root / [See PASSWORDS.md]
- All VMs: agamache / [See PASSWORDS.md]
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

### Current VMs (All Standardized Jan 12, 2026)
| VM | CPU | RAM | Disk | Storage | Config |
|----|-----|-----|------|---------|--------|
| **181 - GitLab** | 8 cores | 16 GB | 500 GB | vm-critical | ✅ Standard |
| **182 - Runner** | 8 cores | 8 GB | 100 GB | vm-ephemeral | ✅ Standard |
| **183 - SonarQube** | 4 cores | 8 GB | 30 GB | vm-critical | ✅ Standard |
| **200 - Kubernetes** | 8 cores | 8 GB | 100 GB | vm-ephemeral | ✅ Standard |

### RAM Allocation Strategy
- **GitLab:** 16 GB (memory-hungry, keep high)
- **SonarQube:** 6-8 GB (official minimum 6 GB, 8 GB for large projects)
- **Runner:** 8 GB (ephemeral workloads, sufficient for builds)
- **Kubernetes/QA:** 8 GB (adjust based on container count)
- **Total Allocated:** 40 GB of 126 GB available (32%)

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

**Current Status:** January 12, 2026 (9:22 PM EST)

### Active Kernel
- **Running:** 6.17.2-1-pve ✅ STABLE
- **Pinned:** 6.17.2-1-pve (via `proxmox-boot-tool kernel pin`)
- **Held packages:** proxmox-kernel-6.17.2-1-pve-signed, proxmox-default-kernel

### ⚠️ KNOWN ISSUE: Kernel 6.17.4-2-pve
**Problem:** NVMe timeout errors on all disks during boot (HP Z8 G4 hardware incompatibility)

**What Happened (Jan 12, 2026):**
1. Ran Proxmox updates via new `update` script
2. Kernel upgraded from 6.17.2-1 → 6.17.4-2
3. Reboot failed with NVMe timeouts on all 4x 1TB NVMe drives
4. System hung at boot showing: `cpu_startup_entry`, `start_secondary`, `common_startup_64`

**Resolution:**
1. Hard reset server
2. Booted into old kernel (6.17.2-1-pve) via GRUB Advanced Options
3. Pinned old kernel: `proxmox-boot-tool kernel pin 6.17.2-1-pve`
4. Held kernel packages: `apt-mark hold proxmox-kernel-6.17.2-1-pve-signed proxmox-default-kernel`
5. Removed bad kernel: `dpkg --force-depends --purge proxmox-kernel-6.17.4-2-pve-signed`

**Current Protection:**
```bash
# Pinned kernel (always boots this one):
proxmox-boot-tool kernel list
# Shows: Pinned kernel: 6.17.2-1-pve

# Held packages (won't auto-upgrade):
apt-mark showhold
# proxmox-default-kernel
# proxmox-kernel-6.17.2-1-pve-signed
```

**Update Script Modified:**
- `/usr/local/bin/proxmox-update.sh` created with alias `update`
- Automatically disables subscription nag after each update
- Checks for reboot required
- Safe to run: kernel won't upgrade due to holds

**DO NOT UNHOLD KERNEL PACKAGES** until Proxmox releases 6.17.5+ with NVMe fixes!

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
| 3 | GitLab Server | ✅ VERIFIED |
| 4 | GitLab Runner | ✅ VERIFIED |
| 5 | CI/CD Pipelines | ✅ COMPLETE (QA + GCP both working!) |
| 6 | SonarQube | ✅ COMPLETE (test-app + Capricorn both integrated!) |
| 7 | Local WWW Server | ✅ COMPLETE (vm-www-1 @ .184, cap + www live!) |
| 8 | Monitoring Stack | 🔲 NEXT |

**Phase docs:** `/phases/`

---

## SONARQUBE

- **URL:** http://192.168.1.183:9000
- **Version:** 26.1.0 (community, latest)
- **Login:** admin / [See PASSWORDS.md]
- **Container:** `sonarqube:community` (Docker)
- **Data:** `/opt/sonarqube/data` (persisted)

**Projects:**
- test-app (token: sqp_1f2e5062c88890cd98477759b593428ac494576d)
  - Quality Gate: PASSED ✅
  - 86 lines of code (HTML, Docker)
  - 0 security issues, 0 bugs, 1 maintainability issue
- capricorn (token: sqp_fcfecef2186a725979f59666e04bb1f451eded3b)
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

**Problem:** HTTPS timeout, but HTTP worked (redirected to HTTPS)

**Root Cause:** Traefik and Capricorn containers on different networks
- Traefik on `web` network (172.18.0.x)
- Capricorn on `capricorn_capricorn-network` (172.19.0.x)
- Traefik logs showed wrong IPs (172.19.0.5 instead of actual container IPs)

**Solution:**
1. Connected Traefik to capricorn network: `docker network connect capricorn_capricorn-network traefik`
2. Updated `/opt/traefik/docker-compose.yml` to include both networks permanently
3. Containers restarted successfully, traffic flowing

**Lesson:** Multi-service applications with their own networks require reverse proxy to join ALL networks!

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

## GITHUB

- **Repo:** https://github.com/fiberoptix/home-lab-setup
- **User:** fiberoptix (SSH: ~/.ssh/id_ed25519)
- **Email:** andrew.gamache@gmail.com
- **Credentials:** See `github_credentials.md` (git-ignored)

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
- All documentation now references: [See PASSWORDS.md]
- Old password: capricorn2025 (deprecated, documented in PASSWORDS.md)
- Current password: Powerme!1 (SSH verified Jan 13, 2026)
- Also stored in: `/proxmox/credentials` and `/proxmox/nas_credentials` (git-ignored)

---

## FILES TO READ

1. `PASSWORDS.md` - All credentials
2. `SYSTEM_VERIFICATION.md` - Complete hardware inventory, drive serials, VM configs (Jan 14, 2026)
3. `/phases/current_phase.md` - Current work status
4. `/phases/phase0_hardware.md` - Hardware specs and BIOS settings
5. `/phases/phase1_proxmox.md` - ZFS configuration and best practices
6. `/phases/phase5_ci_cd_pipelines.md` ✅ COMPLETE
7. `/phases/phase6_sonarqube.md` ✅ COMPLETE
