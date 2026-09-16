# CKA logistics — time, scoring, retakes, simulator

**Researched September 16, 2026.** Marking scheme in [`README.md`](README.md).

| Item | Value | Mark |
|---|---|---|
| **Duration** | **2 hours (120 minutes)** | 🟢 Linux Foundation FAQ + exam page |
| **Pass mark** | **66% or above** *(CKAD also 66%; CKS is 67%)* | 🟢 Linux Foundation FAQ |
| **Format** | Online, **proctored, performance-based**. **No multiple choice at all** | 🟢 |
| **Number of tasks** | **~15–20** hands-on tasks | 🟡 community; 🟢 confirms only that it is "multiple tasks". The **17 questions** figure is officially stated **for the Killer.sh simulator**, not the live exam |
| **Kubernetes version** | **v1.35** | 🟢 |
| **Certification validity** | **2 years** | 🟢 |
| **Eligibility window** | **12 months** to schedule and sit from purchase | 🟢 |
| **Retake** | **One retake** included on a standard purchase, *"regardless of why"* you did not pass; must be used within 12 months of purchase. ⛔ **`SINGLE-ATTEMPT`/`SINGLE` purchases and SkillCred get ONE attempt only** | 🟢 retake policy |
| **Results** | Emailed **within 24 hours** | 🟡 community |
| **Renewal** | Retake and pass **before** the expiry date; the renewal runs 2 years from the pass date | 🟢 |
| **Proctoring** | PSI Bridge, PSI Secure Browser, with **audio, video and screen monitoring**; strict environment requirements | 🟢 platform / 🟡 the "strict" characterisation |

---

## ⏱️ What the numbers imply, which is the only reason to write them down

- **15–20 tasks in 120 minutes ≈ 6–8 minutes per task.** Practice sessions in the lab should be timed
  against that, because correctness and speed are separate skills and only one of them is fun to train.
- **66% is a high floor for a two-hour hands-on exam.** 🟡 One guide puts it bluntly: you cannot afford
  to leave a third of it untouched. ⭐ **The tactical consequence is triage** — read everything, do the
  cheap ones first, and **never let one hard task eat fifteen minutes** while three easy ones go unread.
- **Troubleshooting is 30% of the marks** (see [`curriculum.md`](curriculum.md)) — and troubleshooting
  tasks are exactly the ones with unbounded time risk. Deciding *in advance* when to abandon a task and
  come back is itself a technique to practise.

---

## The included simulator (Killer.sh)

🟢 Registration includes **two simulator attempts**, each granting **36 hours of access** from
activation, with **17 questions per session** and a **different question set** each time. Results are
**graded**. The link lives in the *Preparing for the Exam* section of the Exam Preparation Checklist.

⛔ 🟢 **Not included with `CKA-SINGLE`, `CKAD-SINGLE` or `CKS-SINGLE` registrations.**

⭐ **Treat the two attempts as scarce, because they are.** They are the only exam-shaped rehearsal that
exists — real interface, real time pressure, real grading, multiple clusters. **Get competent in the lab
first**; opening an attempt to discover you are shaky on `kubeadm upgrade` wastes the most valuable
practice asset in the whole registration. See [`lab-parity.md`](lab-parity.md) §6 for what only the
simulator can teach.
