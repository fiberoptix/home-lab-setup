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

---

## Closing record — demoted from `current_phase.md` (Aug 24, 2026)

Copied verbatim from a "Key Achievements" section that sat at the bottom of `current_phase.md` for
seven months. Preserved because the **DEV/QA/GCP definition below was recorded nowhere else** —
`grep` found it in no other phase file and not in `MEMORY.md`.

**Complete CI/CD Infrastructure:**
- ✅ GitLab Server verified (git push/pull, Container Registry)
- ✅ GitLab Runner verified (Docker builds, registry push, SSH deploy)
- ✅ Test app pipeline working (validation complete)
- ✅ **Capricorn pipeline working** (production application deployed!)

**Deployment Clarity Established:**
- **DEV** = Local workstation development
- **QA** = vm-kubernetes-1 @ 192.168.1.180 (automated CI/CD)
- **GCP** = Google Cloud Platform (real production)

🚨 **The QA line above is HISTORICALLY accurate and CURRENTLY WRONG — that is why it was worth
deleting from `current_phase.md` rather than leaving it there.** As of **Aug 20, 2026** `.180` is
**VMID 180, `vm-docker-qa-1`**, running plain `docker compose`, **not Kubernetes and not Swarm**. The
misnamed `vm-kubernetes-1` was VMID 200, was cloned to this one, and is stopped awaiting destroy.
⛔ **The only Kubernetes in this lab is k3s on VM 186.** `MEMORY.md` → *IPs & HOSTS* is authoritative.

⭐ **Why this one mattered more than its size.** A stale *fact* is a nuisance; this was a stale
**definition of the environments**, sitting under a heading that reads as current reference. Anyone
reading "QA = vm-kubernetes-1" would go looking for a Kubernetes QA box that has not existed since
August, and `MEMORY.md` carries an explicit prohibition against exactly that inference. Same shape as
cross-phase rule 2 — *a superseded directive in a history log is more dangerous than a stale fact,
because a future session can act on it.*

**One more date from the same demoted section, also recorded nowhere else:**
**January 8, 2026** — the GitHub repository was set up and published, and the hardware specs and
documentation were updated. (The dual-remote GitHub-safe / GitLab-full split came later, June 18
2026 — see `MEMORY.md` → *HOME-LAB-SETUP REPO*.)

**Also deleted in the same pass, and deliberately not preserved:**
- A **"Next Steps"** section still offering *"Phase 7 Options — Option A: Monitoring Stack
  (Prometheus + Grafana), Option B: Traefik + SSL"* as an open choice. **Option B was chosen and
  built**; Traefik has been live on `.184` since January (120 mentions in `phase7_local_www.md`).
  📌 The only part not superseded: **Prometheus/Grafana was never built and is still unbuilt** — the
  one live idea in that section, noted here so the road-not-taken survives the deletion.
- A **"Quick Reference"** VM table listing 4 hosts, labelling `.180` as *"QA/K8s"*. The lab has 9.
  A wrong duplicate of `MEMORY.md` → *IPs & HOSTS*.
- A **"Blockers"** section reading *"None. Phase 6 complete, ready for Phase 7!"* — stale by ten
  phases; Phase 17 is current.

---

## The build session itself — demoted from `current_phase.md` (Aug 24, 2026)

From *"Completed Previous Session (Jan 11, 2026 — Morning Session)"*, the **oldest block in
`current_phase.md`**. Five of its items were in no other file.

**GitHub repo published (9:00 AM):** `home-lab-setup` to GitHub with a README carrying the hardware
specs; refined several times over **8 commits** (hardware cost, Z8 G4, rpool naming).

**test-app pipeline (10:00–11:30 AM):** nginx + animated HTML splash, three stages
**build → push → deploy**, CI/CD variables and deploy SSH keys configured.
✅ Deployed to `http://192.168.1.180:8080` by pipeline.

**Capricorn CI/CD (11:45 AM–1:35 PM):** dual-remote (GitHub + GitLab), the **`production` group**
created in GitLab, and the branch strategy that still governs the project — **`develop` → QA,
`production` → GCP**. ✅ QA auto-deploy to `http://192.168.1.180:5001`; ✅ GCP deploy as a **manual** trigger on
`production`, reaching **`http://capricorn.gothamtechnologies.com`**. The pipeline installs
`terraform`, `gcloud`, `kubectl` and `docker buildx` itself.
⚠️ **That GCP hostname is still live and is NOT the primary any more** — Phase 7 moved production to
`.184` behind `cap.gothamtechnologies.com`, leaving `capricorn.*` as the on-demand GCP instance.

🚨 **The `prod` → `qa` refactoring, and why the filenames look the way they do.** Everything named
*prod* that actually meant *QA* was renamed in one pass: `run-prod.sh` → **`run-qa.sh`**,
`docker-compose.prod.yml` → **`docker-compose.qa.yml`**, `Dockerfile.*.prod` → **`Dockerfile.*.qa`**,
and the strings *"PROD Environment"* → *"QA Environment (192.168.1.180)"*. A separate
`docker-compose.qa.deploy.yml` was added for registry-based deploys.
⭐ **Worth knowing before touching Capricorn:** a `.qa` suffix there is not a variant of prod, it is
the *renamed* prod, done because the old naming actively misled. ⚠️ This predates the real
PROD-local server (`.184`, Phase 7) by ten days — so **"prod" in Capricorn now means `.184`, and
`.qa` means `.180`**, and any file still saying `prod` in a Phase-5-era context means QA.

⚠️ **The gotcha that cost real time: `.gitignore` was blocking `lib/`**, which silently excluded
**four `lib/api-client.ts` API files** from the repo. The build failed on missing modules that were
present locally. ⭐ **A `.gitignore` pattern broad enough to catch a source directory fails at
BUILD time on the runner and never on the developer's machine** — the files are right there when you
look. Same family as the later `smb_credentials` rules: a path-shaped rule catching more than intended.

**Eleven issues resolved that day**, kept because the list is a fair picture of what a first pipeline
actually costs: Docker API mismatch (`docker:24.0` → **`docker:27`**); registry auth via CI/CD
variables; SSH key deployment from runner to QA host; YAML nested-string syntax; the missing
`lib/api-client.ts` files; SSH key *format* inside a CI/CD variable; the PROD→QA naming confusion;
build stages not running on the `production` branch; installing terraform/gcloud/kubectl on Alpine;
creating the GCP service-account key file from a variable; and `git` missing for `docker buildx`
metadata.

