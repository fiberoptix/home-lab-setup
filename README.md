# 🏠 Home Lab Setup - Proxmox DevOps Environment

**Building a complete FREE DevOps/QA home lab on Proxmox VE 9.1**

[![Status](https://img.shields.io/badge/Status-In_Progress-yellow)]()
[![Proxmox](https://img.shields.io/badge/Proxmox-VE_9.1-orange)]()
[![Hardware](https://img.shields.io/badge/Hardware-HP_Z6_G4-blue)]()

---

## 📋 Project Overview

This repository documents the complete build of a **professional-grade DevOps home lab** running on Proxmox VE 9.1, providing enterprise capabilities at zero software cost:

- 🔧 **Source Control:** GitLab CE with Container & Package Registries
- 🚀 **CI/CD Pipelines:** Automated build, test, quality gates, and deployment
- 🔍 **Code Quality:** SonarQube for security & quality scanning
- 📊 **Monitoring:** Prometheus + Grafana observability stack
- 🌐 **Dual Access:** Tailscale VPN (admin) + Public HTTPS (QA testing)
- 🔐 **Security:** Zero-trust VPN, Let's Encrypt SSL, infrastructure isolation

This system was designed out of interest to build and deploy the **Capricorn** project (a unified personal finance application hosted in the same GitLab repository) to multiple environments: **QA** (local Kubernetes/Docker on this home lab) and **PROD** (local production server). The infrastructure provides a complete DevOps pipeline for automated testing, quality gates, and deployment orchestration.

**Please check out the Capricorn project:**
- 📦 **GitLab Repository:** http://gitlab.gothamtechnologies.com/capricorn
- 🌐 **Live Demo (PROD-Local):** https://cap.gothamtechnologies.com ← **Check it out!**
- ☁️ **GCP Instance:** https://capricorn.gothamtechnologies.com (available on-demand for public demos)

**Total Hardware Cost:** $3,894  
**Monthly Operating Cost:** ~$15-20 (electricity)  
**Commercial Equivalent:** ~$70-100/month SaaS services

---

## 🖥️ Hardware Specifications

**Platform:** HP Z8 G4 Workstation

| Component | Specification |
|-----------|---------------|
| **CPU** | Dual Intel Xeon Platinum 8168 (48 cores / 96 threads @ 2.7GHz) |
| **RAM** | 256GB DDR4 ECC (8x 32GB) |
| **Boot Storage** | 2x 500GB NVMe (ZFS mirror) |
| **VM Storage** | 4x 1TB NVMe (HP Z Turbo Drive Quad Pro) |
| **Network** | 2x 1GbE onboard NICs |
| **Total Storage** | 3.5TB usable ZFS pools |

**Storage Architecture (ZFS):**
- `local-zfs` (rpool1): 2x500GB mirror - Proxmox OS, ISOs
- `vm-critical` (rpool2): 2x1TB mirror - GitLab, SonarQube, Monitoring (data protection)
- `vm-ephemeral` (rpool3): 2x1TB stripe - Runner, QA Host (disposable workloads)

---

## 🏗️ Infrastructure Architecture

**4 Virtual Machines (Currently Active):**

| VM | Purpose | RAM | Disk | Storage Pool | IP |
|----|---------|-----|------|--------------|-----|
| **GitLab** | Git + CI/CD + Registries | 16GB | 500GB | vm-critical | .181 |
| **Runner** | CI/CD job execution | 8GB | 100GB | vm-ephemeral | .182 |
| **SonarQube** | Code quality & security | 8GB | 30GB | vm-critical | .183 |
| **QA Host** | Deployed applications | 8GB | 100GB | vm-ephemeral | .180 |

**Planned VMs:**
| **Traefik** | Public HTTPS reverse proxy | 2GB | 10GB | local-zfs | TBD |
| **Monitoring** | Prometheus + Grafana | 6GB | 30GB | vm-critical | TBD |

**VM Configuration Standard:**
- CPU: `host` type (native performance)
- NUMA: Disabled (single-socket optimization)
- Disk: `iothread=1,discard=on,cache=none,aio=native` (optimized for ZFS + NVMe)
- Network: `firewall=1` (all VMs protected)
- Boot: `onboot=1` (auto-start on Proxmox boot)

**Resource Utilization:**
- Total RAM Allocated: 40 GB of 126 GB (32% - room for 11 more 8GB VMs)
- Total CPU Cores: 28 of 48 vCPUs (58% - plenty of headroom)

**Dual-Access Strategy:**
- 🔒 **Tailscale VPN** - Admin access to ALL services (GitLab, SonarQube, Grafana)
- 🌐 **Public HTTPS** - QA application testing only (infrastructure stays private)

---

## 📊 Project Status

**Current Phase:** 7 - ✅ **COMPLETE** (Local WWW/Production Server with Traefik + SSL!)

| Phase | Description | Status |
|-------|-------------|--------|
| 0 | Hardware Installation | ✅ Complete |
| 1 | Proxmox VE Installation | ✅ Complete |
| 2 | ZFS Storage Configuration | ✅ Complete |
| 3 | Host Setup Automation | ✅ Complete |
| 4 | GitLab Server Setup | ✅ Complete |
| 5 | GitLab Runner Setup | ✅ Complete |
| 6 | CI/CD Pipelines | ✅ Complete |
| 7 | **SonarQube Integration** | ✅ **Complete** |
| 8 | Monitoring Stack | ⏳ Next |
| 9 | **Traefik + SSL** | ✅ **Complete** |
| 10 | Backup Configuration | ⏳ Planned |

**Infrastructure Status:**
- ✅ Proxmox VE 9.1 at 192.168.1.150 (kernel 6.17.2-1-pve pinned)
- ✅ GitLab CE at 192.168.1.181 (source control + CI/CD, 16GB RAM, auto-start)
- ✅ GitLab Runner at 192.168.1.182 (Docker executor v18.7.2, 8GB RAM, auto-start)
- ✅ SonarQube at 192.168.1.183:9000 (v26.1.0, 8GB RAM, auto-start)
- ✅ QA Host at 192.168.1.180 (vm-kubernetes-1, 8GB RAM, auto-start)
- ✅ Container Registry at gitlab.gothamtechnologies.com:5050 (operational)
- ✅ Script server at http://192.168.1.195/scripts/ (host setup automation)

**Applications Deployed via CI/CD:**
- ✅ Test App: http://192.168.1.180:8080 (validation + quality scan)
- ✅ Capricorn: http://192.168.1.180:5001 (QA automated + quality scan)
- ✅ Capricorn: https://cap.gothamtechnologies.com (PROD-Local, primary)
- ☁️ Capricorn: https://capricorn.gothamtechnologies.com (GCP instance, on-demand)

**Code Quality Scanning:**
- ✅ test-app: 86 LOC, Quality Gate PASSED (0 bugs, 0 security issues)
- ✅ Capricorn: 28k LOC, Quality Gate PASSED (639 issues identified for improvement)

---

## 📁 Repository Structure

```
home-lab-setup/
├── README.md                    # This file
├── CURSOR_RULES                 # AI agent startup instructions
├── MEMORY.md                    # Current infrastructure state
├── MAKE_MEMORIES                # Memory creation rules
│
├── phases/                      # Detailed phase documentation
│   ├── current_phase.md         # Active phase tracker
│   ├── phase0_hardware.md       # Hardware installation notes
│   ├── phase1_proxmox.md        # Proxmox setup
│   ├── phase2_host_setup_automation.md
│   ├── phase3_gitlab_server.md  # GitLab installation & config
│   ├── phase4_gitlab_runner.md  # Runner setup & troubleshooting
│   ├── phase5_ci_cd_pipelines.md # CI/CD implementation
│   └── phase6_sonarqube.md      # Code quality integration
│
├── proxmox/                     # Proxmox documentation
│   ├── Home_Lab_Proxmox_Build_Plan.md    # Master build checklist
│   ├── Home_Lab_Proxmox_Design.md        # Architecture overview
│   ├── Home_Lab_Proxmox_Storage.md       # ZFS configuration
│   ├── Home_Lab_Proxmox_Install.md       # Installation notes
│   ├── credentials              # (git-ignored)
│   └── nas_credentials          # (git-ignored)
│
├── vmware/                      # VMware ESXi reference (replaced by Proxmox)
│   └── *.md                     # Design docs for comparison
│
└── www/                         # Host setup automation
    ├── run_www.sh               # Script server launcher
    ├── docker-compose.yml       # nginx file server
    ├── nginx.conf               # Web server config
    └── scripts/                 # Automated host setup scripts
        ├── host_setup.sh        # Master setup orchestrator
        ├── setup_docker.sh      # Docker + insecure registry config
        ├── setup_ssh.sh         # SSH key deployment
        ├── setup_sudo.sh        # Passwordless sudo
        ├── setup_smb_mount.sh   # NAS mount configuration
        └── setup_desktop.sh     # Desktop environment
```

---

## 🚀 Quick Start

### Access Proxmox
```bash
# Web UI
https://192.168.1.150:8006
Username: root

# SSH
ssh root@192.168.1.150
```

### Access GitLab
```bash
# Web UI
http://192.168.1.181
Username: root

# Container Registry
http://gitlab.gothamtechnologies.com:5050
```

### Access SonarQube
```bash
# Web UI
http://192.168.1.183:9000
Username: admin

# Integrated with CI/CD pipelines for automated code scanning
```

### Setup New Host
```bash
# Download and run setup script
wget http://192.168.1.195/scripts/host_setup.sh
bash host_setup.sh

# Includes: Docker, SSH keys, sudo config, SMB mount
```

---

## 📚 Key Documentation Files

**Start Here:**
1. [`MEMORY.md`](MEMORY.md) - Current infrastructure state, IPs, credentials reference
2. [`/proxmox/Home_Lab_Proxmox_Build_Plan.md`](proxmox/Home_Lab_Proxmox_Build_Plan.md) - Complete build checklist
3. [`/proxmox/Home_Lab_Proxmox_Design.md`](proxmox/Home_Lab_Proxmox_Design.md) - Architecture overview

**Phase Documentation:**
- Each phase has detailed implementation notes in `/phases/`
- Includes: objectives, commands used, issues encountered, solutions

---

## 🛠️ Technology Stack (All FREE)

**Infrastructure:**
- Proxmox VE 9.1 (hypervisor)
- Ubuntu Server 24.04 LTS (guest OS)
- ZFS (software RAID)

**DevOps Tools:**
- GitLab Community Edition (source control, CI/CD, registries)
- GitLab Runner (Docker executor)
- SonarQube Community Edition (code quality)
- Traefik v2.10 (reverse proxy)
- Let's Encrypt (SSL certificates)

**Monitoring:**
- Prometheus (metrics)
- Grafana (dashboards)
- Node Exporter (system metrics)

**Access:**
- Tailscale (zero-trust VPN)
- AWS Route53 (DNS for public QA)

---

## 🎯 Use Cases

This lab supports:
- ✅ Automated CI/CD pipelines (build → test → scan → deploy)
- ✅ Container/package hosting (Docker Registry, npm, pip, maven)
- ✅ Code quality gates (SonarQube integration)
- ✅ Infrastructure monitoring (full observability)
- ✅ Public QA testing (HTTPS with valid SSL)
- ✅ Private admin access (Tailscale VPN from anywhere)

**Target Application:** Capricorn (unified personal finance application)
- Production (Primary): https://cap.gothamtechnologies.com (home lab)
- Production (Instance): https://capricorn.gothamtechnologies.com (GCP, on-demand)
- QA: http://192.168.1.180:5001 (home lab)

---

## 🔐 Security

**Principle: Security by Design**
- Infrastructure services NOT exposed publicly (GitLab, SonarQube, Grafana)
- Admin access via Tailscale zero-trust VPN only
- Public HTTPS limited to QA applications via Traefik
- UFW firewall on all VMs
- SSH key authentication (password auth disabled)
- Let's Encrypt SSL with DNS-01 challenge (Route53)

---

## ⚙️ Infrastructure Optimizations

**VM Performance Tuning (January 12, 2026):**
- ✅ Standardized all VMs with optimized disk configuration
- ✅ Enabled native AIO for lower CPU overhead
- ✅ Enabled discard (TRIM) for ZFS space reclamation
- ✅ Configured firewall on all VMs
- ✅ Enabled auto-start on boot (onboot=1)
- ✅ Adjusted RAM allocation based on actual usage patterns

**Proxmox Kernel Management:**
- ⚠️ **Kernel 6.17.4-2-pve incompatible** with HP Z8 G4 NVMe hardware (boot failure)
- ✅ **Running stable kernel:** 6.17.2-1-pve (pinned via `proxmox-boot-tool`)
- ✅ **Kernel packages held** to prevent automatic upgrades
- ✅ **Update script created:** `/usr/local/bin/proxmox-update.sh` (alias: `update`)
  - Automatically updates Proxmox + Debian packages
  - Disables subscription nag after updates
  - Checks for reboot requirements
  - Kernel won't upgrade due to package holds

**Reboot Tested:** All VMs auto-start successfully, all services operational within 2-3 minutes

---

## 📝 Notes

**Why Proxmox over ESXi?**
- ✅ Native ZFS support (no VROC driver issues)
- ✅ Full Linux CLI access
- ✅ LXC containers for lightweight services
- ✅ Built-in backup tools (vzdump)
- ✅ Free clustering support
- ✅ No UEFI boot issues

**GitLab Runner Notes:**
- Docker-in-Docker (DIND) doesn't work reliably
- Use socket mount instead: `/var/run/docker.sock:/var/run/docker.sock`
- Container registry requires insecure-registry config (HTTP on port 5050)

---

## 📖 License

This is a personal home lab project. Documentation and scripts are provided as-is for reference purposes.

---

## 🤝 Contributing

This is a personal project, but feel free to use the documentation as reference for your own home lab!

---

**Last Updated:** January 12, 2026 (9:30 PM EST)  
**Proxmox Version:** VE 9.1 (Kernel: 6.17.2-1-pve - pinned)  
**Build Status:** Phase 6 Complete | Infrastructure Optimized & Production-Ready

---

*Built with ❤️ on Proxmox VE*

