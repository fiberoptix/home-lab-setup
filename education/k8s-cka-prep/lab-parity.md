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
| Cockpit | ✅ **DECIDED Sep 16 — keep it.** Not in the exam, so it is "extra", but it is an *access method* and a five-node cluster is exactly where a second way in earns its keep. It is a lab-operations tool, not a Kubernetes crutch, so it cannot teach a bad exam habit. ⚠️ Chapter 01 marks it as **ours, not required** |
| `sysbench`, shell aliases, `btop` etc. | 🟡 Harmless on the host, but ⛔ **do not add `kubectl` conveniences beyond the exam's** — no `krew`, no `kubectx`/`kubens`, no `k9s`, no custom `kgp`-style aliases. Those are genuinely good tools that will **not be there on exam day** |
| `jq` | ⛔ **Deliberately do NOT install it.** 🟢 The official tool list is **`yq`**. Practise `yq` and `kubectl -o jsonpath=`, or you will reach for a missing tool under a clock |
| `yq` | ✅ **Install it** — it is on the exam hosts, so it should be on ours |
| `crictl` | ✅ **DECIDED Sep 17, 2026 — install it** (`cri-tools`, from the `pkgs.k8s.io` minor repo so it version-matches). ⚠️ Exam presence **unverified** — 🟢 the official list omits it, 🟡 one blog says it is there. ⭐ **The decision does not depend on the answer:** with Docker removed there is otherwise **no way to inspect a container on a node**, and 🟢 kubernetes.io's own troubleshooting pages — the only docs allowed in the exam — use it. It also passes §2's principle in the right direction: it does not change how a *Kubernetes* task is performed, it is the only window into the layer **below** Kubernetes. 🚨 `/etc/crictl.yaml` is required — current `crictl` has no default-endpoint fallback |
| `k` alias + bash completion | ✅ **Configure it, to MATCH the exam** (where it is pre-set). Same reflexes, and it removes the temptation to burn exam minutes setting up something already present |
| `etcdctl` | ✅ **Needed on the control-plane nodes** for the etcd backup/restore drill (⚠️ that was "Part 6" before the plan was restructured into stages — it is **Stage 3** now) |
| Kubernetes version | 🔻 **Build v1.35 to match the exam** — see §4, this changes the plan |

⭐ **The principle behind all of it:** anything that changes **how a task is performed** must match the
exam. Anything that only helps us **operate the lab** is free. Cockpit is lab operations; `k9s` would be
task performance.

---

## 3. The Docker question — 🔻 RESOLVED DIFFERENTLY THAN PLANNED, and the reason matters

Our `setup_docker.sh` leaves `/etc/containerd/config.toml` with **`disabled_plugins = ["cri"]`** and no
`SystemdCgroup` setting (✅ verified on `.191`, Sep 16 2026). That is **correct for a Docker host and
fatal for a kubeadm node** — `kubeadm init` will hang on a kubelet that cannot reach a container
runtime, and the error names the kubelet, not containerd.

**A broken CRI is about as on-syllabus as a fault gets**, since *Troubleshooting* is 30% of the exam
and *"understand extension interfaces (CNI, CSI, CRI)"* is a stated competency.

🔻 **CORRECTED Sep 17, 2026 — the plan this section described is DEAD, for two independent reasons,
and both are worth knowing because the section survived a day looking current:**

1. ⛔ **All planted traps were WITHDRAWN** at Andrew's instruction — see
   `phases/phase18_k8s_cka_build.md` §8. Nothing is left broken on purpose during Stages 0 and 1, so
   "let T1/T2 fire" is no longer an instruction anyone may follow.
2. ✅ **Measurement overturned the premise.** The template ships **neither Docker nor containerd**, so
   there was never anything to subtract. `containerd.io` is installed **alone** and configured for
   Kubernetes from the outset.

⭐ **So the node never has Docker at any point, which is better than installing it and undoing it:**
nothing to subtract if you never add it, and no residue from a removal. ⛔ **And still do not "fix"
the shared `setup_docker.sh`** — hard rule B3; every other host in this lab genuinely wants CRI
disabled.

⚠️ **The consequence that survives, and it looks like the opposite of itself:
`/etc/apt/sources.list.d/docker.list` is still REQUIRED on these nodes**, because `containerd.io`
ships from Docker's repository. It reads as residue on a Docker-free host, and removing it breaks the
runtime's upgrade path (hard rule B8).

---

## 4. 🔻 The version correction this research forces

🔻 **Written while the plan still said build v1.36.4 and upgrade to v1.37.0. It no longer does — this
research is WHY it changed, and the plan was corrected the same day (Sep 16, 2026).** 🟢 **The exam
runs v1.35.** Practising on a version two minors ahead of the exam is the wrong trade.

✅ **Revised: build the current v1.35 patch, and make the upgrade drill v1.35 → v1.36** (Stage 3 in
the restructured plan; it was "Part 6" when this was written). This is
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

🔻 **RESOLVED Sep 16, 2026 — and it changes the strategy, so do not follow older advice here.**
🙋 **Andrew: "I WILL take the killer.sh tests ($39 each) as many times as necessary."** 🟢 Two attempts come
with a standard registration; beyond that, sessions are **purchasable**, so exam-shaped rehearsal is
effectively **unlimited** rather than a scarce resource.

⭐ **What that changes: the simulator becomes a FEEDBACK LOOP, not a final exam.** The earlier plan here was
"hoard the two attempts, get good in the lab first". With unlimited sessions the better pattern is the
reverse — **sit one early to find out what you are actually bad at**, then bring those specific weaknesses
back to the lab where they can be drilled against a snapshot for free, and re-sit. **The lab is the cheap
place to repeat; the simulator is the accurate place to measure.** ⭐ Each session runs **36 hours** and is
graded, so one purchase supports a long working session, not a single sitting.

✅ **It also retires the worst parity gap.** Multi-cluster context switching, the PSI interface and time
pressure under an unfamiliar UI **do not need to be simulated in the lab at all** — the simulator provides
them accurately and repeatably. ⛔ **So do not build synthetic multi-context kubeconfigs to fake it**; that
was a workaround for a scarcity that no longer exists.
⚠️ 🟡 **Community consensus is that Killer.sh is HARDER than the real exam.** Unverified here, and worth
knowing before a low score is read as "not ready" — see the gaps list in [`sources.md`](sources.md).
