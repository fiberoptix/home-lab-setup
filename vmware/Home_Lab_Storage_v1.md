# Home Lab Storage Configuration v1.0

**Created:** December 8, 2025  
**Target:** HP Z6 G4 with VMware ESXi  
**Hardware:** 6 drives total → 3.5TB usable

---

## Physical Configuration

```
HP Z6 G4 Motherboard:
├─ Onboard M.2 Slot 1: 500GB SSD #1 ─┐
├─ Onboard M.2 Slot 2: 500GB SSD #2 ─┴─ RAID 1 → 500GB usable
│
└─ PCIe Slot 2: ASUS Hyper M.2 x16 Card
    ├─ Card Slot 1: 1TB SSD #3 ─┐
    ├─ Card Slot 2: 1TB SSD #4 ─┴─ RAID 1 → 1TB usable
    ├─ Card Slot 3: 1TB SSD #5 ─┐
    └─ Card Slot 4: 1TB SSD #6 ─┴─ RAID 0 → 2TB usable
```

---

## Storage Pools

### Pool 0: `esxi-system` (500GB RAID 1)
```
Drives: 2x 500GB onboard M.2
RAID: 1 (mirror)

Contents:
├─ ESXi Boot/System      10GB
├─ ESXi Swap             48GB
├─ ESXi Logs/Scratch     10GB
├─ Traefik VM             5GB
├─ SonarQube VM          20GB
├─ Monitoring VM         30GB
├─ ISO Library           50GB
└─ Spare                327GB
```

### Pool 1: `vm-critical` (1TB RAID 1)
```
Drives: 2x 1TB on ASUS card (slots 1&2)
RAID: 1 (mirror)

Contents:
├─ GitLab VM            200GB
├─ GitLab Backups       100GB
├─ VM Snapshots         100GB
└─ Spare                600GB
```

### Pool 2: `vm-ephemeral` (2TB RAID 0)
```
Drives: 2x 1TB on ASUS card (slots 3&4)
RAID: 0 (stripe - 2x speed, NO redundancy)

Contents:
├─ GitLab Runner VM     100GB
├─ QA Host VM           100GB
├─ Staging VM           100GB
├─ Build Cache          200GB
├─ Test Databases        50GB
└─ Spare               1.45TB
```

---

## VM Placement

| VM | Datastore | Size | Why |
|----|-----------|------|-----|
| ESXi Boot | `esxi-system` | 10GB | System |
| Traefik | `vm-critical` | 5GB | Small VM |
| SonarQube | `vm-critical` | 20GB | Small VM |
| Monitoring | `vm-critical` | 30GB | Small VM |
| GitLab | `vm-critical` | 200GB | Critical data |
| GitLab Runner | `vm-ephemeral` | 100GB | Fast builds |
| QA Host | `vm-ephemeral` | 100GB | Fast deployments |

---

## VROC Setup Steps

### 1. BIOS (F10 during boot)
```
Advanced → PCIe Configuration
  └─ Slot 2 Bifurcation: x4 x4 x4 x4

Advanced → Device Configuration
  └─ VROC RAID Controller: Enabled
  └─ VROC Managed RAID: Enabled
```

### 2. Create RAID Arrays (Ctrl+I during boot)

**Array 1: esxi-system**
- RAID Level: RAID1
- Disks: 2x 500GB onboard

**Array 2: vm-critical**
- RAID Level: RAID1
- Disks: 1TB #3 + 1TB #4

**Array 3: vm-ephemeral**
- RAID Level: RAID0
- Disks: 1TB #5 + 1TB #6

### 3. ESXi Install
- Boot ESXi 8.0+ ISO
- Install on `esxi-system`
- Create 3 datastores

---

## Backup Plan

**Weekly Backups:**
- GitLab VM → External NAS/USB
- GitLab: `gitlab-backup create`

**No Backup Needed:**
- Runner (rebuild in 5 min)
- QA Host (redeploy from GitLab)

---

## Key Rules

1. GitLab on RAID 1 (critical data)
2. Runner/QA on RAID 0 (fast, disposable)
3. RAID 0 = NO redundancy (one drive fails = lose pool)
4. Backup GitLab weekly (RAID ≠ backup)

---

## Summary

| Pool | RAID | Drives | Usable | Protected | VMs |
|------|------|--------|--------|-----------|-----|
| esxi-system | 1 | 2x500GB | 500GB | ✅ Yes | ESXi + small VMs |
| vm-critical | 1 | 2x1TB | 1TB | ✅ Yes | GitLab |
| vm-ephemeral | 0 | 2x1TB | 2TB | ❌ No | Runner + QA |
| **TOTAL** | | **6** | **3.5TB** | | |

