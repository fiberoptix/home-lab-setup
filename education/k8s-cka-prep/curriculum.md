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

**The plan covers the cluster-building half well and under-covers the rest.** Written down here so it is
fixed before building rather than discovered at chapter-writing time.

| Curriculum area | Phase 18 plan covers it? |
|---|---|
| HA control plane, kubeadm install, lifecycle/upgrade | ✅ Parts 2, 3, 6 — this is the plan's spine |
| Troubleshooting (**30%!**) | 🟡 **Partly** — Part 5's drills and traps T1/T2/T5/T7 are genuine troubleshooting, but 30% deserves more deliberate coverage |
| RBAC | ✅ Part 7 |
| NetworkPolicy, CoreDNS | ✅ Part 5 (trap T6) and Calico |
| **Extension interfaces (CNI/CSI/CRI)** | 🟡 CNI and CRI are hit hard by construction (Calico, and traps T1/T2 are *literally* a CRI misconfiguration). **CSI is not covered at all.** |
| **Storage — StorageClasses, dynamic provisioning, PV/PVC** | ⛔ **NOT in the plan.** 10% of the exam and zero coverage |
| **Helm and Kustomize** | ⛔ **NOT in the plan.** Newly added competency, and Helm's docs are exam-allowed |
| **CRDs and operators** | ⛔ **NOT in the plan** |
| **Gateway API** | ⛔ **NOT in the plan.** Newly added, and CKA-only among the allowed docs |
| **Workload autoscaling (HPA)** | ⛔ **NOT in the plan** |
| Ingress | ⛔ **NOT in the plan** |
| Scheduling — affinity, limits, admission | 🟡 Only incidentally, via the drain/PDB drill |

⭐ **The plan is a strong *infrastructure* phase and an incomplete *exam* phase**, which makes sense —
it was written from the lab's perspective before this research existed. **The gap is a decision for
Andrew, not a defect to quietly patch:** the missing items are mostly *workload-level* topics that need
a working cluster and very little infrastructure, so they fit naturally as **additional parts after the
cluster exists**, or as a **second phase**. Recorded as **A8** in the phase file.
