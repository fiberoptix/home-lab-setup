# Phase 7: Local WWW/Production Server

**Status:** 🔲 PLANNING  
**Depends On:** Phase 5 (CI/CD Pipelines), Phase 6 (SonarQube)  
**Goal:** Replace expensive GCP hosting with local production server, maintain GCP for interview demos only

---

## Overview

Phase 7 creates a local production web server to host:
1. **Capricorn PROD** - The main finance application at `cap.gothamtechnologies.com`
2. **Splash Page** - Company landing page at `www.gothamtechnologies.com`

This eliminates ongoing GCP costs while keeping GCP available for interview demonstrations.

---

## Architecture

### Network Topology

```
Internet
    │
    ▼
[Verizon Router] ──── Port Forward 80,443 ────┐
    │                                          │
    │ (LAN 192.168.1.x)                        ▼
    │                                  ┌───────────────┐
    ├── Proxmox Host (.150)            │  vm-www-1     │
    │   ├── vm-gitlab-1 (.181)         │  .184         │
    │   ├── vm-gitrun-1 (.182)         │               │
    │   ├── vm-sonarqube-1 (.183)      │  ┌─────────┐  │
    │   ├── vm-kubernetes-1 (.180) QA  │  │ Traefik │  │
    │   └── vm-www-1 (.184) ◄──────────┼──│ :80/443 │  │
    │                                  │  └────┬────┘  │
    └── DEV Workstation (.195)         │       │       │
                                       │  ┌────▼────┐  │
                                       │  │Capricorn│  │
                                       │  │ :5001   │  │
                                       │  └─────────┘  │
                                       │  ┌─────────┐  │
                                       │  │ Splash  │  │
                                       │  │ :8080   │  │
                                       │  └─────────┘  │
                                       └───────────────┘
```

### DNS Configuration

| Domain | Record Type | Value | Purpose |
|--------|-------------|-------|---------|
| `cap.gothamtechnologies.com` | CNAME | `capricorn.ddns.net` | Local Capricorn |
| `www.gothamtechnologies.com` | CNAME | `capricorn.ddns.net` | Splash page |
| `capricorn.gothamtechnologies.com` | A | GCP IP (existing) | Interview demos |

### Environment Naming (Final)

| Environment | Location | Branch | URL | Deploy Trigger |
|-------------|----------|--------|-----|----------------|
| **DEV** | Workstation | local | localhost:3000 | Manual (npm run dev) |
| **QA** | .180 | develop | http://192.168.1.180:5001 | Auto on push |
| **PROD-Local** | .184 | production | https://cap.gothamtechnologies.com | Manual button |
| **PROD-GCP** | GCP | production | https://capricorn.gothamtechnologies.com | Manual button |

---

## VM Specification

### vm-www-1

| Setting | Value | Rationale |
|---------|-------|-----------|
| **VMID** | 184 | Sequential after SonarQube |
| **Name** | vm-www-1 | Naming convention |
| **IP** | 192.168.1.184 | Static, sequential |
| **RAM** | 4 GB | Sufficient for Traefik + 2 containers |
| **CPU** | 4 cores | Web serving, SSL termination |
| **Disk** | 50 GB | Container images, logs, certificates |
| **Storage Pool** | vm-critical | Mirrored/redundant for production |
| **OS** | Ubuntu 24.04 LTS Server | Standard |
| **Auto-start** | Yes | Recovery after Proxmox reboot |

### Proxmox Create Command

```bash
qm create 184 \
  --name vm-www-1 \
  --memory 4096 \
  --cores 4 \
  --cpu host \
  --numa 0 \
  --onboot 1 \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr0,firewall=1 \
  --scsi0 vm-critical:0,iothread=1,discard=on,cache=none,aio=native,size=50G
```

---

## Implementation Tasks

### Task 1: Create VM in Proxmox

- [ ] SSH to Proxmox host (192.168.1.150)
- [ ] Run qm create command (above)
- [ ] Attach Ubuntu 24.04 ISO
- [ ] Start VM, complete Ubuntu installation
- [ ] Configure static IP: 192.168.1.184
- [ ] Set hostname: vm-www-1
- [ ] Reboot and verify network connectivity

### Task 2: Run Host Setup Scripts

```bash
# On vm-www-1 after Ubuntu install
wget http://192.168.1.195/scripts/host_setup.sh
bash host_setup.sh
```

This installs:
- ✅ SSH server
- ✅ Passwordless sudo
- ✅ Docker + Docker Compose
- ✅ Git (configured)
- ✅ NAS mount (~/DevShare)
- ✅ Insecure registry config for GitLab

### Task 3: Configure Proxmox Firewall

**Goal:** Only allow ports 80 and 443 from internet. SSH only from internal network.

On Proxmox Web UI → vm-www-1 → Firewall → Options:
- Enable firewall: Yes

Add rules (Firewall → Add):

| Direction | Action | Source | Protocol | Dest Port | Comment |
|-----------|--------|--------|----------|-----------|---------|
| IN | ACCEPT | 192.168.1.0/24 | tcp | 22 | SSH (internal only) |
| IN | ACCEPT | | tcp | 80 | HTTP (internet) |
| IN | ACCEPT | | tcp | 443 | HTTPS (internet) |
| IN | DROP | | - | - | Default deny |

**Outbound:** Allow all (needed for apt, docker pulls, Let's Encrypt, etc.)

**Note:** SSH is only accessible from internal LAN (192.168.1.x), NOT from the internet.

### Task 4: Install Traefik Reverse Proxy

Traefik handles:
- SSL termination (Let's Encrypt)
- Routing by hostname
- Automatic certificate renewal

**Directory structure:**
```
/opt/traefik/
├── docker-compose.yml
├── traefik.yml
├── acme.json           # Let's Encrypt certificates
└── config/
    └── dynamic.yml     # Route definitions
```

**docker-compose.yml:**
```yaml
version: '3.8'

services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/traefik.yml:ro
      - ./acme.json:/acme.json
    networks:
      - web

networks:
  web:
    external: true
```

**traefik.yml:**
```yaml
api:
  dashboard: false  # No public dashboard

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

certificatesResolvers:
  letsencrypt:
    acme:
      email: andrew.gamache@gmail.com
      storage: /acme.json
      httpChallenge:
        entryPoint: web

providers:
  docker:
    exposedByDefault: false
```

**Note:** Using HTTP-01 challenge - Traefik automatically handles certificate verification via port 80. No AWS credentials needed!

**Create acme.json:**
```bash
touch /opt/traefik/acme.json
chmod 600 /opt/traefik/acme.json
```

**Create Docker network:**
```bash
docker network create web
```

### Task 5: Create Splash Page

Simple landing page for `www.gothamtechnologies.com`.

**Directory:** `/opt/splash/`

**docker-compose.yml:**
```yaml
version: '3.8'

services:
  splash:
    image: nginx:alpine
    container_name: splash
    restart: unless-stopped
    volumes:
      - ./html:/usr/share/nginx/html:ro
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.splash.rule=Host(`www.gothamtechnologies.com`)"
      - "traefik.http.routers.splash.entrypoints=websecure"
      - "traefik.http.routers.splash.tls.certresolver=letsencrypt"
      - "traefik.http.services.splash.loadbalancer.server.port=80"
    networks:
      - web

networks:
  web:
    external: true
```

**html/index.html:**
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Gotham Technologies</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            font-family: 'Segoe UI', system-ui, sans-serif;
            color: #fff;
        }
        .container {
            text-align: center;
            padding: 2rem;
        }
        h1 {
            font-size: 3.5rem;
            font-weight: 300;
            letter-spacing: 0.1em;
            margin-bottom: 1rem;
            background: linear-gradient(90deg, #e94560, #ff6b6b);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        .tagline {
            font-size: 1.2rem;
            color: #a0a0a0;
            letter-spacing: 0.2em;
            text-transform: uppercase;
        }
        .divider {
            width: 100px;
            height: 2px;
            background: linear-gradient(90deg, transparent, #e94560, transparent);
            margin: 2rem auto;
        }
        .coming-soon {
            font-size: 0.9rem;
            color: #666;
            margin-top: 2rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>GOTHAM TECHNOLOGIES</h1>
        <p class="tagline">Innovation in Progress</p>
        <div class="divider"></div>
        <p class="coming-soon">More coming soon</p>
    </div>
</body>
</html>
```

### Task 6: Configure Capricorn PROD Deployment

**Directory:** `/opt/capricorn/`

**docker-compose.yml:**
```yaml
version: '3.8'

services:
  capricorn-frontend:
    image: gitlab.gothamtechnologies.com:5050/production/capricorn/frontend:latest
    container_name: capricorn-frontend
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.capricorn.rule=Host(`cap.gothamtechnologies.com`)"
      - "traefik.http.routers.capricorn.entrypoints=websecure"
      - "traefik.http.routers.capricorn.tls.certresolver=letsencrypt"
      - "traefik.http.services.capricorn.loadbalancer.server.port=80"
    networks:
      - web

  capricorn-backend:
    image: gitlab.gothamtechnologies.com:5050/production/capricorn/backend:latest
    container_name: capricorn-backend
    restart: unless-stopped
    # Backend exposed via frontend proxy, not directly via Traefik
    networks:
      - web

networks:
  web:
    external: true
```

**Note:** Actual docker-compose will depend on Capricorn's current structure. We'll adapt this during implementation.

### Task 7: Update GitLab CI/CD Pipeline

Add two manual deployment buttons for the `production` branch.

**Updates to Capricorn's .gitlab-ci.yml:**

```yaml
stages:
  - build
  - push
  - scan
  - deploy_qa
  - deploy_prod  # Renamed from deploy_gcp

# ... existing build/push/scan stages ...

# QA Deployment (automatic on develop)
deploy_qa:
  stage: deploy_qa
  # ... existing config ...
  only:
    - develop

# LOCAL PROD Deployment (manual button)
deploy_prod_local:
  stage: deploy_prod
  image: alpine:latest
  before_script:
    - apk add --no-cache openssh-client
    - eval $(ssh-agent -s)
    - echo "$SSH_PRIVATE_KEY" | tr -d '\r' | ssh-add -
    - mkdir -p ~/.ssh
    - chmod 700 ~/.ssh
    - ssh-keyscan -H 192.168.1.184 >> ~/.ssh/known_hosts
  script:
    - |
      ssh agamache@192.168.1.184 << 'EOF'
        cd /opt/capricorn
        docker login gitlab.gothamtechnologies.com:5050 -u root -p $CI_REGISTRY_PASSWORD
        docker-compose pull
        docker-compose up -d
        docker image prune -f
        echo "Deployed to LOCAL PROD: https://cap.gothamtechnologies.com"
      EOF
  only:
    - production
  when: manual
  environment:
    name: production-local
    url: https://cap.gothamtechnologies.com

# GCP PROD Deployment (manual button - existing, for interviews)
deploy_prod_gcp:
  stage: deploy_prod
  image: alpine:latest
  before_script:
    - apk add --no-cache curl bash git
    # ... existing GCP setup ...
  script:
    # ... existing GCP deployment script ...
    - echo "Deployed to GCP PROD: https://capricorn.gothamtechnologies.com"
  only:
    - production
  when: manual
  environment:
    name: production-gcp
    url: https://capricorn.gothamtechnologies.com
```

### Task 8: Configure Verizon G3100 Router Port Forwarding

**Access router:** http://192.168.1.1 (or My Verizon app)

**Port forwarding rules to add:**

| External Port | Internal IP | Internal Port | Protocol | Description |
|---------------|-------------|---------------|----------|-------------|
| 80 | 192.168.1.184 | 80 | TCP | HTTP (redirects to HTTPS) |
| 443 | 192.168.1.184 | 443 | TCP | HTTPS |

**Note:** NO SSH (port 22) forwarding - SSH only accessible from internal network.

**Steps for Verizon G3100:**
1. Open browser to http://192.168.1.1
2. Login with admin password (on router sticker or custom)
3. Click **Advanced** in top menu
4. Click **Port Forwarding** in left sidebar
5. Click **Add Port Forwarding Rule**
6. For HTTP:
   - Description: `WWW-HTTP`
   - Device: Select `192.168.1.184` (or enter manually)
   - External Port: `80`
   - Internal Port: `80`
   - Protocol: `TCP`
   - Click **Add**
7. For HTTPS:
   - Description: `WWW-HTTPS`
   - Device: `192.168.1.184`
   - External Port: `443`
   - Internal Port: `443`
   - Protocol: `TCP`
   - Click **Add**
8. Click **Apply** to save changes

**Verify:** After setup, check https://www.yougetsignal.com/tools/open-ports/ to confirm ports 80/443 are open.

### Task 9: Install and Configure NoIP on vm-www-1

NoIP Dynamic Update Client (DUC) will run on vm-www-1 to keep your dynamic IP updated.

**Prerequisites:**
1. NoIP.com account (Andrew has this)
2. Hostname created in NoIP (e.g., `gothamtech.ddns.net`)

**Install NoIP DUC on vm-www-1:**
```bash
# SSH to vm-www-1
ssh agamache@192.168.1.184

# Install build dependencies
sudo apt update
sudo apt install -y build-essential

# Download NoIP DUC
cd /usr/local/src
sudo wget https://dmej8g5cpdyqd.cloudfront.net/downloads/noip-duc_3.3.0.tar.gz
sudo tar xzf noip-duc_3.3.0.tar.gz
cd noip-duc_3.3.0

# Build and install
sudo make
sudo make install

# Configure (will prompt for NoIP credentials)
sudo noip-duc --configure

# Create systemd service
sudo tee /etc/systemd/system/noip-duc.service << 'EOF'
[Unit]
Description=NoIP Dynamic Update Client
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/noip-duc
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable noip-duc
sudo systemctl start noip-duc

# Verify it's running
sudo systemctl status noip-duc
```

**Verify IP Update:**
```bash
# Check NoIP dashboard shows your current public IP
# Or use:
curl -s ifconfig.me
# Compare with what NoIP shows for your hostname
```

**Note:** NoIP DUC checks your IP periodically and updates the hostname if it changes. This ensures `cap.gothamtechnologies.com` and `www.gothamtechnologies.com` always resolve to your current home IP.

### Task 10: Configure AWS Route53 (MANUAL - Andrew)

**⚠️ MANUAL TASK FOR ANDREW**

**In AWS Console → Route53 → gothamtechnologies.com hosted zone:**

**Add CNAME records:**

| Name | Type | Value | TTL |
|------|------|-------|-----|
| cap | CNAME | capricorn.ddns.net | 300 |
| www | CNAME | capricorn.ddns.net | 300 |

**Keep existing (unchanged):**
| Name | Type | Value | TTL |
|------|------|-------|-----|
| capricorn | A | (GCP IP) | 300 |

**TTL Note:** Using 300 seconds (5 min) for faster propagation during testing. Can increase later.

**Checklist:**
- [ ] Andrew: Create `cap` CNAME → `capricorn.ddns.net`
- [ ] Andrew: Create `www` CNAME → `capricorn.ddns.net`
- [ ] Verify with: `dig cap.gothamtechnologies.com` (should return CNAME to capricorn.ddns.net)

---

## Testing & Validation

### Pre-Deployment Checklist

- [ ] VM created and accessible via SSH (192.168.1.184) from internal network
- [ ] host_setup.sh completed successfully
- [ ] Docker running, can pull from GitLab registry
- [ ] Proxmox firewall rules in place (80, 443 open; SSH internal only)
- [ ] NoIP DUC installed and running on vm-www-1
- [ ] NoIP hostname (capricorn.ddns.net) showing correct public IP
- [ ] **Andrew:** Router port forwarding configured (80, 443 → .184)
- [ ] **Andrew:** Route53 CNAMEs created (cap, www → capricorn.ddns.net)

### SSL Certificate Test

```bash
# On vm-www-1, after Traefik starts
docker logs traefik

# Look for:
# "Certificate obtained successfully" or similar

# Test from external (phone on cellular):
curl -I https://cap.gothamtechnologies.com
curl -I https://www.gothamtechnologies.com
```

### Application Tests

| Test | Expected Result |
|------|-----------------|
| https://www.gothamtechnologies.com | Splash page loads |
| https://cap.gothamtechnologies.com | Capricorn app loads |
| http://cap.gothamtechnologies.com | Redirects to HTTPS |
| Pipeline "Deploy to Local PROD" button | Deploys successfully |
| Pipeline "Deploy to GCP PROD" button | Deploys to GCP (if enabled) |

### Security Tests

```bash
# From external network (phone hotspot or ask friend), verify only web ports open:
nmap -Pn <your-public-ip>   # Should ONLY show 80, 443 (no SSH!)

# Verify can't reach internal services from external:
curl http://192.168.1.181  # GitLab - should timeout/fail
curl http://192.168.1.183:9000  # SonarQube - should timeout/fail

# Verify SSH only works from internal:
# From external: ssh agamache@<your-public-ip> → Should fail/timeout
# From internal: ssh agamache@192.168.1.184 → Should work
```

---

## Rollback Plan

If issues occur:

1. **DNS:** Change Route53 CNAMEs back to GCP IP
2. **Router:** Remove port forwarding rules
3. **VM:** Can be deleted and recreated (stateless, images from registry)

---

## Cost Savings

| Item | GCP Monthly | Local Monthly | Savings |
|------|-------------|---------------|---------|
| Compute (e2-medium or similar) | ~$25-40 | $0 | $25-40 |
| Egress bandwidth | ~$5-10 | $0 | $5-10 |
| **Total** | **~$30-50** | **~$2-3 electricity** | **~$30-45/month** |

**Annual savings:** ~$360-540

---

## Decisions Made

| Question | Answer | Date |
|----------|--------|------|
| NoIP installation | Install on vm-www-1 | Jan 22, 2026 |
| NoIP hostname | capricorn.ddns.net | Jan 22, 2026 |
| Route53 configuration | Manual task for Andrew | Jan 22, 2026 |
| Router model | Verizon G3100 | Jan 22, 2026 |
| SSH from WAN | NO - internal only | Jan 22, 2026 |
| Let's Encrypt method | HTTP-01 (no AWS creds needed) | Jan 22, 2026 |

## Outstanding Questions

None - all questions resolved! Ready for implementation.

---

## Implementation Order

| Step | Task | Who | Status |
|------|------|-----|--------|
| 1 | Create VM in Proxmox | AI | 🔲 |
| 2 | Run host_setup.sh | AI | 🔲 |
| 3 | Configure Proxmox firewall | AI | 🔲 |
| 4 | Install NoIP DUC on vm-www-1 | AI | 🔲 |
| 5 | Install Traefik + create Docker network | AI | 🔲 |
| 6 | Deploy splash page container | AI | 🔲 |
| 7 | Configure Verizon G3100 port forwarding | Andrew | 🔲 |
| 8 | Configure Route53 CNAMEs | Andrew | 🔲 |
| 9 | Test SSL certificates (wait for DNS propagation) | AI | 🔲 |
| 10 | Update GitLab CI/CD pipeline | AI | 🔲 |
| 11 | Copy SSH key from runner to vm-www-1 | AI | 🔲 |
| 12 | Deploy Capricorn via pipeline | AI | 🔲 |
| 13 | Full end-to-end testing | Both | 🔲 |

---

## Related Files

- `/phases/phase5_ci_cd_pipelines.md` - Existing pipeline configuration
- `/phases/phase6_sonarqube.md` - Quality gates
- `/MEMORY.md` - Current infrastructure state
- `/www/scripts/host_setup.sh` - VM setup automation

---

**Phase 7 Planning Complete:** January 22, 2026  
**Ready for:** User review and approval before implementation
