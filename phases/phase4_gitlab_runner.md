# Phase 4: GitLab Runner

**Status:** ✅ COMPLETE & VERIFIED (Jan 11, 2026)  
**Depends On:** Phase 3 (GitLab Server)  
**Goal:** Install GitLab Runner with Docker executor for CI/CD pipelines

---

## Completion Summary

- **VM:** vm-gitrun-1 @ 192.168.1.182
- **Runner Name:** gitlab-runner-1 (ID #2, token prefix quIskojI)
- **Version:** 18.6.6
- **Tags:** docker, linux, build
- **Status:** Online, runs untagged jobs

**Test Results:**
- ✅ test-job (alpine) - passes
- ❌ build-docker (dind) - fails (DIND config issue, not blocking)

**Note:** Standard jobs work. Docker-in-Docker services need more config. Use socket mount for Docker access.

---

## Overview

GitLab Runner executes CI/CD jobs defined in `.gitlab-ci.yml` files. Using Docker executor, it can:
- Build Docker images
- Run tests in isolated containers
- Deploy to QA (vm-kubernetes-1) and PROD (AWS/GCP)

---

## VM Specifications

| Property | Value |
|----------|-------|
| **Hostname** | gitrun.gothamtechnologies.com |
| **IP Address** | 192.168.1.182 |
| **RAM** | 16GB |
| **CPU** | 8 cores |
| **Disk** | 100GB |
| **Storage Pool** | vm-ephemeral (ZFS stripe - fast, no redundancy) |
| **OS** | Ubuntu 24.04 LTS Server |
| **Access** | Internal only |

**Why vm-ephemeral?** Runner data is disposable - builds are temporary. Speed > redundancy.

---

## Sub-Phases

### Phase 4a: Create VM in Proxmox
- [x] Log into Proxmox UI (https://192.168.1.150:8006)
- [x] Create new VM:
  - VM ID: 182 (matches IP)
  - Name: vm-gitrun-1
  - ISO: Ubuntu 24.04 Desktop
  - Disk: 100GB on vm-ephemeral
  - CPU: 8 cores
  - RAM: 16384 MB (16GB)
  - Network: vmbr0
- [x] Start VM and complete Ubuntu installation
- [x] Set static IP: 192.168.1.182

### Phase 4b: Base OS Setup
- [x] Run master setup script: `bash host_setup.sh`
- [x] Verify SSH access: `ssh agamache@192.168.1.182`
- [x] Docker verified working
- [x] Registry login works

### Phase 4c: Install GitLab Runner
- [x] Added GitLab Runner repository
- [x] Installed GitLab Runner v18.6.6

### Phase 4d: Get Registration Token from GitLab
- [x] Created instance runner in GitLab Admin UI
- [x] Name: gitlab-runner-1
- [x] Tags: docker, linux, build
- [x] Run untagged: yes

### Phase 4e: Register Runner
- [x] Registered with non-interactive command
- [x] Runner shows "Online" in GitLab UI

### Phase 4f: Configure Runner for Docker-in-Docker
- [x] Set privileged = true
- [x] Added docker.sock volume mount
- [x] Restarted runner

### Phase 4g: Test Runner with Sample Pipeline
- [x] Created test-pipeline project
- [x] Added .gitlab-ci.yml with test and build stages
- [x] **Result:** test-job passes, build-docker (dind) fails
- [x] Standard CI jobs work, DIND needs more config (not blocking)

---

## DNS Setup Required

Add to AWS Route53:

| Record | Type | Value |
|--------|------|-------|
| gitrun | A | 192.168.1.182 |

---

## Verification Checklist

- [x] Runner VM created and accessible
- [x] GitLab Runner installed (v18.7.2)
- [x] Runner registered and showing "online" in GitLab UI
- [x] Test pipeline completes successfully (all stages)
- [x] Docker builds working (using docker:27 image, not docker:24.0)
- [x] Docker socket mount working (/var/run/docker.sock)
- [x] Registry push operations working
- [x] SSH deployment to QA host working

---

## Runner Configuration Reference

### Full config.toml Example

```toml
concurrent = 4  # Number of parallel jobs
check_interval = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "docker-runner"
  url = "http://gitlab.gothamtechnologies.com"
  token = "[your-token]"
  executor = "docker"
  
  [runners.custom_build_dir]
  
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  
  [runners.docker]
    tls_verify = false
    image = "docker:24.0"
    privileged = true
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock"]
    shm_size = 0
```

### Useful Tags

Configure jobs to target specific runners:

| Tag | Use For |
|-----|---------|
| `docker` | Docker build jobs |
| `linux` | Linux-specific jobs |
| `build` | Build/compile jobs |
| `deploy-qa` | QA deployment jobs |
| `deploy-prod` | Production deployment jobs |

---

## Troubleshooting

```bash
# Check runner status
sudo gitlab-runner status

# View runner logs
sudo journalctl -u gitlab-runner -f

# Verify runner registration
sudo gitlab-runner verify

# Re-register if needed
sudo gitlab-runner unregister --all-runners
sudo gitlab-runner register

# Test runner locally
sudo gitlab-runner run
```

---

## Resource Usage (Expected)

| Resource | Idle | During CI Jobs |
|----------|------|----------------|
| RAM | ~500MB | 4-12GB (depends on jobs) |
| CPU | ~1% | 50-100% (during builds) |
| Disk | ~5GB | Growing with Docker images |

### Docker Image Cleanup

Set up periodic cleanup to prevent disk fill:

```bash
# Add to crontab
sudo crontab -e

# Add this line (runs daily at 2am):
0 2 * * * docker system prune -af --volumes
```

---

## Next Phase

After Runner is working → **Phase 5: CI/CD Pipelines** (deploy to QA)

---

## Related Files

- `/phases/phase3_gitlab_server.md` - GitLab server (prerequisite)
- `/phases/phase5_ci_cd_pipelines.md` - Pipeline configuration
- `/phases/phase7_cloud_deploy.md` - AWS/GCP deployment

---

## Origin date — demoted from `current_phase.md` (Aug 24, 2026)

**December 13, 2025** — `gitlab-runner-1` installed at **192.168.1.182**, Docker executor configured
with the socket mount, test pipeline verified: standard jobs worked, **DIND did not** and was left
for later.

⚠️ **This date existed in exactly one place** — a "Previous Sessions" list at the bottom of
`current_phase.md` — and was recorded nowhere in `phases/` or `MEMORY.md`. It is preserved here
because the demotion check asked whether the *knowledge* was held somewhere appropriate rather than
whether the text was duplicated; a verbatim-text check would have reported "not duplicated" for the
whole block and a coverage check would have reported "covered" for the surrounding CI/CD content.
**The install date was the one genuinely unique fact in 57 lines of otherwise stale or wrong text.**

⭐ Its lasting relevance: the **socket mount** decided here is what
`MEMORY.md` → *GITLAB RUNNER* still warns about — it is root-equivalent on `.182`, and the Phase 16
security ledger (L19) prices it. The DIND gap noted that day is *why* the socket mount was kept.

---

## COPIED VERBATIM FROM `MEMORY.md` @ `pre-memory-diet` (lines 1453–1561) — Nov 24, 2026 (memory-diet, copy-first) — GITLAB RUNNER

## GITLAB RUNNER

- **VM:** vm-gitrun-1 @ 192.168.1.182
- **Name:** gitlab-runner-1 (ID #2)
- **Executor:** Docker (docker:24.0)
- **Tags:** docker, linux, build
- **Status:** ✅ Online, runs untagged jobs
- **Config:** `/etc/gitlab-runner/config.toml`

**DIND Note:** Docker-in-Docker (services: docker:dind) fails. Standard jobs work fine.
Use docker socket mount for builds: `volumes = ["/var/run/docker.sock:/var/run/docker.sock"]`

### 🚨 What that socket mount actually costs (read out of config.toml, Aug 19 2026 — Phase 16 ledger L19)

Verbatim from `/etc/gitlab-runner/config.toml`:

```
executor = "docker"
  image = "docker:24.0"
  privileged = true
  volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock"]
```

**The docker socket is a root shell on `.182`.** Any job can `docker run -v /:/host` and read or write
the whole filesystem as root. Runner #2 is **`instance_type`** (instance-wide shared) with
`run_untagged=true`, so **every project on this GitLab can do that** — and `.182` is the host that runs
`deploy_prod_local` against real production.

⚠️ **A pipeline author CANNOT decline it.** `privileged` and `volumes` are *runner* config, so least
privilege is unavailable at the job level no matter how the `.gitlab-ci.yml` is written. Phase 16's
"the runner already exists and needs no setup" (item A1) was good news about effort and bad news about
blast radius. Fixing this is part of the **Phase 17 charter**, not a Phase 16 task.

### `docker:24.0` already ships an SSH client (verified Aug 19, 2026)

`docker run --rm docker:24.0 sh -c 'command -v ssh; command -v scp'` → `/usr/bin/ssh`, `/usr/bin/scp`,
on Alpine 3.20. **Mechanism:** the Docker CLI supports `ssh://` connection contexts, so the image must
carry one. So a deploy job on this image needs **no `apk add --no-cache openssh-client`** — unlike
Capricorn's `alpine:latest` jobs, which do. Pin `image:` in the job anyway, so a `config.toml` edit here
cannot silently change a job's toolchain.

**APT signing key (packages.gitlab.com):**
- Keyring: `/etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg`
- Source list: `/etc/apt/sources.list.d/runner_gitlab-runner.list` (uses `signed-by=`)
- Fingerprint: `F6403F65 44A38863 DAA0B6E0 3F01618A 51312F3F`
- **Current expiration: Feb 6, 2028** (rotated May 23, 2026 after the old copy expired Feb 27, 2026)
- ⭐ **The non-obvious bit, and why the fix is a re-download rather than a new source list:
  packagecloud-style repos RE-ISSUE THE SAME KEYPAIR with a later expiry date.** The fingerprint is
  unchanged (`F6403F65…51312F3F`) — only the embedded expiry moved. So `EXPKEYSIG` here means *"your copy
  of the key is stale"*, **not** *"the key was replaced"*, and nothing in `sources.list.d/` needs editing.
  Generalises to any packagecloud-hosted repo (GitLab, GitLab Runner, and others).
- Backup of expired key: `/etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg.bak.20260523`

**Refresh procedure (when EXPKEYSIG appears again ~early 2028):**
```bash
sudo cp /etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg{,.bak.$(date +%Y%m%d)}
curl -fsSL https://packages.gitlab.com/runner/gitlab-runner/gpgkey \
  | sudo gpg --batch --yes --dearmor \
             -o /etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg
sudo apt-get update   # should be clean: no EXPKEYSIG
```

### 🚨 containerd image store is DISABLED here on purpose (Aug 17, 2026) — do not "clean this up"

`/etc/docker/daemon.json` on .182 (backup: `daemon.json.bak-20260817`):

```json
{
  "insecure-registries": ["gitlab.gothamtechnologies.com:5050"],
  "features": { "containerd-snapshotter": false }
}
```

Verify with `docker info | grep -i 'storage driver'` → must say **`overlay2`**. If it ever says
`overlayfs` with `driver-type: io.containerd.snapshotter.v1`, the flag was lost and CI pushes will
start failing again.

**Why.** Docker 29.7.2 defaults to the containerd image store, which makes `docker build` emit **OCI
image indexes**. Its push path can send the **parent index before the child manifest** it references,
and the GitLab registry (v4.40.2) correctly rejects that:

```
PUT .../manifests/sha256:cdd1b210…  → 400  MANIFEST_BLOB_UNKNOWN (detail: sha256:ebc0db88…)
PUT .../manifests/sha256:ebc0db88…  → 201  ← the child, 5ms later
```

Symptom in CI is `error from registry: blob unknown to registry` on the push job while all builds
pass. **It is not a registry problem** — the blob is on disk and .181 had 440 GB free. It is also a
**race, not a certainty**, so it hides: it only bites when several images have genuinely new content
in one pipeline, and a job that changes one image will pass and look like proof the daemon is fine.

**How we got there — the actual lesson.** A **manual** `apt-get upgrade` on **Aug 10 17:18** (by
`agamache`, reboot 17:20) took docker-ce 29.6.2→29.7.2, containerd.io 2.2.6→2.3.3, buildx
0.35→0.36.1, gitlab-runner 19.2.0→19.2.1. **CI then stayed green for a week** and broke on Aug 17,
so nothing connected the failure to the upgrade. unattended-upgrades is enabled on all four VMs but
its `Allowed-Origins` is Ubuntu/ESM only and can never touch `download.docker.com` — **package holds
would not have helped.** The exposure is hand-run `apt upgrade` on the runner. Treat a Docker major
bump on .182 as a change that needs a deliberate CI test, not a routine patch.

**⚠️ After toggling this flag, images in the old store are invisible to the new driver** (`docker
images` reads empty). Retrying just the push job cannot work — there is nothing to push. **Run a new
pipeline**; the first one is a genuine full rebuild.

Application-side detail (Capricorn pipelines #159 fail → #160 green) is recorded in the Capricorn
project: `project/phases/phase25_all_states_tax_brackets.md`, "CI incident".

---
