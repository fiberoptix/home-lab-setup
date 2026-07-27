# Phase 14 — Kubernetes + Redpanda + OpenSearch POC

**Status:** IN PROGRESS — Parts 1, 2, 3 and **4 COMPLETE** (Jul 25–27). **Redpanda is live: 3 brokers, healthy 3/3, topic `market-ticks` (6 partitions, RF 3), quorum and failure drills run and documented.** Education series: Chapter 1 (k3s, 846 lines, 6 diagrams) and Chapter 3 (Redpanda, 1023 lines, 3 diagrams) written; Chapter 3 doubles as a replayable install runbook, with the working Helm values committed at `education/manifests/redpanda-values.yaml`. ⚠️ Snapshot `s02-k3s-up` **predates Redpanda** — rolling back to it destroys the cluster; take a fresh snapshot before risky work. **Next: consumer groups + rebalancing, then Part 6 (the Python app). Interview ~Aug 1.**
**Created:** July 25, 2026
**Owner:** Andrew
**Deadline driver:** Hedge-fund interview, ~1 week out.

---

## Why this phase exists (read this first)

This is **not** a production home-lab service. It is a **learning rig with a deadline**.

Andrew is interviewing at a hedge fund that runs **Kubernetes + Redpanda** for incoming/outgoing
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
│  Ubuntu 24.04 LTS Server · 16 vCPU · 32 GB RAM · 300 GB (vm-ephemeral)  │
│                                                                         │
│  ┌───────────────────────── k3s (single node) ────────────────────────┐ │
│  │                                                                    │ │
│  │   namespace: redpanda                                              │ │
│  │   ┌──────────┐  ┌──────────┐  ┌──────────┐   StatefulSet           │ │
│  │   │ broker-0 │──│ broker-1 │──│ broker-2 │   + Raft quorum         │ │
│  │   └──────────┘  └──────────┘  └──────────┘   RF=3                  │ │
│  │        │  Schema Registry :8081 · Kafka API :9092 · Admin :9644    │ │
│  │        │  Redpanda Console (web UI)                                │ │
│  │        │                                                           │ │
│  │   namespace: market                                                │ │
│  │   ┌────────────┐   produces (Avro)    ┌────────────┐               │ │
│  │   │ producer   │ ───────────────────► │  topic:    │               │ │
│  │   │ (Python)   │                      │ market-    │               │ │
│  │   └────────────┘                      │ data       │               │ │
│  │                                       └─────┬──────┘               │ │
│  │   ┌────────────┐   consumes                 │                      │ │
│  │   │ consumer   │ ◄──────────────────────────┘                      │ │
│  │   │ (Python)   │ ──────► indexes documents ──┐                     │ │
│  │   └────────────┘                             │                     │ │
│  │                                              ▼                     │ │
│  │   namespace: logging                  ┌──────────────┐             │ │
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

**Host headroom note:** VM 185 (OpenClaw, 16 GB / 12 cores) is dormant with `onboot=0` and stays
that way. If it were ever started alongside this VM, headroom gets tight — don't.

---

## Snapshot checkpoints (your safety net — use them)

You learn this material fastest by **deliberately breaking things**. That's only comfortable if
rollback is instant. Take a Proxmox snapshot at each green milestone:

| Snapshot name | Taken when |
|---|---|
| `s01-base-clean` | Fresh from template, personalized, before k3s — **TAKEN Jul 25** |
| `s02-k3s-up` | k3s running, `kubectl get nodes` Ready |
| `s03-redpanda-up` | 3 brokers healthy, Console reachable |
| `s04-opensearch-up` | OpenSearch + Dashboards + Fluent Bit shipping logs |
| `s05-apps-working` | Producer/consumer round-trip proven |

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
| CPU / RAM | 16 vCPU / 31 GB |
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

**Chapter 2 still to be written** from this session — deliberately not written in advance, and the
raw material is now all captured.

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
> failure drills — is [`education/chapter03_redpanda.md`](../education/chapter03_redpanda.md).**
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
  -f education/manifests/redpanda-values.yaml | grep -c requiredDuringScheduling   # must be 0

helm install redpanda redpanda/redpanda -n redpanda \
  -f education/manifests/redpanda-values.yaml --wait --timeout 10m
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

**⚠️ Snapshot `s03-redpanda-up` NOT yet taken.** Do this before the next risky step; `s02-k3s-up`
predates Redpanda and rolling back to it would destroy the cluster.

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

**→ Snapshot `04-opensearch-up` here.**

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

**→ Snapshot `05-apps-working` here.**

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

**Why a hedge fund cares:** no JVM garbage collection means far more predictable **tail latency**.
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
| Jul 27, 14:5x | **Chapter 3 written** (1023 lines, 3 diagrams, 33 questions) as a replayable runbook; `education/manifests/redpanda-values.yaml` committed and verified against `helm get values` | **Part 4 COMPLETE** except Console + Schema Registry |
