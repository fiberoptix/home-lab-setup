# CKA Preparation — research, environment notes, and practice material

**Purpose:** everything needed to pass the **Certified Kubernetes Administrator** exam and to onboard
onto the new job's Kubernetes platform. This folder is the **prep and research** shelf; the **build**
it practises on is Phase 18 (`../phases/phase18_k8s_cka_build.md`), and the **printable study
chapters** will live in `../education/k8s-cka/`.

**Created:** September 16, 2026. Expected to grow considerably.

---

## Status and chapters

**Status:** 🔲 **No chapters written yet.** The phase plan is drafted and awaiting Andrew's review;
this folder currently holds **research only**. Working record: `../../phases/phase18_k8s_cka_build.md`.

⚠️ **This track is unusual on the shelf and it is deliberate:** it holds **prep research *and* the
chapters**, because the exam research is not a by-product of the build — it *directs* the build. Andrew
consolidated them on Sep 16, 2026 rather than keeping `k8s-cka-prep/` apart from an `education/k8s-cka/`.

| Chapter | Subject | Stage | Status |
|---|---|---|---|
| 01 | **Portable node prep** — given a fresh Ubuntu host, what makes it a Kubernetes node (containerd/CRI, cgroup driver, swap, modules, sysctls, pinning). ⭐ Written to be repeatable where there is no template 9000 and no script server | 0 (work) | 🔲 Planned |
| 02–04 | Installing and configuring Kubernetes piece by piece: kube-vip, `kubeadm init`, CNI, joining an HA control plane, joining workers | 1 (work) | 🔲 Planned |
| 05+ | One CKA administrative task type per chapter, weighted by the exam's own domain weights | 3 (exam) | 🔲 Planned |

⭐ **Stages 0 and 1 are written as procedures to repeat at work. Stage 3 is exam drilling.** The split is
the whole design of the phase — see the plan's §6.

---

## Which file answers what

| File | Holds |
|---|---|
| [`exam-environment.md`](exam-environment.md) | ⭐ **What the exam machine is actually like** — the desktop, the terminal, the SSH model, which tools are pre-installed, what you may open in the browser. **The single most useful file for making the lab feel like the exam.** |
| [`curriculum.md`](curriculum.md) | The five domains, their weights, the competency list, and what the Feb 2025 update added |
| [`logistics.md`](logistics.md) | Duration, pass mark, retakes, the included simulator, validity, results turnaround |
| [`lab-parity.md`](lab-parity.md) | ⭐ **Where our home lab differs from the exam environment, and what to do about each difference.** This is what turns a cluster into practice |
| [`sources.md`](sources.md) | Every source, marked by authority — and the **contradictions found between them**, which matter more than the agreements |

---

## 🚦 How claims in this folder are marked

The same discipline the education tracks use, because prep material assembled from blogs is exactly
where a confident wrong fact does the most damage — you will act on it under time pressure.

| Mark | Meaning |
|---|---|
| 🟢 **OFFICIAL** | Stated by the Linux Foundation or CNCF — `docs.linuxfoundation.org`, `training.linuxfoundation.org`, `cncf.io`, or the CNCF curriculum repo. **Treat as authoritative.** |
| 🟡 **COMMUNITY** | From a blog, guide or course. Often correct, occasionally stale, **never** a reason to doubt a 🟢 claim. |
| 🔴 **CONTRADICTED** | A community claim that **conflicts with an official source.** Recorded on purpose, with the conflict named, so it is not silently re-absorbed from another blog later. |
| 🔲 **UNVERIFIED** | Nobody has confirmed it and it matters. Do not repeat it as fact. |

⭐ **Marking is not ceremony here.** The first research pass found a widely-circulated blog claiming
reweighted domains (25/12/22/10/31) and a Kubernetes version two years stale. Both are wrong against
the official listing. **An unmarked compilation would have laundered them into our own notes.**

---

## ⚠️ A boundary this folder will not cross

🚨 **No actual exam questions, dumps, or recalled task text — ever.** The Linux Foundation's Global
Certification and Confidentiality Agreement covers exam content, and material circulating as "the real
2025/2026 CKA questions" is generally a breach of it. **Possessing or using it can invalidate a
certification**, which for a credential being used to onboard into a regulated financial institution is
a disproportionate risk for a small time saving.

✅ **What goes here instead, all of it legitimate and most of it more useful:** the official curriculum
and its competency list (CNCF publishes it deliberately), the officially documented exam environment,
the **Killer.sh simulator that comes with the registration**, official docs, and community *study
guidance about topics and technique*. ⭐ The curriculum is a better guide than any leaked question set:
it is what the questions are generated **from**.

---

## 🔲 Open questions — things that still need answering

| # | Question | Why it matters |
|---|---|---|
| **Q1** | **Has Andrew booked an exam date, and which Kubernetes version will be live then?** | The environment tracks the latest minor within ~4–8 weeks of release. It is **v1.35** today; a booking a few months out may sit on v1.36 or later, which changes what we build. |
| **Q2** | Is the registration a standard one or a `CKA-SINGLE`? | 🟢 **`-SINGLE` registrations get NO simulator access and no retake.** That materially changes the practice plan. |
| **Q3** | Task-shape research is **incomplete** — the second search attempt failed. | We know the domains and the weights but have not yet gathered *published* guidance on how tasks are phrased or timed. |
| **Q4** | Does the exam's `k` alias and completion come pre-set on every host, or only some? | 🟢 says pre-installed and pre-configured on all SSH hosts. Worth confirming inside the simulator, since setting it up manually costs exam minutes if it was already there. |
