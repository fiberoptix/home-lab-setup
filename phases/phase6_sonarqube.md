# Phase 6: SonarQube Code Quality Integration

**Status:** ✅ COMPLETE  
**Depends On:** Phase 5 (CI/CD Pipelines)  
**Goal:** Add automated code quality and security scanning to CI/CD pipeline
**Completed:** January 13, 2026

---

## Overview

SonarQube will add a quality gate to the CI/CD pipeline, automatically scanning code for:
- **Bugs:** Null pointers, logic errors, type mismatches
- **Vulnerabilities:** SQL injection, XSS, hardcoded secrets, insecure dependencies
- **Code Smells:** Complexity, duplications, maintainability issues
- **Coverage:** Test coverage metrics (if tests exist)

**Philosophy:** Catch issues before they reach QA, enforce code standards consistently.

---

## Sub-Phases

### Phase 6a: Create SonarQube VM

**VM Specifications:**

| Property | Value | Reasoning |
|----------|-------|-----------|
| **Hostname** | sonarqube.gothamtechnologies.com | Descriptive |
| **IP Address** | 192.168.1.183 | Sequential allocation (.180s series) |
| **RAM** | 6GB | SonarQube minimum (can spike to 8GB) |
| **CPU** | 4 cores | Parallel scanning |
| **Disk** | 30GB | Database + analysis cache + growth room |
| **Storage Pool** | vm-critical (rpool2, ZFS mirror) | Data persistence important |
| **OS** | Ubuntu 24.04 LTS Server | Consistent with other VMs |
| **Access** | Internal only (Tailscale VPN) | Security |

**Why vm-critical?**
- SonarQube database contains project history
- Quality metrics tracked over time
- Losing data means losing historical trends

**Tasks:**
- [ ] Log into Proxmox UI (https://192.168.1.150:8006)
- [ ] Create new VM:
  - VM ID: 184
  - Name: sonarqube
  - ISO: Ubuntu 24.04 Server
  - Disk: 30GB on vm-critical (rpool2)
  - CPU: 4 cores
  - RAM: 6144 MB (6GB)
  - Network: vmbr0
- [ ] Start VM and complete Ubuntu installation
- [ ] Set static IP: 192.168.1.183

### Phase 6b: Base OS Setup

**Tasks:**
- [ ] Run master setup script:
  ```bash
  wget http://192.168.1.195/scripts/host_setup.sh
  bash host_setup.sh
  ```
  This installs: SSH, passwordless sudo, Docker, Git, NAS mount, insecure-registry config
  
- [ ] Verify SSH access from DEV machine:
  ```bash
  ssh agamache@192.168.1.183
  ```
  
- [ ] Set hostname:
  ```bash
  sudo hostnamectl set-hostname sonarqube
  echo "127.0.1.1 sonarqube sonarqube.gothamtechnologies.com" | sudo tee -a /etc/hosts
  ```

### Phase 6c: Install SonarQube

**Approach:** Docker container (simpler than manual install)

**Tasks:**
- [ ] Create directory for persistent data:
  ```bash
  sudo mkdir -p /opt/sonarqube/{data,logs,extensions}
  sudo chown -R 1000:1000 /opt/sonarqube
  ```

- [ ] Run SonarQube container:
  ```bash
  docker run -d \
    --name sonarqube \
    --restart unless-stopped \
    -p 9000:9000 \
    -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
    -v /opt/sonarqube/data:/opt/sonarqube/data \
    -v /opt/sonarqube/logs:/opt/sonarqube/logs \
    -v /opt/sonarqube/extensions:/opt/sonarqube/extensions \
    sonarqube:lts-community
  ```

- [ ] Wait for initialization (~2 minutes)

- [ ] Check logs:
  ```bash
  docker logs -f sonarqube
  # Wait for "SonarQube is operational"
  ```

### Phase 6d: Initial SonarQube Configuration

**Tasks:**
- [ ] Access SonarQube UI: http://192.168.1.183:9000
- [ ] Login with default credentials: admin / admin
- [ ] Change admin password (set to: <See PASSWORDS.md>)
- [ ] Skip tutorial (we'll configure manually)

### Phase 6e: Create Capricorn Project in SonarQube

**Tasks:**
- [ ] Click "Create Project" → "Manually"
- [ ] Project settings:
  - Project key: `capricorn`
  - Display name: `Capricorn`
  - Main branch: `develop`
- [ ] Click "Set Up"
- [ ] Choose "Use existing token" → "Generate Token"
  - Token name: `gitlab-ci`
  - Type: Project Analysis Token
  - Expires: Never
  - **Save this token!** (e.g., `squ_a1b2c3d4e5f6...`)

### Phase 6f: Configure GitLab CI/CD Integration

**Add CI/CD Variables to GitLab:**

Go to: http://gitlab.gothamtechnologies.com/production/capricorn/-/settings/ci_cd

Add these variables:

| Variable | Value | Visibility | Purpose |
|----------|-------|------------|---------|
| `SONAR_HOST_URL` | `http://192.168.1.183:9000` | Visible | SonarQube server |
| `SONAR_TOKEN` | (token from 6e) | Masked | Authentication |

### Phase 6g: Add SonarQube Stage to Pipeline

**Modify `.gitlab-ci.yml`:**

Add new stage and job:

```yaml
stages:
  - build
  - push
  - scan        # NEW STAGE
  - deploy_qa
  - deploy_gcp

# Add after push_images job:
sonar_scan:
  stage: scan
  image: sonarsource/sonar-scanner-cli:latest
  tags:
    - docker
  variables:
    SONAR_USER_HOME: "${CI_PROJECT_DIR}/.sonar"
    GIT_DEPTH: "0"  # Full history for better analysis
  script:
    - sonar-scanner
      -Dsonar.projectKey=capricorn
      -Dsonar.sources=backend,frontend/src
      -Dsonar.host.url=$SONAR_HOST_URL
      -Dsonar.login=$SONAR_TOKEN
      -Dsonar.python.version=3.11
      -Dsonar.javascript.node.maxspace=4096
  only:
    - develop
    - production
  allow_failure: true  # Don't block deployment initially
```

**Pipeline Flow Becomes:**
```
build → push → scan → deploy
```

### Phase 6h: Configure Quality Gates

**In SonarQube UI:**

- [ ] Go to Quality Gates
- [ ] Use default "Sonar way" gate, or customize:
  - Bugs: > 0 on new code = Fail
  - Vulnerabilities: > 0 on new code = Fail
  - Code Smells: > 10 on new code = Warning
  - Coverage: < 80% = Warning
  - Duplications: > 3% = Warning

**Optional:** Start with `allow_failure: true` in pipeline, then change to `allow_failure: false` once baseline is clean.

---

## Testing Approach

### Phase 6i: Test the Integration

**Test 1: Successful Scan**
- [ ] Push clean code to develop branch
- [ ] Watch pipeline: build → push → scan → deploy_qa
- [ ] Verify SonarQube shows results
- [ ] Check quality gate passes

**Test 2: Failed Quality Gate (Intentional)**
- [ ] Add intentional bug (e.g., `x = 1/0` in Python)
- [ ] Push to develop
- [ ] Verify scan detects issue
- [ ] Verify pipeline behavior (fails or warns based on allow_failure)
- [ ] Fix the bug
- [ ] Verify pipeline passes

**Test 3: View Reports**
- [ ] Access SonarQube UI
- [ ] Navigate to Capricorn project
- [ ] Review: Issues, Security Hotspots, Code Smells
- [ ] Verify AI can read reports (SSH or API)

---

## Architecture Integration

### DNS Setup (Optional for Now)

Add to local `/etc/hosts` on DEV machine:
```
192.168.1.183  sonarqube sonarqube.gothamtechnologies.com
```

Or AWS Route53 (internal only):
- Type: A
- Name: sonarqube
- Value: 192.168.1.183

### Tailscale VPN Access

**Future Enhancement:**
- [ ] Install Tailscale on SonarQube VM
- [ ] Access remotely via VPN: http://sonarqube:9000
- [ ] Keep internal (not publicly accessible)

---

## Decisions Made (January 12, 2026)

### **Deployment Strategy:**

**Q1: Quality Gate Enforcement** ✅ DECIDED
- **Answer:** Learning mode (`allow_failure: true`)
- **Reason:** First time with SonarQube, see what it finds
- **Plan:** Fix baseline issues, then switch to strict mode

**Q2: Scan Scope** ✅ DECIDED
- **Answer:** Scan both develop AND production branches
- **Reason:** Consistency, catch issues everywhere

**Q3: Integration Timing** ✅ DECIDED
- **Answer:** test-app first, THEN Capricorn
- **Reason:** Learn the workflow with simple project first
- **Approach:** 
  1. Add scan stage to test-app/.gitlab-ci.yml
  2. Verify it works, learn the reports
  3. Copy working config to Capricorn

### **VM Configuration:**

**Q4: Storage Size** ✅ DECIDED
- **Answer:** 30GB disk
- **Reason:** Room to grow, better safe than sorry

**Q5: Scan Focus** ✅ DECIDED
- **Answer:** All types (Security + Bugs + Code Quality)
- **Reason:** Comprehensive scan, it's free!

**Q6: Access Method** ✅ DECIDED
- **Answer:** Access via IP (192.168.1.183:9000)
- **Reason:** Simple, DNS can be added later if needed

---

## Success Criteria

- [ ] SonarQube VM created and accessible
- [ ] SonarQube container running
- [ ] Can login to web UI
- [ ] Capricorn project created in SonarQube
- [ ] Pipeline includes scan stage
- [ ] First successful scan completes
- [ ] Quality gate evaluated (pass or fail)
- [ ] AI can access reports to fix issues
- [ ] Issues visible in SonarQube UI

---

## Validation Checklist

**Infrastructure:**
- [ ] VM responding to ping
- [ ] SSH access working
- [ ] Docker running
- [ ] SonarQube container healthy
- [ ] Port 9000 accessible from DEV machine

**SonarQube:**
- [ ] Web UI loads
- [ ] Admin login works
- [ ] Project exists
- [ ] Token generated

**Pipeline Integration:**
- [ ] Scan stage added to .gitlab-ci.yml
- [ ] CI/CD variables configured
- [ ] Pipeline runs scan stage
- [ ] Results appear in SonarQube
- [ ] Quality gate evaluated

**AI Access:**
- [ ] Can read reports (via API or SSH)
- [ ] Can identify issues from scan
- [ ] Can fix code based on findings

---

## Resource Usage (Expected)

| Resource | Idle | During Scan |
|----------|------|-------------|
| RAM | ~2-3GB | ~5-6GB |
| CPU | ~5% | ~80%+ |
| Disk | ~2GB initial | Growing with history |

**Note:** Scans are temporary CPU spikes (~30-60 seconds), then back to idle.

---

## Troubleshooting (Pre-emptive)

### SonarQube Won't Start
```bash
# Check logs
docker logs sonarqube

# Common issue: Insufficient memory
# Solution: Increase VM RAM to 8GB if needed
```

### Pipeline Scan Fails
```bash
# Check sonar-scanner can reach SonarQube
curl http://192.168.1.183:9000/api/system/status

# Check CI/CD variables are set
# Verify token hasn't expired
```

### Quality Gate Always Fails
```bash
# Initial scan will find many issues
# Options:
#   1. Set allow_failure: true temporarily
#   2. Fix issues incrementally
#   3. Adjust quality gate thresholds
```

---

## Phase 6j: PostgreSQL Migration (Optional Enhancement)

**Status:** 📋 PLANNED (Not yet implemented)  
**Priority:** Low (H2 embedded database works fine for 2-5 projects)  
**When to Do This:** If you add 5+ projects, need historical data preservation, or upgrade SonarQube frequently

### Why PostgreSQL?

**Current Setup (H2 Embedded Database):**
- ✅ Works perfectly for evaluation/home lab
- ✅ Zero configuration required
- ❌ May lose data on major version upgrades (26.x → 27.x)
- ❌ No export/import capability
- ❌ Not production-ready

**With PostgreSQL:**
- ✅ Automatic schema migrations on upgrades
- ✅ Guaranteed data preservation across all upgrades
- ✅ Production-ready configuration
- ✅ Better performance at scale (50+ projects)
- ❌ Requires ~30 minutes setup time
- ❌ Additional container to manage

### When to Migrate?

**Keep H2 if:**
- You have 2-5 projects only
- This is primarily for learning
- You're okay recreating projects after major upgrades (~15 min work)
- You don't need long-term historical trends

**Switch to PostgreSQL if:**
- You have 5+ projects
- Historical scan data/trends are important
- You plan to upgrade SonarQube frequently
- You want production-ready configuration

### Implementation Steps

#### Step 1: Backup Current Configuration

```bash
# SSH to SonarQube VM
ssh agamache@192.168.1.183

# Document current projects and settings
docker exec sonarqube curl -u admin:<See PASSWORDS.md> \
  http://localhost:9000/api/projects/search | jq . > ~/sonarqube_projects.json

# Note: Can't migrate H2 data to PostgreSQL - will need to recreate projects
```

#### Step 2: Deploy PostgreSQL Container

```bash
# Create PostgreSQL data directory
sudo mkdir -p /opt/sonarqube/postgres
sudo chown -R 999:999 /opt/sonarqube/postgres

# Run PostgreSQL container
docker run -d \
  --name sonarqube-db \
  --restart unless-stopped \
  -e POSTGRES_USER=sonarqube \
  -e POSTGRES_PASSWORD=<See PASSWORDS.md> \
  -e POSTGRES_DB=sonarqube \
  -v /opt/sonarqube/postgres:/var/lib/postgresql/data \
  postgres:15-alpine

# Wait for PostgreSQL to start
sleep 10

# Verify PostgreSQL is running
docker logs sonarqube-db | grep "ready to accept connections"
```

#### Step 3: Reconfigure SonarQube to Use PostgreSQL

```bash
# Stop and remove existing SonarQube container
docker stop sonarqube
docker rm sonarqube

# OPTIONAL: Backup old H2 database (just in case)
sudo mv /opt/sonarqube/data /opt/sonarqube/data.h2.backup
sudo mkdir -p /opt/sonarqube/data
sudo chown -R 1000:1000 /opt/sonarqube/data

# Start new SonarQube container with PostgreSQL
docker run -d \
  --name sonarqube \
  --restart unless-stopped \
  --link sonarqube-db:db \
  -p 9000:9000 \
  -e SONAR_JDBC_URL=jdbc:postgresql://db:5432/sonarqube \
  -e SONAR_JDBC_USERNAME=sonarqube \
  -e SONAR_JDBC_PASSWORD=<See PASSWORDS.md> \
  -v /opt/sonarqube/data:/opt/sonarqube/data \
  -v /opt/sonarqube/logs:/opt/sonarqube/logs \
  -v /opt/sonarqube/extensions:/opt/sonarqube/extensions \
  sonarqube:community

# Wait for SonarQube to initialize with PostgreSQL
docker logs -f sonarqube
# Watch for: "SonarQube is operational"
```

#### Step 4: Recreate Projects

**For test-app:**
1. Login to http://192.168.1.183:9000 (admin / <See PASSWORDS.md>)
2. Create Project → Manually
   - Project key: `test-app`
   - Display name: `Test App`
3. Generate token: `gitlab-ci`
4. Update GitLab CI/CD variable `SONAR_TOKEN` with new token

**For Capricorn:**
1. Create Project → Manually
   - Project key: `capricorn`
   - Display name: `Capricorn`
   - Main branch: `develop`
2. Generate token: `gitlab-ci`
3. Update Capricorn's GitLab CI/CD variable `SONAR_TOKEN` with new token

#### Step 5: Verify Migration

```bash
# Check PostgreSQL connection from SonarQube
docker exec sonarqube-db psql -U sonarqube -c "\dt"
# Should show SonarQube tables

# Check SonarQube logs for any errors
docker logs sonarqube | grep -i error

# Trigger pipeline runs for both projects
# Verify scans complete successfully
```

#### Step 6: Test Upgrade Path

```bash
# Simulate a future upgrade (without actually upgrading)
# This verifies PostgreSQL is configured correctly

# Check current version
docker exec sonarqube curl -s http://localhost:9000/api/system/status | jq .version

# Backup PostgreSQL data
docker exec sonarqube-db pg_dump -U sonarqube sonarqube > /tmp/sonarqube_backup.sql

# When ready to upgrade in the future:
# 1. Stop SonarQube: docker stop sonarqube
# 2. Pull new image: docker pull sonarqube:community
# 3. Remove old container: docker rm sonarqube
# 4. Start new container (same command as Step 3)
# 5. SonarQube will auto-migrate PostgreSQL schema
# 6. All data preserved!
```

### Configuration Updates

**Update MEMORY.md:**
```markdown
SonarQube (.183):
- Database: PostgreSQL 15 (container: sonarqube-db)
- Projects: test-app, capricorn
- No more embedded database warning!
```

**Update credentials file:**
```
PostgreSQL (sonarqube-db):
- User: sonarqube
- Password: <See PASSWORDS.md>
- Database: sonarqube
- Port: 5432 (internal to Docker network)
```

### Resource Impact

**Additional Resources Required:**

| Resource | PostgreSQL | Total (SonarQube + PostgreSQL) |
|----------|------------|--------------------------------|
| RAM | ~100-200MB | ~3-4GB idle, ~6GB during scans |
| CPU | ~1-2% idle | Negligible impact |
| Disk | ~500MB-2GB | +500MB-2GB |

**Note:** PostgreSQL is very lightweight - minimal impact on VM resources.

### Rollback Plan

If PostgreSQL causes issues, rollback to H2:

```bash
# Stop and remove PostgreSQL-based setup
docker stop sonarqube sonarqube-db
docker rm sonarqube sonarqube-db

# Restore H2 backup
sudo rm -rf /opt/sonarqube/data
sudo mv /opt/sonarqube/data.h2.backup /opt/sonarqube/data

# Start original SonarQube container (without PostgreSQL)
docker run -d \
  --name sonarqube \
  --restart unless-stopped \
  -p 9000:9000 \
  -v /opt/sonarqube/data:/opt/sonarqube/data \
  -v /opt/sonarqube/logs:/opt/sonarqube/logs \
  -v /opt/sonarqube/extensions:/opt/sonarqube/extensions \
  sonarqube:community
```

### Time Estimate

- **Setup:** 30 minutes
- **Testing:** 15 minutes
- **Total:** ~45 minutes

### Success Criteria

- [ ] PostgreSQL container running
- [ ] SonarQube connects to PostgreSQL (no embedded DB warning)
- [ ] Projects recreated (test-app, capricorn)
- [ ] New tokens generated and updated in GitLab
- [ ] Pipelines scan successfully
- [ ] Results visible in SonarQube UI
- [ ] Database persists after SonarQube container restart

---

## Next Phase

After SonarQube working → **Phase 7: Monitoring Stack** (Prometheus + Grafana)

---

## Related Files

- `/phases/phase5_ci_cd_pipelines.md` - CI/CD foundation (prerequisite)
- `/phases/phase7_monitoring.md` - Monitoring stack (next)
- `/proxmox/Home_Lab_Proxmox_Design.md` - Overall architecture

---

**Created:** January 12, 2026  
**Ready for Review:** Yes - awaiting Andrew's input on questions above  
**Estimated Time:** 1-2 hours total (VM creation + setup + integration + testing)
