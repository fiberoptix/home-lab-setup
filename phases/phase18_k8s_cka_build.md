# Phase 18 — Kubernetes the hard way(ish): a 5-node HA `kubeadm` cluster with kube-vip

**Status:** 📋 **PLAN — DRAFT, AWAITING ANDREW'S REVIEW. Nothing has been built.**
**Created:** September 16, 2026
**Owner:** Andrew
**Track:** `education/kubernetes-cka/` (proposed name — see 🅐 A3)
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

**Names:** `k8s-cp-1/2/3` and `k8s-worker-1/2` (proposed — 🅐 A2).
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

⭐ **Oversubscription is not automatically a problem** — these guests are overwhelmingly idle, and 133%
of threads on a 24-core/48-thread Xeon is normal virtualisation practice. But it is **CPU, not RAM,
that is now the binding constraint**, which inverts the assumption the lab has planned against all
year, and a five-node cluster running control-plane components is less idle than a Swarm node.
**Two levers exist if it bites, in this order** (🅐 A5):
1. **Stop the three Swarm nodes while working on this phase.** They are `onboot 0`, Phase 16 is closed
   and Phase 17 is on hold, so nothing needs them until Jenkins Part 4 resumes. **Frees 6 vCPU / 12 GB
   instantly and reversibly.** ⛔ **Stop, never destroy** — Part 4 deploys to them.
2. Drop the workers to 2 GB. ⚠️ Do **not** drop control planes below **2 vCPU** — `kubeadm` preflight
   *fails* below that, and it is a documented exam-relevant requirement rather than a suggestion.

**Storage placement: `vm-ephemeral`, deliberately.** It is a **no-redundancy stripe**, which is the
correct home for a cluster whose whole point is to be destroyed and rebuilt from a script. ⚠️ Stated
plainly so it is never mistaken for an oversight: **a pool failure loses this cluster, and that is
accepted.** Nothing irreplaceable may ever live here.

---

## 5. Addressing — ⚠️ NOT SETTLED, and there is a real hazard (🅐 A1)

**Measured by ping sweep, Sep 16 2026.** Free: `.187–.190`, `.194`, `.196–.199`, `.201`, `.203–.210`.
In use: `.191–.193` (Swarm), `.195` (dev box), `.200`, **`.202`**.

🚨 **`.202` answers ping and appears in NO project documentation.** `.200` is known (the Mac mini
running Plex, per the Phase 12 router notes) but `.202` is not in `MEMORY.md`'s IPs & HOSTS table at
all. ⛔ **Do not allocate anything in the `.2xx` range until it is identified** — an unknown live host
next to a proposed static block is exactly how a duplicate-address incident starts, and this lab has
already had one near-miss from a cloned VM claiming a live address.

🚨 **The deciding question is the router's DHCP pool, which nobody has written down.** Every lab host
is a static address inside `.150–.196`; if the G3100's pool starts at `.200` (a common default), then
`.202` is simply a phone and **the whole `.2xx` range is unsafe for static assignment.**

**Two candidate allocations. Preference depends entirely on that answer:**

| | Nodes | VIP | Verdict |
|---|---|---|---|
| **Option A** | VMIDs 203–207 → `.203–.207` | `.208` | Contiguous, VMID matches last octet, ✅ **only if the DHCP pool excludes it** |
| **Option B** | VMIDs 187–190 + 194 → `.187–.190`, `.194` | `.196` | Non-contiguous and slightly ugly, but ✅ **inside the proven-static block** |

⭐ **Option B is the safer default** and I recommend it unless the DHCP pool is confirmed. The VMID↔IP
convention still holds for every node; only the tidiness of a contiguous run is lost.
📌 **The VIP is an address with NO VM behind it.** It must be outside DHCP *and* outside anything
Proxmox might hand out, and it must be recorded in `MEMORY.md`'s IPs & HOSTS with "no VM — kube-vip
VIP", or a future session will hunt for a guest that does not exist.

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

| # | Question | Why it cannot be defaulted |
|---|---|---|
| **A1** | **Addressing: Option A or B, and what IS `.202`?** | An unidentified live host and an unknown DHCP pool. A duplicate address takes down a live host, and only Andrew can read the router. |
| **A2** | Node naming: `k8s-cp-1/2/3` + `k8s-worker-1/2`? | Convention is his; the Swarm used `docker-swarm-N`. |
| **A3** | Track folder: `education/kubernetes-cka/`? | ⚠️ Must not be confusable with track 1's `k8s-k3s-redpanda/`. |
| **A4** | **CNI: Calico?** | Recommended — `NetworkPolicy` is on the syllabus and enables T6. Cilium teaches eBPF but is a bigger subject; flannel cannot do policy at all. |
| **A5** | May I **stop the three Swarm VMs** during this phase to reclaim 6 vCPU / 12 GB? | Reversible, but it takes Jenkins Part 4's target offline while the phase runs. |
| **A6** | **Which CKA version/date are you sitting?** | The syllabus is versioned and the coverage matrix is worthless against the wrong one. Also sets the Kubernetes minor version to build. |
| **A7** | **Roadmap deviation — confirm on the record.** `education/fin_tech_stack.txt` says next is **OpenSearch**, and the standing rule is to work the list step-by-step. | Kubernetes *is* #1 on that list and was only ever done as single-node k3s, and the CKA is a dated commitment — so this is defensible. But the rule exists to stop the AI re-deriving priorities, so **you** should be the one to set it aside. |

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
deliberately deleted first · an upgrade that leaves every node one minor version higher · every CKA
domain marked hands-on or explicitly not.

## 12. Who drives what (`METHOD.md`)

🙋 **Andrew:** everything Kubernetes — runtime config, `kubeadm`, kube-vip, CNI, the drills, the
diagnosis when something breaks. First control-plane join by hand.
🤖 **AI:** VM cloning and `host_setup.sh`, the third control-plane join and the second worker
(repetition rule), all writing, all scripts as committed artefacts.
🚨 **When a trap fires, the AI stays quiet until asked.** Debugging while confused is the exam skill
and the job skill.
