# phases/INDEX.md — area → file → what you get WRONG without it

Loaded at boot AFTER `MEMORY.md` and RESUME HERE. ⛔ **Budget: ≤ 8 KB, ≤ 300 bytes per row** (`tools/memory_budget.sh`).
**First touch of an area in a session: read its file, and SAY which file you read.** Grep big files, never read whole.
A pointer states the COST of skipping it; findings live in the phase file, not here. Status: 🔵 current · ⏸️ hold · ✅ closed.

| Touching this | Read FIRST | You will be WRONG without it |
|---|---|---|
| 🔵 **Kubernetes / CKA — Phase 18** (`.201–.206`, `education/k8s-cka-prep/`) | `phases/phase18_k8s_cka_build.md` + `education/k8s-cka-prep/{lab-parity,exercises}.md` | Start with `scripts/lab_check.sh`; reset only via `reset_cluster.sh` (`c03` is the ready point); run kubectl on control-1; updates frozen; B9 no ingress-nginx; new baseline ⇒ `lab_check.sh --record` |
| 🔵 **Rancher on K3s — Phase 20** (`.187`) | `phases/phase20_k3s_rancher.md` (▶️ BUILD RESULTS first) | CKA cluster never imported; kubeconfig stays on VM; community Rancher patches newest minor only; Fleet GitOps deploys |
| 🔵 **Visitor analytics (Matomo) — Phase 21** (`.184`) | `phases/phase21_www_analytics_matomo.md` (BUILD RESULTS first) | LIVE on both apps; UI LAN-only `https://192.168.1.184:8443` (entrypoint `lan`, not forwarded); tracker `/s/a.*` on dionysus+cap; home IP excluded; `.184` unbacked by decision |
| ⏸️ **Jenkins — Phase 17** (`.185`) | `phases/phase17_jenkins.md` | Paused at Part 4, not closed; B10; stack `capricorn-jenkins`; traps T1–T8 unfixed on purpose; spec lines marked 🔧 mechanics vs 📐 invention |
| ✅ **Docker Swarm — Phase 16** (`.191–.193`) | `phases/phase16_docker_swarm.md` (345 KB — grep) | B1; all traps C1–C7 closed — don't "re-fix"; ledger L1–L23; ch.8 Swarm↔k8s crib sheet (provenance marks) |
| ✅ **k3s / Redpanda — Phase 14** (`.186`) | `phases/phase14_k8s_redpanda_poc.md` | Frozen & running; never `k3s-uninstall.sh`; ~40 findings exist only in its demoted tail |
| 🗄️ **Storage tiers, VM placement, backups — Phase 19** | `phases/phase19_storage_tiers.md` | Thin pools (read CAP); placement question; `move-disk` drops snapshots; `c01/c02` unreachable behind `c03`; `vm-ephemeral` boot-import unproven |
| 🔧 **Build any host / script server / `www/`** | `phases/phase2_host_setup_automation.md` (+ `phase2b_fedora…`) | Two-step bootstrap; never `curl\|bash`; never run in `www/` trees; `--no-nas` for `.184`; script-server systemd unit; `/files/` is open guest access |
| 🔧 **Host RAM / drives / serials / BIOS** | `phases/phase0_hardware.md` | Identify drives by serial (nvme names drift); Z8 is not a DIMM donor; Z6 is 6/6 channels, 192 GB |
| 🔧 **Proxmox host config, kernels, ZFS, email alerts** | `phases/phase13_fable_proxmox_audit.md` + `phase1b_proxmox_kernel_upgrade_safe_try.md` | Kernel pin is deliberate; `--next-boot` trial first; backups to NAS only |
| 🔧 **Firewall, port-forwards, public exposure** | `phases/phase12_network_segmentation.md` | Perimeter closed except `.184`; some open ports are flagged for removal |
| 🔧 **GitLab / runner / CI / SonarQube** | `phases/phase3_…`, `phase4_…`, `phase5_…`, `phase6_…` | Runner socket = root (L19); containerd image store disabled on purpose; `phase5` holds `.180` renumber + autostart |
| **vm-www-1 `.184`, Traefik, PROD Capricorn + Dionysus** | `phases/phase7_local_www.md` (DIONYSUS section first) | `.184` never contacts the registry (images arrive via `docker load`); network design is load-bearing; access log since Nov 27 only; firewall truth is `phase12` |
| **Backups (vzdump → NAS)** | `phases/phase8_backups.md` | One CIFS storage per VM; backup test-restore drill cadence is event-driven |
| 🔵 **Education tracks / chapters / docx / highlight pass** | `education/CONVENTIONS.md` + `METHOD.md` + track `README.md`; tree moves → `phases/phase15_education_program.md` | 10 pt figure floor; docx rebuild rewrites every file (commit only yours); highlight skips tables/code; phase15 is a RECORD — re-running undoes the layout |
| ⛔ **OpenClaw (`.185` before Aug 19)** | `phases/phase11_openclaw.md` | VM destroyed; nothing actionable; any `.185` in it means OpenClaw |
| **VM create / clone / template 9000 / cloud-init / `nofail`** | `reference/vm_build.md` | New-VM recipe; `.184` mounts no NAS; `nofail` cost |
| **VM settings, AUTOSTART, PATCHING policy, RAM** | `reference/vm_standard.md` | `cache=none`/`aio=native`; `onboot` list; masked timers lie in config; "Current VMs Feb 20" table is stale |
| **`refresh.sh` / patching hosts** | `reference/patching.md` | Never refresh `.186/.19x/.20x`; GitLab safe-reboot checklist; bash assoc-array hash order |
| **SSH keys, remote access (laptop/tailnet), credentials layout** | `reference/access_and_remote.md` | `agamache` not `andrew`; `authorized_keys2`; two remote routes; three gaps |
| **IP allocation, ARP sweep, K8s node addressing** | `reference/hosts_and_addressing.md` | Ping lies; household `.200/.215/.217/.220/.231`; `.207–.220` sweep first |
| **Git remotes, push scripts, secret hygiene** | `reference/git_and_secrets.md` | Scripts only; GitLab mirror disjoint by design; `push_github.sh` false "uncommitted" warning; purge ≠ rotation |
| **Dev box `.195`, OS upgrade, `piper-say`** | `reference/dev_workstation.md` | `.195` is a VMware guest on the Z8; script server cannot build its own host |
| **Why/how MEMORY was slimmed; old status & history** | `reference/memory_archive.md` + tag `pre-memory-diet` | Old Jan–Feb status bullets are stale — don't revive them |
