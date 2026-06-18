# Phase 1a: Proxmox Kernel Upgrade Failure & Rollback (Jan 12, 2026)

**Status:** ✅ RESOLVED (host pinned/held on stable kernel)
**Host:** HP Z6 G4 @ 192.168.1.150 (single Xeon Platinum 8168, 128GB, Intel VMD + NVMe)
**Related:** forward-looking retry plan in `phases/phase1b_proxmox_kernel_upgrade_safe_try.md`

> Moved here from `current_phase.md` (Jun 18, 2026) to keep the kernel history with
> the rest of the Proxmox-host (phase 1) documentation.

---

## 🔥 Critical Incident: Proxmox Kernel Issue (Jan 12, 2026 - 9:00-9:22 PM)

**What Happened:**
1. ✅ Enabled Proxmox community repository (pve-no-subscription)
2. ✅ Disabled subscription nag popup
3. ✅ Created `update` script (`/usr/local/bin/proxmox-update.sh`)
4. ⚠️ Ran updates: kernel upgraded 6.17.2-1 → 6.17.4-2
5. 🔴 **REBOOT FAILED:** NVMe timeout errors on all disks
6. 🔴 System hung at boot (cpu_startup_entry messages)

**Root Cause:**
- Kernel 6.17.4-2-pve has NVMe driver bug incompatible with HP Z6 G4 hardware
- All 4x 1TB NVMe drives timed out during boot
- System unusable

**Resolution Steps:**
1. Hard reset server
2. Interrupted GRUB autoboot (DOWN ARROW key spam)
3. Selected "Advanced Options" → old kernel (6.17.2-1-pve)
4. Booted successfully into old kernel
5. Pinned old kernel: `proxmox-boot-tool kernel pin 6.17.2-1-pve`
6. Held packages: `apt-mark hold proxmox-kernel-6.17.2-1-pve-signed proxmox-default-kernel`
7. Removed bad kernel: `dpkg --force-depends --purge proxmox-kernel-6.17.4-2-pve-signed`
8. VMs wouldn't start: discovered disk config incompatibility
9. Fixed disk config: `cache=writeback` → `cache=none` (incompatible with `aio=native`)
10. All VMs started successfully

**Configuration Issues Discovered:**
- ❌ `cache=writeback` + `aio=native` = INCOMPATIBLE
  - aio=native requires cache.direct=on (direct I/O)
  - cache=writeback uses cache.direct=off (buffered I/O)
- ✅ `cache=none` + `aio=native` = WORKING
  - Still benefits from native AIO and discard
  - Not quite as fast as writeback, but stable

**Current Stable State:**
- ✅ Running kernel: 6.17.2-1-pve (pinned, held)
- ✅ All 4 VMs running with corrected disk config
- ✅ Update script works, won't upgrade kernel (held)
- ✅ Subscription nag disabled
- ✅ Bad kernel completely removed from system
- ✅ GRUB menu only shows working kernel

**Lessons Learned:**
1. Test kernel updates in maintenance window (not during active development)
2. Always have GRUB access ready for kernel rollback
3. QEMU disk options have strict compatibility rules
4. Proxmox kernel updates can break specific hardware (NVMe controllers)
5. `proxmox-boot-tool kernel pin` is the proper way to lock kernels
6. apt-mark hold prevents accidental kernel upgrades

**Updated Documentation:**
- MEMORY.md: VM Configuration Standard (corrected cache=none)
- MEMORY.md: New "PROXMOX KERNEL MANAGEMENT" section
- MEMORY.md: Compatibility warnings for disk options
- All changes documented for future VM builds

**Time Lost:** ~90 minutes (but learned critical recovery procedures!)

---

## Current protection (as of Jun 18, 2026)

```bash
# Pinned kernel (always boots this one):
proxmox-boot-tool kernel list      # Pinned kernel: 6.17.2-1-pve

# Held packages (won't auto-upgrade):
apt-mark showhold                  # proxmox-default-kernel
                                   # proxmox-kernel-6.17.2-1-pve-signed
```

**⚠️ The hold has a side effect:** normal `apt install <pkg>` on the Proxmox host
fails the dependency solver (`proxmox-default-kernel : Depends: proxmox-kernel-6.17`).
Install host packages via `apt-get download` + `dpkg -i` until the hold is lifted
(see how tmux was installed, Jun 18, 2026).

**Aggravating factor identified later (Jun 18, 2026):** the host boots with **Intel
VMD enabled** (`8086:201d`), and the 6.17 NVMe regression hits VMD-backed NVMe
hardest. The safe retry strategy lives in **`phase1b_proxmox_kernel_upgrade_safe_try.md`**.
