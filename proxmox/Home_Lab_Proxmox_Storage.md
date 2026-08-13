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

⚠️ **Gotcha that cost 20 minutes — and the real cause is the FILE FORMAT.**
`/etc/pve/priv/storage/<id>.pw` is **not** a bare password. PVE writes a credentials-style body:

```
password=<the password>          # 9-char password -> 19 bytes on disk, including the newline
```

Pre-placing a file containing **only** the password is therefore malformed, and `pvesm add` fails with
`NT_STATUS_LOGON_FAILURE` — an error that names authentication and sends you hunting for a wrong
password instead of a wrong file format. **Always pass `--password` and let PVE write the file.**

⚠️ **`pvesm set --password` needs `--username` in the SAME call**, even when the storage config already
has `username`. Without it: `storage <id>: ignoring password parameter, no user set`, and it writes a
body with an **empty** password. Verified here on `nas-gitlab`.

⚠️ **The `subdir` is part of the mount source, so it cannot be created through its own storage.** To
add a new per-VM folder, mount the share root once (or reuse a storage scoped one level up), `mkdir`
the folder, then define the storage.

🚨 **`vzdump` does NOT include snapshots** — `INFO: snapshots found (not included into backup)`. The
archive is the **current disk state only**, so a restore yields a VM with no snapshot history. A
`vzdump` is a recovery point; a snapshot chain is not, and neither substitutes for the other.

### ❌ RETRACTED — the "stale nas-gitlab credential" was a measurement error, not a finding

**Aug 13, 2026. Recorded in full because the mistake is more instructive than the false alarm.**

**The claim, briefly believed:** `/etc/pve/priv/storage/nas-gitlab.pw` held a stale password, so the
mount only worked because it predated the change, and the next host reboot would silently end GitLab's
offsite backup.

**Why it looked true.** `wc -c` reported **19 bytes**, which was read as "an 18-character password" — a
different length from the 9-character value in `PASSWORDS.md`. A `smbclient` test with it then failed
`NT_STATUS_LOGON_FAILURE`, while the credential copied off a swarm node succeeded. Two independent
signals agreeing, and both wrong for the same reason.

🚨 **The actual cause: the `.pw` file is `password=<value>` + newline, not a bare password.** For a
9-character password that is exactly 19 bytes. The test authfile was built as
`password=$(cat nas-gitlab.pw)`, which produced **`password=password=Powerme!1`** — a malformed
credential that of course fails to authenticate. **The stored password was correct the whole time**,
and the identical mistake explains the `pvesm add` failure that started the whole detour.

⭐ **The lesson worth keeping: a byte count is not a value, and two tests that share an assumption are
not two independent confirmations.** `wc -c` was used as a proxy for "which password is this", and every
later test inherited the same wrong parse of the file. **When a value's length is the evidence, verify
the format before trusting the comparison** — one `od -c` at the start would have ended it.

**Net effect on the lab:** none, and the storage is verifiably healthier for the round trip.
`nas-gitlab.pw` now holds `password=Powerme!1` (written by `pvesm set --username --password`), and this
is now **proven** rather than assumed: unmounted and remounted **twice**, PVE re-established the mount
both times, all 7 VM 181 archives list, and a write test to `dump/` succeeded. The reboot path that was
never actually broken has now at least been *tested*, which it had not been since June.

⚠️ **The one genuinely true part, kept:** *a working CIFS mount is not evidence of a working
credential*, because CIFS does not re-authenticate a live mount. That risk is real for any long-lived
mount; it just was not being realised here. **Testing it costs one `umount` and is worth doing
deliberately rather than discovering at 2 AM.**

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

