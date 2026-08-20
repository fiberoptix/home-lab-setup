# Phase 14 — Kubernetes + Redpanda + OpenSearch POC

**Status:** ✅ **CLOSED Aug 12, 2026 — GOAL MET. Andrew interviewed Aug 6/7 and GOT THE JOB**
(SRE/DevOps on an order management system). This phase existed to prepare for those two days, so it
is closed rather than extended; follow-on study work lives in
[`phase15_education_program.md`](phase15_education_program.md) and its per-track phase files.
⚠️ **All `education/…` paths in this file moved to `education/k8s-k3s-redpanda/…` on Aug 12** (Phase
15 restructured `education/` into one folder per study track); the references below were updated, but
any command copied out of an older commit will need the same requalification.
🔻 **VM 186 was right-sized on Aug 12, 2026 from 32 GB / 16 vCPU to 16 GB / 8 vCPU** — it was
provisioned for an OpenSearch install that never happened. Cluster verified healthy 3/3 afterwards
and the Part 6 ledger still reconciles to exactly 800,000 shares; see
[Right-sized Aug 12](#-right-sized-aug-12-2026--32-gb--16-gb-16-vcpu--8-vcpu). Note that **all
topic data has since aged out** under the default 7-day retention — re-seed before further work.
Parts 1, 2, 3, 4 and **6 COMPLETE** (Jul 25 – Aug 3). **Redpanda is live: 3 brokers, healthy 3/3, topics `orders` / `executions` / `market-ticks` / `orders-v2` (6 partitions, RF 3), quorum and failure drills run and documented.** **Part 6 done Aug 3: our own producer + consumer (`education/k8s-k3s-redpanda/app/`, Python 3.12 + confluent-kafka 2.6.1) built, containerised as `oms:dev`, side-loaded into k3s containerd and running — `order-gateway` Job + `position-keeper` Deployment in ns `market`, reconciling 10,000 events to exactly 800,000 shares with `seq_gaps=0`.** Education series: Chapters 1 (k3s, 846 lines), 2 (object model / rollouts / probes, 631 lines), 3 (Redpanda, 1216 lines), 4 (provisioning application state, 823 lines), 5 (consumer groups, 488 lines) and **6 (the application, 792 lines)** written; Chapters 2–6 double as replayable runbooks, with tested artefacts at `education/k8s-k3s-redpanda/manifests/` and `education/app/`. **Numbering settled Aug 3: the app is 6, Schema Registry 7, OpenSearch 8, failure drills 9.** **Headline findings from Aug 3: (1) pod-Ready is not cluster-ready — a measured 9-second window where all 3 brokers were `2/2 Ready` and 11 of 18 partitions were leaderless; (2) SIGTERM vs SIGKILL on a consumer is the difference between a clean offset handover and 3 records processed twice; (3) a transactional state store + commit-after-write is effectively-once for free, and duplicates only hurt when the side effect escapes the transaction — measured 11 duplicate "executions" against an external gateway while the transactional ledger stayed exact; (4) `acks=0` lost 29 records while reporting `delivered=15000 failed=0`.** **Restore point: `qm rollback 186 s05-app-running`** (Aug 3 19:13, live via guest-agent fs-freeze — the app deployed and reconciling. `s04-topics-seeded` (18:34) is the pre-Part-6 fallback; rolling back that far removes `orders-v2`, the app and its PVC). **Still outstanding in Part 4: Redpanda Console (ClusterIP-only, needs a port-forward) and Schema Registry.** **Next: Chapter 7 (Schema Registry) — reuses Ch4's provisioning pattern and puts a contract in front of the hand-rolled JSON the app currently produces.**
**Created:** July 25, 2026
**Owner:** Andrew
**Deadline driver:** Financial institution interview, ~1 week out.

---

## Why this phase exists (read this first)

This is **not** a production home-lab service. It is a **learning rig with a deadline**.

Andrew is interviewing at a financial institution that runs **Kubernetes + Redpanda** for incoming/outgoing
**market data and trades**, and **OpenSearch** for log search. The goal is to be able to *talk
fluently* about that stack in an interview — not merely to have made it run.

That changes how this document is written. Every part answers **what** we're doing, **why** it's
done that way, and **what an interviewer is likely to ask about it**. If a step is a shortcut that
production wouldn't take, it says so explicitly — knowing the difference between your sandbox and
a real deployment is itself an interview signal.

**Success = Andrew can whiteboard this architecture and defend the design choices.**
Running pods are just the evidence.

---

## Learning objectives

By the end you should be able to explain, without notes:

**Kubernetes**
- The difference between a Pod, Deployment, StatefulSet, and DaemonSet — and *why brokers need a
  StatefulSet* (stable network identity + stable storage that survives rescheduling).
- How a Service finds Pods (label selectors), and the difference between ClusterIP, NodePort,
  LoadBalancer, and Ingress.
- How storage is attached (PersistentVolumeClaim → StorageClass → PersistentVolume).
- What happens, step by step, when you `kubectl delete pod` something in a StatefulSet.
- Resource requests vs limits, and what actually happens when a pod exceeds each.
- Where k3s differs from a "real" cluster (see the crib sheet at the end — this WILL come up).

**Redpanda / Kafka model**
- Topic, partition, offset, consumer group, replication factor, leader vs follower.
- Why partitioning is the unit of parallelism, and how a message key decides partition placement.
- What ordering guarantees you actually get (per-partition, not per-topic) — a classic trap
  question for market-data systems.
- Raft consensus and what a quorum loss means with 3 brokers (you can lose 1, not 2).
- Why Redpanda is architecturally different from Apache Kafka: C++/Seastar thread-per-core, no
  JVM, no ZooKeeper, Raft built in, single binary.
- Schema Registry: why a trading firm enforces schemas on market data, and what
  backward/forward compatibility means when you evolve a message format.

**OpenSearch**
- The pattern of shipping pod logs via a DaemonSet collector.
- Index vs document vs shard, and why time-series data gets time-based indices.
- The difference between using it for *logs* and using it for *queryable event data*.

---

## Target architecture

Everything runs inside **one beefy VM** (VM 186), on a **single-node k3s cluster**.
Three Redpanda brokers run as three pods, giving real Raft quorum without needing three VMs.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  VM 186  vm-k8-redpanda-1   192.168.1.186                               │
│  Ubuntu 24.04 LTS Server · 8 vCPU · 16 GB RAM · 300 GB (vm-ephemeral)   │
│                                                                         │
│  ┌───────────────────────── k3s (single node) ────────────────────────┐ │
│  │                                                                    │ │
│  │   namespace: redpanda                            << BUILT Jul 27   │ │
│  │   ┌──────────┐  ┌──────────┐  ┌──────────┐   StatefulSet           │ │
│  │   │ broker-0 │──│ broker-1 │──│ broker-2 │   + Raft quorum         │ │
│  │   └──────────┘  └──────────┘  └──────────┘   RF=3                  │ │
│  │        │  Kafka API :9093 int (:9094 ext → NodePort 31092)         │ │
│  │        │  Admin :9644 · Schema Registry :8081 · HTTP proxy :8082   │ │
│  │        │  Redpanda Console — ClusterIP :8080, needs port-forward   │ │
│  │        │                                                           │ │
│  │   namespace: market                              << Part 6 (todo)  │ │
│  │   ┌────────────┐   produces (Avro)    ┌────────────┐               │ │
│  │   │ producer   │ ───────────────────► │  topic:    │               │ │
│  │   │ (Python)   │                      │ market-    │               │ │
│  │   └────────────┘                      │ ticks      │               │ │
│  │                                       └─────┬──────┘               │ │
│  │   ┌────────────┐   consumes                 │                      │ │
│  │   │ consumer   │ ◄──────────────────────────┘                      │ │
│  │   │ (Python)   │ ──────► indexes documents ──┐                     │ │
│  │   └────────────┘                             │                     │ │
│  │                                              ▼                     │ │
│  │   namespace: logging                  ┌──────────────┐ << Part 5   │ │
│  │   ┌──────────────┐  pod logs          │  OpenSearch  │             │ │
│  │   │  Fluent Bit  │ ─────────────────► │  + Dashboards│             │ │
│  │   │  (DaemonSet) │                    └──────────────┘             │ │
│  │   └──────────────┘                                                 │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

**Why this shape mirrors the firm's:** market data arrives on a durable, partitioned bus
(Redpanda), is consumed by services that transform and persist it, and everything — both
application logs and the event data itself — becomes searchable in OpenSearch. That is the
same pipeline shape, just smaller.

---

## Resource plan

| Resource | Allocation | Reasoning |
|---|---|---|
| **vCPU** | 16 (1 socket × 16) | Redpanda uses a thread-per-core design and wants dedicated cores — 2 per broker = 6, plus OpenSearch (JVM) 2–4, k3s control plane ~2, apps ~2. Host has 48 threads; 36 are allocated to running VMs today, so 52/48 is a trivial ~1.1:1 overcommit and CPU overcommit is normal. |
| **RAM** | 32 GB | OpenSearch is a JVM and the single hungriest component (~6–8 GB with dashboards); 3 brokers at 2–4 GB each; k3s + system pods ~2 GB; apps + OS ~3 GB. Host shows **69 GB free**, so this leaves ~37 GB headroom. |
| **Disk** | 300 GB on `vm-ephemeral` | Redpanda log segments + OpenSearch indices + container images. Pool has **1.6 TB free** and is correctly `ashift=12` since July. |
| **Pool choice** | `vm-ephemeral` (not `vm-critical`) | Per the documented rule: disposable/rebuildable workloads go on the stripe. This VM is by definition disposable — that's the point. |
| **Backups** | **None** | Consistent with the standing decision for rebuildable VMs. Protection here comes from **snapshots** (below), not vzdump. |

> ⚠️ **The vCPU and RAM rows above are the original July 25 plan and are now superseded.** Both
> were sized around OpenSearch, which was never installed. The VM was right-sized to **8 vCPU /
> 16 GB on Aug 12, 2026** — see [Right-sized Aug 12](#-right-sized-aug-12-2026--32-gb--16-gb-16-vcpu--8-vcpu)
> below for the measurements and the verification.

**Host headroom note:** VM 185 (OpenClaw, 16 GB / 12 cores) is dormant with `onboot=0` and stays
that way. If it were ever started alongside this VM, headroom gets tight — don't.

### Measured after Part 4 (Jul 27) — the projections were far too pessimistic

| | Planned | **Actual, idle 3-broker cluster** |
|---|---|---|
| Redpanda RAM | 2–4 GB per broker | **434 Mi per broker** (~1.3 GB total) against a 2560Mi limit |
| Redpanda CPU | 2 cores per broker | **~26m per broker** against a 1-core limit |
| k3s + system pods | ~2 GB | **317 Mi** |
| Whole node | — | **2.9 GB of 31 GB (9%), CPU 1%** |
| Disk | 300 GB | **6.0 GB used of 290 GB (3%)** |

Two things follow. **The chart's `resources` are *reservations*, not consumption** — each broker
reserves a whole core and 2.5 GB and then uses a fraction of it, which is correct for a
thread-per-core design that wants guaranteed headroom under load, but it means "allocated" and
"used" are wildly different numbers. Worth being precise about in an interview.

And **there is far more room for OpenSearch than planned** — roughly 28 GB free. Resources are not
the reason to cut Part 5 if time runs short; time is.

### 🔻 Right-sized Aug 12, 2026 — 32 GB → 16 GB, 16 vCPU → 8 vCPU

The resource plan above sized this VM for a workload that **never arrived**. OpenSearch (Part 5)
was the single hungriest line item at ~6–8 GB and it was never installed; the phase closed with
Redpanda + the OMS app only. Nine days of measurement made the over-provisioning unambiguous:

| | Assigned before | Actually needed | Assigned now |
|---|---|---|---|
| RAM | 32 GB | **3.0 GB used**; 7.7 GB *requested* by pods | **16 GB** |
| vCPU | 16 | **~1% node CPU**; 3.25 cores *requested* by pods | **8** |

The distinction that matters is the one already made above: **pod requests are reservations, not
consumption.** Kubernetes will only schedule pods whose *requests* fit the node, so the floor for
this VM is set by the 7.7 GB / 3.25 cores the pods reserve — not by the 3 GB they actually touch.
16 GB / 8 vCPU keeps requests at **50% of RAM and 41% of CPU**, which leaves genuine room to add
OpenSearch later (Part 5 is still ~6–8 GB and would fit) while returning 16 GB and 8 threads to
the host for the Phase 15 study clusters.

**Redpanda was unaffected by design, and this was verified rather than assumed.** Each broker's
Seastar arena is sized from its *container* limit (`1` core / `2560Mi`, both unchanged), not from
host RAM. Read the broker's own command line:

```bash
kubectl exec -n redpanda redpanda-0 -c redpanda -- cat /proc/1/cmdline | tr '\0' ' '
# /opt/redpanda/bin/redpanda --redpanda-cfg /etc/redpanda/redpanda.yaml \
#   --default-log-level=info --memory=2048M --reserve-memory=205M --smp=1 --lock-memory=false
kubectl exec -n redpanda redpanda-0 -c redpanda -- cat /sys/fs/cgroup/memory.max
# 2684354560   == exactly 2560Mi, the container limit
```

`--memory=2048M` + `--reserve-memory=205M` is ~88% of that 2560Mi limit, and `--smp=1` comes from
`resources.cpu.cores: 1`. **Neither flag can see the hypervisor's numbers**, which is why the resize
was safe without re-tuning the Helm values — and why the brokers still measure 468–475 Mi each
afterwards, in line with the 434 Mi recorded back in Part 4.

```bash
# On the Proxmox host. A CPU/RAM change needs a full stop — this is not a reboot.
qm shutdown 186 --timeout 240      # graceful, via guest agent — completed in 35 s
qm set 186 --cores 8 --memory 16384
qm start 186
```

> **`qm reboot` would not have worked.** `cores`/`memory` are consumed when QEMU launches the
> process, so a guest-visible reboot keeps the old topology. The VM must reach `stopped` and be
> started again. (`qm set` on a *running* VM succeeds silently and stages the change for next
> boot, which is a good way to fool yourself into thinking it applied.)

**Verified after boot** (k3s came up in ~90 s; no snapshot was taken first because a CPU/RAM
change touches no disk state and reverts with a single `qm set`):

| Check | Result |
|---|---|
| `nproc` / `free -h` in guest | **8** / **15 Gi** total |
| k3s node | `Ready`, `v1.36.2+k3s1` |
| Pods | **all 12 Running** (`redpanda-0/1/2` at 2/2, `position-keeper` 1/1, Traefik, CoreDNS, metrics-server) |
| `rpk cluster health` | **`Healthy: true`**, nodes `[0 1 2]`, **0 leaderless**, **0 under-replicated** |
| Topics | `orders`, `executions`, `market-ticks`, `orders-v2` — all 6 partitions RF 3, intact |
| Consumer group | `position-keeper` **Stable** |
| Ledger (PVC `position-state`) | **`sum(qty) = 800000` across 2000 orders, 8000 fills** — the Part 6 invariant still reconciles exactly |
| OOM kills | **none** (`dmesg` clean) |
| Graceful stop | `signal 15 received, shutting down gracefully` → `FINAL … idempotent_total=800000 … seq_gaps=0` |

Host RAM assigned to running VMs dropped from **100 GB to 84 GB of 125 GB**.

#### Two unrelated findings surfaced during verification

Both predate the resize and neither is caused by it — recorded because they will bite the next
person who opens this rig:

**1. All topic data has aged out.** `retention.ms` is the default **604800000 (7 days)** and the
events were seeded Aug 3 — nine days earlier. Every partition now reports
`LOG-START-OFFSET == LOG-END-OFFSET`, i.e. the log is empty but the offsets are preserved. **Any
future chapter work against `orders-v2` must re-seed** (`education/k8s-k3s-redpanda/manifests/seed-topics-job.yaml`).

This also explains a `TOTAL-LAG 1665` that looks alarming and is not: `orders-v2` partition 5 had
a committed offset of `0`, which is now below the log start, so on restart librdkafka logged
`offset reset … to cached BEGINNING offset 1665: Broker: Offset out of range` and moved the
*position* to the end. The **committed** offset stays at 0 until the consumer processes a record
and commits — and there are no records left to process. Lag will read 1665 until the topic is
re-seeded. The ledger proves nothing was lost.

**2. The Redpanda trial licence expires ~Aug 25, 2026** (13 days out at time of writing). The
cluster reports two Enterprise features in use, both enabled by the chart's defaults rather than
by us: `partition_auto_balancing_continuous` and `core_balancing_continuous`. Decide before then
whether to disable them or request a licence; expiry on a rig this size is not expected to be
disruptive, but it should not be a surprise.

---

## Snapshot checkpoints (your safety net — use them)

You learn this material fastest by **deliberately breaking things**. That's only comfortable if
rollback is instant. Take a Proxmox snapshot at each green milestone:

| Snapshot name | Taken when |
|---|---|
| `s01-base-clean` | Fresh from template, personalized, before k3s — ✅ **TAKEN Jul 25 16:57** |
| `s02-k3s-up` | k3s running, `kubectl get nodes` Ready — ✅ **TAKEN Jul 27 10:42** |
| `s03-redpanda-up` | 3 brokers healthy, drills complete — ✅ **TAKEN Jul 27 14:58** |
| `s04-topics-seeded` | Ch4+Ch5 state: topics seeded, consumer-group lab in place — ✅ **TAKEN Aug 3 18:34** |
| `s05-app-running` | Part 6 proven: OMS app live, ledger reconciling — ✅ **TAKEN Aug 3 19:13 ← current restore point** |

*(The planned `s04-opensearch-up` / `s05-apps-working` were never taken under those names —
Part 5 was cut, so the two slots were used for the topic-seeding and application milestones
instead. The names above are what `qm listsnapshot 186` actually reports.)*

> **Take them hot — no shutdown needed.** VM 186 has `agent: enabled=1`, so `qm snapshot` issues a
> guest **fs-freeze → snapshot → fs-thaw**. `s03-redpanda-up` took **1.5 seconds** with the Redpanda
> cluster running, and afterwards the pods showed 0 restarts and the whole log was still readable.
> The freeze is what makes a live snapshot *filesystem-consistent* rather than merely
> crash-consistent — without the agent you'd be relying on fsync and journal replay to sort it out.

> **Naming gotcha (learned the hard way, Jul 25):** Proxmox snapshot names are *configuration IDs*
> and **must start with a letter**. `01-base-clean` is rejected with
> `invalid format - invalid configuration ID`. Hence the `s` prefix, which also preserves ordering.

Roll back with `qm rollback 186 <name>`. Delete them all when the phase is done — stale snapshots
on ZFS cost space and were flagged in the Phase 13 audit.

---

## Part 1 — Reusable cloud-init base template

**Goal:** a golden Ubuntu 24.04 image that any future VM clones from in ~30 seconds.

### Why we're doing this (and why it's new for this lab)

Every VM in this lab so far was built by hand: attach ISO, click through the Ubuntu installer,
run `host_setup.sh`. That works but it is ~30 minutes of console time per VM, and it means we
have **no golden image** — confirmed on July 25: zero templates exist, and the one semi-clean
base snapshot that once existed (VM 200's `Generic-Host-Config`, Dec 2025) was deleted during
the Phase 13 audit.

A **cloud-init template** fixes this properly. Ubuntu publishes an official *cloud image* — a
pre-installed, minimal server disk designed to be cloned. On first boot, `cloud-init` reads
per-VM settings (hostname, static IP, SSH keys, user) that Proxmox injects, and configures
itself. That solves the exact problem that makes cloning dangerous: **identity collision**.
No manual scrubbing of machine-id, SSH host keys, or netplan.

> **Interview-relevant:** this is the same "immutable base image + per-instance config" pattern
> behind AMIs, Packer, and container images. Being able to describe why you template rather than
> hand-build is a DevOps maturity signal.

### Prep gaps found on the host (July 25) — ALL RESOLVED

- ~~`libguestfs-tools` is **not installed**~~ → installed (1:1.54.1).
- ~~The `local` storage lacks `snippets`~~ → content types now `iso,snippets,vztmpl,import,backup`.
- Cloud image already downloaded to `/var/lib/vz/template/iso/noble-server-cloudimg-amd64.img`.
  A pristine copy was preserved as `noble-server-cloudimg-amd64.img.pristine` (622 MB) before
  customizing, so the bake step can be repeated from a known-good starting point.

### Steps — AS BUILT (July 25, ~6 minutes end to end)

```bash
# 1. Tooling + enable snippets on local storage
apt-get install -y libguestfs-tools
pvesm set local --content iso,import,backup,vztmpl,snippets

# 2. Bake essentials into the image before it ever boots
#    (guest agent = clean shutdowns + IP reporting in the PVE UI; fleet standard since Jul 9)
cd /var/lib/vz/template/iso
cp -n noble-server-cloudimg-amd64.img noble-server-cloudimg-amd64.img.pristine
export LIBGUESTFS_BACKEND=direct        # avoids the libvirt backend, which is not set up here
virt-customize -a noble-server-cloudimg-amd64.img \
  --install qemu-guest-agent \
  --run-command 'systemctl enable qemu-guest-agent' \
  --truncate /etc/machine-id          # cleared so every clone generates its own

# 3. Create the template VM shell (VMID 9000 — Proxmox convention for templates,
#    keeps it clear of the .18x VMID series)
qm create 9000 --name tmpl-ubuntu-2404-cloudinit --ostype l26 \
  --memory 2048 --cores 2 --cpu host --numa 0 \
  --net0 virtio,bridge=vmbr0,firewall=1 \
  --scsihw virtio-scsi-single --agent enabled=1 \
  --serial0 socket --vga serial0        # cloud images expect a serial console

# 4. Import the cloud image as the boot disk, with the lab's standard disk flags.
#    NOTE: this replaces the older two-step `qm importdisk` recipe you'll find in most
#    blog posts. Modern PVE does the import and the attach in one command.
qm set 9000 --scsi0 vm-ephemeral:0,import-from=/var/lib/vz/template/iso/noble-server-cloudimg-amd64.img,iothread=1,discard=on,cache=none,aio=native

# 5. Attach the cloud-init drive — this is how Proxmox injects per-clone config
qm set 9000 --ide2 vm-ephemeral:cloudinit --boot order=scsi0
qm set 9000 --ciuser agamache --cipassword '<fleet password>' \
            --sshkeys /root/cloudinit-keys-all.pub --ciupgrade 0

# 6. Convert to a template (becomes read-only; clone it to make changes later)
qm template 9000
```

**Verification:** `qm config 9000` shows `template: 1`; the disk is renamed by Proxmox from
`vm-9000-disk-0` to **`base-9000-disk-0`** (4.81 GB) when it becomes a template — that rename is
normal and is how PVE marks a volume as a clone source.

### Two things that would have bitten us

**1. `/root/.ssh/authorized_keys` was the wrong key source.** The original plan said to inject
`/root/.ssh/authorized_keys` from the Proxmox host. On inspection that file is a symlink to
`/etc/pve/priv/authorized_keys` and contains **only the PVE cluster's RSA key** — Andrew's
workstation ED25519 key is *not* in it. Cloning with that would have produced a VM the
workstation could not SSH into. Fixed by building a combined key file on the host:

```bash
# from the workstation
cat ~/.ssh/id_ed25519.pub | ssh root@192.168.1.150 'cat > /root/cloudinit-keys.pub'
# on the host
cat /root/.ssh/authorized_keys /root/cloudinit-keys.pub | sort -u > /root/cloudinit-keys-all.pub
```

`/root/cloudinit-keys-all.pub` now holds both keys (workstation + PVE root) and is the key source
for all future clones. **Use this file, not `authorized_keys`.**

**2. `--ciupgrade 0`.** By default cloud-init runs a full package upgrade on first boot, which
adds minutes to every clone and makes "identical" clones drift apart depending on when they were
created. Turned off deliberately; upgrade explicitly when you want to.

**Maintaining it later:** you cannot boot a template. To update it, clone to a scratch VMID,
boot, `apt upgrade`, shut down, re-template, delete the old one. Expect to refresh it a couple
of times a year.

---

## Part 2 — VM 186 from the template

**Goal:** `vm-k8-redpanda-1` at `192.168.1.186`, personalized with the lab's standard tooling.

### Why VMID 186 / IP .186

The lab convention (followed by 181, 182, 184) is **VMID = last octet of the IP**. Both 186 and
.186 were verified free on July 25. VM 200 at .180 is the legacy exception, not the rule.

### Steps — AS BUILT (July 25)

```bash
# Full clone (not linked) — linked clones stay dependent on the template forever;
# with 1.3 TB free there's no reason to accept that coupling. Took ~10 seconds.
qm clone 9000 186 --name vm-k8-redpanda-1 --full --storage vm-ephemeral

# Size it for the workload
# ⚠️ SUPERSEDED Aug 12, 2026 — right-sized to `--cores 8 --memory 16384` once it was clear
#    OpenSearch was never coming. Kept verbatim as the as-built record; if you are rebuilding
#    this rig from scratch, use the smaller numbers.
qm set 186 --cores 16 --sockets 1 --memory 32768 --onboot 1
qm resize 186 scsi0 300G

# cloud-init does the identity work: static IP, hostname, user, SSH keys.
# ciuser/cipassword/sshkeys are inherited from the template — no need to repeat them.
qm set 186 --ipconfig0 ip=192.168.1.186/24,gw=192.168.1.1 \
           --nameserver "8.8.8.8 8.8.4.4"
qm start 186
```

**`--searchdomain` was dropped** from the original plan. The lab resolves internal names through
`/etc/hosts`, not DNS, so a search domain of `gothamtechnologies.com` would only add failed
lookups on every unqualified name.

**Result: pingable in ~10 seconds, fully booted with `cloud-init status: done` in ~30 seconds.**
That is the entire payoff of Part 1 — compare with ~30 minutes of ISO-installer clicking.

Verified on first boot without touching the console:

| Check | Result |
|---|---|
| Hostname | `vm-k8-redpanda-1` |
| OS | Ubuntu 24.04.4 LTS |
| cloud-init | `status: done` |
| Root filesystem | 290 GB — **`growpart` auto-expanded it** to fill the resized disk |
| CPU / RAM | 16 vCPU / 31 GB *(as built Jul 25; now 8 vCPU / 15 GB — see Right-sized Aug 12)* |
| machine-id | unique per clone (derived from the VM's own SMBIOS UUID) |
| SSH from workstation | key-based, no password prompt |
| `qm agent 186 ping` | responds |

### Personalization (the lab's standard post-install)

Run unattended — note that `host_setup.sh` prompts for confirmation and that
`setup_smb_mount.sh` needs a `smb_credentials` file sitting next to it, which `host_setup.sh`
does **not** download for you:

```bash
mkdir -p ~/setup && cd ~/setup
wget -q http://192.168.1.195/scripts/host_setup.sh
wget -q http://192.168.1.195/scripts/smb_credentials    # required, not auto-fetched
echo y | bash host_setup.sh                              # ~2 minutes
```

That installs Docker, passwordless sudo, the NAS mount, and the insecure-registry config for
`gitlab.gothamtechnologies.com:5050`.

**Post-setup cleanup (do this on any headless VM).** `host_setup.sh` is written for desktop
workstations, so it also installs **Google Chrome and Cursor** — about 1.8 GB of GUI software on
a box with no desktop. It does *not* pull in a full desktop environment, so removal is clean:

```bash
sudo apt-get purge -y google-chrome-stable cursor
sudo apt-get autoremove --purge -y
```

Disk went 4.4 GB → 2.6 GB. Worth considering a `--headless` flag on `host_setup.sh` later.

**Decisions specific to this VM:**
- **Docker:** kept. k3s brings its own containerd and does **not** need Docker, but having it is
  useful for building the Python app image locally. Worth knowing for the interview: *Kubernetes
  removed Docker as a runtime in 1.24 — it now speaks CRI to containerd directly.*
- **`refresh.sh` fleet updater:** **exclude** VM 186. Unattended package churn on a cluster
  you're actively learning on causes confusing breakage. Revisit when the POC is stable.
- **`unattended-upgrades` disabled**, along with the `apt-daily` timers — same reasoning as
  above. The cloud image ships with them on. Patch this VM manually when you choose to.
- **qemu-guest-agent:** already baked into the template.
- **Swap is off** (cloud-image default), which is what Kubernetes wants — the kubelet refuses to
  start with swap enabled unless explicitly configured otherwise. Nothing to do, but know *why*
  if an interviewer asks.

**Reboot test passed:** back up and reachable in 25 seconds, Docker and the NAS mount both
persistent, `systemctl --failed` empty.

### SSH password login — enabled after the fact (July 25, 4:55 PM)

Ubuntu cloud images ship `/etc/ssh/sshd_config.d/60-cloudimg-settings.conf` containing
`PasswordAuthentication no`, so the first build of VM 186 was **key-only** — reachable from the
Z8 (which holds the key) and from the Proxmox console, but from nowhere else. Existing fleet VMs
(`.182`, `.184`) both allow password auth, so 186 was the odd one out.

Set to `yes` on **both VM 186 and the template**, so future clones match the fleet:

```bash
# on the VM
sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' \
  /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
sudo sshd -t && sudo systemctl restart ssh
```

Login is `agamache` / the fleet password in `PASSWORDS.md`. Key auth still works and is preferred.
See the CLOUD-INIT TEMPLATE section of `MEMORY.md` for how the template disk was edited in place
(and the `machine-id` trap that comes with it). Verified by cloning a throwaway VM, proving both
password and key login on it, then destroying it.

**→ Snapshot `s01-base-clean` taken here** (retaken after the sshd change, so rolling back to it
does not silently revert password login).

---

## Part 3 — k3s (the Kubernetes layer)

**Goal:** a working single-node cluster you understand, not just one that runs.

### Why k3s

k3s is **fully upstream-conformant Kubernetes** in a single binary — the same API, the same
`kubectl`, the same YAML manifests, the same Helm charts. What it changes is the packaging:
it bundles containerd, CoreDNS, Traefik (ingress), ServiceLB, metrics-server, and a
local-path storage provisioner, and it defaults to SQLite instead of etcd for the datastore.

For learning in a week, that's ideal: you skip a day of cluster bootstrapping and spend it on
the concepts. **Be ready to name the differences** — see the crib sheet.

### Steps — AS BUILT (July 27, install took ~15 seconds)

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -

# NOTE: use $(id -u):$(id -g), not $USER. $USER sets the owner but leaves the group as
# root, and is unset in non-interactive SSH commands.
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config

kubectl get nodes -o wide
kubectl get pods -A          # see what k3s pre-installed, and ask why each exists
```

**Result:** k3s **v1.36.2+k3s1** (Kubernetes 1.36), containerd 2.3.2, node `Ready` as
`control-plane`, ~512 MB RSS. Add-ons that came with it: coredns, local-path-provisioner,
metrics-server, traefik, svclb-traefik (DaemonSet), plus two `helm-install-traefik` Jobs showing
`Completed` (success, not failure).

Also added to `~/.bashrc` on VM 186: `kubectl` bash completion, `alias k=kubectl`, `KUBE_EDITOR=nano`.

**Verified after a reboot:** `k3s.service` is enabled, node returns `Ready`, all add-ons come back.

**Gotchas worth remembering:**
- The kubeconfig points at `https://127.0.0.1:6443`, so it only works **on VM 186**. To run
  `kubectl` from the Z8, copy it and change that to `https://192.168.1.186:6443`.
- `kubectl wait --for=condition=Ready pods --all -n kube-system` **reports a timeout even on a
  healthy cluster** — Job pods complete rather than becoming Ready. The command is wrong, not the cluster.
- `--write-kubeconfig-mode 644` makes `/etc/rancher/k3s/k3s.yaml` world-readable. That file holds an
  admin client cert, so this is a sandbox convenience only.
- k3s deploys its add-ons from YAML in `/var/lib/rancher/k3s/server/manifests/` and re-applies them,
  so deleting a whole add-on Deployment gets it rebuilt from there.

**→ Snapshot `s02-k3s-up` taken July 27.**

### The hands-on session — DONE (July 27, 11:15 AM – 12:50 PM)

Run with **Andrew typing every command** and me coaching and verifying out-of-band. That split is
worth repeating for Part 4: he drives, I check state over SSH and explain what the output means.

Covered: Deployment written by hand → the three objects it creates → imperative/declarative drift →
self-healing → rollout and rollback (proving the pod-template-hash is deterministic) → Service,
EndpointSlice and DNS → the full PVC lifecycle → graceful termination → the three namespaces.

The findings worth keeping are all written up in **Chapter 1** (§5 EndpointSlice + per-connection
load balancing, §6 storage, §7 grace periods, §9a error messages) and summarised in
`current_phase.md`. Highlights that changed how I'd explain things:

- **`kubectl rollout undo` revived the *original* ReplicaSet** — still 50 minutes old, not a copy.
  Rollback is just the template hash landing on an object that already exists.
- **`curl -w "%{remote_ip}"` cannot see the backend** — it reports the ClusterIP, because DNAT is
  transparent to the client. Read the pods' own logs instead.
- **Services balance connections, not requests** → a gRPC client pins to one pod forever.
- **A 30-second `kubectl delete` is correct**, caused by the PID 1 signal rule, and measured here
  at 31 s vs 2 s with a SIGTERM handler.

**Chapter 2 was written from this session plus the 3:00 PM probe session** — deliberately not
written in advance. See [`education/k8s-k3s-redpanda/chapter02_object_model.md`](../education/k8s-k3s-redpanda/chapter02_object_model.md).

### What to actually learn here (don't skip)

Work through these deliberately — each maps to a likely interview question:

1. `kubectl run`, `kubectl get/describe/logs/exec` — the daily driver commands.
2. Write a Deployment by hand. Scale it. Delete a pod and watch the ReplicaSet replace it.
3. Expose it with a Service; understand how the label selector binds Service → Pods.
4. Inspect the `local-path` StorageClass — this is what Redpanda's PVCs will use.
5. Namespaces: we'll use `redpanda`, `market`, and `logging` to keep concerns separated.

**→ Snapshot `02-k3s-up` here.**

---

## Part 4 — Redpanda: 3 brokers + Schema Registry + Console

**Goal:** a real quorum you can break and heal.

### Why three brokers

One broker teaches you the API and nothing about distributed systems. Three gives you **Raft
consensus**: a quorum of 2 of 3 must agree, so the cluster survives losing **one** broker and
stops accepting writes if it loses **two**. Replication factor 3 means every partition has a
leader and two followers. This is exactly the territory a trading firm will probe, because it
determines whether they lose market data during a node failure.

They run as a **StatefulSet** — the workload type for stateful, individually-identifiable pods.
Each broker gets a stable DNS name (`redpanda-0`, `redpanda-1`, `redpanda-2`) and its **own**
PersistentVolumeClaim that follows it across reschedules. A Deployment would be wrong here:
interchangeable pods with shared or ephemeral storage break a consensus protocol.

### ✅ Steps as actually executed (Jul 27)

> **The full runbook — including the failed first attempt, the `rpk` wiring, verified demos and the
> failure drills — is [`education/k8s-k3s-redpanda/chapter03_redpanda.md`](../education/k8s-k3s-redpanda/chapter03_redpanda.md).**
> Only the summary lives here.

The `--set` outline below **did not work**: the chart ships **hard** pod anti-affinity, so on a
single node only one broker can schedule and the other two sit `Pending` until Helm times out.
And the documented override (`statefulset.podAntiAffinity.type=soft`) is **vestigial in chart
26.1.9** — it changes nothing. The working install uses a values file:

```bash
helm repo add redpanda https://charts.redpanda.com && helm repo update
kubectl create namespace redpanda

# verify the override actually renders BEFORE installing — this is the lesson
helm template redpanda redpanda/redpanda -n redpanda \
  -f education/k8s-k3s-redpanda/manifests/redpanda-values.yaml | grep -c requiredDuringScheduling   # must be 0

helm install redpanda redpanda/redpanda -n redpanda \
  -f education/k8s-k3s-redpanda/manifests/redpanda-values.yaml --wait --timeout 10m
```

Result: chart `redpanda-26.1.9` / app `v26.1.12`, 3 brokers `2/2 Running`, PVCs
`datadir-redpanda-{0,1,2}` 20Gi `local-path`, Console as a ClusterIP on `:8080`.

**Sandbox shortcut, flagged honestly:** `tls.enabled=false`. Production Redpanda at a financial
firm runs **mTLS between brokers and clients** plus SASL authentication. We disable it so the
first week is about Kafka semantics rather than certificate debugging. *Know that you did this
and why* — "I disabled TLS in my sandbox to focus on the data plane; in production you'd run
mTLS + SASL/SCRAM and rotate certs" is a much better answer than not noticing.

### Schema Registry — why it matters here

Redpanda ships a **Confluent-compatible Schema Registry built in** (port 8081) — no separate
component. For market data this is the whole ballgame: producers and consumers must agree on the
shape of a tick, and schemas can evolve without breaking downstream consumers. We'll register an
Avro schema for our market-data message and have the producer serialize against it.

Concepts to be able to explain: **backward compatibility** (new consumer reads old data),
**forward compatibility** (old consumer reads new data), and why adding an optional field with a
default is safe while renaming one is not.

### ✅ Exercises — done

- ✅ `rpk cluster info` / `rpk cluster health`; topic created as **`market-ticks`** (not
  `market-data`) with `-p 6 -r 3`.
- ✅ Leader-per-partition identified, and watched it move during failover:
  `rpk topic describe market-ticks -p | awk 'NR>1&&NF{print $2}' | sort -n | uniq -c`.
- ✅ Produced and consumed from the CLI. Proved **keys are deterministic** (AAPL→p3 every time)
  while **unkeyed producing is sticky, not round-robin** (300 records → one partition).
- ✅ Failure drills run early (they were the best teaching material): one broker down → surgical,
  non-load-balanced failover with writes continuing; two down → quorum lost, producers hang,
  `Leaderless` fires while `Under-replicated` misleadingly reads 0; recovery → **32 records
  reconciled exactly, zero loss.**
- 🔲 Redpanda Console not yet opened — it is ClusterIP-only, so it needs
  `kubectl -n redpanda port-forward svc/redpanda-console 8080:8080`.
- 🔲 Schema Registry (built in on `:8081`) untouched — still the Part 4 remainder.

**✅ Snapshot `s03-redpanda-up` taken Jul 27 14:58** — this is now the restore point (`s02-k3s-up`
predates Redpanda). Taken **live**, no shutdown: the guest agent fs-froze the filesystem, the ZFS
snapshot took **1.5 seconds**, and the cluster came through with 0 pod restarts and all 33 records
readable. Worth knowing as a general technique — `agent: enabled=1` is what makes a hot snapshot
filesystem-consistent rather than merely crash-consistent.

```bash
qm snapshot 186 s03-redpanda-up --description "..."   # freeze → snapshot → thaw
qm rollback 186 s03-redpanda-up                        # back to a healthy 3-broker cluster
```

---

## Part 5 — OpenSearch + Dashboards + Fluent Bit

**Goal:** searchable logs, plus a home for the event data.

The firm uses OpenSearch to check logs, so we build the canonical pattern: a **Fluent Bit
DaemonSet** — one collector pod on every node, which is precisely what DaemonSets are for —
tailing container logs and shipping them to OpenSearch, with Dashboards on top.

```bash
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm repo add fluent https://fluent.github.io/helm-charts
kubectl create namespace logging
# single-node OpenSearch + Dashboards + Fluent Bit output → OpenSearch (values validated at build time)
```

**Sandbox shortcut, flagged:** single node, and the security plugin disabled. Production runs a
multi-node cluster with dedicated master/data roles, TLS, and RBAC. Single-node means no shard
replication — fine for a sandbox, unacceptable for a firm's audit trail.

**Second use, and the more interesting one:** our Python consumer will also index the market-data
events themselves into OpenSearch, so you can query ticks — not just logs. That demonstrates you
understand OpenSearch as a **queryable data store**, not merely a log bucket.

**→ Snapshot `s04-opensearch-up` here.**

---

## Part 6 — The market-data test app (Python)

**Goal:** prove the round trip, in the domain language of the job.

### Design

Two small Python services, both running **as pods in k8s** (namespace `market`):

**Producer** — generates synthetic ticks and publishes to the `market-data` topic:
```
{ symbol: "AAPL", price: 231.44, quantity: 100, side: "BUY", ts: "2026-07-25T15:04:05.123Z" }
```
Keyed by **symbol**, which is the point worth understanding: the key decides the partition, so
all ticks for one symbol land on one partition and are therefore **strictly ordered relative to
each other**. Across symbols there is no global ordering. In a trading system that distinction
is not academic.

**Consumer** — joins a consumer group, reads the topic, and indexes each tick into OpenSearch.
Demonstrates consumer groups, offset commits, and at-least-once delivery.

### Library choice

`confluent-kafka` (the librdkafka binding) — the same client a real shop would use, and the one
with first-class Schema Registry + Avro support. `kafka-python` is pure-Python and simpler but
slower and less representative.

### Image build path (manual, per decision)

Build locally with Docker, then import straight into k3s's containerd — no registry round-trip
while iterating:
```bash
docker build -t market-producer:dev .
docker save market-producer:dev | sudo k3s ctr images import -
```
Set `imagePullPolicy: Never` in the manifest so k8s uses the local image. Wiring this into
GitLab CI is deliberately deferred — learn k8s first, automate second.

### Exercises that teach the most

- Stop the consumer, let the producer run, restart it — watch it resume from its committed offset.
- Run **two** consumer replicas in the same group and watch partitions get rebalanced between them.
- Run a second consumer in a *different* group and watch it get its own full copy of the stream.

**→ Snapshot `s05-apps-working` here.**

---

## Part 7 — Failure drills (the part that makes it stick)

Do these **after** snapshot 05, so you can always roll back:

| Drill | Command | What to watch / be able to explain |
|---|---|---|
| Kill a broker | `kubectl delete pod redpanda-1 -n redpanda` | StatefulSet recreates it with the *same* identity and reattaches the *same* PVC; partition leadership fails over; cluster stays writable (2 of 3 quorum). |
| Kill two brokers | delete two pods | Quorum lost → writes stop. This is the failure mode that matters at a trading firm. |
| Kill the consumer | `kubectl delete pod -l app=consumer -n market` | Consumer group rebalances; offsets prevent data loss; note whether any message is processed twice (at-least-once). |
| Scale consumers | `kubectl scale deploy consumer --replicas=3 -n market` | Partition assignment across group members; what happens with more consumers than partitions. |
| Exhaust memory | set a low memory limit on a pod | OOMKilled vs throttling — the practical difference between a limit and a request. |

---

## Part 8 — Interview crib sheet

### Where k3s differs from "real" Kubernetes (expect this question)

| Aspect | k3s (what you built) | kubeadm / EKS / production |
|---|---|---|
| Datastore | SQLite by default | etcd, usually 3 or 5 members |
| Packaging | Single binary, ~60 MB | Separate control-plane components |
| Ingress | Traefik bundled | Usually nginx-ingress or a cloud LB |
| LoadBalancer Services | ServiceLB (klipper) | Cloud provider LB integration |
| Storage | local-path (node-local) | EBS/CSI drivers, networked, node-independent |
| HA | Needs `--cluster-init` + embedded etcd | Multi-master by default |

The honest framing: *"k3s is conformant Kubernetes — same API and manifests — packaged for edge
and single-node use. I used it to learn the concepts quickly; the manifests I wrote would deploy
unchanged to EKS, though I'd swap local-path storage for a CSI driver and use a real ingress."*

### Redpanda vs Apache Kafka

| | Redpanda | Kafka |
|---|---|---|
| Language / runtime | C++ (Seastar), thread-per-core | Java/Scala on the JVM |
| Coordination | Raft built in | ZooKeeper (older) / KRaft (newer) |
| Deployment | Single binary | JVM + tuning + separate components |
| Compatibility | Kafka API compatible — same clients | — |
| Extras bundled | Schema Registry, HTTP proxy, Console | Usually separate (Confluent stack) |
| Typical pitch | Lower tail latency, no GC pauses, simpler ops | Larger ecosystem, longer track record |

**Why a financial institution cares:** no JVM garbage collection means far more predictable **tail latency**.
In market data, p99 latency is often the number that matters, not the average.

### Glossary to have cold

Pod · Deployment · StatefulSet · DaemonSet · Service (ClusterIP/NodePort/LoadBalancer) · Ingress ·
PVC/PV/StorageClass · ConfigMap/Secret · Namespace · liveness vs readiness probe · requests vs
limits · taints/tolerations · affinity/anti-affinity · HPA · RBAC
Topic · Partition · Offset · Consumer group · Replication factor · Leader/follower · ISR ·
Retention vs compaction · Idempotent producer · At-least-once vs exactly-once · Raft quorum ·
Schema evolution / compatibility modes

---

## Suggested schedule (~1 week)

| Session | Focus | Outcome |
|---|---|---|
| Day 1 | Parts 1–2 | Template exists; VM 186 up and personalized |
| Day 2 | Part 3 | k3s running; comfortable with kubectl and core objects |
| Day 3 | Part 4 | 3-broker Redpanda; topics via `rpk`; Console; schema registered |
| Day 4 | Parts 5–6 | OpenSearch + Fluent Bit; producer/consumer round-trip |
| Day 5 | Part 7 | Failure drills; re-read Part 8 out loud |
| Buffer | Part 8 | Rehearse the whiteboard version of the architecture |

---

## Teardown / rollback

- Roll back a mistake: `qm rollback 186 <snapshot>`
- Start over from clean: `qm destroy 186 --purge` then re-clone from template 9000 (~2 minutes)
- Delete all snapshots when finished (Phase 13 flagged stale snapshots as a real cost on ZFS)
- The template (9000) **stays** — it's the lasting deliverable from this phase and the base for
  the Phase 8 monitoring VM

---

## Out of scope (deliberately)

- GitLab CI build/deploy pipeline for the app — learn k8s first (candidate for Phase 14b)
- Multi-node k3s cluster — the template makes adding agent nodes a ~5-minute job later if wanted
- mTLS/SASL on Redpanda, OpenSearch security plugin — documented as production gaps, not built
- vzdump backups for VM 186 — it's disposable by design
- Public exposure of anything — LAN only; the Phase 12 perimeter rules stay untouched
- The "more complex app" — TBD after the POC proves out

---

## Implementation log

| When | What | Result |
|---|---|---|
| Jul 25, 11:0x | Phase planned; Ubuntu 24.04 cloud image downloaded to host; prep gaps identified (`libguestfs-tools` missing, `local` storage lacks `snippets`) | Ready to build Part 1 |
| Jul 25, 11:31 | Installed `libguestfs-tools`; added `snippets` to `local` storage content types | Done |
| Jul 25, 11:31 | Found host `/root/.ssh/authorized_keys` holds only the PVE cluster RSA key — no workstation key. Built `/root/cloudinit-keys-all.pub` (workstation ED25519 + PVE RSA) | Averted building a VM we couldn't SSH into |
| Jul 25, 11:32 | `virt-customize`: baked + enabled `qemu-guest-agent`, truncated machine-id. Pristine image copy preserved | 36 seconds |
| Jul 25, 11:33 | Created VM 9000 `tmpl-ubuntu-2404-cloudinit`, imported disk via `--import-from`, attached cloud-init drive, converted to template | Template exists; disk renamed `base-9000-disk-0` |
| Jul 25, 11:34 | Full-cloned to VM 186 `vm-k8-redpanda-1`; 16 vCPU / 32 GB / 300 GB; `ipconfig0` .186; started | Booted, cloud-init done, SSH + guest agent OK in **~30 s** |
| Jul 25, 11:35 | Ran `host_setup.sh` unattended (with `smb_credentials` staged) | Docker 29.6.2, Compose v5.3.1, NAS at `/mnt/DevShare`, passwordless sudo — all verified |
| Jul 25, 11:36 | Purged Chrome + Cursor (GUI cruft on a headless node) | 4.4 GB → 2.6 GB; `apt update` clean |
| Jul 25, 11:37 | Reboot test | Back in 25 s; Docker + NAS persistent; no failed units |
| Jul 25, 11:38 | Disabled `unattended-upgrades` and `apt-daily` timers per the no-churn decision | Done |
| Jul 25, 11:40 | Snapshot `s01-base-clean` taken (name needed the `s` prefix — PVE rejects leading digits) | **Parts 1 & 2 COMPLETE — ready for the guided Part 3** |
| Jul 25, 16:53 | Found cloud image disables SSH password auth (fleet VMs allow it). Enabled on VM 186 + edited the template zvol in place with `virt-customize` | Both password and key login work |
| Jul 25, 16:56 | Caught `virt-customize` re-populating `/etc/machine-id` on the template — would have given every future clone the same identity. Re-truncated to 0 bytes | Fixed before any clone was taken |
| Jul 25, 16:57 | Validated by cloning throwaway VM 999: password SSH ✅, key SSH ✅, unique machine-id ✅, guest agent active ✅. Destroyed it + the ZFS safety snapshot | Template proven |
| Jul 25, 16:58 | Retook `s01-base-clean` so a rollback keeps password login | Done |
| Jul 27, 08:33 | **Part 3:** installed k3s v1.36.2, set up kubeconfig, added kubectl completion/alias | Node `Ready` in ~15 s |
| Jul 27, 08:49 | Started the **education series** (`education/`): Chapter 1 on Kubernetes/k3s | 5 diagrams, ~4,700 words |
| Jul 27, 09:35 | Proved self-healing live: deleted coredns → replaced in 6 s. Traced ownership Pod → ReplicaSet → Deployment | Controller-manager (Part A) heals the add-on pods (Part B) |
| Jul 27, 09:50 | Demonstrated `local-path` PV **node affinity** and `WaitForFirstConsumer` with a throwaway PVC | PV pinned to `vm-k8-redpanda-1`; volume not created until a pod was scheduled |
| Jul 27, 10:01 | Demonstrated container-restart vs pod-replacement (same UID/IP + RESTARTS climbing, vs all-new pod) | Captured as Chapter 2's centrepiece |
| Jul 27, 10:42 | Snapshot `s02-k3s-up`; verified k3s survives a reboot | Part 3 install done |
| Jul 27, 11:15–12:50 | **Part 3 hands-on, Andrew driving:** Deployment by hand → drift → self-healing → rollout/rollback → Service + EndpointSlice → PVC lifecycle → grace periods → 3 namespaces | **Part 3 COMPLETE**; cluster returned to clean |
| Jul 27, 12:50 | Chapter 1 expanded 548 → 846 lines: new §6 storage walkthrough + fig6, §5 EndpointSlice / per-connection LB, §7 grace periods, §9a error messages, 31 self-test questions | Everything documented came from something he ran |
| Jul 27, ~13:1x | **Part 4 begins.** Concepts first: partitions/offsets, replication, Raft quorum, why StatefulSet + headless Service. Figures 1 & 2 drawn | Andrew's summary back to me ("18 replicas, 6 raft groups") was correct |
| Jul 27, ~13:3x | First `helm install` **hung and timed out**; brokers 1 & 2 `Pending` | Root cause: chart's **hard** pod anti-affinity vs a 1-node cluster |
| Jul 27, ~13:4x | ⚠️ Documented override `statefulset.podAntiAffinity.type=soft` had **no effect** — vestigial in chart 26.1.9. Found the live path via `helm template`: `statefulset.podTemplate.spec.affinity` | Habit adopted: **render and grep before installing** |
| Jul 27, 13:57 | Reinstalled from a values file (hard rule nulled, soft preference added) after `kubectl delete pvc --all` — `helm uninstall` had left the StatefulSet PVCs behind | **3 brokers `2/2 Running`**; config Job `Complete 1/1` in 37 s (one `Error` pod = normal backoff, raced broker readiness) |
| Jul 27, ~14:0x | `rpk` on the host couldn't reach brokers: dialled `localhost:31092`, failed on `redpanda-0...` — the **advertised-listener** problem | Diagnosed from the address mismatch in the error itself |
| Jul 27, 14:10 | Fixed via `/etc/systemd/resolved.conf.d/k3s-cluster-dns.conf` (`DNS=10.43.0.10`, `Domains=~cluster.local`); rpk profile repointed at all three internal FQDNs | `rpk cluster health` green; survives pod replacement |
| Jul 27, ~14:2x | Topic `market-ticks` (6 × RF 3). Keyed vs unkeyed producing; **discovered the sticky partitioner** — 300 unkeyed records all landed in one partition | Corrected the "unkeyed round-robins" explanation |
| Jul 27, ~14:3x | **Failure drills.** One broker killed → surgical, non-load-balanced failover, writes continued. Scaled to 1 → quorum lost, survivor stepped down, `Leaderless (8)` incl. the controller group, producer hung; `Under-replicated` read **0** | The best interview material of the whole phase |
| Jul 27, 14:4x | Recovered to 3/3 and reconciled the log: `-o :end` count == Σ high-watermarks == 32 | **Zero data loss.** Degraded-but-acked writes survived; the write that hung never appeared |
| Jul 27, 14:4x | Re-ran every documented command verbatim to verify the runbook, incl. the single-broker drill | Found initial leader assignment and sticky-partition choice **vary per run** — chapter now says so |
| Jul 27, 14:5x | **Chapter 3 written** (1023 lines, 3 diagrams, 33 questions) as a replayable runbook; `education/k8s-k3s-redpanda/manifests/redpanda-values.yaml` committed and verified against `helm get values` | **Part 4 COMPLETE** except Console + Schema Registry |
| Jul 27, 14:58 | Snapshot **`s03-redpanda-up`** taken **live** in 1.5 s via guest-agent fs-freeze | No downtime; verified 0 restarts + 33 records readable after |
| Jul 27, 15:05–15:30 | **Chapter 2 hands-on** (`default` ns, nginx, 5 revisions / 4 ReplicaSets): ownership chain → template hash → maxSurge/maxUnavailable → **broken readiness** (rollout stalls, 4 pods/3 Ready, still `200`s) → **broken liveness** (rollout *succeeds*, then `CrashLoopBackOff`, `000`s) → rollback + revision renumbering + `last-applied-configuration` drift | Redpanda untouched throughout; `default` returned to clean |
| Jul 27, 15:3x | **Chapter 2 written** (631 lines, 2 diagrams, 27 questions); `education/k8s-k3s-redpanda/manifests/web-deployment.yaml` verified end-to-end and carries both failure drills as inline comments | Corrected Andrew's one real misconception: `maxUnavailable` is a **capacity** guarantee, not a quorum one |

---

## 📦 CLOSING RECORD — demoted from `current_phase.md` on Aug 20, 2026

**Verbatim, not summarised.** This is the Phase 14 closing block that lived in `current_phase.md` from
Aug 12 until the file was trimmed. ⭐ **A duplication check found 0% of it anywhere in this file, so it
was genuinely the only copy** — that is why it was moved rather than dropped.

⚠️ **`education/` paths inside it are PRE-MOVE.** Everything named `education/<x>` here now lives at
`education/k8s-k3s-redpanda/<x>` (moved Aug 12, 2026). The narrative was left unedited on purpose;
correcting paths in place would have made the copy unverifiable against the original.

## ✅ CLOSED: Phase 14 — Kubernetes + Redpanda POC (was interview prep, ~1 week)

**Full plan + learning material: `phases/phase14_k8s_redpanda_poc.md`.** This was a learning rig
with a deadline (financial institution interview), not a production service. **It did its job — see above.**
All `education/` paths below moved to `education/k8s-k3s-redpanda/` on Aug 12.

### 🎯 THE ROLE (confirmed July 27) — SRE / DevOps on an ORDER MANAGEMENT SYSTEM

This is the single most important framing fact for everything in this phase. **Weight all teaching
and documentation toward operational reasoning** — failure modes, runbooks, what you do at 3am,
which instincts make an incident worse — rather than application design. **Tie every concept back
to a consequence for order/trade processing.** Examples that landed well: an unkeyed producer means
a cancel can be processed before the order it cancels; a 2-of-3 cluster has full data redundancy but
**zero** fault tolerance, so the reflex to "just bounce something" turns degraded into outage.
Andrew explicitly asked for these caveats to be kept in the docs.

### ✅ Parts 1 & 2 COMPLETE — the box is built and idle (July 25, 11:31–11:40 AM)

**Part 1 — first template in the lab: VM 9000 `tmpl-ubuntu-2404-cloudinit`**
- Installed `libguestfs-tools`, added `snippets` to `local` storage.
- `virt-customize` baked + enabled `qemu-guest-agent` into the Ubuntu 24.04 cloud image and
  truncated machine-id. Pristine image copy kept alongside it.
- VM 9000 built with the lab's standard disk flags, cloud-init drive attached, then templated.
  Its disk is now `vm-ephemeral/base-9000-disk-0` (4.81 GB) — PVE renames template volumes.
- ⚠️ **Key gotcha:** the host's `/root/.ssh/authorized_keys` (symlink to `/etc/pve/priv/`)
  holds **only the PVE cluster RSA key** — not the workstation key. Cloning with it would have
  produced an unreachable VM. Use **`/root/cloudinit-keys-all.pub`** (workstation ED25519 +
  PVE RSA) as the cloud-init key source for all future clones.

**Part 2 — VM 186 `vm-k8-redpanda-1` @ 192.168.1.186** (built 16 vCPU / 32 GB / 300 GB,
vm-ephemeral — **right-sized to 8 vCPU / 16 GB on Aug 12**, see the right-sizing section above)
- Full clone → booted → `cloud-init status: done` in **~30 seconds** (vs ~30 min of ISO clicking).
  Root fs auto-grew to 290 GB, unique machine-id, key-based SSH, guest agent responding.
- `host_setup.sh` ran unattended: Docker 29.6.2 + Compose v5.3.1, NAS at `/mnt/DevShare`,
  passwordless sudo — all verified. Needs `smb_credentials` staged next to it; it isn't auto-fetched.
- Purged **Chrome + Cursor** that `host_setup.sh` installs (desktop script on a headless box):
  4.4 GB → 2.6 GB. Consider a `--headless` flag on that script later.
- Disabled `unattended-upgrades` + `apt-daily` timers; VM 186 also stays **out of `refresh.sh`**.
  No package churn while learning. Swap is off, which is what the kubelet wants.
- Reboot test: back in 25 s, Docker + NAS persistent, no failed units.
- **Snapshot `s01-base-clean` taken.** Note: PVE snapshot names **must start with a letter** —
  `01-base-clean` is rejected, hence the `s` prefix.

### ✅ Part 3 — k3s INSTALLED (July 27, 8:33 AM) — snapshot `s02-k3s-up`

- **k3s v1.36.2+k3s1** (Kubernetes 1.36) on VM 186. Node `Ready` as `control-plane`, containerd
  2.3.2, ~512 MB RSS. Install took ~15 seconds. **Verified it survives a reboot.**
- Add-ons k3s brought: coredns, local-path-provisioner, metrics-server, traefik, svclb-traefik
  (DaemonSet), plus 2 `helm-install-traefik` Jobs at `Completed` (that's success, not failure).
- kubeconfig copied to `~/.kube/config` (mode 600). Used `$(id -u):$(id -g)` for chown, **not
  `$USER`** — `$USER` leaves the group as root and is unset in non-interactive SSH.
- Added to `~/.bashrc`: kubectl completion, `alias k=kubectl`, `KUBE_EDITOR=nano`.
- ⚠️ kubeconfig points at `127.0.0.1:6443` → only works ON VM 186. For the Z8, copy it and change
  the server to `https://192.168.1.186:6443`.
- ⚠️ `kubectl wait --for=condition=Ready pods --all -n kube-system` **times out on a healthy
  cluster** — Job pods complete instead of becoming Ready.

**Things proven live (kept as teaching material, all cleaned up afterwards):**
- Deleted coredns → replaced in 6 s. Ownership chain is Pod → ReplicaSet → Deployment, so the
  **controller-manager inside the k3s binary heals the add-on pods**.
- `local-path` PVs carry a **hard node affinity** to `vm-k8-redpanda-1`, and `WaitForFirstConsumer`
  means no volume exists until a pod is scheduled. So on node loss a pod isn't rescheduled
  elsewhere — it sits `Pending` forever.
- **Container restart ≠ pod replacement.** Container crash: same pod name/UID/IP, `RESTARTS` climbs.
  Pod deleted: new name, new UID, new IP, restarts back to 0. Different debugging entirely.

### 📘 NEW: `education/` series started (July 27)

Andrew's idea — printable study chapters with illustrations, for interview prep. Includes his own
**"ranch model"** analogy (ranch=cluster, field=node, herd=pod, cow=container, brand=label, barn
name=Service) plus a "where the analogy breaks down" section.

**Chapter 1 is now 846 lines / 6 diagrams / 31 self-test questions** (was 548 / 5 / 22). Everything
added on July 27 came out of something Andrew actually ran:

- **§5** gained the **EndpointSlice** chain (kube-proxy never evaluates selectors — a controller
  materialises them into an EndpointSlice, which is why an empty slice is the thing to check when a
  Service blackholes), the DNAT-invisibility proof, and **per-connection not per-request load
  balancing** → the gRPC/HTTP2 single-backend trap. That last one is squarely interview material
  for a firm shipping market data over gRPC.
- **§6** rewritten from a 24-line summary into a full walkthrough: new **fig6** showing the six
  layers from ZFS pool down to `/data/notes.txt`, the PVC lifecycle he drove, "the requested
  capacity is a fiction" (local-path sets no quota), and the single-failure-domain admission for
  the coming 3-broker Redpanda cluster.
- **§7** gained the 30-second grace-period table + PID 1 signal rule.
- **§9a** is new: the `kubectl` command grammar and the three real errors from the session.

**Chapter 3 (Redpanda) written July 27 — 1023 lines, 3 diagrams, 33 self-test questions.** It is
deliberately a **runbook**, not just theory: full install (incl. the failed first attempt and its
symptom cascade), the `rpk` wiring, verified demos, and the failure drills, so it can be replayed on
another lab cluster. New `education/k8s-k3s-redpanda/manifests/` folder holds real tested artefacts — currently
`redpanda-values.yaml`. Every command in it was executed and every output quoted is real; where a
result varies between runs (sticky-partition choice, initial leader assignment) the chapter says so
explicitly, because Andrew intends to re-run all of it.

**Chapter 2 (object model) written July 27 — 631 lines, 2 diagrams, 27 self-test questions.** Written
straight out of the 3:00–3:30 PM hands-on session below, so it is also a runbook:
`manifests/web-deployment.yaml` is the tested Deployment + Service with **both probe failure drills
documented inline as sed-able comments**, verified end-to-end (`apply` → `rollout status` → `200`s →
`delete`). Fig 2 is the chapter's payoff — the readiness-vs-liveness asymmetry side by side.

**Chapter 4 (provisioning application state) written Aug 3 — 823 lines, 3 diagrams, 24 self-test
questions + 10 worked interview answers.** The theme is the boundary between the two control planes:
Kubernetes builds brokers, Redpanda owns topics, and nothing owns the gap. Ships two tested artefacts
— `manifests/seed-topics.sh` (idempotent *and* drift-checking) and `manifests/seed-topics-job.yaml`
(the health-gated Job). Generalises deliberately: Schema Registry subjects, OpenSearch index
templates and DB migrations are the same problem, so Chapters 5–6 reuse the pattern.

**Chapter 5 (consumer groups) written Aug 3 — 488 lines, 3 diagrams, 24 self-test questions +
9 worked interview answers.** Covers partition assignment, the parallelism ceiling, key skew, lag,
rebalancing and delivery semantics. Ships `manifests/consumer-group-lab.sh`, a step runner that
replays the entire session. **Chapter numbering shifted:** Schema Registry is now 6, OpenSearch 7,
the app 8, failure drills 9.

**Diagrams are Graphviz `.dot` sources in `education/k8s-k3s-redpanda/diagrams/`, NOT AI-generated** — image
generators garble technical labels, and these need to be exactly right. Installed `graphviz` on the
Z8 for this. Editing gotchas (both now in `education/README.md`): newlines inside HTML-style labels
render as literal leading spaces, so keep each table cell on one source line; and `BALIGN="LEFT"`
only aligns lines *after* a `<BR/>` — set **both** `ALIGN="LEFT" BALIGN="LEFT"` on the `<TD>`, and
use a one-cell `<TABLE>` rather than `shape=box` for callouts.

### ✅ Part 3 COMPLETE — guided hands-on session (July 27, 11:15 AM – 12:50 PM)

**Andrew typed every command; I coached and verified out-of-band over SSH.** That format worked
well — keep using it. Cluster was returned to clean afterwards.

What he built and broke, in order:

- **Deployment by hand** (nginx:1.27-alpine, requests+memory limit). One manifest produced
  **three objects**: Deployment → ReplicaSet → Pod. Container is a fourth thing but not an API
  object.
- **`-l app=web` did not match the Deployment** — the manifest only put labels in
  `spec.template`, so the Deployment itself had none. Labels are per-object. Real manifests
  normally repeat them in top-level `metadata`.
- **Imperative/declarative drift:** `kubectl scale --replicas=3`, then re-applied the unchanged
  file → snapped back to 1. Best possible argument for GitOps. Scaling does **not** make a new
  ReplicaSet (template unchanged).
- **Self-healing:** deleted a pod → replacement in ~1 s, **new name, new IP**, ReplicaSet name
  unchanged. Speed was partly luck: the image was already cached. In production image pull time
  dominates recovery.
- **Rollout + rollback proved the hash is deterministic.** Changed image to `traefik/whoami` → a
  2nd ReplicaSet appeared. `kubectl rollout undo` → the **original RS came back to life, still
  50 minutes old**, rather than a third being created. Revision history then read `2, 3` (not
  `1, 2`) because a ReplicaSet only carries its most recent revision number.
- **Service.** ClusterIP `10.43.83.136`, 3 endpoints. `curl -w "%{remote_ip}"` returned the
  **ClusterIP every time** — DNAT is invisible to the client. The nginx access logs showed the
  real spread (4/3/5), so LB was working; the measurement was wrong.
- **PVC lifecycle.** `Pending` while unbound (WaitForFirstConsumer), `Bound` the instant a pod was
  scheduled, data survived pod deletion + recreation, and `kubectl delete pvc` destroyed the
  directory with no prompt (RECLAIMPOLICY=Delete).
- **Namespaces `redpanda` / `market` / `logging` created.** Demo workloads torn down; storage dir
  back to 0 entries.

**Three quirks worth remembering (all now documented in Chapter 1 §9a / §7):**

1. `name:web` (no space after the colon) → `cannot unmarshal string into Go struct field
   metadataOnlyObject.metadata of type v1.ObjectMeta`. YAML needs **colon + space**; that rule
   exists so `image: nginx:1.27-alpine` isn't torn in half. Use `--dry-run=client` to catch it.
2. `kubectl describe pod kube-system` → NotFound, because a **namespace was put in the name slot**.
   Grammar is `kubectl <verb> <type> <name> [-n <ns>]`, and `describe` defaults to `default`.
3. Object names must be **lowercase RFC 1123** — `kubectl run graceA` is rejected. They become DNS
   records.

**`kubectl delete pod` taking 30 s is correct behaviour**, and Andrew caught it himself. Measured
on this cluster, same busybox image: `sh -c "sleep 3600"` = **31 s**; with `trap ... TERM` = **2 s**;
nginx = **2 s**; `--grace-period=5` = **7 s**. Cause is the **PID 1 signal rule** — PID 1 in a
namespace only receives signals it has a handler for, even from the kubelet. Only SIGKILL/SIGSTOP
are forced. Consequence: containers that ignore SIGTERM make rolling updates and node drains crawl.
**Never `--grace-period=0 --force` a broker** — the replacement can start while the original still
holds the volume.

### ✅ Part 4 COMPLETE — Redpanda installed, broken, and healed (July 27, 1:00 – 2:50 PM)

**3-broker cluster live in ns `redpanda`.** Chart `redpanda-26.1.9` / app `v26.1.12`, `rpk v26.1.14`,
Helm v3.21.3. PVCs `datadir-redpanda-{0,1,2}` 20Gi local-path. Topic `market-ticks` 6 partitions RF 3.
Cluster currently **healthy 3/3**. Values file is committed at
`education/k8s-k3s-redpanda/manifests/redpanda-values.yaml` and verified to reproduce the live release
(`helm get values` matches; `helm template` renders 0 × `requiredDuringScheduling`).

**Two real problems solved — both are the good interview stories:**

1. **Install hung, pods `Pending`.** Chart ships **hard** pod anti-affinity → only 1 broker can
   schedule on a 1-node cluster. ⚠️ **The documented override `statefulset.podAntiAffinity.type:
   soft` is VESTIGIAL in 26.1.9 — setting it does nothing.** Real path is
   `statefulset.podTemplate.spec.affinity`: null the `required...` rule, add a `preferred...` one.
   Habit installed: **`helm template … | grep -A14 affinity` BEFORE installing.**
   Symptom cascade to remember: Helm hangs → pods Pending → **PVCs Pending is a *symptom*** (local-path
   is WaitForFirstConsumer) → redpanda-0 never Ready (no quorum alone) → config Job fails → Console
   crash-loops. Diagnose with `kubectl describe pod redpanda-1 | tail -20`; read the **earliest stuck**
   thing, not the loudest broken thing.
2. **`rpk` could not reach brokers.** Dialled `localhost:31092`, error named `redpanda-0...` — the
   mismatch IS the diagnosis. Bootstrap only asks "who are the brokers?"; the client then dials the
   **advertised listeners** directly. Fixed by teaching the host cluster DNS:
   `/etc/systemd/resolved.conf.d/k3s-cluster-dns.conf` → `DNS=10.43.0.10`, `Domains=~cluster.local`
   (`~` = routing-only). rpk profile `local` now bootstraps off all three internal FQDNs :9093
   (Kafka) / :9644 (Admin). Survives pod replacement — nothing references a pod IP.
   ⚠️ Only works because **the host IS the node** (pod IPs on `cni0`). Not a LAN-wide solution.

**Measured facts that corrected my own explanations:**

- **Unkeyed ≠ round-robin.** Sticky partitioner: 6 unkeyed → 1 partition; **300 unkeyed → still 1
  partition.** *Which* partition is random per producer session (saw p1 one run, p5 the next).
  Keys ARE deterministic and reproduced exactly across runs: AAPL→3, GOOG→3, MSFT→0, TSLA→5, AMZN→5
  — 5 keys, only 3 partitions used, two collisions, p1/p2/p4 idle. This is why ordering bugs pass
  every dev test.
- ⚠️ **`rpk topic describe -p`: HIGH-WATERMARK is awk field `$8`, not `$6`** — `REPLICAS [0 1 2]`
  contains spaces. Cost me one wrong record count.
- ⚠️ **`rpk topic consume -n N` HANGS** if fewer than N records exist; piping to `wc -l` shows
  nothing (no EOF). Use **`-o :end`** = read all + exit. `-o start:end` silently returns **0**.
- **Failover is surgical but NOT load-balanced.** Killed redpanda-1: 2/2/2 → broker 2 took **both**
  orphaned partitions (leads 4). Writes never stopped.
- **Healthy ≠ balanced.** After recovery: `Healthy: true`, yet broker 1 leads **0** partitions.
  Leader balancer runs on its own timer (minutes).
- **Quorum loss (scaled to 1):** survivor goes `1/2 Running` and steps down, `Leaderless (8)`
  including **`redpanda/controller/0`** (lose admin too), producer **hangs** rather than errors, and
  ⚠️ **`Under-replicated` reads 0** — no leader left to compute it. **Alert on `Leaderless` +
  `Nodes down`, never on `Under-replicated` alone.**
- **Zero data loss proven.** 32 records reconciled exactly (`-o :end` count == Σ high-watermarks).
  Both writes made while degraded survived; the write that hung during quorum loss never appeared.
  *Never lies about whether an order was accepted* — that's the OMS framing.
- `helm uninstall` does **not** delete StatefulSet PVCs. `kubectl -n redpanda delete pvc --all`.
- A `redpanda-configuration-*` pod in `Error` next to a `Complete` Job is **normal Job backoff**
  (post-install raced broker readiness). Judge the Job, not the pod.

**Drill hygiene learned the hard way:** always
`kubectl -n redpanda wait --for=delete pod/<name>` before judging. Checking too fast caught a
`Terminating`-but-still-serving broker and produced a write that "should" have failed.

### ✅ Chapter 2 session — Deployments, rollouts, probes (July 27, 3:00 – 3:30 PM)

Same format: Andrew typed everything, I verified over SSH. `default` ns, `nginx:1.27-alpine`,
`replicas:3`, `maxSurge:1`, `maxUnavailable:0`. Five revisions across four ReplicaSets.
**Cleaned up afterwards — `default` empty, Redpanda untouched (Healthy, 33 records).**

- **The headline demo: same broken path (`/healthz` → nginx 404), wired two ways.**
  - **Readiness broken → fails SAFE.** Rollout stalls at 4 pods / 3 Ready. EndpointSlice shows
    `10.42.0.82 ready=false` while the other three are `true`. Service returns `200 200 200 200 200 200`
    — **the bad build never served a single request.**
  - **Liveness broken → fails DEADLY.** Readiness still passed, so the **rollout SUCCEEDED** and
    deleted all three good pods; only *then* did liveness start killing. All pods
    `CrashLoopBackOff restarts=4`, service returns `000 000 000 000 000 000`. **Total outage.**
  - One-liner to remember: **readiness gates the rollout, liveness does not.**
- **`CrashLoopBackOff` + `Exit Code: 0` ⇒ something external killed it — almost always liveness.**
  Best debugging heuristic of the session. nginx caught SIGTERM and exited clean.
- **`rollout status --timeout=60s` is client-side patience only.** It went red while
  `progressDeadlineSeconds=600` kept the rollout grinding in the background. A red CI job can leave a
  half-rolled deploy that everyone assumes never shipped.
- **`Available=True` while the deploy was broken.** Availability ≠ rollout success. Monitor
  `Progressing` too.
- **`rollout undo` leaves a landmine.** After a *successful* rollback: live cluster `/` (good), file on
  disk `/healthz`, `last-applied-configuration` `/healthz` (both broken). The next `apply` re-ships the
  outage. Andrew got this instantly — strongest GitOps argument available. Also **revisions get
  re-tagged**: history went `1,2,3` → `1,3,4`, so a revision number quoted earlier in an incident may
  not exist any more.
- **The two rollbacks differed, and that's the lesson.** After the readiness stall the good pods were
  never touched (RS held 3/3, age climbed to 8m38s) = zero disruption. After the liveness outage they
  were already destroyed, so rollback created new pods under the same hash = real downtime.
- **Andrew's one genuine misconception — re-check this later.** He thought `maxUnavailable` protects
  Raft quorum. It doesn't: it's a **capacity** guarantee, and the Deployment controller counts Ready
  pods with no concept of consensus. Answered in Ch2 §9 (StatefulSet ordinal updates, PDBs for
  *voluntary* disruption only, cluster-aware readiness), tied back to Part 4's finding that
  `Healthy: true` coexisted with a broker leading zero partitions.
- Minor but confirmed: `apply` printing `configured` does **not** mean a rollout happened (only
  pod-template changes churn pods); scaling makes no new ReplicaSet; labels are per-object
  (`-l app=web` missed the Deployment until `metadata.labels` was added).

### ✅ Chapter 4 session — topic provisioning, idempotency, drift, the readiness race (Aug 3, ~1:00 – 5:45 PM)

Long session, six demos, all written up the same day. Framing was Andrew's: *"what would I do as a
DevOps guy during a pipeline deployment to get the brokers deployed and the topics seeded?"*

- **The gap, proved.** With `auto_create_topics_enabled=false`, producing to an unseeded topic fails
  `UNKNOWN_TOPIC_OR_PARTITION` exit 1 — while Helm says `deployed`, pods are `Running` and
  `rpk cluster health` says `Healthy: true`. **Infrastructure green ≠ service usable.**
- **`rpk topic create` is not idempotent** (exit 1 on `TOPIC_ALREADY_EXISTS`). Naive Job works on the
  first deploy, then fails forever. Guard is `rpk topic describe` (exit 0 = exists).
- **`kubectl wait --for=condition=complete` only watches for success.** Job died at 34s, the wait sat
  the full 90s then reported a *timeout* — wrong cause, wasted time. Race both conditions (§9a).
- **THE headline finding — pod-Ready is not cluster-ready.** Andrew spotted the state by accident,
  then we measured it: **`21:32:02` all 3 pods `2/2 Ready` → `21:32:11` `Healthy: true`. A 9-second
  window** where every Kubernetes signal was green and **11 of 18 partitions were leaderless.** It was
  11 not 18 because each partition is its own Raft group and they elect independently.
- **`Under-replicated partitions (0)` while 11 were leaderless — the metric lied for the second time**
  (first was the Jul 27 quorum drill). No leader ⇒ nobody computes it. **Alert on `Leaderless`.**
- **The trap inside the fix:** `rpk cluster health` is an **Admin API (:9644)** call. `-X brokers=`
  (Kafka API :9093) is *silently ignored*, so rpk fell back to `127.0.0.1:9644` and the guard hung
  5 minutes against a healthy cluster. Tested from inside `redpanda-0` it "worked" — because there
  localhost:9644 really is a broker. **A health gate that can't reach its target looks exactly like an
  unhealthy target.** Correct flag: `-X admin.hosts=`.
- **Retry moved from pod level into the container.** `backoffLimit` conflates "tolerate a slow
  dependency" with "retry a real error". An init container polling for health decouples them: 600s
  wait budget, `backoffLimit: 2` failure budget. Costs **0s** healthy, took **50s** through a full
  scale-to-zero outage.
- **Fixed sleeps are unfixable:** scheduled→Ready was **21s** warm and **~2 min** cold.
- **Idempotent ≠ reconciling.** An existence-only guard reports success forever on a topic with 2
  partitions where 6 were declared. Led to the **three-tier drift model**, all four behaviours
  captured live: **Tier 1** (retention → fix in place, exit 0), **Tier 2** (RF → report, exit 1, human
  schedules the data movement), **Tier 3** (partition count → *never* auto-fix, exit 1).
- **Script design notes:** `set -uo pipefail` deliberately **without `-e`** so every drift is reported
  in one run, not revealed serially; and `awk` on table output rather than `jq`, which the broker
  image doesn't ship — using the broker's own image also keeps `rpk` version-matched to the cluster.
- Confirmed `publishNotReadyAddresses: true` on the headless Service, so **DNS resolution is not a
  readiness signal** — it hands out brokers that aren't accepting connections yet.
- Also confirmed: `market-ticks` records from Jul 27 had **aged out** via `retention.ms=604800000`
  (`LOG-START-OFFSET` caught up to `HIGH-WATERMARK`). Not data loss.

### ✅ Chapter 5 session — consumer groups, rebalancing, delivery semantics (Aug 3, 5:50 – 6:30 PM)

Same format, five hands-on steps on topic `orders` (6 partitions, 1500 records, 12 keys) with group
`oms-processor` grown 1 → 7 members and back to 5.

- **Three rules of assignment:** one owner per partition at any instant; a consumer may own many;
  **assignment counts partitions, not records.** At 2 members the split was 3/3 by partition and
  **120 vs 60 by data** — one consumer doing double the work, permanently.
- **Parallelism ceiling proved:** 7 consumers on 6 partitions → the 7th got **no assignment, zero
  records**. And `c1` owned p0 which has **never held a record**, so 7 consumers, only 5 working.
  **Worst-case lag is set by the hottest partition, not the consumer count.**
- **But idle ≠ useless** — when the p2 owner was killed, the surplus `c7` **inherited it instantly**
  (already connected, already in the group). A surplus consumer is a **warm standby**. I'd called it
  "pure cost" one step earlier and the next demo disproved it.
- **Skew, quantified:** 12 keys hashed into 6 partitions gave p2 **5 keys = 42% of traffic** and p0
  **zero**. Andrew asked the right question — why doesn't Redpanda rebalance it? Two answers: the
  producer computes `hash(key) % n` **client-side** so the broker never gets a vote; and moving a key
  would split its history across two partitions read by two consumers → **a cancel could be processed
  before its order**. Separate small-numbers skew (self-correcting at real cardinality) from a
  genuinely hot key (needs a composite key or dedicated topic — *not* more partitions).
- **⭐ THE demo: SIGTERM vs SIGKILL on the same partition.** p2 had 4 owners over its life:
  `c1 0..74`, `c6 75..137`, `c7 138..395`, `c2 393..624`. **SIGTERM** → committed and left cleanly,
  `137→138`, **zero duplicates**. **SIGKILL** → consumed through 395 but last commit was 392, so the
  successor replayed **393/394/395 (ORD-10, ORD-11, ORD-2) — 628 processed for 625 written.**
  Real-world OOM kills, force-deletes and liveness kills are all the SIGKILL case.
- **Duplicates = throughput × time since last commit.** Tuning the commit interval changes the odds,
  never the possibility → **the fix is an idempotent consumer**, not tuning. Exactly-once only covers
  read-process-write loops that stay *inside* the cluster.
- **Reading the describe table:** lag is per-partition (`TOTAL-LAG` is only the sum, and hides a
  stalled hot partition — **alert on max per-partition lag**); `CURRENT-OFFSET  -` means *never
  committed*, which is not offset 0.
- **Rebalances make distribution less fair over time** — after two deaths, one consumer owned both p2
  (hot) and p3. Nothing balances for load.
- **Offsets live in `__consumer_offsets`** — 16 partitions, RF 3, **`cleanup.policy=compact`** so they
  can't age out. Group name hashes to one partition (`/7` here) whose leader is the coordinator.
  Explains why `-o start` did *not* replay history for a newly joined member.
- Andrew's one misread, worth noting: seeing p2 records in several logs he said "everyone got some of
  his messages." It's a **relay, not sharing** — contiguous, non-overlapping ranges over time. The log
  file is the union of everything that consumer ever owned.

### ✅ Part 6 + Chapter 6 session — our own producer and consumer (Aug 3, 6:40 – 9:10 PM)

Built unattended. Python 3.12 + `confluent-kafka` 2.6.1, one image `oms:dev` with two entrypoints,
side-loaded into k3s containerd (no registry). Topic `orders-v2` 6p/RF3, group `position-keeper`,
`order-gateway` Job + `position-keeper` Deployment in ns `market`. Source at `education/k8s-k3s-redpanda/app/`.
Workload is **2000 orders × (1 NEW + 4 FILL) = 10,000 events / 8,000 fills / 800,000 shares**, with
fixed arithmetic so the right answer is knowable without coordination.

**Chapter 6 is built around four bugs, three of them mine.** They turned out to be far better
material than the working version would have been.

- ⭐ **The demo that "failed".** Two ledgers, hard kill mid-stream, expecting the naive one to
  inflate. Got **zero duplicates in both** — because both were in the *same SQLite transaction*,
  committed just before the offset. The kill rolled the writes back, the offset was also
  uncommitted, so state and offset stayed in lockstep and redelivery re-applied cleanly.
  ⇒ **A transactional state store + commit-after-write is effectively-once for free.** No dedupe
  table, no exactly-once protocol. That is the cheap answer, and most consumers qualify.
- **So duplicates only hurt when the side effect escapes the transaction.** Reworked the second
  ledger as a separate file on an autocommit connection (a stand-in for a POST to a venue). Same
  kill: **8011 gateway calls for 8000 real fills — 11 duplicate executions, 1,100 shares nobody
  ordered** — while the transactional ledger stayed exactly 800,000.
- **The tail that never commits.** Commit trigger was record-count only, so on an idle topic the
  last partial batch never committed: **lag stuck at 13 indefinitely**, and that tail replayed on
  *every* restart — duplicates went **11 → 22 → 33, compounding**. Fix: commit on count **or**
  elapsed time, including on the idle path. ⇒ **stuck lag is a commit-policy bug; a slow consumer's
  lag changes.**
- ⚠️ **`kubectl delete pod --force --grace-period=0` is not a reliable SIGKILL.** The runtime still
  delivered SIGTERM and my handler shut down cleanly — I was testing the graceful path believing it
  was the hard one. `kill -9 1` inside the container fails too (the kernel shields PID 1). What
  works is killing from the node; confirmed by `lastState: Error:137`, the same code an **OOM kill**
  gives. It was a **container restart in place**, not a pod replacement.
- **A hung consumer looks exactly like a healthy one.** A SQLite lock bug left it processing one
  record while `1/1 Running` with a clean log and zero restarts. Only lag showed it. ⇒ liveness
  should assert **progress**, not that the process exists.
- **`acks=0` lost 29 records silently** — `delivered=15000 failed=0` but 14,971 in the topic, against
  15,000/15,000 for `acks=all`. **The whole benefit was 0.2 seconds.** A duplicate is loud and
  recoverable; a lost fill is a position you don't know you hold.
- **Ch5's skew caveat confirmed:** 12 keys gave 42% on one partition; **2000 keys gave a 9.4%
  spread.** Skew is a function of key *cardinality*, not partitioning.
- **Ordering proven, not assumed:** `seq_gaps=0` across 2000 orders, via per-order sequence tracking.
- `BALANCER range` here vs `cooperative-sticky` in Ch5 — **rebalance behaviour belongs to the
  clients, not the cluster.** And a per-event durable side effect cost **~8×** throughput (1,550 → 200
  events/s), which is *why* commit windows exist.

### ✅ Documentation session — audit, Word build, highlighting, Chapter 7 (Aug 3, 7:15 – 10:30 PM)

**Pure documentation. The VM was not touched — no k3s, no Redpanda, no drills.** Snapshot
`s05-app-running` is still the restore point and is unaffected.

- **Audited Ch1–6 against the artefacts** and fixed as I went (commit `8baab57`). Real errors, not
  polish: a wrong k3s memory claim, a broken `kubectl wait`, wrong `rpk group describe` column
  indices, a `Service` selector that did not match, a bad anti-affinity example, and record counts
  that disagreed with the scripts. Also hardened the shipped manifests — `restricted` PSA on ns
  `market`, `automountServiceAccountToken: false`, non-root `USER` in the Dockerfile.
- **Word `.docx` pipeline** (`education/tools/build_docx.py`, output committed to
  `education/k8s-k3s-redpanda/docx/`).
  7-inch column, Cambria 11 pt, single-spaced, images full width — Andrew's spec so it reads like a
  textbook and prints legibly. **The TOC was removed entirely** after it rendered as a literal "No
  table of contents entries found" banner on page 1; pandoc writes the field but only Word can
  populate it, so patching was the wrong fix and he said "drop all TOC".
- **Ch1's ranch allegory deleted** at his request; the piece-by-piece table stayed.
- **~15 % yellow highlighting across all 7 chapters** so he can revise from the marks alone.
  Character style `Key`, shade `#FFF3B0` (low saturation, chosen so print does not bleed). Marks are
  stored in the Markdown, so rebuilds keep them. Mechanics and traps are in MEMORY.md.
- **Chapter 7 — `additional_infra_stack`, 981 lines, 2 figures, 18 questions** (commits `720c655`,
  `134943b`). Commissioned straight off the job description and scoped by him to **research only,
  build nothing**: edge/Cloudflare, IAM + Symantec PAM, Vault, PKI/cert-manager, MongoDB, and
  OTEL → Prometheus/Grafana/OpenSearch, each framed as "how would this attach to *our* OMS at
  thousands of external and hundreds of internal users". Researched by five parallel subagents; the
  edge one died twice on `resource_exhausted` and I wrote that section by hand.
- **The chapter's argument, worth keeping:** every area maps onto something the earlier chapters
  already measured. Mongo write concern *is* `acks`; an arbiter downgrades the default write concern
  the way `min.insync.replicas=1` undermines `acks=all`; and putting the Kafka offset inside a Mongo
  transaction buys exactly-once for the database while **changing nothing** about the non-idempotent
  execution gateway — so **Ch5's 821,600 phantom shares would be exactly as phantom afterwards.**
- **Two corrections to earlier chapters, made inside Ch7** rather than by editing them (he said not
  to touch existing docs): Redpanda **does** now publish consumer-group lag behind an opt-in
  property, which qualifies Ch3 without overturning "lag is derived, not intrinsic"; and Ch6's
  "undetectable" hung consumer **is** detectable — a staleness gauge climbing at exactly one second
  per second.

### ⏭️ Next — SUPERSEDED (this list was written Aug 3, before the interviews)

> **Historical.** Read the Phase 15 section at the top of this file for what is actually next.
> The deadline this list was organised around has passed and the outcome was an offer.

1. **Nothing is blocked and nothing is half-finished.** All 7 chapters are written, audited,
   highlighted, built to `.docx` and committed.
2. ~~**Open verification item:** the `.docx` highlighting has never been *seen*.~~
   ✅ **CLOSED Aug 12** — Andrew confirmed the yellow looks right in Word. The OOXML inspection
   (318 `Key` runs, `FFF3B0` fill, no leaked markup) was correct. There is still no
   LibreOffice on the Z8, so future highlight work is still verified by unzipping.
3. ~~⛔ **Do NOT start chapters 8–10 before the interviews**~~ — no longer applies; the interviews
   happened Aug 6/7. Chapters 8–10 are now simply **planned and unblocked**. The motivation for 8
   (Schema Registry) is still sound: the app produces hand-rolled JSON with no contract, so renaming
   `qty` silently breaks the consumer. 9 is OpenSearch + Fluent Bit, 10 is failure drills.
4. Hands-on loose ends, ~an hour each, all still open and none urgent: a **liveness probe that
   asserts progress** on the consumer (Ch6 §13 argues for it but it was never built — it closes the
   one story that currently has no ending), Redpanda Console via port-forward, `rpk group seek` for
   replay, and a lag-alerting demo.

**📅 Timing — the interviews were Aug 6 and Aug 7, and Andrew got the job.** ✅ Everything from here
to the end of this section is the **Aug 3 run-up plan, kept as a record.** The one judgement in it
worth carrying forward: *unabsorbed documentation is worth nothing* — reading and drilling what
exists beat producing more of it, and that stayed true.

Two days almost certainly means two panels, so expect breadth. The asymmetry to manage: Ch1–6 is
material he *ran with his own hands* and can speak to from experience, whereas **Ch7 is the only
material he has merely read** — and it maps directly onto the job description's bullet list, which
makes it likely interview ground. That gap is the thing to close first.

Suggested use of the 3 days (proposed Aug 3, not yet agreed with Andrew):
- **Aug 4** — read all 7 chapters once, then revise from the yellow highlights. That is exactly what
  the 15 % pass was built for. Ch7 twice, since it is the unpractised half.
- **Aug 5** — hands on the box. Rebuild the muscle memory for the commands in the "know by heart"
  sections, and do the one build that is still missing: **a liveness probe that asserts progress**
  on the consumer. Ch6 §13 argues for it and it was never built, and "a hung consumer looks
  identical to a healthy one" is a strong story that currently ends without a fix.
- **Keep in reserve, only if time is genuinely free:** Redpanda Console, `rpk group seek` replay,
  lag alerting. All are nice; none are worth trading sleep for.

Redpanda remains the strongest part of the story. Part 5 (OpenSearch) is still the one to cut.

**Restore point: `qm rollback 186 s05-app-running`** (taken Aug 3 19:13, live via guest-agent
fs-freeze) — the OMS app deployed, reconciling, lag 0. Fallbacks: `s04-topics-seeded` (Aug 3 18:34,
pre-Part-6; rolling back that far removes `orders-v2`, the app and its PVC) and `s03-redpanda-up`
(Jul 27 14:58, healthy 3-broker cluster, no topics from Aug 3).
`s02-k3s-up` predates Redpanda — rolling back that far wipes it. Snapshot was taken **live** in 1.5 s
via guest-agent fs-freeze, no VM downtime, verified 0 restarts + 33 records readable after.

---

