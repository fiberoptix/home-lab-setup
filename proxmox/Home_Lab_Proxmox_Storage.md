# Proxmox Storage Configuration

**Created:** December 12, 2025  
**Server:** HP Z6 G4 + Proxmox VE 9.1  
**Total Usable:** ~3.5TB across 3 ZFS pools

---

## Physical Configuration

```
HP Z6 G4 Motherboard:
├─ Onboard M.2 Slot 1: 500GB SSD #1 ─┐
├─ Onboard M.2 Slot 2: 500GB SSD #2 ─┴─ ZFS mirror (rpool) → ~465GB
│
└─ PCIe Slot: HP Z Turbo Drive Quad Pro
    ├─ Slot 1: 1TB SSD #3 ─┐
    ├─ Slot 2: 1TB SSD #4 ─┴─ ZFS mirror (vm-critical) → ~1TB
    ├─ Slot 3: 1TB SSD #5 ─┐
    └─ Slot 4: 1TB SSD #6 ─┴─ ZFS stripe (vm-ephemeral) → ~2TB
```

---

## ZFS Pool Summary

| Pool Name | Proxmox Storage ID | Drives | ZFS Type | Usable | Redundancy |
|-----------|-------------------|--------|----------|--------|------------|
| rpool | local-zfs | 2x 500GB | mirror | ~465GB | ✅ Yes |
| vm-critical | vm-critical | 2x 1TB | mirror | ~1TB | ✅ Yes |
| vm-ephemeral | vm-ephemeral | 2x 1TB | stripe | ~2TB | ❌ No |

---

## Pool Details

### Pool 0: `rpool` (local-zfs)

**Purpose:** Proxmox OS, ISOs, templates, small VMs

```
Drives: 2x 500GB onboard M.2 (motherboard)
ZFS Type: mirror (RAID1 equivalent)
Usable: ~465GB

Proxmox Storage IDs:
├─ local        → /var/lib/vz (ISOs, templates, backups)
└─ local-zfs    → rpool/data (VM disks)

Contents:
├─ Proxmox OS           ~5GB
├─ ISO Library         ~50GB (Ubuntu, etc.)
├─ Traefik VM           5GB
└─ Available          ~400GB
```

**ZFS Properties:**
- Compression: lz4
- ashift: 12

---

### Pool 1: `vm-critical`

**Purpose:** Critical VMs that need redundancy

```
Drives: 2x 1TB on HP Turbo card (slots 1&2)
ZFS Type: mirror (RAID1 equivalent)
Usable: ~1TB

Contents:
├─ GitLab VM          200GB
├─ SonarQube VM        20GB
├─ Monitoring VM       30GB
└─ Available          ~750GB
```

**ZFS Properties:**
- Compression: lz4
- ashift: 12

**Why mirror:**
- GitLab has irreplaceable data (repos, CI configs)
- Drive failure won't lose data
- Can replace failed drive and resilver

---

### Pool 2: `vm-ephemeral`

**Purpose:** Fast, disposable VMs (can rebuild if lost)

```
Drives: 2x 1TB on HP Turbo card (slots 3&4)
ZFS Type: stripe (RAID0 equivalent)
Usable: ~2TB

Contents:
├─ GitLab Runner VM   100GB
├─ QA Host VM         100GB
├─ Build cache        ~500GB
└─ Available         ~1.3TB
```

**ZFS Properties:**
- Compression: lz4
- ashift: 12

**Why stripe (RAID0):**
- Maximum speed for builds/deployments
- 2x read/write performance
- Data is disposable (rebuild from GitLab)
- ⚠️ NO redundancy - drive failure = pool loss

---

## VM Placement Rules

| Storage Pool | VM Types | Why |
|--------------|----------|-----|
| **local-zfs** | Traefik, ISOs, templates | Small, system-level |
| **vm-critical** | GitLab, SonarQube, Monitoring | Needs redundancy |
| **vm-ephemeral** | Runner, QA Host | Speed matters, data disposable |

---

## ZFS Commands Reference

### Check Pool Status
```bash
zpool status
zpool list
```

### Check Pool Health
```bash
zpool status -v
```

### Check Space Usage
```bash
zfs list
```

### Scrub Pool (Check for Errors)
```bash
zpool scrub vm-critical
zpool scrub vm-ephemeral
```

### Replace Failed Drive
```bash
# Find failed drive
zpool status

# Replace (for mirror pool)
zpool replace vm-critical /dev/old-drive /dev/new-drive
```

### Create Snapshot
```bash
zfs snapshot vm-critical/vm-102-disk-0@backup
```

### List Snapshots
```bash
zfs list -t snapshot
```

---

## Drive Identification

All 4x 1TB drives are **Lexar SSD NM620 1TB**

To identify which physical drive is which:
```bash
lsblk -o NAME,SIZE,MODEL,SERIAL
```

| Device | Serial (Partial) | Pool |
|--------|------------------|------|
| nvme4n1 | PKG237W103863... | vm-ephemeral |
| nvme5n1 | PKG237W103887... | vm-ephemeral |
| (check) | (check) | vm-critical |
| (check) | (check) | vm-critical |

**Note:** Document full serial numbers for drive replacement.

---

## Backup Strategy

### Must Backup (vm-critical)

| Data | Backup Method | Frequency |
|------|---------------|-----------|
| GitLab repos | gitlab-backup create | Daily |
| GitLab config | /etc/gitlab backup | Weekly |
| VM snapshots | vzdump | Weekly |

### Can Rebuild (vm-ephemeral)

| VM | Recovery Method |
|----|-----------------|
| Runner | Reinstall Ubuntu, register runner |
| QA Host | Reinstall Ubuntu, deploy from GitLab |

---

## Key Rules

1. ✅ **GitLab on vm-critical** (mirror = redundancy)
2. ✅ **Runner/QA on vm-ephemeral** (stripe = speed)
3. ⚠️ **Stripe (RAID0) = NO redundancy** (one drive fails = pool lost)
4. ⚠️ **RAID ≠ Backup** (still need offsite backups)
5. 📝 **Document serial numbers** (for drive replacement)

---

## Monitoring

### In Proxmox UI
- **pve → Disks** - Physical drive health
- **pve → Disks → ZFS** - Pool status

### S.M.A.R.T. Health
```bash
smartctl -a /dev/nvme0n1
```

### Set Up Email Alerts
Configure ZFS Event Daemon (ZED) to email on errors:
```bash
nano /etc/zfs/zed.d/zed.rc
# Set ZED_EMAIL_ADDR and ZED_EMAIL_OPTS
```

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Dec 12, 2025 | Initial ZFS storage configuration |

