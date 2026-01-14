# System Verification Report

**Date:** January 14, 2026  
**Purpose:** Verify actual Proxmox configuration matches documentation  
**Status:** ✅ VERIFIED - Documentation updated to match reality

---

## Proxmox Host Configuration

### Kernel
```
Running: 6.17.2-1-pve
Pinned: 6.17.2-1-pve
Status: ✅ Stable (kernel 6.17.4-2-pve has NVMe issues on this hardware)
```

### Storage Pools (ZFS)

| Pool | Size | Type | Drives | Compression | Usage | Status |
|------|------|------|--------|-------------|-------|--------|
| **rpool** | 460GB | mirror | 2x WD Blue SN5100 500GB | OFF ⚠️ | 10.2GB (2%) | ✅ ONLINE |
| **vm-critical** | 952GB | mirror | 2x Lexar NM620 1TB | lz4 ✅ | 51.6GB (5%) | ✅ ONLINE |
| **vm-ephemeral** | 1.86TB | stripe | 2x Lexar NM620 1TB | lz4 ✅ | 40.3GB (2%) | ✅ ONLINE |

**⚠️ Note:** rpool compression should be lz4 (mistake during install). Can be fixed with:
```bash
zfs set compression=lz4 rpool  # Only affects new data
```

**Last Scrub:** January 11, 2026 - 0 errors on all pools

---

## Drive Inventory

### Boot Drives (rpool - Mirror)

| Device | Model | Serial | Status |
|--------|-------|--------|--------|
| nvme0n1 | WD Blue SN5100 500GB | 25434V801543 | ✅ ONLINE |
| nvme3n1 | WD Blue SN5100 500GB | 25434V802501 | ✅ ONLINE |

### VM Storage - Critical (Mirror)

| Device | Model | Serial | Pool | Status |
|--------|-------|--------|------|--------|
| nvme1n1 | Lexar SSD NM620 1TB | PKG237W103886P1100 | vm-critical | ✅ ONLINE |
| nvme2n1 | Lexar SSD NM620 1TB | PKG237W103845P1100 | vm-critical | ✅ ONLINE |

### VM Storage - Ephemeral (Stripe)

| Device | Model | Serial | Pool | Status |
|--------|-------|--------|------|--------|
| nvme4n1 | Lexar SSD NM620 1TB | PKG237W103863P1100 | vm-ephemeral | ✅ ONLINE |
| nvme5n1 | Lexar SSD NM620 1TB | PKG237W103887P1100 | vm-ephemeral | ✅ ONLINE |

---

## Virtual Machines

| VMID | Name | Status | RAM | CPU | Disk | Storage Pool | IP |
|------|------|--------|-----|-----|------|--------------|-----|
| **181** | vm-gitlab-1 | ✅ Running | 16GB | 8 cores | 500GB | vm-critical | 192.168.1.181 |
| **182** | vm-gitrun-1 | ✅ Running | 8GB | - | 100GB | vm-ephemeral | 192.168.1.182 |
| **183** | vm-sonarqube-1 | ✅ Running | 8GB | 4 cores | 30GB | vm-critical | 192.168.1.183 |
| **200** | vm-kubernetes-1 | ✅ Running | 8GB | - | 100GB | vm-ephemeral | 192.168.1.180 |

**Total RAM Allocated:** 40GB of 128GB available (31%)

---

## VM Disk Configuration Standard

All VMs use this configuration (verified on vm-gitlab-1 and vm-sonarqube-1):

```
scsi0: <pool>:vm-<id>-disk-0,aio=native,cache=none,discard=on,iothread=1,size=<size>
```

**Breakdown:**
- `aio=native` - Native Linux AIO (lower CPU overhead)
- `cache=none` - Direct I/O (required for aio=native)
- `discard=on` - TRIM support for ZFS space reclamation
- `iothread=1` - Dedicated I/O thread for better performance

**Note:** cache=none + aio=native is the correct working combination for this hardware.

---

## Network Configuration

**Proxmox Host:**
- IP: 192.168.1.150
- Interface: vmbr0 (bridged to physical NIC)

**All VMs:**
- Bridge: vmbr0
- Firewall: Enabled
- Network type: virtio

---

## Documentation Updates Made

### Files Updated:
1. ✅ `/phases/phase0_hardware.md`
   - Added WD Blue SN5100 boot drive specifications
   - Added all drive serial numbers
   - Updated BIOS settings table
   - Fixed device names (nvme0n1, nvme3n1, etc.)

2. ✅ `/phases/phase1_proxmox.md`
   - Corrected ZFS pool device assignments
   - Added actual storage usage statistics
   - Documented compression settings (rpool=off, others=lz4)
   - Added ZFS management commands section
   - Added backup strategy section

3. ✅ `/CURSOR_RULES`
   - Updated startup reading order to prioritize phase files
   - Made Design.md optional reference

---

## Key Differences Found & Fixed

| Item | Documentation Said | Reality | Action |
|------|-------------------|---------|--------|
| Boot drives | Generic "500GB NVMe" | WD Blue SN5100 500GB | ✅ Updated |
| rpool compression | lz4 (should be) | OFF (mistake) | ⚠️ Documented, fix optional |
| vm-critical serials | Not documented | PKG237...886, PKG237...845 | ✅ Added |
| Device names | nvme0, nvme2, nvme4 | nvme0n1, nvme1n1, nvme4n1 | ✅ Fixed |
| Storage usage | Not documented | 51.6GB on vm-critical | ✅ Added |

**Note:** rpool compression=OFF is a configuration mistake from Proxmox install. Best practice is lz4 on all pools. Phase files now document correct procedure for future pools.

---

## Verification Commands Used

```bash
# Storage configuration
zpool status
zpool list
zfs get compression rpool vm-critical vm-ephemeral

# Drive inventory
lsblk -o NAME,SIZE,MODEL,SERIAL

# Kernel version
uname -r
proxmox-boot-tool kernel list

# VM configuration
qm list
qm config 181
qm config 183

# Proxmox storage view
pvesm status
```

---

## Next Steps for Future VM Creation

When creating new VMs, use this verified configuration:

```bash
# Example: Create new VM
qm create <vmid> \
  --name <vm-name> \
  --memory <ram-mb> \
  --cores <num-cores> \
  --cpu host \
  --numa 0 \
  --onboot 1 \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr0,firewall=1 \
  --scsi0 <pool>:0,iothread=1,discard=on,cache=none,aio=native,size=<size>G
```

**Pool Selection:**
- Use `vm-critical` for: GitLab, SonarQube, Monitoring, databases
- Use `vm-ephemeral` for: Runner, QA Host, test VMs

---

## Health Check Schedule

| Task | Frequency | Command |
|------|-----------|---------|
| ZFS Scrub | Monthly | `zpool scrub rpool vm-critical vm-ephemeral` |
| S.M.A.R.T. Check | Quarterly | `smartctl -a /dev/nvme0n1` (repeat for all drives) |
| Backup Verification | Monthly | Test restore from GitLab backup |
| Kernel Check | After updates | `proxmox-boot-tool kernel list` |

---

**Verified by:** AI Assistant  
**Date:** January 14, 2026  
**Status:** All documentation now matches production configuration
