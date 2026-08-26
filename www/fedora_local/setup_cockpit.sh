#!/bin/bash
#
# setup_cockpit.sh - Cockpit web admin UI at https://<host>:9090 (Fedora)
#
# Usage: sudo ./setup_cockpit.sh
#
# ============================================================================
# READ THIS BEFORE EDITING -- the Ubuntu trap does NOT apply here, and knowing
# WHY is the point.
#
# On Ubuntu (www/ubuntu/setup_cockpit.sh) the rule is "never `apt install
# cockpit`", because the metapackage Recommends cockpit-networkmanager, which
# drags in NetworkManager itself onto boxes running netplan + systemd-networkd.
# Letting NM take over the interfaces of a machine you only reach over SSH is
# how you lose the machine.
#
# On Fedora Workstation, NetworkManager IS ALREADY THE NETWORK STACK (measured
# on .196, Aug 21 2026: NetworkManager active, connection "Wired connection 1"
# on ens160). So cockpit-networkmanager manages what is already in charge and
# is genuinely useful -- exactly the case where the Ubuntu script also enables
# it.
#
# The GUARD IS KEPT, RE-AIMED. Its value was never "NetworkManager is bad". It
# was: refuse to proceed if installing an admin UI would change the machine's
# foundations. On Fedora that means refusing on any REMOVAL, and on any change
# to the kernel or the network stack. A comment saying "check the transaction"
# gets ignored a year from now; a script that exits 1 does not.
# ============================================================================
#
# Measured starting state on a stock Fedora 44 Workstation install:
#   - cockpit-ws AND cockpit-bridge are ALREADY INSTALLED (Fedora ships them)
#   - the `cockpit` metapackage is NOT installed
#   - cockpit.socket exists but is DISABLED
#   - firewalld ships a `cockpit` service definition
# So on Fedora this script is mostly "enable and open", not "install".
#

set -e

echo "=========================================="
echo "Cockpit Web Admin Setup (Fedora)"
echo "=========================================="

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root (sudo ./setup_cockpit.sh)"
    exit 1
fi

# ---------------------------------------------------------------------------
# Build the package list to match this host
# ---------------------------------------------------------------------------
# cockpit-files is the Cockpit file manager. Added Aug 21, 2026 at Andrew's request.
# On Fedora it is a clean single-package add (43-1.fc44, no dependencies) because the
# distro ships a current Cockpit. On Ubuntu it is NOT that simple -- see the note in
# www/ubuntu/setup_cockpit.sh.
PKGS="cockpit-ws cockpit-bridge cockpit-system cockpit-storaged cockpit-packagekit cockpit-files"

echo ""
echo "[1/6] Detecting the active network stack..."
if systemctl is-active --quiet NetworkManager; then
    echo "    NetworkManager is ACTIVE -- adding cockpit-networkmanager"
    echo "    (correct on Fedora: the module manages what is already in charge)"
    PKGS="$PKGS cockpit-networkmanager"
else
    echo "    NetworkManager is NOT active -- omitting cockpit-networkmanager"
fi

echo ""
echo "    Package list: $PKGS"

# ---------------------------------------------------------------------------
# SIMULATE FIRST. Abort on anything that touches the foundations.
# ---------------------------------------------------------------------------
echo ""
echo "[2/6] Simulating the transaction before touching anything..."
SIM=$(dnf install --assumeno $PKGS 2>&1 || true)

# Abort on any section that takes something away. Installing an admin UI must
# never remove, replace or downgrade a package.
if printf '%s\n' "$SIM" | grep -qE '^(Removing|Replacing|Downgrading):'; then
    echo ""
    echo "ABORTING: this transaction would REMOVE, REPLACE or DOWNGRADE packages."
    echo "$SIM"
    exit 1
fi

# Check the FOUNDATIONS by exact package NAME, parsed out of the transaction
# table. dnf5 prints table rows indented by one space:
#     cockpit-packagekit noarch 0:366-1.fc44 updates 957.9 KiB
#
# ------------------------------------------------------------------------
# Do NOT go back to grepping the raw text for a substring. The first version
# of this guard used `grep -qiE 'NetworkManager-[0-9]'` and ABORTED A CLEAN
# INSTALL, because case-insensitively `cockpit-networkmanager-360` contains
# `networkmanager-3`. The guard fired on the exact package Fedora WANTS us to
# add. On Fedora the desired package's name contains the forbidden package's
# name, so any substring test is wrong by construction.
# ------------------------------------------------------------------------
TXN_PKGS=$(printf '%s\n' "$SIM" | awk '/^ [^ ]/ && NF>=4 {print $1}')

for pkg in $TXN_PKGS; do
    case "$pkg" in
        NetworkManager|kernel|kernel-core|kernel-modules|kernel-modules-core|dracut|systemd)
            echo ""
            echo "ABORTING: transaction would change a foundation package: $pkg"
            echo "$SIM"
            exit 1
            ;;
    esac
done

if [ -n "$TXN_PKGS" ]; then
    echo "    Simulation clean. Would install:" $TXN_PKGS
else
    echo "    Simulation clean: nothing to do, everything already present"
fi

# ---------------------------------------------------------------------------
echo ""
echo "[3/6] Installing packages..."
dnf install -y $PKGS

echo ""
echo "[4/6] Enabling cockpit.socket..."
systemctl enable --now cockpit.socket

echo ""
echo "[5/6] Opening the firewall..."
if systemctl is-active --quiet firewalld; then
    ZONE=$(firewall-cmd --get-default-zone)
    if firewall-cmd --zone="$ZONE" --query-service=cockpit &>/dev/null; then
        echo "    cockpit already permitted in zone '$ZONE'"
    else
        firewall-cmd --zone="$ZONE" --add-service=cockpit --permanent
        firewall-cmd --reload
        echo "    Added cockpit to zone '$ZONE' and reloaded"
    fi
else
    echo "    firewalld not active, nothing to open"
fi

# ---------------------------------------------------------------------------
# VERIFY. Socket-activated means cockpit-ws only spawns on connect, so check the
# LISTENER, not the service.
# ---------------------------------------------------------------------------
echo ""
echo "[6/6] Verifying something is listening on 9090..."
if ss -ltn | grep -q ':9090'; then
    echo "    Confirmed: port 9090 is open"
else
    echo "ERROR: cockpit.socket is enabled but nothing is listening on 9090"
    systemctl status cockpit.socket --no-pager | head -20
    exit 1
fi

# ---------------------------------------------------------------------------
# Cockpit authenticates through PAM, so a key-only account cannot log in even
# though SSH works fine. Warn loudly rather than let it be discovered at the
# login screen.
# ---------------------------------------------------------------------------
LOGIN_USER=${SUDO_USER:-agamache}
echo ""
if passwd -S "$LOGIN_USER" 2>/dev/null | awk '{print $2}' | grep -qx 'P'; then
    echo "    $LOGIN_USER has a usable password -- Cockpit login will work"
else
    echo "    WARNING: $LOGIN_USER has NO usable password."
    echo "             Cockpit authenticates via PAM, so this account CANNOT log in"
    echo "             even though SSH may work. Fix with: passwd $LOGIN_USER"
fi

if id -nG "$LOGIN_USER" | tr ' ' '\n' | grep -qx wheel; then
    echo "    $LOGIN_USER is in 'wheel' -- Administrative access available in the UI"
else
    echo "    NOTE: $LOGIN_USER is not in 'wheel'; the UI will be read-mostly"
fi

IP_ADDR=$(hostname -I | awk '{print $1}')
echo ""
echo "=========================================="
echo "SUCCESS! Cockpit is up"
echo "=========================================="
echo ""
echo "  https://${IP_ADDR}:9090"
echo ""
echo "  Log in with your SYSTEM password (PAM), not an SSH key."
echo "  The cert is self-signed, so the browser will warn."
echo "  NOTE: the Cursor built-in browser CANNOT open it -- it fails"
echo "        ERR_CERT_AUTHORITY_INVALID with no bypass. Use Chrome or Firefox."
echo ""
echo "  Verify auth without a browser (returns a csrf-token on success):"
echo "    curl -sk -u ${LOGIN_USER}:PASSWORD https://${IP_ADDR}:9090/cockpit/login"
echo "  Do NOT test /login -- it returns 200 for good AND bad passwords."
echo ""
echo "Done!"
