# Home Lab DevOps Environment Design - Proxmox Edition

**Created:** December 12, 2025  
**Updated:** December 12, 2025  
**Target Platform:** Proxmox VE 9.1 on HP Z6 G4  
**Philosophy:** Maximum capability, minimum cost (all free/open source)  
**Access Strategy:** Dual-access (Tailscale VPN for admin + Public HTTPS for QA testing)

---

## Executive Summary

This document outlines a complete **FREE DevOps/QA home lab infrastructure** providing enterprise-grade capabilities:
- Source control with container/package registries (GitLab CE)
- Automated CI/CD pipelines with quality gates
- Code quality & security scanning (SonarQube)
- Monitoring & observability (Prometheus + Grafana)
- Dual-access strategy:
  - **Tailscale VPN** for private admin access to all services
  - **Public HTTPS** (capricorn-qa.gothamtechnologies.com) for QA testing

**Total Software Cost:** $0  
**Monthly Operating Cost:** ~$15-20 (electricity)  
**Commercial Equivalent Value:** ~$70-100/month  
**Actual Hardware:** **192GB RAM** (6x 32GB, all 6 channels — upgraded from 128GB Aug 26, 2026), 24 CPU cores (48 threads), 3.5TB ZFS storage

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                    INTERNET                                       │
│                       │                                           │
│         ┌─────────────┴─────────────┐                            │
│         │                           │                            │
│         ▼                           ▼                            │
│  Tailscale VPN              Router (Port 443)                    │
│  (Admin Access)             (Public QA Access)                   │
└──────────────────────────────────────────────────────────────────┘
         │                           │
         └─────────────┬─────────────┘
                       ▼
┌──────────────────────────────────────────────────────────────────┐
│              Proxmox VE Host (HP Z6 G4)                          │
│              192.168.1.150                                        │
│              192GB RAM, 24 CPU Cores (48 threads)                │
│              3x ZFS Pools (3.5TB usable)                         │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ VM1: Traefik Reverse Proxy                                 │ │
│  │ • 1GB RAM, 5GB disk on local-zfs                          │ │
│  │ • Port 80/443 (public HTTPS only)                          │ │
│  │ • Let's Encrypt SSL (Route53 DNS-01)                       │ │
│  │ • Routes to QA apps only:                                  │ │
│  │   - capricorn-qa.gothamtechnologies.com → QA:5001         │ │
│  │   - (Infrastructure NOT exposed publicly)                  │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ VM2: GitLab Community Edition                              │ │
│  │ • 12GB RAM, 200GB disk on vm-critical (ZFS mirror)        │ │
│  │ • Git repositories                                         │ │
│  │ • Container Registry (Docker images)                      │ │
│  │ • Package Registry (npm, pip, maven)                      │ │
│  │ • CI/CD pipelines                                         │ │
│  │ • Tailscale: http://gitlab (admin VPN access)             │ │
│  │ • NOT exposed publicly (private infrastructure)            │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ VM3: GitLab Runner                                         │ │
│  │ • 8GB RAM, 100GB disk on vm-ephemeral (ZFS stripe)        │ │
│  │ • Executes CI/CD jobs with Docker executor                │ │
│  │ • Builds containers, runs tests                           │ │
│  │ • Deploys to QA host                                       │ │
│  │ • Internal only (not exposed)                              │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ VM4: SonarQube Community Edition                           │ │
│  │ • 6GB RAM, 20GB disk on vm-critical (ZFS mirror)          │ │
│  │ • Code quality analysis                                    │ │
│  │ • Security vulnerability scanning                         │ │
│  │ • Tailscale: http://sonarqube:9000 (admin VPN access)     │ │
│  │ • NOT exposed publicly                                     │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ VM5: Monitoring Stack                                      │ │
│  │ • 6GB RAM, 30GB disk on vm-critical (ZFS mirror)          │ │
│  │ • Prometheus (metrics collection)                         │ │
│  │ • Grafana (dashboards)                                     │ │
│  │ • Tailscale: http://monitoring:3000 (admin VPN access)    │ │
│  │ • NOT exposed publicly                                     │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ VM6: QA Host (Ubuntu + Docker)                             │ │
│  │ • 16GB RAM, 100GB disk on vm-ephemeral (ZFS stripe)       │ │
│  │ • Docker + Docker Compose                                  │ │
│  │ • Deployed applications:                                   │ │
│  │   - Capricorn (port 5001)                                 │ │
│  │ • Access methods:                                          │ │
│  │   - Local: http://192.168.1.56:5001                       │ │
│  │   - Tailscale VPN: http://qa-host:5001 (admin)           │ │
│  │   - Public: https://capricorn-qa.gothamtechnologies.com   │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘

TOTAL RESOURCES:
• VMs: 6 (Traefik, GitLab, Runner, SonarQube, Monitoring, QA)
• RAM: 104GB allocated (192GB available - 87GB headroom)  [live Aug 26, 2026]
• CPU: 21 cores allocated (48 threads available)
• Storage: 3.5TB usable (3x ZFS pools)
• Cost: $0 (all open source software)
```

---

## Hardware Configuration

### HP Z6 G4 Workstation

| Component | Specification |
|-----------|---------------|
| **CPU** | Intel Xeon Platinum 8168 (24 cores / 48 threads) |
| **RAM** | **192GB** DDR4 ECC (6x 32GB, all 6 channels — upgraded Aug 26, 2026) |
| **Boot Storage** | 2x 500GB NVMe (motherboard M.2 slots) |
| **VM Storage** | 4x 1TB NVMe (HP Z Turbo Drive Quad Pro) |
| **Network** | 2x 1GbE onboard NICs |
| **PCIe** | HP Z Turbo Drive Quad Pro (passive bifurcation x4x4x4x4) |

### Storage Architecture (ZFS)

| Pool | Drives | RAID | Usable | Purpose |
|------|--------|------|--------|---------|
| `local-zfs` (rpool) | 2x 500GB (motherboard) | mirror | ~465GB | Proxmox OS, ISOs, small VMs |
| `vm-critical` | 2x 1TB (HP Turbo slots 1&2) | mirror | ~1TB | GitLab, SonarQube, Monitoring |
| `vm-ephemeral` | 2x 1TB (HP Turbo slots 3&4) | stripe | ~2TB | Runner, QA Host |
| **TOTAL** | **6 drives** | | **~3.5TB** | |

**Note:** ZFS stripe (RAID0) has NO redundancy. Data on vm-ephemeral is disposable/rebuildable.

---

## VM Resource Allocation

| VM | Purpose | RAM | Disk | Storage Pool | CPU | IP Address |
|----|---------|-----|------|--------------|-----|------------|
| VM1 | Traefik | 1GB | 5GB | local-zfs | 1 | 192.168.1.51 |
| VM2 | GitLab | 12GB | 200GB | vm-critical | 4 | 192.168.1.52 |
| VM3 | Runner | 8GB | 100GB | vm-ephemeral | 4 | 192.168.1.53 |
| VM4 | SonarQube | 6GB | 20GB | vm-critical | 2 | 192.168.1.54 |
| VM5 | Monitoring | 6GB | 30GB | vm-critical | 2 | 192.168.1.55 |
| VM6 | QA Host | 16GB | 100GB | vm-ephemeral | 8 | 192.168.1.56 |
| **TOTAL** | **6 VMs** | **49GB** | **455GB** | | **21** | |
| **Available** | | **79GB free** | **3TB free** | | **27 free** | |

---

## Network Architecture

### IP Address Allocation

| Service | IP Address | Tailscale | Public Access |
|---------|------------|-----------|---------------|
| Proxmox Host | 192.168.1.150 | No | No (local only) |
| Traefik | 192.168.1.51 | No | Yes (port 443) |
| GitLab | 192.168.1.52 | Yes | No (VPN only) |
| Runner | 192.168.1.53 | No | No (internal) |
| SonarQube | 192.168.1.54 | Yes | No (VPN only) |
| Monitoring | 192.168.1.55 | Yes | No (VPN only) |
| QA Host | 192.168.1.56 | Yes | Yes (via Traefik) |

**Reserved:** 192.168.1.57-59 for future VMs

### Route53 DNS (Public QA Only)

| DNS Record | Type | Value |
|------------|------|-------|
| `capricorn-qa.gothamtechnologies.com` | A | Your Public IP |

---

## Dual-Access Strategy

### 1. Tailscale VPN - Admin Access (You)

**Purpose:** Private, secure access to ALL infrastructure from anywhere

```
Your Laptop → Tailscale VPN → Home Lab
  ├─ http://gitlab (GitLab via MagicDNS)
  ├─ http://sonarqube:9000 (Code quality)
  ├─ http://monitoring:3000 (Grafana dashboards)
  ├─ http://qa-host:5001 (Capricorn direct access)
  └─ ssh admin@gitlab (SSH to any VM)
```

### 2. Public HTTPS - QA Testing (Friends)

**Purpose:** Easy access for external testers (no VPN required)

```
Friend's Browser → Internet → Router (Port 443) → Traefik VM
  └─ Traefik routes capricorn-qa.gothamtechnologies.com → QA Host:5001
  └─ ONLY QA apps exposed (NOT GitLab, SonarQube, Grafana)
```

### Security Model

```
Publicly Exposed (via Traefik):
✅ Capricorn QA app ONLY (port 5001)
✅ HTTPS with valid SSL
✅ Rate limiting enabled

Private (Tailscale VPN only):
🔒 GitLab (source code, container registry)
🔒 SonarQube (code quality reports)
🔒 Grafana (monitoring dashboards)
🔒 Proxmox (hypervisor management)
🔒 GitLab Runner (CI/CD executor)
```

---

## Software Stack (All FREE)

### Core Infrastructure
- **Proxmox VE 9.1** - Free hypervisor with ZFS support
- **Ubuntu Server 24.04 LTS** - Guest OS for all VMs
- **ZFS** - Native Linux software RAID

### DevOps Tools
- **GitLab Community Edition** - Source control, CI/CD, container/package registries
- **GitLab Runner** - CI/CD job executor (Docker)
- **SonarQube Community Edition** - Code quality & security scanning
- **Traefik v2.10** - Reverse proxy for public QA access
- **Let's Encrypt** - Free SSL certificates (DNS-01 via Route53)

### Access & Security
- **Tailscale** - Zero-trust VPN for admin access
- **AWS Route53** - DNS for public QA domain
- **UFW** - Firewall on all VMs

### Monitoring & Observability
- **Prometheus** - Metrics collection
- **Grafana** - Dashboards & visualization
- **Node Exporter** - System metrics

### Runtime
- **Docker** - Container runtime (on all VMs)
- **Docker Compose** - Multi-container orchestration

---

## Key Differences: Proxmox vs ESXi

| Feature | VMware ESXi | Proxmox VE |
|---------|-------------|------------|
| **Cost** | Free (limited) | Free (full features) |
| **Storage** | VMFS, vSAN | ZFS, LVM, Ceph |
| **RAID** | Hardware or VROC | ZFS software RAID |
| **Web UI** | vSphere Client | Proxmox Web UI |
| **CLI** | esxcli | Standard Linux |
| **Containers** | No | LXC support |
| **Backup** | Manual/ghettoVCB | Built-in vzdump |
| **Clustering** | vSphere (paid) | Free clustering |

**Why we chose Proxmox:**
1. ✅ Native ZFS support (no VROC driver issues)
2. ✅ Full Linux CLI access
3. ✅ LXC containers for lightweight services
4. ✅ Built-in backup tools
5. ✅ No UEFI boot issues like ESXi

---

## Cost Analysis

### One-Time Costs

| Item | Cost |
|------|------|
| HP Z6 G4 | $0 (already owned) |
| 128GB RAM (original 4x 32GB) | $0 (already installed) |
| **+2x 32GB RAM → 192GB** | **~$600** (bought + installed Aug 26, 2026 — fills all 6 channels) |
| 6x NVMe SSDs | $0 (already owned) |
| HP Z Turbo Drive Quad Pro | $0 (already owned) |
| APC BR1500MS2 UPS | ~$300 (ordered) |
| **TOTAL** | **~$900** |

### Recurring Costs

| Item | Monthly | Annual |
|------|---------|--------|
| Electricity (~400W avg) | ~$15-20 | ~$180-240 |
| Software licenses | $0 | $0 |
| Tailscale (personal) | $0 | $0 |
| **TOTAL** | **~$15-20** | **~$180-240** |

### Commercial Equivalent Value: ~$70-100/month saved

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Dec 12, 2025 | Initial Proxmox design (migrated from ESXi plan) |

---

**Refer to `Home_Lab_Proxmox_Build_Plan.md` for step-by-step execution checklist.**

