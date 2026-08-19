# Phase 0: Hardware Setup & Configuration

**Status:** ✅ Complete  
**Date:** December 2025  
**Amended:** Aug 19, 2026 — added **Memory Configuration** (verified DIMM inventory for the Z6 *and*
the Z8 dev workstation, the do-not-move-DIMMs decision, and current pricing). This file is the
reference for physical part numbers and slot maps.

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
| Motherboard M.2 #1 | nvme0n1 | WD Blue SN5100 | 500GB | Proxmox OS (mirror) |
| Motherboard M.2 #2 | nvme3n1 | WD Blue SN5100 | 500GB | Proxmox OS (mirror) |
| HP Turbo Quad Slot 1 | nvme1n1 | Lexar SSD NM620 | 1TB | vm-critical (mirror) |
| HP Turbo Quad Slot 2 | nvme2n1 | Lexar SSD NM620 | 1TB | vm-critical (mirror) |
| HP Turbo Quad Slot 3 | nvme4n1 | Lexar SSD NM620 | 1TB | vm-ephemeral (stripe) |
| HP Turbo Quad Slot 4 | nvme5n1 | Lexar SSD NM620 | 1TB | vm-ephemeral (stripe) |

### HP Z Turbo Drive Quad Pro

- PCIe card with 4x M.2 NVMe slots
- Passive bifurcation (x4x4x4x4)
- No RAID controller - drives appear individually to OS
- Originally configured with Intel VROC (abandoned due to ESXi issues)

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

**Boot Drives (2x WD Blue SN5100 500GB):**

| Device | Pool | Serial Number |
|--------|------|---------------|
| nvme0n1 | rpool (mirror) | 25434V801543 |
| nvme3n1 | rpool (mirror) | 25434V802501 |

**VM Storage Drives (4x Lexar SSD NM620 1TB):**

| Device | Pool | Serial Number |
|--------|------|---------------|
| nvme1n1 | vm-critical (mirror) | PKG237W103886P1100 |
| nvme2n1 | vm-critical (mirror) | PKG237W103845P1100 |
| nvme4n1 | vm-ephemeral (stripe) | PKG237W103863P1100 |
| nvme5n1 | vm-ephemeral (stripe) | PKG237W103887P1100 |

**To check all serials:**
```bash
lsblk -o NAME,SIZE,MODEL,SERIAL
```

**Why this matters:** If a drive fails in a ZFS mirror, you need the serial number to identify which physical drive to replace.

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

