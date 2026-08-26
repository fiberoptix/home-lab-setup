#!/bin/bash
#
# setup_ssh.sh - Enable SSH access on new Fedora hosts
#
# Usage: sudo ./setup_ssh.sh
#
# Fedora counterpart of www/ubuntu/setup_ssh.sh. Three real differences from Ubuntu,
# all measured on Fedora 44 Workstation (192.168.1.196, Aug 21 2026):
#   1. The unit is `sshd`, not `ssh`.
#   2. Fedora Workstation does NOT enable sshd by default, so a fresh install is
#      unreachable until this runs. Ubuntu Server does. This is the whole reason
#      the first Fedora build needs one command typed at the console.
#   3. The firewall is firewalld and it is ACTIVE by default (ufw is inactive on
#      every Ubuntu VM in this lab). The default FedoraWorkstation zone already
#      permits ssh, but we assert it rather than trust it.
#

set -e

echo "=========================================="
echo "SSH Server Setup (Fedora)"
echo "=========================================="

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root (sudo ./setup_ssh.sh)"
    exit 1
fi

# Step 1: Install OpenSSH Server
echo ""
echo "[1/5] Installing openssh-server..."
if rpm -q --quiet openssh-server; then
    echo "    Already installed: $(rpm -q openssh-server)"
else
    dnf install -y openssh-server
fi

# Step 2 + 3: Enable and start (one call; --now is enable+start)
echo ""
echo "[2/5] Enabling and starting sshd..."
systemctl enable --now sshd

# Step 4: firewalld
echo ""
echo "[3/5] Configuring firewalld..."
if systemctl is-active --quiet firewalld; then
    ZONE=$(firewall-cmd --get-default-zone)
    if firewall-cmd --zone="$ZONE" --query-service=ssh &>/dev/null; then
        echo "    ssh already permitted in zone '$ZONE'"
    else
        firewall-cmd --zone="$ZONE" --add-service=ssh --permanent
        firewall-cmd --reload
        echo "    Added ssh to zone '$ZONE' and reloaded"
    fi
else
    echo "    firewalld not active, skipping firewall config"
fi

# Step 5: VERIFY, do not assume. A unit that is 'enabled' is not a unit that is
# listening -- prove the socket is open before claiming success.
echo ""
echo "[4/5] Verifying sshd is actually listening..."
if ss -ltn | grep -qE '(:22|:ssh)\s'; then
    echo "    Confirmed: something is listening on port 22"
else
    echo "ERROR: sshd is enabled but NOTHING is listening on port 22"
    systemctl status sshd --no-pager | head -20
    exit 1
fi

echo ""
echo "[5/5] Connection details..."
IP_ADDR=$(hostname -I | awk '{print $1}')
CURRENT_USER=${SUDO_USER:-$(whoami)}

echo ""
echo "=========================================="
echo "SUCCESS! SSH is enabled and listening"
echo "=========================================="
echo ""
echo "Connect from your DEV machine with:"
echo "  ssh ${CURRENT_USER}@${IP_ADDR}"
echo ""
systemctl status sshd --no-pager | head -5
echo ""
echo "Done!"
