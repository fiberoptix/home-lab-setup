# Phase 1b: Proxmox Kernel Upgrade — Safe Retry (6.17.2-1 → 6.17.13-13)

**Status:** ✅ COMPLETE — `6.17.13-13-pve` running + permanently pinned (Jun 18, 2026, ~7:10 PM EDT).
No NVMe timeouts, ZFS healthy, all VMs back up. Old `6.17.2-1-pve` kept as fallback.
**Created:** June 18, 2026

---

## ✅ RESULT (Jun 18, 2026)

Executed with all VMs gracefully shut down and console access available.

| Check | Result |
|-------|--------|
| Boot on `6.17.13-13-pve` | ✅ clean, no hang (vs Jan 12 total hang on 6.17.4-2) |
| NVMe timeout/error lines in dmesg | **0** (the prior regression is gone) |
| All 6 NVMe present (behind VMD) | ✅ 2× WD Blue + 4× Lexar |
| ZFS (`zpool status -x`) | ✅ all pools healthy |
| `systemctl is-system-running` | ✅ running |
| VMs auto-started (`onboot=1`) | ✅ 181/182/183/184/185/200 all running |
| Permanent pin | ✅ `6.17.13-13-pve` (ESPs refreshed) |
| Fallback | `6.17.2-1-pve` still installed |

Benign-only log noise: `nvme … PCI INT A: no GSI/not connected` (normal for NVMe
behind VMD using MSI), `using unchecked data buffer` (info), and HP `_SB.WMIV` ACPI
WMI errors (firmware quirk, kernel-independent). None storage-affecting.

**Install method:** dpkg-download (the held `proxmox-default-kernel` still blocked
`apt-get install` on the host) → `--next-boot` one-shot → reboot → verify → permanent pin.

### Follow-on (same session): holds removed + full PVE 9.2 upgrade

- **Unheld** `proxmox-default-kernel` + `proxmox-kernel-6.17.2-1-pve-signed` → holds now NONE.
- First `apt full-upgrade` failed: `proxmox-default-kernel : Depends: proxmox-kernel-6.17
  but it is not installed`. **Root cause** (same error that blocked tmux earlier): the
  `proxmox-kernel-6.17` **metapackage** was never installed — only the specific image was.
  Fix: `apt-get install proxmox-kernel-6.17` (deps already satisfied, adds only the meta).
- Re-ran `apt full-upgrade` → clean. **PVE 9.1.4 → 9.2.3** (pve-manager 9.2.3, qemu-kvm
  11.0, ZFS 2.4.2, systemd 257.13, new shim/systemd-boot, ~160 pkgs, 0 removed).
- PVE 9.2 pulled in a NEW default kernel **`7.0.6-2-pve`** — installed + on ESPs but
  **NOT pinned**, so it will not boot. Adopt later via this same `--next-boot` procedure.

**Outstanding (optional):**
- **Reboot** to fully activate systemd/libc/QEMU 11 (boots pinned `6.17.13-13`).
- After a soak, optionally **purge** `6.17.2-1` and/or test-adopt `7.0.6-2`.

---
**Type:** Maintenance / risk-managed kernel upgrade (reversible)
**Requires:** Maintenance window + console/physical access to the Proxmox box (Z6 G4)
**Related:** failure/rollback history in `phases/phase1a_proxmox_upgrade_fail_rollback.md`

---

## Goal

Get the Proxmox host off the pinned/held `6.17.2-1-pve` kernel and onto a current
6.17 kernel (`6.17.13-13-pve`), **without** repeating the Jan 12, 2026 boot failure
(see `phase1a`). Secondary benefit: clears the `apt-mark hold` that currently breaks
normal `apt install` on the host (the reason tmux had to be installed via dpkg).

## Background — what happened before

Full detail in **`phases/phase1a_proxmox_upgrade_fail_rollback.md`** and `MEMORY.md`
→ "PROXMOX KERNEL MANAGEMENT".

Jan 12, 2026: routine update bumped `6.17.2-1-pve → 6.17.4-2-pve`. On reboot **all
NVMe drives timed out and the host hung at boot**. Recovered via GRUB → old kernel,
then pinned `6.17.2-1-pve`, held `proxmox-default-kernel` +
`proxmox-kernel-6.17.2-1-pve-signed`, and purged the bad kernel.

## Hardware context (verified Jun 18, 2026)

- **Host:** HP **Z6 G4**, single Xeon Platinum 8168 (24c/48t), 128 GB RAM
- **Intel VMD ENABLED** (`8086:201d` x2, `vmd` module loaded) — NVMe sits behind VMD
  (PCI domains `10000:`/`10001:`). This is the configuration the 6.17 regression
  hits hardest.
- **NVMe:** 2× WD Blue SN5100 500GB (rpool boot mirror), 4× Lexar NM620 1TB
  (vm-critical mirror + vm-ephemeral stripe). All pools currently healthy.
- **BIOS:** HP P60 **v02.96** — already the **latest** for Z6/Z8 G4 (no newer exists;
  2.97 is Z4 G4 only). 2.96 is anti-rollback; leave BIOS untouched.

## Evidence the regression is fixed in newer kernels

- Ubuntu bug #2142040: "NVMe timeout regression in kernel 6.17 (works in 6.14)" —
  recognized upstream regression (PCI "device readiness with Configuration RRS",
  commit `d591f6804e7e`; quirk fixes followed).
- Proxmox forum "ZFS and NVMe issues with PVE Kernel 6.17" — exact `6.17.4-2-pve`
  NVMe identify failures, fixed by reverting.
- **Solidigm/Dell Precision 7820 (Xeon Gold 6130/6140 + VMD — same platform class):**
  6.17.4-2 panics, 6.14 fine, **and "6.17.9-1-pve resolves the problem."**
- Repo now has `6.17.9-1` and `6.17.13-1 … 6.17.13-13` (current default candidate).

**Caveat:** No report confirms the *exact* Z6 G4 + this VMD config. Promising, not
guaranteed → must be reversible.

## Target

- New kernel: **`proxmox-kernel-6.17.13-13-pve-signed`** (latest; most fixes on top
  of the 6.17.9 fix). Fallback choice: `6.17.9-1-pve` (the specifically-confirmed one).

---

## Procedure (reversible)

### 0. Pre-flight (no changes)
```bash
pveversion
uname -r                                   # expect 6.17.2-1-pve
zpool status -x                            # expect: all pools healthy
proxmox-boot-tool kernel list              # note pinned = 6.17.2-1-pve
proxmox-boot-tool status                   # note ESP partitions
apt-mark showhold                          # proxmox-default-kernel, ...6.17.2-1...-signed
df -h /                                     # confirm rpool free space
```
- Confirm console/physical access is available before proceeding.
- (Optional) Confirm VM autostart list so we can verify recovery after reboot.

### 0.5 Gracefully shut down all guest VMs (start of outage)
All guests have `onboot=1`, so they auto-start after a successful host boot — no
manual start needed. Shut them down cleanly first so a possible hard power-cycle
(if the new kernel hangs) can't crash-corrupt the databases.
```bash
# Running as of Jun 18, 2026: 181,182,183,184,200 (185/openclaw already stopped).
for id in $(qm list | awk 'NR>1 && $3=="running"{print $1}'); do
  echo "shutting down VM $id ..."; qm shutdown "$id" --timeout 300 &
done; wait
qm list                       # confirm ALL show "stopped" before continuing
```
> No qemu-guest-agent on these VMs → `qm shutdown` uses ACPI (Ubuntu honors it).
> If any VM refuses to stop in time, investigate before rebooting the host
> (last resort: `qm stop <id>`).

### 1. Install the new kernel ALONGSIDE the old (old stays installed + pinned)
```bash
apt-get update
# Install the explicit kernel package; this does NOT remove 6.17.2-1 and does NOT
# touch the default-kernel metapackage (avoids pulling the broken dep set):
apt-get install -y proxmox-kernel-6.17.13-13-pve-signed
proxmox-boot-tool kernel list              # should now list BOTH kernels
```
> Keep `6.17.2-1-pve` installed and the permanent pin on it for now. Do NOT
> `apt-mark unhold` yet — we want the permanent pin to remain the safety fallback.

### 2. One-shot boot into the new kernel
```bash
proxmox-boot-tool kernel pin 6.17.13-13-pve --next-boot
```
- `--next-boot` applies for the **next boot only**. If it hangs, a power-cycle
  automatically reverts to the permanently-pinned `6.17.2-1-pve` — no manual GRUB
  rescue needed (unlike Jan 12).

### 3. Reboot (maintenance window, console attached)
```bash
reboot
```

### 4. Verify on the new kernel
```bash
uname -r                                   # expect 6.17.13-13-pve
zpool status -x                            # all pools healthy
nvme list                                  # all 6 NVMe present
dmesg | grep -iE 'nvme|timeout|vmd'        # NO "timeout"/"Device not ready"/"reset controller"
qm list                                     # VMs present; confirm autostart came up
journalctl -p err -b --no-pager | tail -40 # scan for errors this boot
```
- Soak: let it run, optionally `zpool scrub rpool` and watch for I/O errors.

### 5a. If GOOD → make permanent
```bash
proxmox-boot-tool kernel pin 6.17.13-13-pve        # permanent pin
apt-mark unhold proxmox-default-kernel proxmox-kernel-6.17.2-1-pve-signed
# Keep 6.17.2-1 installed as fallback for now (purge later once confident).
```
- Update `MEMORY.md` (PROXMOX KERNEL MANAGEMENT) + this file's status.

### 5b. If BAD (boot hang / NVMe timeout) → auto-revert + clean up
1. Hard power-cycle → host boots the permanently-pinned `6.17.2-1-pve` on its own.
2. Verify recovery:
   ```bash
   uname -r            # back to 6.17.2-1-pve
   zpool status -x     # healthy
   ```
3. Remove the bad kernel and re-confirm holds:
   ```bash
   proxmox-boot-tool kernel unpin 6.17.13-13-pve 2>/dev/null || true
   apt-get purge -y proxmox-kernel-6.17.13-13-pve-signed
   apt-mark showhold   # confirm 6.17.2-1 + default still held
   ```
4. Document the failure here and in `phase1a` (append a "second attempt" note).
5. **Fallback ladder before giving up:** with the host safely back on `6.17.2-1`,
   optionally repeat steps 1–4 targeting the conservative **`6.17.9-1-pve`** (the
   version specifically confirmed working on the comparable Dell 7820 + VMD box).
   If 6.17.9-1 also fails → stay on `6.17.2-1` (re-pinned/held) and try Step 6 cmdline
   mitigations, or wait for a newer kernel.

### 6. Optional mitigations to try BEFORE declaring failure (only if step 4 shows NVMe timeouts on the new kernel)
Add boot params (from the regression research) via `/etc/kernel/cmdline`, then
`proxmox-boot-tool refresh` and one more `--next-boot` attempt:
- `pcie_aspm=off`
- `nvme_core.default_ps_max_latency_us=0`
- `nvme_core.io_timeout=4294967295`

---

## Risks & mitigations

| Risk | Mitigation |
|------|-----------|
| New kernel hangs at boot (NVMe timeout, like Jan 12) | `--next-boot` one-shot + permanent pin on 6.17.2-1 → power-cycle auto-reverts |
| Need manual recovery | Console/physical access required during the window (home lab — available) |
| apt solver pulls unwanted packages | Install the explicit `-signed` kernel pkg, don't unhold default-kernel until verified |
| VMD-specific incompatibility persists | Step 6 cmdline mitigations; else stay on 6.17.2-1 |
| BIOS angle | None — already on latest (2.96), anti-rollback; do NOT touch |

## Rollback summary
Power-cycle → boots pinned `6.17.2-1-pve` automatically → `apt purge` the new kernel.
No BIOS changes, old kernel never removed until success is confirmed.

## Decisions (Jun 18, 2026)
1. ✅ Approved by Andrew.
2. ✅ Target = `6.17.13-13` (latest), with `6.17.9-1` as the fallback rung.
3. ⏳ Execute when Andrew confirms he's at the console (boot-hang recovery needs physical access).
