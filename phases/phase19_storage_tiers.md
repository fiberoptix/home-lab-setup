# Phase 19 — Storage tiers: thin pools, the right VMs on the mirror, backups by tier

**Opened and closed Sep 28, 2026, in one session.** 🙋 Andrew drove every decision; the AI ran the
commands with his go-ahead ("Plan and build now in this session").

## Why

🙋 *"We are going to do a lot of heavy R&D in the next year… I want to re-configure what we are doing so
WHEN we need space it's available and we don't have to think about 'getting' more space."* Assume the
footprint doubles. Consolidate before spending.

✅ **Measured first (Sep 28):** the PVE GUI said `vm-critical` was **71%** used; `zpool list` said **6%**.
Both VM pools were **thick** — every zvol reserved its full size on creation. Real data across both pools
≈ 140 G; reservations ≈ 1.46 T. **Doubling the data (~300 G) was trivial; doubling the reservations
(2.9 T) fit no layout of these drives.** So the limit was the provisioning model, not the hardware — the
same answer `phase0_hardware.md` → Storage Capacity Audit gave on Aug 19.

## Decisions (Andrew)

| Decision | Detail |
|---|---|
| **Keep TWO tiers, by rebuildability** | *"We can rebuild ephemeral VMs using this project."* |
| **Critical (`vm-critical`, mirror)** | **181, 183, 185, 201–205** (+ 184, already there; stays, no backup — July decision stands) |
| **Rebuildable (`vm-ephemeral`, stripe)** | 180, 182, 186, 191–193, template 9000 |
| **Thin-provision everything** | + an email alert + a boot-time check in `CURSOR_RULES` (< 80%) |
| **Snapshots that matter live on critical** | — so the k8s nodes moved, taking `c01`/`c02` with them |
| **Nightly backups for critical** | NAS; restore drills event-driven (a new job IS an event) |
| **Swarm snapshots `s01`–`s07` purged** | NAS backups from Aug 13 kept; one fresh offline baseline taken |
| **Money only when real allocation nears ~60%** | First purchase = larger drives in the same slots, not a new card |

⭐ **AI's refinements Andrew accepted:** move only what is UNDER-protected (184 stays on the mirror —
over-protection is nearly free once thin); snapshots cannot be placed separately from their disk, so
"snapshots on critical" means "the VMs whose snapshots matter live on critical".

## What was done — all measured

| Step | Result |
|---|---|
| **1. `nas-critical` storage** | `//192.168.1.120/NeoCortex/ProxmoxBackups/critical`, write-tested. Folder created via a temporary parent mount using the existing credential file. 🚨 **PVE's `.pw` file is ONE line `password=…`**, not the bare password — writing `password=$(cat …)` doubled the prefix and the mount failed with error 13. `--smbversion` takes `3.11`, not `3.1.1` |
| **2. Job `critical-nightly`** | 02:30, VMs 183,185,201–205, snapshot mode, zstd, keep-last=7. **First run by hand: 7/7 OK in 7¾ min, 28 GB total** (183 13.8 G, 185 2.5 G, k8s 1.5–2.2 G each), guest-agent fs-freeze/thaw on every VM, cluster 5/5 Ready after. ✅ PVE's "not backed up" list afterwards = exactly the rebuildable tier |
| **3. Thin provisioning** | `sparse 1` on both storages; `refreservation=none` on all **27** zvols. **GUI 70.92% → 6.87%** (now agrees with zpool CAP). No restart. Undo: `zfs set refreservation=auto <zvol>` |
| **4. Capacity alert** | `/usr/local/bin/zfs-capacity-alert.sh` + `zfs-capacity-alert.timer` (hourly), repo copies in `proxmox/build-scripts/`. Reads **zpool CAP**; warns 70%, critical 80%, any pool not ONLINE; once per pool per level per day. ✅ Tested: real thresholds → no mail; forced 1%/2% → mail; re-run → deduplicated; postfix log `status=sent (250 … gsmtp)` |
| **5. k8s nodes → `vm-critical`** | Via `zfs send -R` (see below), one node at a time: 205 (+ rollback proof), 204, 201, 203, 202 (etcd leader last). Every snapshot GUID-identical; cluster never below 5/5 Ready; etcd: no election for non-leaders, exactly one (term 9 → 10) when the leader moved. Old stripe copies destroyed only after a gate (conf, running, GUIDs, NAS backup present). **`vm-critical` 8%, `vm-ephemeral` 3% after** |
| **6. Swarm** | `s01`–`s07` deleted (0/0 at qm + ZFS), shut down non-leaders first, offline snapshot **`baseline-2026-09-28`** on all three, back up: 3 managers Ready, 4 services at full replicas |
| **7. Restore drill** (required — new job) | 205's backup → VMID 999, `--unique`, **`link_down=1` before first boot**, checked through the guest agent: hostname, kernel 142, kubelet v1.35.8, `kubelet.conf` intact, NIC `NO-CARRIER`. Restore 19 s (90% sparse). Destroyed, 0 leftovers; real .205 Ready throughout |

## ⭐ Findings that apply beyond this phase

- 🚨 **PVE `move-disk` DROPS SNAPSHOTS.** Read in `/usr/share/perl5/PVE/API2/Qemu.pm`: *"moving disk
  with snapshots, snapshots will not be moved!"* and it refuses `--delete` of the source. To move a VM
  with snapshots between ZFS pools: shut down → `zfs snapshot …@xfer` → `zfs send -R …@xfer | zfs recv -u
  <dst>` (disk AND cloudinit) → **compare every snapshot's `guid`** (identical GUID = identical snapshot)
  → destroy `@xfer` on both sides → rewrite ALL storage refs in the conf (current + every snapshot
  section; 6 per k8s node) → start. Keep the source until the whole batch is verified.
- 🚨 **ZFS can only roll back to the MOST RECENT snapshot** (PVE refuses otherwise). So the transfer
  snapshot must be destroyed, or `c02` stops being rollback-able — and ⚠️ **`c01-nodes-ready` can NOT be
  rolled back to while `c02-virgin-cluster` exists.** Going back to `c01` means deleting `c02` first.
- 🚨 **"Ready" lies for ~50 s after a node goes down** (the grace period). A move shorter than that
  still shows the node Ready. **Prove the node came back with its `kube-node-lease` `renewTime`**
  (renewed every ~10 s) newer than the VM's start time. **Not** the node conditions'
  `lastHeartbeatTime` — measured ~4 min stale, because it is re-posted only when something changes.
- 🚨 **Two parsing lies caught by known-fail tests:** `awk '/lastHeartbeatTime/{print $2}'` printed
  the LABEL on YAML list items (`- lastHeartbeatTime:` shifts the field) — and the known-fail case
  "passed" anyway, because the error happened to read as "no". **A known-fail case must fail for the
  RIGHT reason — look at the value, not just the verdict.** And a staged-set check compared a sorted
  list with an unsorted literal (failed closed, harmless).
- ⚠️ **A command ran TWICE** (cause unknown — the tool reported only the second, aborted copy). The
  pre-flight guard (5/5 Ready) stopped the duplicate before any change. **Fix: `flock` in the script**,
  tested with a held lock. ⭐ Any script that mutates shared state should refuse to run concurrently.
- ⭐ **Deleting a snapshot of a thick zvol freed MORE than its `used`** (184: 5.39 G shown, 14 G freed)
  — `used` counts only unique blocks. Measure the pool before and after; do not predict from `used`.

## Undo / recovery map

| If… | Then |
|---|---|
| Thin provisioning must be reverted | `zfs set refreservation=auto <zvol>` per zvol; `pvesm set <storage> --sparse 0` |
| A moved node's conf is wrong | `/root/20X.conf.pre-p19` on the host (all five kept) |
| A k8s node's disk is lost | nightly `nas-critical` backup (keep 7) → `qmrestore`; or `qm rollback … c02-virgin-cluster` |
| The alert must be silenced | `systemctl disable --now zfs-capacity-alert.timer` |

## Open

- ✅ `CURSOR_RULES` boot-time pool check — **startup item 5**, approved in writing by Andrew Sep 28
  ("exactly as written"); tested: `💾 Pools: rpool 3% vm-critical 8% vm-ephemeral 3% - all ONLINE`.
- ⚠️ `/mnt/pve/nas-backup` — empty mountpoint from Jun 18, no storage entry. Harmless leftover.
- ⚠️ Phase 16 trap **C2** was recorded as needing "a restore to `s02-swarm-up`" to re-run honestly —
  **`s02` no longer exists.** Re-running C2 now means rebuilding the Swarm to its Part 2 state.
- ✅ `CURSOR_RULES` hardware line corrected 128 → 192 GB RAM (measured 6× 32 GB; approved in writing).

## How to place a NEW VM from now on

1. **Can this project rebuild it from scratch?** Yes → `vm-ephemeral`. No → `vm-critical`.
2. Critical → **add its VMID to `critical-nightly`** (`/etc/pve/jobs.cfg`), then run the job once by hand
   and check the NAS listing. A new or changed job triggers a restore drill (MEMORY.md rule).
3. Disks are thin automatically now (`sparse 1`). Watch `zpool list` CAP, never the GUI.
