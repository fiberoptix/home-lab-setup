# Phase 1: Proxmox VE Installation & Configuration

**Status:** ✅ Complete  
**Date:** December 12, 2025

---

## Why Proxmox (Not ESXi)

Originally planned VMware ESXi 8.0, but encountered blocking issues:

| Issue | Detail |
|-------|--------|
| UEFI Boot Hang | ESXi hung at "Loading Crypto Module ESX Crypto Module" |
| VROC Driver | Custom ISO with Intel VROC driver didn't resolve |
| Legacy Mode | ESXi booted in Legacy but VROC arrays invisible |

**Solution:** Switched to Proxmox VE - native ZFS support, no driver issues.

---

## Installation

### Proxmox VE Version
- **Version:** 9.1
- **Base:** Debian Bookworm
- **Downloaded:** Official ISO from proxmox.com

### Installation Steps

1. Created bootable USB with Proxmox ISO (Rufus on Windows)
2. Booted HP Z6 G4 from USB
3. Selected "Install Proxmox VE (Graphical)"
4. **Target disk:** Selected ZFS RAID1 on 2x 500GB NVMe (nvme0, nvme1)
5. **ZFS options:**
   - Compression: lz4 (enabled)
   - ARC max: 8192 MiB (8GB)
   - ashift: 12 (default)
6. **Network:** 
   - Interface: e1000e (MGMT port)
   - IP: 192.168.1.150/24
   - Gateway: 192.168.1.1
   - DNS: 192.168.1.1
7. Set root password
8. Completed installation, rebooted

---

## Post-Installation Configuration

### Fix APT Repositories

Default Proxmox uses enterprise repos (requires subscription). Fixed with:

```bash
# Disable enterprise repo
sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list

# Disable Ceph enterprise repo
sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/ceph.list 2>/dev/null

# Add no-subscription repo
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list

# Update
apt update && apt upgrade -y
```

### ZFS Storage Pools Created

After wiping Intel VROC metadata from 1TB drives:

| Pool | Devices | RAID | Command | Purpose |
|------|---------|------|---------|---------|
| `rpool` | nvme0n1, nvme3n1 | mirror | (created during install) | Proxmox OS, ISOs |
| `vm-critical` | nvme1n1, nvme2n1 | mirror | `zpool create vm-critical mirror /dev/nvme1n1 /dev/nvme2n1` | Important VMs |
| `vm-ephemeral` | nvme4n1, nvme5n1 | stripe | `zpool create vm-ephemeral /dev/nvme4n1 /dev/nvme5n1` | Rebuildable VMs |

**ZFS Compression Settings:**
```bash
# ALL pools should have lz4 compression enabled:
zfs set compression=lz4 rpool
zfs set compression=lz4 vm-critical
zfs set compression=lz4 vm-ephemeral
```

**⚠️ CURRENT STATUS (Jan 14, 2026):**
- rpool: compression=OFF (mistake during install - should be lz4)
- vm-critical: compression=lz4 ✅
- vm-ephemeral: compression=lz4 ✅

**To fix rpool (optional):**
```bash
# Enable compression on rpool (only affects new data)
zfs set compression=lz4 rpool

# Existing data won't be recompressed automatically
# To recompress existing data (optional):
# zfs send/receive or copy files to force recompression
```

**Why lz4?**
- Transparent compression (no performance impact)
- Saves 20-40% disk space typically
- CPU overhead is negligible on modern processors
- **Always enable on new pools**

### Wiping VROC Metadata

The 4x 1TB drives had Intel VROC RAID metadata. Wiped via Proxmox UI:
1. Datacenter → Node → Disks
2. Selected each 1TB drive
3. Clicked "Wipe Disk"

---

## Creating New ZFS Pools (Best Practice)

**For future pool creation, ALWAYS enable compression from the start:**

### Mirror Pool (redundancy)
```bash
# Create mirror pool with compression
zpool create <pool-name> mirror /dev/<disk1> /dev/<disk2>
zfs set compression=lz4 <pool-name>

# Example:
zpool create vm-critical mirror /dev/nvme1n1 /dev/nvme2n1
zfs set compression=lz4 vm-critical
```

### Stripe Pool (speed, no redundancy)
```bash
# Create stripe pool with compression
zpool create <pool-name> /dev/<disk1> /dev/<disk2>
zfs set compression=lz4 <pool-name>

# Example:
zpool create vm-ephemeral /dev/nvme4n1 /dev/nvme5n1
zfs set compression=lz4 vm-ephemeral
```

**Why lz4 compression?**
- 20-40% space savings on typical data
- Near-zero CPU overhead (negligible performance impact)
- Transparent to applications
- **ALWAYS enable on new pools**

---

## Final Configuration

### Access

| Method | URL/Command |
|--------|-------------|
| Web UI | https://192.168.1.150:8006 |
| SSH | `ssh root@192.168.1.150` |

### Credentials

Stored in `/proxmox/credentials`:
- Username: root
- Password: [See PASSWORDS.md]

### Storage Summary (Current)

```
NAME           SIZE  ALLOC   FREE  HEALTH    TYPE
rpool          460G  10.2G   450G  ONLINE    mirror (2x WD Blue 500GB)
vm-critical    952G  51.6G   900G  ONLINE    mirror (2x Lexar 1TB)
vm-ephemeral  1.86T  40.3G  1.82T  ONLINE    stripe (2x Lexar 1TB)
```

**Proxmox Storage View:**
```
Name            Type      Status    Total       Used     Available    %
local           dir       active    463 GB      6.2 GB   456 GB      1.34%
local-zfs       zfspool   active    457 GB      96 KB    457 GB      0.00%
vm-critical     zfspool   active    967 GB      564 GB   403 GB      58.36%
vm-ephemeral    zfspool   active    1.9 TB      220 GB   1.7 TB      11.40%
```

**Note:** vm-critical is 58% full with GitLab (500GB) and SonarQube (30GB) VMs.

### ISO Storage

Uploaded Ubuntu 24.04 LTS Server ISO to `local-zfs` for VM creation.

---

## ZFS Management Commands

### Check Pool Status
```bash
zpool status              # Overall health
zpool status -v           # Verbose (show errors)
zpool list                # Capacity usage
zfs list                  # Dataset usage
```

### Maintenance
```bash
# Scrub pool (check for errors, run monthly)
zpool scrub vm-critical
zpool scrub vm-ephemeral

# Check scrub progress
zpool status
```

### Replace Failed Drive (Mirror Only)
```bash
# 1. Identify failed drive
zpool status

# 2. Replace drive (ZFS will resilver automatically)
zpool replace vm-critical /dev/old-drive /dev/new-drive
```

### Snapshots
```bash
# Create snapshot
zfs snapshot vm-critical/vm-181-disk-0@backup

# List snapshots
zfs list -t snapshot

# Rollback to snapshot
zfs rollback vm-critical/vm-181-disk-0@backup
```

### S.M.A.R.T. Monitoring
```bash
# Check drive health
smartctl -a /dev/nvme0n1
```

---

## Backup Strategy

### Critical Data (vm-critical pool)

| Data | Backup Method | Frequency |
|------|---------------|-----------|
| GitLab repos | `gitlab-backup create` | Daily |
| GitLab config | `/etc/gitlab` backup | Weekly |
| VM snapshots | `vzdump` | Weekly |

### Disposable Data (vm-ephemeral pool)

| VM | Recovery Method |
|----|-----------------|
| Runner | Reinstall Ubuntu, register runner (15 min) |
| QA Host | Reinstall Ubuntu, deploy from GitLab (20 min) |

**Key Rule:** RAID ≠ Backup! ZFS mirror protects against drive failure, NOT data corruption or accidental deletion.

---

## Proxmox Tips Learned

1. **Subscription popup** - Normal, just dismiss it (no-subscription is fine for home lab)
2. **ZFS ARC** - Set max to ~10% of RAM for good performance
3. **Stripe vs Mirror** - Use mirror for important data, stripe for speed on rebuildable VMs
4. **Web UI** - Most tasks easier via UI than CLI
5. **RAID0 (stripe) = NO redundancy** - One drive fails = entire pool lost
6. **Scrub monthly** - Catches silent data corruption early

---

## Related Files

- `/proxmox/Home_Lab_Proxmox_Install.md` - Detailed install notes
- `/proxmox/Home_Lab_Proxmox_Storage.md` - Storage configuration details
- `/proxmox/Home_Lab_Proxmox_Design.md` - Full architecture plan

