# Home Lab Project - AI Memory

**Purpose:** Context reload for AI. No humans read this.

---

## CURRENT STATE

- Proxmox running at 192.168.1.150 (HP Z8 G4: Dual Xeon, 256GB RAM, ZFS)
- Script server running at http://192.168.1.195/scripts/
- **GitLab CE LIVE at http://192.168.1.181** (root/Powerme!1)
- **GitLab Runner LIVE at 192.168.1.182** (gitlab-runner-1, v18.7.2)
- **Container Registry OPERATIONAL** on port 5050
- **CI/CD Pipeline PRODUCTION-READY** - Both test-app and Capricorn working!
- **Test app deployed:** http://192.168.1.180:8080 (via pipeline)
- **Capricorn deployed:** http://192.168.1.180:5001 (via pipeline!)
- **GitHub repos:** home-lab-setup + Capricorn (dual-remote setup)
- Next: Add monitoring/quality tools OR enable GCP deployment

---

## IPs & HOSTS

| Host | IP | Status |
|------|-----|--------|
| Proxmox | .150 | ✅ Running |
| QA/K8s | .180 | ✅ Built (vm-kubernetes-1) |
| GitLab | .181 | ✅ LIVE |
| **Runner** | **.182** | **✅ LIVE (gitlab-runner-1)** |

---

## CREDENTIALS

**File:** `/proxmox/credentials`

- Proxmox: root / Powerme!1
- All VMs: agamache / Powerme!1
- **GitLab Web: root / Powerme!1**
- NAS (SMB): fiberoptix / Powerme!1 @ 192.168.1.120

---

## GITLAB

- **URL:** http://192.168.1.181 (or gitlab.gothamtechnologies.com)
- **Registry:** http://gitlab.gothamtechnologies.com:5050
- **Sign-up:** Disabled
- **Email:** Not configured yet (Gmail SMTP pending)

**Registry Note:** Uses HTTP. Docker needs `insecure-registries` config:
```json
{"insecure-registries": ["gitlab.gothamtechnologies.com:5050"]}
```
`setup_docker.sh` now auto-configures this for new VMs.

---

## GITLAB RUNNER

- **VM:** vm-gitrun-1 @ 192.168.1.182
- **Name:** gitlab-runner-1 (ID #2)
- **Executor:** Docker (docker:24.0)
- **Tags:** docker, linux, build
- **Status:** ✅ Online, runs untagged jobs
- **Config:** `/etc/gitlab-runner/config.toml`

**DIND Note:** Docker-in-Docker (services: docker:dind) fails. Standard jobs work fine.
Use docker socket mount for builds: `volumes = ["/var/run/docker.sock:/var/run/docker.sock"]`

---

## SCRIPT SERVER

**URL:** http://192.168.1.195/scripts/  
**Restart:** `cd www && ./run_www.sh`

**Setup new host:** 
```bash
wget http://192.168.1.195/scripts/host_setup.sh
bash host_setup.sh
```

---

## STORAGE

| Pool | Name | Type | Use |
|------|------|------|-----|
| local-zfs | rpool1 | mirror | Proxmox, ISOs (2x500GB) |
| vm-critical | rpool2 | mirror | GitLab (2x1TB) |
| vm-ephemeral | rpool3 | stripe | Runner, QA (2x1TB) |

---

## PHASES

| # | Name | Status |
|---|------|--------|
| 0-2 | Hardware/Proxmox/Automation | ✅ |
| 3 | GitLab Server | ✅ VERIFIED |
| 4 | GitLab Runner | ✅ VERIFIED |
| 5 | CI/CD Pipelines | ✅ COMPLETE (test-app + Capricorn) |
| 6 | SonarQube/Monitoring | 🔲 Next |
| 7 | Traefik + SSL | 🔲 |
| 8 | GCP Pipeline | 🔲 |

**Phase docs:** `/phases/`

---

## GITHUB

- **Repo:** https://github.com/fiberoptix/home-lab-setup
- **User:** fiberoptix (SSH: ~/.ssh/id_ed25519)
- **Email:** andrew.gamache@gmail.com
- **Credentials:** See `github_credentials.md` (git-ignored)

---

## CAPRICORN PROJECT

- **GitLab:** http://gitlab.gothamtechnologies.com/production/capricorn
- **GitHub:** https://github.com/fiberoptix/capricorn
- **Remotes:** Dual-remote setup (origin=GitHub, gitlab=GitLab)
- **Branches:** develop (QA auto-deploy), production (GCP manual deploy)
- **Production (GCP):** http://capricorn.gothamtechnologies.com
- **QA (CI/CD):** http://192.168.1.180:5001 ✅ PIPELINE DEPLOYED
- **Local Path:** /home/agamache/DevShare/cursor-projects/unified_ui_DEV_PROD_GCP_2026.1.12/capricorn

---

## FILES TO READ

1. `/proxmox/credentials`
2. `/phases/current_phase.md`
3. `/phases/phase3_gitlab_server.md`
4. `/phases/phase4_gitlab_runner.md`
