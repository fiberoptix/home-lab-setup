# Phase 20 — Rancher on a single-node K3s VM (`vm-k3s-rancher-1`), with GitLab → Fleet GitOps

**Status: 🔵 BUILT Oct 27, 2026 (AI-built at Andrew's instruction, 22:10–23:00) — Parts 0–6 done, drills
D1–D4 done, D5 due Oct 28 ~23:00 (24 h of Prometheus data), D6 waits for a newer Rancher release.**
📚 **Study track `education/rancher-k3s/` WRITTEN Oct 27, 23:25–23:50** (5 chapters + `COMMANDS.md` + README, all 🤖 AI-executed) — see the EDUCATION TRACK section. **Not yet committed.**
🙋 *"Write a plan to build rancher into a new VM vm-k3s-rancher-1 with all the things you said and ideally
I'd like you to build it for me completely."* · *"Try to build the whole thing and note errors."*

## ▶️ RESUME HERE — state at session close (Oct 27, 2026, 23:10)

🙋 Andrew, 23:09: *"Confirm that we now have a working Rancher in K3s and we have documented the build
and are ready to action MAKE_MEMORIES then commit and push. Later we can deploy an actual app to it."*
→ **Confirmed.** 🙋 23:10: *"make sure to document the above in the phase file so when I come back and ask
you to read it you remember everything we did"* → this section.

**✅ Verified working at ~23:05 Oct 27 (final health check, after the drills):** `/ping` → `pong`, dashboard
200, admin login OK (bootstrap value rejected), management cluster `local` Ready=True, **0 pods not
Running**, Fleet GitRepo `hello-lab` **1/1** on commit `0682a5d`, `hello-rancher` serving `3a2687e8`
delivered by Fleet. Survived 2 reboots unattended; app + GitOps kept working with Rancher at 0 replicas.

**✅ Recorded and pushed:** this file (build results, E1–E7, F1–F12, drills), `MEMORY.md` (PHASE INDEX
row, `.187` host row, phase-table row 20 → backlog renumbered 21+, files table, `refresh.sh` lines, the
stale "only Kubernetes is k3s on 186" line corrected), `README.md`, `current_phase.md` (pointer at the top
of RESUME HERE + an Oct 27 Phase 20 session block). **home-lab-setup commit `84c15fd`** → GitLab
(snapshot `74ba8ad`) and GitHub. Apps repo `production/rancher-k3s` is at `0682a5d` (GitLab only — it has
no GitHub mirror). Only `education/fin_tech_stack.txt` is left uncommitted, on purpose (Andrew).

### 🔲 Open items (carry these forward)

| Item | Detail |
|---|---|
| **`MAKE_MEMORIES` pass** | ✅ **Done Oct 27 (pass 13)** — `current_phase.md` 13 → 9 blocks: the Sep 28 and Oct 27 PVE-update handoffs, the stale "ACTIVE: Phase 16" block and Phase 15 demoted (commits 13a–d); the Phase 20 block kept as the newest handoff. Backlog left: five Aug 19–21 blocks |
| **D5** | ≥ **Oct 28, 23:00**: `sudo kubectl exec -n cattle-monitoring-system prometheus-rancher-monitoring-prometheus-0 -c prometheus -- du -sh /prometheus` on `.187`; compare with baseline **44.3 MB / ~207k head series / zvol 10.2 G**; confirm `retentionSize 15GiB` is honoured. Record in the Drills table |
| **D6** | When a community Rancher newer than 2.15.2 exists: upgrade drill with the SAME `rancher-values.yaml` (and the matching rancher-monitoring chart — 110.x is tied to 2.15) |
| **Root PAT `phase20-ai-build`** | 7-day GitLab root token (scope `api`), expires **2026-11-03** — revoke when Phase 20 is closed. Value in `PASSWORDS.md` |
| **E7 — shared password** | Printed once in this session's tool output (local only). The same string is already in tracked `MEMORY.md` / `current_phase.md` as the SMB password, so rotating it is a lab-wide decision for Andrew |
| **Token renewals** | Deploy tokens + `BUMP_TOKEN` expire **2027-10-27**; push-model SA token **2027-10-28** |

### 🚀 Next: deploying a real app (Andrew: "Later we can deploy an actual app to it")

The pipeline → registry → Fleet path is proven; `hello-lab` is the template to copy. Per app:
1. **DNS:** a new Route53 A record `<name>.gothamtechnologies.com` → `192.168.1.187` (zone
   `Z09296022UK9OS9I920TO`, AWS CLI on `.195`) — there is **no wildcard**.
2. **Repo layout** in `production/rancher-k3s`: `<app>/` (source + Dockerfile) and `fleet/<app>/`
   (`fleet.yaml` with its own `defaultNamespace`, `kustomization.yaml` with an `images:` entry, manifests,
   Ingress `ingressClassName: traefik`).
3. **Fleet:** add `fleet/<app>` to `paths:` in `proxmox/build-scripts/rancher-k3s/fleet-gitrepo.yaml` and
   re-run `6-gitops.sh` (or give the app its own GitRepo).
4. **CI:** copy the `build`/`bump` jobs with `changes: [<app>/**/*]` and the app's own `kustomization.yaml`
   path. Images go ONLY to `gitlab.gothamtechnologies.com:5050/production/rancher-k3s/<app>` (B10 scoped
   reading). The registry pull credential in `registries.yaml` is node-wide — nothing per namespace.
5. **Container hygiene:** must exit on SIGTERM (F1 — otherwise +30 s per rollout and +90 s per reboot);
   non-root, probes, memory limit, as `hello-lab/deployment.yaml` does.
6. **Data:** `local-path` PVCs live on this one VM's disk on `vm-ephemeral` (no backup job) — fine for a
   demo, not for data that matters.
7. ⚠️ **Lab-only anti-pattern:** apps on Rancher's own `local` cluster. At work they go on downstream clusters.

### 🧰 Operating it (so nothing has to be rediscovered)

- **Shell:** `ssh agamache@192.168.1.187`, then `sudo kubectl …`. For Helm: `sudo -E env
  KUBECONFIG=/etc/rancher/k3s/k3s.yaml helm …` (plain `sudo helm` cannot find the cluster — F11).
  ⛔ Never copy the kubeconfig to `.195`.
- **Scripts on the VM:** `~agamache/rancher-k3s/` (copies of `3-`…`6-*.sh` + yaml). Repo is the source of
  truth: `proxmox/build-scripts/rancher-k3s/` — edit there, `scp` over, re-run, expect `0 change(s)`.
  `4-rancher.sh` / `6-gitops.sh` need their root-only secrets file **only** to (re)write credentials;
  values in `PASSWORDS.md`, shred the file after.
- **Apps repo clone:** `/home/agamache/DevShare/cursor-projects/rancher-k3s` — `origin` has no
  credentials; push with `http://oauth2:<token>@gitlab.gothamtechnologies.com/production/rancher-k3s.git`.
  **Pull before committing** (the bump job commits to `main` after every app build — see E5).
- **Fleet status:** `sudo kubectl get gitrepo -n fleet-local`; if it says NotReady, check
  `kubectl rollout status` first (F2). Roll back = `git revert` the bump commit.
- **Rollback of the whole VM:** `qm rollback 187 r03-gitops-wired` on `.150` (newest snapshot only — ZFS).
- **Patching:** `refresh` on the PVE host patches `.187`'s OS; K3s/Rancher upgrades are drills, never a click
  on "upgrade" for `local` in the UI (F5).

## 📚 EDUCATION TRACK `education/rancher-k3s/` — PLAN (Oct 27, 2026, 23:25) — ✅ APPROVED 23:24 · ✅ WRITTEN by 23:50

🙋 Approval (23:24): *"Go ahead. You're writing this so I can learn about Rancher. Later we will build a
proper k8s cluster by hand. Now I just need to learn enough to know how it works."* ⭐ **So the weighting is
CONCEPTUAL** — what each piece is, why it is there, what depends on what — with the procedure kept as the
evidence, not as a runbook to memorise. Live outputs re-captured read-only from `.187` at 23:24–23:30.

🙋 *"let's create some documentation about how to install and configure rancher. use the
@education/CONVENTIONS.md and @education/METHOD.md to create documentation so I can learn how we built
this implementation and call the directory /rancher-k3s inside /education."* This supersedes **Q4**
below ("no education track yet"). Per `CURSOR_RULES` education rule 6, **this file is the track's
phase file** — no new phase number.

### Decisions (Andrew, Oct 27, 23:2x — answered as multiple choice)

| # | Question | Answer |
|---|---|---|
| T1 | The AI built Phase 20, but METHOD says Andrew runs anything new | **Write now, every chapter DECLARED "AI-executed"** in its opening paragraph (the Swarm chapter 7 precedent). A hands-on replay can come later; when it does, a chapter's declaration is removed only after Andrew has run that chapter |
| T2 | Scope | **5 chapters + `COMMANDS.md`** (outline below) |
| T3 | Phase file | **This file** (`phase20`) |
| T4 | Finish level | **Full conventions:** Graphviz diagrams, Lab-vs-PROD callouts, 20 % highlight pass, docx builds, `figcheck` clean |

### 🚨 The honesty rules this track runs under (because the AI ran it)

1. **Every chapter opens with the 🤖 DECLARATION block** (Swarm ch7 wording adapted): commands executed
   and outputs real, but run by the AI at Andrew's instruction — one step weaker than an Andrew-run chapter.
   The track README and the shelf table in `education/README.md` say the same.
2. **No invented output.** An output block is either (a) quoted from this file / the session record, or
   (b) **re-captured now from the live VM by READ-ONLY commands** (`get`, `describe`, `version`, `curl`,
   `helm list`), with the capture date in the chapter's verified-facts header. Build-time output that
   was not recorded (e.g. a full `helm install` transcript) is **described, not reconstructed**.
3. **`COMMANDS.md` marks every entry** ✅ *ran here (AI)* or ⚠️ *standard, not run here*.
4. **"In production you would…" is marked verified or recited**, every time (CONVENTIONS).
5. **No secrets, ever:** no passwords, tokens or token names' values; `PASSWORDS.md` is referenced, never read
   into a chapter. Hostnames and the `192.168.1.x` plan are already public in this repo and may appear.

### Chapter plan (procedure, not story — tripping points at the step; CONVENTIONS shape)

| Ch | Title (H1: `# Rancher on K3s · Chapter N — …`) | Content | Figures | Lab-vs-PROD candidates (threshold: WRONG in prod, not smaller) |
|---|---|---|---|---|
| 1 | **What Rancher Is, and Why It Gets Its Own Cluster** | Rancher = a Helm app on Kubernetes; the `local` (management) cluster vs downstream clusters; why not the Docker install / LXC / inside a managed cluster (blast radius, cluster-admin everywhere); why single-node K3s and why 1.35; what Rancher pulls in beyond the docs (F12); community vs Prime patch policy → upgrading every minor is mandatory | fig1 the stack on VM 187 · fig2 manager/downstream in prod vs this lab | 🚨 **Apps on the `local` cluster** |
| 2 | **Installing It: K3s, Helm, cert-manager, Rancher** | VM prep assumed (pointer); DNS that pods can resolve (and why a private IP in public Route53); K3s from a downloaded, pinned installer, `config.yaml` (`0600`, `tls-san`, CIDR check), verify; Helm **v3** + F11 (`sudo` loses `KUBECONFIG`); cert-manager; Rancher values file (`replicas=1`, `ingress.tls.source=rancher`, saved for upgrades), E1 at its step, first login + bootstrap retired; F5 (`system-upgrade-controller` = a path around the pin); snapshot | fig3 install order / what depends on what · fig4 the TLS chain (cert-manager → Rancher CA → Traefik) | 🚨 **Self-signed Rancher CA → clicking through the browser warning**; ⚠️ kubeconfig never leaves the VM (good practice, likely prose not callout) |
| 3 | **Seeing It: rancher-monitoring** | CRD chart + chart, version tied to the Rancher minor; explicit `retention`/`retentionSize` because the pool is thin; verify from Prometheus targets, not the Grafana tile; F3 the cached 502; F9 footprint; D5 shown as 🔲 pending until measured | fig5 how metrics reach Grafana through Rancher's proxy | Prometheus on single-disk `local-path`, no backup (decide at writing — may be a table row) |
| 4 | **Shipping to It: GitOps with Fleet, and the Push Model** | apps-repo layout; CI build → registry → bump commit `[skip ci]` (E4 YAML traps at the step); `registries.yaml` (K3s ignores `daemon.json`; node-wide credential); Fleet `GitRepo` over HTTP with a deploy token (F6); push → serving in 36–42 s; push model with a namespace-scoped SA; F2 Fleet status lags → check `rollout status`; container hygiene F1 (SIGTERM / PID 1) | fig6 pull model vs push model — who holds which credential · fig7 the delivery path with measured timings | 🚨 **Plaintext registry + git over HTTP carrying credentials** · 🚨 **Cluster token held by a privileged runner** (push model) |
| 5 | **Breaking It** | D1 reboot (the 87 s SIGTERM miss → 63 s), D2 Rancher at 0 replicas (apps + GitOps carry on — F7), D3 broken manifest (`ErrApplied`; alert on `Ready` not `Stalled` — F8), D4 registry 401 hidden by Rancher's summary (F4); each as prediction → measured → what to conclude at 3am; D5/D6 stated as not yet run | fig8 what keeps running when Rancher is gone | none expected (drills, not shortcuts) |

Plus **`README.md`** (chapter table, the declaration, versions, what this track is for, link to the build
scripts) and **`COMMANDS.md`** (indexed by the question each command answers, in incident order).

### Artefacts and layout

- `education/rancher-k3s/{README.md, COMMANDS.md, chapter01…05_*.md, diagrams/, images/, docx/, manifests/, scratch/}`.
- **`manifests/`** = copies of the tested YAML (`rancher-values.yaml`, `monitoring-values.yaml`,
  `fleet-gitrepo.yaml`, `push-rbac.yaml`, and the `hello-lab` Fleet bundle), each with a header naming its
  source of truth. **The scripts stay in `proxmox/build-scripts/rancher-k3s/`** (infra owns VM provisioning;
  copying them invites drift); chapters quote the relevant fragments inline and name the path.
- Tooling unchanged — `build_docx.py` / `figcheck.py` / `highlight.py` find a track by its chapter files.
- Also updated: `education/README.md` track table (row 5, "Built in the lab? Yes — **AI-executed**"),
  `MEMORY.md` PHASE INDEX Phase 20 row (track exists), this file's status line.

### Work order and validation

1. Re-capture live outputs (read-only) on `.187`. 2. Chapters 1 → 5 in order, each written at ~20 %
highlight, figures rendered and `figcheck rancher-k3s` clean before moving on. 3. `COMMANDS.md`, README,
shelf row. 4. `build_docx.py rancher-k3s`; `highlight.py --check` per chapter; per-section highlight
density measured. 5. A secrets scan of the track (`rg` for the password/token patterns) before any commit.
6. Commit + push only when Andrew says (ask GitHub / GitLab / both).

**Out of scope:** the replay itself, the real-app deployment (a later chapter 6 when it happens), D5/D6
results (added when measured), any change to the running VM.

### ✅ What was written (Oct 27, 23:50)

| Artefact | Result |
|---|---|
| Chapters 1–5 | `chapter01_what_rancher_is` … `chapter05_breaking_it`, each 21–22 % highlighted (per-section 17–25 %), 1 or 2 Lab-vs-PROD callouts in Ch 1–4, none in Ch 5 (drills) |
| Figures | 8 (`ch01_fig1/2`, `ch02_fig1/2`, `ch03_fig1`, `ch04_fig1/2`, `ch05_fig1`) — `figcheck rancher-k3s`: all ≥ 10 pt (lowest `ch03_fig1` 10.5) |
| `COMMANDS.md`, `README.md` | Indexed by question; every row marked ✅ ran here (AI) / ⚠️ standard / 🔲 planned |
| Word | `docx/` × 5 built; inner `document.xml` checked — Key runs 77–173, media present, no markup leaks |
| Shelf / MEMORY | `education/README.md` row added; MEMORY task-router row, PHASE INDEX row 20 and files table updated |

**Corrections made while writing (outputs re-checked against the captures):** ch3's targets block had a
duplicated `rancher-monitoring-prometheus` line in place of `rancher-monitoring-operator`, and its PV
command had been simplified — both restored to the captured text; "Fleet puts hand edits back" corrected
(drift correction is opt-in, `correctDrift`, recited); ch1's 29 pods clarified (31 listed, two completed
install jobs). **New read-only captures ~23:45:** `6-gitops.sh --check` all in sync; the Fleet-made Helm
release `hello-lab-fleet-hello-lab` is at **revision 21**, chart `…-v0.0.0+git-0682a5dc00f4`; `hello-lab-push`
holds **no Secrets** (the push token is signed, not stored); no secret files left in `/root` on `.187`.
🔲 Still in `/tmp` on `.195`: `gl-phase20.tok` (the root PAT, 0600) — goes with revoking the PAT.

## ▶️ BUILD RESULTS (Oct 27, 2026) — read this first

| | |
|---|---|
| Rancher UI | **https://rancher.gothamtechnologies.com** — user `admin`, password in `PASSWORDS.md` (Rancher-generated CA → browser warning) |
| Demo app | **http://hello-rancher.gothamtechnologies.com/** → JSON with the commit SHA it was built from |
| VM | VMID **187** `vm-k3s-rancher-1` `192.168.1.187`, 6 vCPU / 24 GB / 120 G on `vm-ephemeral`, onboot 1, startup order=4, kernel `6.8.0-147`, Cockpit `:9090`, auto-updates masked, **in `refresh.sh`** |
| Versions (all pinned) | K3s **v1.35.9+k3s1** (Traefik 3.7.13) · Helm **v3.22.1** · cert-manager **v1.21.3** · Rancher **2.15.2** (1 replica) · rancher-monitoring **110.0.2+up80.9.1-rancher.22** |
| Apps repo | GitLab **`production/rancher-k3s`** (project 8, private) — local clone `/home/agamache/DevShare/cursor-projects/rancher-k3s` (origin URL has no credentials; push with a token in the URL) |
| Build scripts | `proxmox/build-scripts/rancher-k3s/` — `1-provision-vm.sh` (runs on .195) · `3-k3s.sh` `4-rancher.sh` `5-monitoring.sh` `6-gitops.sh` (run ON the VM as root; copies in `~agamache/rancher-k3s/`) · values files · `fleet-gitrepo.yaml` · `push-rbac.yaml`. Every script re-run reported **0 changes** |
| Snapshots | `r01-os-ready` → `r02-rancher-up` → `r03-gitops-wired` (PVE + ZFS both verified). 🚨 ZFS rolls back only to the newest |
| DNS | Route53 A records `rancher` and `hello-rancher` → `192.168.1.187` (TTL 300) — resolve from .195, the VM, and inside pods |
| Credentials | All in `PASSWORDS.md`: Rancher admin (+ dead bootstrap value), 2 deploy tokens, CI bump token, push-model kubeconfig notes, and a **7-day root PAT `phase20-ai-build` (expires 2026-11-03) — revoke when this phase is closed** |

**How a change ships (measured):** commit to `hello-lab/` → pipeline (build 9 s + bump 6 s) → bump commit
`deploy: hello-lab <sha> [skip ci]` → Fleet polls (15 s) → rolling update. **Push → new SHA serving: 36–42 s.**
The manual `deploy_push` job is the push-model comparison (ServiceAccount limited to `hello-lab-push`).

### 🧾 Error log (Andrew asked for every error to be noted)

| # | Where | What happened | Fixed? |
|---|---|---|---|
| E1 | Part 4, `4-rancher.sh` | `kubectl patch settings telemetry-opt` → **NotFound**. Rancher 2.15.2 has no `telemetry-opt` setting (exists: `server-url`, `eula-agreed`, `first-login`). Script stopped after `server-url` | ✅ script now skips settings that do not exist; re-run clean |
| E2 | Part 5 | Prometheus target `rancher-monitoring-grafana` **down, HTTP 502** for ~5 min after install | ✅ self-healed — cause below (F3). No change made |
| E3 | Part 6, `6-gitops.sh --push-kubeconfig` | Two `warn` lines claimed the CI ServiceAccount could read Secrets and reach namespace `hello-lab`. **False positive:** `kubectl auth can-i` exits 1 on "no", and under `pipefail` the `| grep -q no` pipeline failed | ✅ verified by hand (`no`/`no`), check rewritten to read the answer, not the exit code |
| E4 | Part 6, CI YAML | Caught BEFORE the first push by parsing: `- git commit -qam "deploy: …"` parsed as a YAML **mapping** (`": "`), and `" #"` inside a plain scalar would have truncated the `sed` line as a comment | ✅ quoted / block scalars; `ci/lint` valid |
| E5 | Part 6, my own sequencing | First end-to-end test: `git pull --rebase` ran before the commit → push rejected → the timer waited 304 s for a deploy that never started. Not a system fault | ✅ re-run: 36 s |
| E6 | D3, my own sequencing | `git revert HEAD~1` after a revert pointed at the D3 commit again, not D2 → chain stopped before push; a diagnostic `revert` then re-applied the broken commit **locally** (never pushed; reset) | ✅ reverted D2 by hash; recovered in 21 s |
| E7 | Part 6 (Andrew to decide) | My redaction regex missed one `PASSWORDS.md` line while listing GitLab entries, so the **GitLab root password was printed into this session's tool output** (local transcript only, nothing pushed). ⚠️ Context found by the pre-commit scan: the same string is ALREADY in tracked `MEMORY.md` (the SMB-mount notes, ~ln 911/925) and `current_phase.md`, pre-dating this phase — it is a shared password, so rotating it is a lab-wide decision | 🔲 **Andrew: decide whether to rotate the shared password** |

### ⭐ Findings (things a reader would get wrong without them)

- **F1 — One container that ignores SIGTERM adds 90 s to EVERY reboot of the VM.** D1 first run: shutdown
  took 87 s (`cri-containerd-…scope: Stopping timed out. Killing … (python)`) — systemd's
  `DefaultTimeoutStopSec`. Python as PID 1 has no default SIGTERM action. After adding a handler to
  hello-lab: **shutdown 4 s; reboot-to-Rancher 151 s → 63 s.** The same bug makes every rollout wait the
  30 s `terminationGracePeriod`. ⭐ At work: check PID-1 signal handling in every image (or use `tini`).
  🔎 *Precision (from the session record, Oct 27 23:50):* the handler (`3a2687e`) was already in the Fleet
  copies before D1; the container that hung the shutdown was the **push-model copy**, still on the old
  image `fd227698` because its manual job had not been re-run. Re-running `deploy_push` fixed it.
- **F2 — Fleet reported the app `NotReady` / `[progressing] Updated: 1/2` for ~4 min after a COMPLETE,
  healthy rollout** (Deployment 2/2, `NewReplicaSetAvailable`). The agent evaluated status once, mid-rollout
  (`update-status … not ready` at 22:44:45) and did not re-check until the agent restarted. ⚠️ **Fleet's
  status can lag reality — confirm with `kubectl rollout status` before acting on a Fleet "NotReady".**
- **F3 — The Grafana 502 was CACHED.** Rancher's `grafana-proxy` nginx sidecar has
  `proxy_cache_valid any 5m`, so a 502 from Grafana's startup is served for 5 minutes after Grafana is fine.
- **F4 — Rancher's summary view hides the root cause of an image-pull failure** (D4). Raw events say
  `failed to fetch oauth token: … GET http://gitlab…/jwt/auth?… 401 Unauthorized` — the registry was reached,
  the CREDENTIAL was rejected (not DNS, not network). Rancher's state for the same pod:
  `imagePullBackOff`, *"containers with unready status"*, **`error: false`, `transitioning: true`** — not
  painted as an error, no 401. You need the pod's Events tab.
- **F5 — Rancher installs `system-upgrade-controller` into its own cluster.** K3s is pinned here and not
  apt-managed, but the Rancher UI can upgrade the `local` cluster's K3s through it — a path around the pin.
  Upgrades stay a deliberate drill; do not click "upgrade" on `local` casually.
- **F6 — Fleet over a plain-HTTP git URL WORKS** (was "unverified" in the plan): GitRepo with
  `repo: http://gitlab…` + a `kubernetes.io/basic-auth` deploy-token Secret fetched on the first poll.
- **F7 — GitOps does not depend on Rancher** (D2): with `deploy/rancher` at 0 the UI returned 503, the app
  answered 30/30, and **Fleet still applied a new commit in 22 s** — `fleet-controller`/`gitjob` are separate
  Deployments. Rancher returned (`pong`) 34 s after scaling back to 1.
- **F8 — The broken-manifest failure mode is safe** (D3): `replicas: three` → `ErrApplied` with the exact
  API error (`.spec.replicas: expected numeric … got string`), old ReplicaSet kept serving 15/15,
  `git revert` → Ready in 21 s. ⚠️ The GitRepo's `Stalled` condition stays **False** throughout — alert on
  `Ready`, not `Stalled`.
- **F9 — Rancher's own footprint on one node, idle:** node ~4.7–5.8 GiB used of 24, CPU 1.5–2.2 cores
  while settling after restarts (Rancher pod up to 1.2 cores), steal 0.0 %. Prometheus head ~207k series.
- **F10 — `helm-install-traefik` showed 2 restarts on first K3s boot** (CRD race; normal, completed).
- **F11 — Under plain `sudo`, `helm` cannot find the cluster** (`localhost:8080 refused`); `k3s kubectl`
  defaults to `/etc/rancher/k3s/k3s.yaml`, Helm does not. The scripts export `KUBECONFIG`.
- **F12 — Rancher pulled in more than the docs list:** `cattle-capi-system` (CAPI controller),
  `cattle-turtles-system`, `helmops`, `system-upgrade-controller` — ~20 pods before any app.
- **F13 — The TLS chain, traced (found while writing the track, Oct 27 23:28).** With
  `ingress.tls.source=rancher`, **Rancher generates its own 10-year self-signed CA** (`O=dynamiclistener-org,
  CN=dynamiclistener-ca@…`, Secret `cattle-system/tls-rancher`, valid to 2036); cert-manager's `Issuer
  rancher` is a **CA issuer pointing at that Secret**; `Certificate tls-rancher-ingress` (SAN only, empty
  subject, **90 days**) is what the Ingress names and **Traefik serves — served serial `25B9DC7A…` = the
  Secret's**. `curl` without the CA → exit 60; with the CA from `https://rancher…/cacerts` → 200. ⭐ So
  cert-manager here **renews a leaf from a CA it does not own**, and "the browser warning" is the missing
  trust in Rancher's CA, not a broken certificate.
- **F14 — Alerts go nowhere (found while writing the track).** Alertmanager's config has ONE receiver,
  `"null"`, on every route; 31 `PrometheusRule` objects are loaded and no `AlertmanagerConfig` exists. Rules
  evaluate and alerts can fire, **but nobody is told.** Lab-acceptable; at work this is the first thing to wire.
  (At 23:40 exactly one alert was firing: `Watchdog`, the always-on alert whose job is to prove the pipeline
  delivers — delivered to `"null"`.)
- **F15 — The Prometheus PVC's 20 Gi is a LABEL, not a limit (found while writing the track, 23:40).**
  `local-path` provisions a **directory** on the node's root filesystem
  (`/var/lib/rancher/k3s/storage/pvc-8c51…_cattle-monitoring-system_…`, 94 MB); inside the pod `df -h
  /prometheus` shows **`/dev/sda1 115.2G`** — the whole disk. So **`retentionSize: 15GiB` is the ONLY cap that
  works**; the plan's "Prometheus on a 20 Gi PVC" protected nothing by itself. D5 must therefore check that
  `retentionSize` is honoured (it is the real guard), and the VM's 120 G disk is the real outer bound.

### 🧪 Drills

| # | Prediction | Measured | Verdict |
|---|---|---|---|
| D1 | SSH ≈40 s, app ≤90 s, Rancher ≤3 min, nothing needs a hand restart | **Run 1:** ssh 109 s, app 139 s, Rancher 151 s — 87 s of it was shutdown (F1). **Run 2 (after fix):** ssh **27 s**, app **47 s**, Rancher `/ping` + dashboard **63 s**. No hand restarts either time | ✅ after F1 fix; ❌ run 1 (the miss found F1) |
| D2 | App keeps serving; Fleet keeps delivering without Rancher | 30/30 OK; Fleet applied replicas=3 in 22 s; Rancher back in 34 s | ✅ both |
| D3 | Fleet shows an error, old version keeps running, revert recovers | `ErrApplied` + exact API error; 3/3 kept serving; revert → Ready in 21 s | ✅ (+ `Stalled=False` surprise, F8) |
| D4 | New pod `ImagePullBackOff` with a 401; survivor serves; restore recovers | Exactly that; 15/15 OK during; restore + K3s restart → Running in **16 s**, no pod delete needed. Rancher's summary omits the 401 (F4) | ✅ |
| D5 | `retentionSize` enforced | **Baseline 22:59 Oct 27: `/prometheus` = 44.3 MB, ~207k head series, VM zvol 10.2 G used.** Re-measure ≥ Oct 28 23:00: `sudo kubectl exec -n cattle-monitoring-system prometheus-rancher-monitoring-prometheus-0 -c prometheus -- du -sh /prometheus` | 🔲 due |
| D6 | Upgrade path | Rancher 2.15.2 is still the newest community release | 🔲 when one exists |

## Why

🙋 Work is evaluating **Rancher as a GUI/admin tool for Kubernetes**. This lab test-drives it in the shape
an enterprise runs it — **Rancher installed by Helm onto its own Kubernetes cluster** — scaled down to one
node. ⛔ **Not systemd in a VM, not a Proxmox LXC container, and not inside a cluster it manages:** losing
that cluster would take the tool you fix it with down too, and Rancher holds cluster-admin to everything it
manages, so it belongs in its own blast radius.

## Decisions already made (Andrew, Oct 27)

| Decision | Detail |
|---|---|
| **Community Rancher** | Not Prime |
| **One VM, single-node K3s + Helm** | Not the Docker install (dev/test only, no upgrade path except backup/restore migration) and not more k8s VMs |
| **⛔ The CKA cluster (201–205) is NOT touched** | No import, no agents, no snapshots. 🙋 *"we should not pollute the CKA cluster"* — importing puts `cattle-system`/`cattle-fleet-system` pods, Rancher's admission webhook and cluster-admin bindings into it, which confounds Stage 3 troubleshooting drills and would bake into the `c03` baseline. ⭐ **Rancher manages its OWN cluster (`local`) instead — that is the test-drive target** |
| **Apps + pipelines live in a NEW GitLab repo** | Infra/build scripts stay in this repo (PROJECT SCOPE: VM provisioning is ours) |
| **Build it completely** | The AI builds; Andrew approves this plan first |

⚠️ **The one deliberate anti-pattern, and it is lab-only:** Rancher's docs say its own (`local`) cluster
should run **only** Rancher. Here apps run on it too, because a separate downstream cluster was declined.
**At work, apps go on downstream clusters** — never carry this shortcut there. *(A separate small
downstream cluster can be added later as an optional Part 9 if the import/provisioning workflow itself
needs testing.)*

## Verified facts this plan rests on (Oct 27, 2026)

| Fact | Source |
|---|---|
| **Rancher v2.15.2** is the current release **and is a Community release** | GitHub release notes ("This is a Community version release"); top entry of `releases.rancher.com/server-charts/latest/index.yaml`, chart `kubeVersion: < 1.37.0-0` |
| Rancher v2.15.2 certifies **K3s v1.34–v1.36** as its own cluster, and K3s/RKE2 1.34–1.36 for imported/provisioned | SUSE support matrix for v2.15.2 |
| ⚠️ **Community gets patch releases only for the NEWEST minor.** Once 2.16.0 ships, 2.15.x patches go Prime-only | SUSE release policy (Aug 2024 on). **Consequence: staying patched on community = upgrading every minor — the upgrade drill is not optional** |
| **K3s v1.35.9+k3s1** (Sep 30, 2026) is the newest 1.35 patch; ships **Traefik v3.7.13**, local-path, metrics-server, CoreDNS | docs.k3s.io v1.35.X release notes |
| The Helm chart **needs a DNS hostname** (an Ingress host); `<ip>.sslip.io` is the documented PoC fallback | Rancher "Install on a Kubernetes cluster" docs |
| K3s's bundled ingress satisfies Rancher — **no ingress-nginx, so B9 holds** | Same docs: "For RKE2 and K3s installations, you don't have to install the Ingress controller" |
| Chart default is **3 Rancher replicas** → must be **1** on a single node | Same docs (rollout example shows 3) |
| **`gitlab.gothamtechnologies.com` already resolves PUBLICLY to `192.168.1.181`** → a private IP in public Route53 is existing lab practice | `getent hosts`; zone `Z09296022UK9OS9I920TO`, public; AWS CLI on `.195` can see it |
| **`.187`–`.190`, `.194`, `.196`–`.199` answer neither ping nor ARP; VMID 187 is free** | Sweep from `.195`, 21:59 Oct 27 (script 1 re-checks by ARP at build time) |
| Runner `.182` = **Docker executor**, tags `docker, linux, build` | `phase4_gitlab_runner.md` |
| Registry = **HTTP** `gitlab.gothamtechnologies.com:5050`, auth required (401) | `MEMORY.md` |

## Target

| Item | Value |
|---|---|
| VM | **VMID 187, `vm-k3s-rancher-1`, `192.168.1.187`** (VMID = IP, lab convention) |
| Size | **6 vCPU, 24 GB RAM, 120 GB disk** — Rancher + monitoring + a demo app. 🔻 *Corrected Oct 27 after the build: host vCPU went 64 → **70 of 48 threads** (read live from `qm config`; the plan's "54 → 60" was wrong), RAM 148 of 192 GB. Guest `%st` measured 0.0 % under Rancher's settle load* |
| Storage | **`vm-ephemeral`** — Phase 19 rule: this project can rebuild it. No backup job |
| Boot | `onboot 1`, `startup order=4` (after GitLab, whose registry it pulls from) |
| OS build | Template 9000 → **script 1 (provision) → script 2 (`2-personalize.sh --freeze-updates …`)**. 🔻 *Corrected Oct 27: NOT `host_setup.sh` — that is the **Docker-host** standard, and this repo's rule is "one build standard cannot serve both a Docker host and a Kubernetes node". K3s brings its own containerd; Docker would add a second runtime and its iptables rules for nothing* |
| Kubernetes | **K3s `v1.35.9+k3s1`, pinned** — same minor as the CKA cluster (v1.35.8), inside Rancher 2.15's 1.34–1.36 range |
| Rancher | **v2.15.2**, chart `rancher-latest/rancher --version 2.15.2`, `replicas=1`, Rancher-generated CA via **cert-manager** (version pinned at build) |
| Names | **Decided (Q1):** `rancher.gothamtechnologies.com` and `hello-rancher.gothamtechnologies.com` → `.187`, one A record each (no wildcard) — a new app needs a new record |
| Patching | **Added to `refresh.sh`** (OS only). K3s and Rancher are pinned and NOT apt-managed, so a refresh can never upgrade them — those are deliberate, separate drills |

## Parts

Each part ends with a **verification from inside the guest** and a status line in this file.
Scripts are **re-runnable** (`--check` mode, idempotent, "0 changes on re-run" is the test), in the style of
`education/k8s-cka-prep/scripts/`.

**Part 0 — Preflight (no changes).** ARP-sweep `.187`; confirm VMID 187 free; `zpool list` CAP; host free
RAM; Route53 record absent; GitLab group `lab` exists.

**Part 1 — VM.** Provision 187 from template 9000 (**Q2** decides how). Verify from inside: `df -h /` ≈ 120 G,
guest agent, SSH by key. `2-personalize.sh --hostname vm-k3s-rancher-1 --timezone America/New_York
--sudo-nopasswd agamache --freeze-updates` (+ `--cockpit` to match the Ubuntu fleet). Add `.187` to
`refresh.sh` — repo copy **and** deployed copy, `md5sum` both; SSH to it once from the PVE host (the
stale-host-key hazard). Snapshot **`r01-os-ready`**.

**Part 2 — DNS.** Route53 UPSERT of the record(s) from Q1 via the AWS CLI on `.195`. Verify resolution from
`.195`, from the VM, and **from inside a pod** (pods resolve through CoreDNS → upstream, not `/etc/hosts` —
this is why an `/etc/hosts`-only name was rejected).

**Part 3 — K3s.** Download the installer to a file (never `curl | sh`), pin `INSTALL_K3S_VERSION`. Config
`/etc/rancher/k3s/config.yaml`:
- `write-kubeconfig-mode: "0600"` — ⚠️ Phase 14 used `644`, which made the cluster-admin kubeconfig
  world-readable. Not again.
- `tls-san:` the Rancher name and `192.168.1.187`.
- Default CIDRs `10.42.0.0/16` pods / `10.43.0.0/16` services — no overlap with `192.168.1.0/24`
  (the Phase 18 lesson: a default CIDR is a guess about someone else's network; at work check `10.x`).

Verify: node `Ready`, all `kube-system` pods Running, Traefik answering on 80/443, `local-path` default
StorageClass. ⛔ **The kubeconfig stays on the VM** (operate over SSH). Never merge it into a kubeconfig on
`.195` — one wrong context and a CKA drill command lands on the wrong cluster.

**Part 4 — Helm, cert-manager, Rancher.** Helm CLI pinned (tarball + checksum). cert-manager via
`jetstack/cert-manager` with `crds.enabled=true`, pinned. Rancher:
```
helm install rancher rancher-latest/rancher --version 2.15.2 -n cattle-system \
  --set hostname=<Q1 name> --set replicas=1 --set bootstrapPassword=<new, stored in PASSWORDS.md>
```
Values saved to a file in the repo (the docs: "save your options — upgrades need the same ones"), **minus
the password**. Verify: `rollout status deploy/rancher`, UI returns 200 from `.195`, log in, set the admin
password (→ `PASSWORDS.md`), `local` cluster `Active`. Snapshot **`r02-rancher-up`**.

**Part 5 — Monitoring.** `rancher-monitoring-crd` + `rancher-monitoring` from `charts.rancher.io`, the chart
version that matches 2.15 (pinned at build). 🚨 **Retention is set explicitly:** `retention: 7d`,
`retentionSize: 15GiB`, Prometheus on a 20 Gi local-path PVC. Reason: `vm-ephemeral` is a **thin** pool and
a pool that fills stalls every VM on it at once (Phase 19). Verify: Grafana dashboards show node + pod
metrics; measure Prometheus disk after 24 h.

**Part 6 — The apps repo and GitOps.** New GitLab project **`production/rancher-k3s`** (Q3; the plan
first proposed `lab/rancher-apps`, so the `lab/…` paths below read `production/rancher-k3s/…` as built):
```
hello-lab/            tiny HTTP app + Dockerfile (ours; proves build → registry → deploy end to end)
fleet/hello-lab/      Deployment, Service, Ingress (<app>.k3s…), kustomization.yaml (image tag)
.gitlab-ci.yml        build → push :$CI_COMMIT_SHORT_SHA → bump the tag in fleet/ with a [skip ci] commit
fleet.yaml            Fleet bundle options
```
- **Images to `gitlab.gothamtechnologies.com:5050/lab/rancher-apps/...` ONLY** — hard rule **B10**: never
  `production/*`, which QA `.180` and PROD `.184` pull from.
- **Pulls:** K3s does not read Docker's `daemon.json`. `/etc/rancher/k3s/registries.yaml` gets an HTTP
  mirror for `:5050` plus a **read-only deploy token** (`read_registry`) — root-only file, never in git.
  ⚠️ Without it the first deploy fails as `ImagePullBackOff` with an error that reads like an auth or DNS
  fault.
- **Pull-model GitOps (primary):** a Fleet `GitRepo` in the `fleet-local` workspace watches `fleet/` over
  HTTP with a read-only deploy token. **GitLab holds no cluster credential.** ⚠️ *Fleet over a plain-HTTP
  git URL is believed to work but is NOT verified — tested first, in Part 6.*
- **Push-model (comparison, small):** one CI job runs `kubectl` from the runner using a **namespace-scoped
  ServiceAccount** (not cluster-admin), kubeconfig as a masked/protected CI variable. ⚠️ The runner is
  privileged with the Docker socket (ledger L19), so that token is effectively readable by anything on `.182`.
  **That trade-off is the point of comparing the two models.**

Verify: commit → pipeline green → Fleet `Ready` → `curl http://hello-lab.k3s…` returns the new commit SHA.
Snapshot **`r03-gitops-wired`**.

**Part 7 — Drills** (METHOD style: predict, run, measure, record the surprises).

| # | Drill | What it proves |
|---|---|---|
| D1 | Reboot the VM | Time to Rancher 200 and app 200; nothing needs a hand restart |
| D2 | Scale `deploy/rancher` to 0 | **The app keeps serving with the manager gone** — workloads do not depend on Rancher |
| D3 | Commit a broken manifest | What Fleet shows; does the old version keep running; recovery is `git revert` |
| D4 | Break the registry credential | Diagnose `ImagePullBackOff` from first principles, then from Rancher's UI — compare |
| D5 | Prometheus disk after 24 h | `retentionSize` is enforced, not assumed |
| D6 | Rancher 2.15.2 → next community patch/minor (when one exists) | The upgrade path community users are forced onto |

**Part 8 — Document.** This file's results section; `MEMORY.md` PHASE INDEX row + IP ledger (`.187`);
`README.md`; `refresh.sh` comment; credentials in `PASSWORDS.md` only.

**Optional Part 9 — a downstream cluster** (only if Andrew asks): one small kubeadm or K3s cluster for Rancher
to import or provision, to test that workflow without the CKA cluster.

## Snapshot chain — read before rolling back

`r01-os-ready` → `r02-rancher-up` → `r03-gitops-wired`. 🚨 **ZFS rolls back only to the MOST RECENT
snapshot** (Phase 19): once `r03` exists, `r01`/`r02` are unreachable without deleting the newer ones first.

## Risks

| Risk | Mitigation |
|---|---|
| Wrong-cluster `kubectl` from `.195` | Rancher kubeconfig never leaves the VM |
| Thin pool fills (Prometheus, images) | Disk capped at 120 G; explicit retention; D5 measures it |
| Community patch window closes on 2.15 | D6; record the cadence as a finding for the work decision |
| `refresh.sh` preflight aborts on one bad host | SSH from the PVE host once after build (stale host key rule) |
| CPU oversubscription 60/48 | Watch `%st` inside guests during Part 5/7 |
| A new credential lands in a tracked file | Bootstrap/admin password + deploy tokens → `PASSWORDS.md` / root-only files; `push_github.sh` gates |

## ✅ Answers (Andrew, Oct 27, 22:06)

- **Q1 — Names:** single name **`rancher.gothamtechnologies.com` → `192.168.1.187`** (no wildcard).
  ✅ Follow-up answered: the AI creates it via the AWS CLI, plus `hello-rancher` for the demo app.
- **Q2 — Provisioning:** **a new script for this phase** — the CKA track's `1-provision-vms.sh` stays untouched.
- **Q3 — Repo:** **`production/rancher-k3s`** in GitLab; the AI uses whatever credentials it needs.
  ✅ Scoped reading of **B10** confirmed ("OK in production space"): images go only to
  `production/rancher-k3s/<app>`, which cannot overwrite `production/capricorn/*` — the hazard B10 exists for.
- 🙋 *"You can do whatever you want in the new DNS and repo and VM - you control everything."*
- **Q4 — Write-up:** **no education track yet** — this phase file is the record. 🔄 *Superseded Oct 27,
  23:2x: Andrew asked for the track `education/rancher-k3s/` — see the EDUCATION TRACK plan above.*
- **Q5 — Build mode:** **build the whole thing, log errors, keep going where later parts do not depend on
  the failure**; Andrew returns to help with what is logged.

## ❓ Questions for Andrew (original, answered above)

- **Q1 — Names:** wildcard `*.k3s.gothamtechnologies.com` → `.187` (Rancher at `rancher.k3s…`, apps at
  `<app>.k3s…`)? Or a single `rancher.gothamtechnologies.com` and decide app names later?
- **Q2 — Provisioning:** add a backward-compatible `--config <file>` flag to the CKA track's
  `1-provision-vms.sh` (default behaviour unchanged, re-verified with `--check`) so one script builds both,
  **or** keep that study script untouched and provision 187 with a short Phase 20 script using the same
  `qm` recipe? (The first edits study material, so `CONVENTIONS.md`/`METHOD.md` apply.)
- **Q3 — Repo:** `lab/rancher-apps` in the `lab` group? Created by the AI via the GitLab API (root
  credentials read from `PASSWORDS.md` at that moment only).
- **Q4 — Write-up:** infra phase record only (this file), or a new **education track** with chapters
  (`education/k8s-rancher/`)? A track brings CONVENTIONS/METHOD, a prediction log and printable chapters.
- **Q5 — Build mode:** straight through Parts 0–6 stopping only on a failure or surprise, then the drills
  together? Or a checkpoint after each part?
