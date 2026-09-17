# Phase 3: GitLab CE Server

**Status:** ✅ COMPLETE & VERIFIED (Jan 11, 2026)  
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

  ⚠️ **Historical record — do NOT copy that command.** It is left as typed, because this is a
  record of the Dec 2025 build. On **Aug 21, 2026** the process-substitution form was found to be
  **broken for `host_setup.sh`**: `BASH_SOURCE[0]` is `/dev/fd/63`, so `SCRIPT_DIR` resolves to the
  unwritable `/dev/fd` and the download-first step fails. (It worked here only because the script
  was simpler then.) **Current form is two steps — `wget`/`curl` the file, then `bash host_setup.sh`
  — see `phases/phase2_host_setup_automation.md`.**
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
- [x] Change root password immediately (set to [See PASSWORDS.md])
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
- [x] Can create projects (tested with test-app project)
- [x] Can push/pull code (HTTP with embedded credentials works)
- [x] Container registry accessible on port 5050 (push/pull verified)
- [ ] Email notifications working (Phase 3f - optional, skipped for now)
- [x] HTTP git operations working (SSH setup not required for pipeline)

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

---

## DEMOTED VERBATIM FROM `phases/current_phase.md` — Sep 17, 2026 (`MAKE_MEMORIES` pass 9)

⭐ **Copied, not summarised.** This was the OLDEST block in `current_phase.md` and it is routed here
because the GitLab server is the mirror's host.

⚠️ **Every governing RULE in it is already in `CURSOR_RULES` → GIT REMOTES & COMMIT ROUTING**, verified
fact-by-fact rather than by text overlap: `NO git-crypt`, the four gates, `FAILS CLOSED`, `--yes`
required for unattended use, the `main @ <sha>` stamp, `fully disjoint`, and `no common ancestor`.
⛔ **So read `CURSOR_RULES` for what to DO. This is kept only as the record of how it came to be.**

🚨 **ONE LIVE ITEM WAS PROMOTED, NOT FILED: the leaked password was never rotated.** It is now in
`MEMORY.md` → *Secret hygiene*, because a rule buried in history is a rule that stops being followed.

⚠️ **Stale paths below, deliberately left as written:** `www/scripts/smb_credentials` moved to
`www/smb_credentials` on Aug 21, 2026, and the file counts (98 / 42 / 208) are long out of date.

## Dual-remote (GitHub-safe / GitLab-full) + secret scrub (June 18, 2026, night)

**Status:** COMPLETE ✅
**What:** Established the same dual-remote model as the Capricorn project
(unified_ui_DEV_PROD_GCP): SAFE/curated content → public GitHub, EVERYTHING (incl.
secrets, plaintext) → private GitLab. NO git-crypt / NO encryption.

### Remotes
- `origin` → GitHub (PUBLIC): `git@github.com:fiberoptix/home-lab-setup.git` (SSH). Curated;
  secrets `.gitignore`'d so they NEVER reach it. Update with **`./push_github.sh`**.
- `gitlab` → GitLab (PRIVATE): `http://root:<pw>@gitlab.gothamtechnologies.com/production/home-lab-setup.git`.
  HTTP "wallet" auth (pw baked into URL in `.git/config`, same as Capricorn/capricorn-docs).
  Full plaintext mirror, pushed with **`./push_gitlab.sh "msg"`**.

> ⚠️ **Renamed Aug 12, 2026: `gl-backup.sh` → `push_gitlab.sh`**, and a new `push_github.sh` was
> added. Push only via the scripts, never a raw `git push`. Everything below describing
> "gl-backup.sh" is the same code under the new name.

### push_gitlab.sh (repo root — formerly gl-backup.sh)
- Snapshots the ENTIRE working tree (tracked + ignored, minus `.DS_Store`) onto `gitlab/main`
  via a temp index — does NOT touch the working tree, real index, or the GitHub-bound `main`.
- Force-includes ignored files (PASSWORDS.md, github_credentials.md, proxmox/credentials,
  nas_credentials, /working/, /ddns/, vmware/*.zip, www/scripts/smb_credentials).
- Handles nested git repos (working/openclaw-ansible) by moving their `.git` to an external
  holding dir during the add, so their WORKING FILES are captured (not empty gitlinks) and
  their `.git` internals are NOT. Always restored.
- GitLab mirror = 98 files; GitHub = ~42 files. (As of Aug 12, 2026 the GitLab snapshot is 208
  files — the education program and its images account for most of the growth.)

### push_github.sh (repo root — new Aug 12, 2026)
- Pushes the curated tree to `origin/main`, and **fails closed**: nothing is pushed unless all four
  gates pass. Gates: (1) `origin` really is GitHub and we are on `main`; (2) no TRACKED file has a
  secret-looking name; (3) every known sensitive path that exists on disk is still gitignored;
  (4) the outgoing diff contains no private-key blocks, no URL with an embedded password, and no AWS
  keys. Then it lists the commits about to become public and demands a typed `yes`.
- **Why it exists:** GitHub has no encryption, so `.gitignore` was the only guard and "verify before
  pushing" was a convention a human or an agent could skip. This makes it enforced.
- ⚠️ **`--yes` is required for non-interactive use; without a TTY it refuses rather than assuming.**
- Content scanning deliberately uses only high-confidence patterns, so the *word* "password" in
  documentation does not trip it. The credentialed-URL check is the one that would catch the GitLab
  wallet (`http://root:<pw>@...`) being committed to a tracked file.
- **Proven, not assumed:** staging a fake `_gatetest.key` made it block, name the file and exit 1
  without pushing; repo state was byte-identical after cleanup.

### What the GitLab mirror preserves — and the context leak we closed

`gitlab/main` and `main` are **fully disjoint** (`git merge-base` finds nothing in common):
**82 real commits on `main` against 22 snapshots on `gitlab/main`.** The mirror keeps every *file*
perfectly and history only coarsely — though it is a genuine commit chain, so diffs between snapshots
work fine.

The leak was that a snapshot could not be tied back to the real history, and when the message
argument was forgotten the snapshot was labelled only `Full snapshot 2026-08-03 17:44:28 EDT` — tree
intact, reason gone. Two of the existing 22 look like that.

✅ **Closed:** `push_gitlab.sh` now auto-stamps. Default is
`Snapshot <ts> — main @ <sha>[+dirty]: <HEAD subject>`, and a message you pass gets
`[main @ <sha>]` appended. **`+dirty` flags a snapshot containing work in no commit at all**, which
is exactly when the SHA alone would mislead. Nothing is lost on the GitHub side — `push_github.sh`
never authors a commit, so real commit messages are untouched.

### Security scrub (CRITICAL — was a real leak)
- Found the master password (Proxmox/VMs/GitLab/NAS), the SonarQube admin password, an old
  deprecated password, and two SonarQube project tokens committed to PUBLIC GitHub (current
  files AND history) in MEMORY.md, phases/current_phase.md, www/scripts/setup_smb_mount.sh.
  (Actual values intentionally NOT repeated here — see PASSWORDS.md.)
- Scrubbed all of them from tracked files → `[See PASSWORDS.md]`. Real values live ONLY in
  PASSWORDS.md (gitignored → GitLab mirror) + `.git/config` wallet.
- Purged from ALL 54 commits with `git filter-repo --replace-text`, force-pushed GitHub
  (`546b85a`→`24cda0c`). Pre-rewrite safety bundle: `/tmp/home-lab-setup-prefilter-*.bundle`.
- User chose NOT to rotate the password. CAVEAT: GitHub may retain orphaned commits by SHA
  until GC; true fix would be rotation. (Offer remains open.)
- git-crypt setup that was started earlier was fully reverted (no `.gitattributes`, filters
  stripped, key removed).

### setup_smb_mount.sh password handling
- No longer hardcodes the SMB pw. Resolves it: `SMB_PASSWORD` env var → `www/scripts/smb_credentials`
  (gitignored; present on GitLab mirror so a LAN clone "just works") → interactive prompt.
- `www/scripts/smb_credentials` holds `SMB_PASSWORD='...'`, gitignored (rule in .gitignore),
  included on GitLab via gl-backup. NEVER on GitHub.

**Commits this session:** `24cda0c` (scrub + dual-remote + gl-backup), `db88fed` (smb_credentials
file wiring). GitLab snapshots: `f65cf2a` (initial full mirror), `087fc5b` (+ smb_credentials).

---
