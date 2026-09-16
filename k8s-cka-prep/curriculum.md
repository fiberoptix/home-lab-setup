# CKA curriculum — domains, weights, and what the 2025 update changed

**Researched September 16, 2026.** Marking scheme in [`README.md`](README.md).
🟢 Source of truth is the **CNCF curriculum repository** (`github.com/cncf/curriculum`), currently
**CKA_Curriculum_v1.35**, mirrored by the Linux Foundation and CNCF certification pages.

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

🔴 **CONTRADICTED — do not use these numbers:** a community post circulates a "2025–2026 reweighting" of
**25 / 12 / 22 / 10 / 31** (Workloads down to 12%, Networking up to 22%, Troubleshooting up to 31%).
**This conflicts with both official listings**, which still show 25/15/20/10/30. The same post also
states a Kubernetes version roughly two years stale. ⚠️ **Recorded here specifically so it is not
re-absorbed from a different blog in three months and mistaken for new information.**

---

## Competencies, by domain

🟢 As published, with the **Feb 18, 2025** program update folded in. Items marked 🆕 were **added or
substantially reworded** in that update.

### Cluster Architecture, Installation & Configuration — 25%
- Manage **role-based access control (RBAC)**
- 🆕 **Prepare underlying infrastructure** for installing a Kubernetes cluster
- **Create and manage** Kubernetes clusters *(kubeadm)*
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

### Services & Networking — 20%
- Define and enforce **NetworkPolicies**
- **ClusterIP, NodePort, LoadBalancer** service types
- **Ingress** controllers and Ingress resources
- **CoreDNS** / cluster DNS
- 🆕 **Gateway API** *(and its docs are on the allowed-resources list — a strong signal)*

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
