# Home Lab Project - AI Memory

**Purpose:** Context reload for AI. No humans read this.

---

## PROJECT SCOPE (READ FIRST — stay in your lane)

This repo covers the **INFRASTRUCTURE layer ONLY**:
- Hardware (HP Z6 G4 Proxmox host, NAS, networking)
- Proxmox host config, kernel/package management, storage, backups
- VM provisioning / deployment / lifecycle management (create, resize, snapshot, shut down, restore)
- Host-level services that make VMs reachable (DNS, port-forwards, firewall at the infra edge)

It does **NOT** own the **APPLICATION layer**. Application state, functionality, image tags,
DB schema, app docker-compose internals, and app config are owned by their OWN projects
(e.g. **Capricorn** / `unified_ui_DEV_PROD_GCP`). 

Practical rules:
- Do NOT maintain or "reconcile" application docker-compose files, app image tags, or app DB
  contents here. That's the app project's job. If you capture them, label them clearly as a
  *read-only reference snapshot* and point to the owning project — don't treat drift as a bug here.
- At the VM level, document only what's infra-relevant: "vm-www-1 (.184) runs Docker + a Traefik
  ingress (80/443, Let's Encrypt) and hosts the Capricorn PROD stack + splash page." The internals
  of that stack live in the Capricorn project.

---

## CURRENT STATE

- **✅ Phase 13 Proxmox host audit + same-day fixes — July 9, 2026.** Full record in
  `phases/phase13_fable_proxmox_audit.md` (findings, action plan, implementation log). Done:
  - **Email alerting LIVE:** PVE notification endpoint `gmail-smtp` (smtp.gmail.com:587,
    app password in PASSWORDS.md "Gmail SMTP Relay") + default matcher retargeted; postfix
    relayhost + SASL + `root:` alias → ZED/smartd/vzdump/cron mail all reach Andrew's Gmail.
    Both paths tested + confirmed received. Rollback notes in phase13.
  - **Host upgraded to PVE 9.2.4**, 0 pending pkgs. Kernel 7.0.14-4 pin-tested + adopted
    same day (see below). Stale bookworm apt entries removed (`/etc/apt/sources.list` emptied, backup
    `/root/sources.list.bak-20260709`).
  - **ARC cap 8G → 16G** (runtime + `/etc/modprobe.d/zfs.conf`, initramfs rebuilt).
  - **rpcbind/nfs-client disabled** (port 111 closed; NAS backups are CIFS, unaffected).
  - **`zpool upgrade` all 3 pools** (feature-current). **VM200 snapshot deleted** (+5.1G);
    only remaining snapshot = 184's `pre_phase12_firewall` (keep until Phase 12 window closes).
  - **Tools added:** nvme-cli, numactl, lm-sensors (+ coretemp persisted via
    /etc/modules-load.d/coretemp.conf), libsasl2-modules. CPU pkg ~51°C healthy.
  - **vm-ephemeral REBUILT with ashift=12** (afternoon session, ~10 min downtime): 182+200
    shut down → disks qm-move-disk'd to vm-critical → pool destroyed/recreated (same 2 NM620s,
    by-id, `-o ashift=12` + lz4) → disks back → VMs verified healthy. Old pool was ashift=9.
  - **AMT verified DISABLED without BIOS visit:** HP exposes BIOS read-only from Linux via
    `/sys/class/firmware-attributes/hp-bioscfg/attributes/` (280 attrs). "Intel AMT" = Disable,
    "ME Firmware Mode" = "AMT Disabled"; all AMT ports (623/664/5900/16992-5) closed from LAN.
    **This sysfs trick works for reading ANY BIOS setting on the HP hosts — remember it.**
  - **⏸️ DEFERRED by Andrew:** SSH key-only hardening (SEC-1) + web UI TOTP (SEC-2) + host.fw —
    LAN-only home lab behind Phase 12 perimeter; revisit later.
  - **❎ WON'T-FIX by Andrew:** vzdump backups for 183 (Sonar, barely used) + 184 (WWW =
    vanity/demo box) — both easily rebuilt. Only GitLab (181) holds irreplaceable data.
    **VM 185 (OpenClaw) stays dormant as-is** (not destroyed).
  - **Audit discoveries:** host runs Tailscale (100.108.209.77, `pve` on tailnet); idle Quadro
    P2000 GPU (nouveau, passthrough candidate); SNC enabled in BIOS → 2 NUMA nodes (64G each);
    only 4/6 memory channels populated; fallback kernel 6.17.2-1 no longer on ESPs.
  - **✅ Console visit DONE (Jul 9, 12:53 PM):** SNC disabled in BIOS (host is now 1 flat
    NUMA node / 128GB) AND kernel **7.0.14-4-pve pin-tested + made PERMANENT pin** (booted
    clean 1st try: 6/6 NVMe, 0 errors, pools ONLINE, VMs up, public site 200). Fallbacks on
    ESPs: 7.0.6-2 + 6.17.13-x. Slot 5 Bifurcation x4x4x4x4 unaffected (it, not SNC, drives
    the quad-NVMe card — Andrew's question, answered from hp-bioscfg).
  - **Subscription nag:** widget-toolkit 5.2.6 (Jul 9 upgrade) broke the old sed patch in
    `/usr/local/bin/proxmox-update.sh`. BOTH fixed: live proxmoxlib.js patched (check →
    `false`) and update script line 28 now uses a perl pattern matching the new code
    (idempotent). If nag reappears after a future update → pattern needs refreshing again.
  - **✅ GitLab backup test-restore drill PASSED (Jul 9, 1:20 PM):** qmrestore of the
    nightly vzdump → VMID 999 on vm-ephemeral (2m17s), clone kept its baked-in .181 IP but
    was isolated on a **host-only bridge vmbr999 + /32 route** (no LAN exposure; live 181
    unaffected). Verified 16/16 services, DB (4 users / 5 projects), and a real
    `git clone` of capricorn (306 files). Torn down clean. Procedure in phase13 (bottom).
    Repeat ~quarterly (agent can now do in-VM checks directly).
  - **✅ qemu-guest-agent on ALL 5 live VMs (Jul 9, 1:28 PM):** installed in guests
    181/182/183/184/200 + `agent enabled=1` + graceful stop/start each (runner idle-checked,
    GitLab last). All answer `qm agent ping`. Restarts also put every VM on the **new QEMU
    11.0.2** binary (upgrade loose end closed). All services verified healthy after.
    185 (dormant) skipped — add agent if ever revived.
  - **Still open/optional:** 2x32GB DIMMs for 6-channel bandwidth; tailscaled NetInfo log
    noise (G3100 UPnP flapping; fix = TS_DEBUG_DISABLE_PORTMAPPER override if it bothers);
    delete 184 snapshot `pre_phase12_firewall` ~mid-July.
  - **Dev workstation (Z8) side quest:** Ubuntu VMware VM resized 32→24 vCPUs **as 2 sockets
    x 12** — Andrew found 2x12 makes Windows place the VM on idle PROC1 (1x24 co-locates with
    Windows on PROC0). +11%/thread, 93% scaling eff. Details in phase13 addendum.

- **✅ Phase 12 network perimeter lockdown — IMPLEMENTED July 8, 2026.** Full detail in
  `phases/phase12_network_segmentation.md`. What's live now:
  - **Router (G3100):** deleted public VNC/ARD forwards (3283/5900/5988→.200); Mac-mini is
    Tailscale-only. Kept: 80/443→.184, Plex .200:32400, Tailscale UPnP holes, .100 (Verizon
    ARRIS equipment — ISP-managed, accepted). UPnP stays ENABLED (Andrew's call).
  - **Capricorn deploy = PUSH model:** `deploy_prod_local` now pulls images on the runner (.182)
    and streams them via `docker save | ssh .184 "docker load"`. .184 never contacts the
    registry. On `production` (e0f3057) AND `develop` (9e5d2dc). Live-tested: pipeline #137
    job #722 succeeded, cap.gothamtechnologies.com 200.
  - **.184 is inbound-only (Proxmox fw):** `/etc/pve/firewall/184.fw` — IN policy DROP
    (allow 80/443 anywhere; 22 from .182/.195/.150 only; LAN ICMP); OUT = ACCEPT to gateway .1
    + internet, DROP to all RFC1918. Datacenter fw ENABLED via new `cluster.fw` (was disabled —
    the old 184.fw had been inert). Other VMs have no .fw files → unaffected (185.fw exists,
    VM stopped). Rollback: `/root/184.fw.bak-20260708` on pve, VM snapshot `pre_phase12_firewall`.
  - **Validated:** .184→.180/.181/.183/.150 all blocked; .184→internet/DNS works; public 200;
    .195/.182 SSH in OK; .181→.184:22 blocked; :8080 dashboard blocked from LAN.
  - **Still open (minor):** off-LAN scan of WAN IP (needs external vantage); .195 workstation
    is STATIC IP (SSH allowlist rule safe). Related Capricorn work: `unified_ui_DEV_PROD_GCP`
    `project/phases/phase22*` (app has NO auth + is the sole public door → app hardening matters).

- Proxmox running at 192.168.1.150 (HP Z6 G4: single Xeon Platinum 8168 24c/48t, 128GB RAM, ZFS) — **PVE 9.2.4**, kernel **7.0.14-4-pve** (pinned + tested Jul 9, 2026; SNC disabled → single NUMA node)
- **NOTE:** The Proxmox server is a **Z6 G4** (single CPU, 128GB). The **dev workstation** we work from is a **Z8 G4** (dual Platinum 8168, 256GB). Don't confuse the two.
- **Jun 18, 2026: kernel fully un-stuck.** Went 6.17.2-1 → 6.17.13-13 → **7.0.6-2-pve** (all NVMe-clean), full host upgrade to PVE 9.2.3, all package holds removed. 7.0.6-2 tested via --next-boot, then made permanent and confirmed it boots autonomously (2 reboots clean). 6.17.13-13 kept as fallback. See current_phase.md + phase1b.
- Script server running at http://192.168.1.195/scripts/
- **GitLab CE LIVE at http://192.168.1.181** (root/[See PASSWORDS.md])
- **GitLab Runner LIVE at 192.168.1.182** (gitlab-runner-1, v18.7.2)
- **Container Registry OPERATIONAL** on port 5050
- **CI/CD Pipeline PRODUCTION-READY** - Full automation working!
- **Test app deployed:** http://192.168.1.180:8080 (via pipeline)
- **Capricorn QA:** http://192.168.1.180:5001 (auto-deploy on develop push)
- **Capricorn GCP:** http://capricorn.gothamtechnologies.com (manual deploy on production)
- **GitHub repos:** home-lab-setup + Capricorn (both updated)
- **SonarQube LIVE at http://192.168.1.183:9000** (v26.1.0, admin/[See PASSWORDS.md])
- **Phase 6 COMPLETE:** Both test-app and Capricorn integrated with SonarQube!
- **Phase 7 COMPLETE:** Local WWW Server operational + all documentation updated! (vm-www-1 @ .184)
- **PROD URLs (PRIMARY):** https://cap.gothamtechnologies.com (Capricorn) + https://www.gothamtechnologies.com (splash)
- **GCP Instance (on-demand):** https://capricorn.gothamtechnologies.com (for public demos)
- **Cost Savings:** ~$400/year by replacing GCP hosting
- **README Files:** Both projects direct users to cap.* as primary production URL
- **Phase 11 COMPLETE:** OpenClaw AI Agent Server LIVE (vm-openclaw-1 @ .185, Tailscale Serve, Telegram)
- **`refresh` command on Proxmox:** Parallel update + reboot of all 5 VMs (.180-.184, excluding .185), live status display. See REFRESH SCRIPT section.
- Next: Phase 8 (Monitoring Stack)

---

## IPs & HOSTS

| Host | IP | Status |
|------|-----|--------|
| Proxmox | .150 | ✅ Running |
| QA/K8s | .180 | ✅ Built (vm-kubernetes-1) |
| GitLab | .181 | ✅ LIVE |
| Runner | .182 | ✅ LIVE (gitlab-runner-1) |
| SonarQube | .183 | ✅ LIVE (vm-sonarqube-1, v26.1.0) |
| **WWW** | **.184** | **✅ LIVE (vm-www-1, Traefik, Capricorn PROD, Splash)** |
| **OpenClaw** | **.185** | **✅ LIVE (vm-openclaw-1, AI agent, Tailscale Serve)** |

---

## CREDENTIALS

**File:** `/proxmox/credentials`

- Proxmox: root / [See PASSWORDS.md]
- All VMs: agamache / [See PASSWORDS.md]
- **SSH key auth:** ✅ ed25519 key deployed to ALL VMs (.180-.185) from dev workstation (Feb 27, 2026)
- **GitLab Web: root / [See PASSWORDS.md]**
- **SonarQube Web: admin / [See PASSWORDS.md]**
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

**APT signing key (packages.gitlab.com):**
- Keyring: `/etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg`
- Source list: `/etc/apt/sources.list.d/runner_gitlab-runner.list` (uses `signed-by=`)
- Fingerprint: `F6403F65 44A38863 DAA0B6E0 3F01618A 51312F3F`
- **Current expiration: Feb 6, 2028** (rotated May 23, 2026 after the old copy expired Feb 27, 2026)
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

---

## SCRIPT SERVER

**URL:** http://192.168.1.195/scripts/  
**Restart:** `cd www && ./run_www.sh`

**Setup new host:** 
```bash
wget http://192.168.1.195/scripts/host_setup.sh
chmod +x host_setup.sh
./host_setup.sh
```

**Or one-liner:**
```bash
wget http://192.168.1.195/scripts/host_setup.sh && chmod +x host_setup.sh && ./host_setup.sh
```

**Note:** The main script automatically downloads all sub-scripts (setup_ssh.sh, setup_docker.sh, etc.) before running them.

**After reboot:** Run `update` from terminal to apply system updates.

---

## VM CONFIGURATION STANDARD

**Last Updated:** January 14, 2026 (4:30 PM EST)  
**Documentation Verified:** All specs match running production configuration  
**ALL NEW VMs MUST USE THESE SETTINGS:**

### Proxmox VM Settings (qm create/set)
```bash
-cpu host                    # Use host CPU type (best performance)
-numa 0                      # NUMA disabled for single-socket
-onboot 1                    # Auto-start on Proxmox boot
-scsihw virtio-scsi-single   # SCSI controller
-net0 virtio=XX:XX:XX:XX:XX:XX,bridge=vmbr0,firewall=1  # Firewall ENABLED

# Disk configuration (CRITICAL - use all these flags):
-scsi0 POOL:vm-XXX-disk-0,iothread=1,discard=on,cache=none,aio=native,size=XXG

# Explanation:
# - iothread=1       : Dedicated I/O thread (better performance)
# - discard=on       : TRIM support for ZFS space reclamation
# - cache=none       : No cache (required for aio=native compatibility)
# - aio=native       : Native Linux AIO (lower CPU overhead)

# ⚠️ IMPORTANT COMPATIBILITY NOTE:
# cache=writeback + aio=native are INCOMPATIBLE!
# - aio=native requires cache.direct=on (direct I/O)
# - cache=writeback uses cache.direct=off (buffered I/O)
# - Use cache=none with aio=native (working configuration)
# - Or use cache=writeback with aio=threads (default, but higher CPU)
```

### Current VMs (Last verified Feb 20, 2026)
| VM | CPU | RAM | Disk | Storage | Config |
|----|-----|-----|------|---------|--------|
| **181 - GitLab** | 8 cores | 24 GB | 500 GB | vm-critical | ✅ Standard |
| **182 - Runner** | 8 cores | 12 GB | 100 GB | vm-ephemeral | ✅ Standard |
| **183 - SonarQube** | 4 cores | 12 GB | 30 GB | vm-critical | ✅ Standard |
| **184 - WWW** | 8 cores | 8 GB | 50 GB | vm-critical | ✅ Standard |
| **185 - OpenClaw** | 8 cores | 16 GB | 50 GB | vm-critical | ✅ Standard |
| **200 - Kubernetes** | 8 cores | 12 GB | 100 GB | vm-ephemeral | ✅ Standard |

### RAM Allocation Strategy
- **GitLab:** 24 GB (memory-hungry, upgraded from 16 GB)
- **SonarQube:** 12 GB (upgraded from 8 GB for large project scans)
- **Runner:** 12 GB (upgraded from 8 GB)
- **Kubernetes/QA:** 12 GB (upgraded from 8 GB)
- **WWW:** 8 GB (Traefik + Capricorn PROD + splash)
- **OpenClaw:** 16 GB (AI agent gateway + Docker sandboxes, upgraded from 8 GB -- Ubuntu Desktop used 90%)
- **Total Allocated:** 84 GB of 128 GB available (66%)

---

## REFRESH SCRIPT (PROXMOX HOST)

**Purpose:** Update + reboot all 5 home-lab VMs in parallel from the Proxmox host.

- **Location:** `/usr/local/bin/refresh.sh` on Proxmox (192.168.1.150)
- **Source in repo:** `proxmox/build-scripts/refresh.sh`
- **Alias:** `refresh` in `/root/.bashrc` on Proxmox
- **Invocation:** SSH to Proxmox as root, then type `refresh`

**tmux detach/reattach-safe (since Jun 18, 2026):**
- `refresh.sh` self-wraps in a tmux session named `refresh`.
- Type `refresh` with no session running → starts the run in tmux.
- Type `refresh` while a run is active → **re-attaches to the same run** (does NOT re-run).
- Survives the Proxmox web console dropping (e.g. switching to a VM VNC console);
  tmux server is reparented to PID 1, so the update+reboot keeps going.
- After completion the pane is held so you can reconnect and read the summary
  (Enter to close, `Ctrl-b d` to detach).
- `tmux 3.5a` is installed on Proxmox. It was installed via `apt-get download` +
  `dpkg -i` (NOT `apt-get install`) because the held kernel
  (`proxmox-default-kernel`/`proxmox-kernel-6.17`) breaks apt's solver for new
  installs on the Proxmox host. Same workaround applies to future host packages
  until the kernel hold is lifted.
- **Test hook:** `REFRESH_SELFTEST=1 refresh` runs the full machinery but the
  per-VM remote command is just `sleep 45` (no apt, no reboot) — safe to test.

**Lesson from Jun 18:** A `refresh` run was killed mid-flight when the Proxmox
web console was switched to a VM VNC console. The 4 fast VMs had already
rebooted, but GitLab (slow Omnibus reconfigure) finished apt but never got to
`init 6`, so it didn't reboot. tmux wrapping prevents this.

**VMs targeted (parallel):** .180, .181, .182, .183, .184
**Excluded:** .185 (vm-openclaw-1) — managed separately

**What it does on each VM:**
1. Records pre-update `/proc/uptime` (baseline for reboot detection)
2. SSHes as `agamache` (key auth, no password)
3. Runs `apt-get update && apt-get upgrade` non-interactively
   (`DEBIAN_FRONTEND=noninteractive`, `--force-confdef`/`--force-confold` to keep existing config files, passwordless sudo)
4. On success (`&&`) runs `sudo init 6` to reboot

**Live status display** (redraws every 30s, with countdown in between):

| State    | Meaning                                                                  |
|----------|--------------------------------------------------------------------------|
| RUNNING  | SSH session active, apt is working                                       |
| SHUTDOWN | SSH ended (init 6 fired) but VM still reachable (mid-shutdown, <180s)    |
| BOOTING  | SSH ended, host unreachable (reboot in progress)                         |
| DONE     | Host back online with fresh uptime (reboot complete)                     |
| FAILED   | SSH ended; host stayed up with unchanged uptime past 180s grace          |

**Per-VM logs:** `/tmp/refresh-<ip>.log` on Proxmox (overwritten each run)

**SSH from Proxmox root to VMs:**
- Dev workstation's `~/.ssh/id_ed25519` keypair was copied to Proxmox `/root/.ssh/` (Option B from May 23, 2026 setup)
- Same key is in `agamache@<vm>:~/.ssh/authorized_keys` on all VMs (deployed Feb 27, 2026)
- `/root/.ssh/known_hosts` pre-populated for .180–.184

**Reboot detection trick:** `init 6` exits SSH with ambiguous exit code (often 0) and the VM stays reachable for ~5-90s before sshd dies. Don't rely on ssh exit code — compare `/proc/uptime` before vs after.

**Created:** May 23, 2026 (this session, see `phases/current_phase.md`)

### Storage Pool Selection
- **vm-critical (mirror):** GitLab, SonarQube, Monitoring (data persistence)
- **vm-ephemeral (stripe):** Runner, QA Host (disposable/rebuildable)

### ZFS Pool Creation (NEW POOLS)
**ALWAYS enable lz4 compression on new pools:**
```bash
# Create pool (mirror or stripe)
zpool create <pool-name> [mirror] /dev/<disk1> /dev/<disk2>
# Enable compression (REQUIRED)
zfs set compression=lz4 <pool-name>
```

### Guest OS Setup
After VM creation, run setup script:
```bash
wget http://192.168.1.195/scripts/host_setup.sh
bash host_setup.sh
```
Installs: Docker, SSH keys, passwordless sudo, NAS mount, insecure-registry config, sysbench

---

## PROXMOX KERNEL MANAGEMENT

**Current Status:** June 18, 2026 — on 6.17.13-13-pve, PVE 9.2.3, holds removed

### Active Kernel
- **Running + permanently pinned:** **7.0.14-4-pve** ✅ (tested Jul 9, 2026 via --next-boot
  during the SNC BIOS change window, then pinned permanent — 0 NVMe timeouts, all 6 NVMe
  behind VMD, ZFS healthy). Prior good: 7.0.6-2-pve (Jun 18 → Jul 9).
- **Fallbacks on ESPs (verified Jul 9, 2026):** 6.17.13-x and 7.0.x lines only — 6.17.2-1 is
  NO LONGER boot-selectable. To revert, `proxmox-boot-tool kernel pin 6.17.13-13-pve` +
  `proxmox-boot-tool refresh` (console access advised).
- **History on this box:** 6.17.4-2 hung (Jan); ran 6.17.2-1 pinned; Jun 18 → 6.17.13-13
  → 7.0.6-2; Jul 9 → 7.0.14-4 (current). All 6.17.9+ / 7.0 kernels are NVMe-clean here.
- **Holds:** NONE ✅ — `proxmox-default-kernel` + `proxmox-kernel-6.17.2-1-pve-signed`
  unheld Jun 18. `apt install` is normal again (dpkg-download workaround no longer needed).
- **Root cause of the recurring solver error** (`proxmox-default-kernel : Depends:
  proxmox-kernel-6.17`, which had blocked tmux + the first full-upgrade attempt): the
  `proxmox-kernel-6.17` **metapackage was not installed**. Installing it (`apt-get
  install proxmox-kernel-6.17`, deps already satisfied) fixed it permanently.
- **History:** 6.17.4-2 hung the box (Jan 12); ran pinned on 6.17.2-1 until Jun 18.
  See `phases/phase1a_*` (failure) and `phases/phase1b_*` (this upgrade + results).

### Status
- systemd 257.13 / libc / QEMU 11 now fully active (host rebooted Jun 18). VMs were
  stopped+started during the kernel test, so they now run on the new QEMU 11 binary too.

### ⚠️ KNOWN ISSUE: Kernel 6.17.4-2-pve
**Problem:** NVMe timeout errors on all disks during boot (HP Z6 G4 + Intel VMD; 6.17 NVMe regression).
**Full incident + rollback write-up:** `phases/phase1a_proxmox_upgrade_fail_rollback.md`
**Safe retry plan (to 6.17.13-13):** `phases/phase1b_proxmox_kernel_upgrade_safe_try.md`

Short version: Jan 12, 2026 the `update` script bumped `6.17.2-1 → 6.17.4-2`; reboot
hung with NVMe timeouts on all drives. Recovered via GRUB → old kernel, then pinned
`6.17.2-1-pve` and held `proxmox-kernel-6.17.2-1-pve-signed` + `proxmox-default-kernel`,
purged the bad kernel.

**Current Protection (as of Jun 18, 2026):**
```bash
# Pinned kernel (always boots this one):
proxmox-boot-tool kernel list
# Shows: Pinned kernel: 7.0.14-4-pve
#   (7.0.6-2-pve and 6.17.13-x-pve also installed as fallbacks)

# Holds: NONE — removed Jun 18, 2026. apt install works normally again.
apt-mark showhold   # (empty)
```

**Update Script:**
- `/usr/local/bin/proxmox-update.sh` created with alias `update`
- Automatically disables subscription nag after each update
- Checks for reboot required
- The **pin** (not holds) is now what controls which kernel boots. A routine
  `apt upgrade` may install newer kernels, but they will NOT boot until explicitly
  `proxmox-boot-tool kernel pin`-ed and tested with console access.

**KERNEL POLICY (post Jun 18, 2026):** Holds are removed; rely on the **boot pin**
instead. The pin is on `7.0.14-4-pve`. Before adopting any future newer kernel, use the
reversible `--next-boot` procedure in
`phases/phase1b_proxmox_kernel_upgrade_safe_try.md` **with physical/console access**,
verify NVMe + ZFS, then make the pin permanent (this is exactly how 6.17.13-13, 7.0.6-2
and 7.0.14-4 were validated).

---

## HOST EMAIL ALERTING (Phase 13, Jul 9 2026) — see phase13 for full detail

All Proxmox-host alerts now reach Andrew's Gmail via app password (PASSWORDS.md "Gmail SMTP Relay"):
- **PVE notifications** (vzdump results, PVE alerts): endpoint `gmail-smtp`
  (smtp.gmail.com:587 STARTTLS) + builtin `default-matcher` retargeted to it.
  Manage: `pvesh get/set /cluster/notifications/...`. Test:
  `pvesh create /cluster/notifications/targets/gmail-smtp/test`
- **Local root mail** (ZED pool events, smartd disk warnings, cron): postfix
  `relayhost = [smtp.gmail.com]:587` + SASL (`/etc/postfix/sasl_passwd`, root-only) +
  `/etc/aliases` root→gmail. `smtp_address_preference = ipv4` (host has no IPv6 route).
  Test: `echo hi | mail -s test root` then check journal for `status=sent ... gsmtp`.
- Rotate credential at Google → Security → App passwords (named "pve").

---

## STORAGE

**Last Verified:** January 14, 2026 (4:35 PM EST)

| Pool | Drives | Type | Size | Usage | Compression | Ratio | Use |
|------|--------|------|------|-------|-------------|-------|-----|
| rpool | 2x WD Blue SN5100 500GB | mirror | 460GB | 11GB (2%) | lz4 ✅ | 1.17x | Proxmox, ISOs |
| vm-critical | 2x Lexar NM620 1TB | mirror | 952GB | 66GB (6%) | lz4 ✅ | 1.40x | GitLab, Sonar, WWW, (OpenClaw) |
| vm-ephemeral | 2x Lexar NM620 1TB | stripe | 1.86TB | 46GB (2%) | lz4 ✅ | ~1.5x | Runner, QA |

**ashift (verified/fixed Jul 9, 2026):** ALL pools now ashift=12 (vm-ephemeral was 9 —
rebuilt Jul 9; NM620s only expose 512B LBA so ashift must be set at pool creation).
ARC cap = **16 GiB** (`/etc/modprobe.d/zfs.conf`, raised from 8 Jul 9).
All pools feature-flag current (zpool upgrade Jul 9).

**Note:** All pools now have lz4 compression enabled. rpool shows 1.00x ratio because existing data is uncompressed (new data will be compressed).

**Drive Serial Numbers:** See `/SYSTEM_VERIFICATION.md` for complete inventory.

---

## PHASES

| # | Name | Status |
|---|------|--------|
| 0-2 | Hardware/Proxmox/Automation | ✅ |
| 12 | Network perimeter lockdown (.184 DMZ) | ✅ IMPLEMENTED July 8, 2026 (see phase12 + current_phase.md) |
| 13 | Proxmox host audit + fixes (Fable) | ✅ AUDIT + quick wins DONE July 9, 2026 (see phase13; maintenance-window items open) |
| 1a | Proxmox kernel upgrade failure + rollback (Jan 12) | ✅ RESOLVED (pinned/held) |
| 1b | Proxmox kernel upgrade — safe retry (→6.17.13-13) | ✅ COMPLETE (Jun 18, 2026, running+pinned) |
| 3 | GitLab Server | ✅ VERIFIED |
| 4 | GitLab Runner | ✅ VERIFIED |
| 5 | CI/CD Pipelines | ✅ COMPLETE (QA + GCP both working!) |
| 6 | SonarQube | ✅ COMPLETE (test-app + Capricorn both integrated!) |
| 7 | Local WWW Server | ✅ COMPLETE (vm-www-1 @ .184, cap + www live!) |
| 8 | Monitoring Stack | 🔲 Planned |
| 11 | OpenClaw AI Agent | ✅ COMPLETE (vm-openclaw-1 @ .185, Feb 20, 2026) |

**Phase docs:** `/phases/`

---

## SONARQUBE

- **URL:** http://192.168.1.183:9000
- **Version:** 26.1.0 (community, latest)
- **Login:** admin / [See PASSWORDS.md]
- **Container:** `sonarqube:community` (Docker)
- **Data:** `/opt/sonarqube/data` (persisted)

**Projects:**
- test-app (token: [See PASSWORDS.md])
  - Quality Gate: PASSED ✅
  - 86 lines of code (HTML, Docker)
  - 0 security issues, 0 bugs, 1 maintainability issue
- capricorn (token: [See PASSWORDS.md])
  - Quality Gate: PASSED ✅
  - 28k lines of code (TypeScript, Python)
  - 5 security issues, 144 reliability issues, 490 maintainability issues

**Note:** Upgraded from 9.9.8 → 26.1.0 (required fresh database)

**Pipeline Integration:** Scan stage runs after build/push, before deploy (allow_failure: true)

---

## WWW SERVER (LOCAL PRODUCTION)

- **VM:** vm-www-1 @ 192.168.1.184
- **RAM:** 8 GB | **CPU:** 8 cores | **Disk:** 50 GB (vm-critical)
- **OS:** Ubuntu 24.04 Desktop
- **URLs:** 
  - https://cap.gothamtechnologies.com (Capricorn PROD)
  - https://www.gothamtechnologies.com (Splash page)
  - https://192.168.1.184 (Direct IP access from internal network)
- **Reverse Proxy:** Traefik v3 (ports 80/443/8080)
- **SSL:** Let's Encrypt (HTTP-01 challenge, auto-renewal)
- **DDNS:** bullpup.ddns.net (Verizon G3100 router-managed)
- **DNS:** AWS Route53 CNAMEs → bullpup.ddns.net

### Docker Network Architecture

**Key Learning:** Traefik must be on BOTH networks to route traffic correctly!

```
web (172.18.0.0/16) - Public-facing network
├── traefik (172.18.0.5)
├── splash (172.18.0.2)
├── capricorn-frontend (172.18.0.4)
└── capricorn-backend (172.18.0.3)

capricorn_capricorn-network (172.19.0.0/16) - Internal application network
├── traefik (172.19.0.6) ← MUST be here to reach backend services!
├── capricorn-frontend (172.19.0.5)
├── capricorn-backend (172.19.0.4)
├── postgres (172.19.0.3) ← NOT on web network (security)
└── redis (172.19.0.2) ← NOT on web network (security)
```

**Why two networks:**
- `web` network: Public-facing services (Traefik, frontend, splash)
- `capricorn_capricorn-network`: Application services + database isolation
- Traefik bridges both networks to route traffic
- Databases stay isolated from public network (security best practice)

### Traefik Configuration

**Location:** `/opt/traefik/`

**docker-compose.yml:**
```yaml
services:
  traefik:
    image: traefik:latest
    networks:
      - web
      - capricorn_capricorn-network  # ← CRITICAL: Must join both networks!
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"  # API/dashboard for debugging
```

**traefik.yml:**
- DEBUG logging enabled (helpful for troubleshooting)
- HTTP-01 challenge for Let's Encrypt
- Auto HTTP→HTTPS redirect
- Docker provider with `exposedByDefault: false`

### Capricorn PROD Deployment

**Location:** `/opt/capricorn/`

**Key Features:**
- Images pulled from GitLab Container Registry
- Traefik labels for routing (both hostname and IP)
- Database initialization via mounted SQL scripts
- Persistent volumes for postgres + redis

**Routing:**
- `cap.gothamtechnologies.com` → frontend + backend (/api)
- `192.168.1.184` → frontend + backend (/api) - for internal access

### Security - Proxmox Firewall

**vm-www-1 Firewall Rules:**
- ✅ IN: SSH (22) from 192.168.1.0/24 ONLY
- ✅ IN: HTTP (80) from anywhere
- ✅ IN: HTTPS (443) from anywhere
- ✅ OUT: Allow all (for apt, docker pulls, Let's Encrypt)
- ❌ NO SSH from internet (blocked by source IP filter)

**Router Port Forwarding (Verizon G3100):**
- 80 → 192.168.1.184:80
- 443 → 192.168.1.184:443
- NO port 22 forwarding (SSH internal only)

### Troubleshooting Notes (Jan 22, 2026)

**Problem 1:** HTTPS timeout, but HTTP worked (redirected to HTTPS)

**Root Cause:** Traefik and Capricorn containers on different networks
- Traefik on `web` network (172.18.0.x)
- Capricorn on `capricorn_capricorn-network` (172.19.0.x)
- Traefik logs showed wrong IPs (172.19.0.5 instead of actual container IPs)

**Solution:**
1. Connected Traefik to capricorn network: `docker network connect capricorn_capricorn-network traefik`
2. Updated `/opt/traefik/docker-compose.yml` to include both networks permanently
3. Containers restarted successfully, traffic flowing

**Lesson:** Multi-service applications with their own networks require reverse proxy to join ALL networks!

---

**Problem 2:** Localhost access not working on vm-www-1 itself (10:00 PM)

**Root Cause:** 
- Traefik routing rules only configured for `cap.gothamtechnologies.com` and `192.168.1.184`
- No routing rule for `localhost` hostname
- `/etc/hosts` didn't have domain name entries for local resolution

**Solution:**
1. Added `/etc/hosts` entries for local domain resolution:
   ```
   127.0.0.1 cap.gothamtechnologies.com
   127.0.0.1 www.gothamtechnologies.com
   ```
2. Updated `/opt/capricorn/docker-compose.yml` with localhost routing:
   - Frontend: Added `traefik.http.routers.capricorn-localhost.rule=Host(\`localhost\`)`
   - Backend: Added `traefik.http.routers.capricorn-api-localhost.rule=Host(\`localhost\`) && PathPrefix(\`/api\`)`
3. Restarted containers: `cd /opt/capricorn && sudo docker compose up -d`

**Result:** Now accessible three ways from vm-www-1:
- ✅ https://localhost (self-signed cert, works)
- ✅ https://192.168.1.184 (self-signed cert, works)
- ✅ https://cap.gothamtechnologies.com (Let's Encrypt cert, trusted)

**Lesson:** Always configure localhost routing for services running on the same machine as the reverse proxy!

### GitLab CI/CD Integration

**Pipeline Stages:** build → push → scan → deploy_qa → deploy_prod

**New Deployment Jobs (production branch):**
- `deploy_prod_local` (manual) → vm-www-1 @ 192.168.1.184
- `deploy_prod_gcp` (manual) → Google Cloud Platform (for interviews)

**Deployment Method:**
- SSH to vm-www-1
- Pull latest images from GitLab registry
- `docker compose up -d` in `/opt/capricorn/`

### Cost Savings

- **Before:** GCP hosting ~$30-45/month (~$400/year)
- **After:** Local hosting ~$2-3/month electricity
- **Savings:** ~$400/year 💰

---

## OPENCLAW

- **VM:** vm-openclaw-1 @ 192.168.1.185 (16GB RAM, 8 cores, 50GB vm-critical)
- **OS:** Ubuntu 24.04 Desktop
- **Version:** 2026.4.5 (updated Apr 6, 2026; prior: 3.13 → 3.22 → 3.23-beta.1 → 3.28 → 4.5)
- **Install Method:** Bash script (`curl -fsSL https://openclaw.ai/install.sh | bash`)
- **Gateway Port:** 1885 (non-default to avoid scanner detection; default is 18789)
- **Gateway Bind:** LAN (0.0.0.0)
- **Gateway Auth:** Token [See working/open-claw-keys.txt]
- **AI Model:** OpenRouter / Anthropic Claude Sonnet 4.6
- **Status:** ✅ LIVE

**Access:**
- **Control UI (HTTPS):** https://vm-openclaw-1.tail8f8df.ts.net/ (via Tailscale Serve)
- **Control UI (localhost):** http://localhost:1885 (from VM only)
- **Telegram Bot:** @OC_GothamBot (DM policy: pairing required)
- **SSH:** ssh agamache@192.168.1.185 (from LAN only)

**Tailscale:**
- **Tailscale IP:** 100.119.212.71
- **Tailscale Serve:** HTTPS proxy on port 443 → localhost:1885
- ~~This is the ONLY VM with Tailscale in the lab~~ **CORRECTION (Jul 9, 2026): the Proxmox
  HOST also runs Tailscale** (tailscaled active on pve, 100.108.209.77). .185 remains the only *VM* with it.

**CRITICAL: Control UI requires HTTPS or localhost!**
- Plain HTTP to LAN IP (http://192.168.1.185:1885) will NOT work -- OpenClaw blocks it
- Must use Tailscale Serve (HTTPS) or access from VM itself (localhost)
- Tailscale Serve provides auto-managed TLS certs via the tailnet domain

**CRITICAL: allowedOrigins required since v2026.2.23!**
- Non-loopback bind (`gateway.bind: "lan"`) now requires `gateway.controlUi.allowedOrigins`
- Without it, the gateway refuses to start (crash loop, exit 1)
- Current config has: `["https://vm-openclaw-1.tail8f8df.ts.net", "http://localhost:1885", "http://127.0.0.1:1885"]`
- If updating OpenClaw in the future, check release notes for similar breaking security changes

**Services (all auto-start on boot):**
- `openclaw-gateway.service` (systemd user service, enabled, lingering)
- `tailscaled.service` (systemd service, enabled)
- Tailscale Serve (persistent via --bg flag)

**Config:** `~/.openclaw/openclaw.json` on vm-openclaw-1 (permissions: 600)
**Config backups on VM:**
- `~/.openclaw/openclaw.json.bak` (auto-created by doctor)
- `~/.openclaw/openclaw.json.bak.pre-fix` (pre-v2026.2.23 fix)
- `~/.openclaw/openclaw.json.bak.pre-v3.28-fix` (pre-v3.28 fix, Apr 6 2026)
- `~/.openclaw/openclaw.json.bak.pre-v4.5-fix` (pre-v4.5 fix, Apr 6 2026)
- `~/.openclaw/openclaw.json.bak.pre-elevenlabs-fix` (pre-ElevenLabs fix, Apr 6 2026)

**TTS (ElevenLabs) — v4.5 config location:**
- Provider credentials go in `messages.tts.providers.elevenlabs` (NOT `plugins.entries` or top-level `messages.tts`)
- Valid keys: `apiKey`, `voiceId`, `modelId`, `baseUrl`, `seed`, `applyTextNormalization`, `languageCode`
**Logs:** `/tmp/openclaw/openclaw-YYYY-MM-DD.log`
**npm global bin:** `/home/agamache/.npm-global/bin` (added to PATH in .bashrc)

**Installed Skills:** github, himalaya (email), nano-pdf, summarize, blogwatcher, goplaces
**Google Places API Key:** configured in openclaw.json

**Proxmox Firewall (VM 185):**
- IN: SSH (22/tcp) from 192.168.1.0/24
- IN: OpenClaw Control UI (1885/tcp) from 192.168.1.0/24
- IN: Tailscale (41641/udp) from anywhere
- OUT: Allow all
- Default IN policy: DROP

**CLI Commands (must use localhost due to HTTPS enforcement):**
```bash
export PATH=/home/agamache/.npm-global/bin:$PATH
openclaw devices list --url ws://127.0.0.1:1885 --token [See working/open-claw-keys.txt]
openclaw devices approve <requestId> --url ws://127.0.0.1:1885 --token [See working/open-claw-keys.txt]
openclaw gateway status
openclaw gateway restart
openclaw doctor --non-interactive
openclaw status --all
sudo tailscale serve --bg 1885
```

**Update procedure (safe):**
```bash
# 1. Back up config FIRST
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak.pre-update

# 2. Update (pick one)
curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard
# Or: npm update
npm i -g openclaw@latest

# 3. Try doctor first (may not fix everything)
openclaw doctor --fix --non-interactive

# 4. Check if gateway started
openclaw gateway status

# 5. If still crash-looping, check the error and fix config manually:
journalctl --user -u openclaw-gateway.service -n 20 --no-pager
# Then edit ~/.openclaw/openclaw.json to remove offending keys
# Then: openclaw gateway restart

# 6. Final verification
openclaw status --all
```

**Rollback (if update breaks things):**
```bash
npm i -g openclaw@<version>   # e.g. openclaw@2026.2.19-2
openclaw doctor
openclaw gateway restart
```

**Reference:** Ansible playbook at `working/openclaw-ansible/` (not used, kept for reference)
**Phase Plan:** `phases/phase11_openclaw.md`

**SSH:** Key auth from dev workstation ✅ FIXED (Feb 27, 2026 — `ssh-copy-id` via sshpass, same as all other VMs)

**SSHFS Mount (Dev Workstation → OpenClaw):**
- **Mount point:** `/home/agamache/mnt/openclaw` (mounts remote `/home/agamache`)
- **Symlink:** `~/openclaw` → `/home/agamache/mnt/openclaw`
- **Service:** `~/.config/systemd/user/sshfs-openclaw.service` (enabled, lingering)
- **Persistence:** Survives reboot (systemd user service + linger enabled)
- **Options:** reconnect, ServerAliveInterval=15, ServerAliveCountMax=3
- **Manage:** `systemctl --user {status|start|stop|restart} sshfs-openclaw`
- **Why user service not fstab:** fstab mounts run as root (wrong SSH keys); user service runs as agamache

**⚠️ KNOWN BUG: Skip v2026.3.22!**
- npm package is missing `dist/control-ui/` directory (packaging bug)
- Control UI shows "assets not found" error
- v3.13 and v3.23+ both have the UI assets; v3.22 does not
- Verify before upgrading: `npm pack openclaw@<version> --dry-run | grep control-ui/`

**⚠️ POST-UPGRADE: Always run doctor, then verify manually!**
- v2026.3.28: Changed TTS config schema, renamed `streamMode` → `streaming`
- v2026.4.5: Tightened plugin entries (only `enabled`/`hooks` allowed); moved TTS creds to `messages.tts.providers.<name>`
- Doctor FAILED to auto-fix plugin config issues in v4.5
- Gateway crash-loops if config has unrecognized keys
- **After ANY upgrade:** back up config, run `openclaw doctor --fix --non-interactive`, then `openclaw gateway status`
- **If doctor fails:** check `journalctl --user -u openclaw-gateway.service -n 20`, inspect config, remove offending keys
- **Schema discovery:** `openclaw config schema | python3 -c "import sys,json; ..."` to find where keys moved

**Manual TODOs:**
- [x] Configure OpenRouter API key/credits (done, working as of Mar 2026)
- [ ] Test Telegram bot from iPhone

---

## GITHUB

- **Repo:** https://github.com/fiberoptix/home-lab-setup
- **User:** fiberoptix (SSH: ~/.ssh/id_ed25519)
- **Email:** andrew.gamache@gmail.com
- **Credentials:** See `github_credentials.md` (git-ignored)

---

## HOME-LAB-SETUP REPO (this repo) — dual-remote (Capricorn method, NO encryption)

Same model as Capricorn/capricorn-docs: SAFE content → GitHub, EVERYTHING → GitLab.
There is NO git-crypt and NO encryption — safety on GitHub comes purely from .gitignore.

- **GitHub (PUBLIC):** https://github.com/fiberoptix/home-lab-setup — remote `origin` (SSH, id_ed25519).
  Curated showcase. Secrets are .gitignore'd and NEVER reach GitHub. Push with: `git push origin main`.
- **GitLab (PRIVATE):** http://gitlab.gothamtechnologies.com/production/home-lab-setup — remote `gitlab`.
  Full plaintext mirror of the ENTIRE working tree (incl. ignored secrets/binaries).
  Auth = HTTP "wallet" baked into the remote URL in .git/config
  (`http://root:<GitLab root pw — see PASSWORDS.md>@gitlab.gothamtechnologies.com/production/home-lab-setup.git`),
  identical to how Capricorn/capricorn-docs authenticate. No SSH key needed for GitLab.
  The real password lives ONLY in .git/config (never pushed) + PASSWORDS.md (gitignored).
- **Push EVERYTHING to GitLab with `./gl-backup.sh "message"`** — it snapshots the whole working
  tree (tracked + ignored, minus .DS_Store) onto `gitlab/main` via a temp index, WITHOUT touching
  the working tree or the GitHub-bound `main`. Do NOT `git push gitlab main` directly (that only
  sends the curated tree, not the secrets). Always use gl-backup.sh for the full private mirror.
- **No auto-push-to-both.** Pushes are explicit; ALWAYS ASK "GitHub, GitLab, or both?" first.
  See the "GIT REMOTES & COMMIT ROUTING" section in CURSOR_RULES.
- **Ignored-and-therefore-GitHub-safe:** PASSWORDS.md, github_credentials.md, proxmox/credentials,
  proxmox/nas_credentials, /working/, /ddns/, *.pem, *.key, *.crt, .env*,
  www/scripts/smb_credentials  (verify: `git check-ignore <f>`).
- **smb_credentials:** `www/scripts/smb_credentials` holds `SMB_PASSWORD='...'`; gitignored (GitHub
  never sees it) but rides the GitLab mirror, so a LAN clone lets setup_smb_mount.sh run unattended.
- **Secret hygiene:** NEVER put real passwords/tokens in tracked files (they go public on GitHub).
  History was purged once already (git filter-repo) after a leak — keep it clean.
- **Branch:** `main` only (docs/scripts repo — no CI/CD or registry like Capricorn).

---

## VM BACKUPS → NAS (Phase 8, June 18 2026) — see phases/phase8_backups.md

- **Why:** GitLab (VM 181) holds private-only data (home-lab-setup full mirror, capricorn-docs,
  registry). ZFS mirror ≠ backup. Whole-VM vzdump → NAS = bare-metal DR.
- **Layout:** NAS NeoCortex (192.168.1.120, SMB only) → share `NeoCortex` →
  `ProxmoxBackups/<hostname>/dump/...`. Per-host subfolder; `dump/` is Proxmox-fixed.
  GitLab → `ProxmoxBackups/vm-gitlab-1/`.
- **Storage:** one CIFS storage **per host** (a storage = one `dump/`). GitLab = **`nas-gitlab`**
  (subdir `/ProxmoxBackups/vm-gitlab-1`, content=backup). Pw root-only at
  `/etc/pve/priv/storage/nas-gitlab.pw`.
- **Job:** `gitlab-nightly` in /etc/pve/jobs.cfg — VM **181**, storage **nas-gitlab**, **02:00 EDT**
  daily, **snapshot** (no downtime), **zstd**, **keep-last=7**. Seed verified (15.3 GB, ~6 min).
- **Add another server:** mkdir `ProxmoxBackups/<host>` → `pvesm add cifs nas-<host> ... --subdir
  /ProxmoxBackups/<host> --content backup` → `pvesh create /cluster/backup --id <host>-nightly
  --storage nas-<host> --vmid <id> ...` (stagger schedules). See phase8_backups.md.
- **Consistency:** app-consistent since Jul 9, 2026 — qemu-guest-agent installed + enabled on
  all live VMs, so vzdump snapshot mode uses fs-freeze/thaw. (Was crash-consistent before.)
- **Restore:** GUI Storage→nas-gitlab→Backups→Restore, or
  `qmrestore /mnt/pve/nas-gitlab/dump/<file>.vma.zst <vmid> --storage <tgt>`. Needs a `vmbr0`.
- **TODO:** one-time proof-of-life test restore (VMID 999, isolated NIC); optionally add jobs for
  VMs 182/183/184/200; offsite/second copy (NAS is a single point).

---

## CAPRICORN PROJECT

- **GitLab:** http://gitlab.gothamtechnologies.com/production/capricorn
- **GitHub:** https://github.com/fiberoptix/capricorn
- **Remotes:** Dual-remote setup (origin=GitHub, gitlab=GitLab)
- **Branches:** develop (QA auto-deploy), production (Local PROD + GCP manual deploy)
- **Production (Local):** https://cap.gothamtechnologies.com (Phase 7 - in progress)
- **Production (GCP):** http://capricorn.gothamtechnologies.com (for interviews)
- **QA (CI/CD):** http://192.168.1.180:5001 ✅ PIPELINE DEPLOYED
- **Local Path:** /home/agamache/DevShare/cursor-projects/unified_ui_DEV_PROD_GCP/capricorn

**Note:** Standard project path is now `unified_ui_DEV_PROD_GCP` (no date suffix)

---

## PASSWORD MANAGEMENT

**PASSWORDS.md** - Central credential storage (git-ignored)
- Contains ALL system passwords and credentials
- All documentation references: [See PASSWORDS.md] (NEVER write real passwords in tracked files)
- Current + deprecated passwords are recorded ONLY in PASSWORDS.md
- Also stored in: `/proxmox/credentials` and `/proxmox/nas_credentials` (git-ignored)

---

## FILES TO READ

1. `PASSWORDS.md` - All credentials
2. `SYSTEM_VERIFICATION.md` - Complete hardware inventory, drive serials, VM configs (Jan 14, 2026)
3. `/phases/current_phase.md` - Current work status
4. `/phases/phase0_hardware.md` - Hardware specs and BIOS settings
5. `/phases/phase1_proxmox.md` - ZFS configuration and best practices
   - `/phases/phase1a_proxmox_upgrade_fail_rollback.md` - Jan 12 kernel failure + rollback
   - `/phases/phase1b_proxmox_kernel_upgrade_safe_try.md` - planned reversible kernel upgrade
6. `/phases/phase5_ci_cd_pipelines.md` ✅ COMPLETE
7. `/phases/phase6_sonarqube.md` ✅ COMPLETE
8. `/phases/phase11_openclaw.md` ✅ COMPLETE
