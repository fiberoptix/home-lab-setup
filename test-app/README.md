# Test App - GitLab CI/CD Validation

**Purpose:** Simple test application to validate the GitLab CI/CD pipeline infrastructure.

---

## What This Tests

- ✅ GitLab project creation
- ✅ Git push/pull operations
- ✅ GitLab Runner job execution
- ✅ Docker image builds
- ✅ Container Registry push/pull
- ✅ SSH deployment to QA host
- ✅ End-to-end pipeline flow

---

## Application Stack

- **Web Server:** nginx:alpine
- **Content:** Static HTML splash page
- **Port:** 80 (mapped to 8080 on QA host)

---

## Pipeline Stages

### 1. Build Stage
- Uses `docker:24.0` image
- Builds Docker image from Dockerfile
- Tags with commit SHA and 'latest'

### 2. Push Stage
- Logs into Container Registry
- Pushes both image tags to registry
- URL: `gitlab.gothamtechnologies.com:5050/test-app`

### 3. Deploy Stage (Manual)
- SSHs to QA host (192.168.1.180)
- Pulls latest image from registry
- Stops/removes old container
- Runs new container on port 8080

---

## Local Testing

### Build and run locally:
```bash
cd test-app
docker build -t test-app .
docker run -d -p 8080:80 --name test-app test-app
```

### Test:
```bash
curl http://localhost:8080
# Or open in browser: http://localhost:8080
```

### Clean up:
```bash
docker stop test-app
docker rm test-app
```

---

## GitLab Setup

### 1. Create Project in GitLab
1. Go to http://192.168.1.181
2. Login as root
3. Click "New Project"
4. Project name: `test-app`
5. Visibility: Private
6. Initialize with README: No

### 2. Add Git Remote
```bash
cd /home/agamache/DevShare/cursor-projects/home-lab-setup/test-app
git init
git remote add gitlab http://gitlab.gothamtechnologies.com/root/test-app.git
```

### 3. Configure CI/CD Variables
In GitLab: Settings → CI/CD → Variables

Add these variables:
- `CI_REGISTRY_USER`: `root` (or your GitLab username)
- `CI_REGISTRY_PASSWORD`: Your GitLab password (masked)

### 4. Setup SSH Access to QA Host
Runner needs SSH key to deploy:
```bash
# On runner VM (192.168.1.182)
ssh-keygen -t ed25519 -C "gitlab-runner"
ssh-copy-id agamache@192.168.1.180
```

### 5. Push to GitLab
```bash
git add .
git commit -m "Initial commit: test app"
git push -u gitlab main
```

---

## Expected Results

### Build Stage:
```
✅ Building Docker image...
✅ Build complete!
```

### Push Stage:
```
✅ Logging into Container Registry...
✅ Pushing images to registry...
✅ Push complete!
```

### Deploy Stage:
```
✅ Deploying to QA host at 192.168.1.180...
✅ Deployment complete! App running at http://192.168.1.180:8080
```

---

## Validation Checklist

- [ ] Project created in GitLab
- [ ] Code pushed to GitLab
- [ ] Pipeline triggered automatically
- [ ] Build stage passes
- [ ] Push stage passes
- [ ] Image visible in Container Registry
- [ ] Deploy stage runs (manual trigger)
- [ ] App accessible at http://192.168.1.180:8080
- [ ] Page displays correctly with bounce animation

---

## Troubleshooting

### Pipeline fails at build stage:
- Check runner has Docker access
- Verify socket mount in runner config: `/var/run/docker.sock:/var/run/docker.sock`

### Pipeline fails at push stage:
- Check CI/CD variables are set (CI_REGISTRY_USER, CI_REGISTRY_PASSWORD)
- Verify registry is accessible: `docker login gitlab.gothamtechnologies.com:5050`

### Pipeline fails at deploy stage:
- Check SSH key is set up from runner to QA host
- Verify QA host has Docker installed
- Check insecure-registry config on QA host

### App doesn't display:
- Check container is running: `docker ps | grep test-app`
- Check logs: `docker logs test-app`
- Verify port 8080 is not in use: `netstat -tlnp | grep 8080`

---

## Next Steps

Once this test app pipeline works:
1. ✅ We know the infrastructure is solid
2. 🚀 We can confidently deploy Capricorn
3. 📊 We can add more stages (test, quality scan, etc.)

---

**Created:** January 11, 2026  
**Purpose:** Infrastructure validation for Phase 5 CI/CD testing

