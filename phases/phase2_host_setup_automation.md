# Phase 2: Host Setup Automation

**Status:** ✅ Complete  
**Date:** December 12, 2025  
**Amended:** August 20, 2026 — added `setup_cockpit.sh` to the standard build (see below)  
**Amended:** August 21, 2026 — `cockpit-files`, `btop`, and four defects fixed (see *Aug 21 corrections*)

> 🔀 **RENAMED August 21, 2026 — the served paths and the directories both changed:**
>
> | Was | Is now |
> |---|---|
> | `www/scripts/` → `http://192.168.1.195/scripts/` | `www/ubuntu/` → **`http://192.168.1.195/ubuntu/`** |
> | `www/scripts_fedora/` → `http://192.168.1.195/scripts_fedora/` | `www/fedora/` → **`http://192.168.1.195/fedora/`** |
>
> ⭐ **Old URLs still work.** `nginx.conf` keeps `301` redirects from both old paths, because the old
> `SCRIPT_SERVER` is baked into every `host_setup.sh` copy already sitting on a built host, and into
> the build commands recorded verbatim in eight phase files. Both `wget` and `curl -fsSL` follow
> redirects, so those keep working rather than failing with a 404 that looks like the server is down.
> **Verified end-to-end: an old URL fetched with either tool delivers the correct script.**
>
> ⚠️ **Any `/scripts/` URL you find in a phase file predates this and is a historical record — do
> not "fix" it.** The redirects are what make that safe.
>
> ⭐ **What needed NO edit is the interesting part.** The `smb_credentials` protections had just been
> rewritten to match by *name* rather than by path (the nginx `location ~ /smb_credentials$`, the
> `.gitignore` `/www/*/smb_credentials`, and `push_gitlab.sh`'s listing). All three survived this
> rename untouched, while the three path-based rules they replaced would each have gone silently
> quiet for the second time in one day.

> 🔀 **This file is the UBUNTU/DEBIAN half of the build standard.** The Fedora half is
> **`phases/phase2b_fedora_host_setup.md`** (`www/fedora/`, built and verified on
> `VM-FEDORA-01` / `.196`, Aug 21 2026).
>
> ⚠️ **The two trees are parallel implementations of one standard, so a fix made in one is NOT in
> the other.** That asymmetry is the main hazard: it is exactly how the `nofail` bug survived across
> nine VMs — one builder, one bug, fixed per-host and never folded back. **When you change a script
> here, check whether its counterpart needs the same change, and say which way you decided.**

---

## Overview

Created a centralized script server and automated setup scripts to configure new Ubuntu VMs consistently. Any new VM can be fully configured with a single command.

🚨 **Where the NAS credential file lives, and why it is not next to the scripts.** As of Aug 21,
2026 it is **`www/smb_credentials`** — one level *above* both script trees. `docker-compose`
bind-mounts `www/ubuntu` and `www/fedora` into nginx but never `www/` itself, so a file
kept there **cannot be served, cannot be listed by `autoindex`, and cannot be exposed by a future
`location` block someone adds without thinking.** It previously sat inside `www/ubuntu/`, where it
was protected only by a deny rule — which hid the contents but still let the directory listing
advertise that a credential file existed at a known path. Both `setup_smb_mount.sh` scripts read
the new location first and still accept the old ones, so an existing clone keeps working.

---

## Script Server

### Architecture

- **Host:** DEV machine (Ubuntu 25.10 workstation)
- **IP:** 192.168.1.195
- **Port:** 80
- **Technology:** Docker + nginx:alpine container
- **Location:** `/www/` directory in project root

### Files

```
/www/
├── run_www.sh          # Start/restart the server
├── docker-compose.yml  # Container configuration
├── nginx.conf          # Serves /scripts/ with directory listing
└── scripts/            # All setup scripts
    ├── host_setup.sh       # Master orchestrator
    ├── setup_ssh.sh        # SSH server
    ├── setup_sudo.sh       # Passwordless sudo
    ├── setup_cockpit.sh    # Cockpit web admin on :9090
    ├── setup_docker.sh     # Docker + Git
    ├── setup_smb_mount.sh  # NAS mount
    ├── setup_desktop.sh    # Desktop configuration (11 steps)
    └── anysphere.gpg       # Cursor apt repo GPG key
```

### Usage

**Start/restart server:**
```bash
cd /mnt/DevShare/cursor-projects/home-lab-setup/www
./run_www.sh
```

Editing a script in `www/ubuntu/` or `www/fedora/` publishes it immediately — nginx serves the
directory straight off disk, so there is no rebuild step. But a VM you already built
keeps whatever it downloaded at build time. Changing a script here changes *future*
builds only.

**Access:** start at **http://192.168.1.195/** — the landing page. The two trees stay browsable at
http://192.168.1.195/ubuntu/ (Ubuntu/Debian) and http://192.168.1.195/fedora/ (Fedora) for pulling
an individual script by hand.

### The landing page — `www/index.html` (added Aug 21, 2026)

`/` used to return a two-link stub generated inline by `nginx.conf`. It is now a real page holding
the bootstrap commands for both distros with copy buttons, the flags, and the warning about piping
into bash. Two decisions in it are worth keeping:

- **The page rewrites its own hostname in JavaScript**, from `window.location.host`, rather than
  containing `192.168.1.195`. Hardcoding the IP is what every other copy of these commands did, and
  it is why the same command exists in five files that can drift apart. Browse the page from any
  interface, DNS name, or port and the commands it shows are the ones that will work.
- ⛔ **`index.html` is bind-mounted as a SINGLE FILE, not by mounting `www/` as the web root.**
  Mounting the directory is the obvious way to serve an index and it would drag
  `www/smb_credentials` into the container with it, undoing the entire reason the credential file
  was moved up out of the trees. Verified after the change: the container's web root holds only
  `index.html`, `ubuntu/`, `fedora/`, and nginx's stock `50x.html`.
- The clipboard uses a `<textarea>` + `document.execCommand('copy')` fallback, because
  `navigator.clipboard` requires a secure context and this is plain HTTP on a LAN — so the modern
  API is `undefined` here and the fallback is the path that actually runs. Confirmed by clicking it.

---

## Setup Scripts

### Master Script: host_setup.sh

Two commands to fully configure a new host — **download first, then run**:

```bash
# Ubuntu / Debian
wget http://192.168.1.195/ubuntu/host_setup.sh
bash host_setup.sh                    # NOT sudo — it handles sudo internally

# Fedora  (curl, because stock Fedora Workstation has no wget)
curl -fsSLO http://192.168.1.195/fedora/host_setup.sh
bash host_setup.sh
```

Add `--no-nas` on a DMZ / prod-local host, and `--hostname <name>` or `--server` on either distro.

#### 🚨 Never run `host_setup.sh` from inside `www/` — it used to eat the library

**Done Aug 21, 2026: one run from inside `www/ubuntu/` zeroed all seven sub-scripts and
`anysphere.gpg`.** Three individually sensible facts combine into a self-destruct:

1. `host_setup.sh` downloads its sub-scripts **next to itself** (`SCRIPT_DIR`), on purpose, so a
   built host keeps them for re-runs.
2. `wget -O <file>` **truncates the destination as it opens it**, before any bytes arrive.
3. nginx serves `www/ubuntu/` **off disk via a bind mount** — served copy and source copy are the
   same inode.

wget emptied each file, then asked nginx for it, and got back the zero bytes it had just written.
`host_setup.sh` itself survived only because it is not in its own download list.

⭐ **The general shape: a program that fetches its inputs into its own source directory, from a
server backed by that same directory, will eat itself.**

Both trees now **refuse to start** if `../nginx.conf` and `../docker-compose.yml` sit beside them —
the reliable signature of this repo — and print the `mktemp -d` form to use instead.

**The more valuable fix was the second one: downloads are now atomic** (`.<name>.part`, then `mv`
only on success *and* non-empty). Before this, **any** failed download replaced a working script
with an empty file, and the case that hurts is the one the script exists for: a re-run to repair a
host, where a brief network blip would have left eight empty scripts and no indication why. Fedora
had the identical `curl -o` flaw and escaped the incident only because its distro guard exits first
on a Debian host — luck, not a control. Both are fixed.

⚠️ **Recovery was luck too.** The zeroed files were modified-but-uncommitted, so `git checkout` would
have restored *pre-session* content and quietly lost hours of work, and `setup_hostname.sh` was
**untracked** — git had nothing. What actually saved it: earlier bootstrap tests had left complete
downloaded sets in `/tmp/tmp.*/`, one timestamped after the final edit. ⭐ **Commit before testing
anything that writes into the repo.**

🚨 **Do NOT use the old one-liner `bash <(curl -s .../host_setup.sh)`, and do not "simplify" this
back to it.** It was documented here and printed by `run_www.sh` until Aug 21, 2026, and it is
**broken for these scripts in two independent ways** — both measured:

1. `host_setup.sh` downloads its sub-scripts *next to itself*, via
   `dirname "${BASH_SOURCE[0]}"`. Under process substitution `BASH_SOURCE[0]` is **`/dev/fd/63`**,
   so `SCRIPT_DIR` resolves to **`/dev/fd`** — which is not writable. Every download fails.
2. `curl ... | bash` dodges that but breaks the **confirmation prompt**: the script arrives *on
   stdin*, so `read -p` consumes the next **byte of the script itself**. Observed: `REPLY='e'`
   taken from the following `echo`, the run aborted, and bash then reported
   `cho: command not found` because the line had been eaten.

⭐ **Downloading to a real file fixes both — and it is what you want anyway**, because the scripts
stay on the host for a re-run. All of them are idempotent, so re-running is the normal repair path.

If you specifically want to paste *one thing*, use a one-liner that still lands the script in a real
file. This was run and verified on Aug 21, 2026 — all 8 sub-scripts downloaded, the prompt read the
answer correctly, and `n` aborted cleanly:

```bash
cd "$(mktemp -d)" && wget -q http://192.168.1.195/ubuntu/host_setup.sh && bash host_setup.sh
```

The distinction that matters is **one line, not one stream.** Piping is what breaks; length never
had anything to do with it. The cost of this form is that it throws the scripts away with the temp
directory, which is why the two-step version stays the recommendation.

⛔ **Do not try to make the scripts pipe-safe instead.** It looks like a two-line change — redirect
the one `read -p` in `host_setup.sh` from `/dev/tty` — but `host_setup.sh` invokes its sub-scripts
with stdin inherited, and `setup_smb_mount.sh` has its own `read -rsp` for the NAS password. The
identical bug would reappear deeper in the run, at the one point where a corrupted read gets
**written to disk as a credential file** instead of just aborting. Landing the script in a file
fixes the whole chain at once; patching reads fixes it one prompt at a time and fails silently.

Downloads everything first, shows what it got, prompts once, then runs in this order:

| Phase | Script | Gives you |
|-------|--------|-----------|
| 0 Identity | `setup_hostname.sh` | Hostname — **only with `--hostname <name>`** |
| 1 Base | `setup_ssh.sh` | SSH in |
| 1 Base | `setup_sudo.sh` | Passwordless sudo |
| 1 Base | `setup_cockpit.sh` | Web admin on :9090 |
| 2 Tools | `setup_docker.sh` | Docker + Git |
| 3 Storage | `setup_smb_mount.sh` | `~/DevShare` NAS mount |
| 4 Desktop | `setup_desktop.sh` | Full desktop, **or CLI tools + aliases only** on a headless host |

Cockpit sits in Phase 1 with SSH and sudo because it is an *access* method, not a
tool. If a later phase wedges the box, Cockpit is already up and is a second way in.

Phase 0 runs **first**, and only when `--hostname` is passed. The ordering is deliberate: the rename
fixes the `/etc/hosts` entry, and until it does, every `sudo` call in every later phase prints
`sudo: unable to resolve host <old>` and can stall on a DNS timeout. Renaming last would mean doing
the entire build through that noise.

### `--server`, and the 1.44 GB that had been going onto every server

**Added Aug 21, 2026 — Ubuntu first, Fedora the same day (see phase2b).** `--server` skips Google
Chrome, Cursor, the resolution steps,
all the GNOME `gsettings` writes, the terminal profile, the dock and the login keyring. It keeps the
timezone, DNS, CLI tools and shell aliases, on the grounds that `htop`, `jq`, `vim` and the `update`
alias are wanted *more* on a headless box than on a desktop, not less.

🚨 **The flag is the small half of this change. The bug it exposed is the important half.** The gate
deciding whether to run `setup_desktop.sh` was:

```bash
if command -v gnome-shell &> /dev/null || command -v gsettings &> /dev/null; then
```

`gsettings` ships in **`libglib2.0-bin`**, which headless hosts routinely pull in as a dependency of
something else. So the second test passed on machines with no desktop at all, and the build went on
to install a **web browser and an IDE on servers**. Measured on `vm-jenkins-1` (.185), a headless
host:

| | |
|---|---|
| `gnome-shell` | **absent** — correctly headless |
| `gsettings` | `/usr/bin/gsettings` — and this alone opened the gate |
| `cursor` | **1012.4 MB** |
| `google-chrome-stable` | **430.8 MB** |
| **wasted** | **1443.2 MB** |

⭐ **What hid it for months is the part worth remembering: the summary block at the end of the same
script tested `gnome-shell` *alone*.** So a server installed 1.4 GB of desktop applications and then
printed **no line whatsoever** about the desktop step — the work was invisible in the very output
written to tell a human what happened. Two tests for the same question, disagreeing, and the quieter
one was the one doing the reporting. **When two conditions are meant to describe the same thing they
have to *be* the same expression, not two expressions that happen to agree today.** Both now read one
`DESKTOP_MODE` variable, set once.

The detection is also now correct on its own, so `--server` is rarely needed by hand:

| Host | Mode |
|---|---|
| `gnome-shell` present | full desktop |
| `gnome-shell` absent | **server mode automatically** — CLI tools and aliases, no desktop apps |
| `--server` passed | server mode, whatever is installed |

⚠️ Note the deliberate behaviour change: a headless host used to be skipped *entirely* and so got no
CLI tools at all. It now runs in server mode and gets them.

**Fleet survey, Aug 21 2026** — `.185` was headless and carried both apps; `.181`–`.184` genuinely
have desktops so theirs are legitimate; `.186` is clean. The scripts deliberately do not remove
anything — that is not a build script's job — but server mode now *reports* leftovers with the
command to reclaim the space.

✅ **`.185` cleaned the same day:** `sudo apt-get purge -y google-chrome-stable cursor` took it from
**5.7 G to 4.2 G**, and Jenkins stayed `active` and answered HTTP `200` throughout. The purge was
simulated first (`-s`), which confirmed it would touch nothing else.

⚠️ **`autoremove` was deliberately skipped, and this is a judgement worth keeping.** It wanted **100
packages / 382 MB** — every X11 and GTK library Chrome and Cursor had dragged in. Technically safe:
`gcc`, `cc` and `make` are already absent and nothing manually-installed depends on any of them. But
`.185` is a **CI host**, and headless browser testing (Selenium, Playwright, `chrome --headless`)
needs precisely those libraries. Trading a plausible future capability for 382 MB on a 58 G disk is
a bad deal, so they stay. **Do not "finish the cleanup" without revisiting that.**

**Fedora got `--server` the same day**, so the asymmetry warning that used to live here is closed.
Two deliberate differences, both documented in phase2b: Fedora **still masks the systemd sleep
targets** in server mode (a server needs that more than a desktop), and server mode is **exempt from
the D-Bus session-bus requirement**, without which the flag would refuse to run on the very hosts it
was added for. Worth noting the Fedora tree **never had the 1.44 GB bug** — its gate always tested
`gnome-shell` alone — so there the flag is parity rather than repair.

Two smaller fixes came out of the same work. The step labels are now **generated** rather than
hand-written, because the hardcoded ones had already drifted from their own comments — `# Step 3:
Install Google Chrome` printed `[4/12]`, `# Step 5` printed `[6/12]` — and a second mode with a
different step count would have made that worse in both modes at once. And the DNS step now guards
on `nmcli` being present: it is **absent on a netplan/systemd-networkd server** (confirmed on `.185`),
where the bare call printed `command not found` and made the step look broken rather than
not-applicable.

### `setup_hostname.sh` — and why it is not one shared script

`--hostname` was Fedora-only until **Aug 21, 2026**, on the reasoning that every Ubuntu VM here is a
Proxmox clone of template 9000 where cloud-init already sets the name from `qm clone --name`. That
covers *most* Ubuntu hosts, which is not the same as all of them: it leaves out renaming an existing
host, and Ubuntu installed from an ISO rather than cloned — the dev box itself. Both trees now have
it, and the two copies are **deliberately not identical**:

| | Ubuntu / Debian | Fedora |
|---|---|---|
| `/etc/hosts` | **Maintains a `127.0.1.1` line**, creating it if absent — Debian policy, and what `sudo` reads | **Never creates one.** Fedora's nsswitch `hosts:` includes systemd's `myhostname`, which resolves the local name with no file entry. Only rewrites a line that already exists and has gone stale |
| cloud-init | Pins `preserve_hostname: true`; the clone workflow *will* otherwise revert it | Same code, normally a no-op (Workstation has no cloud-init), but Fedora Cloud images do |

⭐ **The thing `hostnamectl` does not do is the thing that matters.** It sets the hostname and stops
there. A rename that skips `/etc/hosts` leaves the new name unresolvable, and the symptom —
`sudo: unable to resolve host <name>` before *every* sudo command, plus a DNS timeout in some tools —
looks nothing like "I renamed the host". Both scripts finish by running `getent hosts <name>`, the
same lookup path `sudo` uses, so the summary reports resolution as a measurement rather than assuming
it.

🚨 **`setup_hostname.sh` is the only script in either tree that can run on the wrong distro and
succeed.** Every other script self-guards *by accident*: they call `dnf` or `apt-get`, so on the
wrong distro they die loudly with "command not found". This one is built entirely from
`hostnamectl`, `sed` and `getent`, which exist everywhere — so it will cheerfully apply Fedora's
`/etc/hosts` policy to a Debian host. Both copies now check `/etc/fedora-release` explicitly. This
was found the hard way: the Fedora copy was run on the Ubuntu dev box and **renamed it**.

⛔ **Two argument bugs were fixed at the same time, in both orchestrators.** A trailing `--hostname`
with no value set an empty string and the hostname phase was silently skipped — no error, no rename,
no clue. Worse, `--hostname --no-nas` set the hostname to the literal string `--no-nas` *and*
consumed the flag, so **the NAS mount ran on a host that had been told not to touch the NAS.** Both
now refuse. The Ubuntu loop also had to change from `for arg in "$@"` to `while`/`shift`, because a
`for` loop sees each argument in isolation and cannot consume the value after a flag.

⚠️ **`setup_hostname.sh` also refuses more than one argument**, which sounds pedantic and is not.
An unquoted shell variable holding `has space` expands to two words; the script took word one, found
`has` to be a perfectly valid hostname, and renamed the machine. It did exactly what it was asked —
the defect was that "a hostname plus junk" was indistinguishable from "a hostname". The `cp -n
/etc/hosts /etc/hosts.orig` backup is what made that recoverable, and it is `cp -n` rather than `cp`
precisely so a second run cannot overwrite the pristine copy with an already-modified one.

**Failure handling (added Aug 21, 2026).** There is deliberately **no `set -e`** in
`host_setup.sh`: aborting on the first non-zero exit would skip the closing summary, which is the
most useful output the script produces. Instead every step's exit code is **recorded**, the summary
lists what failed, and **the run ends non-zero** — because a build that printed failures and then
exited 0 is the same false green as a hardcoded checkmark, and it is the difference between a human
noticing and a wrapper script noticing.

⭐ **One step is exempt from "record and carry on": `setup_sudo.sh` is a hard gate.** Passwordless
sudo is a genuine *prerequisite*, not a feature — every later step runs under sudo and
`setup_desktop.sh` calls it dozens of times. Continuing without it produces a wall of failures whose
real cause has scrolled off the screen long before you reach the summary. Everything else is
recorded and the build continues, because a missing dock icon should not stop a NAS mount.

⚠️ **The Ubuntu summary itself was a false green until the same date** — it printed `✓` for SSH,
sudo, Docker, Git and the desktop **without checking any of them**; only Cockpit and the NAS mount
were ever tested. It now measures all seven, including the Docker **storage driver** (see
`setup_docker.sh` below for why that specific check earns its place).

---

### Individual Scripts

#### 1. setup_ssh.sh
**Run as:** sudo  
**Purpose:** Enable SSH server for remote management

- Installs openssh-server
- Enables and starts SSH service
- Configures firewall (if UFW active)

#### 2. setup_sudo.sh
**Run as:** sudo  
**Purpose:** Passwordless sudo for agamache

- Creates `/etc/sudoers.d/agamache`
- Sets `NOPASSWD: ALL`
- Validates syntax before applying

#### 3. setup_cockpit.sh
**Run as:** sudo
**Purpose:** Cockpit web admin UI at `https://<host>:9090`
**Added:** August 20, 2026 — standard on every Ubuntu server from here on

Gives a browser view of services, logs, storage, users, updates and a root terminal,
on a headless box, without installing a desktop.

- Detects whether NetworkManager is active on the host
- Installs an explicit package list chosen for that answer
- **Simulates the install first and aborts if `network-manager` would appear unexpectedly**
- Enables `cockpit.socket` and confirms something is listening on 9090
- Warns if the login user has no password or no sudo

**THE TRAP — never run `apt install cockpit` on a server VM.**
The `cockpit` metapackage *Recommends* `cockpit-networkmanager`, which drags in
`network-manager` itself along with `dnsmasq-base`, `ppp`, `pptp-linux` and
`wpasupplicant`. Our server VMs run netplan + systemd-networkd. Installing
NetworkManager onto a box whose interfaces are already managed by something else
risks losing the network on a machine we only reach over SSH.

Measured on a swarm node, Aug 20 2026:

| Install | Packages added | Pulls network-manager? |
|---------|---------------|------------------------|
| `apt install cockpit` | 35 | **YES** (+ dnsmasq-base, ppp, pptp-linux, wpasupplicant) |
| Our explicit list | 19 | No |

**The safe list:**
```
cockpit-ws cockpit-bridge cockpit-system cockpit-storaged cockpit-packagekit
```
`cockpit-networkmanager` is added **only** when NetworkManager is already the active
network stack — i.e. desktop builds, where the module manages what is already in
charge and is genuinely useful.

**`cockpit-files` — added Aug 21, 2026, and deliberately NOT in the list above.**

Andrew asked for the Cockpit file manager on every host. On Fedora that is a clean
one-package add. On Ubuntu it **cannot be done that way**, and the reason is worth
keeping:

```
cockpit-files : Depends: cockpit-bridge (>= 318) but 314-1 is to be installed
```

`cockpit-files` exists **only in backports** (v39) and needs a bridge newer than the
314 that noble/main ships. Measured Aug 21, 2026 in clean 24.04 and 22.04 containers.

🚨 **Putting the name in the safe list above would have broken every Ubuntu build.**
`apt-get install` is all-or-nothing, and with `set -e` the script aborts — so hosts
would get **no Cockpit at all** rather than Cockpit minus one plugin.

⭐ The tempting fix, `-t noble-backports`, *does* resolve cleanly and — checked
explicitly — does **not** pull `network-manager`. But it moves the **entire Cockpit
stack from 314 to 362** out of a lower-tier repo on servers. Too much surface for a
file manager, so it was rejected.

**What the script does instead:** installs `cockpit-files` as a **separate, optional
transaction after** the main install, so it can never take Cockpit down with it. It
simulates first and refuses on three conditions — it would pull `network-manager`, it
would remove packages, or it would touch any `cockpit-*` package other than
`cockpit-files` itself (a new bridge beside an old ws is an unsupported split stack).
Otherwise it skips and says why. **No edit will be needed when Ubuntu catches up** —
the moment the distro ships `cockpit-bridge >= 318` it simply starts succeeding.

Both branches were proven in throwaway containers, with the test harness *generated
from the real code block* so it cannot drift: stock 24.04/22.04 → clean SKIP, exit 0,
script continues; backports pinned up → REFUSED with the stack change named.

**Gotchas:**
- Cockpit authenticates through **PAM**, so it needs a real system password. A
  key-only account cannot log in even though SSH works fine.
- The TLS cert is self-signed. The **Cursor built-in browser cannot open it** —
  `ERR_CERT_AUTHORITY_INVALID` with no bypass offered. Use Chrome or Firefox.
- To verify auth without a browser, hit `/cockpit/login`, not `/login`. `/login`
  serves the HTML page and returns 200 for a good *and* a bad password, so it proves
  nothing. `/cockpit/login` returns a `csrf-token` on success.
- Socket-activated: `cockpit-ws` only starts on connect, so idle cost is ~zero.

#### 4. setup_docker.sh
**Run as:** sudo  
**Purpose:** Docker + Git installation

- Installs Git, configures user.name/email
- Adds official Docker apt repository
- Installs Docker CE + Docker Compose plugin
- Writes `/etc/docker/daemon.json` — insecure registry **and** `containerd-snapshotter: false`
- **Verifies the daemon actually loaded both**, then adds the user to the docker group

**Git config:**
- user.name: Andrew Gamache
- user.email: agamache@gothamtechnologies.com
- defaultBranch: main

**🚨 `containerd-snapshotter: false` — added Aug 21, 2026, and the most load-bearing line in the
file.** Docker 29.7.x defaults to the containerd image store, which makes `docker build` emit OCI
image **indexes**. Its push path can send the parent index *before* the child manifest that index
references, and the GitLab registry correctly rejects that:

```
error from registry: blob unknown to registry
```

⭐ **This is the `nofail` bug again, exactly.** It broke CI on the runner `.182` on **Aug 17, 2026**
and was fixed **there, by hand** — the builder never learned it, so *every host this standard
produced between Aug 17 and Aug 21 ships the broken default*. **Fixing one VM fixes one VM; fixing
the builder fixes every future one.** It was found only because the Fedora rewrite measured
`docker info` on a fresh install instead of assuming.

⚠️ **It hides, because it is a RACE, not a certainty.** It only bites when several images have
genuinely new content in one pipeline — a job that changes one image passes and looks like proof the
daemon is fine.

🔲 **Still OPEN: the existing fleet.** The builder is fixed; the hosts already built are not.
Retrofitting means restarting Docker on each, and ⚠️ **images in the old store become invisible to
the new driver** (`docker images` reads empty — expected; rebuild or repull), so it is not a
zero-impact change on anything running.

**The verification step matters as much as the flag.** Writing `daemon.json` is a *claim*;
`docker info` is the daemon's own report of what it loaded. A malformed file makes Docker fail to
start, and a restart that silently kept the old config looks identical to success — so the script
now asserts the registry appears **and** that the storage driver reads `overlay2`, and exits 1 if
not.

#### 5. setup_smb_mount.sh
**Run as:** sudo  
**Purpose:** Mount NAS share permanently

- Installs cifs-utils
- Mounts `//192.168.1.120/NeoCortex/DEV_Projects`
- Mount point: `/mnt/DevShare`
- Creates symlink: `~/DevShare`
- Persists in /etc/fstab with `_netdev,nofail`

**`nofail` (added Aug 20, 2026).** The script wrote `_netdev` but not `nofail` until
now. Without `nofail` the generated unit is `RequiredBy=remote-fs.target`, so an
unreachable NAS fails the mount, fails `remote-fs.target` with it, stalls boot for the
mount timeout and leaves a permanently failed unit. With `nofail` it is only
`WantedBy=` — it still mounts at boot, it just cannot hold boot up.

⚠️ **Correcting an overstatement made earlier the same day.** This was first written up
here as "drops to an emergency console, no network, no SSH." **That is wrong**, and the
lab disproves it: `_netdev` already keeps these entries out of `local-fs.target`, and
`.184` failed this exact mount at *every* boot from July 9 onward while still coming up
with networking and SSH fine. The emergency-console behaviour belongs to network mounts
written **without** `_netdev`. The real cost here is a bounded boot delay (11 s measured
on `.184`, up to ~90 s on a timeout) plus a permanently failed unit. Worth fixing,
**not** the catastrophe first claimed. 🧠 The failure mode was believing a plausible
mechanism instead of checking the one host already running the experiment.

Swept across the whole lab on Aug 20, 2026: **all 9 VMs plus the dev workstation** now
show `RequiredBy=` empty.

##### 🚫 Prod-local hosts must NOT mount the NAS

🙋 **Andrew's rule:** *"184 should NOT mount the NAS! It's prod-local."* `.184`
(`vm-www-1`) is the internet-facing DMZ box. Phase 12 gave it
`OUT DROP -dest 192.168.1.0/24` — **no pivot to the internal LAN** — so the NAS is
unreachable from it *by design*.

**What we found there on Aug 20, 2026.** The standard build had given `.184` the NAS
fstab entry anyway. It had been failing at every boot since **July 9**, and — worse
than the noise — it left **`/root/.smbcredentials` sitting on the internet-facing
host** for a share it is forbidden to reach. Removed: fstab line, mount unit,
`/mnt/DevShare`, and the credentials file. `.184` now reports **zero failed units**.

⭐ **The security point, which is the real lesson: a build standard applied uniformly
will plant credentials on hosts your network design deliberately isolates.** The
firewall was doing its job perfectly; the *builder* was the leak. Blanket automation
and a tiered network are in tension, and the automation has to know about the tiers.

**Two guards now enforce this, belt and braces:**

| Guard | Behaviour |
|---|---|
| `bash host_setup.sh --no-nas` | Skips the NAS step outright. The deliberate choice for a known prod-local host. |
| Reachability pre-check in `setup_smb_mount.sh` | Tests `<nas>:445` first and **refuses** to write an fstab entry or credentials if it cannot connect. Catches the case where nobody remembered the flag. |

The pre-check is the one that matters, because it would have prevented the `.184`
situation with no operator knowledge at all. Verified by running the script **on `.184`
itself**: it refused, wrote nothing, and left the host clean.

⚠️ **`SKIP_NAS=1 sudo -E …` does not work on these boxes.** sudo is built with
`env_reset`; it prints *"preserving the entire environment is not supported"* and
silently drops the variable — the script then runs in full. Put the assignment
**after** sudo: `sudo SKIP_NAS=1 bash ./setup_smb_mount.sh`.

**NAS credentials:**
- Server: 192.168.1.120
- User: fiberoptix
- Password: [See PASSWORDS.md]

#### 6. setup_desktop.sh
**Run as:** user (not sudo)  
**Purpose:** Full desktop environment configuration

**12 Steps** (this list said "11 Steps" and omitted the DNS step until Aug 21, 2026):
1. Set timezone to America/New_York
2. Set DNS to Google (8.8.8.8) + Cloudflare (1.1.1.1) via `nmcli`
3. Install CLI tools (curl, wget, htop, **btop**, vim, jq, net-tools, tree, unzip, sysbench)
4. Install Google Chrome (via .deb)
5. Install Cursor (via apt - official repo) + AppArmor profile for its sandbox
6. Set display resolution to 1920x1080
7. Hide Home folder icon; file manager list view + show hidden; dock size/panel mode
8. Disable screen lock and screen saver
9. Create "Andrew" terminal profile (200x50, transparent dark)
10. Configure dock icons (Files, Chrome, Firefox, Cursor, Terminal, SysMon, Settings, Editor)
11. Disable login keyring prompt (auto-unlock)
12. Add bash aliases:
    - `godev` → `cd ~/DevShare`
    - `update` → `sudo apt update && sudo apt upgrade -y`
    - `sysbench` → `sysbench --threads=$(nproc) cpu run`

⭐ `btop` added Aug 21, 2026 at Andrew's request, to **both** this script and the Fedora one.
Verified present in the default repos of Ubuntu 24.04 (1.3.0) and 22.04 (1.2.3) before adding —
`apt-get install` is all-or-nothing, so one unavailable name in that list installs **none** of the
tools. The script now also checks each binary individually afterwards, because the old
"WARNING: Some tools may have failed" could equally mean *one* missing or *all ten*.

**Cursor Installation Note:**
Official Cursor GPG key URL is broken. Key is hosted locally at:
`http://192.168.1.195/ubuntu/anysphere.gpg`
(⭐ Ubuntu-only. Fedora's `downloads.cursor.com/yumrepo` **and** its key both return HTTP 200, so
`www/fedora/` points straight at the official source and mirrors nothing.)

**🚨 The closing summary was a false green until Aug 21, 2026, and this is the defect worth
remembering.** It printed **fifteen hardcoded checkmarks**. Every `gsettings` call in this script
ends in `2>/dev/null || true`, and three of the schemas it writes to do not exist on every host
(`ding`, `desktop-icons`, `dash-to-dock`) — so the write failed, the error was swallowed, and the
summary still announced *"✓ Home folder: Hidden"* and *"✓ Dock panel mode: Disabled"* **having
changed nothing.** ⭐ *A false green in our own tooling is worse than a red, because a red gets
investigated.*

✅ Rewritten to **read every value back** and report `ok` / `WARN` / `--`, where `--` means the
schema is genuinely absent on this host (an honest outcome, not counted against the run) and `WARN`
means we wrote something and it did not stick. The script now **exits non-zero** when anything
warns, so `host_setup.sh` can report the desktop step's real verdict instead of assuming one.
Verified by running the new summary in a bare Ubuntu 24.04 container with no `gsettings`, `nmcli`
or `dconf` present at all: it degraded to `--`/`WARN` lines and exited 1 rather than crashing.

**🪲 The resolution autostart entry named the wrong output (fixed Aug 21, 2026).** Step 6 detects
the display dynamically into `$DISPLAY_NAME`, but the autostart file written near the end of the
script was hardcoded to `Exec=xrandr --output Virtual-1 --mode 1920x1080`. On any host whose output
is not named `Virtual-1`, the resolution was correct for that session and then **silently reverted
at next login** — and because the detection above it worked, the failure looked like GNOME
forgetting the setting rather than a bug here. It now uses the detected name, and **skips with a
stated reason** in the two cases where the entry could only ever be dead weight: no display
detected, or a Wayland session (where `xrandr` sees only XWayland and cannot set a mode).

---

## Test VM: vm-kubernetes-1

Created a test VM to validate all scripts:

| Property | Value |
|----------|-------|
| Name | vm-kubernetes-1 |
| IP | 192.168.1.180 |
| User | agamache |
| Password | [See PASSWORDS.md] |
| OS | Ubuntu 24.04 Desktop |
| Storage | vm-ephemeral pool |

**All scripts tested and working on this VM.**

> **Naming update, Aug 2026.** This VM never ran Kubernetes and its VMID (200) never
> matched its IP (.180). It was cloned to **VMID 180, `vm-docker-qa-1`** on Aug 20,
> 2026 and is now the Capricorn QA deploy target. The old name above is left in place
> as the historical record of what was tested in Dec 2025.

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Script server on DEV machine | Central location, easy to update |
| Docker nginx vs Python SimpleHTTP | More robust, auto-restart |
| Cursor via apt (not AppImage) | Proper package management, auto-updates |
| Passwordless sudo | Required for automation |
| GPG key hosted locally | Official URL returns 403 |
| Keyring auto-unlock | Eliminates annoying prompt on desktop VMs |
| Cockpit on every server (Aug 2026) | Browser-based admin on headless boxes without installing a desktop |
| Explicit Cockpit packages, never the metapackage | The metapackage Recommends NetworkManager, which fights netplan/systemd-networkd |
| The script simulates before it installs | A comment saying "don't pull NetworkManager" gets ignored; a script that refuses to proceed does not |
| `nofail` on the NAS fstab entry (Aug 2026) | A NAS outage must not strand a headless VM at an emergency console |

---

## Future Scripts (When Needed)

| Script | Purpose | When |
|--------|---------|------|
| setup_gitlab.sh | GitLab CE installation | Building GitLab VM |
| setup_runner.sh | GitLab Runner + registration | Building Runner VM |
| setup_sonarqube.sh | SonarQube container | Building SonarQube VM |
| setup_monitoring.sh | Prometheus + Grafana | Building Monitoring VM |
| setup_traefik.sh | Reverse proxy + SSL | Building Traefik VM |
| setup_tailscale.sh | VPN for admin access | When ready for remote access |

---

## Related Files

- `/www/` - Script server directory
- `/proxmox/credentials` - All passwords
- `/proxmox/Home_Lab_Proxmox_Design.md` - VM architecture plan

