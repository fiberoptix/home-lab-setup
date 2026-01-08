#!/bin/bash
#
# setup_smb_mount.sh - Mount SMB share permanently on Ubuntu
#
# Usage: sudo ./setup_smb_mount.sh
#
# This script will:
# 1. Install required packages (cifs-utils)
# 2. Create a credentials file (secure, root-only)
# 3. Create mount point
# 4. Add to /etc/fstab for permanent mount
# 5. Mount the share
# 6. Create symlink in user's home directory
#

set -e

# ============================================
# CONFIGURATION - EDIT THESE VALUES IF NEEDED
# ============================================

SMB_SERVER="192.168.1.120"
SMB_SHARE="NeoCortex/DEV_Projects"
SMB_USERNAME="fiberoptix"
SMB_PASSWORD="Powerme!1"
MOUNT_POINT="/mnt/DevShare"
MOUNT_OPTIONS="uid=1000,gid=1000,file_mode=0775,dir_mode=0775"

# ============================================
# DO NOT EDIT BELOW THIS LINE
# ============================================

echo "=========================================="
echo "SMB Share Mount Setup"
echo "=========================================="
echo "Server: $SMB_SERVER"
echo "Share:  $SMB_SHARE"
echo "Mount:  $MOUNT_POINT"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root (sudo ./setup_smb_mount.sh)"
    exit 1
fi

# Step 1: Install required packages
echo ""
echo "[1/6] Installing cifs-utils..."
apt update -qq
apt install -y cifs-utils

# Step 2: Create credentials file (secure)
echo ""
echo "[2/6] Creating credentials file..."
CREDS_FILE="/root/.smbcredentials"
cat > "$CREDS_FILE" << EOF
username=$SMB_USERNAME
password=$SMB_PASSWORD
EOF
chmod 600 "$CREDS_FILE"
echo "    Created $CREDS_FILE (mode 600)"

# Step 3: Create mount point
echo ""
echo "[3/6] Creating mount point..."
mkdir -p "$MOUNT_POINT"
echo "    Created $MOUNT_POINT"

# Step 4: Add to /etc/fstab (if not already there)
echo ""
echo "[4/6] Configuring /etc/fstab..."
FSTAB_ENTRY="//${SMB_SERVER}/${SMB_SHARE} ${MOUNT_POINT} cifs credentials=${CREDS_FILE},${MOUNT_OPTIONS},_netdev 0 0"

if grep -q "${SMB_SERVER}/${SMB_SHARE}" /etc/fstab; then
    echo "    Entry already exists in /etc/fstab, skipping..."
else
    echo "$FSTAB_ENTRY" >> /etc/fstab
    echo "    Added entry to /etc/fstab"
fi

# Step 5: Mount the share
echo ""
echo "[5/6] Mounting share..."
mount "$MOUNT_POINT" || mount -a

# Verify mount
if mountpoint -q "$MOUNT_POINT"; then
    echo ""
    echo "=========================================="
    echo "SUCCESS! SMB share mounted at $MOUNT_POINT"
    echo "=========================================="
    echo ""
    echo "Contents:"
    ls -la "$MOUNT_POINT" | head -10
    
    # Step 6: Create symlink in user's home directory
    echo ""
    echo "[6/6] Creating symlink in home directory..."
    if [ -n "$SUDO_USER" ]; then
        USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        SYMLINK_PATH="$USER_HOME/DevShare"
        
        if [ -L "$SYMLINK_PATH" ]; then
            echo "    Symlink already exists at $SYMLINK_PATH"
        elif [ -e "$SYMLINK_PATH" ]; then
            echo "    WARNING: $SYMLINK_PATH exists but is not a symlink, skipping..."
        else
            ln -s "$MOUNT_POINT" "$SYMLINK_PATH"
            chown -h "$SUDO_USER:$SUDO_USER" "$SYMLINK_PATH"
            echo "    Created symlink: $SYMLINK_PATH -> $MOUNT_POINT"
        fi
    else
        echo "    WARNING: Could not determine user, run with sudo to create symlink"
    fi
else
    echo ""
    echo "=========================================="
    echo "WARNING: Mount may have failed."
    echo "=========================================="
    echo "Try manually:"
    echo "  mount -t cifs //${SMB_SERVER}/${SMB_SHARE} ${MOUNT_POINT} -o credentials=${CREDS_FILE},${MOUNT_OPTIONS}"
fi

echo ""
echo "Done!"
