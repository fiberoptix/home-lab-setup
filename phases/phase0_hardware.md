# Phase 0: Hardware Setup & Configuration

**Status:** ✅ Complete  
**Date:** December 2025  
**Amended:** Aug 19, 2026 — added **Memory Configuration** (verified DIMM inventory for the Z6 *and*
the Z8 dev workstation, the do-not-move-DIMMs decision, and current pricing) and the **Storage
Capacity Audit** (verdict: **no storage purchase needed — 4% of pool space is actually written**;
also corrects the stale `nvmeXn1` device names). This file is the reference for physical part numbers
and slot maps.

⭐ **Both of Aug 19's findings had the same shape: a number in the docs was believed, and the live
hardware disagreed.** RAM slot positions were wrong, DIMM prices were 10x stale, disk device names had
drifted, and "70% full" turned out to be 7.5% written. **Re-read the hardware before spending.**

---

## Server Hardware

**HP Z6 G4 Workstation**

| Component | Specification |
|-----------|---------------|
| CPU | Intel Xeon Platinum 8168 (24 cores / 48 threads) |
| RAM | 128GB DDR4 ECC (4x 32GB DIMMs) — **4 of 6 channels; slot map + parts in Memory Configuration below** |
| Boot Storage | 2x WD Blue SN5100 500GB NVMe (motherboard M.2 slots) |
| VM Storage | 4x Lexar SSD NM620 1TB NVMe (HP Z Turbo Drive Quad Pro PCIe card) |
| Network | 2x 1GbE onboard NICs (Intel e1000e + i40e) |
| UPS | APC BR1500MS2 (ordered) |

---

## Memory Configuration — both workstations (verified live Aug 19, 2026)

Read from live SMBIOS on the same afternoon, not from invoices or memory. **Z6:** `dmidecode -t memory`
over SSH to `.150`. **Z8:** PowerShell on the *Windows host* — a VMware guest reports virtual memory,
so the dev VM cannot see the real DIMMs and `.115` has no SSH/WinRM (RDP or console only).

### HP Z6 G4 — Proxmox host (192.168.1.150)

**6 DIMM slots** for the installed CPU (SMBIOS type 16: `Number Of Devices: 6`), **6 memory channels**
→ one DIMM per channel, so populated slots = populated channels.

| Slot | Size | Part Number | Mfr | Speed | Rank |
|------|------|-------------|-----|-------|------|
| CPU0-DIMM1 | 32GB | HMA84GR7AFR4N-VK | Hynix | 2666 MT/s (configured 2666) | 2 |
| CPU0-DIMM2 | 32GB | HMA84GR7AFR4N-VK | Hynix | 2666 MT/s (configured 2666) | 2 |
| **CPU0-DIMM3** | **EMPTY** | — | — | — | — |
| **CPU0-DIMM4** | **EMPTY** | — | — | — | — |
| CPU0-DIMM5 | 32GB | HMA84GR7AFR4N-VK | Hynix | 2666 MT/s (configured 2666) | 2 |
| CPU0-DIMM6 | 32GB | HMA84GR7AFR4N-VK | Hynix | 2666 MT/s (configured 2666) | 2 |

**128GB total, 4 of 6 channels populated.** All sticks run at their full rated 2666 (no downclock).
NUMA: 1 flat node since SNC was disabled Jul 9, 2026. Usage at audit: **125 GiB total, 91 GiB used,
33 GiB available, swap 0** (ZFS ARC counts as *used*, not cache, on Linux).

⚠️ **This corrects `phase13` PERF-3**, which recorded the DIMMs as `CPU0-DIMM1..4` with 5/6 empty.
It is the reverse: **1, 2, 5, 6 are populated and 3, 4 are free.** The channel count (4 of 6) and
PERF-3's conclusion were right; the slot names were not. Anyone opening the case with the old text
would install in occupied slots.

### HP Z8 G4 — dev workstation (192.168.1.115)

**24 DIMM slots (12 per CPU), 6 channels per CPU, 2 sockets per channel** (black filled before white).
Per HP's Z8 G4 technical white paper, the one-DIMM-per-channel set is slots **1, 3, 5, 8, 10, 12**.

| Slot | Size | Part Number | Mfr | Speed |
|------|------|-------------|-----|-------|
| CPU0-DIMM1 | 32GB | HMA84GR7JJR4N-VK | Hynix | 2666 MT/s (configured 2666) |
| CPU0-DIMM3 | 32GB | HMA84GR7JJR4N-VK | Hynix | 2666 MT/s (configured 2666) |
| CPU0-DIMM10 | 32GB | HMA84GR7JJR4N-VK | Hynix | 2666 MT/s (configured 2666) |
| CPU0-DIMM12 | 32GB | HMA84GR7JJR4N-VK | Hynix | 2666 MT/s (configured 2666) |
| CPU1-DIMM1 | 32GB | HMA84GR7JJR4N-VK | Hynix | 2666 MT/s (configured 2666) |
| CPU1-DIMM3 | 32GB | HMA84GR7JJR4N-VK | Hynix | 2666 MT/s (configured 2666) |
| CPU1-DIMM10 | 32GB | HMA84GR7JJR4N-VK | Hynix | 2666 MT/s (configured 2666) |
| CPU1-DIMM12 | 32GB | HMA84GR7JJR4N-VK | Hynix | 2666 MT/s (configured 2666) |

**256GB total, 8x 32GB, 4 of 6 channels per socket.** The four sticks per CPU are all members of HP's
one-per-channel set, so they sit on four *distinct* channels. **Empty one-per-channel slots: `DIMM5`
and `DIMM8` on BOTH CPUs.**

✅ **This closes the "verify DIMM population" item** that had been open on the Z8 BIOS checklist in the
`phase13` addendum since Jul 9, 2026. The suspicion recorded there — "same 4-of-6 concern as the Z6" —
was **correct**.

**The two machines use different Hynix die revisions of the same module** (`AFR4N` on the Z6, `JJR4N`
on the Z8). Both are 32GB x4 ECC RDIMM at 2666, so either part is usable in either machine; a mixed
fleet already exists and works.

### Both boxes are under-populated — this is not a redistribution problem

| | Z6 G4 | Z8 G4 |
|---|---|---|
| Cores contending | 24c/48t | **48c/96t** |
| Channels live | 4 of 6 | 4 of 6 **per socket** |
| To reach full channels | +2x 32GB → 192GB | +4x 32GB → 384GB |
| Slots to fill | `CPU0-DIMM3`, `CPU0-DIMM4` | `DIMM5` + `DIMM8` on **each** CPU |
| Hard ceiling | 192GB (6 slots, 1 CPU) | 1.5TB+ |

HP's guidance: *"install memory in sets of 6 for single CPU configurations or 12 for dual CPU"*, and
*"unbalanced RAM population can reduce memory bandwidth by up to 33% from its maximum potential."*
The Z6 has 4 where it wants 6; the Z8 has 8 where it wants 12.

### ⛔ Do NOT move DIMMs from the Z8 to the Z6 (decision, Aug 19, 2026)

The question was asked and answered: it is **negative-sum**.

1. **There are only two ways to pull a pair, and both hurt more than the Z6 gains.** One stick per
   socket leaves the Z8 at **3 channels per socket** — both CPUs degraded a quarter. Two from one
   socket **halves** that socket's bandwidth (4 channels → 2).
2. **It attacks the one memory tuning result we actually measured.** The dev VM is deliberately
   presented as **2 sockets x 12 so Windows places it on the idle PROC1** (996 ev/s/thread, 93%
   scaling efficiency — phase13 addendum). Stripping PROC1 feeds 24 vCPUs from fewer channels and
   pushes the VM into cross-socket access; stripping PROC0 starves Windows and the host instead.
3. **The Z8's channels serve twice the cores**, so the aggregate across both machines goes *down*.
4. 🚨 **At current prices every installed stick is a ~$300 asset.** Pulling two out of the Z8 does not
   cost nothing — it strands that box needing **6** sticks instead of 4 to reach full channels,
   raising its eventual repair bill from ~$1,200 to ~$1,800. It destroys value to avoid spending it.

### 💰 Pricing: PERF-3's cost estimate is badly stale

| | July 9, 2026 (phase13 PERF-3) | **Aug 19, 2026 (Andrew)** |
|---|---|---|
| 32GB DDR4-2666 ECC RDIMM | ~$25–40 each | **~$300 each** |
| Z6 to 192GB + 6/6 channels (2 sticks) | ~$50–80 | **~$600** |
| Z8 to 384GB + 6/6 per socket (4 sticks) | ~$100–160 | **~$1,200** |
| Both fully populated (6 sticks) | ~$150–240 | **~$1,800** |

DDR4 is end-of-life with DRAM production shifted to DDR5, so the trend is **upward, not downward** —
waiting probably costs more, which is the one honest argument for buying sooner.

### ⚠️ Recommendation: buy NOTHING yet — the free levers are untested

PERF-3 called 6-channel population *"the single biggest hardware perf lever available"* when it cost
$50–80. At **$600** for the Z6 pair, it no longer clears the bar, for two reasons:

- 🚨 **The bandwidth gain has never been measured on either machine.** There is **no STREAM or `mbw`
  number anywhere in this repo.** The phase13 sysbench figures are CPU. The "2/3 of platform
  bandwidth" and HP's 33% are *channel-count arithmetic*, not observations of our workloads — and
  GitLab, the runner, SonarQube and ZFS are I/O and CPU bound long before they are bandwidth bound.
- **The Z6's real problem is capacity (91 of 125 GiB used), and capacity may be recoverable for $0.**

**Do these first, in order — all free:**
1. **Check `zfs_arc_max` on the Z6.** ⚠️ **Not yet measured** (see the SSH note below). Older PVE
   installs default ARC to **50% of RAM = up to ~64GB here**. If it is uncapped, capping it is the
   single biggest free lever and may exceed what $600 of DIMMs would add.
2. **Measure the VMs' actual working sets** — GitLab is allocated 24GB and SonarQube 12GB. This is
   *already an open item* (#8 in `current_phase.md`: "Measure RAM/CPU headroom on the other VMs the
   way 186 was measured").
3. **Then, if still short, measure bandwidth before buying** — `mbw` or STREAM on the Z6, before and
   after, so the next person has a number instead of arithmetic.

Spend only what steps 1–3 prove is needed. If a purchase is justified, buy for the **Z6 first**
(`CPU0-DIMM3` + `CPU0-DIMM4`) — it is the box with measured capacity pressure, and it is cheaper.

### Why this matters

Same reason as the drive serials above: **the part number and slot map are what you need at the
moment of purchase or failure**, and both were wrong or missing in the repo until today. A DIMM
bought without matching capacity, rank and speed can drop the whole set to a lower common clock, and
mixed RDIMM/LRDIMM will not POST at all.

### How to re-check (both machines)

```bash
# Z6 / any Linux host — full DIMM inventory incl. empty slots
dmidecode -t memory | grep -E 'Locator|Size|Speed|Manufacturer|Part Number|Rank'
dmidecode -t 16                      # slot count for the installed CPU(s)
numactl --hardware                   # NUMA layout
free -h                              # note: ZFS ARC shows as 'used', not 'cache'
```

```powershell
# Z8 — must run on the WINDOWS host (RDP/console), NOT in the dev VM
Get-CimInstance Win32_PhysicalMemory |
  Select-Object DeviceLocator,BankLabel,Capacity,Speed,Manufacturer,PartNumber,ConfiguredClockSpeed |
  Format-Table -AutoSize
```

⚠️ **Gotcha hit while gathering this, worth knowing:** the Z6 answered the first query in under half a
second, then **every later SSH attempt hung after the password prompt** while port 22 still served its
banner (`OpenSSH_10.0p2`) and the web UI stayed up. Leading hypothesis (**unconfirmed**):
**OpenSSH 10's `PerSourcePenalties`, on by default**, penalising this source address for ~6 sessions
killed mid-authentication. If so it is self-inflicted, per-source, and clears itself. Confirm with
`sshd -T | grep -i persourcepenalt` and `journalctl -u ssh | grep -i penalt`. **On PVE 9, a few
abandoned SSH sessions can lock you out of your own host for minutes while the port still answers —
which looks exactly like a host fault and is not one.** This is why ARC was never measured.

---

## Storage Configuration

### Physical Layout

| Slot | Device | Model | Size | Purpose |
|------|--------|-------|------|---------|
| Motherboard M.2 #1 | ~~nvme0n1~~ | WD Blue SN5100 | 500GB | Proxmox OS (mirror) |
| Motherboard M.2 #2 | ~~nvme3n1~~ | WD Blue SN5100 | 500GB | Proxmox OS (mirror) |
| HP Turbo Quad Slot 1 | ~~nvme1n1~~ | Lexar SSD NM620 | 1TB | vm-critical (mirror) |
| HP Turbo Quad Slot 2 | ~~nvme2n1~~ | Lexar SSD NM620 | 1TB | vm-critical (mirror) |
| HP Turbo Quad Slot 3 | ~~nvme4n1~~ | Lexar SSD NM620 | 1TB | vm-ephemeral (stripe) |
| HP Turbo Quad Slot 4 | ~~nvme5n1~~ | Lexar SSD NM620 | 1TB | vm-ephemeral (stripe) |

🚨 **The `nvmeXn1` names above are STALE and the lesson is that they always will be — NVMe
enumeration order is not stable across boots/kernels.** Verified Aug 19, 2026: the boot mirror is now
`nvme0n1`+`nvme1n1` (not `0`+`3`), `vm-critical` is `nvme2n1`+`nvme3n1`, `vm-ephemeral` is
`nvme4n1`+`nvme5n1`. **Pool membership by SERIAL never changed** — only the kernel names moved.
⚠️ **Never act on a device name from a document. Re-read it, and identify drives by serial**
(see Drive Serial Numbers below). The *physical* quad-slot ↔ serial mapping was NOT re-verified on
Aug 19 and is still as originally recorded.

### HP Z Turbo Drive Quad Pro

- PCIe card with 4x M.2 NVMe slots — **in Slot 5** (hence `phase13`'s "Slot 5 Bifurcation" +
  "Slot 5 VROC" BIOS settings). **All 4 slots are FULL.**
- Passive bifurcation (x4x4x4x4)
- No RAID controller - drives appear individually to OS
- Originally configured with Intel VROC (abandoned due to ESXi issues)
- **VMD is active:** two `Intel Volume Management Device` controllers present, giving PCI domains
  `10000` (the 2x boot WDs) and `10001` (the 4x NM620s on this card).

---

## 📊 Storage Capacity Audit — Aug 19, 2026 (verdict: NO PURCHASE NEEDED)

**Question asked:** *"I think we might be near 70% usage on the critical storage. I'm thinking of
buying another card and more NVMe sticks."* **Answer: the 70% is real but it is RESERVATION, not
data. Buy nothing.** All figures below read live from the Proxmox REST API (`/nodes/pve/...`).

### 🚨 The headline: 137 GiB of real data on 3.24 TiB of pool. That is 4%.

| Pool | Layout | Usable | **Actually written** (`zpool alloc`) | Alloc % | Physically free |
|------|--------|--------|--------------------------------------|---------|-----------------|
| `rpool` | 2x 500GB mirror | 460 GiB | 14.1 GiB | 3.1% | 446 GiB |
| `vm-critical` | 2x 1TB mirror | 952 GiB | **71.6 GiB** | **7.5%** | **880 GiB** |
| `vm-ephemeral` | 2x 1TB stripe | 1,904 GiB | 51.2 GiB | 2.7% | 1,853 GiB |

### ⭐ Why PVE says 70.9% when only 7.5% is written

**Both VM pools are THICK-provisioned**, so every zvol reserves its full size whether or not a byte is
written: `vm-critical` has **no `sparse` key at all** and `vm-ephemeral` has `sparse: 0`. Only
`local-zfs` is thin (`sparse: 1`). ⭐ **`zfs list` / the PVE GUI count `refreservation` as USED, while
`zpool list` counts only blocks actually allocated. That gap is the whole mystery** — about **582 GiB
of `vm-critical`'s 654 GiB "used" is reserved space that has never been written.**

| Storage | PVE "used" (reservation-inclusive) | Provisioned zvols | Written |
|---|---|---|---|
| `vm-critical` | 654.0 of 922.5 GiB (**70.9%**) | 630 GiB | **71.6 GiB** |
| `vm-ephemeral` | 647.4 of 1,845 GiB (35.1%) | 623.5 GiB | 51.2 GiB |

`vm-critical` zvols: **VM 181 GitLab = 500 GiB** (79% of the pool's whole commitment), 183 = 30,
184 = 50, **185 = 50 (VM is STOPPED/RETIRED — a dead VM holding a live reservation).**

⚠️ **Thick provisioning is not a fault here.** 630 GiB committed on a 922 GiB pool means **no
overcommit** — every VM could fill its disk and the pool would still hold. PVE's 70.9% is an honest
report of *committed* capacity. It is not a capacity problem, and 71% is not a number to panic at.

### ✅ Three independent reasons no storage is needed

1. **ZFS only cares about allocation, and it is 2.7–7.5%.** Pools degrade past ~80% allocated —
   an order of magnitude of runway away.
2. **~1.43 TiB of committable space is still free even keeping thick provisioning** (268 GiB on
   `vm-critical` + 1,198 GiB on `vm-ephemeral`) — room for many more VMs, changing nothing.
3. **Growth is ~9 GiB/month** on `vm-critical` (71.6 GiB after ~8 months of GitLab + CI + SonarQube).
   The 880 GiB of physically free space on that pool is ~8 years out at that rate.

### 🔲 Free levers, if the 70.9% number is bothersome (cleanups, NOT fixes)

1. **Delete VM 185 (`vm-openclaw-1`)** — retired, stopped, `onboot=0`, phase closed. Frees a 50 GiB
   reservation → `vm-critical` drops to ~63%.
2. **Drop the reservation on GitLab's oversized disk** — instant, no data movement, reversible:
   `zfs set refreservation=none vm-critical/vm-181-disk-0`, then `sparse 1` on the storage so future
   disks are thin. ⚠️ **The trade is real:** thin allows overcommit, and a *full* ZFS pool is far
   worse than a full ext4 — only do this with the existing Gmail alerting watching pool allocation.
3. ⛔ **Do NOT shrink the zvol.** Shrinking under a live filesystem is how you lose a GitLab.

### 🎯 Tripwire — revisit a purchase when ANY of these is true

- **`zpool list` ALLOC crosses ~60–65% on any pool** (act well before the 80% cliff). Today: 7.5% max.
- More than **~1.4 TiB of new thick VM disks** is needed.
- **Redundancy for `vm-ephemeral` is wanted** — see below. This is the only *likely* future purchase,
  and it is driven by redundancy, **not capacity**.

```bash
zpool list                     # ALLOC/CAP = the number that actually matters
zfs list -o name,used,avail,refreservation,volsize
```

### ⚠️ What IS worth attention (bigger than capacity)

**`vm-ephemeral` is a 2-disk STRIPE with no redundancy and it no longer holds disposable workloads.**
It carries VM 186 (k3s/Redpanda rig), **191/192/193 (the whole Docker Swarm study cluster)**, 182
(runner) and 200. 🚨 **The `s01`–`s06` swarm snapshot chain lives on the same pool it is meant to
protect** — one NM620 failure destroys the VMs *and* every snapshot of them.

**And there is exactly ONE scheduled backup job on the host:** VM 181 → `nas-gitlab` at 02:00 (healthy,
nightly, ~12 GiB, latest Aug 19). Everything else has **no schedule**:
- **191/192/193: one backup each, from Aug 13 18:10** — predating Part 4, the C4 fix and chapter 3.
- **182, 183, 184, 186, 200: no backups at all.** ⚠️ **184 hosts PROD Capricorn** (on the mirror, so
  redundant, but with no restore point).

⭐ **The design assumption drifted:** `vm-ephemeral` was chosen for speed because its VMs were
disposable, and the education work living there stopped being disposable when it became onboarding
material. **The fix costs $0** — there are 880 GiB physically free on the *mirrored* pool, so move
what now matters onto `vm-critical` and/or add backup jobs. That is a better use of money than
capacity: it needs none. **Acting on this changes VM placement, so it belongs in a phase, not here.**

### 🔧 If expansion is ever actually needed — the PCIe constraints

- The Z6 G4 has **two x16 CPU slots: Slot 2 and Slot 5**. With a single CPU, **slots 1, 2, 4, 5 are
  active**; slots 3 and 6 need the 2nd CPU riser (HP Z6 G4 QuickSpecs / Architecture white paper).
- **Slot 5 holds the quad card, so Slot 2 is the only candidate** — and the **Quadro P2000 is very
  likely in it** (present at `0000:21:00.0`; the physical slot was NOT confirmed — needs
  `dmidecode -t slot` or eyes inside the case).
- 🚨 **The P2000 cannot simply be removed.** Xeon Platinum 8168 has **no integrated graphics** and
  there is **no out-of-band console** (phase13 gap 3), so it is the only display path for BIOS work —
  including the memory upgrade above. It *can* be relocated to **Slot 1** (x4, open-ended) since it is
  idle and only needed for display.
- ⛔ **Slot 4 is not usable for a 4-drive card:** it is x8 but **drops to x4 electrical when the 2nd
  onboard M.2 is populated** — and both M.2 slots hold the boot mirror.
- **All 4 quad-card slots and both onboard M.2 slots are full**, so adding *any* drive requires a
  second card in Slot 2 with the GPU moved first.

---

## Network Configuration

| Port | NIC | Connection | Purpose |
|------|-----|------------|---------|
| MGMT (labeled) | e1000e | Switch | Management interface |
| Port 2 | i40e | Switch | Secondary (unused) |

**Static IP:** 192.168.1.150 (Proxmox host)

---

## BIOS Settings

| Setting | Value | Location | Reason |
|---------|-------|----------|--------|
| Boot Mode | UEFI | Boot Options | Required for Proxmox/ZFS |
| Secure Boot | Disabled | Boot Options | Proxmox compatibility |
| Legacy Support | Disabled | Boot Options | Pure UEFI boot |
| VT-x (Virtualization) | Enabled | Security → Virtualization | VM hardware virtualization |
| VT-d (IOMMU) | Enabled | Security → Virtualization | PCIe passthrough capability |
| PCIe Bifurcation | x4x4x4x4 | Advanced → PCIe Configuration | Required for HP Z Turbo Drive Quad Pro |
| VROC RAID Controller | Enabled | Advanced → Device Configuration | (Later wiped metadata for ZFS) |

---

## What Didn't Work

### Intel VROC (Virtual RAID on CPU)

Originally planned to use Intel VROC for NVMe RAID arrays, but:

1. **ESXi UEFI boot hung** - "Loading Crypto Module" hang with custom VROC driver ISO
2. **ESXi Legacy mode** - Booted but VROC arrays not visible (VROC requires UEFI)
3. **Decision:** Abandon VROC, use ZFS software RAID instead

This led to switching from VMware ESXi to Proxmox VE.

---

## Drive Serial Numbers

**Serial → pool is the STABLE mapping. Device names are re-verified Aug 19, 2026 and will drift again.**

**Boot Drives (2x WD Blue SN5100 500GB):**

| Serial Number | Pool | Device (Aug 19, 2026) | Device (as first recorded) | Health / wearout |
|---------------|------|----------------------|---------------------------|------------------|
| 25434V801543 | rpool (mirror) | **nvme1n1** | nvme0n1 | PASSED / 99 |
| 25434V802501 | rpool (mirror) | **nvme0n1** | nvme3n1 | PASSED / 99 |

**VM Storage Drives (4x Lexar SSD NM620 1TB, on the HP Turbo Quad Pro):**

| Serial Number | Pool | Device (Aug 19, 2026) | Device (as first recorded) | Health / wearout |
|---------------|------|----------------------|---------------------------|------------------|
| PKG237W103886P1100 | vm-critical (mirror) | **nvme2n1** | nvme1n1 | PASSED / 99 |
| PKG237W103845P1100 | vm-critical (mirror) | **nvme3n1** | nvme2n1 | PASSED / 99 |
| PKG237W103863P1100 | vm-ephemeral (stripe) | **nvme5n1** | nvme4n1 | PASSED / 100 |
| PKG237W103887P1100 | vm-ephemeral (stripe) | **nvme4n1** | nvme5n1 | PASSED / 100 |

**Wearout 99–100 = endurance essentially untouched** after ~8 months (PVE reports life *remaining*;
`smartctl -A /dev/nvmeX` → `Percentage Used` is the direct figure). No drive is near replacement.

**Controllers:** the four NM620s are **`MAXIO MAP1202`, which is DRAM-less** — fine for this lab's
load, but relevant if drives are ever bought: prefer DRAM-equipped, higher-endurance parts for a new
mirrored pool rather than more NM620s.

**To check all serials:**
```bash
lsblk -o NAME,SIZE,MODEL,SERIAL
ls -l /dev/disk/by-id/                       # stable names — prefer these over nvmeXn1
zpool status -v                              # which serial sits in which vdev
```

**Why this matters:** If a drive fails in a ZFS mirror, you need the serial number to identify which
physical drive to replace — and ⚠️ **the `nvmeXn1` name in any document may already be wrong.**
Pull the serial live, then match it to this table.

---

## Lessons Learned

1. **VROC + ESXi = problematic** on HP Z6 G4
2. **ZFS is better** - Native to Linux, no special drivers needed
3. **HP Z Turbo Quad Pro works great** with direct NVMe access
4. **Document drive serial numbers** for future replacement
5. **PCIe bifurcation must be enabled** in BIOS for HP Turbo card

---

## Related Files

- `/proxmox/Home_Lab_Proxmox_Design.md` - Full architecture design
- `/proxmox/Home_Lab_Proxmox_Storage.md` - Detailed ZFS configuration & commands
- `/vmware/` - Abandoned ESXi documentation (reference only)

