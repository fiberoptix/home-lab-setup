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
| Boot Storage | 2x WD Blue SN5100 500GB NVMe (motherboard M.2 slots) |
| VM Storage | 4x Lexar SSD NM620 1TB NVMe (HP Z Turbo Drive Quad Pro PCIe card) |
| Network | 2x 1GbE onboard NICs (Intel e1000e + i40e) |
| UPS | APC BR1500MS2 (ordered) |

---

## Storage Configuration

### Physical Layout

| Slot | Device | Model | Size | Purpose |
|------|--------|-------|------|---------|
| Motherboard M.2 #1 | nvme0n1 | WD Blue SN5100 | 500GB | Proxmox OS (mirror) |
| Motherboard M.2 #2 | nvme3n1 | WD Blue SN5100 | 500GB | Proxmox OS (mirror) |
| HP Turbo Quad Slot 1 | nvme1n1 | Lexar SSD NM620 | 1TB | vm-critical (mirror) |
| HP Turbo Quad Slot 2 | nvme2n1 | Lexar SSD NM620 | 1TB | vm-critical (mirror) |
| HP Turbo Quad Slot 3 | nvme4n1 | Lexar SSD NM620 | 1TB | vm-ephemeral (stripe) |
| HP Turbo Quad Slot 4 | nvme5n1 | Lexar SSD NM620 | 1TB | vm-ephemeral (stripe) |

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

| Setting | Value | Location | Reason |
|---------|-------|----------|--------|
| Boot Mode | UEFI | Boot Options | Required for Proxmox/ZFS |
| Secure Boot | Disabled | Boot Options | Proxmox compatibility |
| Legacy Support | Disabled | Boot Options | Pure UEFI boot |
| VT-x (Virtualization) | Enabled | Security → Virtualization | VM hardware virtualization |
| VT-d (IOMMU) | Enabled | Security → Virtualization | PCIe passthrough capability |
| PCIe Bifurcation | x4x4x4x4 | Advanced → PCIe Configuration | Required for HP Z Turbo Drive Quad Pro |
| VROC RAID Controller | Enabled | Advanced → Device Configuration | (Later wiped metadata for ZFS) |

---

## What Didn't Work

### Intel VROC (Virtual RAID on CPU)

Originally planned to use Intel VROC for NVMe RAID arrays, but:

1. **ESXi UEFI boot hung** - "Loading Crypto Module" hang with custom VROC driver ISO
2. **ESXi Legacy mode** - Booted but VROC arrays not visible (VROC requires UEFI)
3. **Decision:** Abandon VROC, use ZFS software RAID instead

This led to switching from VMware ESXi to Proxmox VE.

---

## Drive Serial Numbers

**Boot Drives (2x WD Blue SN5100 500GB):**

| Device | Pool | Serial Number |
|--------|------|---------------|
| nvme0n1 | rpool (mirror) | 25434V801543 |
| nvme3n1 | rpool (mirror) | 25434V802501 |

**VM Storage Drives (4x Lexar SSD NM620 1TB):**

| Device | Pool | Serial Number |
|--------|------|---------------|
| nvme1n1 | vm-critical (mirror) | PKG237W103886P1100 |
| nvme2n1 | vm-critical (mirror) | PKG237W103845P1100 |
| nvme4n1 | vm-ephemeral (stripe) | PKG237W103863P1100 |
| nvme5n1 | vm-ephemeral (stripe) | PKG237W103887P1100 |

**To check all serials:**
```bash
lsblk -o NAME,SIZE,MODEL,SERIAL
```

**Why this matters:** If a drive fails in a ZFS mirror, you need the serial number to identify which physical drive to replace.

---

## Lessons Learned

1. **VROC + ESXi = problematic** on HP Z6 G4
2. **ZFS is better** - Native to Linux, no special drivers needed
3. **HP Z Turbo Quad Pro works great** with direct NVMe access
4. **Document drive serial numbers** for future replacement
5. **PCIe bifurcation must be enabled** in BIOS for HP Turbo card

---

## Related Files

- `/proxmox/Home_Lab_Proxmox_Design.md` - Full architecture design
- `/proxmox/Home_Lab_Proxmox_Storage.md` - Detailed ZFS configuration & commands
- `/vmware/` - Abandoned ESXi documentation (reference only)

