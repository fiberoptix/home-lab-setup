# Sources, and the disagreements between them

**First research pass: September 16, 2026.** Marking scheme in [`README.md`](README.md).
⭐ **The disagreements are the most valuable part of this file.** Agreement between sources is cheap;
knowing which source loses a conflict is what makes the notes usable under time pressure.

---

## 🟢 Official — authoritative

| Source | Used for |
|---|---|
| [LF exam tips — CKA & CKAD](https://docs.linuxfoundation.org/tc-docs/certification/tips-cka-and-ckad) | ⭐ **The best single source found.** The SSH-per-task model, `base` hostname, no nested SSH, `sudo -i`, the pre-installed tool list (`kubectl`+`k`+completion, `yq`, `curl`, `wget`, `man`), terminal copy/paste keys, and the **v1.35** environment version with the 4–8 week alignment policy |
| [LF handbook — performance-based exam UI](https://docs.linuxfoundation.org/tc-docs/certification/lf-handbook2/exam-user-interface/examui-performance-based-exams) | The remote desktop, terminal emulator, **VSCodium** (extensions prohibited), Firefox, virtual keyboard, translate extension, ReadMe tab |
| [LF — resources allowed](https://docs.linuxfoundation.org/tc-docs/certification/certification-resources-allowed) | Allowed docs: k8s docs + blog, **helm.sh/docs**, **Gateway API (CKA only)**, task Quick Reference links; search-but-don't-leave rule; distro packages may be installed |
| [LF — CKA exam page](https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/) | 2 hours, 2-year validity, 12-month eligibility, one retake, **software version v1.35**, simulator: 2 attempts × 36 h × 17 questions |
| [LF — CKA/CKAD/CKS FAQ](https://docs.linuxfoundation.org/tc-docs/certification/faq-cka-ckad-cks.md) | **66% pass mark**, renewal rules, simulator access, ⛔ `-SINGLE` excluded from simulator, remote-desktop lag acknowledged |
| [LF — exam retake policy](https://training.linuxfoundation.org/about/policies-2-2026/certification-exam-retake-policy/) | One retake per purchase, 12-month window, SINGLE/SkillCred exclusions |
| [LF — CKA program changes (Feb 18, 2025)](https://training.linuxfoundation.org/certified-kubernetes-administrator-cka-program-changes/) | ⭐ **The competency changes**: HA control plane, Helm + Kustomize, CRDs/operators, CNI/CSI/CRI, cluster lifecycle, autoscaling. Domains **unchanged** |
| [CNCF — CKA](https://www.cncf.io/training/certification/cka/) | Domain weights **25/15/20/10/30**, quarterly updates tracking Kubernetes releases |
| [CNCF curriculum repo](https://github.com/cncf/curriculum) | `CKA_Curriculum_v1.35.pdf` — the actual document the exam is built from |

## 🟡 Community — useful, unconfirmed

| Source | Used for | Caution |
|---|---|---|
| [ExamCert — CKA exam day tips 2026](https://www.examcert.app/blog/cka-exam-day-tips-2026/) | Single-pane terminal / no `tmux`; **multiple clusters and the `use-context` mistake**; no clipboard sharing; no `krew`; suggested bookmarks; triage advice | ⚠️ Claims **`jq` and `crictl`** are pre-installed — **not in the official list**. Also advises setting up the `k` alias, which 🟢 says is already configured. Neither is dangerous, but neither is fact |
| [techiescamp — CKA certification guide](https://github.com/techiescamp/cka-certification-guide) | Domain-by-domain study notes; agrees with 🟢 on weights and v1.35 | Community study notes; useful structure, verify specifics |
| [everyexamprep — CKA 2026](https://www.everyexamprep.com/exams/cka) | **15–20 tasks**, results within 24 h, proctoring description | Agrees with 🟢 on duration, pass mark and v1.35 |
| [**Udemy — CKA with Practice Tests**, Mumshad Mannambeth / KodeKloud](https://www.udemy.com/course/certified-kubernetes-administrator-with-practice-tests/) | ✅ **Andrew enrolled Sep 17, 2026, at his new boss's suggestion.** The standard recommendation in nearly every pass report; **last updated 8/2026**; lectures + KodeKloud browser labs + mock exams. Used for **concepts and orientation ahead of each stage**, and its mock exams are sanctioned practice (plan §6) | 🚨 **ENROLLED WITH A KNOWN GAP, and Andrew's standing instruction is that we still cover everything in the CNCF curriculum regardless of the course:** its update history adds **Helm** and **Kustomize** (Jan 2025) but shows **no Gateway API section**, and its section list has none. ⚠️ Its lab environment was last published as **v1.33** while the exam and our cluster are **v1.35**. ⚠️ Its *Design and Install a Kubernetes Cluster* sections teach a simpler install than our HA build — **when the course and the upstream docs disagree, upstream wins for our build** |
| [DEV — CKA exam report 2026 (post-2025 revision)](https://dev.to/suzuki0430/cka-certified-kubernetes-administrator-exam-report-2026-dont-rely-on-old-guides-mastering-the-534m) | ⭐ **The most useful community source found in the second pass.** States the newly-added topics were **about half** the exam and names the weak areas: **Helm, Kustomize, Gateway API, NetworkPolicy, CRDs, extension interfaces.** Also reports tasks that COMBINE topics (Helm + CRD, Ingress → Gateway + HTTPRoute migration) | 🟡 One candidate's experience, and it says Udemy + Killer.sh alone was **not** enough — he credits KodeKloud's extra labs. ⚠️ Treat the "half the exam" figure as an impression, not a measurement. ⛔ Contains no verbatim task text, which is why it is citable here |

## 🔴 Contradicted — recorded so it is not re-absorbed

| Source | Claim | Why it is rejected |
|---|---|---|
| [sailor.sh — CKA exam changes 2025/2026](https://sailor.sh/blog/cka-exam-changes-2025-2026/) | Domains reweighted to **25 / 12 / 22 / 10 / 31** | ⛔ **Conflicts with BOTH the Linux Foundation and CNCF**, which publish **25/15/20/10/30**. The post presents it as a completed change |
| same | *"The CKA exam now covers Kubernetes 1.29 and 1.30 (as of 2026)"* | ⛔ 🟢 says **v1.35**. Roughly two years stale, in a post dated for 2026 |
| [sailor.sh — CKA exam difficulty (Apr 2026)](https://sailor.sh/blog/cka-exam-difficulty/) | Reprints the **25 / 12 / 22 / 10 / 31** weights; **"45–50% first-attempt pass rate"** plus pass-rate-by-experience and pass-rate-by-preparation tables | 🚨 **SAME SITE, SAME ERROR — found by Andrew Sep 17, 2026, ONE DAY after the row above was written.** ⭐ **The note above predicted exactly this** (*"exactly the source a hurried future session would find and trust"*), which is the best argument for keeping this table. ⛔ **Every pass-rate number is unsourced — the Linux Foundation does not publish pass rates**, and the tables conclude that buying mock exams raises your score while asserting twice that *"Sailor.sh mock exams correlate strongly with actual exam performance."* ⚠️ It also says the exam covers *"six different domains"* and then lists five. ✅ **What is still usable, kept deliberately rather than discarding the whole page:** its **readiness self-assessment checklist**, *"deliberately break your lab cluster 3–4 times weekly"* (which is our Stage 3 design), and its agreement that **time management, not knowledge, is the top cause of failure** |

🚨 **Why this one is worth a permanent entry rather than a shrug.** The post is well-formatted, dated
for the right years, titled as an update, and **precisely on the topic you would search for** — so it is
exactly the source a hurried future session would find and trust. ⭐ **Two independent errors in one post
means the problem is the source, not the sentence** — treat everything in it as unreliable, and note
that its *framing* (a table of "previous % → current %") is more convincing than a plain wrong number
would be, because it looks like the output of research.

---

## 🔲 Gaps in this pass — to close next time

- **Task shape and phrasing guidance** — 🟡 **PARTLY CLOSED Sep 17, 2026** by the DEV exam report
  above, which describes tasks that **combine two topics** (Helm + CRD, Ingress → Gateway/HTTPRoute
  migration) rather than testing one each. ⭐ **That answers the shape half of Q3 and it changes the
  exercises: ten single-step drills train a different skill from ten two-step ones.** 🔲 **Still
  open:** exact wording, what the infobox contains, and how partial credit works.
- **Whether Killer.sh's difficulty is above the real exam** — widely asserted in the community, not
  checked here.
- **`crictl`'s actual presence.** 🟢 does not list it; 🟡 says it is there. ✅ **Still unresolved, but no
  longer blocking: we install it anyway (Sep 17, 2026) and the reasoning does not rest on the answer** —
  with Docker removed it is the only way to inspect a container on a node, and 🟢 kubernetes.io's own
  troubleshooting pages use it. See [`lab-parity.md`](lab-parity.md) §2. ⭐ **Worth confirming from a
  simulator session rather than more searching**, since that is the one place the real environment can
  be observed.
- **Whether `etcdctl` is pre-installed on exam control-plane nodes**, or must be located/installed. The
  backup/restore competency implies it is available, but that is an inference, not a source.
- ✅ **CLOSED Sep 16, 2026 — the CNCF curriculum PDF HAS now been read directly** (`CKA_Curriculum_v1.35.pdf`,
  169,029 bytes, sha256 `634b7937…78ec18c`). It confirmed every domain and weight and added four pieces of
  precision the summaries had dropped — see [`curriculum.md`](curriculum.md), items marked 📄. ⭐ **The most
  useful was that the spec names `kubeadm` outright.** ⚠️ It says nothing about task count, phrasing, partial
  credit or chaining, so **Q3 cannot be answered from it.**
