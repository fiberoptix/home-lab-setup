# Home Lab Project - AI Memory

**Purpose:** Context reload for AI. No humans read this.

---

## CURRENT STATE

- Proxmox running at 192.168.1.150
- Script server running at http://192.168.1.195/scripts/
- **GitLab CE LIVE at http://192.168.1.181** (root/[See PASSWORDS.md])
- **GitLab Runner LIVE at 192.168.1.182** (gitlab-runner-1)
- Container Registry on port 5050
- Next: Configure SMTP email OR CI/CD pipeline testing

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

| Pool | Type | Use |
|------|------|-----|
| local-zfs | mirror | Proxmox, ISOs |
| vm-critical | mirror | GitLab (500GB) |
| vm-ephemeral | stripe | Runner, QA |

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

## FILES TO READ

1. `/proxmox/credentials`
2. `/phases/current_phase.md`
3. `/phases/phase3_gitlab_server.md`
4. `/phases/phase4_gitlab_runner.md`
