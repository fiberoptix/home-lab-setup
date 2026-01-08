# Home Lab Project - AI Memory

**Purpose:** Context reload for AI. No humans read this.

---

## CURRENT STATE

- Proxmox running at 192.168.1.150 (HP Z8 G4: Dual Xeon, 256GB RAM, ZFS)
- Script server running at http://192.168.1.195/scripts/
- **GitLab CE LIVE at http://192.168.1.181** (root/[See PASSWORDS.md])
- **GitLab Runner LIVE at 192.168.1.182** (gitlab-runner-1)
- Container Registry on port 5050
- **GitHub repo published:** https://github.com/fiberoptix/home-lab-setup
- Next: Phase 5 - CI/CD pipeline testing

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

- Proxmox: root / [See PASSWORDS.md]
- All VMs: agamache / [See PASSWORDS.md]
- **GitLab Web: root / [See PASSWORDS.md]**
- NAS (SMB): fiberoptix / [See PASSWORDS.md] @ 192.168.1.120

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
| 3 | GitLab Server | ✅ |
| 4 | GitLab Runner | ✅ |
| 5 | CI/CD Pipelines | 🔲 Next |
| 6 | Backups | 🔲 |
| 7 | Cloud Deploy | 🔲 |

**Phase docs:** `/phases/`

---

## GITHUB

- **Repo:** https://github.com/fiberoptix/home-lab-setup
- **User:** fiberoptix (SSH: ~/.ssh/id_ed25519)
- **Email:** andrew.gamache@gmail.com
- **Credentials:** See `github_credentials.md` (git-ignored)

---

## CAPRICORN PROJECT

- **GitLab:** http://gitlab.gothamtechnologies.com/capricorn
- **Production:** http://capricorn.gothamtechnologies.com (GCP)
- **QA:** http://192.168.1.180:5001 (local)

---

## FILES TO READ

1. `/proxmox/credentials`
2. `/phases/current_phase.md`
3. `/phases/phase3_gitlab_server.md`
4. `/phases/phase4_gitlab_runner.md`
