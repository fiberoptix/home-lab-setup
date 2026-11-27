# Home Lab Project — AI Memory (CORE)

**Purpose:** boot context for the AI. No humans read this. ⛔ **Budget: ≤ 30 KB (`tools/memory_budget.sh`).**
Only facts that make you WRONG if missing live here. Everything else loads ON TOUCH through `phases/INDEX.md`.
Verbatim history of what used to be here: tag `pre-memory-diet`, `phases/*.md`, `reference/*.md`.

---

## 1. Scope (stay in your lane — full text in `CURSOR_RULES`)
This repo owns the **infrastructure layer** (HP Z6 G4 Proxmox host, NAS, networking, VM lifecycle, host-level
reachability) and **educational R&D done in the lab** (`/education`). It does **NOT** own the **application
layer** — Capricorn and other real apps (state, images, DB, app compose) belong to their own projects. Never
"reconcile" app compose files or images here; label captures as read-only snapshots.

## 2. ⚠️ This repo is on a CIFS share — the editor cache goes stale (found Aug 12, 2026)
`/home/agamache/DevShare` → `/mnt/DevShare` (CIFS). Observed: edits landed corrupted, read-backs returned stale
text that hid the damage, and a stale editor buffer **wiped 3 uncommitted AI edits** (204 → 158 lines).
1. **Verify important edits from the SHELL**, not a read-back: `wc -l`, `md5sum`, `rg -c '<phrase>'`.
2. **Audit deletions before commit:** `git diff <f> | rg '^-' | rg -v '^---'` shows only lines you meant to remove.
3. If Andrew has a file open and its line count disagrees with disk, tell him to close and reopen it before saving.
4. ⭐ **Commit early** — an uncommitted edit is unrecoverable. Prefer ONE atomic, asserted write over many small ones.

## 3. 🚨 Hard rules (WRONG/DAMAGE if missing). ⛔ The NEVER-list (B1, B10, B9, `.186`, `.201–.205`, `.184`, `curl|bash`) is in `CURSOR_RULES` — stated once.
**Applications / images**
- Rancher kubeconfig never leaves its VM; B10 is scoped: images go ONLY to `production/rancher-k3s/<app>` for Phase 20.
**Kubernetes**
- **B3** Do NOT enable containerd's CRI in `setup_docker.sh` (Docker hosts want it off); fix containerd on the five nodes.
- `.201`–`.205`: auto-updates **frozen** (masked); **never** add them to `refresh.sh` (parallel reboot loses etcd quorum);
  **not** in `critical-nightly` (it caused etcd elections). Reset with `scripts/reset_cluster.sh` — never by hand.
**Hosts / scripts**
- Bootstrap in TWO steps (`wget`/`curl -fsSLO`, then `bash`). **Never `curl | bash`** (stdin eats the script's `read`).
- **Never run `host_setup.sh` from inside `www/ubuntu/` or `www/fedora/`** (it zeroed all the scripts, Aug 21).
- `www/smb_credentials` stays **above** the nginx mount; **never mount `www/` itself**. Name-based `smb_credentials` deny stays.
- `script-server` is started at boot by **host unit `/etc/systemd/system/script-server.service`** (not in git) —
  `restart: "no"` in compose is **deliberate**. Restart with `systemctl restart script-server` (NOT `start` after `down`).
  `http://192.168.1.195/files/` serves untracked sibling `www-files`: **open guest access — nothing sensitive.**
- **`.184` Traefik: every router MUST carry `entrypoints=websecure`** (or `lan` for Matomo only). An unpinned router also attaches
  to the LAN-only `lan` :8443 entrypoint (Matomo UI). Matomo owns `/s/a.js` + `/s/a.php` on the dionysus/cap hosts (`phase21`).
  **Matomo upgrades ONLY via `/opt/matomo/upgrade.sh`** — a plain `docker compose up -d` after a tag change silently keeps the OLD code.
- **The Proxmox host does NOT answer ping** (datacenter firewall). Use `ssh` or `nc -z .150 8006`.
- Login user on every VM is **`agamache`**, never `andrew` (a wrong user looks exactly like a missing key).
  Host key auth works via `/root/.ssh/authorized_keys2` — **not** `authorized_keys` (a PVE-managed symlink).
- **Runner `.182` is privileged with the host Docker socket** (= root on the runner). **containerd image store is DISABLED
  on purpose** (it breaks pushes to the GitLab registry) — do not "clean it up".
**Storage / backups / patching**
- **Backups go to the NAS** (`/ProxmoxBackups/<vm>/`), never NVMe. Place a VM by one question: *can this project rebuild
  it?* yes → `vm-ephemeral`; no → `vm-critical` + add its VMID to `critical-nightly`.
- **All VM pools are THIN.** Read `zpool list` **CAP**, never the PVE GUI. ≥ 70 % flag, ≥ 80 % STOP.
- **ZFS rolls back only to the MOST RECENT snapshot.** PVE `move-disk` silently DROPS snapshots — use
  `proxmox/build-scripts/move_k8s_node_pool.sh` (`--dry-run` only unless told).
- **`refresh.sh` is the ONLY patch path** (`unattended-upgrades`/apt timers are *masked* everywhere). `.186`, `.191`–`.193`
  and `.201`–`.205` get NO automatic patching. `qm set` on a running VM only STAGES a CPU/RAM change.
- **`onboot` describes the NEXT boot, not now.** `onboot 1`: 180–185, 187. `onboot 0`: 186, 191–193, 201–205 (after a
  host reboot start them by hand; Swarm first for Phase 17). Startup order ≠ readiness.
- Kernel: host pinned to **`7.0.14-26-pve`** (since Oct 27, 2026; fallbacks `7.0.14-4`, `7.0.6-2`). Test with `--next-boot`.
**Secrets / git**
- **Push only with `./push_gitlab.sh` (first) and `./push_github.sh`.** Never a raw `git push`. GitHub is PUBLIC.
- **A purge is not a rotation**: the master password leaked to public GitHub (June 2026) and was never rotated; a NAS/SMB
  password was found in 4 tracked files Nov 4 (redacted, **not rotated** by Andrew's choice; `push_github.sh` step 5 gates it).
- Credentials live ONLY in `PASSWORDS.md` (on demand, never at boot), `/proxmox/credentials`, `/proxmox/nas_credentials`.
  Files say `[See PASSWORDS.md]`. `MEMORY_SECRET.md` content never goes into a tracked file.
**Education**
- Track 1's `figcheck.py k8s-k3s-redpanda` **exits 1 BY DESIGN** (four accepted sub-10pt figures) — do not "fix" it.
- Swarm→K8s chapter-8 conversion is **DEFERRED** until the firm's real Swarm is known — keep the Swarm and its snapshots.

## 4. Hosts (measured Aug 24, 2026 + later changes; `qm list` / `ssh` are the source of truth)
| IP | Host | Notes |
|---|---|---|
| **.150** | Proxmox (HP Z6 G4, 192 GB, PVE 9.2.24) | `ssh root@…` key auth; **no ping**; Tailscale runs ON it (subnet router, `pve` 100.108.209.77) |
| .120 | NAS (Synology, SMB) | `fiberoptix`; backups, `/mnt/DevShare` |
| **.180** | `vm-docker-qa-1` — Capricorn QA + Dionysus QA (`:5101`/`:5102`) | plain docker compose (not Swarm/k8s); VMID 200 is free |
| .181 / .182 / .183 | GitLab / `vm-gitrun-1` (runner; `gitlab-runner-1` is only the registration name) / `vm-sonarqube-1` | |
| **.184** | `vm-www-1` — Traefik + Capricorn PROD + splash + **Dionysus PROD** (Nov 27, 2026) | PROD-LOCAL, no NAS, no backups (by decision); Traefik access log since Nov 27; **Matomo UI `https://192.168.1.184:8443` (LAN only)** |
| .185 | `vm-jenkins-1` — Jenkins (Phase 17, on hold) | OpenClaw destroyed Aug 19 — nothing in `phase11` is actionable |
| .186 | `vm-k8-redpanda-1` — k3s/Redpanda POC | FROZEN, running, `onboot 0` |
| .187 | `vm-k3s-rancher-1` — K3s + Rancher (Phase 20) | `onboot 1`, order 4 |
| .191–.193 | `docker-swarm-1/2/3` (Phase 16) | `onboot 0`, disposable |
| **.195** | **THIS workstation `VM-UBUNTU-01` — a VMware guest on the Z8** | AI + repo + script server; not in `qm list` |
| **.201–.205** | `vm-k8s-cka-control-1/2/3`, `worker-1/2` (Phase 18) | VMIDs = last octet; `onboot 0` |
| .206 | kube-vip VIP — no VM behind it | RESERVED |
| 9000 | `tmpl-ubuntu-2404-cloudinit` | template; never started |
- **DHCP pool `.221–.250`.** Household: `.200` Mac mini/Plex, `.231` Denon, `.215/.217/.220` (below pool, old leases).
  **Sweep with ARP before allocating anything in `.207–.220`** (`ip neigh`, not ping — `.150` proves ping lies).
- Pools: `rpool` (mirror 2×500 GB), `vm-critical` (mirror 2×1 TB), `vm-ephemeral` (stripe 2×1 TB, rebuildable tier).
- All VMs: Ubuntu 24.04 LTS. Domain `gothamtechnologies.com` (Route53): `cap.*` = PROD-local on .184, `capricorn.*` = GCP on demand.
  Public ingress = Traefik on .184 only. Admin = LAN or Tailscale to the host. Web UI https://192.168.1.150:8006.
- Full prose (ARP, K8s node addressing, household detail): `reference/hosts_and_addressing.md`.

## 5. Distilled principles (the house rules every phase re-derived)
- **Verify, don't assume; a measurement is not a value.** Probe the capability you will use, not a proxy; prove the negative
  before building the positive; show an instrument can find something before trusting its "found nothing".
- **The layer that reports is not the layer that decides** (`20auto-upgrades` says "1" on masked hosts; GUI said 71 % at 6 %;
  PVE showed `.184` at 90 % RAM with 72 % `MemAvailable` — it counts guest page cache).
- **A fact in N places is N−1 lies after one edit** — `rg` for it before calling anything unresolved or stale.
- **A check that runs BEFORE the thing that breaks it proves nothing** (the keyring false green).
- **If a spec states a number, MEASURE THAT NUMBER**; a trigger that is an opinion is an optional step.
- **A to-do that outlives its completion invites redoing the work** — re-check "ask first" items still exist.
- Always **independently verify what Andrew reports having done**; reversible option first; terse ≠ displeased.

## 6. Apps (not ours)
Capricorn — GitLab `production/capricorn`, GitHub `fiberoptix/capricorn`, QA `http://192.168.1.180:5001` (auto-deploy on
`develop`), PROD `https://cap.gothamtechnologies.com`, GCP on demand; local path `…/unified_ui_DEV_PROD_GCP/capricorn`.
Dionysus (wine search; since Nov 27, 2026) — GitLab `production/dionysus` only (never GitHub), QA `http://192.168.1.180:5101` (auto on
`develop`), PROD `https://dionysus.gothamtechnologies.com` on `.184` (manual button on `production`); local path `…/dionysus`.
Infra facts: `phase7` → DIONYSUS. Its own lab notes: `../dionysus/project/LAB_REFERENCE.md`.

## 7. Where things are (this is the whole loading contract)
`CURSOR_RULES` → this file → `phases/current_phase.md` RESUME HERE → **`phases/INDEX.md`** (area → file → cost of skipping)
→ `MEMORY_SECRET.md`. **First touch of an area: read its INDEX row's file and SAY which file you read.**
**CURRENT PHASE: 18 — Kubernetes/CKA (Stage 3 drills).** Jenkins (17) on hold. Phases 0–16, 19 closed; 20 built.
