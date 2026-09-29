# 🏠 Home Lab Setup - Proxmox DevOps & Learning Lab

**A FREE DevOps/QA home lab on Proxmox VE — and the R&D rig behind four hands-on study tracks**

[![Status](https://img.shields.io/badge/Status-Operational-brightgreen)]()
[![Proxmox](https://img.shields.io/badge/Proxmox-VE_9.2.20-orange)]()
[![Kernel](https://img.shields.io/badge/Kernel-7.0.14--4--pve_(pinned)-informational)]()
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.35.8_HA_(kubeadm)-326ce5)]()
[![Hardware](https://img.shields.io/badge/Hardware-HP_Z6_G4-blue)]()

---

## 📋 Project Overview

This repository documents a **professional-grade DevOps home lab** on a single HP Z6 G4 running
Proxmox VE, built entirely from free software. It does two jobs:

1. **A working DevOps platform** — GitLab CE with a container registry, GitLab CI runners, SonarQube
   quality gates, a Jenkins controller, and a local production web server (Traefik + Let's Encrypt).
2. **A learning lab** — Kubernetes (a five-node HA `kubeadm` cluster and a k3s + Redpanda cluster),
   a three-manager Docker Swarm, and Jenkins, each written up as a printable study track where every
   command was run on this hardware and every output quoted is real.

It was built to deploy the **Capricorn** project (a unified personal finance application) through a
full pipeline to **QA** (on this lab) and **PROD** (a local production server on this lab):

- 🌐 **Live Demo (PROD-Local):** https://cap.gothamtechnologies.com ← **Check it out!**
- ☁️ **GCP Instance:** https://capricorn.gothamtechnologies.com (available on-demand)
- 📦 **GitLab Repository:** http://gitlab.gothamtechnologies.com/capricorn

**Total Hardware Cost:** $3,894  
**Monthly Operating Cost:** ~$15-20 (electricity)  
**Commercial Equivalent:** ~$70-100/month SaaS services

---

## ✨ What's New (June → September 2026)

- ☸️ **A real HA Kubernetes cluster (Phase 18):** five `kubeadm` nodes — **3 control planes with
  stacked etcd + 2 workers** — behind a **kube-vip** virtual IP, **Kubernetes v1.35.8**, **Calico**
  networking. Failover measured at **17 s** after an abrupt power-off of the VIP holder; a snapshot
  baseline whose rollback was *proven* with planted markers. Written up as study chapters 01–04 and
  now used for **CKA** exam drilling.
- 🐳 **Docker Swarm (Phase 16):** a three-manager Swarm running Capricorn, deployed by pipeline, with
  seven failure "traps" planted, triggered and written up — 8 chapters.
- 🛠️ **Jenkins (Phase 17):** a controller + SSH agent wired to GitLab (on hold at the Swarm-deploy step).
- 🗄️ **Storage tiers (Phase 19, Sep 28):** both VM pools switched to **thin provisioning** (the GUI's
  "71% used" was reservation — real allocation was 6%), the Kubernetes cluster moved onto the mirrored
  pool **with its snapshots intact**, and critical VMs now **back up nightly** to the NAS.
- 💾 **Backups & alerting:** nightly VM backups (restore drills passed), a nightly **host
  configuration** backup, and **email alerts** for pool capacity, pool faults, failing drives and
  failed backups.
- 🔄 **One patching policy lab-wide:** no VM updates itself; updates happen deliberately — the
  `refresh` tool for core VMs, a one-node-at-a-time drain drill for Kubernetes, and a pinned-kernel
  procedure for the host (now **PVE 9.2.20**, kernel **7.0.14-4**).
- 🔒 **Perimeter lockdown (Phase 12):** the public web server is an inbound-only DMZ — it can reach the
  internet but nothing else on the LAN; deployments are pushed to it, it never pulls.
- 🔍 **Host audit (Phase 13):** 25 findings, email alerting, ARC tuning, a pool rebuilt for 4K sectors,
  a GitLab backup **test-restore drill** into an isolated network.
- 🖥️ **Two-distro host automation:** one-command setup for Ubuntu **and** Fedora, plus offline USB kits.

---

## 🖥️ Hardware Specifications

**Platform:** HP Z6 G4 Workstation

| Component | Specification |
|-----------|---------------|
| **CPU** | Intel Xeon Platinum 8168 (24 cores / 48 threads @ 2.7GHz, single socket) |
| **RAM** | **192GB** DDR4 ECC (6x 32GB, all 6 channels populated) |
| **Boot Storage** | 2x 500GB NVMe (WD Blue SN5100, ZFS mirror) |
| **VM Storage** | 4x 1TB NVMe (Lexar NM620) on an HP Z Turbo Drive Quad Pro card, behind Intel VMD |
| **Network** | 2x 1GbE onboard NICs |
| **Total Storage** | ~3.3TB usable across three ZFS pools |

All six drives were at **0–2% wear with zero media errors** when last measured (Sep 28, 2026).

---

## 🗄️ Storage & Data Protection

**Two tiers, chosen by one question — *can this project rebuild the VM from scratch?***

| Pool | Layout | Holds | Protection |
|---|---|---|---|
| `rpool` | 2x500GB **mirror** | Proxmox OS, ISOs | Mirror + nightly host-config backup |
| `vm-critical` | 2x1TB **mirror** | GitLab, SonarQube, Jenkins, WWW/PROD, **the Kubernetes cluster** | Mirror + **nightly VM backups** to the NAS |
| `vm-ephemeral` | 2x1TB **stripe** | QA, CI runner, k3s POC, Docker Swarm, template | Rebuildable from this repo by design |

- **Thin-provisioned** — a VM disk uses only what it has written. On Sep 28 real allocation was
  **8%** (`vm-critical`) and **3%** (`vm-ephemeral`).
- ⚠️ **Watch `zpool list` CAP, not the Proxmox GUI.** A thin pool that fills stalls every VM on it, so
  an hourly check emails at **70%** and **80%**, and the AI's startup checklist stops at 80%.
- **Scheduled jobs:** host config 01:30 · GitLab 02:00 · critical tier (SonarQube, Jenkins, 5 k8s
  nodes) 02:30 · monthly ZFS scrub and TRIM. Everything is kept on the NAS, never on the NVMe it protects.
- 🚨 **Lesson recorded:** Proxmox's built-in *move disk* silently drops snapshots — the cluster was
  moved with `zfs send -R` and every snapshot checked by GUID
  ([`move_k8s_node_pool.sh`](proxmox/build-scripts/move_k8s_node_pool.sh)).

Full record: [`phases/phase19_storage_tiers.md`](phases/phase19_storage_tiers.md).

---

## 🏗️ Infrastructure Architecture

**15 VMs running + 1 template** — read live from `qm config` on **Sep 28, 2026**:

| VMID | Name | Purpose | RAM | Cores | Disk | Pool | onboot |
|---|---|---|---|---|---|---|---|
| 180 | `vm-docker-qa-1` | Capricorn QA (docker compose) | 12GB | 8 | 100GB | ephemeral | ✅ |
| 181 | `vm-gitlab-1` | GitLab CE 19.3 + container registry | 24GB | 8 | 500GB | critical | ✅ |
| 182 | `vm-gitrun-1` | GitLab Runner 19.3 (Docker executor) | 12GB | 8 | 100GB | ephemeral | ✅ |
| 183 | `vm-sonarqube-1` | SonarQube 26.1 | 12GB | 4 | 30GB | critical | ✅ |
| 184 | `vm-www-1` | Traefik + Capricorn PROD + splash (DMZ) | 8GB | 8 | 50GB | critical | ✅ |
| 185 | `vm-jenkins-1` | Jenkins 2.568 LTS controller + agent | 8GB | 4 | 60GB | critical | ✅ |
| 186 | `vm-k8-redpanda-1` | k3s + Redpanda POC (frozen) | 16GB | 8 | 300GB | ephemeral | ⚠️ 0 |
| 191–193 | `docker-swarm-1..3` | Three-manager Docker Swarm | 4GB each | 2 each | 40GB each | ephemeral | ⚠️ 0 |
| 201–203 | `vm-k8s-cka-control-1..3` | Kubernetes control planes (stacked etcd) | 4GB each | 2 each | 40GB each | critical | ⚠️ 0 |
| 204–205 | `vm-k8s-cka-worker-1..2` | Kubernetes workers | 4GB each | 2 each | 40GB each | critical | ⚠️ 0 |
| 9000 | `tmpl-ubuntu-2404-cloudinit` | Cloud-init template — **stays stopped** | — | — | — | ephemeral | — |

- **All guests run Ubuntu 24.04 LTS.** The kube-vip virtual IP is **`.206`**, with no VM behind it.
- **Resources:** 124GB of 192GB RAM allocated; **64 vCPUs on 48 threads** (CPU is the tighter constraint).
- 🚨 **The lab VMs are `onboot=0` and stay DOWN after a host reboot** — 186, the Swarm and the
  Kubernetes cluster must be started by hand (control planes first, then workers).
- ⛔ **OpenClaw** (Phase 11, an AI agent server) was destroyed Aug 19, 2026; its VMID and IP are Jenkins now.

**VM Configuration Standard:** CPU type `host` · disk `iothread=1,discard=on,cache=none,aio=native` ·
`firewall=1` on every NIC · QEMU guest agent on every VM (backups freeze the filesystem first).

> **`MEMORY.md` is authoritative** for the host/IP inventory. This table is a convenience copy and
> will drift; when the two disagree, believe `MEMORY.md` — or better, re-read `qm config` on the host.

**Remote access:** 🔒 **Tailscale** — the **Proxmox host is a subnet router** advertising the lab LAN,
so tailnet devices reach every VM by its LAN address (no VM runs Tailscale itself). 🌐 **Public
HTTPS** only for the Capricorn site and splash page, through Traefik on the DMZ box.

---

## 🔁 Operations

| Task | How |
|---|---|
| **Patch the core VMs** (180–185) | `refresh` on the host — parallel update + reboot with a live status screen, `tmux`-protected |
| **Patch the Kubernetes nodes** | Never `refresh` (a parallel reboot loses etcd quorum): drain → update → reboot → `Ready` → uncordon, one node at a time |
| **Patch the host** | `update` (`apt full-upgrade`, never `apt upgrade`), then check the boot report: the kernel **pin** decides what boots, and a known-good fallback must still be on the boot partitions |
| **New host kernel** | One-shot `proxmox-boot-tool kernel pin --next-boot` trial at the console before making it permanent |
| **Automatic updates** | **Off on every VM** (masked *and* stopped) — nothing changes unless someone chose to change it |
| **Place a new VM** | Rebuildable → `vm-ephemeral`; otherwise `vm-critical` **and** add it to the nightly backup job |

Why the kernel is pinned: a `6.17.4-2` kernel once broke NVMe boot on this machine's Intel VMD
controller. Every kernel change since has been reversible and console-gated —
[`phase1a`](phases/phase1a_proxmox_upgrade_fail_rollback.md) (the failure) and
[`phase1b`](phases/phase1b_proxmox_kernel_upgrade_safe_try.md) (the safe method).

---

## 📊 Project Status

| Phase | Description | Status |
|-------|-------------|--------|
| 0 | Hardware installation | ✅ Complete |
| 1 · 1a · 1b | Proxmox + ZFS · kernel failure & rollback · safe kernel upgrade | ✅ Complete |
| 2 · 2b | Host setup automation — Ubuntu · Fedora | ✅ Complete |
| 3 · 4 | GitLab server · GitLab Runner | ✅ Complete |
| 5 · 6 | CI/CD pipelines · SonarQube quality gates | ✅ Complete |
| 7 | Local WWW / PROD server (Traefik + Let's Encrypt) | ✅ Complete |
| 8 | VM backups to NAS (GitLab disaster recovery) | ✅ Complete |
| 11 | OpenClaw AI agent server | ⛔ Built, then destroyed Aug 19, 2026 |
| 12 | Network perimeter lockdown (.184 as DMZ) | ✅ Jul 8, 2026 |
| 13 | Proxmox host audit + fixes | ✅ Jul 9, 2026 |
| 14 | Kubernetes (k3s) + Redpanda POC | ✅ Closed Aug 12, 2026 |
| 15 | Education program (multi-track study repo) | ✅ Aug 12, 2026 |
| 16 | Docker Swarm | ✅ Aug 19, 2026 |
| 17 | Jenkins | ⏸️ On hold (resume at Part 4) |
| 18 | **Kubernetes HA (`kubeadm`) + CKA prep** | 🔵 **Active** — built Sep 17; CKA drilling next |
| 19 | Storage tiers — thin pools, backups by tier | ✅ Sep 28, 2026 |
| 20+ | Backlog, in order: OpenSearch · Prometheus + Grafana · Redpanda Connect + Debezium CDC · MongoDB + Postgres · SAML/OIDC (authentik) · Ansible | 💭 Planned |

**Services:**
- ✅ Proxmox VE **9.2.20** at 192.168.1.150 (kernel **7.0.14-4-pve**, pinned; known-good `7.0.6-2` kept as boot fallback)
- ✅ GitLab CE **19.3.2** at 192.168.1.181 + container registry at `gitlab.gothamtechnologies.com:5050`
- ✅ GitLab Runner **19.3.2** at 192.168.1.182
- ✅ SonarQube **26.1** at 192.168.1.183:9000
- ✅ Jenkins **2.568.3** at 192.168.1.185:8080
- ✅ Capricorn QA at 192.168.1.180:5001 · PROD at https://cap.gothamtechnologies.com
- ✅ Kubernetes **v1.35.8** HA cluster at .201–.205, API through the kube-vip VIP **.206**
- ✅ Docker Swarm (Docker **29.7.2**) at .191–.193 · k3s **v1.36.2** + Redpanda at .186
- ✅ Script server at http://192.168.1.195/ — host setup for Ubuntu and Fedora

---

## 📖 Education Tracks

[`education/`](education/README.md) holds printable study material written on top of the lab — not
tutorials, but chapters where **every command was executed on real infrastructure and every output
quoted is real**, including the failures. Each track has Graphviz diagrams, tested configuration
artefacts, and a Word build for printing.

| Track | Subject | Status |
|---|---|---|
| [k8s-k3s-redpanda](education/k8s-k3s-redpanda/README.md) | Kubernetes (k3s), Redpanda, and an order management system built on both — including the failure drills | 7 chapters |
| [docker-swarm](education/docker-swarm/README.md) | A three-manager Swarm: shipping to it, deploying through a pipeline, breaking it on purpose, and a Swarm↔Kubernetes crib sheet | 8 chapters |
| [jenkins](education/jenkins/README.md) | A controller built from nothing, wired to GitLab, deploying to the same Swarm — then made to fail on purpose | 3 chapters (on hold) |
| [k8s-cka-prep](education/k8s-cka-prep/README.md) | Kubernetes done properly: a five-node `kubeadm` cluster with an HA control plane behind kube-vip, then CKA drilling | 4 chapters (active) |

Track 1 grew out of [Phase 14](phases/phase14_k8s_redpanda_poc.md): a 3-broker Redpanda cluster on
k3s with a Python producer/consumer OMS, reconciling 10,000 events to exactly 800,000 shares across
repeated hard kills. Writing conventions for every track: [`education/CONVENTIONS.md`](education/CONVENTIONS.md);
the learning method: [`education/METHOD.md`](education/METHOD.md).

---

## 📁 Repository Structure

```
home-lab-setup/
├── README.md                    # This file
├── CURSOR_RULES                 # AI agent startup checklist and project rules
├── MEMORY.md                    # Current infrastructure state (authoritative)
├── MAKE_MEMORIES                # How the memory files are maintained (and pruned)
├── push_gitlab.sh / push_github.sh   # The ONLY way this repo is pushed (GitHub copy is curated)
│
├── phases/                      # One record per phase: plans, commands, failures, results
│   ├── current_phase.md         # ▶️ RESUME HERE + the current session handoff
│   ├── phase0 … phase8          # Hardware, Proxmox/ZFS, host automation, GitLab, CI/CD, SonarQube, WWW, backups
│   ├── phase11 … phase13        # OpenClaw (history), perimeter lockdown, host audit
│   ├── phase14 … phase17        # k3s + Redpanda, education program, Docker Swarm, Jenkins
│   ├── phase18_k8s_cka_build.md # Kubernetes HA + CKA (active)
│   └── phase19_storage_tiers.md # Storage tiers, thin pools, backups by tier
│
├── proxmox/
│   ├── Home_Lab_Proxmox_*.md    # Build plan, design, storage, install notes
│   └── build-scripts/           # Deployed to the host's /usr/local/bin:
│       ├── refresh.sh           #   parallel VM update + reboot (tmux-protected)
│       ├── proxmox-update.sh    #   host full-upgrade + boot/kernel report
│       ├── zfs-capacity-alert.* #   hourly pool capacity/health email
│       ├── pve-host-config-backup.*  # nightly host-config archive to the NAS
│       └── move_k8s_node_pool.sh     # snapshot-preserving move of a k8s node between pools
│
├── education/                   # Printable study tracks (see above) + shared tools
├── tools/                       # Repo maintenance helpers (e.g. demote_block.py)
├── www/                         # Script server: nginx + ubuntu/ and fedora/ host-setup trees,
│                                #   plus generated offline USB kits (ubuntu_local/, fedora_local/)
└── vmware/                      # VMware ESXi reference (replaced by Proxmox)
```

---

## 🚀 Quick Start

### Access Proxmox
```bash
https://192.168.1.150:8006      # Web UI (root)
ssh root@192.168.1.150          # SSH
```

### Access GitLab and SonarQube
```bash
http://192.168.1.181                        # GitLab (root)
http://gitlab.gothamtechnologies.com:5050   # Container registry
http://192.168.1.183:9000                   # SonarQube (admin)
```

### Setup New Host

Open **http://192.168.1.195/** on the new machine — the landing page lists the current command for
each distro with a copy button, and rewrites the address to whatever host you reached it on. It is
the copy to trust; the ones below are here for when you cannot open a browser.

```bash
# Download, THEN run. Not sudo -- the script escalates on its own.
wget http://192.168.1.195/ubuntu/host_setup.sh      # Ubuntu / Debian
bash host_setup.sh

# Fedora (stock Fedora has no wget):
#   curl -fsSLO http://192.168.1.195/fedora/host_setup.sh
#   bash host_setup.sh

# Includes: SSH keys, sudo config, Cockpit web admin, Docker, SMB mount

# Flags, all valid on either distro:
#   --no-nas            DMZ / prod-local host that must not reach the NAS
#   --hostname <name>   set the hostname (also fixes /etc/hosts, pins cloud-init)
#   --server            headless host: no Chrome, no Cursor, no GNOME settings.
#                       Usually unnecessary -- auto-detected from gnome-shell.
```

⚠️ Do not run `host_setup.sh` from inside `www/ubuntu/` or `www/fedora/`. It downloads its
sub-scripts next to itself, and nginx serves those same files off disk, so it overwrites the library
with truncated copies of itself. Both scripts now refuse to start there; see phase2 for the detail.

⛔ **Never `curl … | bash`.** The script arrives on stdin, so the confirmation prompt's `read` eats
the next byte of the script itself. If you want a single line, keep the file real:
`cd "$(mktemp -d)" && wget -q http://192.168.1.195/ubuntu/host_setup.sh && bash host_setup.sh`

The Kubernetes nodes use a separate, portable three-script build
([`education/k8s-cka-prep/scripts/`](education/k8s-cka-prep/scripts/)) — written to be reused on
other infrastructure, so it has no dependency on this script server.

### 💾 Offline / USB build kits (both distros) — when the script server is unreachable

🚨 **The script server cannot build the machine it runs on.** `192.168.1.195` is a VMware guest on the
Z8 workstation, so dual-booting that Z8 into Fedora takes Windows down, which takes VMware down, which
takes the script server down — at exactly the moment the new install wants to fetch from it.

`www/fedora_local/` and `www/ubuntu_local/` are **self-contained kits** for that case. `host_setup.sh`
detects that its sub-scripts are already beside it and skips the network entirely:

```bash
cd www && ./make_local_kits.sh --with-creds   # builds BOTH kits (omit the flag to leave the
                                              # NAS password out; the script prompts instead)
cp -r www/fedora_local /path/to/usb/          # carry it

# on the new Fedora box
cp -r /run/media/$USER/<LABEL>/fedora_local ~/fedora_local
cd ~/fedora_local && bash host_setup.sh --hostname AGAMACHE-FEDORA-WKS
```

It prints `OFFLINE MODE`. Internet is still needed for Docker, Chrome and Cursor (all public repos) —
but nothing on the lab network is.

⛔ **Never hand-edit `www/*_local/*.sh`** — they are generated copies. Edit the source tree and
regenerate. `./make_local_kits.sh --check` tells you whether a kit has gone stale.

⚠️ With `--with-creds` the kit holds the **plaintext NAS password**, and FAT32/exFAT sticks cannot
enforce `0600` — treat the USB as a secret, or leave the credential out.

Every server gets **Cockpit** at `https://<host>:9090` (log in with the system password — it
authenticates via PAM). Self-signed cert, so use Chrome or Firefox.

---

## 🔐 Security

What is actually in place (checked Sep 28, 2026):

- ✅ **No infrastructure is exposed publicly.** Only the Capricorn site and splash page are reachable
  from the internet (80/443 → Traefik on `.184`); GitLab, SonarQube, Jenkins and Proxmox are LAN/Tailscale only.
- ✅ **The public box is a DMZ:** Proxmox firewall rules let `.184` reach only the internet and the
  gateway — it cannot open connections to any other LAN address — and accept SSH only from the CI
  runner, the admin workstation and the host. Deployments are **pushed** to it; it never pulls.
- ✅ **SSH key authentication** from the admin workstation to every VM and the host.
- ✅ **Secrets stay out of the public repo:** passwords live in git-ignored files, and
  `push_github.sh` refuses to push if a tracked file or the outgoing diff looks like a credential.
- ✅ **Let's Encrypt** certificates via DNS-01 (Route53).
- ⚠️ **Deliberately deferred:** password SSH logins are still enabled and the Proxmox web UI has no
  two-factor login; UFW is not enabled inside the VMs. Recorded as a conscious decision, not an oversight.

---

## 🛠️ Technology Stack (All FREE)

**Infrastructure:** Proxmox VE 9.2 · ZFS · Ubuntu 24.04 LTS guests · cloud-init templates · Tailscale

**DevOps:** GitLab CE (source, CI/CD, registries) · GitLab Runner · SonarQube · Jenkins ·
Traefik · Let's Encrypt · AWS Route53

**Containers & orchestration:** Docker · Docker Swarm · Kubernetes (`kubeadm` v1.35 HA with kube-vip
and Calico; k3s) · Redpanda (Kafka-compatible streaming)

**Operations:** vzdump backups to a NAS · ZFS snapshots · email alerting (ZED, smartd, backup jobs,
pool capacity)

**Planned:** Prometheus + Grafana, OpenSearch, Debezium CDC, authentik (SAML/OIDC), Ansible

---

## 📝 Notes

**Why Proxmox over ESXi?** Native ZFS (no VROC driver issues), full Linux CLI, LXC containers,
built-in backups (vzdump), free clustering, and no UEFI boot issues.

**GitLab Runner:** Docker-in-Docker was unreliable here — mount the host socket instead
(`/var/run/docker.sock`). The registry runs over HTTP on port 5050, so Docker hosts need it
configured as an insecure registry.

**How this repo is worked:** each phase is planned, approved, built and documented in `phases/`;
failures and corrections are kept in the record rather than tidied away, because they are the
useful part.

---

## 📖 License

This is a personal home lab project. Documentation and scripts are provided as-is for reference purposes.

## 🤝 Contributing

This is a personal project, but feel free to use the documentation as reference for your own home lab!

---

**Last Updated:** September 28, 2026  
**Proxmox Version:** VE 9.2.20 (kernel 7.0.14-4-pve, pinned)  
**Build Status:** DevOps platform operational · Kubernetes HA cluster built · CKA drilling next

---

*Built with ❤️ on Proxmox VE*
