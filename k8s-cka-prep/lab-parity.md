# Lab parity — where our cluster differs from the exam machine, and what to do

**Written September 16, 2026**, answering Andrew's question: *should the nodes be built with our normal
deployment scripts, or limited to what the CKA exam system has available?*

> ⭐ **The short answer: build with our scripts, then converge the NODES toward the exam's toolset, and
> change how you WORK far more than what you install.** The scripts are proven plumbing and rebuilding
> that by hand teaches nothing. What actually creates exam realism is not a stripped package list — it
> is the SSH-into-the-host workflow, the absence of your own conveniences, and the two-hour clock.

---

## 1. What the exam's working environment actually is

Condensed from [`exam-environment.md`](exam-environment.md) — 🟢 all official:

- A desktop whose base system, **`base`, has NO tools** — not even `kubectl`.
- You **`ssh` to a designated host per task**, work there, then `exit`. **No nested SSH.**
- Hosts have **`kubectl` (with `k` alias + bash completion), `yq`, `curl`, `wget`, `man`**.
- Root via **`sudo -i`**.
- You may **install distro packages** if you need something absent.
- Kubernetes **v1.35**.

---

## 2. Recommendation, item by item

| Question | Recommendation |
|---|---|
| Use `host_setup.sh`? | ✅ **Yes — with `--server --no-nas`.** It gives SSH keys, hostname (and the `/etc/hosts` fix), passwordless sudo, timezone and CLI basics. `--server` skips Chrome/Cursor and the GNOME steps; `--no-nas` keeps NAS credentials off a cluster that has no business holding them |
| Docker Engine | ⛔ **Remove it — but only AFTER traps T1/T2 have fired.** See §3; this is the interesting one |
| Cockpit | 🟡 **Andrew's call.** Not in the exam, so it is "extra". But it is an *access method*, and a five-node cluster is exactly where a second way in earns its keep. **My lean: keep it** — it is a lab-operations tool, not a Kubernetes crutch, and it cannot teach him a bad exam habit |
| `sysbench`, shell aliases, `btop` etc. | 🟡 Harmless on the host, but ⛔ **do not add `kubectl` conveniences beyond the exam's** — no `krew`, no `kubectx`/`kubens`, no `k9s`, no custom `kgp`-style aliases. Those are genuinely good tools that will **not be there on exam day** |
| `jq` | ⛔ **Deliberately do NOT install it.** 🟢 The official tool list is **`yq`**. Practise `yq` and `kubectl -o jsonpath=`, or you will reach for a missing tool under a clock |
| `yq` | ✅ **Install it** — it is on the exam hosts, so it should be on ours |
| `k` alias + bash completion | ✅ **Configure it, to MATCH the exam** (where it is pre-set). Same reflexes, and it removes the temptation to burn exam minutes setting up something already present |
| `etcdctl` | ✅ **Needed on the control-plane nodes** for the Part 6 backup/restore drill |
| Kubernetes version | 🔻 **Build v1.35 to match the exam** — see §4, this changes the plan |

⭐ **The principle behind all of it:** anything that changes **how a task is performed** must match the
exam. Anything that only helps us **operate the lab** is free. Cockpit is lab operations; `k9s` would be
task performance.

---

## 3. The Docker question — and why the answer is "keep it, then remove it"

Our `setup_docker.sh` leaves `/etc/containerd/config.toml` with **`disabled_plugins = ["cri"]`** and no
`SystemdCgroup` setting (✅ verified on `.191`, Sep 16 2026). That is **correct for a Docker host and
fatal for a kubeadm node** — `kubeadm init` will hang on a kubelet that cannot reach a container
runtime, and the error names the kubelet, not containerd.

**This is Phase 18's planted traps T1 and T2, and it is also a real CKA skill**, since *Troubleshooting*
is 30% of the exam and *"understand extension interfaces (CNI, CSI, CRI)"* is a stated competency. A
broken CRI is about as on-syllabus as a fault gets.

✅ **So: build all five nodes with the standard script, let T1/T2 fire on the first control-plane node,
diagnose them by hand, then apply the fix as a script to the rest** (`METHOD.md`'s repetition rule —
Andrew does the first, the script does the others).

⛔ **THEN remove Docker Engine from all five and keep containerd alone**, configured for Kubernetes. Real
Kubernetes nodes do not run Docker, and leaving it invites a whole class of confusion — two image stores,
`docker ps` showing nothing useful, `crictl` and `docker` disagreeing. ⛔ **And do not "fix" the shared
`setup_docker.sh`** — hard rule B3; every other host in this lab genuinely wants CRI disabled.

---

## 4. 🔻 The version correction this research forces

The plan currently says **build v1.36.4, upgrade to v1.37.0**. 🟢 **The exam runs v1.35.** Practising on
a version two minors ahead of the exam is the wrong trade.

✅ **Revised: build the current v1.35 patch, and make the Part 6 upgrade drill v1.35 → v1.36.** This is
strictly better than the original:
- **Daily practice happens on the version the exam uses.**
- The upgrade drill still has a real destination, and it now mirrors the actual exam competency
  *"manage the lifecycle of Kubernetes clusters"* — upgrading **from** the version under test.
- ⚠️ The exam tracks the newest minor within ~4–8 weeks, so **re-check before booking**; if it has moved
  to v1.36 by then, the cluster is already one upgrade away from parity, which is the point.

---

## 5. ⭐ The changes that matter more than any package list

**These cost nothing and do more for exam readiness than trimming software.**

1. 🚨 **Work ON the node, never from the workstation.** The exam's `base` has no `kubectl` at all. If he
   practises with a kubeconfig on `.195` and `kubectl` in his own shell, he is training a workflow the
   exam does not permit. ✅ **Keep no kubeconfig on the dev box. `ssh` to a node, work, `exit`.**
2. 🚨 **Practise the `exit` discipline and no nested SSH.** Get used to hopping out to a jump point
   between tasks rather than moving sideways between nodes.
3. ⚠️ **Type the YAML; do not paste it.** 🟡 The exam clipboard reportedly does not share with the local
   machine. **`kubectl create ... --dry-run=client -o yaml` needs to be reflex, not a lookup.**
4. ⏱️ **Practise against a clock.** 15–20 tasks in 120 minutes is roughly **6–8 minutes each**. Time
   pressure is a distinct skill from correctness and the lab is where to meet it.
5. 📖 **Restrict yourself to the allowed docs while practising** — `kubernetes.io/docs`, the blog,
   `helm.sh/docs`, Gateway API. No Stack Overflow, no AI assistant, no blog posts. **Practising with
   help you will not have inflates your sense of readiness**, which is the same false-green problem this
   project keeps finding everywhere else.

---

## 6. ⛔ Known parity gaps our lab CANNOT close

Stated honestly, in the same spirit as *"three VMs on one host is node failure, not host failure."*

| Gap | Consequence |
|---|---|
| 🚨 **The exam has MULTIPLE clusters; we have ONE.** 🟡 The most-reported mistake is forgetting `kubectl config use-context` | **Our cluster cannot train the single most common failure.** Partial mitigations: define several kubeconfig contexts (different users/namespaces) against the one cluster so switching is still a habit, and rely on the Killer.sh simulator for the real multi-cluster experience |
| **No PSI secure browser, no proctor, no remote-desktop lag** | 🟢 The Linux Foundation acknowledges lag as a trade-off of remote delivery. The simulator is the only realistic exposure |
| **Five nodes on one host** | Genuine member/node failure drills; **not** host or site failure |
| **The exam's task infobox and Quick Reference links** | Cannot be reproduced; the simulator has them |

⭐ **This is what the two included Killer.sh attempts are for** (🟢 two attempts, 36 hours of access
each, 17 questions per session). **Spend them deliberately** — they are the only genuine exam-shaped
rehearsal available, and the lab should be used to get *good* before either attempt is opened, not to
discover basics during one. ⚠️ **`CKA-SINGLE` registrations get no simulator at all** — see Q2 in
[`README.md`](README.md).
