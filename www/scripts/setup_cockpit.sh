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
echo "[1/5] Detecting the network stack..."

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
echo "[2/5] Simulating the install before committing to it..."
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
echo "[3/5] Installing Cockpit..."
DEBIAN_FRONTEND=noninteractive apt-get install -y $PKGS

# Socket activation: cockpit-ws only starts when someone connects, so idle cost
# is negligible. Enable explicitly rather than assuming the package did it.
systemctl enable --now cockpit.socket >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# Step 4 - verify it is actually serving
# ---------------------------------------------------------------------------
echo ""
echo "[4/5] Verifying..."

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
# Step 5 - the login will not work without a password, so say so loudly
# ---------------------------------------------------------------------------
echo ""
echo "[5/5] Checking login prerequisites..."

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
