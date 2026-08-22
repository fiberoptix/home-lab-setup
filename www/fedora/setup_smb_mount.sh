#!/bin/bash
#
# setup_smb_mount.sh - Mount the NAS SMB share permanently (Fedora)
#
# Usage: sudo ./setup_smb_mount.sh
#        sudo SKIP_NAS=1 bash ./setup_smb_mount.sh    # prod-local / DMZ host
#
# Fedora counterpart of www/ubuntu/setup_smb_mount.sh. The mechanics are nearly
# identical (cifs-utils, fstab, systemd .mount unit); what matters is that BOTH
# hard-won guards are carried across, not just the feature:
#
#   1. The <nas>:445 REACHABILITY PRE-CHECK. This is the one that matters, because
#      it needs no operator knowledge. On Aug 20 2026 .184 (the internet-facing DMZ
#      box, Phase 12: OUT DROP -dest 192.168.1.0/24) was found with a NAS fstab
#      entry that had failed at every boot since July, AND /root/.smbcredentials
#      sitting on a host forbidden to reach that share. The firewall was doing its
#      job perfectly; the BUILDER was the leak.
#
#   2. nofail ON THE FSTAB ENTRY. Without it the generated unit is
#      RequiredBy=remote-fs.target, so an unreachable NAS fails the mount, fails
#      remote-fs.target with it, stalls boot for the mount timeout (11s measured,
#      ~90s worst case) and leaves a permanently failed unit.
#      NOT a drop to an emergency console -- _netdev already keeps the entry out of
#      local-fs.target. That overstatement was corrected on Aug 20 2026.
#
# What this version ADDS over the Ubuntu original: it PROVES the nofail worked by
# reading RequiredBy off the generated systemd unit. Across the lab that check was
# always run by hand after the fact. An option in fstab is a request; the generated
# unit is the result.
#

set -e

# ============================================
# CONFIGURATION
# ============================================

SMB_SERVER="192.168.1.120"
SMB_SHARE="NeoCortex/DEV_Projects"
SMB_USERNAME="fiberoptix"
MOUNT_POINT="/mnt/DevShare"
MOUNT_OPTIONS="uid=1000,gid=1000,file_mode=0775,dir_mode=0775,nofail"

SKIP_NAS="${SKIP_NAS:-0}"

# ============================================

echo "=========================================="
echo "SMB Share Mount Setup (Fedora)"
echo "=========================================="
echo "Server: $SMB_SERVER"
echo "Share:  $SMB_SHARE"
echo "Mount:  $MOUNT_POINT"
echo "=========================================="

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root (sudo ./setup_smb_mount.sh)"
    exit 1
fi

# Opt-out for prod-local / DMZ hosts.
# NOTE: `SKIP_NAS=1 sudo -E ...` does NOT work -- sudo is built with env_reset,
# warns "preserving the entire environment is not supported" and silently drops
# the variable, so the script runs in full. Put it AFTER sudo.
if [ "$SKIP_NAS" = "1" ]; then
    echo ""
    echo "SKIP_NAS=1 - this host is prod-local, not mounting the NAS."
    echo "No fstab entry and no credentials file will be written."
    exit 0
fi

# ---------------------------------------------------------------------------
echo ""
echo "[0/7] Checking the NAS is actually reachable from this host..."
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

# ---------------------------------------------------------------------------
echo ""
echo "[1/7] Installing cifs-utils..."
if rpm -q --quiet cifs-utils; then
    echo "    Already installed: $(rpm -q cifs-utils)"
else
    dnf install -y cifs-utils
fi

# ---------------------------------------------------------------------------
# Resolve the SMB password. Priority:
#   1. SMB_CRED_FILE / SMB_PASSWORD env var
#   2. www/smb_credentials -- ONE LEVEL ABOVE this script, and the single copy
#      shared by both distro trees. Canonical as of Aug 21, 2026: docker-compose
#      bind-mounts www/ubuntu and www/fedora into nginx but NOT www/, so a
#      secret kept here cannot be served, cannot be listed by autoindex, and cannot
#      be exposed by a future location block. Keeping ONE copy also avoids the real
#      hazard of a per-distro secret: duplicating it is how you end up publishing one.
#   3. the two older per-tree locations, so an existing clone keeps working
#   4. interactive prompt
#
# NOTE: this file is NEVER downloaded by host_setup.sh. On a freshly built host
# there is no candidate and the prompt is the expected path.
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SMB_PASSWORD="${SMB_PASSWORD:-}"

if [ -z "$SMB_PASSWORD" ]; then
    for cand in "${SMB_CRED_FILE:-}" \
                "$SCRIPT_DIR/../smb_credentials" \
                "$SCRIPT_DIR/smb_credentials" \
                "$SCRIPT_DIR/../ubuntu/smb_credentials"; do
        if [ -n "$cand" ] && [ -f "$cand" ]; then
            # shellcheck disable=SC1090
            . "$cand"
            echo "    Loaded SMB password from $cand"
            break
        fi
    done
fi

echo ""
echo "[2/7] Creating credentials file..."
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

# ---------------------------------------------------------------------------
echo ""
echo "[3/7] Creating mount point..."
mkdir -p "$MOUNT_POINT"
echo "    Created $MOUNT_POINT"

# ---------------------------------------------------------------------------
echo ""
echo "[4/7] Configuring /etc/fstab..."
FSTAB_ENTRY="//${SMB_SERVER}/${SMB_SHARE} ${MOUNT_POINT} cifs credentials=${CREDS_FILE},${MOUNT_OPTIONS},_netdev 0 0"

if grep -q "${SMB_SERVER}/${SMB_SHARE}" /etc/fstab; then
    echo "    Entry already exists in /etc/fstab, skipping..."
else
    echo "$FSTAB_ENTRY" >> /etc/fstab
    echo "    Added entry to /etc/fstab"
fi

# systemd caches the fstab-generated units. Without this the RequiredBy check
# below reads a STALE unit and can report a pass for an entry just changed.
systemctl daemon-reload

# ---------------------------------------------------------------------------
echo ""
echo "[5/7] Mounting share..."
# Check first. A re-run of `mount` on an existing mountpoint prints a full
# mount.cifs usage error, which reads like a failure in an otherwise clean
# idempotent run -- a false red in our own tooling.
if mountpoint -q "$MOUNT_POINT"; then
    echo "    Already mounted, nothing to do."
else
    mount "$MOUNT_POINT" || mount -a
fi

if ! mountpoint -q "$MOUNT_POINT"; then
    echo ""
    echo "ERROR: mount failed."
    echo "Try manually:"
    echo "  mount -t cifs //${SMB_SERVER}/${SMB_SHARE} ${MOUNT_POINT} -o credentials=${CREDS_FILE},${MOUNT_OPTIONS}"
    exit 1
fi
echo "    Mounted."

# ---------------------------------------------------------------------------
# PROVE the nofail took effect. Reading the fstab line back only proves what we
# asked for. The generated unit is what boot actually obeys.
# ---------------------------------------------------------------------------
echo ""
echo "[6/7] Verifying a dead NAS cannot block boot..."
UNIT=$(systemd-escape -p --suffix=mount "$MOUNT_POINT")
REQUIRED_BY=$(systemctl show "$UNIT" -p RequiredBy --value 2>/dev/null)
WANTED_BY=$(systemctl show "$UNIT" -p WantedBy --value 2>/dev/null)

echo "    unit      : $UNIT"
echo "    RequiredBy: ${REQUIRED_BY:-(empty)}"
echo "    WantedBy  : ${WANTED_BY:-(empty)}"

if [ -z "$REQUIRED_BY" ]; then
    echo "    CONFIRMED: RequiredBy is empty -- an unreachable NAS cannot hold up boot"
else
    echo ""
    echo "ERROR: RequiredBy is NOT empty ($REQUIRED_BY)."
    echo "       nofail did not take effect. A NAS outage will stall boot and leave"
    echo "       a permanently failed unit. Check the fstab line:"
    grep "${SMB_SERVER}/${SMB_SHARE}" /etc/fstab
    exit 1
fi

# SELinux is ENFORCING on Fedora and is not a factor on any Ubuntu host in this
# lab. Report denials rather than guess -- a CIFS mount that works for root and
# is denied to a confined app looks like a permissions bug in the app.
if command -v getenforce >/dev/null && [ "$(getenforce)" = "Enforcing" ]; then
    echo ""
    echo "    SELinux is Enforcing. Checking for denials against this mount..."

    # ---------------------------------------------------------------------
    # </dev/null and timeout are LOAD-BEARING, not defensive habit.
    #
    # `ausearch` with no audit log to read FALLS BACK TO STDIN. Over a non-TTY
    # ssh session stdin never closes, so it blocks forever -- and it hung this
    # entire build on the first run (Aug 21 2026). The trap is that auditd was
    # ACTIVE while /var/log/audit/ was EMPTY: on this Fedora 44 install the
    # records go to the journal, not to a file. A running audit daemon is not
    # the same thing as an audit log existing.
    #
    # This is a purely diagnostic step. It must never be able to fail the build
    # or hang it, so every branch is bounded and stdin is closed.
    # ---------------------------------------------------------------------
    DENIALS=""
    if command -v ausearch >/dev/null && [ -s /var/log/audit/audit.log ]; then
        DENIALS=$(timeout 10 ausearch -m avc -ts recent </dev/null 2>/dev/null \
                    | grep -F "$MOUNT_POINT" | tail -5 || true)
    else
        # No audit file -- read the journal instead.
        DENIALS=$(timeout 10 journalctl --since "-10 min" --no-pager </dev/null 2>/dev/null \
                    | grep -i 'avc:' | grep -F "$MOUNT_POINT" | tail -5 || true)
    fi

    if [ -n "$DENIALS" ]; then
        echo "    WARNING: SELinux AVC denials mention $MOUNT_POINT:"
        echo "$DENIALS"
    else
        echo "    No recent AVC denials mention $MOUNT_POINT"
    fi
fi

# ---------------------------------------------------------------------------
echo ""
echo "[7/7] Creating symlink in home directory..."
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

echo ""
echo "=========================================="
echo "SUCCESS! SMB share mounted at $MOUNT_POINT"
echo "=========================================="
echo ""
ls -la "$MOUNT_POINT" | head -10
echo ""
echo "Done!"
