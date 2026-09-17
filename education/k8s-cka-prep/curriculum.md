# CKA curriculum — domains, weights, and what the 2025 update changed

**Researched September 16, 2026.** Marking scheme in [`README.md`](README.md).

✅ **READ FROM THE PRIMARY SOURCE, 3:33 PM Sep 16, 2026** — not from summaries. `CKA_Curriculum_v1.35.pdf`
pulled from `github.com/cncf/curriculum`, **169,029 bytes, 3 pages,
sha256 `634b7937…78ec18c`**. Reproduce with:
`curl -sSLO https://raw.githubusercontent.com/cncf/curriculum/master/CKA_Curriculum_v1.35.pdf`
(a copy sits in this track's gitignored `scratch/`; ⚠️ **a fresh clone will not have it** — use the URL).

⭐ **The read CONFIRMED every domain and weight compiled earlier from the web summaries, and added four
pieces of precision the summaries had dropped.** All four are recorded in place below and flagged 📄.
⚠️ **It also settled a naming detail:** the PDF calls the 20% domain **"Servicing and Networking"**, while
CNCF's web page calls it *"Services & Networking"*. **The PDF's wording is the specification's.**
📌 **What the PDF does NOT contain, so it cannot be inferred from it:** anything about task count, task
phrasing, partial credit, or whether tasks chain several steps together (Q3). It is a one-page
capability list, terse by design — **the specification of WHAT is tested, not HOW it is asked.**

---

## The five domains

🟢 **Confirmed identically by the Linux Foundation and CNCF:**

| Domain | Weight |
|---|---|
| **Troubleshooting** | **30%** |
| **Cluster Architecture, Installation & Configuration** | **25%** |
| **Services & Networking** | **20%** |
| **Workloads & Scheduling** | **15%** |
| **Storage** | **10%** |

⭐ **Troubleshooting is the largest single domain at 30%, and it cannot be revised for — only
practised.** Combined with Cluster Architecture, **more than half the exam (55%)** is about operating
and repairing a cluster rather than authoring manifests. That is the argument for Phase 18 weighting
*breaking things* above *building things*.

🔴 **CONTRADICTED — settled against the PRIMARY SOURCE now, not just against two web pages:** a community
post circulates a "2025–2026 reweighting" of **25 / 12 / 22 / 10 / 31** (Workloads down to 12%, Networking
up to 22%, Troubleshooting up to 31%). ⛔ **The CNCF curriculum PDF itself prints 10% Storage, 30%
Troubleshooting, 15% Workloads and Scheduling, 25% Cluster Architecture, 20% Servicing and Networking.**
The claim is simply false. The same post also
states a Kubernetes version roughly two years stale. ⚠️ **Recorded here specifically so it is not
re-absorbed from a different blog in three months and mistaken for new information.**

---

## Competencies, by domain

🟢 As published, with the **Feb 18, 2025** program update folded in. Items marked 🆕 were **added or
substantially reworded** in that update.

### Cluster Architecture, Installation & Configuration — 25%
- Manage **role-based access control (RBAC)**
- 🆕 **Prepare underlying infrastructure** for installing a Kubernetes cluster
- 📄 **Create and manage Kubernetes clusters USING `kubeadm`** — ⭐ **the specification names the tool
  explicitly.** The web summaries said only "create and manage Kubernetes clusters". **This is direct
  confirmation of Phase 18's central build decision** and of why Phase 14's k3s does not substitute
- 🆕 **Manage the lifecycle** of Kubernetes clusters *(upgrades)*
- 🆕 Implement and configure a **highly-available control plane**
- 🆕 Use **Helm and Kustomize** to install cluster components
- 🆕 Understand **extension interfaces** — **CNI, CSI, CRI**
- 🆕 Understand **CRDs**, install and configure **operators**

### Troubleshooting — 30%
- Troubleshoot **clusters and nodes**
- Troubleshoot **cluster components**
- **Monitor** cluster and application resource usage
- Manage and evaluate **container output streams**
- Troubleshoot **services and networking**

### Servicing and Networking — 20%   *(the PDF's own name for this domain)*
- 📄 **Understand connectivity between Pods** — ⚠️ **this competency was MISSING from the earlier
  compilation entirely.** It is the CNI's job, so it is covered by installing Calico *and* by being able
  to test pod-to-pod reachability deliberately
- Define and enforce **Network Policies**
- **ClusterIP, NodePort, LoadBalancer** service types 📄 **and endpoints** — the "and endpoints" is new
  precision: **Endpoints/EndpointSlices are examinable**, which is exactly the object that explains a
  Service that resolves but routes nowhere
- 📄 **Use the Gateway API to manage Ingress traffic** — the summaries listed "Gateway API" loosely; the
  spec frames it **as the mechanism for ingress traffic**, alongside (not instead of) Ingress resources
- Know how to use **Ingress controllers and Ingress resources**
- **Understand and use CoreDNS**

### Workloads & Scheduling — 15%
- Application **deployments**, **rolling updates and rollbacks**
- **ConfigMaps and Secrets** to configure applications
- 🆕 Configure **workload autoscaling** *(HPA)*
- Primitives for **robust, self-healing** deployments
- Configure **Pod admission and scheduling** — limits, node affinity

### Storage — 10%
- **StorageClasses** and **dynamic volume provisioning**
- **Volume types, access modes, reclaim policies**
- Manage **PersistentVolumes and PersistentVolumeClaims**

---

## 🚨 What this list means for Phase 18 as currently planned

🔻 **THIS SECTION WAS THE PRE-RESTRUCTURE GAP ANALYSIS AND IT READ AS CURRENT FOR A DAY — rewritten
Sep 17, 2026.** It cited *"Parts 2, 3, 6"* and *"traps T1/T2/T5/T7"*: ⛔ **the parts were renumbered
into Stages 0–3 and every planted trap was WITHDRAWN**, and it marked six areas ⛔ *NOT in the plan*
that the phase file's **A8** row had already moved into **Stage 3**. 🚨 **This is the worst possible
file for that error, because the plan names THIS FILE as what drives Stage 3's coverage.** ⭐ **A gap
analysis is a snapshot of a plan, so it expires when the plan changes — and nothing in its wording
says so.**

### What covers what, against the CURRENT four-stage plan

| Curriculum area | Where it is covered |
|---|---|
| HA control plane, kubeadm install | ✅ **Stages 0–1** — the plan's spine, chapters 01–04 |
| Cluster lifecycle / upgrade | ✅ **Stage 3** — the v1.35 → v1.36 drill, plus planned kernel maintenance (drain → patch → reboot → uncordon) |
| Troubleshooting (**30%**) | ✅ **Stage 3 is built around it** — named, repeatable exercises rather than one-shot traps. ⭐ The restructure is what fixed this; 30% cannot be covered incidentally |
| RBAC | 🔲 **Stage 3** |
| NetworkPolicy, CoreDNS | 🔲 **Stage 3**, enforced by Calico — which was chosen for exactly this |
| Extension interfaces (CNI/CSI/CRI) | 🟡 **CNI and CRI are hit hard by construction** — CNI installed by hand in Stage 1, CRI configured by hand in Stage 0, `crictl` on every node since Sep 17. ⛔ **CSI still needs a provisioner — see the equipping chapter below** |
| Storage — StorageClasses, dynamic provisioning, PV/PVC | 🔲 **Stage 3, and it needs a PROVISIONER installed first** |
| Helm and Kustomize | 🔲 **Stage 3.** ⭐ Helm's docs being exam-allowed is itself the signal that it is expected |
| CRDs and operators | 🔲 **Stage 3 — and nearly free:** installing the Gateway API CRDs *is* a CRD exercise |
| **Gateway API** | 🔲 **Stage 3 — and it is the one NOBODY ELSE covers. See the plan below** |
| Workload autoscaling (HPA) | 🔲 **Stage 3, and it needs `metrics-server` first** — an HPA with no metrics reports `<unknown>` and scales nothing |
| Ingress | 🔲 **Stage 3, and it needs an ingress controller first** |
| Scheduling — affinity, limits, admission | 🔲 **Stage 3** |

### ⭐ The five remaining gaps are ONE gap, and naming it is how we close them

🚨 **Every outstanding item needs something installed that `kubeadm` does not give you.** Gateway API
needs CRDs **and** a controller. HPA needs `metrics-server`. Dynamic provisioning needs a StorageClass
with a real provisioner. Ingress needs an ingress controller. ⭐ **We have already met this pattern
once, and it is the best-understood thing in the whole build: Kubernetes ships no pod network, which
is why Stage 1 installs Calico by hand.** The rest are the same shape.

✅ **So they become ONE Stage 3 chapter, placed FIRST in the stage: *what a bare kubeadm cluster cannot
do, and what you install to fix it*.** It closes five rows above under one theme, it **is** the
*"understand extension interfaces (CNI, CSI, CRI)"* competency, and ⭐ **it is the closest thing in this
phase to the actual job** — on a brownfield platform the interesting question is always what the
cluster is missing.

⚠️ **What the exam tests here, stated precisely so we do not over-build:** 🟢 the exam hands you a
cluster that **already has** these components, so *installing* them is not what is marked. **What is
marked is writing the objects correctly — and what saves you is recognising the symptom when a
component is absent.** An HPA stuck at `<unknown>`, a PVC stuck `Pending`, a Gateway with no address:
each is a missing-component signature, and reading those is Troubleshooting, the 30% domain.

### 🔲 Gateway API — the concrete plan (decided Sep 17, 2026)

🚨 **Gateway API is NOT part of Kubernetes**, which is the first thing to know and the reason it is so
easy to leave uncovered. It is **(a) a set of CRDs** — `GatewayClass`, `Gateway`, `HTTPRoute` — applied
from the `gateway-api` project's release manifest, and **(b) a controller** that implements them.
⭐ **Without (b) the objects apply cleanly and do nothing**, which is worth seeing once: it is the
difference between valid YAML and working routing.

**Steps, in order, each with what it proves:**

1. **Apply the Gateway API standard CRDs.** ✅ Confirm with `kubectl api-resources | grep gateway`.
   ⭐ **This doubles as the CRD competency** — a real CRD install rather than a toy one.
2. **Create a `Gateway` and an `HTTPRoute` with NO controller running.** ⭐ **Deliberately, before
   installing one.** The objects are accepted and the Gateway never gets an address — **"prove the
   negative before you build the positive" applied to a syllabus topic.**
3. **Install a controller.** 🔲 **Candidate: NGINX Gateway Fabric or Envoy Gateway — NOT DECIDED and
   not to be guessed.** ⚠️ Newer Calico versions are *reported* to ship an optional Gateway API
   implementation; **that is unverified here and must be checked against the Calico version we
   actually install** before it is written down as an option.
4. 🚨 **Solve the EXPOSURE problem — the real lab constraint.** A Gateway's controller wants a
   `Service` of type `LoadBalancer`, and **this cluster has no LoadBalancer implementation**, so it
   sits `<pending>` and the Gateway gets no address. ✅ **Use `NodePort` first** — it separates *"does
   my HTTPRoute match?"* from *"do I have a load balancer?"*, which is one-instrument-per-question.
   ⭐ **Then upgrade it with the deferred kube-vip `--services` + cloud-provider exercise**, which
   makes that exercise a **prerequisite** for this one rather than an optional extra.
5. **Run the drill the community consistently reports as the fumble:** path-route an `Ingress` to two
   backends, terminate TLS on it, **then reproduce the same routing with `Gateway` + `HTTPRoute`.**
   ⭐ **Both models are on the syllabus and a task can ask for either**, so the skill being trained is
   recognising which one is being requested.

⚠️ **SNAPSHOT CONSEQUENCE — a decision, not bookkeeping.** These installs are cluster-wide, so they
must **NOT** land inside `c02-virgin-cluster`. **Two baselines are required:** `c02-virgin-cluster` (a
bare kubeadm cluster — what the exam's *architecture* tasks resemble) and a later
`c03-equipped-cluster` (metrics-server, a storage provisioner, ingress + Gateway API — what its
*workload* tasks resemble). ⭐ **Rolling back to the wrong one silently changes what an exercise is
testing**, which is the quietest way to waste a drill.

### 🚨 Why Gateway API specifically will be missed unless it is planned

**Three independent signals, Sep 17, 2026, and they agree:**
- 🟡 **The standard Udemy/KodeKloud CKA course does not appear to cover it.** Its published update
  history added **Helm Basics** and **Kustomize Basics** in Jan 2025 for the Feb 2025 revision, and
  its section list has **no Gateway API section**.
- 🟡 **A 2026 post-revision exam report** states the newly-added topics were *about half* the exam,
  names Gateway API among the areas candidates struggle with, and says Udemy + Killer.sh alone was
  **not** sufficient.
- 🟡 **A third source** calls it *"relatively new and less documented"* and lists *"Gateway API
  variations you didn't memorize"* among exam-day surprises.

⛔ **And 🟢 puts it beyond argument: the Gateway API docs are on the ALLOWED-RESOURCES list, and they
are allowed for the CKA only.** ⭐ **A certification does not grant access to a documentation site for
a topic it does not test.** That is the strongest available evidence and it is official.
