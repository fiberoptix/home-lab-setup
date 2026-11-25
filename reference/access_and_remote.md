# SSH access matrix + remote lab management (laptop / tailnet)

Topic reference (not tied to one phase). Loaded ON TOUCH via `phases/INDEX.md`. Blocks below are copied VERBATIM from `MEMORY.md` as of tag `pre-memory-diet` (Nov 24, 2026).

---

## COPIED VERBATIM FROM `MEMORY.md` @ `pre-memory-diet` (lines 1275–1329) — Nov 24, 2026 (memory-diet, copy-first) — SSH ACCESS MATRIX

### SSH ACCESS MATRIX — the intended policy, fully verified Aug 12, 2026

**The policy Andrew wants, and which now holds:** key auth from the dev box to *everything* with
password as fallback, and **password-only** access from any other machine (laptop while remote).

| Target | User | Key auth from dev box (.195) | Password fallback | From remote tailnet |
|---|---|---|---|---|
| **.150 pve** | `root` | ✅ (`authorized_keys2`) | ✅ | ✅ direct, it *is* the tailnet node |
| **.180 vm-docker-qa-1** | `agamache` | ✅ | ✅ | ✅ via subnet route — **the Aug 20 clone kept the same SSH host keys, so `known_hosts` did NOT need clearing** |
| **.181 vm-gitlab-1** | `agamache` | ✅ | ✅ | ✅ via subnet route |
| **.182 vm-gitrun-1** | `agamache` | ✅ | ✅ | ✅ via subnet route |
| **.183 vm-sonarqube-1** | `agamache` | ✅ | ✅ | ✅ via subnet route |
| **.184 vm-www-1** | `agamache` | ✅ | ✅ | ✅ — see the firewall note below |
| **.185 vm-jenkins-1** | `agamache` | ✅ | ✅ | ✅ via subnet route — ⛔ **this is Jenkins now, NOT OpenClaw.** `vm-openclaw-1` was destroyed Aug 19, 2026 and the VMID + address were reused. Re-verified by key login Aug 26, 2026 |
| **.186 vm-k8-redpanda-1** | `agamache` | ✅ | ✅ | ✅ via subnet route |
| **.191 docker-swarm-1** | `agamache` | ✅ | ✅ | ✅ via subnet route |
| **.192 docker-swarm-2** | `agamache` | ✅ | ✅ | ✅ via subnet route |
| **.193 docker-swarm-3** | `agamache` | ✅ | ✅ | ✅ via subnet route |

⭐ **Rows for `.185` and the three Swarm nodes added Aug 26, 2026.** The matrix had been frozen at its
Aug 12 shape, so it still described `.185` as a destroyed VM awaiting rebuild and omitted the Swarm
entirely. All four were re-verified that day by real key logins (`ssh -o BatchMode=yes`, which cannot
fall back to a password — so a success proves key auth rather than merely proving reachability).

Every VM reports `passwordauthentication yes` with `agamache` holding a usable password
(`passwd -S` → `P`), and the host the same for `root`. **Proven by test, not by reading config** —
password-only logins were confirmed with `ssh -o PubkeyAuthentication=no
-o PreferredAuthentications=password` against .150, .181, .184 and .186. Config that *says* yes and
an account whose password is locked look identical until you try it.

**How remote (laptop) access actually works — this is the part worth understanding:**

1. **The pve host is a Tailscale subnet router.** It advertises **`192.168.1.0/24`**, and the route
   is approved (it shows in `PrimaryRoutes`). So any device on the tailnet can address
   `192.168.1.x` directly — there is no need to put Tailscale on each VM. ⛔ **Corrected Aug 19, 2026:
   `.185` used to be the only VM running Tailscale, and it was destroyed — so NO VM runs Tailscale
   now.** Remote access depends entirely on the subnet route advertised by the pve host.
2. **Subnet routing SNATs by default** (`NoSNAT: false`). Traffic from a remote laptop therefore
   arrives at the VMs **with a source IP of `192.168.1.150`**, not the laptop's `100.x` address.
3. ⚠️ **That SNAT is what makes .184 reachable at all.** `184.fw` is `policy_in: DROP` and permits
   port 22 from only three sources — `.182` (runner), `.195` (dev box) and **`.150` (the host)**.
   Remote traffic passes *because* it is rewritten to `.150`. Verified by SSHing from the pve host to
   all six live VMs, which is the same post-SNAT path.
4. ⚠️ **The corollary: remote logins are indistinguishable from host logins in the VMs' auth logs** —
   everything appears to come from `.150`. Do not build fail2ban rules, audit trails or source-IP
   allow-lists on VM-side source IPs and expect them to identify a remote user.
5. **The tailnet devices that matter:** `bullpup` (macOS laptop) and `fibermedia` (macOS).
   ⚠️ **This dev box is NOT on the tailnet** — `agamache-z8g4` on the tailnet is the *Windows Z8
   host*; the dev box is the VMware guest inside it. Remote work from the dev box goes via Windows.
6. **No guest-level firewall is in the way:** `ufw` is `inactive` on all six live VMs. **Only .184 has
   PVE-level rules** (`.185`'s went away with the VM on Aug 19, 2026); `cluster.fw` is enabled but
   carries no rules of its own.

---

---

## COPIED VERBATIM FROM `MEMORY.md` @ `pre-memory-diet` (lines 1330–1437) — Nov 24, 2026 (memory-diet, copy-first) — REMOTE LAB MANAGEMENT

## REMOTE LAB MANAGEMENT (laptop, outside the house) — verified Aug 12, 2026

**Answer to "can I manage the lab from my laptop over the tailnet?" — yes, completely.** Every link
below was tested, not inferred. **There are two routes**, and they differ in one important way:
**Route A puts plaintext credentials on the laptop, Route B does not.** Prefer B.

### Route A — work from the laptop itself (requires cloning the credentials)

1. **Tailscale up on the laptop.** The **pve host is the tailnet's subnet router**, advertising an
   approved **`192.168.1.0/24`**, so every LAN address is directly reachable. No VM needs Tailscale.
2. **DNS needs no setup.** `gitlab.gothamtechnologies.com` resolves to **`192.168.1.181` from public
   DNS** (verified against `8.8.8.8`) — a private address published in public DNS. You do **not**
   need an `/etc/hosts` entry on the laptop.
3. **Clone the GitLab mirror to get the credentials** (see the warning below):
   ```bash
   git clone http://root:<pw>@gitlab.gothamtechnologies.com/production/home-lab-setup.git
   ```
   Verified from a post-SNAT source: the `git-upload-pack` endpoint returns **HTTP 200** with the
   root credentials and **401** without, so auth genuinely works over the tailnet path.
4. **Then manage everything** — SSH by password to `root@.150` and `agamache@<any VM>`, plus the
   **Proxmox web UI on `.150:8006`** (open, verified) for console, snapshots and start/stop.

⚠️ **Clone GitLab, NOT GitHub — GitHub has no credentials at all.** `PASSWORDS.md` is gitignored, so
it is **absent from GitHub's `main`** along with every other secret. The **GitLab mirror is the
plaintext snapshot** and is the only place that carries `PASSWORDS.md`, `github_credentials.md`,
`proxmox/credentials`, `proxmox/nas_credentials` and `www/smb_credentials`. **No private keys
are tracked in either remote** (verified) — that is deliberate and should stay true.

### Route B — tailnet into the dev box, then drive the pve **GUI** (no credential clone needed)

**This is the better route when the goal is "manage the lab", and it avoids putting `PASSWORDS.md`
on the laptop at all.** The dev box already holds the SSH keys and this repo, so once you are on it
you are in exactly the position you are in at home.

⚠️ **Precisely: you cannot Tailscale *into the dev box itself* — it is not a tailnet node.**
Tailscale is **not installed** on it (no binary, no `tailscaled`, no `tailscale0`), verified
Aug 12, 2026. The tailnet's `agamache-z8g4` is the **Windows Z8 host** (`100.70.244.97`, LAN
`192.168.1.115`); the dev box is the **VMware Workstation guest inside it** (`VM-UBUNTU-01`, `.195`).
So the Windows host is the entry point and the dev box is one hop further in.

```
laptop ──tailnet──► agamache-z8g4 (Windows Z8, RDP :3389 verified OPEN)
                        ├──► browser ──► https://192.168.1.150:8006     (pve GUI, quickest)
                        └──► VMware Workstation console ──► VM-UBUNTU-01 (.195, the dev box)
                                                              └──► pve GUI + SSH keys + this repo
```

**Why prefer landing on the dev box:** its SSH keys reach the host and every VM (see the access
matrix), and the repo with `PASSWORDS.md` is already there — so **no plaintext credentials ever touch
the laptop**, which removes the biggest risk in Route A.

**Three ways to reach the Proxmox GUI at `https://192.168.1.150:8006`** (port verified open),
cheapest first — pick by how much capability you need:

1. **Laptop browser, straight there.** The subnet route makes `.150:8006` reachable with no clone and
   no RDP. Log in `root` / PVE password. **Enough for start/stop, console, snapshots and `qm` work.**
2. **RDP to the Windows Z8, use its browser.** Same GUI, full desktop, and it does not depend on
   `.150`'s `tailscaled` (see gap 3).
3. **RDP to the Windows Z8 → VMware console → dev box.** The full working environment: Cursor, this
   repo, and key-based SSH to the host and every VM. Slowest to reach, most capable once there, and
   the only one that can push to GitHub.

> **Optional improvement, not done:** installing Tailscale **on the dev box** would make it a direct
> tailnet node and remove the RDP hop entirely. Worth considering if remote work becomes routine —
> it would make Route B as cheap as Route A while keeping the no-credentials-on-laptop benefit.

### Three real gaps — know these before you rely on remote access

1. ⚠️ **Route A cannot push to GitHub** (Route B can). `origin` is `git@github.com:...` over **SSH**,
   and the private key is (correctly) not in the repo; `github_credentials.md` holds a password and
   an SSH-key reference but **no personal access token**. **GitLab pushes work fine** from either
   route (credentials are embedded in the remote URL), so laptop work can be committed and mirrored —
   just not published to GitHub until you are home, on the dev box, or the laptop's key is registered.
2. ⚠️ **Route A has a bootstrap circularity:** you need the **GitLab root password to obtain the file
   that stores your passwords.** It is the standard lab password, so in practice fine — but it must
   **also** live in a password manager, never only in this repo. Route B sidesteps this entirely.
3. ⚠️ **No out-of-band console exists.** If you break the pve host's bridge or firewall while remote,
   **nothing recovers it until you are physically home** — neither route helps, because both
   ultimately need `.150` to be up and on the network. **Treat any network or firewall change on
   `.150` as unsafe to attempt remotely.**
   - ✅ **But remote *entry* is no longer single-path.** `.150`'s `tailscaled` is only required for
     **Route A**; **Route B enters through `agamache-z8g4`**, which is its own independent tailnet
     node with a direct connection. So if pve's `tailscaled` dies or the subnet route stops being
     advertised, **Route B still reaches the lab over the LAN.** That makes the Windows Z8 the de
     facto backup entry point — worth keeping powered on and RDP-reachable when travelling.
   - Also in place for Route A: `tailscaled` on `.150` is `systemctl enabled` **and** the node's key
     has **no expiry** (`KeyExpiry: None`), so neither a reboot nor months away locks you out.

### Smaller notes

- **macOS and Windows accept advertised subnet routes by default**; a **Linux** laptop needs
  `tailscale up --accept-routes` or it will not see `192.168.1.0/24`.
- Tailnet laptops on file: `bullpup` (macOS), `fibermedia` (macOS). ⚠️ `agamache-z8g4` is the
  **Windows Z8 host**, not the dev box — the dev box (VMware guest) is *not* on the tailnet.
- 🔒 **Laptop hygiene (Route A only):** that clone writes the GitLab root password into `.git/config`
  and drops `PASSWORDS.md` in plaintext next to it. **A lost, unencrypted laptop is the whole lab.**
  Full-disk encryption is load-bearing, and the clone should be deleted when the trip ends. **Route B
  avoids all of this** — nothing sensitive is ever copied off the LAN.
- ⚠️ **The repo itself lives on the NAS, not on the dev box or the Windows host.** `/mnt/DevShare` is
  `//192.168.1.120/NeoCortex/DEV_Projects` over CIFS (per `/etc/fstab`). So Route B depends on **`.120`
  being up** as well as `.150` — and it is the reason for the stale-cache hazard documented in the
  workstation gotcha at the top of this file. (The Windows Z8's open `445` is ordinary Windows file
  sharing and is *not* the source of this mount.)
- Remote logins reach the VMs **source-NATted as `192.168.1.150`** — see the SSH ACCESS MATRIX above
  for why that matters to `.184`'s firewall and to any log-based auditing.

---

---

## COPIED VERBATIM FROM `MEMORY.md` @ `pre-memory-diet` (lines 188–197) — Nov 24, 2026 (memory-diet, copy-first) — CURRENT STATE: lab access sorted

- **🔑 LAB ACCESS IS NOW FULLY SORTED (Aug 12, 2026) — read the two sections below before debugging
  any connection problem:** `CREDENTIALS → SSH ACCESS MATRIX` and `REMOTE LAB MANAGEMENT`.
  Headlines: **every VM logs in as `agamache`, never `andrew`** (a wrong username returns
  `Permission denied (publickey,password)`, which looks exactly like a missing key and wasted real
  time today); **the Proxmox host now accepts the workstation key** via `/root/.ssh/authorized_keys2`
  (*not* `authorized_keys`, which is a PVE-managed symlink into `/etc/pve/priv/`); and **remote
  access works two ways** — a laptop on the tailnet via the host's approved `192.168.1.0/24` subnet
  route, or RDP into the Windows Z8 (`agamache-z8g4`) and drive the pve GUI from there, which keeps
  all plaintext credentials on the LAN and survives `.150`'s `tailscaled` failing.

---

## COPIED VERBATIM FROM `MEMORY.md` @ `pre-memory-diet` (lines 1242–1274) — Nov 24, 2026 (memory-diet, copy-first) — CREDENTIALS + key-auth traps

## CREDENTIALS

**File:** `/proxmox/credentials`

- Proxmox: root / [See PASSWORDS.md]
- All VMs: agamache / [See PASSWORDS.md]
- **SSH key auth:** ✅ ed25519 key deployed to ALL VMs (.180–.186) from dev workstation
  (Feb 27, 2026; **.186 inherited it from the cloud-init template**, verified working Aug 12, 2026).
  - ⚠️ **The login user on every VM is `agamache`, never `andrew`.** `ssh andrew@192.168.1.186`
    fails with `Permission denied (publickey,password)`, which reads exactly like a missing key and
    sends you off fixing a problem that does not exist. Verified working:
    `ssh agamache@192.168.1.186` → `kubectl` and `rpk` are on `PATH` with `~/.kube/config` already
    in place, and `sudo -n` needs no password.
  - ✅ **Proxmox HOST key auth added Aug 12, 2026 — `ssh root@192.168.1.150` now works with the
    workstation key**, so `qm` work no longer needs the password from PASSWORDS.md.
    - **The key went in `/root/.ssh/authorized_keys2`, deliberately NOT `authorized_keys`.** The
      latter is a **symlink to `/etc/pve/priv/authorized_keys`** — a PVE-managed file on the cluster
      filesystem that holds only the cluster's own `root@pve` RSA key, and that PVE rewrites on
      cluster operations. `sshd -T` on the host reports
      `authorizedkeysfile .ssh/authorized_keys .ssh/authorized_keys2`, so the second file is read
      natively: **no sshd config change and no service restart were needed.**
    - Verified with password auth explicitly disabled
      (`ssh -o PreferredAuthentications=publickey -o PasswordAuthentication=no root@192.168.1.150`),
      which is the only way to prove the key is doing the work rather than a silent password
      fallback. `sshd` was left untouched: `permitrootlogin yes`, `passwordauthentication yes`.
    - ⚠️ Until Aug 12 this was the trap that made host work painful, and it is the *same* trap
      documented in the cloud-init section: the workstation key lives in
      `/root/cloudinit-keys-all.pub`, which **sshd never reads**. If host key auth ever stops
      working, check `authorized_keys2` still exists before assuming anything else.
- **GitLab Web: root / [See PASSWORDS.md]**
- **SonarQube Web: admin / [See PASSWORDS.md]**
- NAS (SMB): fiberoptix / [See PASSWORDS.md] @ 192.168.1.120
