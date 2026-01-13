# Phase 5: CI/CD Pipelines

**Status:** ✅ COMPLETE (Jan 11, 2026)  
**Depends On:** Phase 3 (GitLab Server), Phase 4 (GitLab Runner)  
**Goal:** Validate end-to-end CI/CD pipeline from code push to deployment

---

## Completion Summary

- **Test Project:** test-app (simple nginx container with HTML splash page)
- **Repository:** http://gitlab.gothamtechnologies.com/root/test-app
- **Pipeline Stages:** build → push → deploy_qa
- **Deployment Target:** 192.168.1.180:8080 (vm-kubernetes-1)
- **Status:** ✅ Full pipeline working end-to-end

**Test Results:**
- ✅ Build stage: Docker image creation successful (docker:27)
- ✅ Push stage: Image pushed to Container Registry
- ✅ Deploy stage: SSH deployment to QA host successful
- ✅ App accessible: http://192.168.1.180:8080

---

## Overview

Phase 5 validates the complete CI/CD infrastructure by creating a test application and deploying it through the entire pipeline. This proves that:
- GitLab can host projects
- Runner can execute jobs
- Docker builds work
- Container Registry accepts images
- SSH deployment to QA host works
- End-to-end automation is functional

---

## Test Application

### What We Built

**Location:** `/test-app/` in home-lab-setup repository

**Components:**
- `index.html` - Beautiful splash page with animation
- `Dockerfile` - nginx:alpine container
- `.gitlab-ci.yml` - 3-stage pipeline
- `README.md` - Complete setup instructions

**Application:**
- Web server: nginx:alpine
- Content: Static HTML with CSS animations
- Size: ~10MB Docker image
- Port: 80 (mapped to 8080 on host)

---

## Pipeline Configuration

### .gitlab-ci.yml Structure

```yaml
stages:
  - build
  - push
  - deploy

variables:
  IMAGE_NAME: gitlab.gothamtechnologies.com:5050/root/test-app
  IMAGE_TAG: $CI_COMMIT_SHORT_SHA
```

### Stage 1: Build

**Image:** `docker:27` (not docker:24.0 - API version mismatch)

**Process:**
1. Clone repository
2. Build Docker image with commit SHA tag
3. Build Docker image with 'latest' tag

**Key Learning:** Docker API version 1.44+ required. docker:27 works, docker:24.0 fails with "client version too old" error.

### Stage 2: Push

**Image:** `docker:27`

**Process:**
1. Login to Container Registry using CI/CD variables
2. Push image with commit SHA tag
3. Push image with 'latest' tag

**Required CI/CD Variables:**
- `CI_REGISTRY_USER` = `root` (visible, username not sensitive)
- `CI_REGISTRY_PASSWORD` = `[See PASSWORDS.md]` (masked)

### Stage 3: Deploy (Manual)

**Image:** `alpine:latest`

**Process:**
1. Install openssh-client
2. Load SSH private key from CI/CD variable
3. SSH to QA host (192.168.1.180)
4. Login to registry
5. Pull latest image
6. Stop/remove old container
7. Run new container on port 8080

**Required CI/CD Variables:**
- `SSH_PRIVATE_KEY` - Runner's private key for SSH access

**Manual Trigger:** Prevents automatic deployment, requires human approval.

---

## Infrastructure Setup

### SSH Key Configuration

**Problem:** Pipeline jobs run in Docker containers, don't have access to host SSH keys.

**Solution:**
1. Generated SSH key on runner host (192.168.1.182):
   ```bash
   ssh-keygen -t ed25519 -C "gitlab-runner"
   ```

2. Copied public key to QA host (192.168.1.180):
   ```bash
   ssh-copy-id agamache@192.168.1.180
   ```

3. Added private key as CI/CD variable (`SSH_PRIVATE_KEY`)

4. Pipeline loads key into ssh-agent in deploy stage

### Container Registry Access

**QA Host Configuration:**
Registry uses HTTP (not HTTPS), requires insecure-registry config:

```json
// /etc/docker/daemon.json on QA host
{"insecure-registries": ["gitlab.gothamtechnologies.com:5050"]}
```

This was already configured via `setup_docker.sh` script.

---

## Issues Encountered & Solutions

### Issue 1: Docker API Version Mismatch

**Error:**
```
Error response from daemon: client version 1.43 is too old. 
Minimum supported API version is 1.44
```

**Cause:** `docker:24.0` image too old for runner's Docker daemon.

**Solution:** Changed to `docker:27` in `.gitlab-ci.yml`

### Issue 2: Registry Authentication

**Error:**
```
error: exit code 1 (docker login failed)
```

**Cause:** CI/CD variables not set for registry credentials.

**Solution:** Added `CI_REGISTRY_USER` and `CI_REGISTRY_PASSWORD` variables in GitLab project settings.

### Issue 3: SSH Permission Denied

**Error:**
```
Permission denied (publickey,password)
```

**Cause:** Pipeline containers don't have access to host SSH keys.

**Solution:** 
1. Added `SSH_PRIVATE_KEY` as CI/CD variable
2. Modified pipeline to load key into ssh-agent before deployment

---

## Verification Checklist

- [x] Test project created in GitLab
- [x] Code pushed successfully via HTTP
- [x] Pipeline triggers automatically on push
- [x] Build stage passes
- [x] Docker image created successfully
- [x] Push stage passes
- [x] Image visible in Container Registry
- [x] Deploy stage runs (manual trigger)
- [x] App deploys to QA host
- [x] Container running on port 8080
- [x] App accessible via browser
- [x] Page displays correctly with animations

---

## CI/CD Variables Reference

All variables configured in: **GitLab → Settings → CI/CD → Variables**

| Variable | Value | Visibility | Purpose |
|----------|-------|------------|---------|
| `CI_REGISTRY_USER` | `root` | Visible | Registry login username |
| `CI_REGISTRY_PASSWORD` | `[See PASSWORDS.md]` | Masked | Registry login password |
| `SSH_PRIVATE_KEY` | (ed25519 private key) | Visible* | SSH access to QA host |

*Note: SSH_PRIVATE_KEY couldn't be masked (format restrictions), but is only visible to project maintainers.

---

## Test Results

### Build Stage
```
✅ Building Docker image...
✅ Successfully tagged gitlab.gothamtechnologies.com:5050/root/test-app:ea5967a
✅ Successfully tagged gitlab.gothamtechnologies.com:5050/root/test-app:latest
✅ Build complete!
Duration: ~15 seconds
```

### Push Stage
```
✅ Logging into Container Registry...
✅ Login Succeeded
✅ Pushing gitlab.gothamtechnologies.com:5050/root/test-app:ea5967a
✅ Pushing gitlab.gothamtechnologies.com:5050/root/test-app:latest
✅ Push complete!
Duration: ~3 seconds
```

### Deploy Stage
```
✅ Deploying to QA host at 192.168.1.180...
✅ Login Succeeded (registry)
✅ Pulling image...
✅ Container stopped and removed
✅ Container started: test-app
✅ Deployment complete! App running at http://192.168.1.180:8080
Duration: ~5 seconds
```

---

## Application Access

### Local Network Access
```
http://192.168.1.180:8080
```

### Container Status
```bash
# On QA host
docker ps | grep test-app
# Shows: test-app container running, mapping 8080:80
```

### Test Page Features
- Purple gradient background
- Bouncing rocket emoji animation
- Success badges for each pipeline stage
- Responsive design
- Modern glassmorphism UI

---

## Next Steps

After Phase 5 complete → **Ready for Production Applications**

**Options:**
1. **Deploy Capricorn** - Use working pipeline for real application
2. **Add Quality Gates** - Integrate SonarQube (Phase 6)
3. **Add Monitoring** - Prometheus + Grafana (Phase 7)
4. **Add HTTPS** - Traefik + Let's Encrypt (Phase 8)

---

## Key Learnings

### What Works
✅ HTTP git operations (embedded credentials)  
✅ Docker socket mount approach  
✅ docker:27 image (not docker:24.0)  
✅ SSH key via CI/CD variables  
✅ Manual deploy stage prevents accidents  
✅ Insecure registry config on all Docker hosts  

### What Doesn't Work
❌ Docker-in-Docker (DIND services)  
❌ docker:24.0 image (API too old)  
❌ SSH keys from host (containers isolated)  

### Best Practices Established
- Use manual trigger for deploy stage
- Store sensitive data in CI/CD variables
- Use specific Docker image versions (not 'latest')
- Test with simple app before production
- Document exact error messages and solutions

---

## Related Files

- `/test-app/` - Test application source code
- `/phases/phase3_gitlab_server.md` - GitLab server setup
- `/phases/phase4_gitlab_runner.md` - Runner configuration
- `/test-app/README.md` - Complete test app documentation

---

**Phase 5 Complete:** January 11, 2026  
**Infrastructure Status:** Ready for production application deployment  
**Next Phase:** Deploy Capricorn or add quality/monitoring tools

