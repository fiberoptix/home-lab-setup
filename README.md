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

**Total Cost:** ~$300 (UPS only) + ~$15-20/month electricity  
**Commercial Equivalent:** ~$70-100/month SaaS services

---

## 🖥️ Hardware Specifications

**Platform:** HP Z6 G4 Workstation

| Component | Specification |
|-----------|---------------|
| **CPU** | Intel Xeon Platinum 8168 (24 cores / 48 threads @ 2.7GHz) |
| **RAM** | 128GB DDR4 ECC (4x 32GB) |
| **Boot Storage** | 2x 500GB NVMe (ZFS mirror) |
| **VM Storage** | 4x 1TB NVMe (HP Z Turbo Drive Quad Pro) |
| **Network** | 2x 1GbE onboard NICs |
| **Total Storage** | 3.5TB usable ZFS pools |

**Storage Architecture (ZFS):**
- `local-zfs` (rpool): 2x500GB mirror - Proxmox OS, ISOs
- `vm-critical`: 2x1TB mirror - GitLab, SonarQube, Monitoring (data protection)
- `vm-ephemeral`: 2x1TB stripe - Runner, QA Host (disposable workloads)

---

## 🏗️ Infrastructure Architecture

**6 Virtual Machines:**

| VM | Purpose | RAM | Disk | Storage Pool | IP |
|----|---------|-----|------|--------------|-----|
| **Traefik** | Public HTTPS reverse proxy | 1GB | 5GB | local-zfs | .51 |
| **GitLab** | Git + CI/CD + Registries | 12GB | 200GB | vm-critical | .52 |
| **Runner** | CI/CD job execution | 8GB | 100GB | vm-ephemeral | .53 |
| **SonarQube** | Code quality & security | 6GB | 20GB | vm-critical | .54 |
| **Monitoring** | Prometheus + Grafana | 6GB | 30GB | vm-critical | .55 |
| **QA Host** | Deployed applications | 16GB | 100GB | vm-ephemeral | .56 |

**Dual-Access Strategy:**
- 🔒 **Tailscale VPN** - Admin access to ALL services (GitLab, SonarQube, Grafana)
- 🌐 **Public HTTPS** - QA application testing only (infrastructure stays private)

---

## 📊 Project Status

**Current Phase:** 5 - CI/CD Pipeline Testing

| Phase | Description | Status |
|-------|-------------|--------|
| 0 | Hardware Installation | ✅ Complete |
| 1 | Proxmox VE Installation | ✅ Complete |
| 2 | ZFS Storage Configuration | ✅ Complete |
| 3 | Host Setup Automation | ✅ Complete |
| 4 | GitLab Server Setup | ✅ Complete |
| 5 | GitLab Runner Setup | ✅ Complete |
| 6 | CI/CD Pipeline Testing | 🔄 In Progress |
| 7 | SonarQube Integration | ⏳ Planned |
| 8 | Monitoring Stack | ⏳ Planned |
| 9 | Traefik + SSL | ⏳ Planned |
| 10 | Backup Configuration | ⏳ Planned |

**Infrastructure Status:**
- ✅ Proxmox VE 9.1 running at 192.168.1.150
- ✅ GitLab CE at 192.168.1.181
- ✅ GitLab Runner at 192.168.1.182 (Docker executor)
- ✅ QA Host at 192.168.1.180 (vm-kubernetes-1)
- ✅ Script server at http://192.168.1.195/scripts/

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
│   └── phase4_gitlab_runner.md  # Runner setup & troubleshooting
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
Password: [see credentials file]

# SSH
ssh root@192.168.1.150
```

### Access GitLab
```bash
# Web UI
http://192.168.1.181
Username: root
Password: [See PASSWORDS.md]

# Container Registry
http://gitlab.gothamtechnologies.com:5050
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
- Production: capricorn.gothamtechnologies.com (GCP)
- QA: capricorn-qa.gothamtechnologies.com (home lab)

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

**Last Updated:** January 8, 2026  
**Proxmox Version:** VE 9.1  
**Build Status:** Phase 5 - CI/CD Pipeline Testing

---

*Built with ❤️ on Proxmox VE*

