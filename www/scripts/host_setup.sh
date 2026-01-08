#!/bin/bash
#
# host_setup.sh - Master setup script for new Ubuntu hosts
#
# Usage: 
#   1. wget http://192.168.1.195/scripts/host_setup.sh
#   2. bash host_setup.sh    (NOT sudo - script handles sudo internally)
#

# If run with sudo, remember the original user
ORIGINAL_USER="${SUDO_USER:-$USER}"

SCRIPT_SERVER="http://192.168.1.195/scripts"

# Get the directory where this script is located (where user downloaded it)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Scripts to download
SCRIPTS="setup_ssh.sh setup_sudo.sh setup_docker.sh setup_smb_mount.sh setup_desktop.sh anysphere.gpg"

echo "=========================================="
echo "     Ubuntu Host Setup - Master Script"
echo "=========================================="
echo ""
echo "Script Server: $SCRIPT_SERVER"
echo "Scripts Dir:   $SCRIPT_DIR"
echo ""
echo "This will configure a new Ubuntu host with:"
echo "  • SSH server"
echo "  • Passwordless sudo"
echo "  • Docker + Git"
echo "  • NAS mount (~/DevShare)"
echo "  • Desktop config (if desktop environment)"
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

DOWNLOAD_FAILED=0
for script in $SCRIPTS; do
    echo -n "  Downloading $script... "
    if wget -q -O "${SCRIPT_DIR}/${script}" "${SCRIPT_SERVER}/${script}"; then
        chmod +x "${SCRIPT_DIR}/${script}"
        echo "✓"
    else
        echo "✗ FAILED"
        DOWNLOAD_FAILED=1
    fi
done

echo ""

if [ $DOWNLOAD_FAILED -eq 1 ]; then
    echo "ERROR: Some scripts failed to download!"
    echo "Make sure script server is running: http://192.168.1.195/scripts/"
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

# ============================================
# PHASE 1: Base System (run as sudo)
# ============================================
echo ""
echo "╔════════════════════════════════════════╗"
echo "║  PHASE 1: Base System Setup            ║"
echo "╚════════════════════════════════════════╝"

echo ""
echo "━━━ Running setup_ssh.sh ━━━"
sudo bash "${SCRIPT_DIR}/setup_ssh.sh"

echo ""
echo "━━━ Running setup_sudo.sh ━━━"
sudo bash "${SCRIPT_DIR}/setup_sudo.sh"

# ============================================
# PHASE 2: Development Tools (run as sudo)
# ============================================
echo ""
echo "╔════════════════════════════════════════╗"
echo "║  PHASE 2: Development Tools            ║"
echo "╚════════════════════════════════════════╝"

echo ""
echo "━━━ Running setup_docker.sh ━━━"
sudo bash "${SCRIPT_DIR}/setup_docker.sh"

# ============================================
# PHASE 3: Storage (run as sudo)
# ============================================
echo ""
echo "╔════════════════════════════════════════╗"
echo "║  PHASE 3: Storage Configuration        ║"
echo "╚════════════════════════════════════════╝"

echo ""
echo "━━━ Running setup_smb_mount.sh ━━━"
sudo bash "${SCRIPT_DIR}/setup_smb_mount.sh"

# ============================================
# PHASE 4: Desktop (run as user)
# ============================================
echo ""
echo "╔════════════════════════════════════════╗"
echo "║  PHASE 4: Desktop Configuration        ║"
echo "╚════════════════════════════════════════╝"

if command -v gnome-shell &> /dev/null || command -v gsettings &> /dev/null; then
    echo "Desktop environment detected, running desktop setup..."
    echo ""
    echo "━━━ Running setup_desktop.sh (as $ORIGINAL_USER, not root) ━━━"
    # Run as the original user, not root
    if [ "$EUID" -eq 0 ]; then
        sudo -u "$ORIGINAL_USER" bash "${SCRIPT_DIR}/setup_desktop.sh"
    else
        bash "${SCRIPT_DIR}/setup_desktop.sh"
    fi
else
    echo "No desktop environment detected, skipping desktop setup."
fi

# ============================================
# SUMMARY
# ============================================
echo ""
echo "=========================================="
echo "     HOST SETUP COMPLETE!"
echo "=========================================="
echo ""
echo "Installed:"
echo "  ✓ SSH server (enabled)"
echo "  ✓ Passwordless sudo"
echo "  ✓ Docker + Docker Compose"
echo "  ✓ Git (configured)"
echo "  ✓ NAS mount at ~/DevShare"
if command -v gnome-shell &> /dev/null; then
echo "  ✓ Desktop configured (Chrome, Cursor, dock, etc.)"
fi
echo ""
echo "Scripts saved in: $SCRIPT_DIR"
echo ""
echo "IMPORTANT:"
echo "  • Log out and back in for docker group to take effect"
echo "  • Run 'source ~/.bashrc' for aliases (godev, update)"
echo "  • Run 'newgrp docker' to use docker without logout"
echo ""
echo "=========================================="
