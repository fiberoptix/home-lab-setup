# Home Lab DevOps Environment Design v1.0

**Created:** December 8, 2025  
**Updated:** December 8, 2025 (Final Design)  
**Target Platform:** VMware ESXi on HP Z6 G4  
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
**Monthly Operating Cost:** ~$15-20 (electricity for Z6 + Z8)  
**Commercial Equivalent Value:** ~$70-100/month  
**Actual Hardware:** 128GB RAM, 48 CPU cores, 3.5TB NVMe storage

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
│              VMware ESXi Host (HP Z6 G4)                         │
│              128GB RAM, 48 CPU Cores                             │
│              3x NVMe RAID Arrays (3.5TB usable)                  │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ VM1: Traefik Reverse Proxy                                 │ │
│  │ • 1GB RAM, 5GB disk on esxi-system                         │ │
│  │ • Port 80/443 (public HTTPS only)                          │ │
│  │ • Let's Encrypt SSL (Route53 DNS-01)                       │ │
│  │ • Routes to QA apps only:                                  │ │
│  │   - capricorn-qa.gothamtechnologies.com → QA:5001         │ │
│  │   - (Infrastructure NOT exposed publicly)                  │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ VM2: GitLab Community Edition                              │ │
│  │ • 12GB RAM, 200GB disk on vm-critical (RAID 1)            │ │
│  │ • Git repositories                                         │ │
│  │ • Container Registry (Docker images)                      │ │
│  │ • Package Registry (npm, pip, maven)                      │ │
│  │ • Dependency Proxy (caching)                              │ │
│  │ • CI/CD pipelines                                         │ │
│  │ • Tailscale: http://gitlab (admin VPN access)             │ │
│  │ • NOT exposed publicly (private infrastructure)            │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ VM3: GitLab Runner                                         │ │
│  │ • 8GB RAM, 100GB disk on vm-ephemeral (RAID 0 - fast)    │ │
│  │ • Executes CI/CD jobs with Docker executor                │ │
│  │ • Builds containers                                        │ │
│  │ • Runs tests                                               │ │
│  │ • Triggers SonarQube scans                                │ │
│  │ • Deploys to QA host                                       │ │
│  │ • Internal only (not exposed)                              │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ VM4: SonarQube Community Edition                           │ │
│  │ • 6GB RAM, 20GB disk on esxi-system                        │ │
│  │ • Code quality analysis                                    │ │
│  │ • Security vulnerability scanning                         │ │
│  │ • Python, JavaScript, TypeScript support                  │ │
│  │ • Technical debt tracking                                  │ │
│  │ • Tailscale: http://sonarqube:9000 (admin VPN access)     │ │
│  │ • NOT exposed publicly                                     │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ VM5: Monitoring Stack                                      │ │
│  │ • 6GB RAM, 30GB disk on esxi-system                        │ │
│  │ • Prometheus (metrics collection)                         │ │
│  │ • Grafana (dashboards)                                     │ │
│  │ • Node Exporter (system metrics)                          │ │
│  │ • Monitors: CPU, RAM, disk, containers                     │ │
│  │ • Tailscale: http://monitoring:3000 (admin VPN access)    │ │
│  │ • NOT exposed publicly                                     │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ VM6: QA Host (Ubuntu + Docker)                             │ │
│  │ • 16GB RAM, 100GB disk on vm-ephemeral (RAID 0 - fast)   │ │
│  │ • Docker + Docker Compose                                  │ │
│  │ • Deployed applications:                                   │ │
│  │   - Capricorn (port 5001)                                 │ │
│  │   - All-in-one finance application                        │ │
│  │ • Access methods:                                          │ │
│  │   - Local: http://192.168.1.56:5001                       │ │
│  │   - Tailscale VPN: http://qa-host:5001 (admin)           │ │
│  │   - Public: https://capricorn-qa.gothamtechnologies.com   │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘

TOTAL RESOURCES:
• VMs: 7 (Traefik, GitLab, Runner, SonarQube, Monitoring, QA, + ESXi)
• RAM: 44GB allocated (128GB available - massive headroom)
• CPU: 24 cores allocated (48 available)
• Storage: 3.5TB usable (3x NVMe RAID arrays)
• Cost: $0 (all open source software)
```

---

## Resource Requirements

### Hardware Requirements

| Component | Minimum | Recommended | Your HP Z6 G4 |
|-----------|---------|-------------|---------------|
| CPU Cores | 8 cores | 12+ cores | ✅ 48 cores (2x Xeon Platinum 8168) |
| RAM | 24GB | 48GB | ✅ 128GB DDR4 ECC (4x32GB) |
| Storage | 500GB | 1TB SSD | ✅ 6x NVMe (3.5TB usable in RAID) |
| Network | 1Gbps | 1Gbps+ | ✅ Built-in |
| Hypervisor | ESXi 7.0+ | ESXi 8.0+ | ✅ Compatible |

### VM Resource Allocation

| VM | Purpose | RAM | Disk | Datastore | CPU | Critical? |
|----|---------|-----|------|-----------|-----|-----------|
| VM1 | Traefik | 1GB | 5GB | esxi-system | 1 | Yes (public routing) |
| VM2 | GitLab | 12GB | 200GB | vm-critical | 4 | Yes (source control) |
| VM3 | Runner | 8GB | 100GB | vm-ephemeral | 4 | Yes (CI/CD) |
| VM4 | SonarQube | 6GB | 20GB | esxi-system | 2 | No (quality) |
| VM5 | Monitoring | 6GB | 30GB | esxi-system | 2 | No (observability) |
| VM6 | QA Host | 16GB | 100GB | vm-ephemeral | 8 | Yes (testing) |
| **TOTAL** | **6 VMs** | **49GB** | **455GB** | **3 datastores** | **21** | |
| **Available** | | **79GB free** | **3TB free** | | **27 free** | |

---

## Software Stack (All FREE)

### Core Infrastructure
- **VMware ESXi 8.0** - Free community edition hypervisor
- **Ubuntu Server 24.04 LTS** - Guest OS for ALL VMs
- **Intel VROC** - Hardware RAID for NVMe drives

### DevOps Tools
- **GitLab Community Edition** - Source control, CI/CD, container/package registries
- **GitLab Runner** - CI/CD job executor (Docker)
- **SonarQube Community Edition** - Code quality & security scanning
- **Traefik v2.10** - Reverse proxy for public QA access
- **Let's Encrypt** - Free SSL certificates (DNS-01 via Route53)

### Access & Security
- **Tailscale** - Zero-trust VPN for admin access to all services
- **AWS Route53** - DNS for public QA domain (gothamtechnologies.com)
- **UFW** - Firewall on all VMs
- **fail2ban** - Intrusion prevention on public-facing services

### Monitoring & Observability
- **Prometheus** - Metrics collection from all VMs
- **Grafana** - Dashboards & visualization
- **Node Exporter** - System metrics
- **cAdvisor** - Container metrics

### Runtime
- **Docker** - Container runtime (on all VMs)
- **Docker Compose** - Multi-container orchestration

---

## Network Architecture

### Internal Network (Home LAN)

| Service | Internal IP | Tailscale Hostname | Purpose |
|---------|-------------|-------------------|---------|
| ESXi Host | 192.168.1.50 | N/A | Hypervisor management (local only) |
| Traefik | 192.168.1.51 | traefik | Public reverse proxy (QA apps) |
| GitLab | 192.168.1.52 | gitlab | Source control (Tailscale only) |
| Runner | 192.168.1.53 | runner | CI/CD executor (internal) |
| SonarQube | 192.168.1.54 | sonarqube | Code quality (Tailscale only) |
| Monitoring | 192.168.1.55 | monitoring | Observability (Tailscale only) |
| QA Host | 192.168.1.56 | qa-host | App testing (Tailscale + public) |

### Access Methods

**Admin Access (You) - Tailscale VPN:**
| Service | Tailscale URL | Notes |
|---------|---------------|-------|
| GitLab | http://gitlab | Full GitLab access from anywhere |
| SonarQube | http://sonarqube:9000 | Code quality reports |
| Grafana | http://monitoring:3000 | Dashboards and metrics |
| QA Apps | http://qa-host:5001 | Direct app access |
| ESXi | https://192.168.1.50 | Use local IP (no Tailscale) |
| SSH | ssh admin@gitlab | SSH to any VM via VPN |

**Public Access (Friends) - HTTPS via Traefik:**
| Service | Public URL | Notes |
|---------|------------|-------|
| Capricorn QA | https://capricorn-qa.gothamtechnologies.com | Valid SSL, no VPN needed |

**NOT Exposed Publicly:**
- ❌ GitLab (admin-only via Tailscale)
- ❌ SonarQube (admin-only via Tailscale)
- ❌ Grafana (admin-only via Tailscale)
- ❌ ESXi (local network only)
- ❌ GitLab Runner (internal only)

---

## Dual-Access Strategy

This lab implements **two separate access methods** for different use cases:

### **1. Tailscale VPN - Admin Access (You)**

**Purpose:** Private, secure access to ALL infrastructure from anywhere

**What it provides:**
- Full access to GitLab, SonarQube, Grafana, ESXi
- SSH access to all VMs
- Remote administration from business trips
- No public exposure of infrastructure

**How it works:**
```
Your Laptop → Tailscale VPN → Home Lab
  ├─ http://gitlab (GitLab via MagicDNS)
  ├─ http://sonarqube:9000 (Code quality)
  ├─ http://monitoring:3000 (Grafana dashboards)
  ├─ http://qa-host:5001 (Capricorn direct access)
  └─ ssh admin@gitlab (SSH to any VM)

Encrypted tunnel, zero-trust, no port forwarding needed
```

**Use cases:**
- Push/pull code from business trips
- View pipeline results remotely
- Check monitoring dashboards
- SSH into VMs for maintenance
- Access container registry

---

### **2. Public HTTPS - QA Testing (Friends)**

**Purpose:** Easy access for external testers (no VPN required)

**What it provides:**
- Clean public URL: https://capricorn-qa.gothamtechnologies.com
- Valid SSL certificate (Let's Encrypt)
- No software installation required
- Professional appearance

**How it works:**
```
Friend's Browser → Internet → Router (Port 443) → Traefik VM
  └─ Traefik routes capricorn-qa.gothamtechnologies.com → QA Host:5001
  └─ ONLY QA apps exposed (NOT GitLab, SonarQube, Grafana, ESXi)

Public access, but infrastructure stays private
```

**Use cases:**
- Share with friends: "Test at https://capricorn-qa.gothamtechnologies.com"
- Beta testing from external users
- Mobile device testing
- Demo to stakeholders

---

### **Security Model:**

```
Publicly Exposed (via Traefik):
✅ Capricorn QA app ONLY (port 5001)
✅ HTTPS with valid SSL
✅ Rate limiting enabled
✅ Minimal attack surface

Private (Tailscale VPN only):
🔒 GitLab (source code, container registry)
🔒 SonarQube (code quality reports)
🔒 Grafana (monitoring dashboards)
🔒 ESXi (hypervisor management)
🔒 GitLab Runner (CI/CD executor)

NOT Accessible:
❌ Infrastructure services not exposed to internet
❌ Admin tools require Tailscale VPN
❌ SSH access only via Tailscale or local network
```

**Benefits of Dual-Access:**
- ✅ Infrastructure stays private and secure
- ✅ Easy QA testing for non-technical users
- ✅ Flexible access (VPN for admin, web for testers)
- ✅ Professional URLs for external sharing
- ✅ Zero-trust admin access via Tailscale
- ✅ Minimal public exposure (one app only)

---

## Development Workflow

### Standard Development Cycle

```
1. Developer writes code on DEV Host
   │
   ▼
2. Push to GitLab (VM2)
   │
   ▼
3. GitLab Runner (VM3) triggered automatically
   │
   ├─> Build Docker image
   ├─> Run unit tests (pytest, npm test)
   ├─> Push image to GitLab Container Registry
   ├─> Trigger SonarQube scan (VM4)
   │   └─> Code quality report generated
   │
   ▼
4. If all checks pass → Auto-deploy to QA Host (VM6)
   │
   ▼
5. Prometheus (VM5) monitors QA application
   │
   ▼
6. Grafana dashboards show real-time metrics
   │
   ▼
7. Friends/testers access: https://capricorn-qa.gothamtechnologies.com
   Admin access via Tailscale VPN for monitoring/debugging
```

### Sample GitLab CI/CD Pipeline

```yaml
# .gitlab-ci.yml
variables:
  DOCKER_IMAGE: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
  DOCKER_LATEST: $CI_REGISTRY_IMAGE:latest

stages:
  - build
  - test
  - quality
  - deploy

# Build Docker image and push to GitLab Container Registry
build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker build -t $DOCKER_IMAGE -t $DOCKER_LATEST .
    - docker push $DOCKER_IMAGE
    - docker push $DOCKER_LATEST
  only:
    - main
    - merge_requests

# Run automated tests
test:
  stage: test
  image: python:3.11
  before_script:
    - pip install -r requirements.txt
  script:
    - pytest tests/ --cov --cov-report=xml
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml

# SonarQube code quality scan
sonarqube:
  stage: quality
  image: sonarsource/sonar-scanner-cli
  variables:
    SONAR_HOST_URL: "http://192.168.1.54:9000"
  script:
    - sonar-scanner
      -Dsonar.projectKey=$CI_PROJECT_NAME
      -Dsonar.sources=.
      -Dsonar.host.url=$SONAR_HOST_URL
      -Dsonar.login=$SONAR_TOKEN
  allow_failure: true  # Don't block deployment on quality issues initially
  only:
    - main
    - merge_requests

# Deploy to QA environment
deploy-qa:
  stage: deploy
  image: alpine:latest
  before_script:
    - apk add --no-cache openssh-client
    - eval $(ssh-agent -s)
    - echo "$SSH_PRIVATE_KEY" | ssh-add -
  script:
    - ssh qa-host "docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY"
    - ssh qa-host "docker pull $DOCKER_IMAGE"
    - ssh qa-host "cd /opt/capricorn && docker-compose pull && docker-compose up -d"
  environment:
    name: qa
    url: https://capricorn-qa.gothamtechnologies.com
  only:
    - main
```

---

## Why GitLab CE Replaces Multiple Commercial Tools

### ✅ GitLab Built-in Features (FREE)

| Feature | Replaces | Commercial Cost |
|---------|----------|-----------------|
| Git Repositories | GitHub Enterprise | $21/user/month |
| Container Registry | Docker Hub Pro, Harbor | $5-7/month |
| Package Registry | Nexus, Artifactory | $30+/month |
| Dependency Proxy | Nexus mirror | Included above |
| CI/CD Pipelines | CircleCI, Jenkins | $30-50/month |
| Issue Tracking | Jira | $7.50/user/month |
| Wiki | Confluence | $5/user/month |
| **TOTAL SAVINGS** | | **~$70-100/month** |

### ❌ Tools You DON'T Need

- **Harbor** - GitLab Container Registry handles Docker images
- **Nexus/Artifactory** - GitLab Package Registry handles npm, pip, maven
- **Jenkins** - GitLab CI/CD is more modern and integrated
- **Docker Hub** - Use GitLab registry instead (no rate limits!)

---

## Implementation Phases

### Phase 1: Core Infrastructure (Week 1)
**Goal:** Basic CI/CD pipeline working

1. ✅ Install VMware ESXi on HP Z6 G4
2. ✅ Configure NVMe RAID 1 with Intel VROC
3. ✅ Create networking (vSwitch, port groups)
4. ✅ Create VM2 - GitLab CE
5. ✅ Create VM3 - GitLab Runner
6. ✅ Create VM6 - QA Host with Docker
7. ✅ Register Runner with GitLab
8. ✅ Create basic CI/CD pipeline
9. ✅ Deploy Capricorn to QA

**Milestone:** Push code → auto-build → auto-deploy to QA

**Test:** Make a code change, push to GitLab, verify it deploys to QA automatically

---

### Phase 2: Quality & Observability (Week 2)
**Goal:** Code quality gates and monitoring

10. ✅ Create VM4 - SonarQube CE
11. ✅ Configure SonarQube project
12. ✅ Add SonarQube stage to CI/CD pipeline
13. ✅ Create VM5 - Monitoring stack
14. ✅ Install Prometheus + Grafana
15. ✅ Configure Prometheus to scrape all VMs
16. ✅ Create Grafana dashboards

**Milestone:** Code quality reports + system monitoring working

**Test:** Push code with intentional bug, verify SonarQube catches it. Check Grafana shows CPU/RAM metrics.

---

### Phase 3: Admin Access & Public QA Setup (Week 3)
**Goal:** Tailscale VPN for admin + Public HTTPS for testers

17. ✅ Install Tailscale on all VMs (GitLab, SonarQube, Monitoring, QA Host)
18. ✅ Install Tailscale on laptop and DEV workstation
19. ✅ Test admin access via Tailscale to all services
20. ✅ Create VM1 - Traefik reverse proxy
21. ✅ Configure Route53: capricorn-qa.gothamtechnologies.com → public IP
22. ✅ Configure Traefik with Let's Encrypt (DNS-01 via Route53)
23. ✅ Setup router port forwarding (80, 443 → Traefik)
24. ✅ Configure Traefik route to QA Host:5001 only
25. ✅ Test external HTTPS access from phone

**Milestone:** Admin has VPN access + Friends can test via public URL

**Test:** 
- Admin: Access http://gitlab via Tailscale from laptop
- Friend: Access https://capricorn-qa.gothamtechnologies.com from phone

---

### Phase 4: Production Hardening (Ongoing)
**Goal:** Bulletproof reliability

26. ✅ Setup ESXi VM snapshots (weekly)
27. ✅ Configure GitLab backup automation (daily to NAS)
28. ✅ Setup UPS monitoring (NUT) with auto-shutdown
29. ✅ Add Grafana alerting (email/Slack)
30. ✅ Configure Tailscale ACLs (admin vs tester access)
31. ✅ Document runbooks for common issues
32. ✅ Implement secrets management (GitLab CI variables)
33. ✅ Setup staging environment (optional VM7)

**Milestone:** Production-grade reliability

---

## Backup Strategy

### Critical Data (Must Backup)

| Data | Location | Backup Frequency | Retention |
|------|----------|------------------|-----------|
| Git Repositories | GitLab VM | Daily | 30 days |
| Container Registry | GitLab VM | Weekly | 14 days |
| GitLab Config | `/etc/gitlab/` | Weekly | 30 days |
| SonarQube Projects | SonarQube VM | Weekly | 14 days |
| Grafana Dashboards | Monitoring VM | Weekly | 14 days |

### Backup Methods

1. **ESXi Snapshots** - Before major changes
2. **GitLab Built-in Backup** - `gitlab-backup create`
3. **External Storage** - NAS or USB drive for off-site
4. **Git Remote** - Mirror repos to external Git (GitHub/Bitbucket as backup)

### Non-Critical Data (Can Rebuild)

- QA Host applications (ephemeral, redeployable from Git)
- Prometheus metrics (time-series, can restart fresh)
- Traefik config (recreate from docker-compose)

---

## Security Considerations

### Network Security
- ✅ Firewall only ports 80, 443 open to internet (Traefik VM only)
- ✅ All infrastructure services private (Tailscale VPN only)
- ✅ SSH key-based authentication (no passwords)
- ✅ GitLab Runner isolated from production
- ✅ Tailscale zero-trust mesh VPN for admin access

### Application Security
- ✅ HTTPS for public QA apps via Let's Encrypt
- ✅ Tailscale encrypted tunnels for infrastructure access
- ✅ SonarQube scans for vulnerabilities
- ✅ Container image scanning (GitLab feature)
- ✅ Secrets stored in GitLab CI variables (encrypted)
- ✅ Regular updates via `apt upgrade`
- ✅ fail2ban on public-facing services

### Access Control
- ✅ Tailscale ACLs (admin vs tester access)
- ✅ GitLab 2FA for root user (mandatory)
- ✅ SSH keys for server access (no password auth)
- ✅ ESXi root password in password manager
- ✅ Traefik rate limiting (prevent abuse)

---

## Cost Analysis

### One-Time Costs

| Item | Cost | Notes |
|------|------|-------|
| HP Z6 G4 | $0 | Already owned |
| 128GB RAM (4x32GB) | $0 | Already installed |
| 6x NVMe SSDs | $0 | Already owned |
| ASUS Hyper M.2 Card | $0 | Already owned |
| Intel VROC Key | $0 | Already owned |
| APC BR1500MS2 UPS | $300 | Ordered |
| **TOTAL** | **~$300** | One-time UPS purchase |

### Recurring Costs

| Item | Monthly Cost | Annual Cost |
|------|--------------|-------------|
| Electricity (Z6 + Z8 ~780W) | ~$15-20 | ~$180-240 |
| Internet (already have) | $0 | $0 |
| Domain (gothamtechnologies.com) | $0 | Already owned |
| SSL (Let's Encrypt) | $0 | $0 |
| Software licenses | $0 | $0 |
| Tailscale (personal plan) | $0 | $0 |
| **TOTAL** | **~$15-20** | **~$180-240** |

### ROI Comparison

**This Home Lab Setup:**
- Upfront: ~$300 (UPS only)
- Monthly: ~$15-20
- **Annual Total: ~$480-540 first year, ~$180-240 ongoing**

**Equivalent Cloud/SaaS Services:**
- GitHub Enterprise: $252/year
- CircleCI: $360/year
- Docker Hub Pro: $60/year
- SonarCloud: $120/year
- Datadog: $180/year
- **Annual Total: ~$972/year**

**Savings: ~$530-790/year** 💰

Plus you own the infrastructure and can scale infinitely for free!

---

## Monitoring & Metrics

### Key Metrics to Track

**System Health:**
- CPU usage per VM
- RAM usage per VM
- Disk I/O (especially on RAID)
- Network throughput
- VM uptime

**Application Health:**
- Container status (running/stopped)
- HTTP response times
- Error rates (5xx responses)
- Request throughput

**CI/CD Pipeline:**
- Build success rate
- Build duration
- Deployment frequency
- Time to deploy

**Code Quality:**
- Code coverage percentage
- Technical debt (SonarQube)
- Security vulnerabilities
- Code smells

### Sample Grafana Dashboards

1. **Infrastructure Overview**
   - All VMs CPU/RAM/Disk
   - ESXi host resources
   - Network traffic

2. **Application Dashboard**
   - Capricorn response times
   - Finance Manager health
   - Portfolio Manager metrics

3. **CI/CD Dashboard**
   - Pipeline success/failure rate
   - Build queue depth
   - Deployment timeline

4. **SonarQube Dashboard**
   - Code quality trend
   - Vulnerability count
   - Technical debt ratio

---

## Troubleshooting Guide

### Common Issues

**Issue: GitLab Runner not picking up jobs**
```bash
# On Runner VM
sudo gitlab-runner verify
sudo gitlab-runner restart
# Check GitLab UI → Admin → Runners
```

**Issue: Out of disk space**
```bash
# Clean up Docker images on QA host
docker system prune -a

# Clean up GitLab registry
# GitLab UI → Project → Settings → Packages & Registries → Cleanup policies
```

**Issue: SonarQube scan fails**
```bash
# Check SonarQube logs
docker logs sonarqube

# Increase Java heap if needed
# Edit docker-compose.yml:
# SONAR_JAVA_OPTS: "-Xmx2048m"
```

**Issue: Let's Encrypt certificate not renewing**
```bash
# Check Traefik logs
docker logs traefik

# Verify DNS points to your public IP
dig gitlab.yourlab.com

# Ensure ports 80/443 forwarded to Traefik
```

**Issue: QA deployment fails**
```bash
# Check Runner can SSH to QA host
ssh qa-host "echo connected"

# Verify SSH key in GitLab CI variables
# GitLab UI → Settings → CI/CD → Variables → SSH_PRIVATE_KEY
```

---

## Future Enhancements

### Phase 5: Advanced Features (3-6 months)

**Staging Environment**
- Add VM7 as staging between QA and Prod
- Implement blue/green deployments

**Database Management**
- Add VM8 for PostgreSQL test databases
- Automated database migrations in pipeline

**Performance Testing**
- Integrate k6 or JMeter
- Automated load testing before deployment

**Advanced Monitoring**
- Add Loki for log aggregation
- Distributed tracing with Jaeger/Tempo

**Security Scanning**
- Trivy for container vulnerability scanning
- OWASP ZAP for web app security testing

**Kubernetes**
- Add K3s cluster for learning/testing
- Migrate some apps to Kubernetes

---

## Reference Links

### Official Documentation
- **VMware ESXi:** https://docs.vmware.com/en/VMware-vSphere/
- **GitLab CE:** https://docs.gitlab.com/ee/
- **SonarQube:** https://docs.sonarqube.org/
- **Traefik:** https://doc.traefik.io/traefik/
- **Prometheus:** https://prometheus.io/docs/
- **Grafana:** https://grafana.com/docs/

### Helpful Resources
- **Let's Encrypt:** https://letsencrypt.org/
- **Tailscale:** https://tailscale.com/kb/
- **AWS Route53:** https://docs.aws.amazon.com/route53/
- **Docker Compose:** https://docs.docker.com/compose/
- **GitLab CI/CD Examples:** https://docs.gitlab.com/ee/ci/examples/
- **NUT (UPS Monitoring):** https://networkupstools.org/

---

## Appendix: VM Specifications

### VM1: Traefik
```yaml
OS: Ubuntu Server 24.04 LTS
RAM: 1GB
CPU: 1 core
Disk: 5GB on esxi-system (RAID 1)
Network: Bridged (192.168.1.51)
Software: Docker, Traefik v2.10
Purpose: Public HTTPS reverse proxy for QA apps only
Access: Public port 443 (port forward from router)
```

### VM2: GitLab
```yaml
OS: Ubuntu Server 24.04 LTS
RAM: 12GB
CPU: 4 cores
Disk: 200GB on vm-critical (RAID 1)
Network: Bridged (192.168.1.52)
Software: GitLab CE (via omnibus package), Tailscale
Purpose: Source control, container/package registry, CI/CD
Access: Tailscale VPN only (NOT exposed publicly)
```

### VM3: GitLab Runner
```yaml
OS: Ubuntu Server 24.04 LTS
RAM: 8GB
CPU: 4 cores
Disk: 100GB on vm-ephemeral (RAID 0 - fast builds)
Network: Bridged (192.168.1.53)
Software: GitLab Runner, Docker
Purpose: CI/CD job executor
Access: Internal only (connects to GitLab internally)
```

### VM4: SonarQube
```yaml
OS: Ubuntu Server 24.04 LTS
RAM: 6GB
CPU: 2 cores
Disk: 20GB on esxi-system (RAID 1)
Network: Bridged (192.168.1.54)
Software: Docker, SonarQube CE, Tailscale
Purpose: Code quality & security scanning
Access: Tailscale VPN only (NOT exposed publicly)
```

### VM5: Monitoring
```yaml
OS: Ubuntu Server 24.04 LTS
RAM: 6GB
CPU: 2 cores
Disk: 30GB on esxi-system (RAID 1)
Network: Bridged (192.168.1.55)
Software: Docker Compose, Prometheus, Grafana, Node Exporter, Tailscale
Purpose: System monitoring and dashboards
Access: Tailscale VPN only (NOT exposed publicly)
```

### VM6: QA Host
```yaml
OS: Ubuntu Server 24.04 LTS
RAM: 16GB
CPU: 8 cores
Disk: 100GB on vm-ephemeral (RAID 0 - fast deployments)
Network: Bridged (192.168.1.56)
Software: Docker, Docker Compose, Tailscale
Purpose: QA application deployment (Capricorn)
Access: Tailscale VPN (admin) + Public HTTPS via Traefik (testers)
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | Dec 8, 2025 | Initial | Complete design specification |
| 1.1 | Dec 8, 2025 | Update | Dual-access strategy (Tailscale+Traefik), gothamtechnologies.com, 128GB RAM, Capricorn-only |

---

## Notes for Implementation

- Follow detailed execution plan in `Home_Lab_Build_Plan.md`
- Start with Phase 1 (Hardware + RAID), work sequentially through Phase 16
- Verify each phase works before moving to next
- Dual-access strategy: Tailscale for admin, Traefik for public QA
- All software is free and open source
- Hardware: 128GB RAM (49GB used, 79GB free), 48 CPU cores (21 used, 27 free)
- Storage: 3 RAID arrays (esxi-system, vm-critical, vm-ephemeral) = 3.5TB usable
- UPS: APC BR1500MS2 for graceful shutdown (both Z6 + Z8)
- Server arrives Friday, Dec 13, 2025

**Refer to `Home_Lab_Build_Plan.md` for step-by-step execution checklist.**

