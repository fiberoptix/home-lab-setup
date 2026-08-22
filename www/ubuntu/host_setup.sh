#!/bin/bash
#
# host_setup.sh - Master setup script for new Ubuntu hosts
#
# Usage: 
#   1. wget http://192.168.1.195/ubuntu/host_setup.sh
#   2. bash host_setup.sh    (NOT sudo - script handles sudo internally)
#
#   Options:
#     --no-nas              prod-local/DMZ host: skip the NAS mount entirely
#     --hostname <name>     set the static hostname, fix /etc/hosts, and pin it
#                           so cloud-init cannot revert it at the next reboot
#     --server              headless host: no Chrome, no Cursor, no GNOME settings.
#                           Still installs the CLI tools and shell aliases.
#

# If run with sudo, remember the original user
ORIGINAL_USER="${SUDO_USER:-$USER}"

# --no-nas: for DMZ / prod-local hosts that must never reach the NAS (e.g. .184).
# setup_smb_mount.sh also refuses on its own if the NAS is unreachable, so this flag
# is the "I meant it" version that skips the attempt and the error entirely.
#
# This is a `while`/`shift` loop, not `for arg in "$@"`. It has to be: a `for` loop
# sees each argument in isolation and CANNOT consume the value after --hostname.
SKIP_NAS=0
NEW_HOSTNAME=""
SERVER_MODE=0
usage() {
    echo "Usage: bash host_setup.sh [--no-nas] [--hostname <name>] [--server]"
    echo "  --no-nas             prod-local/DMZ host: skip the NAS mount entirely"
    echo "  --hostname <name>    set the static hostname"
    echo "  --server             headless host: skip Chrome, Cursor and GNOME"
    echo "                       settings; keep CLI tools and shell aliases"
}
while [ $# -gt 0 ]; do
    case "$1" in
        --no-nas) SKIP_NAS=1 ;;
        --server) SERVER_MODE=1 ;;
        --hostname)
            # Both of these were silent failures before Aug 21, 2026: a trailing
            # `--hostname` set an empty value and the hostname phase was simply
            # skipped with no message, and `--hostname --no-nas` set the hostname
            # to the literal string "--no-nas" AND consumed the real flag, so the
            # NAS mount ran on a host that had been told not to. Both now refuse.
            if [ $# -lt 2 ] || case "$2" in -*) true ;; *) false ;; esac; then
                echo "ERROR: --hostname needs a name after it (got: ${2:-nothing})"
                usage
                exit 1
            fi
            shift
            NEW_HOSTNAME="$1" ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "ERROR: unknown option '$1'"
            usage
            exit 1 ;;
    esac
    shift
done

SCRIPT_SERVER="http://192.168.1.195/ubuntu"

# Get the directory where this script is located (where user downloaded it)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Scripts to download. setup_hostname.sh is fetched unconditionally even though it
# only runs with --hostname: downloading the full set keeps the manifest identical
# on every host, so a later `bash setup_hostname.sh newname` works on a box that
# was built without the flag.
SCRIPTS="setup_ssh.sh setup_sudo.sh setup_cockpit.sh setup_docker.sh setup_smb_mount.sh setup_desktop.sh setup_hostname.sh anysphere.gpg"

echo "=========================================="
echo "     Ubuntu Host Setup - Master Script"
echo "=========================================="
echo ""
echo "Script Server: $SCRIPT_SERVER"
echo "Scripts Dir:   $SCRIPT_DIR"
echo ""
echo "This will configure a new Ubuntu host with:"
if [ -n "$NEW_HOSTNAME" ]; then
echo "  • Hostname: $NEW_HOSTNAME (currently $(hostname))"
fi
echo "  • SSH server"
echo "  • Passwordless sudo"
echo "  • Cockpit web admin (https://<host>:9090)"
echo "  • Docker + Git"
if [ "$SKIP_NAS" -eq 1 ]; then
echo "  • NAS mount: SKIPPED (--no-nas)"
else
echo "  • NAS mount (~/DevShare)"
fi
if [ "$SERVER_MODE" -eq 1 ]; then
echo "  • SERVER mode (--server): CLI tools + shell aliases only"
echo "    NO Chrome (~431 MB), NO Cursor (~1012 MB), no GNOME settings"
elif command -v gnome-shell >/dev/null 2>&1; then
echo "  • Desktop config: Chrome, Cursor, dock, GNOME settings"
else
# Say what will happen, not what might. This line used to read "Desktop config
# (if desktop environment)" in every case -- which on a server was both vague
# and, thanks to the gsettings gate, wrong: it DID install the desktop apps.
echo "  • Server mode (auto: no gnome-shell): CLI tools + shell aliases only"
echo "    NO Chrome, NO Cursor, no GNOME settings"
fi
echo ""
echo "=========================================="
echo ""

# ============================================
# DOWNLOAD ALL SCRIPTS FIRST
# ============================================
echo "╔════════════════════════════════════════╗"
echo "║  Downloading all scripts to $SCRIPT_DIR"
echo "╚════════════════════════════════════════╝"
echo ""

cd "$SCRIPT_DIR"

# ---------------------------------------------------------------------------
# REFUSE TO RUN INSIDE THE SCRIPT LIBRARY ITSELF. Added Aug 21, 2026, after
# doing exactly this and destroying the library.
#
# `wget -O <file>` TRUNCATES the destination the moment it opens it, before the
# transfer. nginx serves www/ubuntu/ straight off disk via a bind mount, so
# running this script with SCRIPT_DIR == www/ubuntu means wget empties the file
# and *then* asks nginx for it -- and nginx reads back the zero bytes wget just
# wrote. All seven sub-scripts plus anysphere.gpg went to 0 bytes in one run.
# host_setup.sh survived only because it is not in its own download list.
#
# ⭐ The general shape: a program that fetches its inputs into its own source
# directory, from a server backed by that same directory, will eat itself. Detect
# it rather than document it -- the source tree is identifiable by the two files
# that sit beside it.
# ---------------------------------------------------------------------------
if [ -f "${SCRIPT_DIR}/../nginx.conf" ] && [ -f "${SCRIPT_DIR}/../docker-compose.yml" ]; then
    echo "ERROR: refusing to run inside the script library source tree."
    echo "       $SCRIPT_DIR"
    echo ""
    echo "       This directory IS what the script server publishes. Downloading"
    echo "       into it overwrites the originals with copies of themselves, and"
    echo "       a truncate-then-read race zeroes them instead."
    echo ""
    echo "       To test the orchestrator, run it from anywhere else:"
    echo "         cd \"\$(mktemp -d)\" && wget ${SCRIPT_SERVER}/host_setup.sh && bash host_setup.sh"
    exit 1
fi

DOWNLOAD_FAILED=0
for script in $SCRIPTS; do
    echo -n "  Downloading $script... "
    # Download to a temporary file and move it into place only on success.
    #
    # `wget -O dest` truncates dest before the transfer, so a failed or partial
    # download REPLACES A WORKING SCRIPT WITH AN EMPTY FILE. That matters most in
    # the case this script is designed for: re-running on a host to repair it. A
    # momentary network blip would have left the box with eight empty scripts and
    # no way to tell that was what happened.
    TMP_DL="${SCRIPT_DIR}/.${script}.part"
    if wget -q -O "$TMP_DL" "${SCRIPT_SERVER}/${script}" && [ -s "$TMP_DL" ]; then
        mv -f "$TMP_DL" "${SCRIPT_DIR}/${script}"
        chmod +x "${SCRIPT_DIR}/${script}"
        echo "✓"
    else
        rm -f "$TMP_DL"
        echo "✗ FAILED"
        DOWNLOAD_FAILED=1
    fi
done

echo ""

if [ $DOWNLOAD_FAILED -eq 1 ]; then
    echo "ERROR: Some scripts failed to download!"
    echo "Make sure script server is running: http://192.168.1.195/ubuntu/"
    echo ""
    echo "On DEV machine run: cd www && ./run_www.sh"
    exit 1
fi

echo "All scripts downloaded to: $SCRIPT_DIR"
echo ""
ls -la "$SCRIPT_DIR"/*.sh
echo ""

# Confirm before starting
read -p "Continue with setup? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Starting setup..."

# ---------------------------------------------------------------------------
# Step runner and failure gate. Added Aug 21, 2026.
#
# There is deliberately NO `set -e` here. Aborting on the first non-zero exit
# would skip the summary at the bottom, which is the most useful output the script
# produces. Instead every step's exit code is RECORDED and the run ends non-zero
# if anything failed.
#
# But "record and carry on" is wrong for one step. Passwordless sudo is a genuine
# PREREQUISITE, not a feature: every step after it runs under sudo, and
# setup_desktop.sh calls it dozens of times. Continuing without it produces a
# cascade of failures whose real cause has scrolled off the screen long before you
# read the summary. That one is a HARD GATE; the rest are recorded.
# ---------------------------------------------------------------------------
FAILED_STEPS=""

run_step() {
    local script="$1"; shift
    local rc=0
    echo ""
    echo "━━━ Running $script ━━━"
    sudo bash "${SCRIPT_DIR}/${script}" "$@" || rc=$?
    if [ "$rc" -ne 0 ]; then
        echo ""
        echo "!!! $script FAILED (exit $rc). Recorded; see the summary at the end."
        FAILED_STEPS="$FAILED_STEPS $script"
    fi
    return "$rc"
}

# ============================================
# PHASE 0: Identity
#
# First, before anything else, and that ordering is deliberate. The rename fixes
# the 127.0.1.1 line in /etc/hosts, and until it does, every sudo call in every
# later phase prints `sudo: unable to resolve host <old>` and can stall on a DNS
# timeout. Renaming last would mean doing the whole build through that noise.
# ============================================
if [ -n "$NEW_HOSTNAME" ]; then
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║  PHASE 0: Hostname                     ║"
    echo "╚════════════════════════════════════════╝"
    run_step setup_hostname.sh "$NEW_HOSTNAME"
fi

# ============================================
# PHASE 1: Base System (run as sudo)
# ============================================
echo ""
echo "╔════════════════════════════════════════╗"
echo "║  PHASE 1: Base System Setup            ║"
echo "╚════════════════════════════════════════╝"

run_step setup_ssh.sh

if ! run_step setup_sudo.sh; then
    echo ""
    echo "=========================================="
    echo "STOPPING: passwordless sudo is not working."
    echo "=========================================="
    echo ""
    echo "Every remaining step runs under sudo, so continuing would produce a wall"
    echo "of failures that all trace back to this one. Read setup_sudo.sh's error"
    echo "above, fix it, then re-run this script — it is idempotent."
    exit 1
fi

run_step setup_cockpit.sh

# ============================================
# PHASE 2: Development Tools (run as sudo)
# ============================================
echo ""
echo "╔════════════════════════════════════════╗"
echo "║  PHASE 2: Development Tools            ║"
echo "╚════════════════════════════════════════╝"

run_step setup_docker.sh

# ============================================
# PHASE 3: Storage (run as sudo)
# ============================================
echo ""
echo "╔════════════════════════════════════════╗"
echo "║  PHASE 3: Storage Configuration        ║"
echo "╚════════════════════════════════════════╝"

echo ""
if [ "$SKIP_NAS" -eq 1 ]; then
    echo "━━━ SKIPPING setup_smb_mount.sh (--no-nas: prod-local host) ━━━"
else
    run_step setup_smb_mount.sh
fi

# ============================================
# PHASE 4: Desktop (run as user)
# ============================================
echo ""
echo "╔════════════════════════════════════════╗"
echo "║  PHASE 4: Desktop Configuration        ║"
echo "╚════════════════════════════════════════╝"

# ---------------------------------------------------------------------------
# Desktop vs server. Fixed Aug 21, 2026, and this was NOT a cosmetic bug.
#
# The gate here used to be `gnome-shell || gsettings`. `gsettings` ships in
# libglib2.0-bin, which plenty of headless hosts pull in as a dependency of
# something else -- so the test passed on machines with no desktop at all, and
# setup_desktop.sh went on to install GOOGLE CHROME AND CURSOR ON SERVERS.
#
# Measured on vm-jenkins-1 (.185), a headless host, Aug 21 2026:
#     gnome-shell   ABSENT        <- correctly headless
#     gsettings     /usr/bin/gsettings   <- and this alone opened the gate
#     cursor           1012.4 MB
#     google-chrome     430.8 MB
#     wasted           1443.2 MB
#
# What hid it for so long: the SUMMARY block at the bottom of this script tests
# `gnome-shell` ALONE. So a server installed 1.4 GB of desktop applications and
# then printed no line about the desktop step whatsoever. Two tests for the same
# question, disagreeing, and the quieter one was the one reporting to the human.
# ⭐ When two conditions are meant to describe the same thing, they have to BE
# the same expression -- not two expressions that happen to agree today.
#
# gnome-shell is now the sole desktop indicator, and a headless host runs the
# script in --server mode rather than being skipped entirely: the CLI tools,
# timezone, DNS and shell aliases are all wanted on a server. Only the desktop
# applications and the GNOME settings are dropped.
# ---------------------------------------------------------------------------
if [ "$SERVER_MODE" -eq 1 ]; then
    DESKTOP_MODE="server (--server)"
elif command -v gnome-shell >/dev/null 2>&1; then
    DESKTOP_MODE="desktop"
else
    DESKTOP_MODE="server (auto: no gnome-shell)"
fi

echo "Mode: $DESKTOP_MODE"
if [ "$DESKTOP_MODE" = "desktop" ]; then
    DESKTOP_ARGS=""
    echo "Full desktop configuration, including Chrome and Cursor."
else
    DESKTOP_ARGS="--server"
    echo "Skipping Chrome (~431 MB), Cursor (~1012 MB) and all GNOME settings."
    echo "Still doing: timezone, DNS, CLI tools, shell aliases."
fi

echo ""
echo "━━━ Running setup_desktop.sh $DESKTOP_ARGS (as $ORIGINAL_USER, not root) ━━━"
DESKTOP_RC=0
if [ "$EUID" -eq 0 ]; then
    sudo -u "$ORIGINAL_USER" bash "${SCRIPT_DIR}/setup_desktop.sh" $DESKTOP_ARGS || DESKTOP_RC=$?
else
    bash "${SCRIPT_DIR}/setup_desktop.sh" $DESKTOP_ARGS || DESKTOP_RC=$?
fi
if [ "$DESKTOP_RC" -ne 0 ]; then
    echo ""
    echo "!!! setup_desktop.sh exited $DESKTOP_RC. See its output above."
    FAILED_STEPS="$FAILED_STEPS setup_desktop.sh"
fi

# ============================================
# SUMMARY - every line below is a MEASUREMENT
#
# This block used to print hardcoded checkmarks for SSH, sudo, Docker, Git and the
# desktop: it claimed success for five things it never checked, and would have
# reported a clean build on a host where four of them had failed. Cockpit and the
# NAS mount were the only two that were actually tested. Rewritten Aug 21, 2026 to
# measure everything, matching the Fedora orchestrator.
# ============================================
echo ""
echo "=========================================="
echo "     HOST SETUP COMPLETE"
echo "=========================================="
echo ""
echo "Verified state of this host:"

systemctl is-active --quiet ssh \
    && echo "  ok   SSH server running" \
    || echo "  FAIL SSH server not running"

sudo -n true 2>/dev/null \
    && echo "  ok   Passwordless sudo" \
    || echo "  FAIL Passwordless sudo not working"

if systemctl is-enabled --quiet cockpit.socket 2>/dev/null; then
    echo "  ok   Cockpit at https://$(hostname -I | awk '{print $1}'):9090"
else
    echo "  FAIL Cockpit not enabled - re-run setup_cockpit.sh and read its error"
fi

if command -v git >/dev/null 2>&1; then
    echo "  ok   Git $(git --version | awk '{print $3}')"
else
    echo "  FAIL Git not installed"
fi

# The storage driver is checked, not just the daemon. A Docker that runs but uses
# the containerd image store pushes broken manifests to the GitLab registry, and
# it fails intermittently enough to look like a registry problem instead.
if command -v docker >/dev/null 2>&1 && systemctl is-active --quiet docker; then
    DRV=$(sudo docker info 2>/dev/null | awk -F': ' '/Storage Driver/ {print $2}' | tr -d ' ')
    if [ "$DRV" = "overlay2" ]; then
        echo "  ok   Docker running, storage driver overlay2"
    else
        echo "  WARN Docker running but storage driver is '$DRV', expected overlay2"
        echo "       Pushes to the GitLab registry may fail intermittently."
    fi
else
    echo "  FAIL Docker not running"
fi

if [ "$SKIP_NAS" -eq 1 ]; then
    echo "  --   NAS mount skipped (prod-local host)"
elif mountpoint -q /mnt/DevShare 2>/dev/null; then
    echo "  ok   NAS mounted at ~/DevShare"
else
    echo "  FAIL NAS mount not active - see setup_smb_mount.sh output above"
fi

# Reports against the SAME variable the run was gated on. Testing `gnome-shell`
# again here is what let a server install Chrome and Cursor with no summary line
# to show for it.
if [ "${DESKTOP_RC:-0}" -eq 0 ]; then
    if [ "$DESKTOP_MODE" = "desktop" ]; then
        echo "  ok   Desktop configured (Chrome, Cursor, dock)"
    else
        echo "  ok   Server mode: CLI tools + aliases, no desktop apps"
    fi
else
    echo "  FAIL setup_desktop.sh reported errors ($DESKTOP_MODE) - see its output"
fi

# State it plainly rather than leaving it to be inferred from an absence. A
# headless host that has these is carrying ~1.4 GB it will never use.
if [ "$DESKTOP_MODE" != "desktop" ]; then
    STRAY=""
    command -v google-chrome >/dev/null 2>&1 && STRAY="$STRAY google-chrome"
    command -v cursor        >/dev/null 2>&1 && STRAY="$STRAY cursor"
    if [ -n "$STRAY" ]; then
        echo "  WARN desktop apps present on a headless host:$STRAY"
        echo "       Not installed by this run. Left in place because removing"
        echo "       packages is not this script's job, but they are ~1.4 GB."
        echo "       To reclaim: sudo apt-get purge -y google-chrome-stable cursor"
    fi
fi

echo ""
echo "Hostname: $(hostnamectl --static 2>/dev/null || hostname)"
echo "Scripts saved in: $SCRIPT_DIR"

if [ -n "$FAILED_STEPS" ]; then
    echo ""
    echo "=========================================="
    echo "SCRIPTS THAT FAILED:$FAILED_STEPS"
    echo "=========================================="
    echo "Re-run the individual script and read its error. All of them are"
    echo "idempotent, so re-running the whole build is also safe."
    echo ""
    exit 1
fi

echo ""
echo "IMPORTANT:"
echo "  • Cockpit logs in with your SYSTEM PASSWORD, not an SSH key (self-signed cert)"
echo "  • Log out and back in for docker group to take effect"
echo "  • Run 'source ~/.bashrc' for aliases (godev, update)"
echo "  • Run 'newgrp docker' to use docker without logout"
echo ""
echo "=========================================="
