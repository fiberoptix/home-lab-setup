# Proxmox Home Lab Build Plan

**Target:** Complete DevOps QA environment on HP Z6 G4 + Proxmox VE 9.1  
**Approach:** Phase by phase, Test → Verify → Move on  
**Started:** December 12, 2025

---

## Quick Reference

### Access

| Service | URL | Credentials |
|---------|-----|-------------|
| Proxmox Web UI | https://192.168.1.150:8006 | root / <See PASSWORDS.md> |
| Proxmox SSH | ssh root@192.168.1.150 | <See PASSWORDS.md> |

### IP Allocation

| Host/VM | IP Address | Storage Pool | Purpose |
|---------|------------|--------------|---------|
| Proxmox Host | 192.168.1.150 | - | Hypervisor |
| Traefik | 192.168.1.51 | local-zfs | Public HTTPS reverse proxy |
| GitLab | 192.168.1.52 | vm-critical | Git + CI/CD + Registry |
| Runner | 192.168.1.53 | vm-ephemeral | CI/CD job execution |
| SonarQube | 192.168.1.54 | vm-critical | Code quality analysis |
| Monitoring | 192.168.1.55 | vm-critical | Prometheus + Grafana |
| QA Host | 192.168.1.56 | vm-ephemeral | Deployed QA applications |

**Reserved:** 192.168.1.57-59 for future VMs

---

## Phase 1: Hardware & Proxmox Installation ✅ COMPLETE

- [x] Install 128GB RAM (4x32GB)
- [x] Install 2x500GB NVMe in onboard M.2 slots
- [x] Install HP Z Turbo Drive Quad Pro in PCIe slot
- [x] Install 4x1TB NVMe in HP Turbo card
- [x] Configure BIOS: PCIe bifurcation x4x4x4x4
- [x] Configure BIOS: VT-x and VT-d enabled
- [x] Configure BIOS: UEFI mode, Secure Boot disabled
- [x] Download Proxmox VE 9.1 ISO
- [x] Create bootable USB with Rufus (GPT, UEFI)
- [x] Install Proxmox on 2x500GB ZFS mirror
- [x] Configure static IP: 192.168.1.150
- [x] Access Proxmox Web UI from DEV workstation

---

## Phase 2: Storage Configuration ✅ COMPLETE

- [x] Wipe VROC metadata from 4x1TB drives (UI: Disks → Wipe)
- [x] Create ZFS pool: vm-critical (2x1TB mirror via UI)
- [x] Create ZFS pool: vm-ephemeral (2x1TB stripe via Shell)
- [x] Add vm-ephemeral to Storage (UI: Datacenter → Storage → Add → ZFS)
- [x] Verify all 3 pools visible in Proxmox UI

**Storage Summary:**
| Pool | Size | RAID | Status |
|------|------|------|--------|
| local-zfs (rpool) | ~465GB | mirror | ✅ Online |
| vm-critical | ~1TB | mirror | ✅ Online |
| vm-ephemeral | ~2TB | stripe | ✅ Online |

---

## Phase 3: System Configuration

- [ ] Fix apt repositories (disable enterprise, enable no-subscription)
- [ ] Run apt update && apt upgrade
- [ ] Configure NTP time sync
- [ ] Upload Ubuntu 24.04 LTS Server ISO to local storage
- [ ] (Optional) Disable subscription nag popup

**Commands for apt fix:**
```bash
# SSH to Proxmox
ssh root@192.168.1.150

# Disable enterprise repo
sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list

# Add no-subscription repo
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list

# Update
apt update && apt upgrade -y
```

---

## Phase 4: GitLab VM

- [ ] Create VM: gitlab (12GB RAM, 4 vCPU, 200GB on vm-critical)
- [ ] Install Ubuntu 24.04 LTS Server
- [ ] Configure static IP: 192.168.1.52
- [ ] Install open-vm-tools, updates
- [ ] Install Tailscale: `curl -fsSL https://tailscale.com/install.sh | sh`
- [ ] Connect to Tailscale: `sudo tailscale up`
- [ ] Enable Tailscale MagicDNS
- [ ] Install GitLab CE omnibus package
- [ ] Wait for initialization (~10 min)
- [ ] Get root password: `cat /etc/gitlab/initial_root_password`
- [ ] Access GitLab via Tailscale: http://gitlab
- [ ] Login and change root password
- [ ] Enable 2FA (recommended)
- [ ] Create first test project
- [ ] Verify Container Registry accessible

---

## Phase 5: GitLab Runner VM

- [ ] Create VM: runner (8GB RAM, 4 vCPU, 100GB on vm-ephemeral)
- [ ] Install Ubuntu 24.04 LTS Server
- [ ] Configure static IP: 192.168.1.53
- [ ] Install Docker
- [ ] Install GitLab Runner
- [ ] Get runner registration token from GitLab UI
- [ ] Register runner with GitLab (docker executor)
- [ ] Verify runner shows "online" in GitLab UI
- [ ] Test: Create simple .gitlab-ci.yml in test project
- [ ] Verify pipeline runs and succeeds

---

## Phase 6: QA Host VM

- [ ] Create VM: qa-host (16GB RAM, 8 vCPU, 100GB on vm-ephemeral)
- [ ] Install Ubuntu 24.04 LTS Server
- [ ] Configure static IP: 192.168.1.56
- [ ] Install Docker + Docker Compose
- [ ] Install Tailscale and connect
- [ ] Generate SSH key on runner VM
- [ ] Copy SSH key to qa-host (ssh-copy-id)
- [ ] Test SSH connection from runner to qa-host
- [ ] Update .gitlab-ci.yml: build → push to registry → deploy
- [ ] Push code, watch full pipeline
- [ ] Verify app deployed and running

---

## Phase 7: SonarQube VM

- [ ] Create VM: sonarqube (6GB RAM, 2 vCPU, 20GB on vm-critical)
- [ ] Install Ubuntu 24.04 LTS Server
- [ ] Configure static IP: 192.168.1.54
- [ ] Install Docker
- [ ] Install Tailscale and connect
- [ ] Run SonarQube container (lts-community)
- [ ] Access via Tailscale: http://sonarqube:9000
- [ ] Change default password
- [ ] Create project and generate token
- [ ] Add token to GitLab CI/CD variables
- [ ] Add SonarQube stage to .gitlab-ci.yml
- [ ] Push code, verify scan runs

---

## Phase 8: Monitoring VM

- [ ] Create VM: monitoring (6GB RAM, 2 vCPU, 30GB on vm-critical)
- [ ] Install Ubuntu 24.04 LTS Server
- [ ] Configure static IP: 192.168.1.55
- [ ] Install Docker Compose
- [ ] Install Tailscale and connect
- [ ] Create docker-compose.yml: Prometheus + Grafana + Node Exporter
- [ ] Start containers
- [ ] Install node_exporter on all VMs
- [ ] Configure Prometheus to scrape all targets
- [ ] Access Grafana via Tailscale: http://monitoring:3000
- [ ] Change Grafana password
- [ ] Add Prometheus datasource
- [ ] Import Node Exporter dashboard
- [ ] Verify all VMs showing metrics

---

## Phase 9: Route53 DNS Setup

- [ ] Login to AWS Console → Route53
- [ ] Navigate to gothamtechnologies.com hosted zone
- [ ] Get home public IP address
- [ ] Create A record: capricorn-qa.gothamtechnologies.com → public IP
- [ ] Test DNS resolution: `dig capricorn-qa.gothamtechnologies.com`
- [ ] Create IAM user for Traefik Let's Encrypt
- [ ] Attach policy: AmazonRoute53FullAccess
- [ ] Generate AWS access key + secret
- [ ] Save credentials securely

---

## Phase 10: Traefik VM + Let's Encrypt SSL

- [ ] Create VM: traefik (1GB RAM, 1 vCPU, 5GB on local-zfs)
- [ ] Install Ubuntu 24.04 LTS Server
- [ ] Configure static IP: 192.168.1.51
- [ ] Install Docker and Docker Compose
- [ ] Create Traefik configuration directory: /opt/traefik
- [ ] Create docker-compose.yml for Traefik:
  - [ ] Enable Let's Encrypt with DNS-01 challenge (Route53)
  - [ ] Configure AWS credentials
  - [ ] Setup route: capricorn-qa.gothamtechnologies.com → qa-host:5001
- [ ] Start Traefik container
- [ ] Configure router: port forward 80, 443 → 192.168.1.51
- [ ] Test HTTPS from external network (phone on cellular)
- [ ] Verify valid SSL certificate

---

## Phase 11: Backup Configuration

- [ ] Configure Proxmox vzdump backups
- [ ] Setup backup schedule for GitLab VM (daily)
- [ ] Configure GitLab automated backup
- [ ] Test backup creation
- [ ] Test restore from backup
- [ ] Document backup/restore procedures

---

## Phase 12: UPS Integration

- [ ] Connect UPS USB cable to Proxmox host
- [ ] Install NUT (Network UPS Tools)
- [ ] Configure UPS monitoring
- [ ] Set shutdown trigger: battery < 20%
- [ ] Test: Unplug UPS, verify detection
- [ ] (Optional) Configure NUT client on DEV workstation

---

## Phase 13: Production Apps Migration

- [ ] Push Capricorn to GitLab
- [ ] Create .gitlab-ci.yml pipeline:
  - [ ] Build stage: Docker build
  - [ ] Test stage: Run unit tests
  - [ ] Quality stage: SonarQube scan
  - [ ] Deploy stage: Deploy to QA host port 5001
- [ ] Push code, trigger pipeline
- [ ] Verify pipeline runs successfully
- [ ] Test locally: http://192.168.1.56:5001
- [ ] Test via Tailscale: http://qa-host:5001
- [ ] Test publicly: https://capricorn-qa.gothamtechnologies.com

---

## Phase 14: Security & Hardening

- [ ] Configure UFW firewall on all VMs
- [ ] Disable SSH password auth (keys only)
- [ ] Enable GitLab 2FA for root user
- [ ] Configure fail2ban on Traefik
- [ ] Configure Tailscale ACLs
- [ ] Review security settings

---

## Phase 15: Documentation & Final Testing

- [ ] Document all VM credentials
- [ ] Document IP addresses and hostnames
- [ ] Document backup procedures
- [ ] Create troubleshooting guide
- [ ] Stress test: Run 5 parallel pipelines
- [ ] Test full power loss scenario (UPS)
- [ ] Test restore from backup
- [ ] Update all documentation with actual configuration

---

## Completion Criteria

- [ ] All 6 VMs running and healthy
- [ ] GitLab CI/CD pipeline working end-to-end
- [ ] Tailscale admin access working from laptop
- [ ] Public QA URL working with valid SSL
- [ ] SonarQube scanning code quality
- [ ] Monitoring showing all metrics
- [ ] Backups running automatically
- [ ] UPS configured for auto-shutdown
- [ ] Documentation complete

---

## Progress Summary

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Hardware & Proxmox Install | ✅ Complete |
| 2 | Storage Configuration | ✅ Complete |
| 3 | System Configuration | 🔄 Next |
| 4 | GitLab VM | ⏳ Pending |
| 5 | GitLab Runner VM | ⏳ Pending |
| 6 | QA Host VM | ⏳ Pending |
| 7 | SonarQube VM | ⏳ Pending |
| 8 | Monitoring VM | ⏳ Pending |
| 9 | Route53 DNS | ⏳ Pending |
| 10 | Traefik + SSL | ⏳ Pending |
| 11 | Backup Config | ⏳ Pending |
| 12 | UPS Integration | ⏳ Pending |
| 13 | App Migration | ⏳ Pending |
| 14 | Security Hardening | ⏳ Pending |
| 15 | Documentation | ⏳ Pending |

**Current Phase:** 3 - System Configuration  
**Next Action:** Fix apt repositories

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Dec 12, 2025 | Initial Proxmox build plan |

