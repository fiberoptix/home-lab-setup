#!/bin/bash
#
# host_setup.sh - Master setup script for new FEDORA hosts
#
# Usage:
#   1. curl -fsSLO http://192.168.1.195/fedora/host_setup.sh
#   2. bash host_setup.sh    (NOT sudo - the script handles sudo internally)
#
#   Options:
#     --no-nas              prod-local/DMZ host: skip the NAS mount entirely
#     --hostname <name>     set the static hostname (Fedora ISO installs inherit
#                           'localhost-live' from the live environment)
#
# ============================================================================
# WHY THE BOOTSTRAP LINE USES curl AND NOT wget
#
# The Ubuntu instruction is `wget http://192.168.1.195/ubuntu/host_setup.sh`.
# That exact command FAILS on a stock Fedora Workstation, because wget is not
# installed (measured on a fresh Fedora 44 install, Aug 21 2026: curl yes, wget
# no). The very first step of the build would fail before anything ran.
#
# So this script is fetched with curl, and it uses curl internally too. wget is
# installed later by setup_desktop.sh, which is the right order: the bootstrap
# may only depend on what a stock install already has.
# ============================================================================
#

ORIGINAL_USER="${SUDO_USER:-$USER}"

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

# Refuse to run on the wrong distro. These scripts call dnf, firewall-cmd and
# rpm; on a Debian host they would fail late and messily, halfway through.
if [ ! -f /etc/fedora-release ]; then
    echo "ERROR: this is the FEDORA build. /etc/fedora-release not found."
    echo "       For Ubuntu/Debian hosts use http://192.168.1.195/ubuntu/host_setup.sh"
    exit 1
fi

# Overridable so the orchestrator can be tested end-to-end against a throwaway
# server without editing the file. The Ubuntu version hardcodes this, which is
# why it has never been proven end-to-end anywhere except a real build.
#   SCRIPT_SERVER=http://localhost:8099 bash host_setup.sh --no-nas
SCRIPT_SERVER="${SCRIPT_SERVER:-http://192.168.1.195/fedora}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# No anysphere.gpg here: the Ubuntu build mirrors Cursor's apt key locally because
# the official URL 403s. The Fedora RPM repo and its key are both publicly
# fetchable (verified HTTP 200), so setup_desktop.sh points straight at them.
SCRIPTS="setup_ssh.sh setup_sudo.sh setup_cockpit.sh setup_docker.sh setup_smb_mount.sh setup_desktop.sh setup_hostname.sh"

echo "=========================================="
echo "     Fedora Host Setup - Master Script"
echo "=========================================="
echo ""
echo "Host:          $(. /etc/os-release && echo "$PRETTY_NAME")"
echo "Script Server: $SCRIPT_SERVER"
echo "Scripts Dir:   $SCRIPT_DIR"
echo ""
echo "This will configure a new Fedora host with:"
echo "  - SSH server (NOT enabled by default on Fedora Workstation)"
echo "  - Passwordless sudo (wheel group)"
echo "  - Cockpit web admin (https://<host>:9090)"
echo "  - Docker CE + Git (Podman is left installed and untouched)"
if [ "$SKIP_NAS" -eq 1 ]; then
echo "  - NAS mount: SKIPPED (--no-nas)"
else
echo "  - NAS mount (~/DevShare)"
fi
if [ -n "$NEW_HOSTNAME" ]; then
echo "  - Hostname: $NEW_HOSTNAME"
fi
if [ "$SERVER_MODE" -eq 1 ]; then
echo "  - SERVER mode (--server): CLI tools + shell aliases + sleep masking"
echo "    NO Chrome, NO Cursor, no GNOME settings, no autologin"
elif command -v gnome-shell >/dev/null 2>&1; then
echo "  - Desktop config: Chrome, Cursor, dock, GNOME settings, autologin"
else
echo "  - Server mode (auto: no gnome-shell): CLI tools + shell aliases"
fi
echo ""
echo "=========================================="
echo ""

# ============================================
# DOWNLOAD ALL SCRIPTS FIRST
# ============================================
echo "-- Downloading all scripts to $SCRIPT_DIR"
echo ""

cd "$SCRIPT_DIR" || exit 1

# ---------------------------------------------------------------------------
# REFUSE TO RUN INSIDE THE SCRIPT LIBRARY ITSELF. Added Aug 21, 2026 after the
# Ubuntu orchestrator did exactly this and zeroed all eight of its own files.
#
# `curl -o <file>` truncates the destination as it opens it, and nginx serves
# www/fedora/ straight off disk, so running here would empty each file and then
# read back the zero bytes just written. This tree escaped the actual incident
# only by luck -- the distro guard above happens to exit first on a Debian host,
# which is where the testing was being done. Luck is not a control.
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
    echo "         cd \"\$(mktemp -d)\" && curl -fsSLO ${SCRIPT_SERVER}/host_setup.sh && bash host_setup.sh"
    exit 1
fi

DOWNLOAD_FAILED=0
for script in $SCRIPTS; do
    printf '  Downloading %-22s ' "$script..."
    # Temp file, then move on success. `curl -o dest` truncates dest up front, so
    # a failed download REPLACES A WORKING SCRIPT WITH AN EMPTY FILE -- worst in
    # the re-run-to-repair case this script exists for.
    TMP_DL="${SCRIPT_DIR}/.${script}.part"
    if curl -fsSL -o "$TMP_DL" "${SCRIPT_SERVER}/${script}" && [ -s "$TMP_DL" ]; then
        mv -f "$TMP_DL" "${SCRIPT_DIR}/${script}"
        chmod +x "${SCRIPT_DIR}/${script}"
        echo "ok"
    else
        rm -f "$TMP_DL"
        echo "FAILED"
        DOWNLOAD_FAILED=1
    fi
done

echo ""
if [ $DOWNLOAD_FAILED -eq 1 ]; then
    echo "ERROR: some scripts failed to download."
    echo "Check the script server is up: $SCRIPT_SERVER/"
    echo "On the DEV machine run: cd www && ./run_www.sh"
    exit 1
fi

echo "All scripts downloaded."
echo ""

read -p "Continue with setup? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# ---------------------------------------------------------------------------
# Step runner and failure gate.
#
# There is deliberately NO `set -e` in this file. Aborting on the first non-zero
# exit would skip the measured summary at the bottom, which is the most useful
# output the script produces. Instead every step's exit code is RECORDED, and the
# run ends non-zero if anything failed.
#
# But "record and carry on" is wrong for one step. Passwordless sudo is a genuine
# PREREQUISITE, not a feature: every step after it runs under sudo, and
# setup_desktop.sh calls it dozens of times. Continuing without it produces a
# cascade of failures whose real cause has scrolled off the screen long before you
# read the summary. So that one is a HARD GATE and the rest are recorded.
# ---------------------------------------------------------------------------
FAILED_STEPS=""

run_step() {
    local script="$1"; shift
    local rc=0
    echo ""
    echo "--- $script ---"
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
# ============================================
if [ -n "$NEW_HOSTNAME" ]; then
    echo ""
    echo "===== PHASE 0: Hostname ====="
    run_step setup_hostname.sh "$NEW_HOSTNAME"
fi

# ============================================
# PHASE 1: Base System
# ============================================
echo ""
echo "===== PHASE 1: Base System Setup ====="

run_step setup_ssh.sh

if ! run_step setup_sudo.sh; then
    echo ""
    echo "=========================================="
    echo "STOPPING: passwordless sudo is not working."
    echo "=========================================="
    echo ""
    echo "Every remaining step runs under sudo, so continuing would produce a wall"
    echo "of failures that all trace back to this one. Read setup_sudo.sh's error"
    echo "above, fix it, then re-run this script -- it is idempotent."
    exit 1
fi

run_step setup_cockpit.sh

# ============================================
# PHASE 2: Development Tools
# ============================================
echo ""
echo "===== PHASE 2: Development Tools ====="

run_step setup_docker.sh

# ============================================
# PHASE 3: Storage
# ============================================
echo ""
echo "===== PHASE 3: Storage Configuration ====="
echo ""
if [ "$SKIP_NAS" -eq 1 ]; then
    echo "--- SKIPPING setup_smb_mount.sh (--no-nas: prod-local host) ---"
else
    run_step setup_smb_mount.sh
fi

# ============================================
# PHASE 4: Desktop
# ============================================
echo ""
echo "===== PHASE 4: Desktop Configuration ====="

# ---------------------------------------------------------------------------
# Desktop vs server. Note the gate here has ALWAYS tested gnome-shell alone, so
# unlike the Ubuntu orchestrator this tree never had the "gsettings implies a
# desktop" bug that put Chrome and Cursor on servers. --server was added Aug 21,
# 2026 for explicit control and parity with Ubuntu, not as a repair.
#
# A headless host now runs the script in server mode rather than being skipped
# outright: the CLI tools, aliases and the systemd sleep masking are all wanted
# on a server, and skipping the whole script meant none of them happened.
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
else
    DESKTOP_ARGS="--server"
    echo "Skipping Chrome, Cursor, GNOME settings, keyring and autologin."
    echo "Still doing: timezone, DNS, CLI tools, aliases, sleep masking."
fi

echo ""
echo "--- setup_desktop.sh $DESKTOP_ARGS (as $ORIGINAL_USER, not root) ---"
# setup_desktop.sh REFUSES to run as root, and in DESKTOP mode also refuses to
# run without a D-Bus session bus, because gsettings would otherwise write to a
# memory backend and report success having changed nothing. Server mode is exempt
# from the bus requirement -- a headless host has none, and server mode never
# touches gsettings.
DESKTOP_RC=0
if [ "$EUID" -eq 0 ]; then
    sudo -u "$ORIGINAL_USER" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$ORIGINAL_USER")/bus" \
        bash "${SCRIPT_DIR}/setup_desktop.sh" $DESKTOP_ARGS || DESKTOP_RC=$?
else
    bash "${SCRIPT_DIR}/setup_desktop.sh" $DESKTOP_ARGS || DESKTOP_RC=$?
fi
# setup_desktop.sh exits non-zero when any of its own checks reported FAIL, so
# this propagates its measured verdict rather than re-testing it here.
if [ "$DESKTOP_RC" -ne 0 ]; then
    echo ""
    echo "!!! setup_desktop.sh reported failures (exit $DESKTOP_RC). See its"
    echo "    RESULTS block above for the specific [FAIL] lines."
    FAILED_STEPS="$FAILED_STEPS setup_desktop.sh"
fi

# ============================================
# SUMMARY - every line below is a MEASUREMENT
# ============================================
echo ""
echo "=========================================="
echo "     HOST SETUP COMPLETE"
echo "=========================================="
echo ""
echo "Verified state of this host:"

systemctl is-active --quiet sshd \
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

echo ""
echo "Hostname: $(hostnamectl --static)"

# The exit code has to agree with the summary above. A build that printed FAIL
# lines and then exited 0 is the false green this whole build standard is written
# against -- and it is the difference between a human noticing and a wrapper script
# noticing.
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
echo "  - Cockpit logs in with your SYSTEM PASSWORD, not an SSH key (self-signed cert)."
echo "    The Cursor built-in browser cannot open it; use Chrome or Firefox."
echo "  - Log out and back in for the docker group, the dock and the keyring."
echo "    On Wayland the GNOME Shell cannot be restarted in place."
echo "  - Run 'source ~/.bashrc' for the aliases (godev, update, sysbench)."
echo ""
echo "=========================================="
