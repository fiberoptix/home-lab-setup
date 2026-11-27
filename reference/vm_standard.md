# VM configuration standard: qm settings, autostart policy, patching policy, RAM

Topic reference (not tied to one phase). Loaded ON TOUCH via `phases/INDEX.md`. Blocks below are copied VERBATIM from `MEMORY.md` as of tag `pre-memory-diet` (Nov 24, 2026).

---

## COPIED VERBATIM FROM `MEMORY.md` @ `pre-memory-diet` (lines 1731–1957) — Nov 24, 2026 (memory-diet, copy-first) — VM CONFIGURATION STANDARD (incl. stale 'Current VMs Feb 20' + RAM table)

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

⚠️ **Changing `cores`/`memory` needs a FULL STOP, not a reboot** — `qm shutdown` → `qm set` → `qm start`.
`qm set` on a RUNNING VM succeeds silently and only stages the change, which looks like success
(measured on VM 186, Aug 12, 2026 — `phase14`; promoted from `current_phase.md` Oct 27, 2026).

### 🚨 AUTOSTART POLICY (Andrew, Aug 20, 2026) — only **SIX** VMs come back after a host reboot
**`onboot 1`: 180, 181, 182, 183, 184, 185. Everything else is `onboot 0` and starts by hand** — that
means **186 (k3s POC) and 191/192/193 (the Docker Swarm)**, all four flipped from `1` to `0` on Aug 20,
plus 200 (retired) and 9000 (template, never set). Rule of thumb: **the always-on service tier
autostarts; lab/POC gear does not.**

> ✅ **Corrected + PROVEN BY A REAL REBOOT, Aug 26, 2026.** This heading said "FIVE" and omitted 185,
> which contradicted the Jenkins note further down in this very section — the file argued with itself.
> The host was powered down for the RAM upgrade and came back with **exactly 180–185 running (six)**
> and **186, 191, 192, 193 stopped**, so the policy is now confirmed by observation rather than by
> reading config. All four `onboot 0` guests were up *before* the shutdown and still came back down:
> ⚠️ **`onboot` describes the next boot, not current state** — "it's running now" tells you nothing
> about whether it will return.

**Boot ORDER, set the same day** (`qm set <id> --startup order=N,up=S`; `up` = seconds to wait *after*
starting that VM before continuing):

| Order | VMs | Delay after |
|---|---|---|
| 1 | **181 GitLab** | `up=60` — everything else that talks to it gets a head start |
| 2 | **182 Runner, 183 SonarQube** | `up=10` each |
| 3 | **180 QA, 184 WWW** | — |

⚠️ **Consequence: 184 (public site) now waits ~80 s longer after a host boot than it used to**, because
it sits behind GitLab's delay. It has no actual dependency on GitLab — **if that ever matters, move it
with `qm set 184 --startup order=1`.** ✅ **No HA resources and no cluster exist, so `onboot` is the sole
authority** — nothing can restart a guest behind your back.

⚠️ **Operational consequence, do not be surprised by it: after any host reboot the Swarm is DOWN.**
Phase 17 deploys Jenkins → Swarm, so `qm start 191 192 193` (and let the cluster converge) is a
**prerequisite step for that work**, not an afterthought. Same for 186 before any k3s work.
✅ **Jenkins (185) BUILT Aug 20, 2026 and joined the autostart tier: `onboot 1`, `startup order=4`
(last).** Andrew's call — it is core infrastructure, and nothing else waits on it to boot.
⭐ **Startup order gives ORDERING, not READINESS.** GitLab CE takes minutes to actually serve, far
longer than its `up=60`, so Jenkins can be up before GitLab can answer an OAuth request no matter what
number it has. **That is not fixable with ordering — it is why Jenkins keeps a break-glass local
admin.**

### 🚨 PATCHING POLICY (Andrew, Aug 20, 2026) — `refresh.sh` is the ONLY way anything gets upgraded

🙋 *"We should disable all auto-upgrades everywhere and only trigger upgrades from the refresh
script."* ✅ **DONE and verified on all 10 VMs** — `unattended-upgrades`, `apt-daily.timer` and
`apt-daily-upgrade.timer` are **`masked`** everywhere.

⭐ **The problem it fixed:** `.180`–`.184` had **two** upgrade mechanisms — `refresh.sh` (deliberate,
windowed, you are watching) **and** `unattended-upgrades` (unscheduled, invisible, will restart a
service mid-job). **Two upgrade paths where one is uncontrolled is worse than either alone**, because
the state you believe you froze can move on its own.

⚠️ **It was never the convention MEMORY implied.** Measured before the change: **masked** on the 3
swarm nodes, **disabled** on `.186`, **enabled** on `.180`, `.181`, `.182`, `.183`, `.184`. *Three
states across nine hosts is an accident, not a policy* — and the boxes where an unscheduled restart
hurts most (GitLab, the runner) were in the `enabled` group.

- **`mask`, not `disable`.** A masked unit is symlinked to `/dev/null` and **cannot be started even as
  another unit's dependency** — which is the whole point, since `apt-daily-upgrade.timer` would
  otherwise pull the service in. `disable` does not stop that.
- 🚨 **Reading `/etc/apt/apt.conf.d/20auto-upgrades` will LIE to you.** It still says
  `APT::Periodic::Unattended-Upgrade "1"` on every masked host. **The timers decide; the config only
  describes.** *The layer that reports is not the layer that decides.*
- **`refresh.sh` now targets `.180`–`.185` and `.187`** (Jenkins added Aug 20; the Phase 20 Rancher VM
  Oct 27 — OS only, reboot-to-Rancher measured at 63 s). ⚠️ **`.186` and `.191`–`.193` are
  masked AND not in `refresh.sh`, so they get NO automatic patching at all** — deliberate (frozen
  known state), but it means patching them is a manual act nothing will remind you about.
- **PVE host `.150` needs nothing:** `unattended-upgrades` is **not installed**, so its apt-daily
  timers refresh package lists but cannot install anything. Host upgrades stay the deliberate pinned
  process from phases 1a/1b. ✅ **Re-verified Sep 28, 2026:** no root crontab, no cron/systemd unit
  calls either script, and 172 packages had sat untouched for 32 days — nothing installs on its own.
- 🆕 **Sep 28, 2026 — THE PHASE 18 k8s NODES `.201`–`.205` WERE THE EXCEPTION, NOW FIXED.** They were
  built Sep 16 without `2-personalize.sh --freeze-updates` (opt-in), and a Sep 17 decision said "do
  not mask" — **reversed Sep 28** (🙋 Andrew: *"We would not have auto-update at work"*; reasoning in
  `phase18`). They had installed kernel `6.8.0-142` and ~20 packages on their own. ✅ **Now masked AND
  stopped on all five**, verified: 0 scheduled apt timers, 0 failed units. ⛔ **They are NOT in
  `refresh.sh` and must never be** (it reboots every target at once → three control planes down →
  etcd quorum lost); they are patched one at a time by the drain drill. ✅ **`c02-virgin-cluster`
  retaken Sep 28 after the mask** (kernel 142, frozen); **`c03-equipped-cluster` (Nov 4) is now the newest and
  the reset point** — it carries the mask too. 🚨 **`c01-nodes-ready` still predates it** —
  after a rollback to `c01`, re-run `2-personalize.sh --freeze-updates` on all five.
  ✅ **All 15 VMs now masked; the other ten also verified `inactive`** (masked is not the same as
  stopped — see next bullet).
- 🚨 **MASKED IS NOT STOPPED, AND `mask --now` LEAVES A TIMER `failed`** (measured Sep 28). `mask`
  alone leaves an already-running timer firing until reboot; `mask --now` masks FIRST, so the running
  timer loses its unit ("Unit to trigger vanished") and lands in `failed`. ⭐ **`systemctl stop` THEN
  `systemctl mask`.** The ten older VMs escaped because `refresh.sh` rebooted them after masking.
  🚨 **`systemctl is-enabled` exits 1 for a masked unit** — `$(systemctl is-enabled u || echo x)`
  yields `masked` + `x`. Capture with `STATE=$(…) || true`.
- ⚠️ **Not covered: snaps.** snapd refreshes on its own timer regardless of the apt masking — `.181`
  refreshed snaps at 16:30 on Sep 28. The k8s nodes have no snaps.
- 🆕 **`proxmox-update.sh` (`update` alias) now runs `apt full-upgrade`, NOT `apt upgrade`**, and is
  in the repo at `proxmox/build-scripts/proxmox-update.sh` (it never was before). ✅ Measured Sep 28 by
  simulation: `apt upgrade` would have **kept back `pve-firewall` and both kernel meta-packages** while
  upgrading `pve-manager` — a mixed-version PVE stack. It now stops on apt failure and reports the pin,
  whether the pin changed, kernels installed-but-not-booted, and the ESP fallback kernels.
- ✅ **HOST UPGRADED Sep 28, 2026: PVE 9.2.4 → 9.2.20** (172 upgraded + 3 new, exit 0, no conffile
  prompts), rebooted 17:13 → back 17:15:56 on the **same pinned `7.0.14-4-pve`**. QEMU 11.0.3-3 (all 15
  VMs verified on it after restart), qemu-server 9.2.10, pve-firewall 6.0.6. ZFS userland **2.4.4** vs
  kmod **2.4.3** until `7.0.14-19` is adopted. Rollback point kept: `rpool/ROOT/pve-1@pre-pve-9.2.20-2026-09-28`. 🔻 **GONE by Nov 24, 2026** (host check, positive control 34 snapshots) — only `pre-pve-9.2.21-2026-10-27` remains on `rpool/ROOT`; nothing is left to "delete".
  🚨 **THE UPGRADE SILENTLY REMOVED THE PROVEN FALLBACK KERNEL FROM THE ESPs.** `proxmox-boot-tool`'s
  automatic selection keeps the newest of each series, so adding `7.0.14-19` and `6.17.13-21` pushed
  **`7.0.6-2` (booted on this box before) and `6.17.13-15` off both ESPs** — the only fallbacks left had
  never booted on this hardware, one from the 6.17 series that caused the VMD NVMe regression. The
  kernels stay installed in `/boot`; they are just no longer bootable. ⭐ **Fixed before the reboot:
  `proxmox-boot-tool kernel add 7.0.6-2-pve` + `refresh`** — it is now a **MANUALLY SELECTED** kernel on
  both ESPs (undo: `kernel remove 7.0.6-2-pve`). ⭐ **After every host upgrade, read the ESP list before
  rebooting — "a fallback exists" is not "a fallback that has booted here exists".**
  ✅ The upgrade did **not** rebuild the pinned kernel's initrd (still dated Jul 25), so that boot was
  byte-for-byte the last good one. ⚠️ `grub-probe: error: unknown filesystem` ×4 during kernel postinst
  — 🟡 believed harmless (host boots via `proxmox-boot-tool`/systemd-boot, and grub cannot probe a ZFS
  root; both ESP copies succeeded), first time recorded.
- ✅ **HOST UPGRADED Oct 27, 2026: PVE 9.2.20 → 9.2.24 AND kernel `7.0.14-26-pve` ADOPTED** (54 upgraded
  + 1 new, exit 0; `--next-boot` trial → permanent pin → second clean reboot; Andrew at the console).
  zfs kmod now **2.4.4 = userland** — mismatch closed. ESPs: **manual `7.0.14-4` + `7.0.6-2`** (both booted
  here), auto `6.17.13-21`, `7.0.14-19`, `7.0.14-26`. Rollback point `rpool/ROOT/pve-1@pre-pve-9.2.21-2026-10-27`.
  Full record: `phase1b` → last section. Two findings that change the PROCEDURE, both now in `phase1b`:
  🚨 **`--next-boot` does NOT auto-revert after a pre-root-mount hang** — it is a persistent
  `loader.conf` default cleared only by a service that runs after root mounts, so a Jan 12-style NVMe
  hang loops; **recovery is picking the old kernel in the systemd-boot menu (3 s timeout).**
  🚨 **Moving the pin drops the OLD pin off the ESPs** — `7.0.14-4` vanished the moment `7.0.14-26` was
  pinned; re-added as manual. ⭐ **Read the ESP list after every upgrade AND after every pin change —
  `update --boot-check` does exactly that without touching apt** (added Oct 27; it also warns if no
  MANUAL fallback besides the pin exists, since the proven fallbacks are kept on the ESPs by hand).
- ⚠️ **After a host reboot, `.186` and `.191`–`.193` stay DOWN** (`onboot=0`, like the k8s nodes) — start
  them by hand if they were running. Sep 28: started again after the reboot.
- 🚨 **Hazard found while doing this — `refresh.sh` can be broken by a REBUILT VM.** It SSHes with
  `StrictHostKeyChecking=accept-new`, which accepts *new* keys but **rejects changed** ones, and its
  **preflight aborts the entire run on the first host it cannot probe.** So a VM rebuilt at a reused
  IP (exactly what `.185` is) leaves a stale host key that **takes down the whole refresh for every
  VM**, not just that one. ⭐ **After rebuilding any VM, SSH to it from the PVE host once by hand
  before the next `refresh`.**

### Current VMs (Last verified Feb 20, 2026)
| VM | CPU | RAM | Disk | Storage | Config |
|----|-----|-----|------|---------|--------|
| **180 - QA** (`vm-docker-qa-1`, IP `.180`) | 8 cores | 12 GB | 100 GB | vm-ephemeral | ✅ Standard — **full clone of the old VMID 200, Aug 20, 2026** (that source VM was destroyed Sep 16, 2026). VMID now matches the IP like every other VM. Only ~15.7 GB is written, but ⚠️ **the zvol RESERVES 116 GB on the pool** — these are thick volumes, so `qm config`'s `size=100G` understates the pool cost and written data understates it further |
| **181 - GitLab** | 8 cores | 24 GB | 500 GB | vm-critical | ✅ Standard |
| **182 - Runner** | 8 cores | 12 GB | 100 GB | vm-ephemeral | ✅ Standard |
| **183 - SonarQube** | 4 cores | 12 GB | 30 GB | vm-critical | ✅ Standard |
| **184 - WWW** | 8 cores | 8 GB | 50 GB | vm-critical | ✅ Standard |
| ~~**185 - OpenClaw**~~ | ~~12 cores~~ | ~~16 GB~~ | ~~50 GB~~ | ~~vm-critical~~ | ⛔ **DESTROYED Aug 19, 2026 — all of it returned to the host.** ⚠️ It held **12 cores, not the 8 recorded here** — measured from `qm config` before the destroy |
| **186 - K8s/Redpanda POC** | 8 cores | 16 GB | 300 GB | vm-ephemeral | ✅ Standard (from template 9000) — **right-sized down from 16c/32 GB Aug 12, 2026** |
| **191 - docker-swarm-1** | 2 cores | 4 GB | 40 GB | vm-ephemeral | ✅ Standard (template 9000) — **built Aug 13, 2026, Phase 16** |
| **192 - docker-swarm-2** | 2 cores | 4 GB | 40 GB | vm-ephemeral | ✅ Standard (template 9000) — **built Aug 13, 2026, Phase 16** |
| **193 - docker-swarm-3** | 2 cores | 4 GB | 40 GB | vm-ephemeral | ✅ Standard (template 9000) — **built Aug 13, 2026, Phase 16** |
| ~~**200 - QA**~~ (old `vm-kubernetes-1`) | — | — | — | — | ⛔ **DESTROYED Sep 16, 2026** — `qm destroy 200 --purge`, no backup (declined: QA is a deploy target, not a data store). The pre-rename QA box, cloned to VMID 180 on Aug 20; rollback window closed Sept 3. Verified gone: config, zvol, and its `pre-clone-20260820` snapshot. **VMID 200 is free.** It had no `200.fw`, no backup job and no storage referencing it, so nothing else moved |
| **9000 - TEMPLATE** | 2 cores | 2 GB | 3.5 GB | vm-ephemeral | 📀 `tmpl-ubuntu-2404-cloudinit` |

### RAM Allocation Strategy
- **GitLab:** 24 GB (memory-hungry, upgraded from 16 GB)
- **SonarQube:** 12 GB (upgraded from 8 GB for large project scans)
- **Runner:** 12 GB (upgraded from 8 GB)
- **QA (`.180`, VMID 180, `vm-docker-qa-1`):** 12 GB (upgraded from 8 GB). Counted once — the old VMID
  200 was destroyed Sep 16, 2026.
- **WWW:** 8 GB (Traefik + Capricorn PROD + splash; + Dionysus PROD and Matomo since Nov 27, 2026 — 5.3 GiB still available that day)
- **~~OpenClaw:~~ 0 GB** — ⛔ **VM 185 destroyed Aug 19, 2026. The 16 GB and 12 cores are actually free
  now, not merely idle.** Phase 17's `vm-jenkins-1` takes 8 GB / 4 vCPU of it, so the lab **nets 8 GB
  and 8 cores.** Host measured **33 GB free** immediately after the destroy.
- **K8s/Redpanda POC (186):** **16 GB** — was 32 GB, sized for 3 Redpanda brokers **+ OpenSearch**.
  OpenSearch (Phase 14 Part 5) was never installed, so **right-sized to 16 GB / 8 cores on
  Aug 12, 2026** after nine days of measurement showed **3.0 GB and ~1% CPU actually in use**.
  The floor is set by pod *requests* (7.7 GB / 3.25 cores), not consumption — 16 GB keeps requests
  at 50% and still fits OpenSearch later if Part 5 is ever revived. Brokers were unaffected: each
  Seastar arena is sized from its container limit (`2560Mi`), not host RAM. Verified healthy 3/3
  with the Part 6 ledger reconciling to exactly 800,000 shares. See
  `phases/phase14_k8s_redpanda_poc.md` → "Right-sized Aug 12, 2026".
- **Docker Swarm nodes (191/192/193):** **4 GB each, 12 GB total** — built Aug 13, 2026, and funded
  exactly by the 16 GB VM 186 gave back the day before. Swarm's control plane is light; CPU
  (2 vCPU each) is the binding constraint, not RAM.
- **Total Allocated — ⭐ RE-BASED Aug 26, 2026 after the RAM upgrade: 104 GB of 192 GB (54%)**,
  measured live from `qm config` across the ten running VMs, with **~87 GB free**.
  🔻 **vCPU CORRECTED Sep 16, 2026: it is 54 of 48 threads assigned (112%), NOT the 42 this line said.**
  Re-summed live from `qm config` across the ten running guests. **So the host is already oversubscribed
  on CPU**, which is the opposite of what the old number implied. ✅ **Measured and accepted, not merely
  tolerated:** PVE's own year RRD reads mean **1.11%**, p95 **2.74%**, max **4.09%**, load **0.70 of 48**.
  ⚠️ **But that year timeframe averages ~8 h per sample, so it CANNOT see short bursts** — the max means
  "no 8-hour window exceeded 4%", not "the host never got busy". For real contention the instrument is
  **`%st` steal time INSIDE the guests**, not host CPU%.
  - *Prior reading (Aug 19, 2026, after 185 was destroyed):* 96 GB of 128 GB (75%), rising to
    **104 GB (81%)** once Phase 17's `vm-jenkins-1` took its 8 GB / 4 vCPU. **The allocation did not
    change on Aug 26 — the denominator did.** Same 104 GB, 81% → 54%.
  - ✅ **The old budget warning is retired.** It read: *"there is no dormant VM left to harvest — the
    next 16 GB has to come from right-sizing something that is running."* That was true at 128 GB and
    is why the sticks were bought. At 192 GB there is roughly **87 GB of genuine headroom**, so new
    VMs no longer require taking RAM from an existing one.
  - ⚠️ **But the ceiling is now physical, not financial.** 192 GB is the maximum this board reaches
    with 32 GB modules (6 slots, 1 CPU, all full). When *this* fills, the answer is not another pair
    of sticks — it is 64 GB modules or a second CPU. Treat 192 GB as fixed when sizing.
  - Note vCPU is **54 of 48 threads assigned** (corrected Sep 16, 2026 — this said 42); the RAM upgrade
    bought no CPU headroom. ⚠️ **CPU is the binding constraint on paper, RAM is not** — but see the
    measured utilisation above before treating that as a limit.

---
