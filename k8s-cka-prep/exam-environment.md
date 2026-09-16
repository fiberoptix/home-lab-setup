# The CKA exam environment — what the machine is actually like

**Researched September 16, 2026.** Marking scheme in [`README.md`](README.md). Sources in
[`sources.md`](sources.md).

> ⭐ **Read this before deciding anything about how the lab is built.** Almost every "how do I practise
> for CKA" question is really a question about this page.

---

## The delivery stack

🟢 The exam is proctored through **PSI's "Bridge" platform**, taken inside the **PSI Secure Browser** —
a purpose-built browser for secure remote delivery. What you get is a **remote Linux desktop**, not a
bare terminal in a web page.

🟢 The remote desktop carries:
- a **terminal emulator** (from the Applications menu or a desktop icon)
- **VSCodium**, a graphical editor — and **its integrated terminal is explicitly allowed** as an
  alternative to the system terminal. ⛔ **Installing VSCodium extensions is disabled and prohibited.**
- **Firefox**, for the allowed documentation only
- a **virtual keyboard**, and a **Simple Translate** extension
- two tabs by default: a **ReadMe** tab with environment instructions, and the **Remote Desktop** tab

🟢 **Copy and paste differ by application, and this trips people up:**
| Where | Copy | Paste |
|---|---|---|
| **In the terminal** | `Ctrl+Shift+C` | `Ctrl+Shift+V` |
| Everywhere else on the desktop | `Ctrl+C` | `Ctrl+V` |

Right-click → Copy/Paste works in the terminal too.

---

## ⭐ The SSH model — the most important structural fact

🟢 **You do not work on the machine you land on.** The desktop's base system has hostname **`base`**,
and:

- **Every task must be completed on a designated `host`.** An **infobox at the start of each task**
  gives you the `ssh` command to reach it.
- **When a task is done, `exit` the SSH session** to get back to `base`.
- 🚨 **Nested SSH is not supported.** You go `base → host`, and back out again. Not `host → host`.
- Elevate with **`sudo -i`** on any host.
- 🚨 **`base` has NONE of the tooling pre-installed** — not even `kubectl` — precisely because all work
  is meant to happen on a designated host.

⭐ **Why this matters more than it looks:** it means muscle memory built by running `kubectl` on your
own workstation against a remote cluster is **the wrong muscle memory**. In the exam you are *on* the
node. See [`lab-parity.md`](lab-parity.md) → *Work on the node, never from the workstation*.

---

## What is pre-installed on the SSH hosts

🟢 Stated by the Linux Foundation as pre-installed **and pre-configured** on all SSH hosts:

| Tool | Detail |
|---|---|
| **`kubectl`** | with the **`k` alias** *and* **Bash autocompletion** already set up |
| **`yq`** | for YAML processing |
| **`curl`**, **`wget`** | for testing web services |
| **`man`** + man pages | for further documentation |

🟢 You **may install packages that are part of the distribution** if something you want is not there.
🟢 You may also read documentation installed by the distribution (`/usr/share` and below).

### ⚠️ Two traps in that list

1. 🚨 **It is `yq`, not `jq`.** A great many community guides drill `jq` for filtering JSON output. The
   official tool list names **`yq`** and does not mention `jq`. 🟡 One blog claims `jq` and `crictl` are
   present — plausible, but it is **not** in the official list, so **do not build a technique on it.**
   **Practise `yq`, and practise `kubectl -o jsonpath=` for the cases where you would reach for `jq`.**
2. 🚨 **The `k` alias and completion are already there.** 🟡 Several guides open with "first, set up your
   alias" — advice that predates this being standard. Setting up what already exists costs exam minutes.
   ✅ **Correct move: verify in the first fifteen seconds** (`type k`), and only configure if absent.

---

## What you may open in the browser

🟢 Allowed, from within the exam VM's Firefox, used only to work independently on the tasks:

- **Kubernetes documentation** — <https://kubernetes.io/docs> · searching within the docs site **is**
  allowed, but ⛔ **you must not open external search results**
- **Kubernetes blog** — <https://kubernetes.io/blog/>
- **Helm documentation** — <https://helm.sh/docs>
- **CKA only: Gateway API documentation** — <https://gateway-api.sigs.k8s.io>
- **Task-specific documentation linked in the task's own Quick Reference box**

🟢 Translations of the docs are allowed, but the Linux Foundation **recommends the English version**,
because localised pages lag and are not updated every release.

⭐ **That Helm and Gateway API are on the allowed list is a curriculum signal, not a courtesy.** Both
were added to the competencies in the Feb 2025 update — see [`curriculum.md`](curriculum.md).

---

## Kubernetes version

🟢 **The CKA environment currently runs Kubernetes v1.35** (CKAD likewise). 🟢 The exam environment is
**aligned with the most recent Kubernetes minor version within roughly 4–8 weeks of that release**, and
🟢 quarterly exam updates are planned to match Kubernetes releases.

🚨 **So "which version do I practise on" has a moving answer, and it is dated the moment it is written.**
Latest upstream stable at the time of this research was **v1.37.0**, while the exam sat on **v1.35** —
so the exam trails upstream by about two minors. **Re-check this before booking**, and prefer building
the version the exam is on rather than the newest available.

🔴 **CONTRADICTED:** one community post states the exam "covers Kubernetes 1.29 and 1.30 (as of 2026)".
That is wrong against the official listing of **v1.35** and is roughly two years stale. It appears in the
same post as the incorrect domain weights — **treat that source as unreliable in full.**

---

## 🟡 Community-reported detail — useful, unverified, and flagged as such

From a 2026 exam-tips blog. None of it conflicts with official sources, but none of it is confirmed
either, so it is 🟡 and stays 🟡 until seen in the simulator:

- The terminal is effectively **single-pane** — no `tmux`, no split screens, one shell.
- **Multiple clusters**, with each task targeting a specific one. 🚨 **Reported as the single most common
  mistake: forgetting `kubectl config use-context` before starting a task.**
- No `kubectl` plugin manager (`krew`).
- **Your local clipboard is not shared** with the exam terminal, so long YAML gets typed rather than
  pasted — an argument for knowing `kubectl create ... --dry-run=client -o yaml` cold.
- Suggested bookmarks once in: Workloads · Services/Networking/Ingress · Configure RBAC · kubectl
  cheatsheet.

⭐ **The context-switching warning is worth taking seriously even though it is 🟡**, because it is
cheap to defend against (make `use-context` the reflex first line of every task) and expensive to get
wrong (a perfect answer on the wrong cluster scores zero). ⚠️ **Our lab has ONE cluster, so it cannot
train this reflex by itself** — see [`lab-parity.md`](lab-parity.md).
