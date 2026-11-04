# CKA exercise bank — exam-shaped tasks, earned in this lab

**Started:** November 4, 2026 (🙋 Andrew: *"let's start collecting possible exercises now … make sure they are
shaped like questions that would be on the exam"*). **Added to by every Stage 3 part from now on** — see the
rule in `phases/phase18_k8s_cka_build.md` § *EXERCISE BANK*.

**Purpose:** a pool of tasks the AI can draw from later to **run a timed mock exam on this cluster** — break
things while Andrew is not looking, start a clock, grade each task by a command whose output proves it.

---

## ⛔ The boundary — read before adding anything

- 🚨 **Original task text only.** Every task here is written from the 🟢 published curriculum
  ([`curriculum.md`](curriculum.md)) and from something **this lab actually built or broke**. Community
  reports of task **types** ("expect an etcd restore") are welcome — they are how coverage is checked. ⛔ But
  **no verbatim recalled exam task, dump, or Killer.sh / course mock text is ever committed here**: this file
  is public, exam content is under the Linux Foundation's confidentiality agreement, and Killer.sh's tasks are
  its copyright. **Extract the type, write our own task, cite the type not the text** (`phase18` § *EXERCISE
  SOURCING*, Sep 16).
- 🚨 **Public-safe.** This file goes to GitHub. Nothing about Andrew's employer or its environment.
- ⭐ **An exercise is chosen and named, not a trap** (`phase18` §8). Andrew knows a fault is coming; he
  does not know which one, or where.

## 📐 The shape — why the tasks read the way they do

Modelled on what is **officially** documented about the exam ([`exam-environment.md`](exam-environment.md)):
🟢 each task opens with an **infobox naming the host to `ssh` to**; you work there and `exit`; no nested SSH;
the task may link its own Quick Reference docs. 🟡 Community reports (not verified — README **Q3** is still
open) add: tasks are **imperative and exact** — named objects, namespaces and output-file paths — several
are **multi-part**, and each shows a **weight**. So every task here:

1. Starts with **Host** (lab: `ssh agamache@<ip>` from the workstation — node names do **not** resolve
   from the nodes, measured Nov 4).
2. States the **outcome**, never the method. Names exact objects and exact answer-file paths.
3. Carries a **weight** — 🔲 *our estimate*, for scoring a mock, not a published figure.
4. Has a **Verify** command the AI runs to grade it, and a **Reset**.
5. Keeps its **answer key folded** — read it only after attempting.

📁 **Answer files go in `~/answers/` on the task's host** (create it if missing — that is part of the task).

## 🏁 Running a mock exam (the procedure, for a future session)

1. **Baseline:** roll back to the right snapshot first (`c03-equipped-cluster` once it exists; until then
   the current state — metrics-server installed, nothing else). ⚠️ The wrong baseline silently changes what
   a task tests (`phase18` §6).
2. **Pick 15–17 tasks weighted like the exam:** Troubleshooting 30 · Cluster Architecture 25 · Services &
   Networking 20 · Workloads & Scheduling 15 · Storage 10. Prefer ✅ *drilled* setups; a 🔲 setup gets a
   dry check by the AI first.
3. **Set up** every task's fault (AI, via SSH, Andrew not watching). Then **start a 120-minute clock**.
   ⏱️ Budget ≈ **7 minutes a task** ([`logistics.md`](logistics.md)); skip and return rather than sink 15.
4. **Andrew works only from the allowed docs** (kubernetes.io/docs, the Helm and Gateway API docs).
   🤫 **The AI says nothing until asked** (`phase18` §12, Stage 3 posture).
5. **Grade** with each task's Verify, score by weight (pass mark 🟢 **66%**), then **Reset** everything.
6. **Write the result into the task's Drilled log** below — date, minutes, pass/fail, what slowed him down.
   Weak areas feed the next lab session; then re-sit a Killer.sh session ([`lab-parity.md`](lab-parity.md) §6).

## Status marks

| Mark | Meaning |
|---|---|
| 🧪 **Earned** | The skill was done for real in this lab (chapter cited); the task's setup has **not** been run as an exercise yet |
| ✅ **Drilled** | Run at least once as a timed exercise; setup, verify and reset all proven |
| 🔲 **Backlog** | A task idea for a part not built yet — gets written out when that part is built |

---

## The tasks

### X01 · metrics-server is installed, but nothing can read metrics

**Domain:** Troubleshooting (30%) — *troubleshoot cluster components*, *monitor resource usage* · also
Cluster Architecture — *use Kustomize to install cluster components* · **Weight:** 7% · **Target:** 7 min ·
**Status:** 🧪 Earned — Ch 05 Part 1, Nov 4, 2026

> **Host:** `vm-k8s-cka-control-1` — `ssh agamache@192.168.1.201`
>
> `metrics-server` is deployed in namespace `kube-system`, but `kubectl top nodes` returns
> `error: Metrics API not available`. Its installation lives in `~/ch05/metrics-server/` (an upstream
> `components.yaml` and a `kustomization.yaml`).
>
> Make `kubectl top nodes` report all five nodes. **Do not modify `components.yaml`**; make any change
> through `kustomization.yaml` and apply it from that directory.

**Setup (AI):** on control-1, rewrite `~/ch05/metrics-server/kustomization.yaml` with `resources:` only (no
`patches:`) and `kubectl apply -k ~/ch05/metrics-server`. Apply replaces the whole `args` list, so the flag goes.

**Verify (AI):**
```bash
kubectl top nodes --no-headers | wc -l                                                     # 5
kubectl get apiservice v1beta1.metrics.k8s.io -o jsonpath='{.status.conditions[?(@.type=="Available")].status}'  # True
sha256sum ~/ch05/metrics-server/components.yaml   # 1cec29a5…f72c79b — unedited upstream v0.9.0
```
**Reset:** the committed `manifests/ch05/metrics-server/kustomization.yaml`, `kubectl apply -k`.

<details><summary>Answer key</summary>

Walk the chain backwards from the error: `kubectl get apiservice v1beta1.metrics.k8s.io` →
`False (MissingEndpoints)` → the pod is `0/1` Ready → `kubectl -n kube-system logs deploy/metrics-server`
→ `x509: cannot validate certificate for 192.168.1.20x because it doesn't contain any IP SANs` (the kubelets'
serving certificates are self-signed). Add a JSON 6902 patch to the kustomization:

```yaml
patches:
  - target:
      kind: Deployment
      name: metrics-server
    patch: |-
      - op: add
        path: /spec/template/spec/containers/0/args/-
        value: --kubelet-insecure-tls
```
`kubectl kustomize .` to preview, `kubectl apply -k .`, `kubectl -n kube-system rollout status deploy/metrics-server`.
⚠️ Lab fix only — production uses kubelet `serverTLSBootstrap` and approved serving-certificate CSRs.
</details>

**Drilled log:** —

---

### X02 · A worker is NotReady

**Domain:** Troubleshooting (30%) — *troubleshoot clusters and nodes* · **Weight:** 7% · **Target:** 6 min ·
**Status:** 🧪 Earned — kubelet behaviour Ch 01 (restart loop) and Ch 04 (node down, Lease)

> **Host:** `vm-k8s-cka-control-1` — `ssh agamache@192.168.1.201`
>
> Node `vm-k8s-cka-worker-2` is reported `NotReady`. Bring it back to `Ready`, and make sure the fix
> **survives a reboot** of that node.

**Setup (AI):** `ssh agamache@192.168.1.205 'sudo systemctl disable --now kubelet'`. Wait ~50 s for `NotReady`.

**Verify (AI):**
```bash
kubectl get node vm-k8s-cka-worker-2 --no-headers | awk '{print $2}'                              # Ready
kubectl -n kube-node-lease get lease vm-k8s-cka-worker-2 -o jsonpath='{.spec.renewTime}'          # within ~10 s of now
ssh agamache@192.168.1.205 'systemctl is-enabled kubelet; systemctl is-active kubelet'            # enabled / active
```
**Reset:** `sudo systemctl enable --now kubelet` on `.205` if the attempt failed.

<details><summary>Answer key</summary>

From control-1, `exit` back to the workstation and `ssh agamache@192.168.1.205` (the exam forbids nested
SSH — practise the same habit). `systemctl status kubelet` → `inactive (dead)`, `disabled`.
`sudo systemctl enable --now kubelet`. "Survives a reboot" is the half that is marked separately: `start`
alone passes the first check and fails the second. Confirm from control-1 that the node is `Ready` — and
⭐ **trust the Lease `renewTime`, not `Ready` alone**: `Ready` lags ~50 s behind reality in both directions.
</details>

**Drilled log:** —

---

### X03 · A worker is NotReady, and the kubelet is running

**Domain:** Troubleshooting (30%) — *troubleshoot clusters and nodes* · Cluster Architecture —
*extension interfaces (CRI)* · **Weight:** 8% · **Target:** 8 min ·
**Status:** 🧪 Earned — Ch 01 step 4 (the CRI plugin Docker's containerd disables) · ⚠️ setup untested

> **Host:** `vm-k8s-cka-worker-1` — `ssh agamache@192.168.1.204`
>
> Node `vm-k8s-cka-worker-1` is `NotReady` although the `kubelet` service is active. Find the cause and fix
> it on the node. Do not reinstall any package.

**Setup (AI):** on `.204`: `sudo cp /etc/containerd/config.toml /root/config.toml.x03`, then set line 5
`disabled_plugins = []` → `disabled_plugins = ["io.containerd.grpc.v1.cri"]`, `sudo systemctl restart containerd`.
🔲 **First run must confirm the fault took:** `sudo ctr plugins ls | grep cri` shows the CRI plugin not `ok`,
and the node goes `NotReady`. (Measured Nov 4: config `version = 4`, containerd v2.3.5, line 5 holds
`disabled_plugins = []`.) If the fully-qualified id does not disable it, try `"cri"` and record which worked.

**Verify (AI):**
```bash
ssh agamache@192.168.1.204 "grep -n '^disabled_plugins' /etc/containerd/config.toml; sudo ctr plugins ls | awk '/grpc.*\<cri\>/{print \$4}'"  # [] / ok
kubectl get node vm-k8s-cka-worker-1 --no-headers | awk '{print $2}'                                                              # Ready
```
**Reset:** `sudo cp /root/config.toml.x03 /etc/containerd/config.toml && sudo systemctl restart containerd`
(⚠️ `config.toml` is the most load-bearing file on a node — hard rule B7).

<details><summary>Answer key</summary>

`kubectl describe node` → `KubeletNotReady … container runtime is down` / `runtime not ready`.
On the node: `sudo journalctl -u kubelet -n 30` → errors reaching the CRI endpoint;
`sudo crictl version` fails (no `RuntimeVersion`); `sudo ctr plugins ls | grep cri` → not `ok`;
`grep disabled_plugins /etc/containerd/config.toml` → the CRI plugin is listed. Set `disabled_plugins = []`,
`sudo systemctl restart containerd`, then (if needed) `sudo systemctl restart kubelet`. ⭐ This is exactly what
every Docker-built host in this lab ships with (`disabled_plugins = ["cri"]`, verified on `.191`, Ch 01).
</details>

**Drilled log:** —

---

### X04 · Read a container's logs with the API out of the picture

**Domain:** Troubleshooting (30%) — *manage and evaluate container output streams* · Cluster Architecture —
*extension interfaces (CRI)* · **Weight:** 4% · **Target:** 5 min · **Status:** 🧪 Earned — `crictl` Ch 01 step 6

> **Host:** `vm-k8s-cka-worker-1` — `ssh agamache@192.168.1.204`
>
> Using the container runtime's tools on the node — **not `kubectl`** — find the running `kube-proxy`
> container on this node.
> 1. Write its container ID to `~/answers/x04-id.txt`.
> 2. Write its **last 10 log lines** to `~/answers/x04-logs.txt`.

**Setup:** none (delete `~/answers/x04-*` on `.204` first).

**Verify (AI):**
```bash
ssh agamache@192.168.1.204 'diff <(sudo crictl ps --name kube-proxy -q) ~/answers/x04-id.txt && wc -l < ~/answers/x04-logs.txt'  # no diff / 10
```
**Reset:** `rm -f ~/answers/x04-*` on `.204`.

<details><summary>Answer key</summary>

```bash
mkdir -p ~/answers
sudo crictl ps --name kube-proxy -q > ~/answers/x04-id.txt
sudo crictl logs --tail 10 $(cat ~/answers/x04-id.txt) > ~/answers/x04-logs.txt 2>&1
```
🚨 **The trap, measured Nov 4:** kube-proxy logs to **stderr**, and `crictl logs` replays each stream on its
own stream — `--tail 2` printed **0 lines on stdout, 2 with `2>&1`**. Without `2>&1` the file is empty and the
task looks done. (`/etc/crictl.yaml` must point at the socket; the lab's does.)
</details>

**Drilled log:** —

---

### X05 · Certificates: when do they expire, and what do they cover?

**Domain:** Cluster Architecture (25%) — *create and manage clusters using kubeadm* · **Weight:** 4% ·
**Target:** 5 min · **Status:** 🧪 Earned — Ch 02 step 7 (SANs), Ch 04 step 7 (expiry)

> **Host:** `vm-k8s-cka-control-1` — `ssh agamache@192.168.1.201`
>
> 1. Write the expiry date of the API server's serving certificate, **as reported by kubeadm**, to
>    `~/answers/x05-expiry.txt`.
> 2. Write every **IP address** that certificate is valid for, one per line, to `~/answers/x05-ips.txt`.
> 3. Do not renew anything.

**Setup:** none.

**Verify (AI):**
```bash
sudo kubeadm certs check-expiration | awk '$1=="apiserver"'          # compare the date with x05-expiry.txt
sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -ext subjectAltName | grep -o 'IP Address:[0-9.]*' | cut -d: -f2 | sort | diff - <(sort ~/answers/x05-ips.txt)
```
**Reset:** `rm -f ~/answers/x05-*`.

<details><summary>Answer key</summary>

1. `sudo kubeadm certs check-expiration` → the `apiserver` row (one year from init; the CA rows are ten).
2. `sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text | grep -A1 'Subject Alternative Name'`
   (or `-ext subjectAltName`). ✅ **Measured Nov 4 on control-1:** `10.96.0.1` (the `kubernetes` Service),
   `192.168.1.201` (the node) and `192.168.1.206` (the VIP, there because it was the `--control-plane-endpoint`
   at init — Ch 02); expiry **Sep 17, 2027**. ⚠️ Each control plane has its **own** `apiserver.crt` with its own
   node IP — the answer differs on control-2 and control-3.
</details>

**Drilled log:** —

---

### X06 · Prepare to add a worker

**Domain:** Cluster Architecture (25%) — *create and manage clusters using kubeadm* · **Weight:** 4% ·
**Target:** 4 min · **Status:** 🧪 Earned — Ch 03 steps 8–11 (joins); token expiry note (old trap T4)

> **Host:** `vm-k8s-cka-control-1` — `ssh agamache@192.168.1.201`
>
> A new worker node will be joined to this cluster in the next hour. Create a bootstrap token that is valid
> for **2 hours** and write the complete command the new node must run to join, to `~/answers/x06-join.sh`.
> Do not join any node.

**Setup:** none.

**Verify (AI):**
```bash
grep -E '^kubeadm join 192\.168\.1\.206:6443 --token [a-z0-9]{6}\.[a-z0-9]{16} --discovery-token-ca-cert-hash sha256:[0-9a-f]{64}' ~/answers/x06-join.sh
sudo kubeadm token list    # the token from the file, TTL ≈ 1h5xm–2h
```
**Reset:** `sudo kubeadm token delete <token>`, `rm -f ~/answers/x06-*`.

<details><summary>Answer key</summary>

`sudo kubeadm token create --ttl 2h --print-join-command > ~/answers/x06-join.sh`. The endpoint in it is the
**VIP** `.206`, not control-1's own address — because `--control-plane-endpoint` was set at init. ⚠️ A
*control-plane* join would also need `--control-plane --certificate-key <key>` from
`sudo kubeadm init phase upload-certs --upload-certs` (Ch 03 step 8). ⚠️ `token create` is ⚠️ not yet run in
this lab (`COMMANDS.md`).
</details>

**Drilled log:** —

---

### X07 · Who leads etcd?

**Domain:** Cluster Architecture (25%) — *highly-available control plane* · Troubleshooting — *cluster
components* · **Weight:** 4% · **Target:** 5 min · **Status:** 🧪 Earned — Ch 04 steps 8–12

> **Host:** `vm-k8s-cka-control-1` — `ssh agamache@192.168.1.201`
>
> 1. Write the number of etcd members to `~/answers/x07-members.txt`.
> 2. Write the **node name** of the current etcd leader to `~/answers/x07-leader.txt`.

**Setup:** none.

**Verify (AI):** the full `etcdctl … endpoint status --cluster -w table` (`COMMANDS.md` §3) — 3 members, and the
`IS LEADER true` endpoint's IP maps to the node name in the file.

**Reset:** `rm -f ~/answers/x07-*`.

<details><summary>Answer key</summary>

```bash
kubectl -n kube-system exec etcd-vm-k8s-cka-control-1 -- etcdctl \
  --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt \
  --key /etc/kubernetes/pki/etcd/server.key endpoint status --cluster -w table
```
`IS LEADER true` gives an **IP** — map it with `kubectl get nodes -o wide`. All three certificate flags are
required every time. `member list` alone proves membership, not agreement or leadership.
</details>

**Drilled log:** —

---

### X08 · Which pod network is the cluster really using?

**Domain:** Services & Networking (20%) — *connectivity between Pods* · Cluster Architecture — *extension
interfaces (CNI)* · **Weight:** 3% · **Target:** 4 min · **Status:** 🧪 Earned — Ch 03 step 5

> **Host:** `vm-k8s-cka-control-1` — `ssh agamache@192.168.1.201`
>
> Write the pod CIDR that the CNI allocates pod addresses from, and the size (prefix length) of the address
> block it gives each node, to `~/answers/x08.txt` in the form `<cidr> /<block-size>`.

**Setup:** none.

**Verify (AI):** `kubectl get ippool default-ipv4-ippool -o jsonpath='{.spec.cidr} /{.spec.blockSize}'`
(measured Nov 4: `10.244.0.0/16 /26`) — compare with the file.

**Reset:** `rm -f ~/answers/x08.txt`.

<details><summary>Answer key</summary>

`kubectl get ippool default-ipv4-ippool -o yaml | grep -E 'cidr|blockSize'` — `-o wide` shows only name and
age, the CRD defines no columns. 🚨 **The trap:** `node.spec.podCIDR` (from kube-controller-manager's
allocator) is a *different* allocator from Calico's IPAM and **does not** describe the addresses pods get
(Ch 03). The kubeadm `--pod-network-cidr` agrees here only because Ch 03 step 5 made the install file agree.
</details>

**Drilled log:** —

---

### X09 · Which control plane is actually doing the work?

**Domain:** Cluster Architecture (25%) — *highly-available control plane* · **Weight:** 3% · **Target:** 3 min ·
**Status:** 🧪 Earned — Nov 4, 2026 (Ch 05 Part 1: control-2 held both leases)

> **Host:** `vm-k8s-cka-control-1` — `ssh agamache@192.168.1.201`
>
> This cluster runs three replicas of `kube-scheduler` and of `kube-controller-manager`. Write the name of the
> node whose `kube-scheduler` is the **active** one to `~/answers/x09-scheduler.txt`, and the same for
> `kube-controller-manager` to `~/answers/x09-kcm.txt`.

**Setup:** none. (Optional harder variant: the AI `qm stop`s the current leader's VM first — the answer moves.)

**Verify (AI):** `kubectl -n kube-system get lease kube-scheduler kube-controller-manager -o custom-columns=N:.metadata.name,H:.spec.holderIdentity`
— the node-name prefix of `holderIdentity` (before `_`) matches each file.

**Reset:** `rm -f ~/answers/x09-*`.

<details><summary>Answer key</summary>

`kubectl -n kube-system get lease kube-scheduler kube-controller-manager` → `HOLDER` is
`<node-name>_<uuid>`; write the node name only. Only the lease holder works; the other two are hot
standbys. Pod logs give it away too (`successfully acquired lease`) but the Lease is the authoritative answer.
</details>

**Drilled log:** —

---

### X10 · Take a worker out for maintenance, safely

**Domain:** Cluster Architecture (25%) — *manage the lifecycle of clusters* · Workloads & Scheduling —
*robust, self-healing deployments* · **Weight:** 7% · **Target:** 8 min ·
**Status:** 🧪 Earned (procedure planned for the kernel drill, `phase18` §6) · ⚠️ setup untested

> **Host:** `vm-k8s-cka-control-1` — `ssh agamache@192.168.1.201`
>
> Deployment `web` in namespace `x10` must never have fewer than **1** available replica during voluntary
> disruptions.
> 1. Create a PodDisruptionBudget named `web-pdb` in `x10` that enforces this.
> 2. Prepare node `vm-k8s-cka-worker-2` for maintenance: no new pods may be scheduled on it, and every pod on
>    it except DaemonSet-managed pods must be evicted. Leave the node in that state.

**Setup (AI):** `kubectl create ns x10 && kubectl -n x10 create deployment web --image=nginx:1.27 --replicas=2`.
⚠️ The task needs pods **on** worker-2: check with `kubectl get pods -A -o wide | grep worker-2`; metrics-server
ran there on Nov 4, and it uses an `emptyDir`, which is the point (see the key).

**Verify (AI):**
```bash
kubectl get node vm-k8s-cka-worker-2 --no-headers | awk '{print $2}'          # Ready,SchedulingDisabled
kubectl -n x10 get pdb web-pdb -o jsonpath='{.spec.minAvailable}'               # 1
kubectl get pods -A --field-selector spec.nodeName=vm-k8s-cka-worker-2 -o jsonpath='{range .items[*]}{.metadata.ownerReferences[0].kind}{"\n"}{end}' | sort -u   # DaemonSet only
kubectl -n x10 get deploy web -o jsonpath='{.status.availableReplicas}'         # 2
```
**Reset:** `kubectl uncordon vm-k8s-cka-worker-2 && kubectl delete ns x10`.

<details><summary>Answer key</summary>

```bash
kubectl -n x10 create pdb web-pdb --selector=app=web --min-available=1
kubectl drain vm-k8s-cka-worker-2 --ignore-daemonsets --delete-emptydir-data
```
Without `--ignore-daemonsets` the drain refuses (Calico, kube-proxy). Without `--delete-emptydir-data` it
refuses on any pod with an `emptyDir` — metrics-server has one. "Leave the node in that state" = do **not**
uncordon. ⭐ The PDB is what turns a drain from "evict everything" into "evict without breaking the app".
</details>

**Drilled log:** —

---

### X11 · The Service exists, the pods run, nothing answers

**Domain:** Troubleshooting (30%) — *troubleshoot services and networking* · Services & Networking —
*service types and endpoints* · **Weight:** 6% · **Target:** 6 min ·
**Status:** 🧪 Earned (Service routing proven, Ch 04 step 3) · ⚠️ setup untested

> **Host:** `vm-k8s-cka-control-1` — `ssh agamache@192.168.1.201`
>
> In namespace `x11`, the pods of Deployment `api` are running, but requests to Service `api` on port 80
> from inside the cluster get no response. Fix it so the Service routes to the Deployment's pods.
> **Do not modify or recreate the Deployment.**

**Setup (AI):**
```bash
kubectl create ns x11
kubectl -n x11 create deployment api --image=nginx:1.27 --replicas=2
kubectl -n x11 create service clusterip api --tcp=80:80
kubectl -n x11 patch service api -p '{"spec":{"selector":{"app":"apy"}}}'
```

**Verify (AI):**
```bash
kubectl -n x11 get endpointslices -l kubernetes.io/service-name=api -o jsonpath='{.items[*].endpoints[*].addresses[0]}'   # two pod IPs
kubectl -n x11 run t --rm -i --restart=Never --image=busybox:1.38.0 -- wget -qO- -T3 http://api | grep -c 'Welcome to nginx'  # 2 (title + h1; seen Nov 4)
kubectl -n x11 get deploy api -o jsonpath='{.metadata.generation}'                                                        # 1 — untouched
```
**Reset:** `kubectl delete ns x11`.

<details><summary>Answer key</summary>

`kubectl -n x11 get endpointslices -l kubernetes.io/service-name=api` → no endpoints. Compare
`kubectl -n x11 get svc api -o jsonpath='{.spec.selector}'` (`app=apy`) with
`kubectl -n x11 get pods --show-labels` (`app=api`). Fix the **Service**:
`kubectl -n x11 patch svc api -p '{"spec":{"selector":{"app":"api"}}}'` (or `kubectl edit`). ⭐ A Service that
resolves in DNS but has no endpoints is the canonical "routes nowhere" — the curriculum's *"and endpoints"*
is there for exactly this.
</details>

**Drilled log:** —

---

### X12 · Two claims are Pending — only one is broken

**Domain:** Storage (10%) — *storage classes, dynamic provisioning, volume modes and access modes, PVs and
PVCs* · also Troubleshooting · **Weight:** 6% · **Target:** 7 min ·
**Status:** 🧪 Earned — Ch 05 Part 2, Nov 4, 2026 (the `WaitForFirstConsumer` half) · ⚠️ setup untested

> **Host:** `vm-k8s-cka-control-1` — `ssh agamache@192.168.1.201`
>
> In namespace `x12`, PersistentVolumeClaims `logs` and `cache` are both `Pending`. One of them is
> behaving exactly as its StorageClass intends; the other will never bind.
> 1. **Do not modify, delete or recreate the claim that is working as intended.**
> 2. Make the broken claim usable with the cluster's **default** StorageClass. Keep its name, size `1Gi`
>    and access mode `ReadWriteOnce`.
> 3. Create a Pod `cache-user` in `x12` (image `busybox:1.38.0`, command `sleep 3600`) that mounts
>    `cache` at `/cache`, and confirm the claim is `Bound`.

**Setup (AI):**
```bash
kubectl create ns x12
kubectl -n x12 apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: logs
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cache
spec:
  storageClassName: fast
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
EOF
kubectl -n x12 get pvc logs -o jsonpath='{.metadata.uid}'; echo   # note it — Verify checks it is unchanged
```

**Verify (AI):**
```bash
kubectl -n x12 get pvc logs -o jsonpath='{.metadata.uid} {.status.phase} {.spec.storageClassName}'; echo  # same uid · Pending · local-path
kubectl -n x12 get pvc cache -o jsonpath='{.status.phase} {.spec.storageClassName} {.spec.resources.requests.storage}'; echo  # Bound local-path 1Gi
kubectl -n x12 get pod cache-user -o jsonpath='{.status.phase} {.spec.volumes[0].persistentVolumeClaim.claimName}'; echo     # Running cache
kubectl get sc fast   # NotFound — the fix was the claim, not a new class
```
**Reset:** `kubectl delete ns x12`. The PV goes with it (reclaim policy `Delete`), and the provisioner's
`helper-pod-delete-…` removes the folder on the node.

<details><summary>Answer key</summary>

`kubectl get sc` first: `local-path (default)`, binding mode `WaitForFirstConsumer`. Then
`kubectl -n x12 describe pvc logs` and `… cache`, and read **the events, not the status** — both say `Pending`.
- `logs`: no class written, so the default was filled in (retroactive assignment); its event is
  `WaitForFirstConsumer … waiting for first consumer to be created before binding`. **This is the one
  working as intended** — nothing mounts it, so nothing is provisioned. Leave it.
- `cache`: asks for class `fast`, which does not exist. 🔲 *Recited, confirm at the first drill:* the event
  names the missing class.

A claim's `storageClassName` cannot be changed once set, so **`cache` must be deleted and recreated** without
the `storageClassName` line (or with `local-path`). Then the Pod:
```bash
kubectl -n x12 get pvc cache -o yaml > cache.yaml   # edit: drop storageClassName, status, uid, resourceVersion
kubectl -n x12 delete pvc cache && kubectl -n x12 apply -f cache.yaml
kubectl -n x12 run cache-user --image=busybox:1.38.0 --dry-run=client -o yaml -- sleep 3600 > pod.yaml
# add volumes[].persistentVolumeClaim.claimName: cache and volumeMounts[].mountPath: /cache, then apply
kubectl -n x12 get pvc cache   # Bound once the pod is scheduled
```
⭐ Seen Nov 4: retroactive assignment is **not instant** — a check 5 s after making the class default still
showed no class; it appeared about 20 s later, on the volume controller's next pass. Wait one pass before
calling it broken.
</details>

**Drilled log:** —

---

### X13 · The Gateway was accepted, and nothing routes

**Domain:** Services & Networking (20%) — *use the Gateway API to manage Ingress traffic* · Cluster
Architecture — *understand CRDs* · also Troubleshooting · **Weight:** 4% · **Target:** 5 min ·
**Status:** 🧪 Earned — Ch 05 Part 3, Nov 4, 2026 (run as `demo` in `default`; not yet as `x13`)

> **Host:** `vm-k8s-cka-control-1` — `ssh agamache@192.168.1.201`
>
> In namespace `x13`, Gateway `shop` was created without errors, but it has no address and serves no traffic.
> Do not change or delete it. Write:
> 1. the controller name its GatewayClass asks for to `/home/agamache/x13/controller.txt`;
> 2. the `reason` of the Gateway's `Programmed` condition to `/home/agamache/x13/reason.txt`;
> 3. every **served** version of CRD `httproutes.gateway.networking.k8s.io`, one per line, the **storage**
>    version first, to `/home/agamache/x13/versions.txt`.

**Setup (AI):**
```bash
mkdir -p ~/x13 && kubectl create ns x13
kubectl apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: edge
spec:
  controllerName: example.com/edge-controller
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: shop
  namespace: x13
spec:
  gatewayClassName: edge
  listeners:
  - name: http
    protocol: HTTP
    port: 80
EOF
```

**Verify (AI):**
```bash
cat ~/x13/controller.txt   # example.com/edge-controller
cat ~/x13/reason.txt       # Pending
cat ~/x13/versions.txt     # v1, then v1beta1 (Gateway API v1.6.3)
kubectl -n x13 get gtw shop -o jsonpath='{.metadata.generation}'; echo   # 1 — untouched
```
**Reset:** `kubectl delete ns x13 && kubectl delete gc edge && rm -rf ~/x13`. ⚠️ The GatewayClass is
cluster-scoped, so deleting the namespace does **not** delete it.

<details><summary>Answer key</summary>

```bash
kubectl -n x13 get gtw shop -o jsonpath='{.spec.gatewayClassName}'                  # edge
kubectl get gc edge -o jsonpath='{.spec.controllerName}' > ~/x13/controller.txt
kubectl -n x13 get gtw shop -o jsonpath='{.status.conditions[?(@.type=="Programmed")].reason}' > ~/x13/reason.txt
kubectl get crd httproutes.gateway.networking.k8s.io \
  -o jsonpath='{range .spec.versions[*]}{.name} served={.served} storage={.storage}{"\n"}{end}'
```
Write the versions by hand from the last command (`v1` storage, `v1beta1` served). ⭐ `Unknown` / `Pending:
Waiting for controller` is **a default in the CRD schema, filled in by the API server** — no controller wrote
it. It means nothing that claims `example.com/edge-controller` has ever seen the object. The fix in real life
is a running controller, or a class that names one that runs. Compare: `the server doesn't have a resource
type "gatewayclass"` means the CRDs themselves are missing.
</details>

**Drilled log:** —

---

### X14 · The HTTPRoute is valid, and the Gateway will not take it

**Domain:** Services & Networking (20%) — *use the Gateway API to manage Ingress traffic* · also
Troubleshooting · **Weight:** 7% · **Target:** 8 min ·
**Status:** 🧪 Earned — Ch 05 Part 4 steps 4–5, Nov 4, 2026 (run as `hello` in `default`; not yet as `x14`)

> **Host:** `vm-k8s-cka-control-1` — `ssh agamache@192.168.1.201`
>
> In namespace `x14`, Deployment `shop` and Service `shop` (port 80) are running, and HTTPRoute `shop` sends
> host `shop.lab` to that Service. Yet `curl -H 'Host: shop.lab' http://192.168.1.204:30080/` returns `404`.
> Make that request return the application's page.
> **Do not modify anything in namespace `traefik`, and do not upgrade the Helm release `traefik`.**
> Keep the route's name, hostname and backend.

**Setup (AI):**
```bash
kubectl create ns x14
kubectl -n x14 create deployment shop --image=nginx:1.27
kubectl -n x14 expose deployment shop --port=80
kubectl -n x14 rollout status deployment shop
kubectl apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: shop
  namespace: x14
spec:
  parentRefs:
  - name: traefik-gateway
    namespace: traefik
  hostnames: ["shop.lab"]
  rules:
  - backendRefs:
    - name: shop
      port: 80
EOF
helm history traefik -n traefik --max 1 -o yaml | grep revision   # note it — Verify checks it is unchanged
```

**Verify (AI):**
```bash
curl -s -H 'Host: shop.lab' http://192.168.1.204:30080/ | grep -c 'Welcome to nginx'      # 2
kubectl -n x14 get httproute shop -o jsonpath='{range .status.parents[*]}{.parentRef.name} {.conditions[?(@.type=="Accepted")].status}{"\n"}{end}'  # <gateway in x14> True
kubectl -n traefik get gtw traefik-gateway -o jsonpath='{.spec.listeners[0].allowedRoutes}'; echo   # {"namespaces":{"from":"Same"}} — untouched
helm history traefik -n traefik --max 1 -o yaml | grep revision   # same as at setup
```
**Reset:** `kubectl delete ns x14` (takes the candidate's Gateway with it — Gateways are namespaced).

<details><summary>Answer key</summary>

`kubectl -n x14 get httproute shop` has **no status column** — read the parents:
`kubectl -n x14 get httproute shop -o jsonpath='{range .status.parents[*].conditions[*]}{.type}={.status} {.reason}{"\n"}{end}'`
→ `Accepted=False NotAllowedByListeners`, `ResolvedRefs=True` (the backend is fine — that condition is a false
comfort). Why: `kubectl -n traefik get gtw traefik-gateway -o jsonpath='{.spec.listeners[0].allowedRoutes}'`
→ `from: Same` — only routes in `traefik` may attach, and the task forbids changing that. So give `x14` its
own Gateway and move the route onto it:
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web
  namespace: x14
spec:
  gatewayClassName: traefik
  listeners:
  - name: http
    protocol: HTTP
    port: 8000          # Traefik's web ENTRYPOINT port, not the Service's 80
```
then set the route's `parentRefs` to `- name: web` (no namespace) and re-apply. ⚠️ **Port 8000:** Traefik
matches a listener to an entrypoint by port (`--entryPoints.web.address=:8000/tcp` in its args); 80 is the
Service port. 🔲 *Recited, not run:* a `ReferenceGrant` does **not** help — it governs `backendRefs` across
namespaces, not which routes a listener admits.
</details>

**Drilled log:** —

---

### X15 · Change a Helm release, then undo it

**Domain:** Cluster Architecture (25%) — *use Helm to install cluster components* · **Weight:** 5% ·
**Target:** 6 min · **Status:** 🧪 Earned — Ch 05 Part 4 step 6, Nov 4, 2026

> **Host:** `vm-k8s-cka-control-1` — `ssh agamache@192.168.1.201`
>
> The Helm release `traefik` in namespace `traefik` serves this cluster's Ingress and Gateway traffic on
> NodePort `30080`. The values it was installed with are in `~/ch05/traefik/values-traefik.yaml`.
> 1. Using Helm only (not `kubectl scale` or `kubectl edit`), run Traefik with **2** replicas. Keep every
>    other customised value; NodePort `30080` must keep serving.
> 2. Roll the release back to the revision that was deployed **before** your change.
> 3. Write the revision number that is deployed **after** the rollback to `/home/agamache/x15/revision.txt`.

**Setup (AI):** `mkdir -p ~/x15`; note `helm history traefik -n traefik --max 1` (call it N).

**Verify (AI):**
```bash
helm history traefik -n traefik --max 3                               # N+1 superseded "Upgrade complete", N+2 deployed "Rollback to N"
cat ~/x15/revision.txt                                                 # N+2 — a rollback adds a revision
kubectl -n traefik get deploy traefik -o jsonpath='{.spec.replicas}'; echo                     # 1
kubectl -n traefik get svc traefik -o jsonpath='{.spec.type} {.spec.ports[0].nodePort}'; echo  # NodePort 30080
curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: nothing.lab' http://192.168.1.204:30080/    # 404 = Traefik answering
```
**Reset:** `rm -rf ~/x15`. The extra revisions are harmless history.

<details><summary>Answer key</summary>

```bash
helm get values traefik -n traefik            # USER-SUPPLIED VALUES only — what must be kept
helm upgrade traefik traefik/traefik --version 42.3.0 -n traefik -f ~/ch05/traefik/values-traefik.yaml --set deployment.replicas=2
kubectl -n traefik rollout status deploy/traefik
helm history traefik -n traefik               # note the revision before the upgrade
helm rollback traefik <that revision> -n traefik
helm history traefik -n traefik --max 1       # the new, higher number → revision.txt
```
⚠️ **Without `-f` (or `--reuse-values`) the upgrade starts from chart defaults + `--set` only** and silently drops
the overrides: the Service goes back to `LoadBalancer` (`<pending>` here), the fixed NodePorts become random, and
the Gateway provider switches off. ⭐ Seen Nov 4: `helm rollback` wrote **revision 3, "Rollback to 1"** — history
only grows; each revision is a Secret `sh.helm.release.v1.traefik.vN` in the release namespace. Pin `--version`
on every upgrade, or `helm repo update` can move the chart under you.
</details>

**Drilled log:** —

---

## 🔲 Backlog — write each out in full when its part is built

| Idea | Domain | Becomes real when |
|---|---|---|
| HPA on a Deployment; then the same HPA with metrics-server gone (`<unknown>`) | Workloads 15 · Troubleshooting | Ch 05 done (metrics-server is in) — **next candidate** |
| Make a StorageClass the default; static PV + PVC with a `Retain` reclaim policy and an access mode that does not match | Storage 10 | **Ready now** — the default-class half was done in Ch 05 Part 2 |
| A pod on a local-path claim stays `Pending` after its node is drained — the PV is pinned to that node (`nodeAffinity` `kubernetes.io/hostname`) | Storage 10 · Troubleshooting | **Ready now** — the pin was seen in Ch 05 Part 2; the drained-node half was not run |
| A GatewayClass that names the wrong `controllerName` while Traefik runs — fix it so the Gateway is `Programmed` (the no-controller half is X13) | Networking 20 · Troubleshooting | **Ready now** — Traefik's controller is `traefik.io/gateway-controller` |
| An Ingress with no `ingressClassName` and no controller: accepted, `Events: <none>`, blank ADDRESS — find why nothing routes | Networking 20 · Troubleshooting | **Ready now** — seen Ch 05 Part 4 step 1 (setup: scale Traefik to 0, or a class no controller owns) |
| Migrate a path-routed, TLS Ingress to `Gateway` + `HTTPRoute` by hand | Networking 20 | Ch 05 Part 4 |
| Default-deny NetworkPolicy that silently kills DNS (old T6); then allow only DNS + one app port | Networking 20 · Troubleshooting | NetworkPolicy chapter |
| etcd snapshot, then restore that brings back a deliberately deleted object | Cluster Arch 25 | etcd backup chapter |
| Two of three control planes down: reads fail, what still works (old T7) | Troubleshooting | HA drills chapter |
| Cluster down after the PVE host reboots (old T8) | Troubleshooting | HA drills chapter |
| A control-plane static pod manifest broken on **one** of three nodes — the cluster keeps working, which is the trap | Troubleshooting | HA drills chapter |
| Upgrade one control plane, then a worker, v1.35 → v1.36 | Cluster Arch 25 | upgrade chapter |
| Kernel maintenance on a control plane with etcd health checked between nodes | Cluster Arch 25 | kernel drill (due ~end Dec 2026) |
| New user by client certificate: CSR → `kubectl certificate approve` → Role + RoleBinding → `kubectl auth can-i` | Cluster Arch 25 (RBAC) | RBAC chapter |
| ServiceAccount + ClusterRole limited to one verb on one resource | Cluster Arch 25 (RBAC) | RBAC chapter |
| CoreDNS: resolve a Service across namespaces; fix a broken Corefile edit | Networking 20 · Troubleshooting | CoreDNS chapter |
| Rolling update with `maxUnavailable: 0`, a bad image, then `rollout undo` | Workloads 15 | workloads chapter |
| ConfigMap + Secret as env and as a mounted file; change one and prove which picks it up | Workloads 15 | workloads chapter |
| Taint a node, tolerate it; required node affinity; requests/limits and a LimitRange that rejects a pod | Workloads 15 | scheduling chapter |
| Sidecar container reading the main container's log file (`emptyDir`) — container output streams | Troubleshooting · Workloads | workloads chapter |
