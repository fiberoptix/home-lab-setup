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
MOUNT_POINT="/mnt/DevShare"
# nofail: without it the generated unit is RequiredBy=remote-fs.target, so an
# unreachable NAS makes the mount fail, fails remote-fs.target with it, and stalls
# boot for the mount timeout (~11s observed, up to ~90s) leaving a permanently
# failed unit. With nofail it is only WantedBy, so boot ignores it.
# NOTE: _netdev already keeps this OUT of local-fs.target, so a missing nofail does
# NOT drop the host to an emergency console - measured on .184, which failed this
# mount at every boot since July 2026 and still came up with network and SSH fine.
MOUNT_OPTIONS="uid=1000,gid=1000,file_mode=0775,dir_mode=0775,nofail"

# Hosts that must never reach the NAS (DMZ / prod-local, e.g. .184 vm-www-1) skip this
# entirely. Put the variable AFTER sudo - `SKIP_NAS=1 sudo -E ...` does NOT work here,
# sudo is built with env_reset and prints "preserving the entire environment is not
# supported" while silently dropping it:
#     sudo SKIP_NAS=1 bash ./setup_smb_mount.sh
# or, for a whole build:
#     bash host_setup.sh --no-nas
SKIP_NAS="${SKIP_NAS:-0}"

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

# Opt-out for prod-local / DMZ hosts
if [ "$SKIP_NAS" = "1" ]; then
    echo ""
    echo "SKIP_NAS=1 - this host is prod-local, not mounting the NAS."
    echo "No fstab entry and no credentials file will be written."
    exit 0
fi

# Refuse to write a doomed entry. A host that cannot reach the NAS now will not be
# able to at boot either, and the result is a permanently failed mount unit plus NAS
# credentials sitting on a box that is not allowed to use them. Exactly what we found
# on .184 (Phase 12 DMZ: `OUT DROP -dest 192.168.1.0/24`) on Aug 20, 2026 - it had
# been failing this mount every boot since July while holding /root/.smbcredentials.
echo ""
echo "[0/6] Checking the NAS is actually reachable from this host..."
if timeout 6 bash -c "</dev/tcp/${SMB_SERVER}/445" 2>/dev/null; then
    echo "    ${SMB_SERVER}:445 reachable"
else
    echo ""
    echo "ERROR: cannot reach ${SMB_SERVER}:445 from this host."
    echo ""
    echo "  If this host is DMZ / prod-local, that is CORRECT - re-run the build with"
    echo "  --no-nas (or SKIP_NAS=1) and it will stop asking."
    echo "  If the NAS is merely down, fix that and re-run this script."
    echo ""
    echo "  Refusing to write an fstab entry that can never mount, or to drop NAS"
    echo "  credentials on a host that cannot use them."
    exit 1
fi

# Step 1: Install required packages
echo ""
echo "[1/6] Installing cifs-utils..."
apt update -qq
apt install -y cifs-utils

# Resolve the SMB password. Priority:
#   1. SMB_PASSWORD env var (if you exported one)
#   2. smb_credentials file sitting NEXT TO this script (gitignored; present on the
#      private GitLab mirror, so a LAN clone "just works" with no prompt)
#   3. interactive prompt (fallback)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SMB_CRED_FILE="${SMB_CRED_FILE:-$SCRIPT_DIR/smb_credentials}"
SMB_PASSWORD="${SMB_PASSWORD:-}"
if [ -z "$SMB_PASSWORD" ] && [ -f "$SMB_CRED_FILE" ]; then
    # shellcheck disable=SC1090
    . "$SMB_CRED_FILE"
    echo "    Loaded SMB password from $SMB_CRED_FILE"
fi

# Step 2: Create credentials file (secure)
echo ""
echo "[2/6] Creating credentials file..."
if [ -z "$SMB_PASSWORD" ]; then
    read -rsp "SMB password for ${SMB_USERNAME} (see PASSWORDS.md): " SMB_PASSWORD
    echo ""
fi
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
