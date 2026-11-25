# The dev workstation (.195, a VMware guest on the Z8), OS upgrade, tooling

Topic reference (not tied to one phase). Loaded ON TOUCH via `phases/INDEX.md`. Blocks below are copied VERBATIM from `MEMORY.md` as of tag `pre-memory-diet` (Nov 24, 2026).

---

## COPIED VERBATIM FROM `MEMORY.md` @ `pre-memory-diet` (lines 814–846) — Nov 24, 2026 (memory-diet, copy-first) — Dev OS upgrade 25.10 -> 26.04

- **✅ Dev workstation OS upgrade: Ubuntu 25.10 → 26.04 LTS — July 25, 2026.** The Z8's
  VMware guest (`VM-UBUNTU-01`, the machine we work from — NOT infra, logged here because
  it's our tooling host). Now **26.04 "Resolute Raccoon", kernel 7.0.0-28**. Upgrade itself
  was clean (0 broken pkgs, 0 failed units). Post-upgrade review found + fixed 4 real breaks:
  - **All 5 third-party apt repos were disabled** by `do-release-upgrade` (standard behavior).
    Re-enabled cursor/docker/chrome/hashicorp + fixed stale suites (docker `questing`→`resolute`,
    hashicorp `noble`→`resolute`). That surfaced 7 Docker pkgs still on 25.10 builds → upgraded
    to the 26.04 rebuilds (same versions); daemon restart bounced containers, all returned
    (`unless-stopped`). **NodeSource left DISABLED on purpose** (pinned dead `node_20.x`, older
    than Ubuntu's node 22 → would conflict; re-enabling needs an apt pin).
  - **npm/npx vanished:** node moved NodeSource 20 → Ubuntu's **22.22.1**, which doesn't bundle
    npm. Ubuntu's `npm` pkg wanted **377** `node-*` deps for a 2022-era npm 9 → skipped. Instead
    installed official **npm 11.18.0** standalone in `/usr/local` (npm 12 needs node ≥22.22.2;
    Ubuntu ships .1). Upgrade path later: `sudo npm i -g npm@latest`. corepack also gives pnpm/yarn.
  - **Python 3.13 → 3.14 orphaned 38 user pip pkgs** (`~/.local/lib/python3.13`, 82M, deleted;
    inventory saved at `~/python313-packages-before-2604-upgrade.txt`). poetry+virtualenv
    rebuilt via **pipx** (isolated venvs → immune to future python bumps). Flask 2.0.3 + httpx
    deliberately NOT recreated (26.04 enforces PEP 668; nothing on the host needs them — the
    Capricorn backend gets httpx from its container).
  - **`sshfs-openclaw.service` disabled** — was retrying the retired VM 185 every 100s forever.
  - Housekeeping: 37 `rc` configs purged, orphaned postgresql-client-17 removed (18 present),
    17 stale snap revs deleted (5.2G→2.7G) + `refresh.retain=2`, dead apt `.bak`/`.orig` files
    archived to `/root/apt-sources-backup-20260725/`. Kept 6.17.0-41 kernel as fallback.
  - Config files the upgrade replaced (all reviewed, no loss): sysctl.conf identical, grub kept
    ours, gdm3 autologin survived, ca-certificates replaced with 26.04 default (distrusts 39
    legacy Mozilla CAs — correct, applied cleanly).
  - Verified after: Docker 29.6.2 + all 5 containers up, Capricorn FE/BE 200, GitLab 200,
    public https 200, CIFS `/mnt/DevShare` mounted, ssh-agent key loaded, journal clean.
  - **Capricorn NOT reviewed** (app layer, own project). Checked exposure only: backend
    container = python 3.11.8, frontend container = node 22.23.1, host `node_modules` has no
    native `.node` binaries, no engines/.nvmrc pin → host node 20→22 actually aligns *closer*
    to the containers. No action expected.

---

## COPIED VERBATIM FROM `MEMORY.md` @ `pre-memory-diet` (lines 1014–1025) — Nov 24, 2026 (memory-diet, copy-first) — dev workstation guest + piper-say

- **Dev workstation guest** = `VM-UBUNTU-01`, VMware Workstation on the Z8, 24 vCPU (2 sockets x12, on idle PROC1), **Ubuntu 26.04 LTS** since Jul 25, 2026 (see CURRENT STATE). Uses `open-vm-tools`, NOT qemu-guest-agent (that's for the Proxmox VMs). Not on Tailscale.
- 🔊 **THE AI CAN SPEAK ON THIS BOX — `piper-say "text"`** (Piper TTS, installed Sep 16, 2026 at
  Andrew's request). Convention: **speak the reply when he says "answer me in piper", and announce
  completion out loud after a long task.**
  - **Voice: `en_GB-cori-high` at `length_scale 0.9`** — chosen by Andrew after auditioning. Wrapper is
    `~/.local/bin/piper-say`; engine and voice models under `~/.local/share/piper/` (all user-local).
  - 🚨 **IT ONLY PLAYS AT A PROPER LEVEL WHILE THE GNOME SOUND CONTROL PANEL IS ACTIVELY OPEN.** With it
    closed the audio is far too quiet to hear. Cause not established; the panel appears to hold the
    emulated VMware sound device open. ⚠️ **So a spoken notice can be MISSED if the panel is shut.**
  - 📌 Full diagnostic detail — an `apt install piper` name collision, a `paplay --volume` setting that
    persisted via `module-stream-restore` and clipped every playback, and the measurement method that
    found it — is **deliberately not kept here.** It lives in the Sep 16, 2026 commit messages.
