# Phase 18 — Kubernetes the hard way(ish): a 5-node HA `kubeadm` cluster with kube-vip

**Status:** ✅ **APPROVED by Andrew, Sep 16, 2026, 5:48 PM — he read it and signed it off. Nothing is
built yet; Stage 0 may begin.**

> 🙋 **His governing directive, and it settles arguments so record it once:** *"As an engineer I think we
> should go step by step in the proper order — by the book — like standard best practices would require.
> We are not in a rush. We are learning, documenting, and studying."*

⭐ **What "by the book" DECIDES, so it is not just a sentiment:**
- **Follow the upstream documented procedure** (kubernetes.io → *Creating Highly Available Clusters with
  kubeadm*) rather than a shortcut that happens to work. Where our lab must deviate, **say so at the step.**
- ⛔ **No skipped steps and no batching.** Each step gets its confirmation before the next one starts —
  which is already `CONVENTIONS.md`'s chapter rule, now also the build rule.
- ⛔ **Time is not a constraint.** If a step needs an hour of reading first, it gets one. **Nothing here is
  deadline-driven except the exam, and that is Stage 3.**
**Created:** September 16, 2026
**Owner:** Andrew
**Track:** `education/k8s-cka-prep/` — 🔻 **moved there Sep 16, 2026 at Andrew's direction**, so the
research and the chapters share one folder instead of splitting prep from track
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

## 1. Success — 🔻 TWO sentences, because there are two goals

🙋 **Andrew, Sep 16, 2026:** *"Do you understand I need to learn how to deploy, install and configure k8s
for work AND then study for CKA separately?"* **Yes — and they need separate finish lines.**

**1 — For WORK:** *"Build a five-node Kubernetes cluster with `kubeadm` from nothing, make its control
plane genuinely highly available behind a kube-vip VIP, and write it up as a procedure someone else could
follow and repeat."*

**2 — For the EXAM:** *"Then, on that cluster, drill one class of CKA administrative task per chapter
until every curriculum domain has been done by hand, weighted the way the exam weights them."*

⭐ **Four words across those sentences are load-bearing.** *`kubeadm`*, because the CKA is a kubeadm exam
and Phase 14's k3s hides precisely the components it tests. *Procedure*, because goal 1 fails if the
write-up only makes sense to whoever was in the room. *By hand*, because 🟢 the exam is entirely
performance-based — there is no multiple choice to revise for. And *then*, because Stage 3 does not open
until the cluster is built, tested and documented.

⛔ **Do not merge the two goals back into one.** The first draft of this plan did exactly that and
produced an excellent infrastructure phase that covered barely half the exam — see §8 and 🅐 A8.

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

**Sizing (settled by Andrew, Sep 16, 2026): 2 vCPU / 4 GB / 40 GB each, all five on `vm-ephemeral`.**
⚠️ **2 vCPU is a floor, not a choice** — `kubeadm` preflight *fails* below it on a control plane. 40 GB
matches the Swarm nodes, and the template ships 3.5 GB, so **`qm resize` is mandatory** and the
filesystem only follows if cloud-init's `growpart` fires — **verify with `df -h /` inside the guest.**

**Names (settled by Andrew, Sep 16, 2026):** `vm-k8s-cka-control-1/2/3` and `vm-k8s-cka-worker-1/2`.
⭐ Note these carry the **`vm-` prefix** the rest of the lab uses (`vm-www-1`, `vm-jenkins-1`,
`vm-docker-qa-1`) — the Swarm's bare `docker-swarm-N` is the odd one out, and this returns to the
convention. The short forms `control-1`, `worker-2` are used in prose below for readability; the
**hostname and the `qm --name` are always the full string**, because those are what `ssh` and `qm` need.
**Runtime:** containerd, **configured for Kubernetes in Stage 0** — ⚠️ the lab's standard build leaves
it configured for *Docker*, which a kubeadm node cannot use. See §8.
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

| Address | Vendor (by MAC) | What it is |
|---|---|---|
| `.200` | **Apple** | The Mac mini running Plex — household, not lab |
| `.231` | **D&M Holdings** (Denon/Marantz) | AV receiver, household. **Was on `.202`**; moved into the DHCP pool once Andrew set it back to DHCP, so **`.202` is free** |

✅ **ALLOCATION — SETTLED, and all six verified free by ARP at 4:12 PM:**

| Role | VMID | Address |
|---|---|---|
| `vm-k8s-cka-control-1` | 201 | `192.168.1.201` |
| `vm-k8s-cka-control-2` | 202 | `192.168.1.202` |
| `vm-k8s-cka-control-3` | 203 | `192.168.1.203` |
| `vm-k8s-cka-worker-1` | 204 | `192.168.1.204` |
| `vm-k8s-cka-worker-2` | 205 | `192.168.1.205` |
| **kube-vip VIP** | **— none —** | **`192.168.1.206`** |

🚨 **CHECK FREE ADDRESSES WITH ARP, NOT PING.** `.150` proves a host can be alive and silent to ICMP, so
"no ping reply" can mean "present but dropping pings". Delete the neighbour entry, ping once to force
ARP, then read `ip neigh` — **a `lladdr` means OCCUPIED even when the ping failed.**

⚠️ **Residual caveat:** `.215`, `.217` and `.220` hold household devices on **pre-change leases** — below
the pool, keeping addresses issued before it was narrowed. ⛔ **Sweep before allocating anything in
`.207–.220`.** Still re-sweep the six immediately before Stage 0; it is one command.

📌 **AND A SIXTH ADDRESS IS REQUIRED EITHER WAY — the plan asked for five.** kube-vip needs a **VIP with
no VM behind it**, so five nodes need six addresses. It must be recorded in `MEMORY.md` → IPs & HOSTS as
*"no VM — kube-vip control-plane VIP"*, or a future session will hunt `qm list` for a guest that does not
exist, which is the exact confusion the `.195` row was added to fix.

---

## 6. The four stages (0–3, Andrew's numbering) — 🔻 RESTRUCTURED Sep 16, 2026 at his direction

🙋 **Andrew:** *"Do you understand I need to learn how to deploy, install and configure k8s for work AND
then study for CKA separately? I know there will be some overlap."*

⭐ **Yes — and it is a better shape than the plan it replaces.** Two goals with **different success
conditions**, run in sequence instead of blended: **Stages 0 and 1 are WORK skills** (a procedure he can
repeat at the firm), **Stage 3 is EXAM preparation** and starts only once a standard cluster is up,
tested and documented. ⭐ **The overlap is an asset, not duplication:** by the time Stage 3 begins, etcd,
the control-plane components, the kubelet and the CNI are things he *installed*, not exam trivia — which
is exactly the position the exam's own framing assumes, since it hands you a built cluster to administer.

### Stage 0 — five VMs, ready for Kubernetes → **chapter 01**

**Add, then subtract.** Clone five from template 9000, size them (⚠️ **2 vCPU minimum on control
planes — `kubeadm` preflight FAILS below that**), resize the 3.5 GB template disk, set static addresses
and hostnames, run `host_setup.sh --server --no-nas`. **Then remove what a Kubernetes node should not
have and add what it needs:**

- ⛔ **Remove Docker Engine.** Real Kubernetes nodes do not run it, and leaving it means two image
  stores with `docker ps` and `crictl` disagreeing about reality.
- ✅ **Configure containerd properly** — CRI plugin **enabled**, `SystemdCgroup = true` to match the
  kubelet. 🚨 **This is the single step most likely to waste an afternoon if skipped**, because the
  failure surfaces as a kubelet that will not start and says nothing about containerd. See §8.
- ✅ Kernel modules (`overlay`, `br_netfilter`), sysctls (IPv4 forwarding, bridge-nf-call-iptables),
  **swap off**, then `kubeadm`/`kubelet`/`kubectl` **pinned to v1.35** and held.
- ✅ **Exam-shaped tooling: `yq`, the `k` alias with completion.** ⛔ **No `jq`, no `krew`, no `k9s`, no
  `kubectx`** — full reasoning in `education/k8s-cka-prep/lab-parity.md`.
- ✅ **Verify from INSIDE each guest** (`df -h /`, `swapon --show`, `containerd config dump`), never from
  `qm config`.

📸 Snapshot **all five together**: `c01-nodes-ready`. 🙋 Andrew drives the node preparation; 🤖 the AI may
drive the cloning, which is proven plumbing (`METHOD.md` split).
📄 **Deliverable: chapter 01, written as a numbered, repeatable procedure** — each step with how to
confirm it took effect.

🔻 **CHAPTER 01 IS SCOPED AS *PORTABLE NODE PREP*, settled by Andrew Sep 16, 2026.** Its subject is
**"given a fresh Ubuntu host, what makes it a Kubernetes node"** — containerd and the CRI, the cgroup
driver, swap, kernel modules, sysctls, package pinning, tooling. ⭐ **The Proxmox side gets a pointer,
not a walkthrough**, which also satisfies `CONVENTIONS.md`'s rule to assume settled lab plumbing.
🚨 **The reason is that at the firm he will be HANDED the VMs.** Cloning from template 9000 is the one
part of this build that **cannot** transfer, so a chapter organised around it would teach the least
useful half in the most detail.
⚠️ **Consequence worth getting right: the chapter must NOT be organised around `host_setup.sh` either.**
There is no script server at work. **The spine is the node's REQUIREMENTS**; our script is mentioned as
the thing that happens to satisfy some of them here. ⭐ *State what must be true, then how we made it
true* — that ordering is what makes it repeatable somewhere else.
✅ **Cockpit stays on the nodes** (Andrew's call) — it is a lab access method, not a Kubernetes crutch,
and it cannot teach a bad exam habit. It is one of the lab-specific items the chapter marks as *ours,
not required*.

### ✅ Stage 0 — COMPLETE, Sep 16, 2026 (results)

🙋 **Andrew ran every command himself** from the dev box; the AI wrote the script and verified the fleet.

🚨 **THE STAGE 0 / STAGE 1 BOUNDARY, because it is easy to misread and Andrew queried it:** Stage 0
**installed the Kubernetes PACKAGES and left them inert.** `kubeadm`, `kubelet` and `kubectl` are on every
node and apt-held, containerd is running with the CRI plugin enabled — but **no cluster exists.** No
`kubeadm init`, no `kubeadm join`, no CNI, and **the kubelet is `inactive` on purpose**; it crash-loops or
waits until a cluster exists, which is normal and not a fault. ⭐ *"The tools are installed"* and *"the
cluster is configured"* are different states and Stage 1 is the second one.

| | |
|---|---|
| Nodes | **5/5 running and IDENTICAL** — `vm-k8s-cka-control-1/2/3` at `.201`–`.203`, `vm-k8s-cka-worker-1/2` at `.204`–`.205`, 2 vCPU / 4 GB / 40 GB each, all **`onboot 0`** per the lab autostart policy |
| Kubernetes | **v1.35.8** (`kubeadm`/`kubelet`/`kubectl`), **apt-held** on every node. ⚠️ `kubeadm` itself reported *"remote version is much newer: v1.37.0; falling back to stable-1.35"* — independent confirmation the two-minor gap to the exam is deliberate |
| Runtime | containerd **active**, `io.containerd.grpc.v1 cri` = **ok**, `SystemdCgroup = true`, **NO Docker installed at all** |
| Verified | `kubeadm init --dry-run` **preflight passes** on control-1; all five report **"nothing was changed"** under `--check` |
| Resources | vCPU **64 of 48 threads (133%)**, RAM 85G of 187G, `vm-ephemeral` 865G used / 980G avail |
| Snapshot | `c01-nodes-ready` on all five (hot, guest-agent freeze — **no etcd exists yet**, so an offline snapshot is not needed until Stage 2) |

📄 **Deliverables built: three scripts in `education/k8s-cka-prep/scripts/`** — `1-provision-vms.sh`,
`2-personalize.sh`, `3-k8s-base.sh`, plus a `README.md`. ⚠️ **They replaced an earlier combined
`k8s-setup.sh`, which was DELETED rather than kept beside them** — two copies drift.
🙋 **Andrew's design call, and it was better than the AI's proposal.** One **self-contained** script rather than a wrapper around the lab's
`www/ubuntu/` sub-scripts, because **there is no script server at the firm** and a script with dependencies
is not portable. Hostname/sudo/Cockpit logic is therefore a **knowing COPY**, labelled in the header, with
an instruction not to turn it back into a caller. Lab conveniences are **opt-in** (`--sudo-nopasswd`,
`--cockpit`) so a bare run is safe at work.

⭐ **A plan assumption that measurement overturned: the template has NEITHER Docker NOR containerd**, so the
approved "add then subtract" was unnecessary. `containerd.io` is installed **alone** and configured for
Kubernetes from the outset, instead of installing Docker and undoing it. **Nothing to subtract if you never
add it** — and it avoids the residue a Docker removal leaves behind.

🔻 **Testing on ONE node first paid for itself immediately.** Against a `c00-virgin` snapshot the script's
**summary block was found to be lying**: it printed doubled values (because `systemctl is-active` PRINTS
`inactive` *and* exits non-zero, so the `|| echo absent` fallback fired too) and it reported
**`CRI enabled: yes` when containerd was not installed at all.** ⭐ **A report that shows green for a
component that does not exist is this project's signature failure**, and it would have been believed on
five nodes instead of one. Fixed to say `n/a — no containerd config yet`.
⚠️ **And the same mistake was then repeated in a throwaway verification command minutes later** — the
`cmd || echo fallback` shape is genuinely easy to write wrong.

📊 **PRE-DRILL BASELINE CAPTURED (the plan asks for this before anything is broken):**
**steal time `st = 0%` on `.201`, `.204` and Swarm node `.191`**, host 98% idle, load 0.51 of 48 threads.
⭐ **This is what licenses the 133% vCPU oversubscription** — steal is the guest saying *"I wanted CPU and
did not get it"*, and host CPU% cannot answer that question at all. ✅ **Andrew asked whether shutting the
Docker Swarm down would help performance: measured answer is NO.** It would return 6 vCPU / 12 GB to
relieve contention that is not occurring. ⛔ **Leave the Swarm running**; revisit only if steal goes
non-zero, and then it is the first lever because Jenkins is on hold anyway.
🔲 **Still owed: the etcd `wal_fsync_duration_seconds` baseline** — impossible until etcd exists, so it
belongs to Stage 2.

### Stage 1 — install and configure Kubernetes, piece by piece → **chapters 02–04**

**The goal is understanding what `kubeadm` does, not getting a green `kubectl get nodes` quickly.**

📖 **CHAPTER 02 TEACHING POINT — 🙋 Andrew spotted this and he is right that it is the good one:
A NODE HAS NO ROLL UNTIL ONE COMMAND GIVES IT ONE.**

✅ **Verified by measurement, Sep 16 2026, across all five:** `/etc/kubernetes/` contains only an empty
`manifests/` directory, no PKI, no `kubelet.conf`, no `admin.conf`, no `/var/lib/etcd`, kubelet
**enabled but inactive**, same three binaries. **A "control" node and a "worker" node are byte-for-byte
identical.**

🚨 **The hostnames `vm-k8s-cka-control-1` and `vm-k8s-cka-worker-2` are LABELS WE CHOSE. Nothing enforces
them.** Run `kubeadm init` on `vm-k8s-cka-worker-2` and it becomes a control plane, and the name is then a
lie that every future reader will believe. ⭐ **A hostname is documentation, not a constraint** — and that
is a real operational hazard, not a curiosity.

**The role comes from exactly one command:**

| Command | What the node becomes | What appears on disk that was not there before |
|---|---|---|
| `kubeadm init` | **first control plane** | static pods in `/etc/kubernetes/manifests/` (etcd, apiserver, controller-manager, scheduler) · the whole `pki/` tree · `admin.conf` · `/var/lib/etcd` |
| `kubeadm join --control-plane --certificate-key …` | **additional control plane** | the same, minus a new CA — it receives the existing one |
| `kubeadm join` | **worker** | `kubelet.conf` and bootstrap credentials. **No manifests. No PKI beyond the CA. No etcd.** |

⭐ **THE PART THAT PAYS OFF IN THE EXAM'S TROUBLESHOOTING DOMAIN (30% of the marks): the kubelet is
IDENTICAL on a control plane and a worker.** A control plane is simply a node whose kubelet *additionally*
runs four **static pods** — read straight off the local disk, **not** scheduled by the API server and not
managed by it. **That is why a broken API server is repaired by editing a file in
`/etc/kubernetes/manifests/` and waiting for the kubelet to notice**, and why `kubectl` cannot help you:
the thing you need to fix is the thing that serves `kubectl`. ⭐ **The control plane is bootstrapped by the
same mechanism that runs ordinary pods, one layer lower down.**

⚠️ **A smaller lesson from checking this: `kubeadm init --dry-run` WROTE TO DISK**, leaving
`/etc/kubernetes/tmp/` behind on control-1 and making it the one node that differed from the other four.
Removed. ⭐ **Same class as the earlier audio fault — the probe mutated the system.** A flag called
`--dry-run` still had a side effect, so "it only reads" is a claim to verify, not to assume.

🚨 **Hard sequencing rule, and it is NOT optional: kube-vip must be answering BEFORE `kubeadm init`.**
`--control-plane-endpoint` has to point at the VIP from the very first second, because the apiserver
certificate's SANs are generated then. **Initialise without it and cp-2 and cp-3 can never join** — the
fix is regenerating certificates or starting over. ⭐ **This is the one irreversible-ish decision in the
whole build, so it goes first and it goes in the chapter as a prerequisite, not a warning.**

1. **kube-vip** as a static pod, ARP/L2 mode, on the VIP.
2. **`kubeadm init` on control-1** with the VIP as the control-plane endpoint — then **stop and read what
   appeared**: `/etc/kubernetes/manifests/` static pods (etcd, apiserver, controller-manager,
   scheduler), the PKI tree, the kubeconfigs, the kubelet's own config, the join token.
   ⭐ **This inspection IS the chapter.** It is also the best available preparation for the exam's
   Troubleshooting domain, because you cannot debug a control plane you have never looked inside.
3. **Calico**, and observe that the nodes were `NotReady` until it existed and CoreDNS was `Pending` —
   ⭐ **explained as mechanism, not discovered as a surprise**: Kubernetes ships no pod network.
4. **Join control-2 by hand** (🙋 Andrew), **control-3 by script** (🤖 AI — repetition rule).
5. **Join both workers**, run a neutral workload, confirm scheduling.

✅ **SEQUENCING SETTLED Sep 16, 2026 — ALL THREE CONTROL PLANES JOIN BEFORE ANY WORKER.** This was the one
open ordering question, and Andrew's *by the book* directive answers it rather than taste: **upstream's HA
procedure sequences it exactly this way** — load balancer, `kubeadm init` with `--control-plane-endpoint`,
CNI, join remaining control planes, *then* workers. ⭐ **It is also right on the merits: etcd quorum is
established before any workload exists**, so the first thing the cluster does is not simultaneously
"form a quorum" and "schedule pods". ⛔ **Do not bring a worker up early "to check it works"** — that
mixes two variables in the one part where the control plane must be provably sound on its own.

🚨 **A `--upload-certs` TRAP that pairs with the 24 h token one, and it is shorter: the certificate key
`kubeadm init --upload-certs` produces EXPIRES AFTER 2 HOURS.** It is what control-2 and control-3 need in
order to join as control planes. If Stage 1 spans a break longer than that, **regenerate with
`kubeadm init phase upload-certs --upload-certs`** rather than debugging a confusing join failure.
⚠️ Given the *no rush* directive, this trap is now **more likely, not less** — a deliberate pace makes a
two-hour expiry easy to walk into.
6. **Prove the HA actually works:** `etcdctl` shows 3 members and a leader; power off a control plane and
   the API still answers *through the VIP*; the VIP demonstrably moved (ARP, not assumption).

📸 Snapshots: `c02-cp1-init`, `c03-ha-control-plane`, `c04-cluster-complete` — **all five nodes together
or not at all** (B5).
📄 **Deliverable: chapters 02–04.** ⭐ **Stage 1 ends when the cluster is built, tested and DOCUMENTED** —
Andrew's condition, and it is the gate into Stage 3.

### Stage 2 — sign off the cluster and snapshot it as the baseline → **completes chapter 04**

🙋 **Andrew's item 2:** *"we will agree the cluster is in 'standard virgin working state' in-line with what
we believe the CKA test environment will look like and snapshot everything."*

**This is a stage, not a checkbox** — it is the gate into exam work and the snapshot every later exercise
rolls back to, so it gets done properly once rather than assumed.

1. **Agree the state explicitly**, both of us, against a written list: five nodes `Ready`, three etcd
   members with a leader, VIP answering and demonstrably able to move, CoreDNS running, a neutral
   workload scheduling on both workers, the exam-matched toolset present on every node.
2. 📸 **Snapshot all five with the VMs SHUT DOWN.** ⭐ An offline snapshot is disk-consistent *by
   construction* rather than by fs-freeze, which matters far more here than it did for the Swarm because
   **etcd is a write-ahead-log database and this is the image we will restore dozens of times.** Phase 17
   took its accepted baseline (`q02`) offline for exactly this reason. Name: `c02-virgin-cluster`.
3. 🚨 **PROVE THE ROLLBACK BEFORE STAGE 3 OPENS — do not assume it.** Restore all five from
   `c02-virgin-cluster`, bring them up, and re-run the step-1 checklist. ⭐ **Ten exercises are built on
   this snapshot being restorable; the one you never test is the one that fails.** Phase 16's whole drill
   programme rested on rollback being instant, and this is a five-node cluster with quorum rather than a
   single VM.
4. 📄 **Write the baseline down** — versions, addresses, what "healthy" prints — because a later
   "something is wrong" is only meaningful against a recorded normal.

⚠️ **HONEST LIMIT on "in line with the CKA test environment", so it is not over-claimed:** we can match
the **node toolset**, the **SSH-from-a-toolless-`base` workflow**, **Kubernetes v1.35**, containerd, and
the fact that it is kubeadm-built. ⛔ **We cannot match the exam's cluster COUNT or topology, and we do
not actually know them.** So this is *"a standard kubeadm cluster with exam-matched tooling"*, not *"the
exam environment"* — a distinction that matters the first time an exercise behaves unexpectedly.

🚨 **A time bomb to expect rather than debug, and it is the k8s analogue of a Phase 16 finding.** Swarm CA
certs expire three months out, so restoring a frozen snapshot there produced a cluster whose certs had
expired *while frozen* — presenting as a network fault when it was not. **kubeadm has the same shape:
cluster certs last a year, kubelet client certs rotate far more often.** If Stage 3 runs over months
against one snapshot, **expect certificate expiry to appear as mysterious TLS or authentication failures
after a rollback**, and recognise it instead of chasing it. `kubeadm certs check-expiration` is the
instrument.

### 🆕 A HIGH-VALUE TARGET THAT ONLY BECAME POSSIBLE TONIGHT

⭐ **The Swarm track's chapter 8 — the Swarm↔Kubernetes crib sheet — contains SEVEN rows marked
`recited`**, meaning *neither lab had tested them*. Examples: *"neither lab tested drain against a
quorum workload"*, *"neither was exercised in either lab"*.

✅ **A real multi-node `kubeadm` cluster now exists, so those rows can be converted from RECITED to
VERIFIED.** ⭐ **This is the single best-value piece of work available**, for three reasons: it is
bounded (seven specific claims), it upgrades an existing artefact rather than starting a new one, and
**a Swarm-to-Kubernetes comparison backed by two real clusters is worth far more than either track
alone.** ⛔ It also fixes the one thing chapter 8 apologises for.

📌 **Sequence it after Stage 2** — the claims need a working HA cluster to test against, and several
involve draining nodes and losing quorum, which is Stage 3 drill territory anyway.
⚠️ **Keep the provenance marks honest when doing it:** a row moves to verified **only** when it was
actually exercised here, and the S / K / 🤖 marking convention exists precisely so nothing recited can
later be quoted as experience.

### Stage 3 — CKA administration, one task type per chapter → **chapters 05+**

**Only now does exam material get opened.** Each chapter takes **one class of administrative task**,
mapped to a curriculum domain, drilled on the cluster Stages 0 and 1 built.

⭐ **This is where deliberate breakage returns — as EXERCISES, not traps.** Troubleshooting is **30% of
the exam** and cannot be learned on a healthy cluster. The difference matters: **a trap is hidden from
the learner and fires once; an exercise is chosen, named, and can be drilled ten times** because the
snapshots make it cheap to restore. **For exam preparation the exercise is strictly better.**

Coverage is driven by `education/k8s-cka-prep/curriculum.md`, weighted by the real exam weights —
**Troubleshooting 30%, Cluster Architecture 25%, Services & Networking 20%, Workloads & Scheduling 15%,
Storage 10%.** ⚠️ **The gaps identified in 🅐 A8 (Storage, Helm/Kustomize, CRDs/operators, Gateway API,
HPA, Ingress) all live in this stage**, which is what resolves A8: they were never missing from the
*build*, they belong to the *exam* half — a distinction the original single-track plan could not make.

✅ **EXERCISE SOURCING — decided by Andrew, Sep 16, 2026: build the ~10 exercises from the CNCF
curriculum plus reputable published practice material, and keep the Killer.sh simulator for rehearsal.**
🔻 **REVISED at Andrew's push-back, Sep 16, 2026 — the earlier wording was too broad and conflated two
different things.** He is right that reviewing what circulates publicly is legitimate and useful:

| Material | Use it? |
|---|---|
| **Official CNCF curriculum** and the competency list | ✅ The spine of Stage 3 — it is what the questions are generated *from* |
| **Community reports on task TYPES and STRUCTURE** — Reddit, blogs, courses: *"expect a kubeadm upgrade"*, *"multiple clusters"*, *"tasks chain 2–3 steps"* | ✅ **Yes, deliberately.** This is intelligence about the exam's *shape*, published everywhere, and it is how we check our exercise coverage. **It is also how Q3 gets answered** |
| **Commercial practice sets** — Killer.sh, KodeKloud, published study guides | ✅ Sanctioned and written for this purpose |
| **Verbatim recalled tasks with solutions** — *"here are the 17 questions I got"* | ⚠️ Read if he wants; ⛔ **but never COMMITTED to this repo** — see below |

⭐ **Andrew's argument that decides it: tasks are randomised and rotated between sittings, so a dump is
nearly worthless for memorisation while a report of task TYPES is valuable for coverage.** That points at
using this material as a **gap analysis**, not an answer key: if the community consistently reports a
Gateway API or etcd-restore task and our exercises have none, **that is a defect in our plan** and we want
to know before the exam, not after.

🚨 **THE ONE HARD LINE, and it is about THIS REPO rather than about principle: no verbatim recalled exam
content gets committed here.** `origin` is **public GitHub under Andrew's own name**, and
`push_github.sh` screens for **secrets**, not for content that is merely unwise to publish — exactly the
gap that made `education/fin_tech_stack.txt` need de-identifying, where the gates would never have caught
an employer name. ✅ **Safe pattern: read it, extract the TASK TYPE, write our own exercise from the
curriculum, cite the type not the text.**

🔲 **CONCRETE NEXT ACTION when Stage 3 approaches (folds Q3 into it):** research the reported task
types and structure, then build a **two-column coverage matrix** — *reported task type* against *our
exercise* — weighted by the real domain weights. **The gaps in that matrix are the exercise backlog.**

🔄 **Rollback policy, so ten exercises do not cost ten cluster restores:** ⛔ **do NOT roll back all five
VMs for every exercise.** Most workload tasks — write a Deployment, fix a Service, add a NetworkPolicy —
are undone with `kubectl delete`. **Reserve the full restore for exercises that genuinely break the
cluster:** etcd, control-plane components, certificates, node failure. ⭐ Worth scripting a
`rollback_cluster.sh` on the PVE host and **measuring how long it takes**, because the cost of a restore
is what decides how boldly you are willing to break things.

⏱️ **Practise against the clock here, not earlier** — 15–20 tasks in 120 minutes is roughly 6–8 minutes
each, and speed is a separate skill from correctness.

🔲 **DEFERRED at Andrew's instruction — NOT NOW:** whether exam tasks chain 2–3 steps of troubleshooting
and administration together. He has heard they do. **This is Q3 in `education/k8s-cka-prep/README.md` and
gets researched properly before the exercises are written**, because it changes their shape: ten
single-step exercises train a different skill from ten three-step ones.

---

## 7. 🅑 Hard rules

- **B1 — `.186` is frozen and out of scope.** See §2.
- **B2 — `vm-ephemeral` only, and nothing irreplaceable ever lives on this cluster.** No-redundancy stripe.
- **B3 — Fix containerd ON THE NODES, and do NOT "fix" the shared `setup_docker.sh`.** 🚨 Patching the
  shared script looks like the fleet-wide fix this lab keeps rewarding, and here it is **wrong**: every
  other host in this lab is a *Docker* host, and Docker's containerd disables the CRI plugin on purpose.
  Enabling it fleet-wide would change eleven working hosts to suit five new ones. ⭐ **The general point,
  and it is chapter material: one build standard cannot serve both a Docker host and a Kubernetes node** —
  the lab could pretend otherwise only while it had no kubeadm nodes.
- **B4 — Never point this cluster at `production/*` in the registry.** Same reasoning as Phase 17's
  B10: `.180` and `.184` pull `production/capricorn/<svc>:latest`, so a push there ships to PROD.
- **B5 — Snapshot all five nodes together or not at all.** Distributed state with etcd quorum; rolling
  one node back to where the others have moved on is an unplanned debugging session (`METHOD.md`).
- **B6 — Do not deploy Capricorn to this cluster.** Application layer, owned by its own project. A
  neutral workload is enough and keeps the phase honest about scope.

## 8. 🚫 NO PLANTED TRAPS — a deliberate, recorded deviation from `METHOD.md`

🙋 **Andrew, Sep 16, 2026:** *"Let's not 'set any traps' while we are building. Just build it as close as
possible to the lab environment. The CKA exam is SO HARD we need to only focus on what they test which is
administering an already built very basic setup and go from there."*

⛔ **The eight traps T1–T8 this plan carried are WITHDRAWN.** Nothing is planted, nothing is left broken
on purpose during Stages 0 and 1, and no failure is concealed from the learner.

⚠️ **This is a deviation from `METHOD.md`, which makes planted traps a stage-1 practice and marks them
do-not-fix.** Recorded here rather than done silently, per that file's own rule 8 — *the method is a
floor, not a ceiling; deviate deliberately, then fold back what works.* 🔲 **If this shape proves out,
`METHOD.md` gains a note that a certification-driven track inverts the trap practice.**

**Why the reasoning holds**, because it is not simply "traps are inconvenient":
- ⭐ **The deliverable changed.** Stage 0 and 1 chapters are **procedures Andrew repeats at work**. A
  procedure's job is to show the path that *works* — which is already `CONVENTIONS.md` decision **A12**
  (*a chapter is the build procedure*). Traps serve a different goal: earning a diagnosis.
- ⭐ **The exam does not test building.** 🟢 It hands you built clusters and asks for administration. Lab
  failure modes invented by us are **not** what is tested, and a hard exam plus a limited clock is a bad
  place to spend attention on lab-specific trivia.
- ⭐ **Breakage is not dropped, it MOVES to Stage 3 as chosen exercises** — see §6. Troubleshooting is
  **30% of the marks**, so deliberate faults are mandatory *eventually*; they just belong to exam prep
  rather than to the build.

🚨 **Two of the withdrawn traps could never actually be "not planted", and that has to be handled rather
than declared away:**

| Was | Now |
|---|---|
| **T1** — containerd's CRI plugin disabled, so `kubeadm init` hangs on a kubelet that cannot reach a runtime | ✅ **PRE-EMPTED in Stage 0 as a documented step.** It is not a trap we set — it is what `setup_docker.sh` leaves behind on **every** lab host (✅ verified on `.191`: `disabled_plugins = ["cri"]`). So the only choices were *fix it deliberately* or *be ambushed*. **Fix it, and explain it in the chapter**, because anyone repeating this at work on a Docker-built host meets it too |
| **T2** — cgroup driver mismatch (containerd `cgroupfs` vs kubelet `systemd`), failing late and intermittently | ✅ **PRE-EMPTED in Stage 0.** ⚠️ Worth stating in the chapter *because of how it fails*: not at install time but later and under load, which makes it nearly undiagnosable after the fact |
| **T3** — `kubeadm init` without `--control-plane-endpoint`, making HA impossible later | ✅ **Now a hard PREREQUISITE in Stage 1**, stated before step 1 rather than discovered in step 4 |
| **T4** — the 24 h join-token expiry | ✅ Now a **documented note**: if Stage 1 spans two sessions, generate a fresh token (`kubeadm token create`) rather than debugging a confusing join failure |
| **T5** — nodes `NotReady`, CoreDNS `Pending` until a CNI exists | ✅ Now **explained as mechanism** in Stage 1 step 3 |
| **T6/T7/T8** — default-deny NetworkPolicy killing DNS · quorum loss failing reads · the cluster down after a host reboot | ✅ **Moved into Stage 3 as named exercises.** All three are genuinely on-syllabus and all three are better drilled repeatedly than sprung once |

⭐ **What we give up, stated honestly:** the experience of diagnosing an unexpected failure *cold*, which
is the thing traps are uniquely good at. **Stage 3 recovers most of it** — the faults are still real and
still have to be diagnosed — but he will know a fault is coming. **That is the trade, and it is the right
one for a dated certification.**

## 9. 🅐 Open items — need Andrew

| # | Question | Status |
|---|---|---|
| **A1** | Addressing, and what `.202` is | ✅ **CLOSED Sep 16** — DHCP moved to `.221–.250`; `.200` = Apple (Mac mini), `.202` = Denon/Marantz receiver. Cluster takes `.187–.190` + `.194`, VIP `.196`. See §5 |
| **A2** | Node naming | ✅ **CLOSED Sep 16 — Andrew's names: `vm-k8s-cka-control-1/2/3` and `vm-k8s-cka-worker-1/2`.** Restores the lab's `vm-` prefix, which the Swarm's `docker-swarm-N` had dropped |
| **A3** | Track folder | ✅ **CLOSED Sep 16 — `education/k8s-cka-prep/`.** 🔻 Andrew's call: the research folder **moves into `education/` and becomes the track**, rather than prep living apart from chapters. ⚠️ It tab-completes alongside track 1's `k8s-k3s-redpanda/`, so **always write the full track name in a command** — `build_docx.py` takes the track as its first argument and a wrong one silently builds the wrong book |
| **A4** | **CNI choice** | ✅ **DECIDED Sep 16 — Calico.** Kubernetes ships with **no** pod network at all (that is trap T5), so one must be installed. Calico is the conventional `kubeadm` pairing, uses ordinary Linux routing, and **enforces `NetworkPolicy`, which is on the CKA syllabus** and is what makes T6 possible. Cilium is more modern (eBPF, better observability) but is a second large subject on top of the exam; flannel — what k3s gave track 1 — **cannot enforce a policy at all**, so the lab has no policy experience yet |
| **A5** | Stop the Swarm VMs to reclaim CPU? | ✅ **NOT NEEDED — measured.** Host CPU over the last year: mean **1.11%**, p95 **2.74%**, p99 **4.06%**. Leave the Swarm running. See §4 |
| **A6** | Kubernetes version | 🔻 **REVISED Sep 16 after the exam research — build the current `v1.35` patch, upgrade to `v1.36` in Part 6.** The earlier answer (build 1.36.4 → 1.37.0) was reasoned only from upstream and is **wrong for this phase's purpose**: 🟢 **the CKA environment runs v1.35**, roughly two minors behind upstream's v1.37.0. Practising daily on a version ahead of the exam trades away the whole point. The revised pair is strictly better — **daily practice matches the exam**, and the upgrade drill now mirrors the real competency *"manage the lifecycle of Kubernetes clusters"* by upgrading **from** the version under test. ⚠️ The exam tracks the newest minor within ~4–8 weeks, so **re-check before booking** (`education/k8s-cka-prep/exam-environment.md`) |
| **A8** | ✅ **RESOLVED Sep 16 by the three-stage restructure — this finding is what forced it.** 🚨 **The curriculum is WIDER than the original plan.** Research on Sep 16 mapped the plan against the published competencies and found real gaps: **Storage (10% of the exam — StorageClasses, dynamic provisioning, PV/PVC) is not covered AT ALL**, nor are **Helm and Kustomize**, **CRDs and operators**, **Gateway API**, **workload autoscaling (HPA)** or **Ingress** — and four of those were **added by the Feb 2025 update**. **Troubleshooting is 30% of the marks** and is covered only incidentally by the drills | ✅ **All of it now lives in Stage 3**, one task type per chapter, weighted by the real exam weights. ⭐ **The gaps were never missing from the BUILD — they belong to the EXAM half**, and a single blended track had nowhere to put them. Full mapping in `education/k8s-cka-prep/curriculum.md` |
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
deliberately deleted first · an upgrade from **v1.35 to v1.36** that leaves every node one minor
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
🔻 **TROUBLESHOOTING POSTURE — settled by Andrew, Sep 16, 2026, and it DIFFERS BY STAGE:**

| Stage | When something breaks |
|---|---|
| **0, 1, 2** (build) | ✅ **Collaborate immediately.** Both of us dig in. The deliverable is a working procedure Andrew can repeat at the firm, so time spent stuck produces nothing a reader needs |
| **3** (exam drilling) | 🚨 **The AI stays quiet until asked.** Andrew diagnoses first |

⭐ **The reason the split is right rather than merely convenient:** `METHOD.md`'s silence rule exists to
protect a *learning* outcome, and in Stage 3 the thing being learned **is diagnosis under time pressure** —
🟢 the CKA is entirely performance-based and Troubleshooting is 30% of the marks. Being handed the answer
teaches the fact and skips the skill. In Stages 0–2 the outcome being protected is a **document**, and
there the fastest correct path is the best one. **Same rule, applied where it pays.**
