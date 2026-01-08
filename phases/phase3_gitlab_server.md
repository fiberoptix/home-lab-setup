# Phase 3: GitLab CE Server

**Status:** ✅ COMPLETE (Dec 12, 2025)  
**Goal:** Install and configure self-hosted GitLab Community Edition

---

## Overview

GitLab CE will be our central DevOps platform providing:
- Git repository hosting (~10 projects)
- Container Registry (local Docker image storage)
- CI/CD pipeline orchestration
- Package registries (npm, pip, etc.)

**Philosophy:** Enterprise-class prototype environment for a small startup

---

## VM Specifications

| Property | Value |
|----------|-------|
| **Hostname** | gitlab.gothamtechnologies.com |
| **IP Address** | 192.168.1.181 |
| **RAM** | 16GB |
| **CPU** | 8 cores |
| **Disk** | 500GB |
| **Storage Pool** | vm-critical (ZFS mirror - redundant) |
| **OS** | Ubuntu 24.04 LTS Server |
| **Access** | Tailscale VPN only (not public) |

---

## Sub-Phases

### Phase 3a: Create VM in Proxmox ✅
- [x] Log into Proxmox UI (https://192.168.1.150:8006)
- [x] Upload Ubuntu 24.04 Server ISO (if not already done)
- [x] Create new VM:
  - VM ID: 181 (matches IP)
  - Name: gitlab
  - ISO: Ubuntu 24.04 Server
  - Disk: 500GB on vm-critical
  - CPU: 8 cores
  - RAM: 16384 MB (16GB)
  - Network: vmbr0, DHCP initially
- [x] Start VM and complete Ubuntu installation
- [x] Set static IP: 192.168.1.181

### Phase 3b: Base OS Setup ✅
- [x] Run master setup script:
  ```bash
  bash <(curl -s http://192.168.1.195/scripts/host_setup.sh)
  ```
  This installs: SSH, passwordless sudo, Docker, Git, NAS mount
- [x] Verify SSH access from DEV machine:
  ```bash
  ssh agamache@192.168.1.181
  ```
- [x] Set hostname:
  ```bash
  sudo hostnamectl set-hostname gitlab
  echo "127.0.1.1 gitlab gitlab.gothamtechnologies.com" | sudo tee -a /etc/hosts
  ```

### Phase 3c: Install GitLab CE ✅
- [x] Install dependencies:
  ```bash
  sudo apt-get update
  sudo apt-get install -y curl openssh-server ca-certificates tzdata perl
  ```

- [x] Add GitLab repository:
  ```bash
  curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash
  ```

- [x] Install GitLab CE:
  ```bash
  sudo EXTERNAL_URL="http://gitlab.gothamtechnologies.com" apt-get install gitlab-ce
  ```
  
  **Note:** We use HTTP initially. HTTPS via Tailscale or internal later.

- [x] Wait for installation (5-10 minutes)

- [x] Get initial root password:
  ```bash
  sudo cat /etc/gitlab/initial_root_password
  ```
  **Save this password!** It expires in 24 hours.

### Phase 3d: Configure GitLab ✅
- [x] Access GitLab UI: http://192.168.1.181
- [x] Login as `root` with initial password
- [x] Change root password immediately (set to Powerme!1)
- [x] Configure admin settings:
  - Admin Area → Settings → General → Sign-up restrictions → **Disabled public sign-up**

### Phase 3e: Configure Container Registry ✅
- [x] Edit GitLab configuration:
  ```bash
  sudo nano /etc/gitlab/gitlab.rb
  ```

- [x] Add registry configuration:
  ```ruby
  # Container Registry
  registry_external_url 'http://gitlab.gothamtechnologies.com:5050'
  gitlab_rails['registry_enabled'] = true
  ```

- [x] Reconfigure GitLab:
  ```bash
  sudo gitlab-ctl reconfigure
  ```

- [x] Verify registry is running:
  ```bash
  sudo gitlab-ctl status registry
  ```

**⚠️ IMPORTANT DISCOVERY:** Registry uses HTTP. Docker clients must configure `insecure-registries`:
```json
// /etc/docker/daemon.json
{"insecure-registries": ["gitlab.gothamtechnologies.com:5050"]}
```
Then `sudo systemctl restart docker`. **Updated `setup_docker.sh` to do this automatically.**

### Phase 3f: Configure Email (Gmail SMTP)
- [ ] **Gmail Setup (do this in browser):**
  1. Go to https://myaccount.google.com/security
  2. Enable 2-Step Verification (if not already)
  3. Go to App Passwords: https://myaccount.google.com/apppasswords
  4. Create new app password for "GitLab"
  5. Save the 16-character password

- [ ] Edit GitLab configuration:
  ```bash
  sudo nano /etc/gitlab/gitlab.rb
  ```

- [ ] Add email configuration:
  ```ruby
  # Email Configuration (Gmail SMTP)
  gitlab_rails['smtp_enable'] = true
  gitlab_rails['smtp_address'] = "smtp.gmail.com"
  gitlab_rails['smtp_port'] = 587
  gitlab_rails['smtp_user_name'] = "YOUR_EMAIL@gmail.com"
  gitlab_rails['smtp_password'] = "YOUR_APP_PASSWORD"
  gitlab_rails['smtp_domain'] = "smtp.gmail.com"
  gitlab_rails['smtp_authentication'] = "login"
  gitlab_rails['smtp_enable_starttls_auto'] = true
  gitlab_rails['smtp_tls'] = false
  gitlab_rails['smtp_openssl_verify_mode'] = 'peer'
  
  # GitLab email settings
  gitlab_rails['gitlab_email_from'] = 'YOUR_EMAIL@gmail.com'
  gitlab_rails['gitlab_email_reply_to'] = 'YOUR_EMAIL@gmail.com'
  ```

- [ ] Reconfigure GitLab:
  ```bash
  sudo gitlab-ctl reconfigure
  ```

- [ ] Test email:
  ```bash
  sudo gitlab-rails console
  # In console:
  Notify.test_email('your@email.com', 'Test Subject', 'Test Body').deliver_now
  ```

### Phase 3g: Create First Project & Test
- [ ] Create new project in GitLab UI
- [ ] Clone locally and push test code
- [ ] Verify container registry access:
  ```bash
  docker login gitlab.gothamtechnologies.com:5050
  ```

---

## DNS Setup Required

Add these A records in AWS Route53 for gothamtechnologies.com:

| Record | Type | Value | Notes |
|--------|------|-------|-------|
| gitlab | A | 192.168.1.181 | Or Tailscale IP for remote access |

**Note:** For local network access, also add to your router's DNS or /etc/hosts on dev machines.

---

## Verification Checklist

- [x] GitLab UI accessible at http://192.168.1.181
- [x] Can login as root
- [ ] Can create projects (not tested yet)
- [ ] Can push/pull code (not tested yet)
- [x] Container registry accessible on port 5050 (docker login works)
- [ ] Email notifications working (Phase 3f - optional, skipped for now)
- [ ] SSH clone working (not tested yet)

---

## Troubleshooting Commands

```bash
# Check GitLab status
sudo gitlab-ctl status

# View logs
sudo gitlab-ctl tail

# Reconfigure after changes
sudo gitlab-ctl reconfigure

# Restart all services
sudo gitlab-ctl restart

# Check specific service
sudo gitlab-ctl tail nginx
sudo gitlab-ctl tail registry
sudo gitlab-ctl tail postgresql
```

---

## Configuration Files

| File | Purpose |
|------|---------|
| `/etc/gitlab/gitlab.rb` | Main configuration |
| `/etc/gitlab/initial_root_password` | Initial root password (delete after use) |
| `/var/opt/gitlab/` | GitLab data directory |
| `/var/log/gitlab/` | Log files |

---

## Resource Usage (Expected)

| Resource | Idle | Under Load |
|----------|------|------------|
| RAM | ~4-6GB | ~10-12GB |
| CPU | ~5% | ~50%+ during CI |
| Disk | Growing with repos/registry | Monitor regularly |

---

## Next Phase

After GitLab server is running → **Phase 4: GitLab Runner**

---

## Related Files

- `/proxmox/Home_Lab_Proxmox_Design.md` - Overall architecture
- `/phases/phase4_gitlab_runner.md` - Runner setup (next)
- `/phases/phase6_backups.md` - Backup strategy

