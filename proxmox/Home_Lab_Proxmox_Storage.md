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
- Compression: lz4 (ALWAYS enable)
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
- Compression: lz4 (ALWAYS enable)
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
- Compression: lz4 (ALWAYS enable)
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

### 📌 STANDING RULE — `vzdump` goes to the NAS, never the NVMe

**Andrew's direction, Aug 13, 2026.** Every VM backup for this project lands on the NAS under
`/ProxmoxBackups/<vm-name>/`. **The NVMe pools are not backup targets.** They are fast, expensive and
— for `vm-ephemeral` — striped with no redundancy, so a "backup" there shares a failure domain with
the thing it is backing up.

**How it is wired.** PVE has no per-VM folder feature: a directory-style storage puts every archive in
one `dump/`. Per-VM folders therefore need **one CIFS storage per VM**, each scoped with `subdir` —
the same pattern the pre-existing `nas-gitlab` entry uses:

```bash
# One-time, per VM. NOTE: --password is REQUIRED (see the gotcha below).
pvesm add cifs nas-<vm-name> \
    --server 192.168.1.120 --share NeoCortex \
    --subdir /ProxmoxBackups/<vm-name> \
    --username fiberoptix --password '<see PASSWORDS.md>' \
    --content backup --prune-backups keep-last=3

# The subdir must ALREADY EXIST on the NAS or the mount fails — PVE does not create it.
vzdump <vmid> --storage nas-<vm-name> --mode stop --compress zstd --notes-template "why"
```

Resulting layout, with PVE creating `dump/` inside each:
`NeoCortex/ProxmoxBackups/<vm-name>/dump/vzdump-qemu-<vmid>-<date>.vma.zst`

Currently defined: `nas-gitlab` (VM 181), `nas-docker-swarm-1/2/3` (VMs 191/192/193, added Aug 13 2026,
`keep-last=3`).

⚠️ **Gotcha that cost 20 minutes: `pvesm add` ignores a pre-placed `/etc/pve/priv/storage/<id>.pw`.**
Its connection check authenticates with what was passed in the API call, so creating the password file
first and omitting `--password` fails with `NT_STATUS_LOGON_FAILURE` **even when the file is correct** —
verified by `smbclient -L` and a manual `mount -t cifs` succeeding with the very same file. The error
names an auth failure, which sends you hunting for a wrong password instead of a missing argument.

⚠️ **The `subdir` is part of the mount source, so it cannot be created through its own storage.** To
add a new per-VM folder, mount the share root once (or reuse a storage scoped one level up), `mkdir`
the folder, then define the storage.

🚨 **`vzdump` does NOT include snapshots** — `INFO: snapshots found (not included into backup)`. The
archive is the **current disk state only**, so a restore yields a VM with no snapshot history. A
`vzdump` is a recovery point; a snapshot chain is not, and neither substitutes for the other.

### 🚨 Latent failure found Aug 13, 2026 — the GitLab NAS backup is one reboot from silence

While wiring the above: **the password stored in `/etc/pve/priv/storage/nas-gitlab.pw` (18 chars) is
stale and no longer authenticates.** A fresh `smbclient` logon with it fails
(`NT_STATUS_LOGON_FAILURE`); the working credential is the 9-character one in `PASSWORDS.md` →
*NAS / SMB Share*, confirmed by copying it off a swarm node that mounted the share successfully the
same day.

**Why nothing has broken yet:** `/mnt/pve/nas-gitlab` has been mounted since **Jun 18** and a live CIFS
mount is not re-authenticated. The nightly 2 AM `vzdump` of VM 181 keeps writing into that mount and
keeps succeeding — the most recent is ~16 GB and looks perfectly healthy.

⭐ **The consequence is the lesson: the next reboot of the Proxmox host silently ends GitLab's offsite
backup.** The mount will fail to re-establish, and the failure will surface as a *backup* problem weeks
later rather than as an *authentication* problem now. **A mount that works is not evidence that the
credential works** — that only gets tested at mount time, which may be months apart from when the
password changed. 🔲 **TODO: fix `nas-gitlab.pw` with the correct credential and prove it by
unmounting and remounting.** Not done here — it touches the GitLab VM's backup path, which is outside
what this session was authorised to change.

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

