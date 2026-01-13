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

| Pool | Command | Purpose |
|------|---------|---------|
| `local-zfs` | (created during install) | Proxmox OS, ISOs |
| `vm-critical` | `zpool create vm-critical mirror /dev/nvme2n1 /dev/nvme3n1` | Important VMs |
| `vm-ephemeral` | `zpool create vm-ephemeral /dev/nvme4n1 /dev/nvme5n1` | Rebuildable VMs |

Enabled compression on all:
```bash
zfs set compression=lz4 vm-critical
zfs set compression=lz4 vm-ephemeral
```

### Wiping VROC Metadata

The 4x 1TB drives had Intel VROC RAID metadata. Wiped via Proxmox UI:
1. Datacenter → Node → Disks
2. Selected each 1TB drive
3. Clicked "Wipe Disk"

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

### Storage Summary

```
NAME           SIZE  ALLOC   FREE  HEALTH
local-zfs      464G   2.5G   462G  ONLINE  (mirror, Proxmox OS)
vm-critical    928G    96K   928G  ONLINE  (mirror, redundant)
vm-ephemeral  1.81T   132K  1.81T  ONLINE  (stripe, no redundancy)
```

### ISO Storage

Uploaded Ubuntu 24.04 LTS Server ISO to `local-zfs` for VM creation.

---

## Proxmox Tips Learned

1. **Subscription popup** - Normal, just dismiss it (no-subscription is fine for home lab)
2. **ZFS ARC** - Set max to ~10% of RAM for good performance
3. **Stripe vs Mirror** - Use mirror for important data, stripe for speed on rebuildable VMs
4. **Web UI** - Most tasks easier via UI than CLI

---

## Related Files

- `/proxmox/Home_Lab_Proxmox_Install.md` - Detailed install notes
- `/proxmox/Home_Lab_Proxmox_Storage.md` - Storage configuration details
- `/proxmox/Home_Lab_Proxmox_Design.md` - Full architecture plan

