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
- ✅ **`crictl` ADDED Sep 17, 2026 (Andrew's call)** — `cri-tools` 1.35.0 from the `pkgs.k8s.io/v1.35`
  repo, so it version-matches the cluster. ⚠️ **Its presence on the exam hosts is UNVERIFIED** (🟢 the
  official list names only `kubectl`/`yq`/`curl`/`wget`/`man`; 🟡 one blog claims `crictl`), and the
  decision deliberately **does not depend on the answer**: with Docker absent there is otherwise **no
  way to inspect a container on a node at all**, and 🟢 kubernetes.io's own troubleshooting pages — the
  only docs allowed in the exam — instruct you to use it. ⭐ **It passes the `k9s` test in the right
  direction:** it does not change how a *Kubernetes* task is performed, it is the only window into the
  layer **below** Kubernetes. 🚨 **`/etc/crictl.yaml` is REQUIRED, not cosmetic** — current `crictl`
  has no default-endpoint fallback, so without it the tool errors instead of finding containerd.
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
`kubeadm init`, no `kubeadm join`, no CNI, and **the kubelet cannot start until a cluster exists**, which is
normal and not a fault. 🔻 **CORRECTED Sep 17, 2026 — this said "the kubelet is `inactive` on
purpose." That was an ARTEFACT, not the steady state.** The kubeadm package **enables** the unit but
does not start it, so `inactive` was only ever true of a node that had not rebooted since install.
✅ **Measured after the Sep 17 reboot on all five: `ActiveState=activating`, `SubState=auto-restart`,
~17 restarts in three minutes**, failing on `open /var/lib/kubelet/config.yaml: no such file or
directory` — the file that `kubeadm init`/`join` writes. ⭐ **The true steady state of a
prepared-but-un-initialised node is a kubelet in a ten-second restart loop**, and that missing file
**is** the absence of a role. ⭐ *"The tools are installed"* and *"the
cluster is configured"* are different states and Stage 1 is the second one.

| | |
|---|---|
| Nodes | **5/5 running and IDENTICAL** — `vm-k8s-cka-control-1/2/3` at `.201`–`.203`, `vm-k8s-cka-worker-1/2` at `.204`–`.205`, 2 vCPU / 4 GB / 40 GB each, all **`onboot 0`** per the lab autostart policy |
| Kubernetes | **v1.35.8** (`kubeadm`/`kubelet`/`kubectl`), **apt-held** on every node. ⚠️ `kubeadm` itself reported *"remote version is much newer: v1.37.0; falling back to stable-1.35"* — independent confirmation the two-minor gap to the exam is deliberate |
| Runtime | containerd **active**, `io.containerd.grpc.v1 cri` = **ok**, `SystemdCgroup = true`, **NO Docker installed at all** |
| Verified | `kubeadm init --dry-run` **preflight passes** on control-1; all five report **"nothing was changed"** under `--check` |
| Resources | vCPU **64 of 48 threads (133%)**, RAM 85G of 187G, `vm-ephemeral` 865G used / 980G avail |
| Snapshot | 🔻 **CLAIMED HERE ON SEP 16 AND NEVER TAKEN — found Sep 17, 2026.** `qm listsnapshot` returned only `current` on all five, no `vm-ephemeral/vm-20[1-5]-disk-0@*` existed, and the PVE task log held exactly one snapshot on 201 — created 18:16:20, deleted 18:19:03 (the `c00-virgin` single-node test). ✅ **`c01-nodes-ready` now EXISTS on all five, taken 09:24 and retaken 09:38 on Sep 17 after the kernel reboot** (hot, guest-agent freeze — **no etcd exists yet**, so offline is not needed until Stage 2), verified at BOTH layers: `qm listsnapshot` **and** a matching `@c01-nodes-ready` on each zvol. 🚨 **This row asserted a rollback point that did not exist, one step before the build's only near-irreversible command.** ⭐ **Institutionalise the check that caught it: a snapshot is confirmed by asking the STORAGE.** `qm listsnapshot` is PVE's own bookkeeping; the zvol is the independent witness |

🔻 **Chapter 01's verified-facts header said `containerd 2.3.3`. It was never that.** `apt` history
shows `containerd.io 2.3.5-1~ubuntu.24.04~noble` installed **once**, at 22:17:39 on Sep 16, and
`ctr version` agrees. Corrected Sep 17. ⭐ **A version in a "verified facts" header that was never
measured is the cheapest false green to produce and the hardest to see — it is one character from
right.**

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
`manifests/` directory, no PKI, no `kubelet.conf`, no `admin.conf`, no `/var/lib/etcd`, same three
binaries. **A "control" node and a "worker" node are byte-for-byte
identical.** 🔻 **The kubelet reads `enabled` + `activating (auto-restart)`, NOT `inactive`** — see
the Stage 0 correction above. ⭐ **This strengthens the teaching point rather than weakening it:** the
node is not idle waiting for a role, it is **actively failing for want of one**, and
`/var/lib/kubelet/config.yaml` is the specific file whose absence says so.

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

🚨 **THE IRREVERSIBLE RULE: `--control-plane-endpoint` MUST point at the VIP on the very first
`kubeadm init`.** The apiserver certificate's SANs are generated at that moment. **Initialise without it
and cp-2 and cp-3 can never join** — the fix is regenerating certificates or starting over.

🔻 **CORRECTED Sep 17, 2026 — THIS SAID "the one irreversible-ish decision in the whole build." THERE
ARE THREE, and the other two were specified NOWHERE in this plan.** Found one command before `init`
was typed, by grepping the whole track for `pod-network-cidr` and getting **no matches at all**.

| Fixed at `init` | Our value | Why it cannot be changed afterwards |
|---|---|---|
| `--control-plane-endpoint` | **`192.168.1.206:6443`** | Written into the apiserver certificate's SANs. Without it cp-2/cp-3 can never join |
| `--pod-network-cidr` | **`10.244.0.0/16`** | Written into the cluster configuration and the controller-manager's `--cluster-cidr`. Changing it is re-initialise territory, not a config edit |
| `--service-cidr` | **`10.96.0.0/12`** (default, knowingly accepted) | Determines the API server's own ClusterIP. Same story |

🚨 **AND THE POD CIDR IS NOT A FREE CHOICE HERE — CALICO'S DEFAULT COLLIDES WITH THIS LAB'S OWN LAN.**
⛔ **Calico's default IP pool is `192.168.0.0/16`, which CONTAINS `192.168.1.0/24`.** Calico carves the
pool into `/26` blocks per node, so it can hand a pod a real address on our wire — potentially a block
containing `.201`–`.205` themselves, the Proxmox host at `.150`, or the router. ⚠️ **The symptoms would
be intermittent and would look like a CNI bug or a switch fault:** some pods unreachable, some LAN
hosts unreachable from pods, duplicate-address complaints — and **nothing would point at a CIDR chosen
days earlier.** ✅ **`10.244.0.0/16` decided Sep 17 (🙋 Andrew):** clear of the LAN, clear of the
service CIDR `10.96.0.0/12`, clear of Docker's `172.17.0.0/16`, and clear of the Swarm's `10.0.0.0/24`
overlay.

🚨 **TWO PLACES MUST AGREE, and this is the step-3 check.** Calico's manifest ships
`CALICO_IPV4POOL_CIDR` **commented out**, and when it is unset Calico uses `192.168.0.0/16`
**regardless of what was passed to `kubeadm`**. ⛔ **So kubeadm and Calico can disagree while the
cluster comes up looking healthy** — nodes `Ready`, pods running, and pod addresses the control plane
does not expect. **Set it explicitly and verify the allocated block, do not trust the install.**

⭐ **THIS IS THE SECOND APPEARANCE OF ONE PATTERN AND THE CROSS-PHASE LESSON IS THE VALUABLE PART:**
Phase 16 recorded that Docker's `ingress` overlay takes `10.0.0.0/24` out of an **invisible
`10.0.0.0/8` default**, flagged as *"a silent collision risk on any corporate `10.x` network"*.
🚨 **Same shape, different tool: a container platform ships a default address range chosen without
knowing what network you are on.** ⭐ **And it inverts at work:** this lab is `192.168.x` so Calico's
default is the hazard, while a firm on `10.x` space would find **Kubernetes' own default service CIDR
`10.96.0.0/12`** is the one to check first. **The rule is not "avoid 192.168" — it is "a default CIDR
is a guess about someone else's network."**

🔻 **CORRECTED Sep 16, 2026 — this section previously said "kube-vip must be ANSWERING before
`kubeadm init`". THAT CANNOT HAPPEN, and the reason is worth understanding because it is the same class
of mistake as a false green.** kube-vip is deployed here as a **static pod**, and **static pods are
started by the kubelet** — but the kubelet on all five **cannot start at all**, and on control-1
**`kubeadm init` is the thing that makes it able to.** So:

🔻 **SHARPENED Sep 17, 2026 — this said the kubelet was "deliberately inactive", which was measured
to be an artefact of never having rebooted.** ⭐ **The corrected mechanism makes the conclusion
STRONGER: the kubelet exits before it ever reads `/etc/kubernetes/manifests/`**, because it dies on
the missing `/var/lib/kubelet/config.yaml` first. **A static pod placed there cannot run — not
because nothing is reading the manifests, but because the process that would read them never gets
that far.**

⭐ **The manifest goes in place BEFORE init; the VIP comes up DURING init.** Ordering is
*manifest-then-init*, not *VIP-then-init*. ⛔ **Do not sit waiting for `.206` to ping before running
`kubeadm init` — it never will, and the build will look stuck when nothing is wrong.**

⚠️ **TWO CONSEQUENCES THAT LOOK LIKE FAULTS AND ARE NOT** — flagged so neither costs an hour:
1. **kube-vip will crash-loop briefly during init.** Its manifest references a kubeconfig under
   `/etc/kubernetes/` that **`kubeadm init` has not created yet**, so the pod restarts until it appears.
   Transient by design.
2. 🚨 **Kubernetes ≥1.29 split `admin.conf` from `super-admin.conf`**, and `admin.conf` no longer
   carries cluster-admin. **We are building v1.35, so this applies.** 🔻 **AND THE CONSEQUENCE WAS
   UNDERSTATED HERE — corrected Sep 17, 2026.** This said kube-vip "fails on permissions in a way
   that reads like a network problem." **What actually happens is worse: the static pod crashes, the
   API endpoint never comes up, and `kubeadm init` TIMES OUT after ~4 minutes leaving an unusable
   cluster** (kube-vip issue #907). ⚠️ **Its author recorded the detail that makes it maddening: it
   works fine WITHOUT `--control-plane-endpoint`** — the one flag we cannot drop.

✅ **VERIFIED AGAINST UPSTREAM DOCUMENTATION, Sep 17, 2026 — the 🔲 flag this block used to carry is
CLEARED.** Sources read: kube-vip's own *Static Pods* page (`kube-vip.io/docs/installation/static/`),
kube-vip issues **#684**, **#907**, **#938**, and kubeadm issue **#3274**. ⭐ **The ordering was
RIGHT:** kube-vip's documented eight-step sequence is manifest → `kubeadm init
--control-plane-endpoint` → the kubelet parses every manifest → **kube-vip starts and advertises the
VIP during init** → init completes. 🟢 So *manifest-then-init* is now upstream-documented rather than
reasoned, and ⛔ **do not wait for `.206` to answer first** stands confirmed.
⭐ **Worth noting for provenance discipline: the correction that was flagged as possibly-wrong turned
out to be right, and the sentence NEXT TO IT — the one nobody doubted — was the one that was wrong.**

🚨 **THE FIX IS ASYMMETRIC, WHICH IS WHY IT IS EASY TO GET BACKWARDS. On control-1 ONLY, before
`kubeadm init`, change the manifest's `hostPath` to `super-admin.conf` and LEAVE the `mountPath`
alone:**
```yaml
volumeMounts:
- mountPath: /etc/kubernetes/admin.conf      # unchanged — the container still sees admin.conf
  name: kubeconfig
volumes:
- hostPath:
    path: /etc/kubernetes/super-admin.conf   # was admin.conf
    name: kubeconfig
```
Then **revert it to `admin.conf` once init succeeds** (this restarts the pod; the issue thread warns
the restart can be flaky). 🚨 **`super-admin.conf` is created ONLY on the first control plane**, so
**control-2 and control-3 take the manifest exactly as generated** — reverse it there and the joins
fail instead of the init. ✅ **kubeadm issue #3274 records this workaround verified on a three-node
v1.35 cluster — our exact version.**

⚠️ **FOUR GOTCHAS FOUND IN THE SAME READ, each of which would have cost time AT the step:**
1. 🚨 **The documented version-detection one-liner needs `jq`, which we deliberately do not have.**
   `curl … | jq -r ".[0].name"` is step one of the official procedure. ⭐ **The `jq`/`yq` decision
   bites at the literal first command of Stage 1** — which is a better argument for that decision
   than the one we wrote down. Two answers, and the first is preferable because we want a pinned
   version anyway: **set `KVVERSION` by hand**, or use the tool we do have —
   `curl -sL https://api.github.com/repos/kube-vip/kube-vip/releases | yq -p json '.[0].tag_name'`.
2. 🚨 **The interface is `eth0`** — ✅ measured on `.201`/`.202`/`.203`, Sep 17. **Every kube-vip
   example says `ens160`/`ens192` because they assume VMware; Proxmox cloud-init images give
   `eth0`.** ⚠️ **A wrong `--interface` means the VIP binds nowhere and nothing says so.**
3. ⚠️ **The `hostAliases` block mapping `kubernetes` → `127.0.0.1` is load-bearing** — early v1.29
   and v1.30 patches silently ignored it in static pods (issue #938), which is why the community
   insists on a recent patch. **Non-issue on 1.35.8, but do not tidy the block away.**
4. ⭐ **`ctr image pull` puts the image in containerd's `default` namespace; the kubelet uses
   `k8s.io`.** So the image pulled to GENERATE the manifest **will not appear in `crictl images`**
   and the kubelet pulls it again. **Two image stores disagreeing — except this time it is
   containerd disagreeing with itself.** 📖 Chapter 02 demonstration, free now that `crictl` exists.

✅ **VERSION DECIDED Sep 17 — kube-vip `v1.2.3` (Aug 10, 2026), NOT the current `v1.2.4`**, which was
published Sep 16 — the day before we would install it. 🙋 Andrew's call, and it is the same reasoning
that picked Kubernetes v1.35 over the newest: **a release with no community exposure means a
crash-loop has two candidate causes — our mistake, or a regression — during the one step that cannot
be half-done.** ⭐ **Deliberate, not newest.**

✅ **FLAGS DECIDED Sep 17 — `--controlplane --arp --leaderElection`, and NOT `--services`**, which
the docs' example includes. 🙋 Andrew's call after the trade was laid out. **Three reasons, and the
first is the one that decides it:** `--services` **does not make `LoadBalancer` services work on its
own** — nothing assigns them an IP without the separate `kube-vip-cloud-provider` deployment and a
ConfigMap naming a range, so the flag turns on half a feature. It also gives kube-vip a **second
responsibility during the bootstrap**, breaking one-instrument-per-question exactly where the
`super-admin.conf` trap lives. And a service range needs addresses we have not allocated — the DHCP
pool owns `.221–.250` and `.207–.220` must be swept first. ⭐ **It is fully additive later:**
`svc_enable` on the static pod, the cloud provider, a ConfigMap. No re-init, no rebuild.

1. **kube-vip manifest into `/etc/kubernetes/manifests/`** — static pod, ARP/L2 mode, on the VIP,
   generated by running the kube-vip image itself (`ctr image pull` **then** `ctr run --rm
   --net-host`; ⚠️ `ctr` does not auto-pull and the older documented alias fails on a fresh node).
   `kube-vip manifest pod --interface eth0 --address 192.168.1.206 --controlplane --arp
   --leaderElection`. **Then edit the `hostPath` to `super-admin.conf` — control-1 only.**
   **It will not be running yet. That is correct.**
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

### ✅ Stage 1 — STEPS 1–5 COMPLETE, Sep 17, 2026 (results)

🙋 **Andrew drove the manifest, `kubeadm init`, Calico and the control-2 and worker-1 joins by hand.**
🤖 **The AI scripted control-3 and worker-2** (`METHOD.md` repetition rule) and did all verification.

| | |
|---|---|
| Cluster | **5/5 `Ready`** — `vm-k8s-cka-control-1/2/3` + `vm-k8s-cka-worker-1/2`, all **v1.35.8** |
| Control plane | 3 × stacked etcd, **3 members, one leader (control-1), raft term 2** |
| VIP | **`192.168.1.206/32` up and held by exactly ONE node.** `kubectl` answers *through* it |
| CNI | **Calico v3.32.2 via the Tigera operator**, `ipipMode: Never` + `vxlanMode: CrossSubnet` → **no encapsulation between nodes on one subnet** |
| Pod network | IPPool **`10.244.0.0/16`**, `blockSize: 26`, one block per node |
| Workers | `ROLES` reads **`<none>`** — ⭐ **Kubernetes has no worker role; a worker is a node WITHOUT the control-plane label.** Same lesson as the hostnames, one layer up |
| Neutral workload | 4 × `pause` scheduled, **all on the workers** (control planes are `NoSchedule`), each pod inside **its own host's /26**. Deleted again so Stage 2 snapshots a clean cluster |
| Service network | `curl -sk https://10.96.0.1:443/livez` → `ok` from a node. ⭐ **A ClusterIP exists only as kube-proxy rules — that address is on no interface anywhere** |

🔻 **CORRECTION — kube-vip did NOT crash-loop, and this plan predicted it would.** Measured `ATTEMPT 0`,
zero restarts. **Why:** kubeadm writes the kubeconfigs — `super-admin.conf` included — in a phase that
runs **before** it starts the kubelet, so the file our manifest pointed at already existed by the time
the kubelet read `/etc/kubernetes/manifests/`. ⭐ **The crash-loop was a symptom of the BROKEN
configuration (pointing at `admin.conf`, which exists but lacks permission), and applying the fix
beforehand removed the symptom entirely rather than shortening it.** ⚠️ **We inherited an expectation
from the failure mode we had already prevented** — worth remembering, because a predicted symptom that
does not appear reads like something went wrong.

🚨 **CORRECTION OF A CORRECTION — the Calico CIDR hazard IS real, and the AI talked itself out of it
mid-decision.** The plan warned that Calico defaults to `192.168.0.0/16` regardless of kubeadm. On
reading the docs the AI retracted that, because Calico's page says *"with kubeadm, no changes are
required — Calico will automatically detect the CIDR."* ⛔ **That note sits on the MANIFEST tabs.** The
**operator's** `custom-resources.yaml` **hard-codes `cidr: 192.168.0.0/16` in the `Installation` CR** —
no detection at all. ✅ **We edited it to `10.244.0.0/16` and verified the resulting IPPool.**
⭐ **The lesson is about documentation, not Calico: guidance on one tab of a tabbed page reads as
general advice**, and the retraction happened *before* the install path was chosen — so a true warning
was converted into a false reassurance by getting ahead of the decision. ⭐ **Provenance includes WHICH
TAB.**

🚨 **`node.spec.podCIDR` IS INERT HERE, and reading it will mislead you.** Measured on control-1:
kubeadm's controller-manager allocated **`10.244.0.0/24`**, while the actual CoreDNS pods hold
**`10.244.48.66/67`** out of Calico's block **`10.244.48.64/26`**. ⭐ **Two allocators with different
block sizes, and Calico's IPAM is the one that decides a pod's address.** ⚠️ **Anyone triaging a routing
problem by reading `node.spec.podCIDR` is reasoning about a range no pod occupies.**
⭐ **And Calico picks blocks PSEUDO-RANDOMLY, not sequentially** (`.48.64`, `.55.192`, `.177.0`,
`.58.192`, `.81.192`) — to avoid two nodes racing for the same block. **"Node 2 has the second /26" is a
reasonable guess and wrong.**

🚨 **EDITING A STATIC POD MANIFEST DELETES AND RECREATES THE POD — SO `RESTARTS 0` DOES NOT MEAN
"NOTHING HAPPENED".** Measured after reverting the kube-vip kubeconfig: new pod UID, new
`creationTimestamp` (15:49 against the apiserver's 15:45), **and a fresh restart counter reading 0.**
⭐ **The instrument that reveals a manifest edit is `creationTimestamp` or the UID, never `RESTARTS`.**
⚠️ Same family as Phase 16's `docker service ps` finding — **the obvious counter answers a narrower
question than it appears to.**

⚠️ **A TWO-MEMBER etcd CLUSTER IS THE LEAST AVAILABLE CONFIGURATION THERE IS**, and the build passes
through it between the control-2 and control-3 joins. Quorum is `floor(n/2)+1`: one member needs 1,
**two members need 2**, three need 2. ⛔ **So two members tolerate NO failures while having twice the
hardware to fail.** ⭐ **Do not linger there and do not reboot anything while you are.**

⭐ **THE WORKER JOIN OUTPUT IS 14 LINES; THE CONTROL-PLANE JOIN IS 55. That diff is the best available
definition of a control plane.** The worker has no `[download-certs]`, no `[certs] Generating`, no
`[control-plane] Creating static Pod manifest`, no `[etcd] Announced new etcd member` — it writes
`kubelet.conf`, starts the kubelet, gets a client cert signed, and stops. 📖 **Chapter 03 should print
the two side by side**; `/tmp/join-cp2.txt` and `/tmp/join-worker1.txt` are kept on the nodes.

✅ **`kubeadm join` for a control plane reported `[certs] Using the existing "sa" key`** — ⭐ **the
service-account signing key must be IDENTICAL across control planes**, or a token minted by one would
be rejected by another. That is what `--upload-certs` and the `kubeadm-certs` Secret exist to move.

⚠️ **Three measurement traps hit on the way, all the same species and all worth the chapter:**
1. **`systemctl is-active ufw` reports `active` while `sudo ufw status` reports `inactive`.** `ufw.service`
   is `Type=oneshot` with `RemainAfterExit=yes`, so "active" means **the unit ran**, not **the firewall
   is on**. ⛔ Reading the unit would have told us a firewall was running when none was — and Calico's
   requirements say an iptables manager must be disabled, so this is the check that matters.
2. 🚨 **`kubeadm init --dry-run` GENERATED A COMPLETE PKI — private keys included — and left it in
   `/etc/kubernetes/tmp/kubeadm-init-dryrun*/`.** Mode `0600` root-only, so not an exposure, but they
   are real cryptographic keys belonging to no cluster that nothing will ever rotate. **Deleted before
   the real init.** ⭐ **A flag called `--dry-run` produced key material.**
3. ⛔ **The AI's own check for that residue reported "clean" because it was wrong.** `ls -la
   /etc/kubernetes/tmp/ 2>/dev/null` **without `sudo`** on a `drwx------` directory returns a permission
   error, which `2>/dev/null` swallowed, so empty output read as "no residue" when the truth was "no
   permission". ⚠️ **Paired with an earlier `ip neigh show … || echo "no entry"` whose fallback could
   NEVER fire, because `ip neigh show` exits 0 on no match.** ⭐ **`cmd || echo fallback` is wrong in
   both directions — Stage 0 recorded one that always fired; these are two that never did.**

✅ **THE ARP SWEEP WAS VALIDATED WITH A POSITIVE CONTROL BEFORE ITS NEGATIVE WAS BELIEVED.** `.206`
returned a bare `FAILED` (no `lladdr` = free); `.150` returned `REACHABLE`, proving the node's sweep can
distinguish *absent* from *present-but-quiet*. ⭐ **Without the control, `FAILED` and "the instrument is
broken" are the same output.**

⚠️ **Flag-name casing in kube-vip is inconsistent and cannot be inferred.** `--controlplane` is all
lowercase, `--leaderElection` has a capital E, and `--controlPlaneHealthCheck*` uses camelCase
`controlPlane` — three spellings of the same words in one flag set. ✅ **Verified against
`manifest pod --help` on the actual v1.2.3 binary rather than trusting v0.5-era examples.**
⚠️ **Every kube-vip example says `--interface ens160`/`ens192` because they assume VMware. Ours is
`eth0`** — a wrong interface binds the VIP nowhere and says nothing.

⚠️ **`ctr` pulls into the `default` namespace; the kubelet reads `k8s.io`.** So the image pulled to
GENERATE the manifest was invisible to `crictl images`, and the kubelet would have fetched it again
**from ghcr.io during `kubeadm init`**. ✅ **Pre-pulled into `k8s.io` on all three control planes**,
which removes an external network dependency from the one step that cannot be half-done. ⭐ **Two image
stores disagreeing — except this time it is containerd disagreeing with itself.**

⚠️ **Expect `W… The recommended value for "bindAddress" in "KubeProxyConfiguration" is: ::` on every
init and join.** It is kubeadm advising a dual-stack bind address because the nodes have IPv6. **We are
IPv4-only by choice, so it is advice declined, not a fault.**

⚠️ **The raft indices in `endpoint status --cluster` read one apart (`11714/11715/11715`). That is
SAMPLING, not lag** — the members are queried in turn, microseconds apart. **Thousands apart would be
lag; one or two is the instrument.**

🔲 **STILL OWED before Stage 2 sign-off, and deliberately not faked:** `pause` has no shell, so this
proved scheduling, IPAM and ClusterIP reachability but **NOT cross-node pod-to-pod connectivity and NOT
DNS resolution.** ⛔ **Both need an image with a shell, chosen deliberately rather than guessed.**
⭐ **A cluster that schedules but cannot resolve names looks fine and is not.**

🔻 **PLAN ORDERING FIX — step 6 and Stage 2 are SWAPPED, Sep 17, 2026 (🙋 Andrew's call).** As written,
step 6 powers off a control plane **before** Stage 2 takes the baseline snapshot, which puts the only
deliberately destructive test in the build **ahead of its rollback point** — the newest snapshot at that
moment is `c01-nodes-ready`, which predates the cluster entirely. ⛔ **An abrupt `qm stop` is an unclean
shutdown of an etcd member**, the realistic failure and the one that can leave a corrupt data directory.
✅ **New order: graceful shutdown → offline snapshot `c02-virgin-cluster` → power on → verify → THEN
break it.** ⭐ **If the failover works the snapshot is still a valid clean baseline, so nothing is
wasted — and the plan's own "offer the reversible option first" rule is what decides it.**

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

### ✅ Stage 2 — COMPLETE, Sep 17, 2026. THE BASELINE, WRITTEN DOWN (step 4)

⭐ **Recorded because a later "something is wrong" is only meaningful against a recorded normal.**
**This is what HEALTHY prints on this cluster.** Measured, not transcribed.

| Check | Healthy output |
|---|---|
| `kubectl get nodes` | **5** nodes `Ready`, all `v1.35.8`. Control planes show `control-plane`; ⭐ **workers show `<none>`, NOT `worker`** |
| `etcdctl endpoint status --cluster` | **3 members**, exactly one `IS LEADER true`, **raft indices equal or 1–2 apart** (the spread is sampling, and it widens with write rate) |
| VIP | `192.168.1.206/32` on **exactly one** control plane. ⛔ Two holders = duplicate addresses on the wire |
| `kubectl get tigerastatus` | `apiserver` · `calico` · `ippools` · `tiers` — all `True`. ⛔ **`goldmane`/`whisker` must be ABSENT** (dropped deliberately) |
| `kubectl get ippool default-ipv4-ippool` | `cidr: 10.244.0.0/16`, `blockSize: 26`, `ipipMode: Never`, `vxlanMode: CrossSubnet` |
| Calico blocks | **one `/26` per node**, scattered not sequential |
| Pods | **43** system pods, none outside `Running`/`Completed` |
| `kubeadm certs check-expiration` | all ten control-plane certs **Sep 17, 2027** (⚠️ kubelet client certs are NOT in that list and rotate far sooner) |
| Pod-to-pod across nodes | ping succeeds, **`ttl=62`** — ⭐ two decrements means **routed, not encapsulated** |
| DNS from a pod | `10.96.0.10` resolves `kubernetes.default.svc.cluster.local` → `10.96.0.1`, and forwards external names |

📊 **MEASURED COSTS — these decide how boldly Stage 3 can break things:**
| Operation | Measured |
|---|---|
| `qm rollback` of five VMs | **6 s** |
| Rollback → all five reachable over SSH | **49 s** |
| Full cycle incl. graceful shutdown | **under ~2 min** (⚠️ **not measured precisely — the script's timer started after the shutdown loop and its label overstated what it covered**) |
| VIP failover after an abrupt power cut | **17 s** (predicted 15–20 s from lease 15 / renew 10 / retry 2) |

✅ **THE ROLLBACK IS PROVEN, NOT ASSUMED — and the method is the transferable part.** ⭐ **A successful
restore and an ordinary power cycle produce IDENTICAL output**, so markers were planted first: a
`ConfigMap` in etcd **and** a file on all five filesystems. Both came back **gone** — the file absent on
5/5, the ConfigMap `NotFound`. ⛔ **Without a marker the test proves nothing**, which is the same
prove-the-negative rule this project uses everywhere.

🔲 **STAGE 1's DOCUMENTATION IS NOT FINISHED.** ✅ **Chapter 02 written Sep 17** (*Giving a Node a
Role* — 1 figure, docx built, 20.0% marked). 🔲 **Chapters 03 and 04 still owed**, and the plan says
**Stage 1 ends when the cluster is built, tested AND DOCUMENTED** — so Stage 3 does not open yet.
⭐ **Both chapters' material is fully measured and in the Stage 1 results block above**; nothing further
needs running on the cluster to write them.

### Stage 3 — CKA administration, one task type per chapter → **chapters 05+**

**Only now does exam material get opened.** Each chapter takes **one class of administrative task**,
mapped to a curriculum domain, drilled on the cluster Stages 0 and 1 built.

⭐ **This is where deliberate breakage returns — as EXERCISES, not traps.** Troubleshooting is **30% of
the exam** and cannot be learned on a healthy cluster. The difference matters: **a trap is hidden from
the learner and fires once; an exercise is chosen, named, and can be drilled ten times** because the
snapshots make it cheap to restore. **For exam preparation the exercise is strictly better.**

🆕 **A SCHEDULED EXERCISE THAT ARRIVES ON ITS OWN — planned kernel maintenance (🙋 Andrew's proposal,
Sep 17, 2026).** ✅ **Measured: `unattended-upgrades` installed `linux-image-6.8.0-139` at 06:07:01
UTC on Sep 17 without being asked**, so the next kernel appears the same way. ⭐ **The drill does not
have to be manufactured — it has to be SCHEDULED**, the same logic the plan already applies to
v1.35 → v1.36. **The exercise is the production procedure, one node at a time:** `kubectl drain
<node> --ignore-daemonsets --delete-emptydir-data` → patch → reboot → confirm `Ready` →
`kubectl uncordon` → **only then the next**. 🚨 **On control planes, confirm etcd has a leader and
three healthy members BETWEEN each one** — taking two of three down is how maintenance becomes an
outage. ⚠️ **The parts a lab habitually skips are the parts that matter:** PodDisruptionBudgets, so a
drain cannot take an app below its minimum replicas, and verifying a node came back **before**
touching the next. ✅ **`Unattended-Upgrade::Automatic-Reboot` is unset on all five (verified
Sep 17)**, so no node reboots itself mid-drill — which is what makes leaving `unattended-upgrades`
**enabled** the right call rather than a hazard. ⛔ **Do NOT mask it like `.186`** — that is a frozen
archive; this cluster is meant to be patched, and masking it would delete the drill's delivery
mechanism.

🆕 **CHAPTER 05 IS FIXED AND IT COMES FIRST IN THE STAGE — *what a bare `kubeadm` cluster cannot do,
and what you install to fix it* (decided Sep 17, 2026).** 🙋 Andrew's question — *"we must add
Gateway API to our curriculum, how do we do that?"* — produced a better answer than a new row.
🚨 **Every remaining curriculum gap is the SAME gap: it needs something installed that `kubeadm`
does not give you.** Gateway API needs **CRDs *and* a controller**; HPA needs **`metrics-server`**
(without it an HPA reports `<unknown>` and scales nothing); dynamic provisioning needs a
**StorageClass with a real provisioner**; Ingress needs an **ingress controller**. ⭐ **We have met
this pattern once already and it is the best-understood thing in the build: Kubernetes ships no pod
network, which is why Stage 1 installs Calico by hand.** So one chapter closes **five** gap rows
under one theme, **is** the *"understand extension interfaces (CNI, CSI, CRI)"* competency, and
⭐ **is the closest thing in this phase to the actual job** — on a brownfield platform the
interesting question is always what the cluster is missing.
⚠️ **Do not over-build it:** 🟢 the exam hands you a cluster that **already has** these components,
so installing them is not what is marked. **What is marked is writing the objects correctly; what
saves you is recognising the symptom when a component is absent** — an HPA at `<unknown>`, a PVC
`Pending`, a Gateway with no address. **Those are missing-component signatures, and reading them is
Troubleshooting.** 📖 **Full step-by-step Gateway API plan, including the NodePort-before-
LoadBalancer sequencing, is in `education/k8s-cka-prep/curriculum.md`.**
🚨 **AND IT CREATES A SECOND BASELINE — a decision, not bookkeeping.** These installs are
cluster-wide, so they must **NOT** land inside `c02-virgin-cluster`. **Two baselines:**
`c02-virgin-cluster` (bare kubeadm — what the exam's *architecture* tasks resemble) and
`c03-equipped-cluster` (metrics-server, a provisioner, ingress + Gateway API — what its *workload*
tasks resemble). ⭐ **Rolling back to the wrong one silently changes what an exercise tests**, which
is the quietest way to waste a drill.
⛔ **The Gateway API controller is NOT chosen** — NGINX Gateway Fabric and Envoy Gateway are both
candidates, and newer Calico is *reported* to ship one. 🔲 **Unverified; check against the Calico
version we actually install rather than recording a guess.**
🔗 **This promotes the deferred kube-vip `--services` exercise from optional to PREREQUISITE**, since
a real `LoadBalancer` is what upgrades the Gateway from NodePort to an address of its own.

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
| 🆕 **Video instruction** — the Udemy/KodeKloud CKA course, enrolled Sep 17, 2026 at his new boss's suggestion | ✅ **Yes, and the distinction matters: this is LEARNING, not PRACTISING.** `lab-parity.md` §5's *"allowed docs only, no blogs, no AI"* rule governs **timed practice**, where outside help inflates a sense of readiness. A lecture is instruction and that rule does not reach it. ⚠️ **The failure mode is different and subtler — watching a competent person type produces confidence that does not survive an empty terminal**, which is why the agreed shape is **video for concepts, our cluster for hands**, per `METHOD.md`'s *Andrew runs the commands*. ⛔ **Andrew's standing instruction: we cover everything in the CNCF curriculum regardless of what the course covers.** ⚠️ **Watch the section BEFORE the matching stage, and expect the course's install sections to diverge from ours — when the course and the upstream docs disagree, UPSTREAM WINS for this build, and the disagreement is worth a chapter note because "the popular course does it differently" is a question he will be asked at work** |
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
- **B7 — `containerd.io` and `cri-tools` are apt-HELD (Sep 17, 2026) and stay that way.** 🚨
  `/etc/containerd/config.toml` is the most load-bearing file on these nodes — it is what withdrawn
  trap T1 was going to be — and a package upgrade is the one event that can replace it, silently
  returning the CRI plugin to `disabled`. ⚠️ **Honest scope: the automatic path cannot reach it
  anyway** — `Unattended-Upgrade::Allowed-Origins` holds only the Ubuntu archive, security and ESM
  pockets, so neither `download.docker.com` nor `pkgs.k8s.io` is eligible (verified Sep 17). ⭐ **The
  hold is insurance against a HUMAN typing `apt upgrade`, not against the machine** — which is
  exactly who it needs to stop. `apt-mark unhold` is one command when a runtime move is deliberate.
- **B8 — do NOT prune `/etc/apt/sources.list.d/docker.list` from these nodes.** It looks like residue
  on a Docker-free host and it is not: **`containerd.io` ships from Docker's repo.** ⚠️ **The
  consequence worth knowing: `apt install docker-ce` would succeed on a Kubernetes node.**

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
| **A1** | Addressing, and what `.202` is | ✅ **CLOSED Sep 16** — DHCP moved to `.221–.250`; `.200` = Apple (Mac mini), `.202` = Denon/Marantz receiver. 🔻 **This row's own allocation was STALE and contradicted §5 — corrected Sep 17, 2026.** It read *"Cluster takes `.187–.190` + `.194`, VIP `.196`"*, the pre-DHCP-move draft. ✅ **The settled allocation is `.201`–`.205`, VIP `.206`** — see §5, which was right all along. ⭐ **A decision recorded twice drifted in the copy a reader reaches last.** |
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
