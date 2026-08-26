#!/bin/bash
#
# setup_sudo.sh - Enable passwordless sudo for agamache on Fedora
#
# Usage: sudo ./setup_sudo.sh
#
# Fedora counterpart of www/ubuntu/setup_sudo.sh. Differences from Ubuntu:
#   1. The admin group is `wheel`, not `sudo`.
#   2. Measured on Fedora 44: the installer puts the first user in `wheel`, but
#      wheel still PROMPTS for a password. Group membership is not the same thing
#      as passwordless.
#   3. This version proves the result by running `sudo -n` as the user. The Ubuntu
#      original only validates sudoers SYNTAX, which cannot tell you whether the
#      rule actually takes effect -- a valid file can still be overridden by a
#      later one, since sudoers.d is read in lexical order.
#

echo "=========================================="
echo "Passwordless Sudo Setup (Fedora)"
echo "=========================================="

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root (sudo ./setup_sudo.sh)"
    exit 1
fi

USERNAME="agamache"
SUDOERS_FILE="/etc/sudoers.d/$USERNAME"

if ! id "$USERNAME" &>/dev/null; then
    echo "ERROR: User '$USERNAME' does not exist"
    exit 1
fi

# Fedora's admin group is wheel. Report it, but the NOPASSWD rule below does not
# depend on it -- the rule names the user directly.
echo ""
echo "[1/3] Checking group membership..."
if id -nG "$USERNAME" | tr ' ' '\n' | grep -qx wheel; then
    echo "    $USERNAME is in 'wheel' (Fedora's admin group)"
else
    echo "    WARNING: $USERNAME is NOT in 'wheel'. Adding."
    usermod -aG wheel "$USERNAME"
fi

echo ""
echo "[2/3] Writing $SUDOERS_FILE..."

# Write to a temp file and validate BEFORE putting it in sudoers.d. A broken file
# already in the directory breaks sudo for everyone, including the shell you would
# need to fix it.
TMP_SUDOERS=$(mktemp /tmp/sudoers.XXXXXX)
echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > "$TMP_SUDOERS"
chmod 440 "$TMP_SUDOERS"

if ! visudo -c -f "$TMP_SUDOERS" &>/dev/null; then
    echo "ERROR: Invalid sudoers syntax, nothing installed"
    rm -f "$TMP_SUDOERS"
    exit 1
fi

install -m 440 -o root -g root "$TMP_SUDOERS" "$SUDOERS_FILE"
rm -f "$TMP_SUDOERS"
echo "    Created $SUDOERS_FILE (mode 440, validated before install)"

# Prove it. Syntax-valid is not the same as in-effect.
echo ""
echo "[3/3] Verifying passwordless sudo actually works..."
if runuser -u "$USERNAME" -- sudo -n true 2>/dev/null; then
    echo "    Confirmed: 'sudo -n true' succeeds as $USERNAME"
    echo ""
    echo "=========================================="
    echo "SUCCESS! $USERNAME can now sudo without a password"
    echo "=========================================="
else
    echo "ERROR: file installed but 'sudo -n' STILL prompts."
    echo "       Check for a later file in /etc/sudoers.d/ overriding it:"
    ls -la /etc/sudoers.d/
    exit 1
fi

echo ""
echo "Done!"
