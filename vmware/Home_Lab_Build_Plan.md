# Home Lab Build Plan

**Target:** Complete DevOps QA environment on HP Z6 G4 + VMware ESXi  
**Approach:** Phase by phase, R&D → Test → Verify → Move on

---

## IP Address Allocation

| VM/Host | IP Address | Datastore | Purpose |
|---------|------------|-----------|---------|
| ESXi Host | 192.168.1.50 | - | Hypervisor management |
| Traefik | 192.168.1.51 | esxi-system | Public HTTPS reverse proxy |
| GitLab | 192.168.1.52 | vm-critical | Git + CI/CD + Registry |
| Runner | 192.168.1.53 | vm-ephemeral | CI/CD job execution |
| SonarQube | 192.168.1.54 | vm-critical | Code quality analysis |
| Monitoring | 192.168.1.55 | vm-critical | Prometheus + Grafana |
| QA Host | 192.168.1.56 | vm-ephemeral | Deployed QA applications |

**Reserved:** 192.168.1.57-59 for future VMs

---

## Route53 DNS Requirements (Public QA Only)

| DNS Record | Type | Value | Purpose |
|------------|------|-------|---------|
| `qa.gothamtechnologies.com` | A | Your Public IP | QA splash page (links to apps) |
| `capricorn-qa.gothamtechnologies.com` | A | Your Public IP | Capricorn QA app |

**Notes:**
- ❌ GitLab, SonarQube, Grafana do NOT need Route53 (Tailscale MagicDNS handles admin access)
- ✅ Only public QA URLs need Route53 entries
- ✅ Both DNS records point to same public IP → Router forwards 443 → Traefik routes by hostname

---

## Phase 1: Hardware & RAID

- [ ] Install 128GB RAM (4x32GB)
- [ ] Install 2x500GB NVMe in onboard M.2 slots
- [ ] Install ASUS Hyper M.2 card in PCIe Slot 2
- [ ] Install 4x1TB NVMe in card (all 4 slots)
- [ ] Install Intel VROC key
- [ ] Connect power, network, keyboard, monitor, UPS
- [ ] Power on, enter BIOS
- [ ] Update BIOS to 02.72+ if needed
- [ ] Configure PCIe Slot 2 bifurcation: x4x4x4x4
- [ ] Enable VROC RAID Controller
- [ ] Ctrl+I: Create RAID array 1 (2x500GB RAID 1 → esxi-system)
- [ ] Ctrl+I: Create RAID array 2 (2x1TB RAID 1 slots 1&2 → vm-critical)
- [ ] Ctrl+I: Create RAID array 3 (2x1TB RAID 0 slots 3&4 → vm-ephemeral)
- [ ] Verify all 3 arrays healthy

---

## Phase 2: ESXi Installation

- [ ] Create ESXi 8.0 USB installer
- [ ] Boot from USB
- [ ] Install ESXi on esxi-system RAID
- [ ] Configure management IP: 192.168.1.50 (static)
- [ ] Set root password
- [ ] Reboot to ESXi
- [ ] Access web UI from DEV workstation
- [ ] Apply free ESXi license
- [ ] Configure NTP, hostname
- [ ] Create datastore: esxi-system (500GB)
- [ ] Create datastore: vm-critical (1TB)
- [ ] Create datastore: vm-ephemeral (2TB)
- [ ] Upload Ubuntu 24.04 ISO

---

## Phase 3: GitLab VM

- [ ] Create VM: gitlab (12GB RAM, 4 vCPU, 200GB on vm-critical, IP: 192.168.1.52)
- [ ] Install Ubuntu 24.04 LTS Server
- [ ] Configure static IP
- [ ] Install open-vm-tools, updates
- [ ] Install Tailscale: curl -fsSL https://tailscale.com/install.sh | sh
- [ ] Connect to Tailscale: sudo tailscale up
- [ ] Enable Tailscale MagicDNS
- [ ] Note Tailscale hostname (e.g., gitlab)
- [ ] Install GitLab CE omnibus package with external_url 'http://gitlab' (Tailscale hostname)
- [ ] Wait for initialization (~10 min)
- [ ] Get root password from /etc/gitlab/initial_root_password
- [ ] Install Tailscale on DEV workstation (Z8)
- [ ] Connect DEV workstation to Tailscale
- [ ] Access GitLab via Tailscale: http://gitlab or http://192.168.1.52
- [ ] Login with root password
- [ ] Change root password
- [ ] Enable 2FA (recommended)
- [ ] Create first test project
- [ ] Verify GitLab Container Registry accessible
- [ ] Document Tailscale access for remote work

---

## Phase 4: GitLab Runner VM

- [ ] Create VM: runner (8GB RAM, 4 vCPU, 100GB on vm-ephemeral, IP: 192.168.1.53)
- [ ] Install Ubuntu 24.04 LTS Server
- [ ] Install Docker
- [ ] Install GitLab Runner
- [ ] Get runner registration token from GitLab UI
- [ ] Register runner with GitLab (docker executor)
- [ ] Verify runner shows "online" in GitLab UI
- [ ] Test: Create simple .gitlab-ci.yml in test project
- [ ] Verify pipeline runs and succeeds

---

## Phase 5: QA Host VM

- [ ] Create VM: qa-host (16GB RAM, 8 vCPU, 100GB on vm-ephemeral, IP: 192.168.1.56)
- [ ] Install Ubuntu 24.04 LTS Server
- [ ] Install Docker + Docker Compose
- [ ] Install Nginx for splash page
- [ ] Create /var/www/html/index.html (QA splash page with app links)
- [ ] Start Nginx (port 80 for splash page)
- [ ] Generate SSH key on runner VM
- [ ] Copy SSH key to qa-host (ssh-copy-id)
- [ ] Test SSH connection from runner to qa-host
- [ ] Enable GitLab Container Registry
- [ ] Update .gitlab-ci.yml: build → push to registry → deploy to qa-host
- [ ] Push code, watch full pipeline
- [ ] Verify app deployed and running on qa-host
- [ ] Access app via browser

---

## Phase 6: SonarQube VM

- [ ] Create VM: sonarqube (6GB RAM, 2 vCPU, 20GB on vm-critical, IP: 192.168.1.54)
- [ ] Install Ubuntu 24.04 LTS Server
- [ ] Install Docker
- [ ] Run SonarQube container (lts-community)
- [ ] Access SonarQube UI, change default password
- [ ] Create project in SonarQube
- [ ] Generate SonarQube token
- [ ] Add token to GitLab CI/CD variables
- [ ] Add SonarQube stage to .gitlab-ci.yml
- [ ] Push code, verify SonarQube scan runs
- [ ] Check quality report in SonarQube UI

---

## Phase 7: Monitoring VM

- [ ] Create VM: monitoring (6GB RAM, 2 vCPU, 30GB on vm-critical, IP: 192.168.1.55)
- [ ] Install Ubuntu 24.04 LTS Server
- [ ] Install Docker Compose
- [ ] Create docker-compose.yml: Prometheus + Grafana + Node Exporter
- [ ] Start containers
- [ ] Install node_exporter on all VMs (GitLab, Runner, QA, SonarQube)
- [ ] Configure Prometheus to scrape all targets
- [ ] Access Grafana UI (default admin/admin)
- [ ] Change Grafana password
- [ ] Add Prometheus datasource
- [ ] Import Node Exporter dashboard
- [ ] Import Docker monitoring dashboard
- [ ] Verify all VMs showing metrics

---

## Phase 8: Tailscale Admin Access Setup

- [ ] Install Tailscale on SonarQube VM
- [ ] Install Tailscale on Monitoring VM (Grafana remote access)
- [ ] Install Tailscale on QA Host VM
- [ ] Verify MagicDNS working for all VMs
- [ ] Install Tailscale on laptop (for business trips)
- [ ] Test laptop access via Tailscale to all services:
  - [ ] GitLab: http://gitlab
  - [ ] SonarQube: http://sonarqube:9000
  - [ ] Grafana: http://monitoring:3000
  - [ ] QA Apps: http://qa-host:5001
- [ ] Configure Tailscale ACLs (admin = full access)
- [ ] Document Tailscale hostnames and IPs
- [ ] Test SSH access to all VMs via Tailscale

---

## Phase 9: Route53 DNS Setup for Public QA Access

- [ ] Login to AWS Console → Route53
- [ ] Navigate to gothamtechnologies.com hosted zone
- [ ] Get your home public IP address (whatismyip.com)
- [ ] Create A record: qa.gothamtechnologies.com → public IP (splash page)
- [ ] Create A record: capricorn-qa.gothamtechnologies.com → public IP
- [ ] Test DNS resolution: dig qa.gothamtechnologies.com
- [ ] Test DNS resolution: dig capricorn-qa.gothamtechnologies.com
- [ ] Wait for DNS propagation (5-10 min)
- [ ] Create IAM user for Traefik Let's Encrypt DNS challenges
- [ ] Attach policy: AmazonRoute53FullAccess (or limited policy)
- [ ] Generate AWS access key + secret access key
- [ ] Save credentials securely (needed for Phase 10)

---

## Phase 10: Traefik VM + Let's Encrypt SSL

- [ ] Create VM: traefik (1GB RAM, 1 vCPU, 5GB on esxi-system, IP: 192.168.1.51)
- [ ] Install Ubuntu 24.04 LTS Server
- [ ] Configure static IP
- [ ] Install open-vm-tools, updates
- [ ] Install Docker and Docker Compose
- [ ] Create Traefik configuration directory: /opt/traefik
- [ ] Create docker-compose.yml for Traefik:
  - [ ] Enable Let's Encrypt with DNS-01 challenge (Route53)
  - [ ] Configure AWS credentials for DNS validation
  - [ ] Setup routes to QA Host for all QA subdomains
  - [ ] Enable HTTP to HTTPS redirect
  - [ ] Configure SSL certificate storage
- [ ] Create Traefik static config (traefik.yml)
- [ ] Create Traefik dynamic config for QA routes:
  - [ ] qa.gothamtechnologies.com → qa-host:80 (Nginx splash page)
  - [ ] capricorn-qa.gothamtechnologies.com → qa-host:5001
- [ ] Start Traefik container
- [ ] Verify Traefik dashboard accessible (internal only)
- [ ] Check Traefik logs for Let's Encrypt certificate requests
- [ ] Configure router: port forward 80, 443 → 192.168.1.51 (Traefik)
- [ ] Test HTTPS from external network (phone on cellular):
  - [ ] https://capricorn-qa.gothamtechnologies.com
  - [ ] Verify valid SSL certificate
  - [ ] Test Capricorn app functionality
- [ ] Configure Traefik security headers
- [ ] Setup rate limiting (optional, prevent abuse)
- [ ] Document public QA URLs for sharing with testers

---

## Phase 11: Backup Configuration

- [ ] Mount NAS on ESXi host (NFS/SMB)
- [ ] Install ghettoVCB on ESXi (VM backup script)
- [ ] Configure ghettoVCB backup schedule (weekly)
- [ ] Test VM backup to NAS
- [ ] Configure GitLab automated backup (daily 2am)
- [ ] Configure GitLab backup to rsync to NAS
- [ ] Test GitLab backup creation
- [ ] Test GitLab restore from backup
- [ ] Document backup/restore procedures

---

## Phase 12: UPS Integration

- [ ] Connect UPS USB cable to ESXi host
- [ ] Install/enable NUT (Network UPS Tools) on ESXi
- [ ] Configure UPS monitoring
- [ ] Set shutdown trigger: on battery + runtime < 8 min
- [ ] Configure VM shutdown order (GitLab last)
- [ ] Test: Unplug UPS, verify detection
- [ ] Verify ESXi starts shutdown sequence
- [ ] Plug UPS back in before full shutdown
- [ ] Install NUT client on DEV workstation (Z8)
- [ ] Configure DEV to connect to ESXi NUT server
- [ ] Test: Both machines get shutdown signal

---

## Phase 13: Production Apps Migration

- [ ] Push Capricorn to GitLab
- [ ] Create .gitlab-ci.yml pipeline for Capricorn:
  - [ ] Build stage: Docker build
  - [ ] Test stage: Run unit tests
  - [ ] Quality stage: SonarQube scan
  - [ ] Deploy stage: Deploy to QA host port 5001
- [ ] Push code, trigger pipeline
- [ ] Verify pipeline runs successfully end-to-end
- [ ] Test Capricorn locally: http://192.168.1.56:5001
- [ ] Test Capricorn via Tailscale: http://qa-host:5001
- [ ] Test Capricorn publicly: https://capricorn-qa.gothamtechnologies.com
- [ ] Verify SSL certificate valid (Let's Encrypt)
- [ ] Test all Capricorn features in QA
- [ ] Document Capricorn QA URL for sharing with testers
- [ ] Share URL with friends for beta testing
- [ ] Collect feedback, iterate

---

## Phase 14: Security & Hardening

- [ ] Enable GitLab 2FA for root user (already done in Phase 3)
- [ ] Configure GitLab email notifications (SMTP)
- [ ] Rotate all default passwords
- [ ] Configure UFW firewall on all VMs:
  - [ ] GitLab: Allow 80, 443, 22 (SSH)
  - [ ] Traefik: Allow 80, 443, 22 (SSH)
  - [ ] Others: Allow 22 (SSH) only, internal access via Tailscale
- [ ] Disable SSH password auth on all VMs (keys only)
- [ ] Configure fail2ban on publicly-accessible VMs (Traefik)
- [ ] Enable GitLab container scanning in pipelines
- [ ] Review GitLab security settings (disable public signup, etc.)
- [ ] Configure Tailscale ACLs for admin full access
- [ ] Review Traefik access logs for suspicious activity
- [ ] Setup SSH key rotation policy (quarterly)
- [ ] Document security procedures

---

## Phase 15: Monitoring & Alerts

- [ ] Configure Grafana alert channels (email/Slack)
- [ ] Create alert: Disk space < 20%
- [ ] Create alert: CPU > 80% for 5 min
- [ ] Create alert: RAM > 90%
- [ ] Create alert: VM down
- [ ] Create alert: GitLab pipeline failures
- [ ] Create alert: Docker container stopped
- [ ] Test alerts by triggering conditions
- [ ] Configure GitLab pipeline notifications
- [ ] Document alert response procedures

---

## Phase 16: Documentation & Final Testing

- [ ] Document all VM credentials (in password manager)
- [ ] Document IP addresses and Tailscale hostnames
- [ ] Document all public QA URLs (*.qa.gothamtechnologies.com)
- [ ] Document backup procedures
- [ ] Document restore procedures
- [ ] Create troubleshooting guide
- [ ] Create "How to add new VM" guide
- [ ] Create "How to add new app to pipeline" guide
- [ ] Create "How to share QA apps with testers" guide
- [ ] Stress test: Run 5 parallel pipelines
- [ ] Monitor resource usage during stress test
- [ ] Verify all services remain stable
- [ ] Test full power loss scenario (UPS)
- [ ] Test restore from backup
- [ ] Test remote access scenarios:
  - [ ] Business trip: Tailscale access to GitLab
  - [ ] Friend testing: Public QA URL access
  - [ ] Mobile access: Test QA URLs from phone
- [ ] Update Home_Lab_Design_v1.md with actual configuration
- [ ] Update MEMORY.md with final architecture
- [ ] Mark project complete

---

## Completion Criteria

✅ All 7 VMs running and healthy (GitLab, Runner, QA, SonarQube, Monitoring, Traefik, plus ESXi)  
✅ GitLab CI/CD pipeline working end-to-end  
✅ All apps deployed and accessible locally (192.168.1.x)  
✅ Tailscale admin access working from laptop (full lab access)  
✅ Public QA URLs working with valid SSL (*.qa.gothamtechnologies.com)  
✅ Friends can access QA apps via public URLs (no VPN needed)  
✅ SonarQube scanning code quality  
✅ Monitoring showing all metrics (accessible via Tailscale)  
✅ Backups running automatically to NAS  
✅ UPS configured for auto-shutdown (both Z6 + Z8)  
✅ Documentation complete  
✅ Stress tested and stable  

---

**Status:** Not started  
**Next Phase:** Phase 1 - Hardware & RAID

---

## Key Architecture Decisions

### **Dual-Access Strategy:**

**1. Admin Access (You) → Tailscale VPN**
- Private encrypted tunnel to ALL services
- Access GitLab, SonarQube, Grafana, ESXi from anywhere
- No public exposure of infrastructure
- Perfect for business trips and remote work

**2. Public QA Testing (Friends) → Traefik + Route53**
- Clean public URLs: *.qa.gothamtechnologies.com
- Valid SSL certificates via Let's Encrypt
- Only QA apps exposed (not infrastructure)
- Easy sharing with testers (just send URL)

### **Security Model:**

```
Public Internet (Port 443):
└─ Traefik VM (192.168.1.51)
    └─ ONLY routes to Capricorn QA app
    └─ capricorn-qa.gothamtechnologies.com → qa-host:5001

Private VPN (Tailscale):
└─ YOU have full access to everything
    ├─ GitLab (http://gitlab or 192.168.1.52)
    ├─ SonarQube (http://sonarqube:9000)
    ├─ Grafana (http://monitoring:3000)
    ├─ ESXi (https://192.168.1.50)
    ├─ QA Host (http://qa-host)
    └─ SSH to all VMs

NOT Exposed:
├─ GitLab (Tailscale only)
├─ SonarQube (Tailscale only)
├─ Grafana (Tailscale only)
├─ ESXi (local network only)
└─ GitLab Runner (internal only)
```

### **Benefits:**
- ✅ Infrastructure stays private (Tailscale VPN)
- ✅ Easy QA testing for friends (public URLs with SSL)
- ✅ Professional appearance (*.gothamtechnologies.com)
- ✅ Flexible access (admin via VPN, testers via web)
- ✅ Secure (minimal public exposure)
- ✅ All free (Tailscale + Let's Encrypt + Route53 existing)

