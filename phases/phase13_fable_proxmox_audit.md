# Phase 13: Proxmox Host Audit (Fable)

**Date:** July 9, 2026 (10:38–10:45 AM EDT)
**Auditor:** AI (Fable 5) — read-only audit. Only change made (approved by Andrew, 11:02 AM):
installed diagnostic tools `nvme-cli`, `numactl`, `lm-sensors`; loaded + persisted the
`coretemp` module (`/etc/modules-load.d/coretemp.conf`) so CPU temps are now readable.
**Scope:** Proxmox HOST ONLY — hardware, firmware, OS, ZFS, and Proxmox VE configuration.
VM guest internals are explicitly OUT of scope (later phase). VM *definitions* (`qm config`)
were reviewed because they live at the Proxmox layer.
**Method:** SSH as root to 192.168.1.150; inspection commands only (lscpu, dmidecode,
smartctl, zpool/zfs/zdb, arc_summary, pvesm, pve-firewall, sshd -T, ss, apt, journalctl, etc.)

---

## Host State at Time of Audit

| Item | Value |
|------|-------|
| Node | `pve` — HP Z6 G4, BIOS P60 v02.96 (2025-06-05) |
| CPU | 1x Xeon Platinum 8168 (24c/48t), intel_pstate, governor=performance, turbo ON |
| RAM | 128 GB (4x 32GB DDR4-2666) — **only 4 of 6 channels populated** (see PERF-3) |
| Kernel | 7.0.6-2-pve (pinned), PVE 9.2.3, ZFS 2.4.2, up 20 days |
| Microcode | 0x2007108 (intel-microcode 3.20251111.1 installed) |
| Pools | rpool (mirror, 2% used), vm-critical (mirror, 71% incl. reservations), vm-ephemeral (stripe, 11%) |
| VMs | 181/182/183/184/200 running; 185 (OpenClaw, retired) stopped, onboot=0 |
| Health | All pools ONLINE 0 errors; all 6 NVMe: 0–1% wear, 0 media errors, temps 25–36°C; no failed systemd units; NTP synced (chrony) |

**Overall:** the host is in good shape — storage healthy, kernel policy sound, firewall
plumbing correct, no failed services, clean scrubs. The findings below are improvements,
not fires. The two biggest gaps are **(1) all automated alerts go nowhere** (no mail relay)
and **(2) SSH allows root password login with no TFA anywhere**.

---

## Executive Summary

| Severity | Count | Highlights |
|----------|-------|------------|
| HIGH | 3 | Dead-end alerting (OPS-1 — ✅ FIXED Jul 9), root password SSH (SEC-1 — ⏸️ deferred), no web-UI TFA (SEC-2 — ⏸️ deferred) |
| MEDIUM | 8 | Stale bookworm repos, pending security updates, ashift=9 on vm-ephemeral, 8GB ARC cap, backup coverage, no restore test, host has no firewall rules, rpcbind exposed |
| LOW | 9 | Snapshots lingering, VM 185 cleanup, pool feature flags, guest agent, fail2ban, AMT verification, ~~no thermal monitoring~~ (fixed Jul 9), doc drift, USB errors |
| INFO | 5 | SMT/CPU vulns accepted, no swap, KSM idle, SNC topology, thick provisioning |

---

## 1. MISCONFIGURATIONS

### MISC-1 — Stale Debian *bookworm* repos alongside *trixie* (MEDIUM) — ✅ FIXED Jul 9
*(Emptied `/etc/apt/sources.list` with explanatory comment; backup `/root/sources.list.bak-20260709`; `apt update` verified clean.)*

`/etc/apt/sources.list` still contains Debian 12 (bookworm) entries while the host runs
PVE 9 on Debian 13 (trixie) via `/etc/apt/sources.list.d/debian.sources`:

```
/etc/apt/sources.list:  deb http://deb.debian.org/debian bookworm main contrib
/etc/apt/sources.list:  deb http://deb.debian.org/debian bookworm-updates main contrib
/etc/apt/sources.list:  deb http://security.debian.org/debian-security bookworm-security main contrib
```

Leftover from the PVE 8→9 upgrade. Mixing suites can confuse the solver and (worst case)
pull an old bookworm version of a package. Everything else is correct: trixie +
`pve-no-subscription` + tailscale; enterprise/ceph repos properly disabled.

**Fix (trivial, safe):** empty the file (`: > /etc/apt/sources.list` or leave only comments),
then `apt update` to confirm clean. **Risk: none.**

### MISC-2 — ~30 pending package updates, several security-tagged (MEDIUM) — ✅ FIXED Jul 9
*(Full-upgrade run: now PVE 9.2.4, 0 packages pending, no failed units, all VMs stayed up.
Kernels 7.0.14-4 + 6.17.13-15 installed to ESPs but pin on 7.0.6-2-pve verified intact — they
will NOT boot until pin-tested per policy. Note: running VMs keep the old QEMU binary until
their next stop/start; no restarts forced.)*

Host was last updated June 18 (uptime 20 days). Pending now includes:
- **Security:** postfix, python3-urllib3, libssh2, libhttp-daemon-perl
- **PVE stack:** pve-manager 9.2.4, qemu-server 9.1.18, pve-qemu-kvm 11.0.2, ZFS userland 2.4.3
- **Kernels:** proxmox-kernel-7.0 → **7.0.14-4** and 6.17.13-15 (will install but NOT boot — pin on 7.0.6-2 governs, per established policy ✅)

**Fix:** run the existing `update` alias. New kernels stay dormant until explicitly
pin-tested with the `--next-boot` procedure (phase1b) — no change to that policy.
Consider scheduling 7.0.14-4 for the next console-access window. **Risk: low.**

### MISC-3 — vzdump backup job covers only VM 181 (MEDIUM)

`jobs.cfg` has one job: `gitlab-nightly` (VM 181 → nas-gitlab, 02:00, snapshot/zstd, keep 7).
Working as designed, but **183 (SonarQube), 184 (WWW/PROD), 200 (QA)** have no VM-level
backup at all. 184 hosts the public production stack; a ZFS mirror is not a backup (documented
in phase8 as a known TODO — elevating it here since 184 is now the public front door).
Also still open: the one-time proof-of-life **test restore** (VMID 999).

**Fix:** add per-host CIFS storages + staggered jobs per the phase8 recipe (e.g. 184 at 02:30,
183 at 03:00); run one test restore. **Risk: none (additive).**

### MISC-4 — `datacenter.cfg` is essentially empty (LOW)

Only `keyboard: en-us`. Missing useful (non-critical) settings: `email_from` (cosmetic until
OPS-1 is fixed), and no explicit `migration:` network (irrelevant single-node).
**Fix:** optional; set `email_from` when mail relay lands. **Risk: none.**

### MISC-5 — Leftover artifacts from retired OpenClaw (VM 185) (LOW)

OpenClaw is retired, but VM 185 still exists (stopped, onboot=0, **cores now 12** — docs say 8),
holds a **50G thick zvol with 50.8G refreservation on vm-critical**, and `185.fw` remains.
**Fix (after Andrew confirms nothing on it is wanted):** take a final vzdump to NAS, then
`qm destroy 185` + remove `185.fw` → frees ~51G of reserved space on the critical pool.
**Risk: destructive — needs explicit approval.**

### MISC-6 — Lingering snapshots (LOW)

- `vm-critical/vm-184-disk-0@pre_phase12_firewall` (Jul 8) — keep until Phase 12 confidence
  window closes, then delete (it grows as .184 diverges).
- ~~`vm-ephemeral/vm-200-disk-0@Generic-Host-Config` (Dec 12, 2025) — **5.14G** and 7 months old~~
  — ✅ DELETED Jul 9 (`qm delsnapshot 200 Generic-Host-Config`), 5.1G freed. The 184 snapshot
  is now the only one remaining (intentionally, for the Phase 12 confidence window).

### MISC-7 — Documentation drift found while auditing (LOW)

1. **Tailscale runs on the Proxmox HOST** (tailscaled 1.98.8 active, IP 100.108.209.77,
   listed in the tailnet as `pve`). MEMORY.md says .185 is "the ONLY VM with Tailscale in
   the lab" — true for VMs, but the host note is missing entirely. This is actually a GOOD
   security asset (admin path independent of LAN), but it must be documented + kept updated.
2. Fallback kernel: ESPs contain only `6.17.13-13` + `7.0.6-2`; `6.17.2-1` (documented as a
   second fallback) is no longer boot-selectable.
3. VM 185 cores = 12 (docs say 8); VM 181 memory = 24596 MB (odd value, docs say 24 GB).

**Fix:** update MEMORY.md when we implement this phase's changes.

---

## 2. PERFORMANCE FINDINGS

### PERF-1 — ZFS ARC capped at 8 GB while ~51 GB RAM sits free (MEDIUM — easy win) — ✅ FIXED Jul 9
*(c_max now 16 GiB: set at runtime via `/sys/module/zfs/parameters/zfs_arc_max` + persisted in
`/etc/modprobe.d/zfs.conf` + initramfs rebuilt. Old conf backed up to `/root/zfs.conf.bak-20260709`.
ARC will warm up to the new cap over hours/days of use.)*

`/etc/modprobe.d/zfs.conf` sets `zfs_arc_max=8589934592` (8 GB). ARC is pegged at 98% of
that cap, i.e. it wants more. The host has 125.6 GB with **51 GB free** even with all
6 VMs' 84 GB provisioned (VMs don't touch all their RAM). All VM disk I/O flows through
ARC (zvols, cache=none), so a larger ARC directly improves guest read performance —
GitLab (git operations) and SonarQube (scans) are exactly the read-heavy workloads that benefit.

**Recommendation:** raise to **16 GB** (conservative; still leaves ~43 GB headroom) —
`zfs_arc_max=17179869184` in zfs.conf + `update-initramfs -u -k all` + either reboot or
runtime `echo 17179869184 > /sys/module/zfs/parameters/zfs_arc_max` (takes effect immediately,
no downtime). Could go to 24 GB later if free RAM stays high. **Risk: low, easily reverted.**

### PERF-2 — vm-ephemeral pool built with ashift=9 (MEDIUM — rebuild to fix)

`zdb` shows the truth (`zpool get ashift` reports the misleading "0/default"):

| Pool | ashift (actual) | Correct for NVMe? |
|------|-----------------|-------------------|
| rpool | 12 (4K) | ✅ |
| vm-critical | 12 (4K) | ✅ |
| **vm-ephemeral** | **9 (512B)** | ❌ |

The Lexar NM620 advertises 512-byte logical sectors, but its flash writes in ≥4K pages.
ashift=9 causes read-modify-write amplification and extra wear on every sub-4K write. It
cannot be changed in place — only at pool creation.

**Confirmed via `nvme id-ns` (Jul 9):** the NM620 exposes ONLY a 512B LBA format (no 4Kn
option), so the drive itself can't be reformatted — the fix is purely `-o ashift=12` at pool
recreation, which is exactly how vm-critical (same drives) was correctly built. Side note:
the WD SN5100 boot drives DO offer a 4096B "Better" format but run 512B; irrelevant in
practice since rpool already uses ashift=12 on top.

**Recommendation:** this is the *ephemeral/rebuildable* pool (Runner + QA), so the fix is
cheap: back up / migrate vm-182 + vm-200 disks (e.g. `qm move-disk` to vm-critical or
vzdump), destroy + recreate the pool with `-o ashift=12` + lz4, move disks back.
~30–60 min of Runner/QA downtime. Also fixes MISC-6's snapshot placement.
**Risk: medium (data moves) — schedule deliberately.**

### PERF-3 — Only 4 of 6 memory channels populated (MEDIUM — hardware $$)

dmidecode: 4x 32GB DDR4-2666 in CPU0-DIMM1..4; DIMM5/6 empty. Skylake-SP has **6 memory
channels per socket** — the current layout gives ~2/3 of the platform's memory bandwidth.
With 24 cores and multiple VMs doing I/O, memory bandwidth is a real ceiling.

**Recommendation (optional, costs money):** add 2x 32GB DDR4-2666 ECC RDIMMs (~$50–80 used)
→ 192 GB *and* full 6-channel bandwidth. Purely optional; noted because it's the single
biggest hardware perf lever available.

### PERF-4 — Sub-NUMA Clustering is ON; docs assume single NUMA node (INFO/LOW)

lscpu shows **2 NUMA nodes on this single socket** (SNC enabled in BIOS), yet all VMs are
created with `numa: 0` per the documented standard ("NUMA disabled for single-socket").
That standard's rationale is stale — the box actually presents 2 nodes, and a 24GB GitLab
VM's memory can straddle them. `kernel.numa_balancing=1` papers over it at some CPU cost.

**Confirmed via `numactl --hardware` (Jul 9):** node0 = 24 threads + 64.1 GB (27.7 free),
node1 = 24 threads + 64.5 GB (25.3 free), inter-node distance 11 vs 10 local — a real but
mild penalty (SNC domains share a die, unlike true dual-socket NUMA).

**Options (pick one):**
- **Simplest:** disable SNC in BIOS → true single node, config matches reality (needs reboot + BIOS access).
- Or enable `numa: 1` on the large VMs (181) so QEMU presents topology.
- Or accept as-is (auto-balancing works; impact modest). **Recommend: disable SNC at next maintenance reboot.**

### PERF-5 — ZFS pool feature flags outdated after 2.4 upgrade (LOW) — ✅ FIXED Jul 9
*(`zpool upgrade` on all three pools: enabled `block_cloning_endian` + `physical_rewrite`.
All pools report feature-current; status warnings gone.)*

All three pools report "Some supported features are not enabled". The host boots via UEFI +
`proxmox-boot-tool` (kernels live on the ESPs, not read from ZFS by the bootloader), so
`zpool upgrade` on rpool is safe on this setup.
**Fix:** `zpool upgrade rpool vm-critical vm-ephemeral` at a quiet moment. One-way operation
(older ZFS software couldn't import), which only matters for rescue media — use a current
PVE ISO for rescue. **Risk: low.**

### PERF-6 — Non-issues verified healthy (INFO)

- **Governor:** `performance` + turbo enabled — correct for a virtualization host.
- **TRIM:** monthly cron trim exists (1st Sunday) + `discard=on` on all VM disks; `autotrim=off`
  is a legitimate choice with scheduled trim. No action.
- **Scrubs:** monthly (2nd Sunday), all clean, seconds-to-90s durations. No action.
- **KSM:** active but 0 pages shared — normal (ksmtuned only engages above ~80% RAM). No action.
- **Disk config standard** (`iothread=1, discard=on, cache=none, aio=native`, virtio-scsi-single)
  is applied consistently on ALL 6 VMs. ✅
- **No swap configured:** standard for PVE-on-ZFS installs; with 40+ GB free RAM this is fine.
  `vm.swappiness=60` is moot. No action (do NOT add swap on ZFS).
- **Thick provisioning (refreservation) on vm-critical:** 654G of 952G reserved (VM 181's 500G
  disk dominates) → pool shows 71% "used" while holding only 66G of real data. This is a *choice*
  (guaranteed space, no overcommit) and consistent with "critical" intent. Note: it limits
  snapshot headroom — snapshots need space *outside* reservations. Acceptable; revisit only if
  more VMs need to land on vm-critical.

---

## 3. SECURITY REVIEW

### SEC-1 — SSH: root login with password enabled (HIGH)

`sshd -T`: `permitrootlogin yes` + `passwordauthentication yes`, port 22 open to the LAN.
The password is the shared lab standard (PASSWORDS.md) — anything on the LAN can brute-force
or reuse it. Notably, **the only key in root's authorized_keys is the host's own** `root@pve`
key (that's why workstation key-auth fails and this audit used the password). The refresh-script
setup copied the workstation *private* key TO the host, but never installed the workstation's
*public* key on it.

**⏸️ DEFERRED (Andrew, Jul 9, 2026):** revisit later. Rationale: LAN-only home lab in a
private apartment; the router/perimeter was just locked down (Phase 12) against external
threats. Accepted risk for now.

**Fix (2 steps, do in order to avoid lockout):**
1. `ssh-copy-id root@192.168.1.150` from the Z8 workstation; verify key login works.
2. Set `PermitRootLogin prohibit-password` + `PasswordAuthentication no` in
   `/etc/ssh/sshd_config.d/hardening.conf`; reload sshd. Keep the Proxmox web console as
   the break-glass path (it doesn't use sshd).

**Risk: low if verified before disabling passwords.** This mirrors what was already done for
the VMs (key auth everywhere since Feb 27) — the host was simply skipped.

### SEC-2 — No TFA on the web UI; single root@pam user (HIGH)

`user.cfg` has exactly one user (root@pam), no TFA configured, no API tokens. The web UI
(:8006) accepts the same shared password from anywhere on the LAN — and the host is on the
tailnet, so tailnet devices can reach it too. Root@pam is the most valuable credential in
the lab (full hypervisor control over the box that runs the public PROD stack).

**⏸️ DEFERRED (Andrew, Jul 9, 2026):** revisit later — same rationale as SEC-1 (LAN-only
home lab behind the freshly locked-down perimeter).

**Fix:** enable **TOTP** for root@pam (Datacenter → Permissions → Two Factor). 5 minutes,
no downtime, huge win. Optionally add a non-root `admin@pve` user for daily use later.
**Risk: keep recovery keys; console access is the fallback.**

### SEC-3 — The host itself has no firewall rules (MEDIUM)

Datacenter firewall is enabled (Phase 12) and VM-level rules work (184/185), but there is
**no `host.fw`** — and PVE's default input policy *for the host* is ACCEPT. Open to the whole
LAN right now: 22 (sshd), 8006 (web UI), 3128 (spiceproxy), 111 (rpcbind), 25 (localhost only ✅).
Phase 12's threat model said "if .184 is popped, it can't pivot" — its OUT rules block that at
VM level, but defense-in-depth at the host would also protect against any *other* compromised
LAN device.

**Fix (careful — lockout potential):** create `/etc/pve/nodes/pve/host.fw` allowing
22 + 8006 from trusted admin IPs (.195, tailnet range 100.64.0.0/10) and dropping the rest of
LAN by default, or at minimum from 192.168.1.184. **Do this from console or with a tested
rule set;** same discipline as Phase 12 (snapshot-equivalent: keep a copy + console open).
**Risk: medium (lockout) — plan carefully or explicitly accept LAN-open as-is.**

### SEC-4 — rpcbind listening on 0.0.0.0:111 with no NFS in use (MEDIUM) — ✅ FIXED Jul 9
*(Disabled rpcbind.socket/.service + nfs-client.target; port 111 verified closed. NAS backups
unaffected — they use CIFS. Reversible with `systemctl enable --now rpcbind.socket nfs-client.target`.)*

`rpcbind` + `nfs-client.target` are enabled/listening but storage uses **CIFS only**
(nas-gitlab). Port 111 is a classic enumeration/amplification target with zero current value.
**Fix:** `systemctl disable --now rpcbind.socket rpcbind.service nfs-client.target`.
**Risk: none unless NFS is planned; trivially reversible.**

### SEC-5 — Intel AMT/ME status unverified; NIC is literally named "amt" (LOW — verify)

The bridge rides the I219-LM port, deliberately renamed `amt` — the port shared with Intel
AMT/vPro out-of-band management (MEI controller present). If AMT is provisioned (or ever gets
provisioned with default creds), it's a below-the-OS admin plane on the production NIC.
The rename suggests this was a conscious choice — but the audit can't see AMT state from the OS.
**Fix:** verify in BIOS (MEBx) that AMT is **disabled/unprovisioned**; document the answer.
If it's intentionally used, it needs a strong MEBx password. **Risk: none (verification).**

### SEC-6 — CPU vulnerability posture (INFO — accept)

Kernel reports mitigations active for Meltdown/Spectre/MDS/L1tf/Retbleed etc., with two accepted gaps:
- **Gather Data Sampling (Downfall): "Vulnerable"** — the installed microcode (0x2007108,
  latest Debian package) doesn't carry the GDS fix for this Skylake-SP stepping.
- **SMT enabled** → L1tf/MDS marked "SMT vulnerable".

Both only matter when *untrusted* code runs in guests. All 6 VMs are Andrew's own workloads;
disabling SMT would cost half the threads. **Recommendation: accept and document.** Revisit
only if untrusted multi-tenant workloads ever land here. Only HTTP(S) to .184 is public, and
that VM can't pivot (Phase 12).

### SEC-7 — Positive security observations (no action)

- Root SSH auth log: **0 failed attempts in 14 days** (quiet LAN, as expected).
- Web UI cert: standard PVE self-signed, valid to Dec 2027.
- Repos properly signed (`signed-by=` everywhere), enterprise repos cleanly disabled.
- Phase 12 firewall rules on 184.fw verified present and exactly as documented. ✅
- Tailscale provides a second, authenticated admin path to the host (document it — MISC-7).
- fail2ban not installed — **fine to skip** given LAN-only SSH + key-only auth once SEC-1 lands.

---

## 4. OPERATIONAL / MONITORING GAPS

### OPS-1 — Every automated alert dead-ends: no mail delivery (HIGH) — ✅ RESOLVED July 9, 2026

**Implemented (11:20 AM, both paths tested and delivered to Gmail):**
1. **PVE notification system:** created SMTP endpoint `gmail-smtp`
   (smtp.gmail.com:587, STARTTLS, auth as andrew.gamache@gmail.com, app password — see
   PASSWORDS.md "Gmail SMTP Relay") and re-pointed the builtin `default-matcher` from the
   dead `mail-to-root` sendmail target to `gmail-smtp`. Covers vzdump results + all PVE alerts.
   Test: `pvesh create /cluster/notifications/targets/gmail-smtp/test` → delivered.
2. **Postfix relay (for ZED/smartd/cron mail to local root):**
   - `/etc/postfix/sasl_passwd` (root-only 600) + postmap
   - `relayhost = [smtp.gmail.com]:587`, SASL auth, `smtp_tls_security_level = encrypt`,
     `smtp_address_preference = ipv4` (host has no IPv6 route; avoids retry noise)
   - `/etc/aliases`: `root: andrew.gamache@gmail.com` + newaliases
   - Test: `mail -s "pve: postfix relay test" root` → `status=sent (250 2.0.0 OK … gsmtp)` ✅
3. **Also installed:** `libsasl2-modules` (was missing; required for Gmail SASL).

**Rollback:** `pvesh set /cluster/notifications/matchers/default-matcher --target mail-to-root`;
`postconf -e "relayhost ="`; remove alias. Credential rotation: Google App passwords page.

**Original finding (for the record):**

The plumbing for alerting exists and is pointed at local `root`… which goes nowhere:
- **ZED** (ZFS events — pool degradation, checksum errors): `ZED_EMAIL_ADDR="root"`
- **smartd** (NVMe pre-failure warnings): `-m root`
- **vzdump** (backup failure notices): defaults to the user email (andrew.gamache@gmail.com in user.cfg)
- But **postfix has no relayhost**, `/etc/pve/notifications.cfg` doesn't exist, `/var/mail` is
  empty, and no root alias is set. A dying disk, a degraded mirror, or 7 consecutive failed
  GitLab backups would all be **silent**.

**Fix:** configure PVE 9's built-in notification system (Datacenter → Notifications) with an
**SMTP target** (Gmail app-password — same credential need as the pending GitLab SMTP TODO),
route vzdump through it, and set postfix relayhost (or a root alias) so ZED/smartd mail also
escapes the box. Then test: `echo test | mail -s "pve test" root`. **Risk: none.**
*(Alternative: fold into Phase 8's Prometheus/Grafana/Alertmanager — but SMTP is 30 minutes
now vs. a phase later; do SMTP first, monitoring stack still valuable.)*

### OPS-2 — No host thermal monitoring (LOW) — ✅ RESOLVED July 9, 2026

`sensors` returned nothing (coretemp module not loaded) — no CPU temperature visibility on a
205W TDP chip. **Fixed during this audit:** installed `lm-sensors`, ran `sensors-detect`,
loaded `coretemp` and persisted it via `/etc/modules-load.d/coretemp.conf`.

**Readings (idle-ish, Jul 9):** all healthy —
- CPU package **51°C** (high 91 / crit 101), cores 47–52°C
- PCH (Lewisburg) 41°C
- NVMe composites 25–35°C
- Quadro P2000 GPU 35°C, fan 2461 RPM (see OPS-4)

`sensors` output now feeds the future Phase 8 monitoring stack (node_exporter picks it up).

### OPS-3 — Minor log findings (INFO)

- **ACPI/hp_bioscfg errors at boot:** HP BIOS quirk noise (WMI methods), harmless, well-known
  on Z-series. A BIOS update may quiet it (P60 v02.96 is from Jun 2025 — check HP for newer,
  optional).
- **USB errors Jul 6** (`usb 1-5.1 error -71`): a flaky USB device/hub — identify or ignore.
- **One CIFS mount failure Jun 18** (transient, NAS storage currently active/healthy).
- **`pveproxy inotify` warnings:** benign, known PVE message.
- **Unsafe shutdown counters (84–92 across drives):** consistent with the January hard-reset
  era; not growing alarmingly; 0 media errors. Watch only.

### OPS-4 — Discovered: NVIDIA Quadro P2000 in the host, idle on nouveau (INFO)

Found while reading the new sensor output: a **Quadro P2000 (5GB)** sits in the box, driven
by the open-source `nouveau` driver, doing nothing but console output (35°C, fan 2461 RPM).
Options if ever wanted: PCI passthrough to a VM (transcoding, CI jobs needing CUDA) or
vGPU-style sharing. No action needed now — just inventory awareness; not previously documented.

---

## 5. PRIORITIZED ACTION PLAN (proposed — nothing done yet)

| # | Action | Finding | Effort | Downtime | Risk |
|---|--------|---------|--------|----------|------|
| 1 | ~~SMTP relay + notifications for ZED/smartd/vzdump~~ ✅ DONE Jul 9 | OPS-1 | — | — | — |
| 2 | Workstation pubkey → host, then disable SSH password auth | SEC-1 | 15 min | none | ⏸️ DEFERRED Jul 9 (home-lab risk acceptance) |
| 3 | TOTP on root@pam web UI | SEC-2 | 5 min | none | ⏸️ DEFERRED Jul 9 (home-lab risk acceptance) |
| 4 | ~~Remove stale bookworm apt entries~~ ✅ DONE Jul 9 | MISC-1 | — | — | — |
| 5 | ~~Full upgrade → PVE 9.2.4 (pin intact)~~ ✅ DONE Jul 9 | MISC-2 | — | — | — |
| 6 | ~~Disable rpcbind/nfs-client~~ ✅ DONE Jul 9 | SEC-4 | — | — | — |
| 7 | ~~Raise ARC cap 8G → 16G~~ ✅ DONE Jul 9 | PERF-1 | — | — | — |
| 8 | Add vzdump jobs for 183/184 (+200?), then test-restore drill | MISC-3 | 1–2 h | none | none |
| 9 | ~~`zpool upgrade` all pools~~ ✅ DONE Jul 9 | PERF-5 | — | — | — |
| 10 | ~~Delete VM 200 snapshot~~ ✅ DONE Jul 9 (184's kept until Phase 12 window closes) | MISC-6 | — | — | — |
| 11 | Decide VM 185 fate → backup + destroy (frees 51G reserved) | MISC-5 | 30 min | none | needs approval |
| 12 | Verify AMT disabled in BIOS; check for BIOS update | SEC-5 | reboot visit | brief | none |
| 13 | Disable SNC in BIOS (same reboot visit as #12) | PERF-4 | same visit | brief | low |
| 14 | Rebuild vm-ephemeral with ashift=12 (move 182/200 disks out/back) | PERF-2 | 1–2 h | Runner+QA ~1h | medium |
| 15 | host.fw for the Proxmox node (console at hand) | SEC-3 | 1 h | none | medium (lockout) |
| 16 | ~~lm-sensors install~~ ✅ DONE Jul 9 (+ nvme-cli, numactl; coretemp persisted) | OPS-2 | — | — | — |
| 17 | (Optional $) 2x 32GB DIMMs → 6-channel bandwidth | PERF-3 | purchase | brief | none |
| 18 | Update MEMORY.md (Tailscale-on-host, kernel fallbacks, VM185 cores) | MISC-7 | 15 min | none | none |

Items 1–10 are a comfortable single session. Items 12–14 want a planned maintenance window
with console access (they combine well with the next kernel pin-test to 7.0.14-4).

---

## Implementation Log — July 9, 2026 (same day as audit)

| Time (EDT) | Action | Result |
|------------|--------|--------|
| 11:02 | Installed nvme-cli, numactl, lm-sensors; persisted coretemp | OPS-2 resolved; new facts fed into PERF-2/PERF-4; found Quadro P2000 (OPS-4) |
| 11:15 | Andrew deferred SEC-1 (SSH hardening) + SEC-2 (TOTP) | Risk accepted: LAN-only lab behind Phase 12 perimeter |
| 11:20 | Gmail SMTP alerting: PVE endpoint `gmail-smtp` + matcher; postfix relayhost + SASL + root alias; libsasl2-modules installed | OPS-1 resolved; both test mails confirmed received by Andrew |
| 11:33 | Emptied stale bookworm sources.list (backup on host) | MISC-1 resolved; apt clean |
| 11:34 | apt full-upgrade → **PVE 9.2.4**, 0 pending; new kernels 7.0.14-4/6.17.13-15 on ESPs, **pin 7.0.6-2 verified intact**; postfix relay survived upgrade | MISC-2 resolved |
| 11:37 | Disabled rpcbind + nfs-client.target (port 111 closed); ARC cap → 16 GiB (runtime + persistent); `zpool upgrade` x3; deleted VM200 snapshot (+5.1G) | SEC-4, PERF-1, PERF-5, MISC-6(part) resolved |

All changes verified: system `running`, no failed units, all 5 production VMs stayed up
throughout, NAS backup storage untouched.

**Still open after today:** backup coverage for 183/184 + test restore (#8), VM 185
decision (#11), maintenance-window items (#12–15: AMT check, SNC off, kernel 7.0.14-4
pin-test, vm-ephemeral ashift rebuild, optional host.fw), RAM purchase (#17), doc sync (#18),
deferred SEC-1/SEC-2.

---

## Appendix: Key Raw Facts

- **Pools:** rpool 460G/11G used; vm-critical 952G/65.9G alloc (654G reserved); vm-ephemeral 1.86T/46.5G. Frag 2%/14%/2%. All lz4, ratios 1.17–1.55x. ashift 12/12/**9**.
- **ARC:** c_max 8 GiB, size 7.9 GiB (98%), free RAM 51 GiB.
- **NVMe wear:** WD SN5100 pair 0% used, 3.57 TBW; Lexar NM620 x4: ≤1% used, 1.0–7.5 TBW. All spare 100%.
- **Listening (LAN-reachable):** 22 sshd, 8006 pveproxy, 3128 spiceproxy, 111 rpcbind, 41641/udp tailscale. 25/85 localhost-only.
- **Firewall:** cluster.fw enable:1; 184.fw (Phase 12 DMZ) + 185.fw present; NO host.fw.
- **Backups:** gitlab-nightly only (VM 181 → nas-gitlab CIFS, 02:00, keep 7); NAS at 67.8% capacity.
- **Kernel/boot:** UEFI + proxmox-boot-tool; ESPs carry 6.17.13-13 + 7.0.6-2; pin = 7.0.6-2-pve; no apt holds.
- **Network:** vmbr0 → `amt` (I219-LM, 1GbE, link up); second NIC `nic` (X722 1GbE) down/unused; Tailscale up (100.108.209.77).
- **Time:** chrony synced (cloudflare + pool peers), EDT correct.
- **VM standard compliance:** all 6 VMs match the documented disk/CPU/net standard (cpu=host, virtio-scsi-single, iothread/discard/cache=none/aio=native, firewall=1). VM 185: cores=12 (doc drift), onboot=0.
- **Thermals (Jul 9, added tooling):** CPU package 51°C (crit 101), PCH 41°C, NVMe 25–36°C, Quadro P2000 35°C / fan 2461 RPM. All comfortable.
- **Tools installed Jul 9 (approved):** nvme-cli, numactl, lm-sensors; `coretemp` persisted in `/etc/modules-load.d/coretemp.conf`.
- **NUMA (numactl):** 2 SNC nodes, 64.1/64.5 GB, distance 10/11.
