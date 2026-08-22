#!/bin/bash
#
# setup_ssh.sh - Enable SSH access on new Ubuntu VMs
#
# Usage: sudo ./setup_ssh.sh
#
# Run this first on new VMs so you can manage them remotely!
#

set -e

echo "=========================================="
echo "SSH Server Setup"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root (sudo ./setup_ssh.sh)"
    exit 1
fi

# Step 1: Install OpenSSH Server
echo ""
echo "[1/4] Installing openssh-server..."
apt update -qq
apt install -y openssh-server

# Step 2: Enable SSH service
echo ""
echo "[2/4] Enabling SSH service..."
systemctl enable ssh

# Step 3: Start SSH service
echo ""
echo "[3/4] Starting SSH service..."
systemctl start ssh

# Step 4: Configure firewall (if UFW is active)
echo ""
echo "[4/4] Configuring firewall..."
if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
    ufw allow ssh
    echo "    Allowed SSH through UFW firewall"
else
    echo "    UFW not active, skipping firewall config"
fi

# Get connection info
IP_ADDR=$(hostname -I | awk '{print $1}')
CURRENT_USER=${SUDO_USER:-$(whoami)}

echo ""
echo "=========================================="
echo "SUCCESS! SSH is now enabled"
echo "=========================================="
echo ""
echo "Connect from your DEV machine with:"
echo "  ssh ${CURRENT_USER}@${IP_ADDR}"
echo ""
echo "SSH Status:"
systemctl status ssh --no-pager | head -5
echo ""
echo "Done!"

