# Home Lab Project - AI Memory

**Purpose:** Context reload for AI. No humans read this.

---

## CURRENT STATE

- Proxmox running at 192.168.1.150 (HP Z8 G4: Dual Xeon, 256GB RAM, ZFS)
- Script server running at http://192.168.1.195/scripts/
- **GitLab CE LIVE at http://192.168.1.181** (root/Powerme!1)
- **GitLab Runner LIVE at 192.168.1.182** (gitlab-runner-1, v18.7.2)
- **Container Registry OPERATIONAL** on port 5050
- **CI/CD Pipeline PRODUCTION-READY** - Full automation working!
- **Test app deployed:** http://192.168.1.180:8080 (via pipeline)
- **Capricorn QA:** http://192.168.1.180:5001 (auto-deploy on develop push)
- **Capricorn GCP:** http://capricorn.gothamtechnologies.com (manual deploy on production)
- **GitHub repos:** home-lab-setup + Capricorn (both updated)
- **SonarQube LIVE at http://192.168.1.183:9000** (v26.1.0, admin/Powerme!12345)
- **Phase 6 COMPLETE:** Both test-app and Capricorn integrated with SonarQube!
- Next: Phase 7 (Monitoring Stack) or Phase 8 (Traefik+SSL)

---

## IPs & HOSTS

| Host | IP | Status |
|------|-----|--------|
| Proxmox | .150 | ✅ Running |
| QA/K8s | .180 | ✅ Built (vm-kubernetes-1) |
| GitLab | .181 | ✅ LIVE |
| **Runner** | **.182** | **✅ LIVE (gitlab-runner-1)** |
| **SonarQube** | **.183** | **✅ LIVE (vm-sonarqube-1, v26.1.0)** |

---

## CREDENTIALS

**File:** `/proxmox/credentials`

- Proxmox: root / Powerme!1
- All VMs: agamache / Powerme!1
- **GitLab Web: root / Powerme!1**
- **SonarQube Web: admin / Powerme!12345**
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
| 5 | CI/CD Pipelines | ✅ COMPLETE (QA + GCP both working!) |
| 6 | SonarQube | ✅ COMPLETE (test-app + Capricorn both integrated!) |
| 7 | Monitoring Stack | 🔲 |
| 8 | Traefik + SSL | 🔲 |

**Phase docs:** `/phases/`

---

## SONARQUBE

- **URL:** http://192.168.1.183:9000
- **Version:** 26.1.0 (community, latest)
- **Login:** admin / Powerme!12345
- **Container:** `sonarqube:community` (Docker)
- **Data:** `/opt/sonarqube/data` (persisted)

**Projects:**
- test-app (token: sqp_1f2e5062c88890cd98477759b593428ac494576d)
  - Quality Gate: PASSED ✅
  - 86 lines of code (HTML, Docker)
  - 0 security issues, 0 bugs, 1 maintainability issue
- capricorn (token: sqp_fcfecef2186a725979f59666e04bb1f451eded3b)
  - Quality Gate: PASSED ✅
  - 28k lines of code (TypeScript, Python)
  - 5 security issues, 144 reliability issues, 490 maintainability issues

**Note:** Upgraded from 9.9.8 → 26.1.0 (required fresh database)

**Pipeline Integration:** Scan stage runs after build/push, before deploy (allow_failure: true)

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
3. `/phases/phase5_ci_cd_pipelines.md`
4. `/phases/phase6_sonarqube.md` ✅ COMPLETE
