#!/bin/bash
#
# setup_cockpit.sh - Install the Cockpit web admin UI (https://<host>:9090)
#
# Usage: sudo ./setup_cockpit.sh
#
# This script will:
# 1. Detect which stack manages networking on this host
# 2. Build a package list that is SAFE for that stack
# 3. Refuse to proceed if the install would pull in NetworkManager unexpectedly
# 4. Install Cockpit and confirm the socket is listening on 9090
#
# WHY THIS SCRIPT EXISTS INSTEAD OF `apt install cockpit`:
#   The `cockpit` metapackage Recommends `cockpit-networkmanager`, which drags in
#   `network-manager` plus dnsmasq-base, ppp and wpasupplicant. Our server VMs run
#   netplan + systemd-networkd. Putting NetworkManager on a box whose interfaces are
#   already managed elsewhere risks losing the network on a machine we administer
#   over SSH. So we install the components explicitly and verify before committing.
#   First hit on vm-k8-redpanda-1 (.186), Aug 20 2026.
#

set -e

echo "=========================================="
echo "Cockpit Web Admin Setup"
echo "=========================================="

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root (sudo ./setup_cockpit.sh)"
    exit 1
fi

ACTUAL_USER=${SUDO_USER:-$USER}
if [ "$ACTUAL_USER" = "root" ]; then
    echo "WARNING: Could not determine non-root user"
    ACTUAL_USER="agamache"
fi
echo "Login user will be: $ACTUAL_USER"

# ---------------------------------------------------------------------------
# Step 1 - which stack owns the network?
# ---------------------------------------------------------------------------
echo ""
echo "[1/6] Detecting the network stack..."

NM_ACTIVE=0
if systemctl is-active --quiet NetworkManager 2>/dev/null; then
    NM_ACTIVE=1
fi

# Base set: everything except the network module.
PKGS="cockpit-ws cockpit-bridge cockpit-system cockpit-storaged cockpit-packagekit"

if [ "$NM_ACTIVE" -eq 1 ]; then
    # Desktop builds genuinely use NetworkManager, so the module is useful and safe.
    PKGS="$PKGS cockpit-networkmanager"
    echo "    NetworkManager is ACTIVE (desktop-style host)"
    echo "    -> including cockpit-networkmanager, it manages what is already in charge"
else
    echo "    NetworkManager is NOT active; networking is systemd-networkd/netplan"
    echo "    -> EXCLUDING cockpit-networkmanager and the 'cockpit' metapackage"
fi

# ---------------------------------------------------------------------------
# Step 2 - simulate, and refuse to proceed on a surprise
# ---------------------------------------------------------------------------
echo ""
echo "[2/6] Simulating the install before committing to it..."
apt-get update -qq

SIM="$(apt-get install -s $PKGS 2>&1 | grep '^Inst' | awk '{print $2}')"

if [ "$NM_ACTIVE" -eq 0 ] && echo "$SIM" | grep -qx "network-manager"; then
    echo ""
    echo "ERROR: refusing to continue."
    echo "  This install would pull in 'network-manager' on a host that does NOT use it."
    echo "  That can take over interfaces managed by systemd-networkd and drop the network"
    echo "  on a machine you are administering over SSH."
    echo ""
    echo "  Packages apt wanted to add:"
    echo "$SIM" | sed 's/^/    /'
    echo ""
    echo "  Fix the package list in this script rather than forcing it through."
    exit 1
fi

if [ -z "$SIM" ]; then
    echo "    OK - already installed, nothing to add (re-run is safe)"
else
    echo "    OK - $(echo "$SIM" | wc -l) package(s) to add, no unexpected network stack"
fi

# ---------------------------------------------------------------------------
# Step 3 - install
# ---------------------------------------------------------------------------
echo ""
echo "[3/6] Installing Cockpit..."
DEBIAN_FRONTEND=noninteractive apt-get install -y $PKGS

# Socket activation: cockpit-ws only starts when someone connects, so idle cost
# is negligible. Enable explicitly rather than assuming the package did it.
systemctl enable --now cockpit.socket >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# Step 4 - cockpit-files, as a SEPARATE and OPTIONAL transaction
#
# WHY IT IS NOT IN $PKGS ABOVE. Measured on Ubuntu 24.04, Aug 21 2026:
# cockpit-files exists ONLY in noble-backports (v39) and Depends: cockpit-bridge
# (>= 318), while noble/main ships 314. apt cannot satisfy that, because backports
# are pinned low and it will not silently upgrade the bridge.
#
#   cockpit-files : Depends: cockpit-bridge (>= 318) but 314-1 is to be installed
#
# `apt-get install` is ALL-OR-NOTHING. Adding the name to the main list would make
# the whole install fail, and with `set -e` that aborts the script -- leaving the
# host with NO Cockpit at all rather than Cockpit minus one plugin. That is a
# terrible trade for an optional file manager.
#
# The alternative, `-t noble-backports`, DOES resolve cleanly and (verified) does
# NOT pull network-manager -- but it moves the ENTIRE Cockpit stack from 314 to
# 362 out of a lower-tier repo, on servers. Too much surface for a file manager.
#
# So: try it, guard it, and skip LOUDLY if it is not cleanly installable. Nothing
# here needs editing when the distro catches up -- the moment Ubuntu ships
# cockpit-bridge >= 318, this simply starts succeeding.
# ---------------------------------------------------------------------------
echo ""
echo "[4/6] Adding cockpit-files (optional Cockpit file manager)..."

# `|| true` is REQUIRED: set -e is active, and this simulate is EXPECTED to fail
# on current Ubuntu. Without it the script would abort on the very condition it
# is designed to detect and tolerate.
CF_SIM="$(apt-get install -s cockpit-files 2>&1 || true)"

if ! echo "$CF_SIM" | grep -q '^Inst'; then
    echo "    SKIPPED - not cleanly installable on this release. apt says:"
    echo "$CF_SIM" | grep -E 'Depends:|^E:' | sed 's/^/      /' | head -4
    echo "    Cockpit itself is unaffected. This will begin working automatically"
    echo "    once the distro ships cockpit-bridge >= 318."
else
    CF_INST="$(echo "$CF_SIM" | grep '^Inst' | awk '{print $2}')"

    if [ "$NM_ACTIVE" -eq 0 ] && echo "$CF_INST" | grep -qx "network-manager"; then
        echo "    REFUSED - this would pull in network-manager on a host that does"
        echo "    not use it. Skipping the plugin; Cockpit itself is unaffected."
    elif echo "$CF_SIM" | grep -q '^Remv'; then
        echo "    REFUSED - this would REMOVE packages:"
        echo "$CF_SIM" | grep '^Remv' | sed 's/^/      /'
    # Cockpit's own packages are installed by Step 3, immediately above. If any of
    # them appear HERE, the plugin is dragging the stack to a different version --
    # e.g. cockpit-bridge 362 from backports next to cockpit-ws 314 from main, which
    # is a mismatched and unsupported combination. Only reachable if someone has
    # raised the backports pin, but that is exactly when you want to be told.
    elif echo "$CF_INST" | grep -q '^cockpit-' && \
         [ -n "$(echo "$CF_INST" | grep '^cockpit-' | grep -v '^cockpit-files$')" ]; then
        echo "    REFUSED - this would change the Cockpit stack itself, not just add"
        echo "    a plugin. Packages it wanted to touch:"
        echo "$CF_INST" | grep '^cockpit-' | sed 's/^/      /'
        echo "    A split-version Cockpit (new bridge, old ws) is unsupported."
    elif ! DEBIAN_FRONTEND=noninteractive apt-get install -y cockpit-files; then
        echo "    WARNING: install failed. Cockpit itself is unaffected."
    elif dpkg -l cockpit-files 2>/dev/null | grep -q '^ii'; then
        echo "    Installed cockpit-files $(dpkg-query -W -f='${Version}' cockpit-files 2>/dev/null)"
    else
        echo "    WARNING: apt reported success but cockpit-files is not installed"
    fi
fi

# ---------------------------------------------------------------------------
# Step 5 - verify it is actually serving
# ---------------------------------------------------------------------------
echo ""
echo "[5/6] Verifying..."

if ! systemctl is-enabled --quiet cockpit.socket; then
    echo "ERROR: cockpit.socket is not enabled"
    exit 1
fi
echo "    cockpit.socket enabled"

if ! ss -ltn 2>/dev/null | grep -q ':9090'; then
    echo "ERROR: nothing is listening on 9090"
    exit 1
fi
echo "    listening on :9090"

if [ "$NM_ACTIVE" -eq 0 ] && dpkg -l 2>/dev/null | grep -q '^ii  network-manager '; then
    echo "ERROR: network-manager got installed anyway - investigate before rebooting"
    exit 1
fi
echo "    network stack unchanged"

# ---------------------------------------------------------------------------
# Step 6 - the login will not work without a password, so say so loudly
# ---------------------------------------------------------------------------
echo ""
echo "[6/6] Checking login prerequisites..."

# Cockpit authenticates through PAM. A key-only account CANNOT log in.
PW_STATUS="$(passwd -S "$ACTUAL_USER" 2>/dev/null | awk '{print $2}')"
if [ "$PW_STATUS" = "P" ]; then
    echo "    $ACTUAL_USER has a usable password - login will work"
else
    echo "    WARNING: $ACTUAL_USER password status is '$PW_STATUS' (need 'P')."
    echo "             Cockpit logs in via PAM, so a key-only account cannot sign in."
    echo "             Fix with: sudo passwd $ACTUAL_USER"
fi

if id -nG "$ACTUAL_USER" 2>/dev/null | grep -qw sudo; then
    echo "    $ACTUAL_USER is in sudo - 'Administrative access' will work in the UI"
else
    echo "    NOTE: $ACTUAL_USER is not in sudo; the UI will be read-mostly"
fi

IP_ADDR="$(ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -1)"

echo ""
echo "=========================================="
echo "SUCCESS! Cockpit installed"
echo "=========================================="
echo ""
echo "  URL:   https://${IP_ADDR:-<this-host>}:9090/"
echo "  Login: $ACTUAL_USER  (system password, not an SSH key)"
echo ""
echo "NOTES:"
echo "  • The TLS cert is self-signed - your browser will warn. Click through."
echo "  • The Cursor built-in browser CANNOT open it (ERR_CERT_AUTHORITY_INVALID,"
echo "    no bypass offered). Use Chrome or Firefox."
echo "  • Verify auth without a browser:"
echo "      curl -sk -u USER:PASS https://${IP_ADDR:-HOST}:9090/cockpit/login"
echo "    Success returns {\"csrf-token\":...}. Do NOT test /login - it returns the"
echo "    HTML page and 200 for good AND bad passwords, so it proves nothing."
echo ""
echo "Done!"
