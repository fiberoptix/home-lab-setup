# Phase 7: Local WWW/Production Server

**Status:** ✅ COMPLETE (January 22, 2026 - 8:45 PM EST)  
**Depends On:** Phase 5 (CI/CD Pipelines), Phase 6 (SonarQube)  
**Goal:** Replace expensive GCP hosting with local production server, maintain GCP for interview demos only

---

## 🎉 IMPLEMENTATION COMPLETE - January 22, 2026

**Live URLs:**
- ✅ https://cap.gothamtechnologies.com (Capricorn PROD)
- ✅ https://www.gothamtechnologies.com (Splash page)
- ✅ https://192.168.1.184 (Direct IP access, internal network)

**Duration:** 5:30 PM - 8:45 PM EST (~3 hours including troubleshooting)

---

## FINAL CONFIGURATION DETAILS

### VM Specifications (vm-www-1)

```
VMID: 184
Name: vm-www-1
IP: 192.168.1.184 (static)
RAM: 8 GB (not 4 GB as planned - needed more for Desktop + services)
CPU: 8 cores (host type)
Disk: 50 GB on vm-critical (mirrored ZFS)
OS: Ubuntu 24.04 Desktop (not Server - user preference)
Network: vmbr0 with firewall=1
Auto-start: Yes
```

**Proxmox Create Command Used:**
```bash
qm create 184 --name vm-www-1 --memory 8192 --cores 8 --cpu host --numa 0 \
  --onboot 1 --scsihw virtio-scsi-single --net0 virtio,bridge=vmbr0,firewall=1 \
  --scsi0 vm-critical:0,iothread=1,discard=on,cache=none,aio=native,size=50G
```

### Network Architecture (CRITICAL - READ THIS!)

**🚨 KEY LEARNING: Traefik MUST be on ALL networks to route traffic!**

Phase 7 uses a **multi-network Docker architecture** for security:

```
┌─────────────────────────────────────────────────────────────────┐
│  web network (172.18.0.0/16) - Public-facing                    │
│  ├── traefik (172.18.0.5)          ← Entry point for traffic   │
│  ├── splash (172.18.0.2)           ← www.gothamtechnologies.com│
│  ├── capricorn-frontend (172.18.0.4) ← cap.gothamtechnologies  │
│  └── capricorn-backend (172.18.0.3)                            │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  capricorn_capricorn-network (172.19.0.0/16) - Internal        │
│  ├── traefik (172.19.0.6)          ← MUST join to reach below │
│  ├── capricorn-frontend (172.19.0.5)                           │
│  ├── capricorn-backend (172.19.0.4)                            │
│  ├── postgres (172.19.0.3)         ← NOT on web (isolated)    │
│  └── redis (172.19.0.2)            ← NOT on web (isolated)    │
└─────────────────────────────────────────────────────────────────┘
```

**Why This Matters:**
- Frontend/backend need to talk to postgres/redis (on capricorn network)
- Traefik needs to forward traffic to frontend/backend (must reach capricorn network)
- Postgres/redis should NOT be exposed to public web network (security)
- **Solution:** Traefik joins BOTH networks, databases stay isolated

**Container Network Membership:**
| Container | web network | capricorn network | Reason |
|-----------|-------------|-------------------|--------|
| traefik | ✅ | ✅ | Bridges public→private |
| splash | ✅ | ❌ | Simple nginx, no DB |
| capricorn-frontend | ✅ | ✅ | Receives traffic + talks to backend |
| capricorn-backend | ✅ | ✅ | Receives API calls + talks to DB |
| postgres | ❌ | ✅ | Internal only (security) |
| redis | ❌ | ✅ | Internal only (security) |

### Traefik Configuration

**Location:** `/opt/traefik/`

**Files Created:**
1. `docker-compose.yml`
2. `traefik.yml`
3. `acme.json` (Let's Encrypt certificates, auto-created)

**docker-compose.yml (FINAL VERSION):**
```yaml
version: '3.8'

services:
  traefik:
    image: traefik:latest
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"  # API/dashboard for debugging
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/traefik.yml:ro
      - ./acme.json:/acme.json
    networks:
      - web
      - capricorn_capricorn-network  # ← CRITICAL: Added after troubleshooting!

networks:
  web:
    external: true
  capricorn_capricorn-network:
    external: true
```

**traefik.yml (with DEBUG logging):**
```yaml
log:
  level: DEBUG  # Helpful for troubleshooting

api:
  dashboard: true
  insecure: true  # Dashboard at :8080/dashboard/ for debugging

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

**Commands to Deploy Traefik:**
```bash
cd /opt/traefik
touch acme.json && chmod 600 acme.json
docker network create web
sudo docker compose up -d
```

### Splash Page Configuration

**Location:** `/opt/splash/`

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

**html/index.html:** Simple gradient landing page with "GOTHAM TECHNOLOGIES" branding

### Capricorn PROD Configuration

**Location:** `/opt/capricorn/`

**Files Created:**
1. `docker-compose.yml` (based on qa.deploy.yml, adapted for Traefik)
2. `database/` (copied from local workstation - SQL init scripts)

**docker-compose.yml (FINAL - with IP routing):**
```yaml
version: '3.8'

services:
  capricorn-frontend-prod:
    image: gitlab.gothamtechnologies.com:5050/production/capricorn/frontend:latest
    container_name: capricorn-frontend-prod
    restart: unless-stopped
    environment:
      - REACT_APP_API_URL=/api
    labels:
      # Hostname-based routing
      - "traefik.enable=true"
      - "traefik.http.routers.capricorn.rule=Host(`cap.gothamtechnologies.com`)"
      - "traefik.http.routers.capricorn.entrypoints=websecure"
      - "traefik.http.routers.capricorn.tls.certresolver=letsencrypt"
      - "traefik.http.services.capricorn.loadbalancer.server.port=80"
      # IP-based routing (for internal access)
      - "traefik.http.routers.capricorn-ip.rule=Host(`192.168.1.184`)"
      - "traefik.http.routers.capricorn-ip.entrypoints=websecure"
      - "traefik.http.routers.capricorn-ip.tls=true"
    networks:
      - web
      - capricorn-network

  capricorn-backend-prod:
    image: gitlab.gothamtechnologies.com:5050/production/capricorn/backend:latest
    container_name: capricorn-backend-prod
    restart: unless-stopped
    environment:
      - DATABASE_URL=postgresql://capricorn_user:capricorn_password@capricorn-postgres-prod:5432/capricorn_db
      - REDIS_URL=redis://capricorn-redis-prod:6379/0
      - ENVIRONMENT=production
    labels:
      # Hostname-based API routing
      - "traefik.enable=true"
      - "traefik.http.routers.capricorn-api.rule=Host(`cap.gothamtechnologies.com`) && PathPrefix(`/api`)"
      - "traefik.http.routers.capricorn-api.entrypoints=websecure"
      - "traefik.http.routers.capricorn-api.tls.certresolver=letsencrypt"
      - "traefik.http.services.capricorn-api.loadbalancer.server.port=8000"
      # IP-based API routing
      - "traefik.http.routers.capricorn-api-ip.rule=Host(`192.168.1.184`) && PathPrefix(`/api`)"
      - "traefik.http.routers.capricorn-api-ip.entrypoints=websecure"
      - "traefik.http.routers.capricorn-api-ip.tls=true"
    networks:
      - web
      - capricorn-network

  capricorn-postgres-prod:
    image: postgres:15.5-alpine
    container_name: capricorn-postgres-prod
    restart: unless-stopped
    environment:
      - POSTGRES_DB=capricorn_db
      - POSTGRES_USER=capricorn_user
      - POSTGRES_PASSWORD=capricorn_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database/init:/docker-entrypoint-initdb.d:ro  # ← Database init scripts
    networks:
      - capricorn-network  # NOT on web network (security)

  capricorn-redis-prod:
    image: redis:7.2.4-alpine
    container_name: capricorn-redis-prod
    restart: unless-stopped
    volumes:
      - redis_data:/data
    networks:
      - capricorn-network  # NOT on web network (security)

networks:
  web:
    external: true
  capricorn-network:
    driver: bridge

volumes:
  postgres_data:
  redis_data:
```

**Key Features:**
- Both hostname AND IP-based routing (for internal access)
- Database initialization via mounted SQL scripts
- Persistent volumes for postgres + redis
- Images from GitLab Container Registry
- Backend environment configured for production

**Deployment Command:**
```bash
cd /opt/capricorn
# Copy database init scripts first
scp -r /local/path/capricorn/database agamache@192.168.1.184:/opt/capricorn/
# Deploy
sudo docker compose up -d
```

### Proxmox Firewall Configuration

**VM Firewall:** ENABLED on vm-www-1

**Rules Configured (Proxmox Web UI):**

| Direction | Action | Source | Protocol | Dest Port | Comment |
|-----------|--------|--------|----------|-----------|---------|
| IN | ACCEPT | 192.168.1.0/24 | tcp | 22 | SSH (internal only) |
| IN | ACCEPT | (any) | tcp | 80 | HTTP |
| IN | ACCEPT | (any) | tcp | 443 | HTTPS |
| IN | DROP | (any) | (all) | (all) | Default deny |
| OUT | ACCEPT | (any) | (all) | (all) | Allow outbound |

**Security Result:**
- ✅ SSH only from internal LAN (192.168.1.x)
- ✅ HTTP/HTTPS from anywhere (internet)
- ❌ Cannot SSH from internet (blocked)
- ✅ Outbound: apt updates, docker pulls, Let's Encrypt validation

### Router Configuration (Verizon G3100)

**Port Forwarding Rules (configured by Andrew):**

| External Port | Internal IP | Internal Port | Protocol | Description |
|---------------|-------------|---------------|----------|-------------|
| 80 | 192.168.1.184 | 80 | TCP | WWW-HTTP |
| 443 | 192.168.1.184 | 443 | TCP | WWW-HTTPS |

**NO SSH port 22 forwarding** - internal access only!

**Router Access:** http://192.168.1.1 → Advanced → Port Forwarding

### DNS Configuration

**Dynamic DNS:** bullpup.ddns.net (NoIP.com)
- Managed by Verizon G3100 router (no DUC on VM needed)
- Auto-updates when public IP changes
- Points to: 108.6.178.182 (Verizon public IP)

**AWS Route53 (gothamtechnologies.com zone):**

| Name | Type | Value | TTL | Purpose |
|------|------|-------|-----|---------|
| cap | CNAME | bullpup.ddns.net | 300 | Capricorn PROD (local) |
| www | CNAME | bullpup.ddns.net | 300 | Splash page (local) |
| capricorn | A | (GCP IP) | 300 | Interview demos (unchanged) |

**Created by:** Andrew (manual task)

### SSL Certificates (Let's Encrypt)

**Method:** HTTP-01 challenge (automatic via Traefik)
- No AWS credentials needed
- Traefik handles verification via port 80
- Certificates stored in `/opt/traefik/acme.json`
- Auto-renewal every 60 days

**Certificates Issued:**
- ✅ cap.gothamtechnologies.com
- ✅ www.gothamtechnologies.com

**Verification:**
```bash
curl -I https://cap.gothamtechnologies.com
# Server: traefik
# SSL certificate valid (Let's Encrypt)
```

### GitLab CI/CD Pipeline Integration

**File:** `/home/agamache/DevShare/cursor-projects/unified_ui_DEV_PROD_GCP/capricorn/.gitlab-ci.yml`

**New Stage Added:** `deploy_prod`

**New Job:** `deploy_prod_local` (manual trigger on production branch)

```yaml
deploy_prod_local:
  stage: deploy_prod
  image: alpine:latest
  before_script:
    - apk add --no-cache openssh-client
    - eval $(ssh-agent -s)
    - echo "$SSH_PRIVATE_KEY" | tr -d '\r' | ssh-add -
    - mkdir -p ~/.ssh && chmod 700 ~/.ssh
    - ssh-keyscan -H 192.168.1.184 >> ~/.ssh/known_hosts
  script:
    - |
      ssh agamache@192.168.1.184 << 'EOF'
        cd /opt/capricorn
        docker login gitlab.gothamtechnologies.com:5050 -u root -p $CI_REGISTRY_PASSWORD
        docker compose pull
        docker compose up -d
        docker image prune -f
        echo "✅ Deployed to LOCAL PROD: https://cap.gothamtechnologies.com"
      EOF
  only:
    - production
  when: manual
  environment:
    name: production-local
    url: https://cap.gothamtechnologies.com
```

**Also kept:** `deploy_prod_gcp` job for GCP deployment (interviews)

**Result:** Two manual deployment buttons on production branch!

---

## TROUBLESHOOTING HISTORY (Critical Lessons Learned)

### Issue 1: HTTPS Timeout (8:00 PM - 8:45 PM)

**Symptoms:**
- HTTP worked (redirected to HTTPS)
- HTTPS timed out with "Gateway timeout"
- Tested from: workstation, laptop, vm-www-1 itself - ALL failed
- Traefik logs showed: "Creating server URL=http://172.19.0.5:80"

**Root Cause:**
- Capricorn docker-compose created its own network: `capricorn_capricorn-network` (172.19.0.0/16)
- Traefik was only on `web` network (172.18.0.0/16)
- **Traefik couldn't route to containers on different network!**
- Docker created `capricorn_capricorn-network` for postgres/redis isolation

**Debugging Steps:**
1. Checked Traefik logs: showed wrong IPs (172.19.x instead of 172.18.x)
2. Listed Docker networks: found TWO networks
3. Inspected network membership: Traefik not on capricorn network
4. Ran tcpdump: saw TCP handshake complete but no data returned

**Solution:**
```bash
# Connect Traefik to capricorn network
docker network connect capricorn_capricorn-network traefik

# Update docker-compose.yml permanently
cd /opt/traefik
# Edit docker-compose.yml to add:
networks:
  - web
  - capricorn_capricorn-network

# Restart Traefik
sudo docker compose restart
```

**Result:** HTTPS immediately worked! ✅

**Lesson:** Multi-container apps with custom networks require reverse proxy to join ALL networks.

### Issue 2: Database Relation Not Found (Earlier)

**Symptoms:**
- Frontend loaded but showed errors
- Backend logs: `relation "user_profile" does not exist`

**Root Cause:**
- Database initialization scripts not mounted
- Postgres started empty (no tables)

**Solution:**
```bash
# Copy database init scripts from local workstation
scp -r /local/capricorn/database agamache@192.168.1.184:/opt/capricorn/

# Update docker-compose.yml
volumes:
  - ./database/init:/docker-entrypoint-initdb.d:ro

# Recreate containers to force DB init
cd /opt/capricorn
sudo docker compose down -v  # -v removes volumes
sudo docker compose up -d
```

### Issue 3: NAT Hairpinning (Earlier)

**Symptoms:**
- External access worked (phone, VPN)
- Internal access failed (couldn't resolve cap.gothamtechnologies.com from LAN)

**Root Cause:**
- Verizon G3100 router doesn't support NAT loopback/hairpinning
- Internal clients can't reach external IP from inside LAN

**Solution:**
```bash
# Add local DNS override on workstation
echo "192.168.1.184 cap.gothamtechnologies.com" | sudo tee -a /etc/hosts
```

**Alternative:** Could use local DNS server (Pi-hole, unbound) for whole network

### Issue 4: Direct IP Access 404 (Earlier)

**Symptoms:**
- User wanted to type `192.168.1.184` in browser
- Traefik returned 404 (no route matched)

**Root Cause:**
- Traefik routes by hostname only (Host header)
- Browser sends `Host: 192.168.1.184` which didn't match any rules

**Solution:**
- Added IP-based routing labels to docker-compose.yml
- `traefik.http.routers.capricorn-ip.rule=Host(\`192.168.1.184\`)`
- Both frontend and backend routers

**Result:** Can now access via IP directly from internal network

---

## FINAL TESTING RESULTS

**External Access (from phone on cellular):**
- ✅ https://cap.gothamtechnologies.com → Capricorn loads
- ✅ https://www.gothamtechnologies.com → Splash page loads
- ✅ Valid SSL certificates (Let's Encrypt)
- ✅ HTTP redirects to HTTPS

**Internal Access (from LAN):**
- ✅ https://192.168.1.184 → Capricorn loads
- ✅ https://cap.gothamtechnologies.com → Works (with /etc/hosts entry)
- ⚠️ Certificate warning for IP (expected - cert is for hostname)

**Security Tests:**
- ✅ SSH from internet: Connection refused (blocked by Proxmox firewall)
- ✅ SSH from LAN: Works (192.168.1.0/24 allowed)
- ✅ nmap from external: Only ports 80, 443 open
- ✅ Internal services not exposed (GitLab, SonarQube)

**Performance:**
- ✅ Capricorn responsive (login, navigation)
- ✅ API calls fast (local network, no cloud latency)
- ✅ Database queries instant

---

## COST SAVINGS ACHIEVED

| Item | GCP (Before) | Local (After) | Savings |
|------|--------------|---------------|---------|
| Compute | ~$25-40/mo | $0 | $25-40/mo |
| Egress | ~$5-10/mo | $0 | $5-10/mo |
| Electricity | $0 | ~$2-3/mo | -$2-3/mo |
| **Total** | **~$30-50/mo** | **~$2-3/mo** | **~$30-45/mo** |

**Annual Savings:** ~$360-540 💰

**GCP Still Available:** Manual deploy button for interview demos

---

## COMMANDS REFERENCE

**Start/Stop Services:**
```bash
# Traefik
cd /opt/traefik && sudo docker compose up -d
sudo docker compose logs -f traefik

# Splash Page
cd /opt/splash && sudo docker compose up -d

# Capricorn
cd /opt/capricorn && sudo docker compose up -d
sudo docker compose logs -f frontend backend

# Stop everything
cd /opt/traefik && sudo docker compose down
cd /opt/splash && sudo docker compose down
cd /opt/capricorn && sudo docker compose down
```

**Debugging:**
```bash
# Check networks
docker network ls
docker network inspect web
docker network inspect capricorn_capricorn-network

# Check container IPs
docker ps
docker inspect <container> --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'

# Traefik dashboard
http://192.168.1.184:8080/dashboard/

# Check certificates
sudo cat /opt/traefik/acme.json | jq .
```

**Restart Entire Stack:**
```bash
# Correct order: stop Traefik last, start Traefik last
cd /opt/capricorn && sudo docker compose down
cd /opt/splash && sudo docker compose down
cd /opt/traefik && sudo docker compose down

cd /opt/splash && sudo docker compose up -d
cd /opt/capricorn && sudo docker compose up -d
cd /opt/traefik && sudo docker compose up -d
```

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
| `cap.gothamtechnologies.com` | CNAME | `bullpup.ddns.net` | Local Capricorn |
| `www.gothamtechnologies.com` | CNAME | `bullpup.ddns.net` | Splash page |
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

**From Proxmox console on vm-www-1 (SSH not available yet):**

```bash
# Download, make executable, and run
wget http://192.168.1.195/scripts/host_setup.sh
chmod +x host_setup.sh
./host_setup.sh
```

**Or one-liner:**
```bash
wget http://192.168.1.195/scripts/host_setup.sh && chmod +x host_setup.sh && ./host_setup.sh
```

**Note:** The main script automatically downloads all sub-scripts before running them.

**After reboot:** Run `update` from terminal to apply system updates.

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

### Task 9: Verify NoIP DDNS (Router-Managed)

**DDNS is handled by the Verizon G3100 router** - no client installation needed on vm-www-1!

**NoIP Hostname:** `bullpup.ddns.net` (existing, already configured on router)

**Verification Steps:**

```bash
# From DEV workstation, verify NoIP hostname resolves to your public IP:
dig bullpup.ddns.net +short

# Get your actual public IP:
curl -s ifconfig.me

# Both should match!
```

**If they don't match:**
1. Login to G3100 router (http://192.168.1.1)
2. Navigate to: Advanced → Dynamic DNS
3. Verify NoIP credentials and hostname are correct
4. Force an update or wait for automatic refresh

**Note:** Router DDNS is preferred because:
- Router is always on and connected
- Knows immediately when IP changes
- No additional software to maintain on VMs

### Task 10: Configure AWS Route53 (MANUAL - Andrew)

**⚠️ MANUAL TASK FOR ANDREW**

**In AWS Console → Route53 → gothamtechnologies.com hosted zone:**

**Add CNAME records:**

| Name | Type | Value | TTL |
|------|------|-------|-----|
| cap | CNAME | bullpup.ddns.net | 300 |
| www | CNAME | bullpup.ddns.net | 300 |

**Keep existing (unchanged):**
| Name | Type | Value | TTL |
|------|------|-------|-----|
| capricorn | A | (GCP IP) | 300 |

**TTL Note:** Using 300 seconds (5 min) for faster propagation during testing. Can increase later.

**Checklist:**
- [ ] Andrew: Create `cap` CNAME → `bullpup.ddns.net`
- [ ] Andrew: Create `www` CNAME → `bullpup.ddns.net`
- [ ] Verify with: `dig cap.gothamtechnologies.com` (should return CNAME to bullpup.ddns.net)

---

## Testing & Validation

### Pre-Deployment Checklist

- [ ] VM created and accessible via SSH (192.168.1.184) from internal network
- [ ] host_setup.sh completed successfully
- [ ] Docker running, can pull from GitLab registry
- [ ] Proxmox firewall rules in place (80, 443 open; SSH internal only)
- [ ] NoIP hostname (bullpup.ddns.net) showing correct public IP (router-managed)
- [ ] **Andrew:** Router port forwarding configured (80, 443 → .184)
- [ ] **Andrew:** Route53 CNAMEs created (cap, www → bullpup.ddns.net)

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
| NoIP hostname | bullpup.ddns.net | Jan 22, 2026 |
| NoIP DDNS updates | Router-managed (G3100), no VM client needed | Jan 22, 2026 |
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
| 4 | Install Traefik + create Docker network | AI | 🔲 |
| 5 | Deploy splash page container | AI | 🔲 |
| 6 | Configure Verizon G3100 port forwarding | Andrew | 🔲 |
| 7 | Verify NoIP DDNS (bullpup.ddns.net) | AI | 🔲 |
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
