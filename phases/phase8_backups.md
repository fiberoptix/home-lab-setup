# Phase 8: VM Backups to NAS (GitLab DR)

**Created:** June 18, 2026 - 9:13 PM EDT
**Status:** OPERATIONAL ✅ (GitLab/VM 181; extendable to other VMs)

---

## Goal

Protect the self-hosted GitLab server (which now holds private-only content that exists
nowhere else: the `home-lab-setup` full mirror incl. `PASSWORDS.md`/credentials, `capricorn-docs`,
and the container registry) against host/storage failure, bad upgrades, corruption, or
accidental deletion. The `vm-critical` ZFS mirror only survives a single disk failure — it is
NOT a backup.

## Why whole-VM (vzdump) instead of app-level gitlab-backup

- Whole-VM `vzdump` captures EVERYTHING in one shot: OS, PostgreSQL, Gitaly repos, uploads,
  artifacts, container registry, AND `/etc/gitlab` secrets (`gitlab-secrets.json`) — the piece
  app-level backups famously forget.
- Restore = bare-metal: build a new Proxmox host, attach the NAS, restore the dump, start the
  VM, and GitLab "just runs" (keeps its IP 192.168.1.181 — that lives inside the guest).
- Trade-off vs `gitlab-backup`: no per-repo granular restore, and full image each run. Fine here.

## What was built (June 18, 2026)

### NAS backup target (off-host = survives host storage failure)
- NAS: **NeoCortex @ 192.168.1.120** (SMB/CIFS; NFS has no exports). Shares: `NeoCortex`, `docker`.
- Layout: a top **`ProxmoxBackups`** folder in the `NeoCortex` share, with a **per-host subfolder**
  inside it; Proxmox then writes into the fixed `dump/` subdir under each host folder:
  ```
  NeoCortex/ProxmoxBackups/
  └── vm-gitlab-1/
      └── dump/            <- Proxmox-fixed subfolder name (NOT configurable)
          └── vzdump-qemu-181-*.vma.zst
  ```
- One Proxmox CIFS storage **per host** (this is how you get per-host folders — a single storage
  can only have one `dump/`). GitLab uses storage **`nas-gitlab`** (content=backup):
  ```
  pvesm add cifs nas-gitlab --server 192.168.1.120 --share NeoCortex \
    --subdir /ProxmoxBackups/vm-gitlab-1 --username fiberoptix \
    --password '<NAS pw, see PASSWORDS.md>' --content backup
  ```
  Password is stored root-only on the host at `/etc/pve/priv/storage/nas-gitlab.pw`.
  NAS free space at setup: ~17.6 TB (plenty).

### Nightly scheduled job (Datacenter -> Backup)
- Job id **`gitlab-nightly`** in `/etc/pve/jobs.cfg`:
  - schedule **02:00** (host TZ America/New_York, so 2 AM Eastern)
  - vmid **181**, storage **nas-gitlab**, mode **snapshot** (no downtime), compress **zstd**
  - retention **keep-last=7**
  - notes-template `{{guestname}} {{node}} {{vmid}}`
- Recreate via:
  ```
  pvesh create /cluster/backup --id gitlab-nightly --schedule "02:00" --storage nas-gitlab \
    --vmid 181 --mode snapshot --compress zstd --prune-backups keep-last=7 --enabled 1
  ```

### Adding another server later (the per-host pattern)
```
# 1. make the host folder on the NAS
smbclient //192.168.1.120/NeoCortex -U fiberoptix%'<pw>' -c 'mkdir "ProxmoxBackups\<hostname>"'
# 2. add a per-host CIFS storage
pvesm add cifs nas-<host> --server 192.168.1.120 --share NeoCortex \
  --subdir /ProxmoxBackups/<hostname> --username fiberoptix --password '<pw>' --content backup
# 3. add a nightly job for that VMID
pvesh create /cluster/backup --id <host>-nightly --schedule "02:00" --storage nas-<host> \
  --vmid <vmid> --mode snapshot --compress zstd --prune-backups keep-last=7 --enabled 1
```
(Stagger schedules a bit, e.g. 02:00 / 02:30 / 03:00, so they don't all hammer the NAS at once.)

### Seed backup (proof it works)
- Ran `vzdump 181 --storage nas-gitlab --mode snapshot --compress zstd --prune-backups keep-last=7`.
- Result: 500 GiB scanned, 91% zero (sparse) -> **15.3 GB** compressed archive, ~6 min.
- File: `nas-gitlab:backup/vzdump-qemu-181-2026_06_18-21_07_36.vma.zst`
  (on NAS: `NeoCortex/ProxmoxBackups/vm-gitlab-1/dump/...`).

## Consistency note

- Backups are currently **crash-consistent** ("skipping guest filesystem freeze - disabled in
  VM options"). PostgreSQL/GitLab recover cleanly on boot (like a power-loss), so this is safe.
- To make them **application-consistent**, enable the QEMU guest agent (small, needs ONE reboot):
  1. `qm set 181 --agent 1`
  2. inside the guest: `apt install qemu-guest-agent && systemctl enable --now qemu-guest-agent`
  3. reboot VM 181 (so the virtio-serial channel attaches)
  Deferred — not done yet to avoid GitLab downtime.

## How to restore (DR runbook)

1. Build/boot a Proxmox host, attach the same NAS as CIFS storage (`content=backup`,
   subdir `/ProxmoxBackups/vm-gitlab-1`).
2. GUI: Storage `nas-gitlab` -> Backups -> select the dump -> **Restore** (pick a VMID/storage).
   CLI: `qmrestore /mnt/pve/nas-gitlab/dump/<file>.vma.zst <vmid> --storage <target>`
3. Ensure a `vmbr0` bridge exists on the new host (NIC is on `vmbr0`); start the VM.
4. GitLab boots with its original config + IP. Optionally `gitlab-ctl reconfigure` if needed.

### Proof-of-life test restore (RECOMMENDED, not yet done)
Restore to a throwaway VMID (e.g. 999) with the NIC on an isolated/no bridge so it can't clash
with the live 192.168.1.181, confirm it boots + login works, then delete the test VM.

## TODO / future

- [ ] One-time test restore to VMID 999 (proof of life).
- [ ] (Optional) Enable QEMU guest agent on 181 for app-consistent snapshots (1 reboot).
- [ ] (Optional) Extend the nightly job to other VMs (182 runner, 183 sonarqube, 184 www, 200 k8s).
- [ ] (Optional) Second/offsite copy of backups (NAS is currently a single point).
- [ ] (Optional) Proxmox Backup Server for dedup/incremental if full dumps grow too large.
