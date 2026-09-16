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

**✅ CURRENT STATUS (Jan 14, 2026 - 4:35 PM):**
- rpool: compression=lz4 ✅ (enabled, existing data uncompressed, new data will be compressed)
- vm-critical: compression=lz4 ✅ (1.58x compression ratio)
- vm-ephemeral: compression=lz4 ✅ (1.63x compression ratio)

**All pools properly configured with lz4 compression!**

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

---

## DEMOTED VERBATIM FROM `current_phase.md` — Sep 16, 2026

The two January 2026 session blocks below were moved here from `phases/current_phase.md`, which is
specified to hold one `RESUME HERE` block plus one session handoff. They are **history, kept as a
record of what was actually done**. Every live rule they contain already lives in its proper home:
the disk flags and CPU/firewall/autostart standard in `MEMORY.md` → **VM CONFIGURATION STANDARD**,
current RAM allocations in `MEMORY.md` → **RAM Allocation Strategy**, drive serials in
`phase0_hardware.md`, and `sysbench` in `phase2_host_setup_automation.md`.

🚨 **READ THIS BEFORE COPYING ANY COMMAND OUT OF THE FIRST BLOCK: its `cache=writeback` is
SUPERSEDED and applying it today would be a mistake.** `cache=writeback` and `aio=native` are
**incompatible** — `aio=native` needs `cache.direct=on` while `writeback` is buffered — so the
standard is **`cache=none` with `aio=native`**, as recorded in `MEMORY.md` → VM CONFIGURATION
STANDARD. The Jan 12 block lists both together because that pairing was not yet understood.
⭐ This is why a closed session block is worth demoting rather than leaving in place: it reads like
an instruction, it is nine months old, and nothing in its own text says it stopped being true.

### 🎯 Infrastructure Optimization (Jan 12, 2026 - 9:00-9:30 PM)

**What:** Standardized and optimized all 4 VMs for performance and reliability

**Resource Reallocation:**
- GitLab: 16 GB (no change - keep high)
- Runner: 16 GB → **8 GB** (over-provisioned, saves 8 GB)
- SonarQube: 6 GB → **8 GB** (improves scan performance for 28k LOC projects)
- Kubernetes: 16 GB → **8 GB** (only using 2.6 GB with Capricorn running)
- **Total:** 54 GB → 40 GB allocated (14 GB freed, 86 GB available)

**Standardized Configuration (Applied to All VMs):**
1. ✅ CPU type: `host` (was mixed x86-64-v2-AES and host)
2. ✅ Firewall: Enabled on all (SonarQube was missing it)
3. ✅ Auto-start: Enabled on all (only SonarQube had it)
4. ✅ ISO unmount: Removed Desktop ISO from SonarQube
5. ✅ Disk optimizations:
   - `discard=on` - TRIM for ZFS space reclamation
   - `cache=writeback` - 10-30% faster disk writes
   - `aio=native` - Lower CPU overhead, better I/O performance

**Performance Impact:**
- Disk write speed: 10-30% improvement
- CPU overhead: 5-10% reduction
- ZFS efficiency: Better space management
- System reliability: Auto-recovery after Proxmox reboot

**Guest OS Standardization:**
- ✅ `sysbench` installed on all VMs
- ✅ Bash alias added: `sysbench` → runs CPU benchmark with all cores
- ✅ Updated `setup_desktop.sh` to include sysbench for future VMs

**Why This Matters:**
- All future VMs will be built with this standard configuration
- Documented in MEMORY.md "VM CONFIGURATION STANDARD" section
- Ensures consistency, performance, and reliability across the infrastructure

