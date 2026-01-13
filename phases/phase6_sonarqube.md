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
- [ ] Change admin password (set to: Powerme!1)
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
