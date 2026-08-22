# Phase 2b: Fedora Host Setup Automation

**Status:** ✅ **BUILT AND VERIFIED on VM-FEDORA-01 (192.168.1.196), August 21, 2026.**
**Created:** August 21, 2026
**Parent:** `phases/phase2_host_setup_automation.md` (the Ubuntu build standard)

> ⚠️ The "DECISIONS NEEDED" and "what actually breaks" sections below are preserved **as
> written before the build**, deliberately. They were predictions. The
> [**BUILD RESULTS**](#build-results--what-was-measured-rather-than-predicted) section at the
> bottom records what was actually measured, including the places the predictions were wrong.
> Andrew's answers on the blocking questions: **Docker CE** (not Podman), **NAS mounted**,
> **match the Ubuntu desktop** (dash-to-dock + gnome-terminal), **hostname `VM-FEDORA-01`**.
>
> ✅ **Aug 21, 2026 — now fully deployed.** During the build itself the script server host
> **192.168.1.195 was offline**, so the whole build was done by direct `scp` rather than via the
> server. It has since been restarted and serves both trees; see
> [Outstanding #1](#-outstanding--must-be-done-when-195-is-back) for the verification table and for
> why the "someone else must do this" blocker turned out to be a wrong inference.
>
> 🔀 **Paths renamed the same day:** `www/scripts_fedora/` → **`www/fedora/`**, served at
> **`/fedora/`** (and the Ubuntu tree `www/scripts/` → `www/ubuntu/` at `/ubuntu/`). Old URLs
> 301-redirect, so the copy of `host_setup.sh` already on `.196` keeps working untouched.

---

## Why this is "2b" and not "18"

`MEMORY.md` reserves **18+ for the study-list backlog** (OpenSearch → Prometheus → Debezium →
MongoDB/Postgres → SAML/OIDC → Ansible), and that order is a standing rule. This work is a second
distro for the **existing** build standard, so it belongs beside its parent — the same relationship
`phase1a`/`phase1b` have to `phase1`. 🔲 **Q7 below asks Andrew to confirm the number.**

---

## Overview

`www/ubuntu/` builds Ubuntu hosts. An **empty `www/fedora/`** was created on Aug 21, 2026
at 19:23; there is **no other mention of Fedora anywhere in the repo** (grepped). This plan covers
building the Fedora equivalent of the Phase 2 build standard.

⭐ **The framing that matters: this is not a port, it is a second implementation of a standard.**
The Phase 2 scripts encode roughly nine months of hard-won fixes — the NAS reachability pre-check,
`_netdev,nofail`, the Cockpit simulate-then-abort guard, `insecure-registries`, the locally-hosted
Cursor GPG key. **Every one of those has to be carried across deliberately.** A rewrite that only
matches the *feature list* will silently drop the *fixes*, and each of those fixes exists because
something broke in this lab.

---

## 🔲 DECISIONS NEEDED FROM ANDREW (this is the blocking section)

| # | Question | Why it changes the plan | My recommendation |
|---|---|---|---|
| **Q1** | **What is the Fedora desktop FOR?** A daily-driver workstation? A Proxmox desktop VM? Learning Fedora/RHEL-family admin for the job? Replacing the Ubuntu desktop VMs? | This decides *everything else*. A throwaway learning VM and a machine you work from every day have opposite answers on NAS mounting, backups, autostart and how much of the desktop polish is worth automating | — (only you know this) |
| **Q2** | **Target host?** New Proxmox VM (which VMID / IP?), or bare metal / an existing box? | VMID/IP drives autostart tier, backup policy, `refresh.sh` inclusion and firewall. ⚠️ Note the lab convention that **VMID matches the last IP octet** (enforced on Aug 20 when 200 became 180) | New VM, VMID = IP octet, `onboot 0` (lab/POC tier) |
| **Q3** | **Fedora 44 or wait for 45?** 44 is stable (released Apr 28 2026, GNOME 50, EOL Jun 2 2027). **45 beta lands Aug 25 — four days from now**; GA Oct 20 2026 | A beta will move under us mid-build and make every measurement unreproducible | **Fedora 44.** Revisit at 45 GA |
| **Q4** | **Script architecture** — see the three options below | Determines whether `host_setup.sh` stays one entry point or becomes two | **Option C (hybrid)** |
| **Q5** | **Docker or Podman?** Fedora ships Podman; the whole lab is Docker + an insecure registry on `:5050` | Podman is the more *Fedora-native* answer and closer to RHEL/OpenShift (relevant to the job); Docker is what every other host here runs | Depends on Q1 — **Docker if it must join the lab, Podman if it is for learning the RHEL family** |
| **Q6** | **Does it mount the NAS?** | 🚨 The Aug 20 `.184` finding: *a uniform build standard plants credentials on hosts the network design isolates.* Answer this **before** building, not after | Yes if it is a workstation, `--no-nas` otherwise |
| **Q7** | **Phase number `2b` OK?** | Avoids colliding with the reserved 18+ study backlog | Yes |
| **Q8** | **Infra or education track?** | If it is a study track it needs `education/CONVENTIONS.md` + `METHOD.md`, a track folder and chapters. As infra it needs neither | **Infra.** It is build automation, not study material |

---

## Implementation approach — three architectures

### Option A — parallel tree (what the empty directory literally implies)

`www/fedora/` gets its own `host_setup.sh` and its own six sub-scripts.

- ✅ Simplest to read; no distro branching anywhere; an Ubuntu change cannot break a Fedora build
- ❌ **Every future fix has to be made twice, and the second one gets forgotten.** This is precisely
  how the `nofail` bug survived across the whole fleet — one builder, one bug, nine VMs

### Option B — one tree, distro detection

`host_setup.sh` reads `/etc/os-release` and each sub-script branches internally.

- ✅ One place to fix things; impossible to update one distro and forget the other
- ❌ `setup_desktop.sh` is already 360 lines. The Ubuntu and Fedora desktop paths diverge so far
  (Ptyxis vs GNOME Terminal, vanilla GNOME vs Ubuntu's dock, Wayland vs X) that a branched version
  would be two scripts wearing one filename

### Option C — hybrid ⭐ RECOMMENDED

**Shared orchestrator, per-distro implementations.** `host_setup.sh` detects the distro and
dispatches to a family directory:

```
www/ubuntu/
├── host_setup.sh          # ONE entry point, detects distro, keeps --no-nas and the download-first pattern
├── common/                # anything genuinely distro-neutral (the Cursor GPG key, shared helpers)
├── debian/                # today's six scripts, moved
└── fedora/                # the new six
```

- ✅ One URL to remember (`http://192.168.1.195/ubuntu/host_setup.sh`) and one place that owns
  orchestration, the `--no-nas` flag and the summary block
- ✅ Distro-specific mess stays isolated where it belongs
- ⚠️ **Cost: it moves the existing files.** Anything referencing
  `http://192.168.1.195/ubuntu/setup_docker.sh` by full path breaks. 🔲 A task below greps for
  every such reference before anything moves

---

## ⚠️ Serving it — two problems that exist right now

**1. A sibling directory is invisible to nginx.** `www/docker-compose.yml` mounts **only**
`./scripts`:

```yaml
volumes:
  - ./scripts:/usr/share/nginx/html/scripts:ro
```

So `www/fedora/` would 404 no matter what is put in it. The mount **and** an nginx
`location` block are both required.

**2. 🚨 The `smb_credentials` deny rule is path-specific and would not cover a second tree.**

```nginx
location = /scripts/smb_credentials { deny all; }
```

That exact-match rule was added on **Aug 20, 2026** after an audit found the NAS password was
downloadable over HTTP by anyone on the LAN. A `scripts_fedora/` tree containing its own
`smb_credentials` would be served in the clear again. ⭐ **Same bug, new path — which is an argument
for Option C**, where one directory root means one deny rule instead of one per tree.

---

## 🔬 What actually breaks — per-script audit

Every row is marked **🔬 MEASURED** (verified by us in this lab) or **📚 EXPECTED** (read from
documentation, *not yet* confirmed on a running Fedora box). ⚠️ **Nothing in this table is 🔬 yet** —
no Fedora host exists. Treat all of it as a hypothesis list to test, not as findings.

### `setup_ssh.sh` — small

| Ubuntu | Fedora | Note |
|---|---|---|
| `apt-get install openssh-server` | `dnf install openssh-server` | 📚 usually already present |
| service auto-enabled | 📚 **`sshd` is NOT enabled by default on Workstation** — needs `systemctl enable --now sshd` | The step that actually matters |
| `ufw` (inactive here) | 📚 **`firewalld` is active by default** — `firewall-cmd --add-service=ssh --permanent` | ⚠️ Real behaviour change: every lab VM currently has `ufw inactive`, so this is the first host with a live host firewall |

### `setup_sudo.sh` — small

`/etc/sudoers.d/agamache` + `visudo -c` validation port unchanged. 📚 The admin group is **`wheel`**,
not `sudo`.

### `setup_cockpit.sh` — ⭐ the trap INVERTS

Phase 2's central Cockpit lesson is *never install the metapackage, because it drags in
NetworkManager onto netplan/systemd-networkd boxes*. **On Fedora Workstation, NetworkManager IS the
network stack** — so `cockpit-networkmanager` is the correct, useful choice, exactly as the Ubuntu
script already does on desktop builds where NM is active.

⭐ **Keep the simulate-then-abort guard, but re-aim it.** The guard's value was never
"NetworkManager is bad" — it was *"refuse to proceed if the install would change the network stack
out from under a machine you only reach over SSH."* That principle is distro-neutral; only the
package that trips it changes. 📚 `dnf install --assumeno` is the `apt-get -s` equivalent.

### `setup_docker.sh` — depends on Q5

- 📚 Docker CE has a Fedora repo at `download.docker.com/linux/fedora`
- ⚠️ **Podman ships preinstalled and provides a `docker` shim on some configurations** — a script
  that tests `command -v docker` can get a false positive and skip the install
- 🚨 **`insecure-registries` for `gitlab.gothamtechnologies.com:5050` must be carried over.** It is
  the single most load-bearing line in the Ubuntu script — Phase 17 confirmed on Aug 20 that `.185`
  already had it *because the standard build wrote it*, closing a question that had been asserted
  wrongly. Podman uses a **different config file and syntax** for the same job
- ⚠️ SELinux: containers need `:z`/`:Z` volume labels that Ubuntu never required

### `setup_smb_mount.sh` — port the fixes, not just the feature

🚨 **Both hard-won guards must survive the port:**
1. The **`<nas>:445` reachability pre-check** that refuses to write fstab or credentials. This is the
   one that needs no operator knowledge, and it is what would have prevented the `.184` incident
2. **`_netdev,nofail`** — verified on the *generated unit* (`systemctl show <unit> -p RequiredBy`
   must be empty), never on the fstab line

⚠️ 📚 New Fedora-only concern: **SELinux is enforcing**, which affects CIFS mount contexts and
anything reading from `/mnt/DevShare`.

### `setup_desktop.sh` — 🚨 this is the one that is mostly a rewrite

Fedora ships **vanilla GNOME**; Ubuntu ships a heavily extended GNOME. Most of this script targets
Ubuntu's extensions.

| Step | Status on Fedora | Detail |
|---|---|---|
| 1 Timezone | ✅ ports as-is | `timedatectl` |
| 2 DNS via `nmcli` | ✅ ports, and is *more* correct | NM genuinely is the stack here |
| 3 CLI tools | ⚠️ `dnf` + package renames | `net-tools` and `sysbench` need checking (📚 sysbench may need RPM Fusion or a COPR) |
| 4 Chrome | ✅ **easier** | 📚 Google ships an RPM and its own yum repo |
| 5 Cursor | ⚠️ **different mechanism** | 📚 official DNF repo `https://downloads.cursor.com/yumrepo`, key `https://downloads.cursor.com/keys/anysphere.asc`. ⭐ **Test whether that key URL 403s the way the apt one did** — we host `anysphere.gpg` locally *because* the official URL was broken. 📚 Known upstream issue: the yumrepo manifest lags the website RPM, so `dnf` can be a version behind |
| 5b AppArmor profile | ❌ **meaningless** | Fedora uses SELinux. The `/etc/apparmor.d/cursor` userns workaround has no Fedora analogue; whether an equivalent fix is *needed* is unknown |
| 6 Resolution via `xrandr` | 🚨 **broken** | 📚 Fedora Workstation is **Wayland by default**; `xrandr` sees only XWayland and cannot set the mode. Needs a different mechanism entirely (monitor config / `gnome-randr` / VM guest tooling) |
| 7 Hide home icon | ❌ **no such schema** | `org.gnome.shell.extensions.ding` is Ubuntu's desktop-icons extension. **Vanilla GNOME has no desktop icons at all**, so there is nothing to hide |
| 7b Dock settings | ❌ **no such schema** | `org.gnome.shell.extensions.dash-to-dock` is Ubuntu's. **Vanilla GNOME has no dock** |
| 8 Screen lock / saver | ✅ ports as-is | Core `org.gnome.desktop.*` schemas |
| 9 "Andrew" terminal profile | 🚨 **entirely broken** | 📚 **Fedora replaced GNOME Terminal with Ptyxis in F41.** The whole dconf block writes to `/org/gnome/terminal/legacy/profiles:/`, a schema that is not installed. Ptyxis has its own profile system |
| 10 Dock favourites | ⚠️ partially | `org.gnome.shell favorite-apps` exists, but **the app IDs differ**: Fedora's Firefox is `firefox.desktop` (RPM), not Ubuntu's snap `firefox_firefox.desktop`, and the terminal is `org.gnome.Ptyxis.desktop`. With no dock installed, favourites only affect the Activities overview |
| 11 Keyring auto-unlock | ✅ 📚 should port | Same `gnome-keyring` mechanism |
| 12 Aliases | ⚠️ one changes | `update` becomes `dnf upgrade --refresh` |

🚨 **The failure mode to design against, and it is our own house special.** Every one of those
`gsettings` calls in the Ubuntu script ends in `2>/dev/null || true`. On Fedora the schemas do not
exist, so **they fail silently and the script still prints its green summary listing settings it did
not apply.** ⭐ **A false green in our own tooling** — the same class as `deploy_swarm.sh`'s inverted
poll and the `|| echo` that printed success on failure. **The Fedora script must verify each setting
took effect and report honestly when a schema is absent**, rather than inheriting `|| true`.

---

## Tasks

**Stage 0 — decide (blocking).** Andrew answers Q1–Q8.

**Stage 1 — prepare, no Fedora host needed**
1. 🔲 Grep the whole repo + `education/` for hardcoded `http://192.168.1.195/ubuntu/<name>.sh`
   references, so Option C's move breaks nothing silently
2. 🔲 Decide and document the directory layout; update `docker-compose.yml` and `nginx.conf`,
   **including a `smb_credentials` deny rule that covers the new tree**
3. 🔲 Confirm from the dev box that the Cursor RPM key URL is reachable (the apt one 403s)

**Stage 2 — build the host**
4. 🔲 Create the VM per Q2 (⚠️ Fedora is **not** template 9000 — that is an Ubuntu 24.04 cloud
   image, so this is an ISO install or a Fedora cloud image, and `MEMORY.md`'s 30-second clone
   recipe does not apply)
5. 🔲 Install Fedora 44, confirm the baseline: SELinux state, firewalld state, NM state, Wayland vs
   X, whether Ptyxis is the terminal — **measured, before writing a line of script**

**Stage 3 — write the scripts**, in Phase 1→4 order, testing each on the live host before the next

**Stage 4 — document**
6. 🔲 Write results into this file: what was built, what differed from plan, what surprised us
7. 🔲 Update `phases/phase2_host_setup_automation.md` and `MEMORY.md` to point here

---

## Testing and validation

- ⭐ **Verify from INSIDE the guest**, never from the builder's report. Standing house rule
- Every step states **how to confirm it took effect** (decision A12's shape, and it applies to a
  build script even better than to a chapter)
- **Re-run for idempotency** — the Ubuntu scripts are idempotent and the Fedora ones must be too
- ⭐ **Prove the negative where a guard exists:** run `setup_smb_mount.sh` on a host that cannot
  reach the NAS and confirm it refuses and writes nothing. That is how the `.184` guard was proven,
  and reading the code is not a substitute
- Throwaway VMID first where practical; `qm destroy --purge` after

---

## 🪲 Two Ubuntu-side defects found while auditing this — ✅ BOTH FIXED Aug 21, 2026

Both were in the existing build standard and unrelated to Fedora. Kept here because the *shape* of
each is more useful than the fix.

1. ✅ **`phases/phase2_host_setup_automation.md` said `setup_desktop.sh` has 11 steps. It has 12.**
   DNS (Google + Cloudflare via `nmcli`) was added as step 2, and `sysbench` joined both the CLI
   tool list and the aliases. The doc's step list had gone stale.
2. ✅ **The resolution autostart entry hardcoded the wrong output name.** Step 6 detects the display
   dynamically with `xrandr` into `$DISPLAY_NAME`, but the autostart file written at the end of the
   script was fixed at `Exec=xrandr --output Virtual-1 --mode 1920x1080`. On any VM whose output is
   not named `Virtual-1`, the resolution was correct for that session and **silently reverted at
   next login** — and because the detection above it worked, the failure looked like GNOME forgetting
   the setting. It now uses the detected name and skips, with a reason, when there is no display or
   the session is Wayland.
   ⭐ **The transferable point: the bug was not in the detection, it was in the SECOND place that
   needed the detected value.** Code that computes a fact correctly and then hardcodes it again a
   hundred lines later fails in the most confusing possible way, because the part you check first is
   right.

## ⭐ Three more Ubuntu-side fixes the Fedora work paid for

Found by writing the Fedora tree honestly and then comparing. Full detail in `phase2`; recorded here
because *this* is the return on having built the second implementation properly.

1. **`containerd-snapshotter`** in the builder (defect 2 above) — a live CI bug, fixed for every
   future host.
2. **`host_setup.sh` claimed five successes it never checked** and always exited 0. It now measures
   all seven, exits non-zero on failure, and hard-gates on `setup_sudo.sh`.
3. **`setup_desktop.sh` printed fifteen hardcoded checkmarks**, three of them for schemas that may
   not exist. It now reads every value back and exits non-zero if anything did not stick — verified
   by running the new summary in a bare Ubuntu 24.04 container with no `gsettings`, `nmcli` or
   `dconf` at all, where it degraded to `--`/`WARN` and exited 1 instead of crashing or lying.

---

## `--server` on Fedora (Aug 21, 2026) — parity, with two deliberate differences

Added after Ubuntu got it. ⭐ **Worth stating plainly: the Fedora tree never had the bug that
prompted the flag.** Ubuntu's gate was `gnome-shell || gsettings`, and `gsettings` is present on
headless hosts, so servers were quietly given 1.44 GB of Chrome and Cursor. **The Fedora gate has
always tested `gnome-shell` alone**, so no Fedora host was ever affected. Here the flag is explicit
control and cross-tree symmetry, not a repair — the second implementation being *right* rather than
paying for a fix, for once.

Skips Chrome, Cursor, resolution, GNOME settings, the terminal profile, the dock, the keyring, the
GDM greeter config and autologin. Keeps timezone, DNS, CLI tools and aliases. Two things differ from
the Ubuntu version, both on purpose:

1. **The systemd sleep targets are still masked in server mode.** This is the one desktop-looking
   step a headless host needs *more* than a workstation: a server that suspends has nobody in front
   of it to wake it up. Only the GDM-greeter half of that step is skipped, because it configures a
   greeter a headless host does not run.
2. **Server mode is exempt from the D-Bus session-bus requirement.** That check exists because
   `gsettings` without a bus writes to a memory backend and reports success having changed nothing —
   the purest false green, so the script refuses to run. But a headless host *has* no session bus,
   and server mode never touches `gsettings`. Enforcing it there would make `--server` refuse to run
   on exactly the machines it was built for. ⚠️ **A safety check whose scope is wider than its
   reason** — the failure mode was "the fix cannot run where it is needed", which reads as the
   feature being broken rather than the guard being over-broad.

The step labels are now generated (`[n/5]` in server mode, `[n/14]` in desktop mode) rather than
hand-written, for the same reason as Ubuntu: two modes with different totals is precisely where
hardcoded `[4/14]` labels drift.

**Verified in a stubbed sandbox**, since no headless Fedora host exists yet to test on: server mode
ran 5 steps, never referenced Chrome or Cursor, *did* mask all four sleep targets, wrote the `dnf`
flavour of the `update` alias, and skipped autologin and the greeter config. Desktop mode with no bus
available still refuses and exits 1; the same conditions with `--server` proceed. Both trees reject
an unknown flag. ⚠️ **Still unproven on real hardware** — the sandbox validates the logic and the
branch selection, not `dnf` behaviour on a genuine Fedora Server.

---

## Related files

- `phases/phase2_host_setup_automation.md` — the Ubuntu build standard this extends
- `www/ubuntu/` — the six current scripts + `anysphere.gpg`
- `www/docker-compose.yml`, `www/nginx.conf` — how the scripts are served
- `MEMORY.md` → *SCRIPT SERVER*, *COCKPIT*, *PROD-LOCAL HOSTS MUST NOT MOUNT THE NAS*

---
---

# BUILD RESULTS — what was measured, rather than predicted

**Host:** `VM-FEDORA-01` @ `192.168.1.196` — VMware guest on the DEV box, Fedora Linux 44
Workstation, kernel 6.19.10, GNOME Shell 50.0, btrfs on `/dev/nvme0n1p3` (98 GB).
**Method:** built live over SSH, writing each script, running it, and reading the result back.
Nothing below is inferred from documentation.

## Architecture as built

Andrew's `www/fedora/` was kept (the plan had recommended Option C, a hybrid tree — that
would move the six Ubuntu scripts, which is a change to the **production** build standard and needs
its own sign-off). Seven scripts now exist:

| Script | Status | Notes |
|---|---|---|
| `setup_ssh.sh` | ✅ run, verified | unit is `sshd`; asserts something is **listening**, not merely enabled |
| `setup_sudo.sh` | ✅ run, verified | `wheel`, not `sudo`; validates in a temp file **before** installing to `sudoers.d` |
| `setup_cockpit.sh` | ✅ run, verified | guard re-aimed (below); Cockpit live on :9090 |
| `setup_hostname.sh` | ✅ run, verified | **new.** Was Fedora-only; an Ubuntu counterpart was added Aug 21, 2026 (see phase2), and this copy was hardened at the same time — it now guards on `/etc/fedora-release`, because it is the one script here made only of `hostnamectl`/`sed`/`getent` and so the only one that runs on Debian and **succeeds at the wrong thing** (it renamed the Ubuntu dev box before the guard existed) |
| `setup_docker.sh` | ✅ run, verified | Docker CE 29.7.2 + insecure registry + **containerd store off** |
| `setup_smb_mount.sh` | ✅ run, verified | both guards ported **plus** a new proof step |
| `setup_desktop.sh` | ✅ run, verified | **20 OK / 2 SKIP / 0 FAIL**, each measured |
| `host_setup.sh` | ⚠️ written, **not yet run end-to-end** | needs `.195` up to fetch over HTTP |

## ⭐ Predictions that were confirmed by measurement

Every red flag in the pre-build audit was real:

- **Ptyxis 50.1** is the terminal; `gnome-terminal` **not installed**; `org.gnome.Terminal.ProfilesList` **absent**.
- `dash-to-dock`, `ding`, `desktop-icons` schemas **all absent** on a stock install.
- **SELinux Enforcing**, **firewalld active** (`FedoraWorkstation` zone).
- Console session is **Wayland**, so `xrandr` cannot set a mode.
- **`sshd` is not enabled by default** — `systemctl status` literally reports `preset: disabled`.
  This is why the first Fedora box needs one command typed at the console before anything else works.

## 🪲 Predictions that were WRONG — corrections

1. **Cockpit was already half-installed.** Fedora Workstation ships `cockpit-ws` *and*
   `cockpit-bridge`; `cockpit.socket` merely sits **disabled**, and firewalld already has a
   `cockpit` service definition. On Fedora this script is *enable and open*, not *install*.
2. **Podman does not provide a fake `docker` binary.** The audit worried an "is docker installed"
   check could be fooled. Measured: `command -v docker` → nothing. No such risk.
3. **`xrandr --output Virtual-1` is not as wrong as claimed.** The output on this VMware guest
   really is `Virtual-1`. The hardcode is correct for VMware guests and wrong for Proxmox ones.
   Moot anyway: Wayland + `open-vm-tools-desktop` auto-fit.
4. **The Cursor GPG key problem is Ubuntu-only.** Both `downloads.cursor.com/yumrepo` and
   `keys/anysphere.asc` return **HTTP 200**. Fedora needs no locally-mirrored key, so
   `anysphere.gpg` is deliberately absent from the Fedora download list.

## 🚨 Five real defects found by building it

### 1. A guard that fired on the package it was meant to permit
`setup_cockpit.sh` first shipped `grep -qiE 'NetworkManager-[0-9]'` to abort if the transaction
touched the network stack. It **aborted a completely clean install**, because case-insensitively
`cockpit-networkmanager-360` contains `networkmanager-3`. On Fedora the *wanted* package's name
contains the *forbidden* package's name, so a substring test is wrong **by construction**.
✅ Fixed: parse the dnf transaction table and compare **exact package names**.
⭐ The Ubuntu script uses the same substring style and should be reviewed.

### 2. 🚨 The containerd image-store bug is in the BUILDER, on every distro
Fresh Docker CE 29.7.2 on Fedora reported `Storage Driver: overlayfs`, `driver-type:
io.containerd.snapshotter.v1` — **the exact state that broke CI on the runner `.182` on Aug 17**
(OCI image indexes pushed parent-before-child → `blob unknown to registry`).
That fix was applied **by hand to one VM and never folded into `setup_docker.sh`**, so *every host
the build standard has produced since then ships the broken default*.
✅ The Fedora script now writes `"features": {"containerd-snapshotter": false}` and **asserts
`docker info` reports `overlay2`**.
✅ **And as of Aug 21, 2026 so does `www/ubuntu/setup_docker.sh` (Ubuntu).** Same shape as the
`nofail` bug: *fixing one VM fixes one VM; fixing the builder fixes every future one.*
🔲 The **already-built fleet** is still on the broken default — see Outstanding #3.

### 3. 🚨 The `.gitignore` credential rule did not generalise
`/www/ubuntu/smb_credentials` is an **absolute-path** rule. A copy at
`www/fedora/smb_credentials` would **not** have been ignored — it would have been committed
and pushed to **public GitHub**. (`push_github.sh`'s name gate greps for `cred` and would probably
have caught it, but MEMORY explicitly says not to lean on that.)
✅ Fixed: rule is now `/www/*/smb_credentials`; both paths verified with `git check-ignore`.

### 4. 🚨 The nginx deny rule did not generalise either — same root cause
`location = /scripts/smb_credentials` is an **exact match on one path**, so the Fedora tree would
have served the NAS password over plain HTTP to the whole LAN.
✅ Fixed: `location ~ /smb_credentials$ { deny all; }`. **Proven, not assumed** — a live nginx
container with both trees mounted returned `200` for both script listings and **`403` for
`smb_credentials` in both trees**, with a body check confirming no leak. Re-verified Aug 21 with a
canary string in the file, and the `?query` and `//double-slash` variants also return 403.

⚠️ **Why the regex wins, stated correctly.** An earlier version of this note (and of the comment in
`nginx.conf`) said *"regex locations are evaluated before prefix locations"*. That is **not** how
nginx works: it finds the **longest matching prefix first and remembers it**, then tests regex
locations in file order, and a matching regex **overrides** the remembered prefix. The conclusion —
this rule beats the two tree prefixes — is right, but the mechanism matters, because a
regex would **not** beat `=` or `^~` on the same path. ⛔ **Do not add either of those to the two
tree locations.**

⭐ Two independent protections, written months apart, failed the same way the moment a second
directory appeared. That pattern — *path-specific safety rules silently not covering new paths* —
is worth looking for elsewhere.

### 4b. ⭐ The follow-up fix: the deny rule protected the CONTENT, not the EXISTENCE
Both fixes above still left the filename visible. `autoindex` builds its listing in the `/scripts/`
handler and **never consults the child URI's location**, so no deny rule can hide the name — the
directory listing in both trees still advertised that a NAS credential file existed at a known path.

✅ Fixed structurally on Aug 21, 2026 by moving the file to **`www/smb_credentials`**, one level
**above** both trees. `docker-compose` bind-mounts `www/ubuntu` and `www/fedora` into nginx
but **never `www/` itself**, so the container has no path to the file at all. Both
`setup_smb_mount.sh` scripts read the new location first and still accept the two old ones, so an
existing clone keeps working. The nginx deny rule and the `/www/*/smb_credentials` ignore rule are
**both kept as second layers**, for the case where a stray per-tree copy reappears.

⭐ **The generalisable point: a rule that denies access is weaker than a layout that denies
reachability.** Three separate fixes were needed to protect one file with a deny rule; one move made
the question moot.

🪲 **And a fact about this repo, found while doing it:** `chmod 600` on that file **does nothing**.
The repo lives on the NAS over CIFS mounted `file_mode=0775`, which *forces* the mode — permissions
cannot be tightened from this side, so file-mode is not available as a protection here at all. Same
root cause as the mode-711 nginx 403 recorded at the end of this file.

### 5. A diagnostic step that hung the entire build
`ausearch -m avc -ts recent` **blocked forever**. Cause: `auditd` was **active** while
`/var/log/audit/` was **empty** (records go to the journal on this install). With no log file,
`ausearch` falls back to reading **stdin**, which over a non-TTY SSH session never closes.
⭐ *A running audit daemon is not the same thing as an audit log existing.*
✅ Fixed: `</dev/null`, a `timeout`, and a journal fallback. A purely diagnostic step must never be
able to hang or fail a build.

## 🔬 Two more traps worth recording

- **`wget` is not installed on stock Fedora Workstation.** The documented Ubuntu bootstrap line
  begins `wget http://192.168.1.195/ubuntu/host_setup.sh` — on Fedora that **fails at the very
  first command**. The Fedora `host_setup.sh` uses `curl` (present by default) throughout, and
  `wget` is installed later by `setup_desktop.sh`. *A bootstrap may only depend on what a stock
  install already has.*
- **`gnome-extensions enable` is a RUNTIME api, not configuration.** It asks the **running**
  GNOME Shell over D-Bus, and the Shell only scans the extensions directory at startup. A
  just-installed system extension reports `doesn't exist` even though the files are on disk and the
  version is compatible (`metadata.json` lists shell-version 45–50; the Shell is 50.0). ✅ Write
  `org.gnome.shell enabled-extensions` instead — the durable key the Shell reads at startup, which
  works over SSH and survives to next login.

## ⭐ The false-green problem, and what was done about it

Every `gsettings` call in the Ubuntu `setup_desktop.sh` ends in `2>/dev/null || true`, and its
closing summary prints **hardcoded checkmarks** for all twelve steps. On Ubuntu that is untidy. On
Fedora it would be **actively dishonest**: three of the schemas it writes to do not exist here, so
the writes fail, the errors are swallowed, and it would print *"Home folder: Hidden"* and *"Dock
panel mode: Disabled"* having changed **nothing**.

The Fedora `setup_desktop.sh` therefore **writes every setting and reads it back**, and reports
`[ OK ] / [SKIP] / [FAIL]` from the measurement. It also **refuses to run without a D-Bus session
bus**, because over SSH `gsettings` silently falls back to a memory backend where every write
"succeeds" and every value evaporates — the purest possible false green.

Final run: **20 OK, 2 SKIP (both with stated reasons), 0 FAIL.** Re-run takes 2.7 s and is fully
idempotent. The two skips are honest outcomes, not failures:
- *Resolution* — not forced; Wayland + VMware auto-fit governs it. **No dead autostart entry was
  written just so a summary line could claim `1920x1080`.**
- *Home icon* — nothing to hide; vanilla GNOME draws no desktop icons at all, so the Ubuntu step's
  goal is satisfied by absence.

The dock failure was caught **by the script itself** on its first run (`[FAIL] dash-to-dock
installed but not enabled`) rather than being papered over — which is the entire point.

## Verified end state of VM-FEDORA-01

```
sshd            active/enabled      cockpit.socket  active/enabled
docker          active/enabled      firewalld       active/enabled
NetworkManager  active/enabled      /mnt/DevShare   mounted (~/DevShare symlink)
```
Chrome 151, Cursor, Docker 29.7.2 (`overlay2`), Podman 5.8.1 (untouched), git 2.53.0,
gnome-terminal with the **Andrew** profile, dash-to-dock enabled, 8 dock favourites pinned,
aliases `godev` / `update` (dnf) / `sysbench`.

Cockpit auth was verified **from outside the box**, and the check was proven to discriminate:
`/cockpit/login` returns a csrf-token for the right password and `authentication-failed` for a
wrong one — while **`/login` returns HTTP 200 for a deliberately wrong password**, reproducing the
documented trap exactly on Fedora.

## Outstanding — and what closed

1. ✅ **DONE Aug 21, 2026 — the script server is restarted and serving both trees.**

   ⭐ **The blocker was a wrong inference, not a locked door, and that is the lesson.** This item
   read *"ANDREW MUST DO THIS AT THE DEV MACHINE"* because a port scan of `.195` showed **only port
   80 open** — no SSH, no Cockpit — so it was concluded the host could not be driven from here. The
   scan was accurate. The inference was wrong: **the dev box `VM-UBUNTU-01` IS `192.168.1.195`.** It
   is the machine this work already happens on, so `cd www && docker compose up -d` was a *local*
   command the whole time. ⚠️ *"I cannot SSH to it" is not the same as "I am not on it."* One
   `hostname -I` would have closed a task that sat blocked across two sessions.

   Verified live on `192.168.1.195` after `docker compose up -d`:

   | URL | Result |
   |---|---|
   | `/` | **200** — landing page linking both trees |
   | `/ubuntu/`, `/fedora/` | **200** with listings |
   | `/ubuntu/host_setup.sh`, `/fedora/host_setup.sh` | **200** |
   | `/ubuntu/anysphere.gpg` | **200** |
   | `/scripts/...`, `/scripts_fedora/...` | **301** → new path, and `curl -fsSL` through it delivers the correct script |
   | `smb_credentials`, either tree | **403**, and **0 occurrences** in either listing |

   ⚠️ **Why the 301s matter here specifically:** the `host_setup.sh` already on `.196` has the old
   `SCRIPT_SERVER=.../scripts_fedora` baked in. The redirect is what keeps that copy working without
   touching the box.

   Reference checks, if the server is ever rebuilt:
   - `http://192.168.1.195/fedora/` → **200** with a listing
   - `http://192.168.1.195/ubuntu/` → **200** with a listing
   - `http://192.168.1.195/ubuntu/smb_credentials` → **403**
   - `http://192.168.1.195/fedora/smb_credentials` → **403**

   ⚠️ **Do NOT try to prove the file moved by looking for a 404.** The deny rule matches the URI
   **before** nginx resolves it to a file, so a path under `/scripts/` returns **403 whether the
   file is there or not**. Measured, after an earlier draft of this note claimed otherwise. The
   status code cannot distinguish "denied" from "absent", which is good for privacy and useless as a
   test.

   ⭐ **The test that does work is the directory listing**, because `autoindex` reflects what is
   actually on disk:
   ```
   curl -s http://192.168.1.195/ubuntu/ | grep -c smb_credentials      # want 0
   curl -s http://192.168.1.195/fedora/ | grep -c smb_credentials # want 0
   ```
   Verified locally against both real trees with the real `nginx.conf`: **0 occurrences in each**,
   where the pre-move listing showed 1. That is the proof the structural fix landed.
2. ✅ **DONE Aug 21, 2026 — `host_setup.sh` proven end-to-end.** Run against a throwaway nginx
   container on `.196`: it fetched itself over HTTP, downloaded all seven sub-scripts with `curl`,
   ran all four phases, and its closing summary reported `ok` for SSH, passwordless sudo, Cockpit
   and Docker (`overlay2`) — every line a live measurement.
   To make that testable at all, `SCRIPT_SERVER` is now **overridable**
   (`SCRIPT_SERVER=http://localhost:8099 bash host_setup.sh --no-nas`). The Ubuntu version
   hardcodes it, which is why *it* has still never been proven except during a real build.
   ⚠️ Still worth one run on a genuinely clean Fedora VM: this run was against an already-built
   host, so it exercised the idempotent paths, not the first-install paths.
3. ✅ **DONE Aug 21, 2026 — the Ubuntu `containerd-snapshotter` fix is in the builder** (defect 2).
   `www/ubuntu/setup_docker.sh` now writes `"features": {"containerd-snapshotter": false}` beside
   the insecure-registry entry and **asserts `docker info` reports `overlay2`**, exiting 1 if not —
   the same shape as the Fedora script.
   🔲 **What remains open is the FLEET, not the builder.** Every host built between Aug 17 and
   Aug 21 still runs the containerd image store; only `.182` was ever fixed, by hand. Retrofitting
   means restarting Docker on each host, and ⚠️ **images in the old store become invisible to the
   new driver** (`docker images` reads empty — expected, rebuild or repull), so this is *not* a
   zero-impact change on anything currently running. **Andrew's call, per host.**
4. ✅ **CLOSED Aug 21, 2026 — this was a FALSE ALARM.** Defect 1 warned that the Ubuntu
   `setup_cockpit.sh` "uses the same substring style and should be reviewed". It does not. It parses
   apt's output into **bare package names first** and then tests with a whole-line match:
   ```bash
   SIM="$(apt-get install -s $PKGS 2>&1 | grep '^Inst' | awk '{print $2}')"
   if [ "$NM_ACTIVE" -eq 0 ] && echo "$SIM" | grep -qx "network-manager"; then
   ```
   `grep -qx` is exact. The weakness was specific to regexing **dnf's transaction table as raw
   text**, which has no Ubuntu equivalent. The `cockpit-files` guard added the same day uses
   `grep -qx` and `grep -v '^cockpit-files$'` and is correct by the same standard.
   ⭐ Worth keeping as a record of the failure mode: *a defect found in one implementation was
   assumed to exist in the other because they share a purpose. Parallel trees invite that inference,
   and it needs checking rather than propagating.*
5. ✅ **DONE Aug 21, 2026 — the hardcoded resolution autostart entry is fixed.** It now uses the
   `$DISPLAY_NAME` the step above already detected, and **skips with a stated reason** where the
   entry could only ever be dead weight: no display detected, or a Wayland session. (The 11-vs-12
   step count defect was fixed the same day.)
6. ✅ **DONE Aug 21, 2026 — the two Ubuntu false greens are gone.** `host_setup.sh` printed `✓` for
   SSH, sudo, Docker, Git and the desktop **without checking any of them** (only Cockpit and the NAS
   mount were tested), and `setup_desktop.sh` printed **fifteen** hardcoded checkmarks including
   ones for schemas that do not exist on every host. Both now measure and report `ok`/`WARN`/`--`,
   both exit non-zero when something failed, and `host_setup.sh` gained a **hard gate on
   `setup_sudo.sh`** — everything downstream runs under sudo, so continuing without it just buries
   the real cause. ⭐ **This is the Fedora work paying back into the Ubuntu standard**, which was
   the argument for writing the Fedora tree honestly in the first place.
7. 🔲 **Standing hazard now that there are two trees: a fix in one is not in the other.** Both
   `phase2` and the new `MEMORY.md` PHASE INDEX row say so. When changing a script, check the
   counterpart and state which way you decided.

---

## Addendum — Aug 21, 2026, after Andrew's full upgrade + reboot

**⭐ The reboot validated the storage work by experiment rather than by inspection.** `.196` was
fully upgraded (kernel **6.19.10 → 7.1.8-200.fc44**) and rebooted. On the way back up:

| Check | Result |
|---|---|
| `/mnt/DevShare` | **mounted** |
| `mnt-DevShare.mount` | **active** |
| `systemctl --failed` | **0 failed units** |
| Docker storage driver | still **overlay2** |
| `/etc/docker/daemon.json` | intact, both keys present |

That is the `_netdev,nofail` fstab entry and the `containerd-snapshotter` flag surviving a real
kernel upgrade and a real reboot — the condition the `.184` bug went undetected under for a month.

**`btop` added to both build standards** at Andrew's request. Verified available before adding,
because both `apt-get install` and `dnf install` are **all-or-nothing**: one unavailable name in
the list installs *none* of the tools.

| Distro | Package | Verified |
|---|---|---|
| Fedora 44 | `btop` 1.4.7 | installed in 5 s (pulls `rocm-smi`) |
| Ubuntu 24.04 | `btop` 1.3.0-1 | `apt-cache policy` in a clean container |
| Ubuntu 22.04 | `btop` 1.2.3-2 | `apt-cache policy` in a clean container |

Both scripts now also **check each binary individually after installing**, because the previous
message *"WARNING: Some tools may have failed to install"* could equally mean one package was
missing or that the whole list failed and you got nothing.

Fedora `setup_desktop.sh` re-run after the change: **20 OK, 2 SKIP, 0 FAIL**, with
`curl wget htop btop vim jq net-tools tree unzip sysbench` all confirmed present.

**`cockpit-files` added to the standard build** (Andrew, Aug 21 2026 — "alongside cockpit, on
everything"). ⭐ This is the clearest example so far of the two distros needing genuinely
different engineering for the same one-line request:

| | Fedora 44 | Ubuntu 24.04 / 22.04 |
|---|---|---|
| Available? | ✅ `cockpit-files` **43**, `updates` repo | ⚠️ **backports only**, v39 |
| Installs? | ✅ single package, **no dependencies** | ❌ `Depends: cockpit-bridge (>= 318)` vs 314 shipped |
| How it is handled | added straight to the main package list | **separate optional transaction, guarded, skips loudly** |

Fedora ships a current Cockpit, so the plugin just fits. Verified installed on `.196`:
`cockpit-files-43-1.fc44`, and `files` now appears in `/usr/share/cockpit/`.

🚨 On Ubuntu, adding the name to the main list **would have broken every build** — all-or-nothing
`apt-get` under `set -e` means no Cockpit at all rather than Cockpit minus a plugin. Full reasoning
and the rejected `-t noble-backports` alternative are recorded in
`phases/phase2_host_setup_automation.md`.

**Dock moved to the left edge** (Andrew, Aug 21 2026 — it came up on the bottom).
⭐ Another "Ubuntu's default is not GNOME's default" case, and a reminder that *matching the Ubuntu
look means matching Ubuntu's PATCHED defaults, not just installing the same extension.*
Upstream `dash-to-dock` defaults to `dock-position: 'BOTTOM'`; **Ubuntu patches that default to
`LEFT`**, so the Ubuntu `setup_desktop.sh` never had to set the key and the omission was invisible
until the same extension was installed unpatched. The Fedora script now sets it explicitly rather
than inheriting whichever default a distro happens to ship. Verified `'LEFT'` read back from the
live session; run is now **21 OK / 2 SKIP / 0 FAIL**.

**No sleep, and passwordless autologin** (Andrew, Aug 21 2026). Steps 13 and 14 added.

🚨 **The lesson here is the important part: the session settings were all correct and the machine
still slept.** Step 8 had already set `idle-delay=0`, `lock-enabled=false`,
`sleep-inactive-ac-type='nothing'` and `idle-dim=false`, and every one of them read back correctly.
Two things sat outside that scope entirely:

1. ⭐ **The login screen is a DIFFERENT USER.** GDM's greeter runs as the `gdm` user with its own
   dconf profile, so nothing set in Andrew's session applies to it. A VM left sitting at the
   greeter blanks regardless. Fixed with `/etc/dconf/db/gdm.d/01-lab-no-sleep` + `dconf update`.
2. ⭐ **gsettings are POLICY, not ENFORCEMENT.** They express a preference; they cannot stop
   anything from asking to suspend. `systemctl mask sleep.target suspend.target hibernate.target
   hybrid-sleep.target` is the enforcement layer.

**Proven by the negative, which is the only proof that counts here:**
```
$ sudo systemctl start suspend.target
Failed to start suspend.target: Unit suspend.target is masked.
```
Also closed `sleep-inactive-battery-type`, which shipped as `'suspend'` — irrelevant on a VM until
a hypervisor presents a battery, at which point it silently becomes the active policy.

**Autologin** via `/etc/gdm/custom.conf` (`AutomaticLoginEnable=True`, `AutomaticLogin=agamache`),
with the distro default preserved once at `custom.conf.orig`. ⚠️ **It pairs with step 11 and is not
independent of it:** with autologin, PAM never receives a password, so a password-protected login
keyring would prompt at every boot — reintroducing the exact prompt this build removes. The
no-password keyring is what makes autologin quiet. The edit deletes-then-reinserts the keys rather
than appending, so it is idempotent; verified still exactly 2 `AutomaticLogin*` lines after three
runs, where appending would have stacked duplicates that GDM silently ignores after the first.

🪲 **Caught in our own output while doing this:** the resolution line began reporting
`session=tty`, because the session probe took the *first* session listed and got the SSH one. The
box was sitting at a Wayland desktop the whole time. Now it searches for the graphical session
specifically. A cosmetic bug, but in a script whose entire purpose is honest reporting, a
misleading fact in the summary is the one defect that matters most.

Run is now **25 OK / 2 SKIP / 0 FAIL**.

🪲 **A trap worth recording from the test rig:** serving the scripts from a container failed with
**HTTP 403** because the files copied off the CIFS share as mode **711** — the owner can read them,
but nginx runs as a different user inside the container and cannot. The scripts were readable to
every check done *as the owner*, and only broke when something else tried to read them. Worth
remembering if the real script server ever starts 403-ing after a file is re-copied.
