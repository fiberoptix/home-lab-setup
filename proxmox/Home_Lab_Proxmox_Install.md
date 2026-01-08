# Proxmox VE Installation Notes

**Created:** December 12, 2025  
**Server:** HP Z6 G4  
**Proxmox Version:** 9.1-1

---

## Hardware Configuration

**Server:** HP Z6 G4 Workstation

| Component | Specification |
|-----------|---------------|
| CPU | Intel Xeon Platinum 8168 (24 cores / 48 threads) |
| RAM | 128GB DDR4 ECC (4x32GB) |
| Storage | 2x500GB NVMe (motherboard M.2) + 4x1TB NVMe (HP Z Turbo Drive Quad Pro) |
| Network | 2x 1GbE onboard (e1000e + i40e drivers) |
| PCIe Card | HP Z Turbo Drive Quad Pro (passive bifurcation adapter) |

---

## BIOS Configuration (HP Z6 G4)

**Required Settings:**

| Setting | Value | Location |
|---------|-------|----------|
| PCIe Bifurcation | x4x4x4x4 | Advanced → PCIe Configuration → Slot for HP Turbo card |
| VROC RAID Controller | Enabled | Advanced → Device Configuration |
| VT-x (Intel Virtualization) | Enabled | Security → Virtualization |
| VT-d (IOMMU) | Enabled | Security → Virtualization |
| UEFI Boot | Enabled | Boot Options |
| Legacy Support | Disabled | Boot Options |
| Secure Boot | Disabled | Boot Options |

**Note:** VROC RAID arrays created in BIOS will show as `isw_raid_member` in Linux and need to be wiped before ZFS can use them.

---

## Pre-Installation: ESXi Attempt (Failed)

**Problem:** VMware ESXi 8.0U3 would not boot in UEFI mode.
- Hung at "Loading Crypto Module ESX Crypto Module"
- Standard ESXi ISO missing Intel VROC drivers
- Built custom ISO with VROC driver - still hung

**Attempted Fixes:**
- Shift+U (disable UEFI runtime services) - No effect
- noIOMMU boot option - No effect
- ignoreHeadless=TRUE - No effect
- ESXi boots in Legacy mode but VROC arrays not visible

**Decision:** Switched to Proxmox VE (Linux-based, native ZFS support)

---

## Proxmox Installation

### USB Creation

1. Downloaded Proxmox VE 9.1-1 ISO from https://www.proxmox.com/en/downloads
2. Used Rufus on Windows:
   - Partition scheme: GPT
   - Target system: UEFI
   - File system: FAT32

### Installation Options Selected

| Option | Value |
|--------|-------|
| Target Disk | 2x500GB drives (ZFS mirror) |
| Filesystem | ZFS (RAID1) |
| ashift | 12 |
| Compression | lz4 |
| ARC Max Size | Default (left blank) |
| Hostname | pve.local |
| IP Address | 192.168.1.150/24 |
| Gateway | 192.168.1.1 |
| DNS | 192.168.1.1 |
| Management Interface | e1000e (1GbE) |
| Password | capricorn2025 |

---

## Post-Installation: Wipe VROC Metadata

The 4x1TB drives showed `isw_raid_member` (Intel VROC RAID metadata from BIOS setup).

**Fix:** In Proxmox UI:
1. Go to **pve → Disks**
2. Click each 1TB drive
3. Click **"Wipe Disk"** button
4. Confirm wipe

Wiped drives:
- /dev/nvme0n1 (1TB)
- /dev/nvme2n1 (1TB)
- /dev/nvme4n1 (1TB)
- /dev/nvme5n1 (1TB)

---

## ZFS Pool Creation

### Pool 1: vm-critical (UI Method)

1. **pve → Disks → ZFS**
2. Click **"Create: ZFS"**
3. Settings:
   - Name: `vm-critical`
   - RAID Level: `mirror`
   - Compression: `lz4`
   - ashift: `12`
   - Devices: Selected 2x 1TB drives
4. Click **"Create"**

**Result:** ~1TB usable, RAID1 redundancy

### Pool 2: vm-ephemeral (Shell Method)

ZFS UI doesn't have RAID0 option for 2 disks. Created via Shell:

1. **pve → Shell**
2. Commands:
   ```bash
   zpool create vm-ephemeral /dev/nvme4n1 /dev/nvme5n1
   zfs set compression=lz4 vm-ephemeral
   ```

3. Added to Storage via UI:
   - **Datacenter → Storage → Add → ZFS**
   - ID: `vm-ephemeral`
   - ZFS Pool: `vm-ephemeral`
   - Content: `Disk image, Container`

**Result:** ~2TB usable, RAID0 (striped, no redundancy)

---

## Final Storage Configuration

| Pool | ZFS Pool Name | Drives | RAID | Usable Size | Purpose |
|------|---------------|--------|------|-------------|---------|
| local-zfs | rpool | 2x 500GB (motherboard) | mirror | ~465GB | Proxmox OS, ISOs, small VMs |
| vm-critical | vm-critical | 2x 1TB (HP Turbo slots 1&2) | mirror | ~1TB | GitLab, critical VMs |
| vm-ephemeral | vm-ephemeral | 2x 1TB (HP Turbo slots 3&4) | stripe | ~2TB | Runner, QA Host |

**Total Usable:** ~3.5TB

---

## Proxmox Web UI Access

- **URL:** https://192.168.1.150:8006
- **Username:** root
- **Password:** capricorn2025
- **Note:** Self-signed certificate warning is normal - click "Advanced" → "Proceed"

---

## Drive Serial Numbers (for future reference)

All 4x 1TB drives are **Lexar SSD NM620 1TB**:

| Device | Serial Number |
|--------|---------------|
| /dev/nvme4n1 | PKG237W103863P1100 |
| /dev/nvme5n1 | PKG237W103887P1100 |
| (vm-critical drive 1) | (check via `lsblk -o NAME,SERIAL`) |
| (vm-critical drive 2) | (check via `lsblk -o NAME,SERIAL`) |

**To check all serials:**
```bash
lsblk -o NAME,SIZE,MODEL,SERIAL
```

---

## Known Issues

### 1. Subscription Nag
Proxmox shows "No valid subscription" on login. This is normal for free version.
- Proxmox is fully functional without subscription
- To disable nag, see: https://pve.proxmox.com/wiki/No_Subscription_Repository

### 2. apt-get update Error
Error 100 on package update - need to configure repositories.

**Fix:** Configure no-subscription repository:
```bash
# Edit sources
nano /etc/apt/sources.list.d/pve-enterprise.list
# Comment out enterprise repo

# Add no-subscription repo
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list

# Update
apt update
```

---

## Next Steps

1. [ ] Fix apt repositories (subscription nag)
2. [ ] Upload Ubuntu 24.04 ISO
3. [ ] Create GitLab VM
4. [ ] Continue with Build Plan

---

## Lessons Learned

1. **Intel VROC + ESXi = Problematic** - ESXi UEFI boot issues with HP Z6 G4
2. **Proxmox ZFS > VROC** - Native Linux ZFS is simpler and more flexible
3. **Wipe VROC metadata** - Drives show as `isw_raid_member` until wiped
4. **ZFS RAID0 via shell** - Proxmox UI doesn't expose RAID0 for 2-disk pools
5. **Document serial numbers** - Important for drive replacement

---

**Document History:**
- v1.0 (Dec 12, 2025) - Initial installation notes

