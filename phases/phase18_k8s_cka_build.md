# Phase 18 — Kubernetes the hard way(ish): a 5-node HA `kubeadm` cluster with kube-vip

**Status:** 📋 **PLAN — DRAFT, AWAITING ANDREW'S REVIEW. Nothing has been built.**
**Created:** September 16, 2026
**Owner:** Andrew
**Track:** `education/k8s-cka/` (settled Sep 16, 2026 — aligned to the VM naming)
**Supersedes nothing.** Phase 17 (Jenkins) is **ON HOLD at Part 4**, paused not closed.

> 🙋 **Andrew, Sep 16, 2026:** *"phase18_k8s_cka_build — where we will properly build a 5 node setup
> (2 worker nodes, 3 control plane workers) and use kube-vip to get a fully HA setup — and create
> documentation and study materials like the other education phases so I can onboard to my new job and
> pass my CKA exam."*

**Two deliverables, and the second is not a by-product:** a real HA cluster, and study material good
enough to (a) onboard onto the firm's platform and (b) pass the **CKA**. The exam is a *dated,
externally-defined syllabus*, which is new for this project — previous tracks were scoped by what the
lab could teach. Here an outside authority decides what "complete" means, so the track carries a
**curriculum coverage matrix** and every domain is marked hands-on or not.

---

## 1. Success, as a sentence

**"Build a five-node Kubernetes cluster with `kubeadm` from nothing, make its control plane genuinely
highly available behind a kube-vip VIP, prove the HA by killing control-plane nodes one at a time,
back up and restore etcd, upgrade the cluster in place, and explain what each failure did to the
workload and to the API."**

⭐ **Two words in that sentence are load-bearing.** *`kubeadm`*, because the CKA is a kubeadm exam and
Phase 14's k3s hides precisely the components the exam tests. And *prove*, because a three-member
control plane that has never lost a member is not known to be HA — it is only configured to be.

---

## 2. Why this is not a repeat of Phase 14, and the prohibition that follows

Phase 14 built **single-node k3s** on `.186`. It is a different exercise in the ways that matter:

| | Phase 14 (`.186`) | Phase 18 (this) |
|---|---|---|
| Distribution | k3s (single binary, SQLite, batteries included) | **`kubeadm`** — the exam's tool |
| Control plane | 1 node, no quorum | **3 nodes, stacked etcd, quorum 2 of 3** |
| API endpoint | the node's own IP | **a kube-vip VIP** that survives losing a node |
| CNI | k3s's bundled flannel | **installed by hand** — the step k3s hides |
| etcd | SQLite, not etcd at all | **real etcd**, backed up and restored |
| Why | interview prep, closed | **CKA + onboarding** |

🚨 **HARD RULE B1 (see §7): `.186` IS FROZEN AND IS NOT PART OF THIS PHASE.** It is deliberately
unpatched, out of `refresh.sh`, and holds ~40 findings that exist nowhere else. ⛔ **Do not touch it,
do not "upgrade" it, do not run `k3s-uninstall.sh`, and do not fold the two clusters together.**

⚠️ **A documentation consequence to handle at the END, not now:** `MEMORY.md` currently states as a
prohibition that *"the only Kubernetes in this lab is k3s on VM 186"* — written to stop sessions
mistaking `.180` for a k8s box. **That sentence stops being true the moment this cluster exists**, and
it appears in more than one place. Rewriting it early would remove a guard that is still correct;
leaving it forever produces a file arguing with itself. **It gets rewritten in the closing pass, to
distinguish the two clusters by purpose rather than by uniqueness.**

---

## 3. Topology

```
                        VIP  (kube-vip, ARP/L2)  ← kubectl and every node talk to THIS
                          │        :6443
        ┌─────────────────┼─────────────────┐
     cp-1              cp-2              cp-3          3 × control plane, stacked etcd
   (etcd member)    (etcd member)    (etcd member)     quorum = 2 of 3
        └─────────────────┴─────────────────┘
                          │
                 ┌────────┴────────┐
              worker-1          worker-2               2 × worker, workload only
```

**Names (settled by Andrew, Sep 16, 2026):** `vm-k8s-cka-control-1/2/3` and `vm-k8s-cka-worker-1/2`.
⭐ Note these carry the **`vm-` prefix** the rest of the lab uses (`vm-www-1`, `vm-jenkins-1`,
`vm-docker-qa-1`) — the Swarm's bare `docker-swarm-N` is the odd one out, and this returns to the
convention. The short forms `control-1`, `worker-2` are used in prose below for readability; the
**hostname and the `qm --name` are always the full string**, because those are what `ssh` and `qm` need.
**Runtime:** containerd (see the trap in 🅒 T1 — the lab's build standard actively breaks this).
**CNI:** proposed **Calico** (🅐 A4) — chosen because `NetworkPolicy` is on the CKA syllabus and the
lab's other CNI experience (flannel via k3s) cannot enforce one.

---

## 4. Resources — measured Sep 16, 2026, not read from the docs

| | Assigned now | This phase adds | After |
|---|---|---|---|
| **vCPU** | **54 of 48 threads (112%)** | +10 (5 × 2) | **64 of 48 (133%)** |
| **RAM** | 104 GB of 187 GB usable | +20 GB (5 × 4 GB) | 124 GB (66%) |
| **Disk** (`vm-ephemeral`) | 662 G used / 1.16 T avail | ~5 × 46 G reserved ≈ 230 G | ~1.15 T → ~920 G avail |

🔻 **`MEMORY.md` says vCPU is "42 of 48 threads". That is WRONG — it is 54**, summed live from
`qm config` across the ten running guests. So **the host is already oversubscribed on CPU before this
phase adds anything**, which is the opposite of what the planning note implies. Corrected in `MEMORY.md`
as part of this phase's opening commit.

✅ **CPU OVER-ALLOCATION IS FINE HERE, AND IT WAS MEASURED RATHER THAN ARGUED.** Host CPU from PVE's
own RRD over the last **year** (1111 samples): **mean 1.11%, median 0.75%, p95 2.74%, p99 4.06%,
max 4.09%.** Load average is **0.70 on 48 threads**. ⛔ **So the Swarm nodes stay running** (A5 closed)
and no VM gets shrunk. ⚠️ Do **not** drop a control plane below **2 vCPU** regardless — `kubeadm`
preflight *fails* below that, and it is an exam-relevant requirement, not a suggestion.

⚠️ **BUT READ THE INSTRUMENT BEFORE QUOTING THAT `max 4.09%`.** The year timeframe averages roughly
**8 hours per sample**, so a five-minute burst at 100% appears as about 1%. **That maximum means "no
8-hour window averaged above 4%", NOT "the host never got busy."** Andrew's recollection of ~25% under
test load is entirely compatible with this data, and would not appear in it. ⭐ **Same house rule as
everywhere else: the number is honest and it answers a narrower question than it looks like it
answers.** For real contention the instrument is **`%st` (steal time) inside the guests**, not host
CPU% — steal is the guest saying it wanted CPU and did not get it, which is the actual symptom.

🚨 **The binding constraint for THIS phase is not CPU at all — it is etcd's fsync latency.** etcd
fsyncs every write to its write-ahead log before acknowledging it, and when that fsync is slow the
cluster does not slow down gracefully: it holds leader elections and logs *"apply entries took too
long"*, which reads exactly like a network fault. Measured posture of the target pool: `sync=standard`,
`logbias=latency`, **no SLOG**, two NVMe in a stripe — reasonable, since NVMe absorbs sync writes well,
but a ZFS zvol still adds write amplification underneath it. **Watch `etcd_disk_wal_fsync_duration_seconds`
p99 (etcd's own guidance is under 10 ms) rather than assuming.**

⭐ **And the honest caveat that belongs in the chapter, not just here: three etcd members on one host
sharing two physical NVMe drives are not three failure domains.** They share a host, a ZFS pool, and a
power supply. This lab can therefore demonstrate **member** failure convincingly and **cannot**
demonstrate host or site failure at all. It is the same limitation Phase 14 recorded for three Redpanda
brokers in one VM and Phase 16 for three Swarm VMs on one host — **the third appearance of one fact:
there is one piece of hardware.** Say it once, clearly, and do not let it become wallpaper.

**Storage placement: `vm-ephemeral`, deliberately.** It is a **no-redundancy stripe**, which is the
correct home for a cluster whose whole point is to be destroyed and rebuilt from a script. ⚠️ Stated
plainly so it is never mistaken for an oversight: **a pool failure loses this cluster, and that is
accepted.** Nothing irreplaceable may ever live here.

---

## 5. Addressing — RESOLVED Sep 16, 2026, and the two unknowns are identified

🙋 **Andrew moved the G3100's DHCP pool to `.221–.250` that afternoon**, so everything below `.221` is
now available for static assignment. **Both previously-unknown hosts were then identified by MAC:**

| Address | MAC | Vendor | What it is |
|---|---|---|---|
| `.200` | `2c:82:17:d9:3a:d8` | **Apple, Inc.** | ✅ Confirms the docs — the Mac mini running Plex. First time this was evidence rather than a claim |
| `.202` | `00:06:78:c8:ee:21` | **D&M Holdings** (Denon / Marantz) | An AV receiver. Household kit, **not lab infrastructure** — it belongs in no phase file |

🚨 **THE HAZARD THAT SURVIVES THE POOL CHANGE, and it is the reason for the allocation below: a ping
sweep proves an address is free RIGHT NOW, not that it is UNCLAIMED.** A device that is powered off or
out of the house still holds its DHCP lease and will reappear on that address. Moving the pool does
**not** revoke leases already handed out — clients keep their address until the lease expires. So the
old pool's range may hold live claims by absent devices, and `.202` is proof the old pool reached at
least that far. ⭐ **Same shape as this project's standing rule about instruments: the sweep answered
"who replies to ping", not "what is allocated".**

✅ **THEREFORE: allocate inside `.187–.199`, which was NEVER in any DHCP pool** — every address in
`.150–.196` has been static lab infrastructure for the life of this project, so no lease can exist
there. This costs a contiguous run and buys immunity from an entire class of collision.

| Role | VMID | Address |
|---|---|---|
| `vm-k8s-cka-control-1` | 187 | `192.168.1.187` |
| `vm-k8s-cka-control-2` | 188 | `192.168.1.188` |
| `vm-k8s-cka-control-3` | 189 | `192.168.1.189` |
| `vm-k8s-cka-worker-1` | 190 | `192.168.1.190` |
| `vm-k8s-cka-worker-2` | 194 | `192.168.1.194` |
| **kube-vip VIP** | **— none —** | **`192.168.1.196`** |

📌 **The VIP has NO VM behind it.** It must be recorded in `MEMORY.md` → IPs & HOSTS as *"no VM —
kube-vip control-plane VIP"*, or a future session will hunt `qm list` for a guest that does not exist —
the exact confusion the `.195` row was added to fix.
⚠️ **`.194` breaks the contiguous run on purpose** (`.191–.193` are the Swarm). Do not "tidy" the
cluster into `.2xx` later for neatness; that range is the one with unrevoked leases in it.

> **If you ever DO want the tidy `.203–.207` run:** it needs the router's lease table checked for
> outstanding entries in that range, not a ping sweep. On the G3100 that is
> **Advanced → Network Settings → IP Address Distribution → Connection List**, which lists MAC, IP and
> lease expiry with a delete icon per row. ⚠️ **Deleting a lease does not notify the client** — it keeps
> its address until its own timer expires, so you must also make the device re-request: toggle its
> Wi-Fi, unplug/replug Ethernet, or power-cycle it (for the Denon, a power cycle is easiest).
> Per-OS: `dhclient -r && dhclient` on Linux, `ipconfig /release && ipconfig /renew` on Windows,
> *Renew DHCP Lease* in macOS network details. **None of this is needed for this phase** — the
> `.187–.199` block avoids the question entirely.

---

## 6. The parts

**Part 0 — Provision.** Five VMs from template 9000, `host_setup.sh --server --no-nas`, `qm resize`,
verified from **inside** each guest (`df -h /`), snapshot `c01-base-clean` on all five together.
🤖 **AI may drive** — cloning from 9000 is proven plumbing, not the subject (`METHOD.md` split).
📌 `--no-nas` is deliberate: a study cluster does not need NAS credentials, and the `.184` finding
showed a uniform build standard plants credentials on hosts that should not have them.

**Part 1 — Make the nodes able to run Kubernetes at all.** containerd CRI + cgroup driver, kernel
modules, sysctls, kubelet/kubeadm/kubectl pinned to one minor version. 🅒 **T1 and T2 fire here.**
🙋 **Andrew drives** — this is the subject.

**Part 2 — kube-vip BEFORE the cluster exists.** The VIP has to answer *before* `kubeadm init`, because
`--control-plane-endpoint` must point at it from the first second. 🅒 **T3, and T4 is armed here.**

**Part 3 — `kubeadm init` cp-1, then CNI, then join cp-2 and cp-3.** Snapshot `c02-cp1-init`,
`c03-ha-control-plane`. 🅒 **T5 fires.** 🙋 Andrew does cp-2 by hand; 🤖 the AI joins cp-3 (repetition
rule).

**Part 4 — Join the workers, run a real workload.** Snapshot `c04-cluster-complete`.

**Part 5 — BREAK IT. The centre of gravity.** Drills, each with its "what to conclude" written *before*
running: lose one control plane (expect: no impact, VIP moves); lose two (expect: **reads fail too**,
not just writes — the Phase 16 Swarm finding and the Phase 14 Redpanda finding predict this, and
confirming it across three orchestrators is the best cross-track result available here); kill the VIP
holder; `drain` a node with a PodDisruptionBudget in the way; a `default-deny` NetworkPolicy that also
kills DNS.

**Part 6 — etcd backup and restore, and a cluster upgrade.** Both are CKA exam tasks and both are real
operational skills. **Restore is only proven if the cluster comes back after a deliberate destruction.**

**Part 7 — RBAC, static pods, troubleshooting the exam's way.** Fill the remaining syllabus domains.

**Part 8 — The track.** Chapters + the CKA coverage matrix. ⚠️ **`education/CONVENTIONS.md` is a
mandatory read before the first chapter** and has not been read yet — it governs chapter shape,
figures, the DOCX build and the highlight pass.

---

## 7. 🅑 Hard rules

- **B1 — `.186` is frozen and out of scope.** See §2.
- **B2 — `vm-ephemeral` only, and nothing irreplaceable ever lives on this cluster.** No-redundancy stripe.
- **B3 — Do NOT "fix" `setup_docker.sh` to enable containerd's CRI plugin.** 🚨 This looks like the
  fleet-wide fix the lab keeps rewarding, and here it is **wrong**: every other host in this lab is a
  *Docker* host, and Docker's containerd deliberately disables CRI. A Kubernetes node needs a
  *different* containerd configuration, not a patched shared one. ⭐ **The general point, and it is
  chapter material: one build standard cannot serve both a Docker host and a Kubernetes node** —
  the lab has been able to pretend otherwise only because it had no kubeadm nodes.
- **B4 — Never point this cluster at `production/*` in the registry.** Same reasoning as Phase 17's
  B10: `.180` and `.184` pull `production/capricorn/<svc>:latest`, so a push there ships to PROD.
- **B5 — Snapshot all five nodes together or not at all.** Distributed state with etcd quorum; rolling
  one node back to where the others have moved on is an unplanned debugging session (`METHOD.md`).
- **B6 — Do not deploy Capricorn to this cluster.** Application layer, owned by its own project. A
  neutral workload is enough and keeps the phase honest about scope.

## 8. 🅒 Planted traps — ⛔ DO NOT FIX BEFORE THEY FIRE

| # | Trap | Precondition | Status |
|---|---|---|---|
| **T1** | **containerd's CRI plugin is disabled**, so `kubeadm init` hangs waiting for a kubelet that cannot talk to a runtime. The error names the kubelet, not containerd. | `disabled_plugins = ["cri"]` present on a lab-built host | ✅ **VERIFIED Sep 16, 2026 on `.191`** — line 15 of `/etc/containerd/config.toml`. **The trap can fire.** |
| **T2** | **cgroup driver mismatch** — containerd defaults to `cgroupfs`, kubelet on Ubuntu expects `systemd`. Fails late and intermittently under load, not cleanly at init. | `SystemdCgroup` unset in the config | ✅ **VERIFIED Sep 16, 2026 on `.191`** — not present at all, so the setting you must change **does not exist in the file to edit**. |
| **T3** | **`kubeadm init` without `--control-plane-endpoint`.** Works perfectly for one node, and then cp-2 **cannot ever join** — the apiserver certificate has no SAN for the VIP. Recovering means regenerating certs or starting over. | Trivially available | 🔲 Armed by construction |
| **T4** | **The join token expires after 24 h.** Come back the next day to add cp-3 and the join fails with an error that reads like a network problem. | Default `kubeadm` TTL | 🔲 Armed; fires only if a session boundary lands mid-phase — **do not "helpfully" use an infinite TTL** |
| **T5** | **Nodes sit `NotReady` and CoreDNS stays `Pending` forever** until a CNI is installed. Looks like a broken cluster; is a cluster with no network. | Default | 🔲 Armed by construction |
| **T6** | **`default-deny` NetworkPolicy silently breaks DNS**, because egress to `kube-dns` was not allowed. Every symptom looks like an application bug. | Needs Calico (🅐 A4) | 🔲 Depends on A4 |
| **T7** | **Losing 2 of 3 control planes fails READS, not just writes.** The instinct is that a quorum loss degrades gracefully to read-only. | 3 etcd members | 🔲 Armed |
| **T8** | **After any host reboot the whole cluster is down** (`onboot 0`), and etcd members come back at different times. | Autostart policy | 🔲 Armed — ⚠️ **may fire by accident**; record it if it does |

⚠️ **`METHOD.md` rule:** checking a precondition is **not** pre-empting a trap. T1 and T2 were verified
by one read-only `grep` on an existing host, which does not make the diagnosis free when they fire.

## 9. 🅐 Open items — need Andrew

| # | Question | Status |
|---|---|---|
| **A1** | Addressing, and what `.202` is | ✅ **CLOSED Sep 16** — DHCP moved to `.221–.250`; `.200` = Apple (Mac mini), `.202` = Denon/Marantz receiver. Cluster takes `.187–.190` + `.194`, VIP `.196`. See §5 |
| **A2** | Node naming | ✅ **CLOSED Sep 16 — Andrew's names: `vm-k8s-cka-control-1/2/3` and `vm-k8s-cka-worker-1/2`.** Restores the lab's `vm-` prefix, which the Swarm's `docker-swarm-N` had dropped |
| **A3** | Track folder | ✅ **CLOSED Sep 16 — `education/k8s-cka/`**, aligned to the VM names rather than invented separately. ⚠️ It tab-completes alongside track 1's `k8s-k3s-redpanda/`, so **always write the full track name in a command**; the build tooling takes the track as its first argument and a wrong one silently builds the wrong book |
| **A4** | **CNI choice** | ✅ **DECIDED Sep 16 — Calico.** Kubernetes ships with **no** pod network at all (that is trap T5), so one must be installed. Calico is the conventional `kubeadm` pairing, uses ordinary Linux routing, and **enforces `NetworkPolicy`, which is on the CKA syllabus** and is what makes T6 possible. Cilium is more modern (eBPF, better observability) but is a second large subject on top of the exam; flannel — what k3s gave track 1 — **cannot enforce a policy at all**, so the lab has no policy experience yet |
| **A5** | Stop the Swarm VMs to reclaim CPU? | ✅ **NOT NEEDED — measured.** Host CPU over the last year: mean **1.11%**, p95 **2.74%**, p99 **4.06%**. Leave the Swarm running. See §4 |
| **A6** | Kubernetes version | ✅ **DECIDED Sep 16 — build `v1.36.4`, upgrade to `v1.37.0` in Part 6.** Latest stable is **v1.37.0**, so one minor behind gives the in-place upgrade drill a real destination instead of a no-op. ⚠️ **Andrew has not named an exam date**, so the coverage matrix is built against the current published syllabus and must be re-checked if he books a dated sitting |
| **A7** | **Roadmap deviation — CONFIRMED BY ANDREW.** `education/fin_tech_stack.txt` lists **OpenSearch** next and the standing rule is to work it step-by-step | ✅ **CLOSED Sep 16 — Andrew set the list aside for this phase, explicitly and on the record.** His grounds: the CKA is a **dated external commitment**, and Kubernetes is **#1 on that very list** but was only ever built as single-node k3s, so the item was never actually finished. ⛔ **A future session must NOT 'correct' this back to OpenSearch** — the override is recorded in `MEMORY.md` beside the ROADMAP RULE itself, because a rule and its exception must live together or the rule wins by default |

## 10. 🅓 Inherited and OUT OF SCOPE

Capricorn (application layer, own project) · Jenkins/CI integration (Phase 17, on hold) · Redpanda,
OpenSearch, Prometheus (later phases) · the `.186` k3s cluster (frozen) · the pre-Aug-21 fleet
containerd retrofit (a real open item, but a **Docker** problem — see B3) · production-grade ingress,
storage classes and service mesh, unless the syllabus requires them.

## 11. Validation — what "done" means

Every claim proven from **inside** the cluster, not from a control-plane report:
`kubectl get nodes` all `Ready` from a **kubectl that talks to the VIP** · `etcdctl endpoint status`
showing 3 members and one leader · a control-plane node powered off and the API still answering ·
the VIP demonstrably **moved** (ARP, not assumption) · an etcd restore that brings back a workload
deliberately deleted first · an upgrade from **v1.36.4 to v1.37.0** that leaves every node one minor
higher · every CKA domain marked hands-on or explicitly not.

📊 **Two baselines to capture BEFORE the first drill, because they are worthless afterwards:**
**etcd `wal_fsync_duration_seconds` p99 while healthy** (so a later election storm can be attributed to
disk latency or exonerated — see §4) and **`%st` steal time inside two guests** (so the CPU
over-allocation decision can be revisited with evidence rather than re-argued). ⭐ **A baseline taken
after the incident is not a baseline.**

## 12. Who drives what (`METHOD.md`)

🙋 **Andrew:** everything Kubernetes — runtime config, `kubeadm`, kube-vip, CNI, the drills, the
diagnosis when something breaks. First control-plane join by hand.
🤖 **AI:** VM cloning and `host_setup.sh`, the third control-plane join and the second worker
(repetition rule), all writing, all scripts as committed artefacts.
🚨 **When a trap fires, the AI stays quiet until asked.** Debugging while confused is the exam skill
and the job skill.
