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

## 🔴 Contradicted — recorded so it is not re-absorbed

| Source | Claim | Why it is rejected |
|---|---|---|
| [sailor.sh — CKA exam changes 2025/2026](https://sailor.sh/blog/cka-exam-changes-2025-2026/) | Domains reweighted to **25 / 12 / 22 / 10 / 31** | ⛔ **Conflicts with BOTH the Linux Foundation and CNCF**, which publish **25/15/20/10/30**. The post presents it as a completed change |
| same | *"The CKA exam now covers Kubernetes 1.29 and 1.30 (as of 2026)"* | ⛔ 🟢 says **v1.35**. Roughly two years stale, in a post dated for 2026 |

🚨 **Why this one is worth a permanent entry rather than a shrug.** The post is well-formatted, dated
for the right years, titled as an update, and **precisely on the topic you would search for** — so it is
exactly the source a hurried future session would find and trust. ⭐ **Two independent errors in one post
means the problem is the source, not the sentence** — treat everything in it as unreliable, and note
that its *framing* (a table of "previous % → current %") is more convincing than a plain wrong number
would be, because it looks like the output of research.

---

## 🔲 Gaps in this pass — to close next time

- **Task shape and phrasing guidance** — a search attempt failed and was not retried. Nothing here
  describes how tasks are worded, what the infobox contains, or how partial credit works.
- **Whether Killer.sh's difficulty is above the real exam** — widely asserted in the community, not
  checked here.
- **`crictl`'s actual presence.** It matters: with Docker removed from our nodes, `crictl` becomes the
  way to inspect containers, and it would be useful to know whether the exam expects it. 🟢 does not list
  it; 🟡 says it is there.
- **Whether `etcdctl` is pre-installed on exam control-plane nodes**, or must be located/installed. The
  backup/restore competency implies it is available, but that is an inference, not a source.
- **The CNCF curriculum PDF itself has not been read** — only its published summaries. It is the actual
  specification and should be read directly before the coverage matrix is called complete.
