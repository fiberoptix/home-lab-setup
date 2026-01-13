# Home Lab Project - AI Memory

**Purpose:** Context reload for AI. No humans read this.

---

## CURRENT STATE

- Proxmox running at 192.168.1.150 (HP Z8 G4: Dual Xeon, 256GB RAM, ZFS)
- Script server running at http://192.168.1.195/scripts/
- **GitLab CE LIVE at http://192.168.1.181** (root/<See PASSWORDS.md>)
- **GitLab Runner LIVE at 192.168.1.182** (gitlab-runner-1, v18.7.2)
- **Container Registry OPERATIONAL** on port 5050
- **CI/CD Pipeline PRODUCTION-READY** - Full automation working!
- **Test app deployed:** http://192.168.1.180:8080 (via pipeline)
- **Capricorn QA:** http://192.168.1.180:5001 (auto-deploy on develop push)
- **Capricorn GCP:** http://capricorn.gothamtechnologies.com (manual deploy on production)
- **GitHub repos:** home-lab-setup + Capricorn (both updated)
- **SonarQube LIVE at http://192.168.1.183:9000** (v26.1.0, admin/<See PASSWORDS.md>)
- **Phase 6 COMPLETE:** Both test-app and Capricorn integrated with SonarQube!
- Next: Phase 7 (Monitoring Stack) or Phase 8 (Traefik+SSL)

---

## IPs & HOSTS

| Host | IP | Status |
|------|-----|--------|
| Proxmox | .150 | ✅ Running |
| QA/K8s | .180 | ✅ Built (vm-kubernetes-1) |
| GitLab | .181 | ✅ LIVE |
| **Runner** | **.182** | **✅ LIVE (gitlab-runner-1)** |
| **SonarQube** | **.183** | **✅ LIVE (vm-sonarqube-1, v26.1.0)** |

---

## CREDENTIALS

**File:** `/proxmox/credentials`

- Proxmox: root / <See PASSWORDS.md>
- All VMs: agamache / <See PASSWORDS.md>
- **GitLab Web: root / <See PASSWORDS.md>**
- **SonarQube Web: admin / <See PASSWORDS.md>**
- NAS (SMB): fiberoptix / <See PASSWORDS.md> @ 192.168.1.120

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
bash host_setup.sh
```

---

## VM CONFIGURATION STANDARD

**Last Updated:** January 12, 2026 (9:22 PM EST)  
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
- **vm-critical (rpool2, mirror):** GitLab, SonarQube, Monitoring (data persistence)
- **vm-ephemeral (rpool3, stripe):** Runner, QA Host (disposable/rebuildable)

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

| Pool | Name | Type | Use |
|------|------|------|-----|
| local-zfs | rpool1 | mirror | Proxmox, ISOs (2x500GB) |
| vm-critical | rpool2 | mirror | GitLab, SonarQube (2x1TB) |
| vm-ephemeral | rpool3 | stripe | Runner, QA (2x1TB) |

---

## PHASES

| # | Name | Status |
|---|------|--------|
| 0-2 | Hardware/Proxmox/Automation | ✅ |
| 3 | GitLab Server | ✅ VERIFIED |
| 4 | GitLab Runner | ✅ VERIFIED |
| 5 | CI/CD Pipelines | ✅ COMPLETE (QA + GCP both working!) |
| 6 | SonarQube | ✅ COMPLETE (test-app + Capricorn both integrated!) |
| 7 | Monitoring Stack | 🔲 |
| 8 | Traefik + SSL | 🔲 |

**Phase docs:** `/phases/`

---

## SONARQUBE

- **URL:** http://192.168.1.183:9000
- **Version:** 26.1.0 (community, latest)
- **Login:** admin / <See PASSWORDS.md>
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
- **Branches:** develop (QA auto-deploy), production (GCP manual deploy)
- **Production (GCP):** http://capricorn.gothamtechnologies.com
- **QA (CI/CD):** http://192.168.1.180:5001 ✅ PIPELINE DEPLOYED
- **Local Path:** /home/agamache/DevShare/cursor-projects/unified_ui_DEV_PROD_GCP_2026.1.12/capricorn

---

## FILES TO READ

1. `/proxmox/credentials`
2. `/phases/current_phase.md`
3. `/phases/phase5_ci_cd_pipelines.md`
4. `/phases/phase6_sonarqube.md` ✅ COMPLETE
