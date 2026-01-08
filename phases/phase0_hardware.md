# Phase 0: Hardware Setup & Configuration

**Status:** ✅ Complete  
**Date:** December 2025

---

## Server Hardware

**HP Z6 G4 Workstation**

| Component | Specification |
|-----------|---------------|
| CPU | Intel Xeon Platinum 8168 (24 cores / 48 threads) |
| RAM | 128GB DDR4 ECC (4x 32GB DIMMs) |
| Boot Storage | 2x 500GB NVMe (motherboard M.2 slots) |
| VM Storage | 4x 1TB NVMe (HP Z Turbo Drive Quad Pro PCIe card) |
| Network | 2x 1GbE onboard NICs (Intel e1000e + i40e) |
| UPS | APC BR1500MS2 (ordered) |

---

## Storage Configuration

### Physical Layout

| Slot | Drive | Size | Purpose |
|------|-------|------|---------|
| Motherboard M.2 #1 | nvme0 | 500GB | Proxmox OS (mirror) |
| Motherboard M.2 #2 | nvme1 | 500GB | Proxmox OS (mirror) |
| HP Turbo Quad Slot 1 | nvme2 | 1TB | vm-critical (mirror) |
| HP Turbo Quad Slot 2 | nvme3 | 1TB | vm-critical (mirror) |
| HP Turbo Quad Slot 3 | nvme4 | 1TB | vm-ephemeral (stripe) |
| HP Turbo Quad Slot 4 | nvme5 | 1TB | vm-ephemeral (stripe) |

### HP Z Turbo Drive Quad Pro

- PCIe card with 4x M.2 NVMe slots
- Passive bifurcation (x4x4x4x4)
- No RAID controller - drives appear individually to OS
- Originally configured with Intel VROC (abandoned due to ESXi issues)

---

## Network Configuration

| Port | NIC | Connection | Purpose |
|------|-----|------------|---------|
| MGMT (labeled) | e1000e | Switch | Management interface |
| Port 2 | i40e | Switch | Secondary (unused) |

**Static IP:** 192.168.1.150 (Proxmox host)

---

## BIOS Settings

| Setting | Value | Reason |
|---------|-------|--------|
| Boot Mode | UEFI | Required for Proxmox/ZFS |
| Secure Boot | Disabled | Proxmox compatibility |
| VT-x | Enabled | VM hardware virtualization |
| VT-d | Enabled | PCIe passthrough capability |
| Legacy Support | Disabled | Pure UEFI boot |

---

## What Didn't Work

### Intel VROC (Virtual RAID on CPU)

Originally planned to use Intel VROC for NVMe RAID arrays, but:

1. **ESXi UEFI boot hung** - "Loading Crypto Module" hang with custom VROC driver ISO
2. **ESXi Legacy mode** - Booted but VROC arrays not visible (VROC requires UEFI)
3. **Decision:** Abandon VROC, use ZFS software RAID instead

This led to switching from VMware ESXi to Proxmox VE.

---

## Lessons Learned

1. **VROC + ESXi = problematic** on HP Z6 G4
2. **ZFS is better** - Native to Linux, no special drivers needed
3. **HP Z Turbo Quad Pro works great** with direct NVMe access
4. **Document drive serial numbers** for future replacement

---

## Related Files

- `/proxmox/Home_Lab_Proxmox_Design.md` - Full architecture design
- `/vmware/` - Abandoned ESXi documentation (reference only)

