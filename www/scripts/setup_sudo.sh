#!/bin/bash
#
# setup_sudo.sh - Enable passwordless sudo for agamache
#
# Usage: sudo ./setup_sudo.sh
#
# This script will allow agamache to run sudo without a password.
#

echo "=========================================="
echo "Passwordless Sudo Setup"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root (sudo ./setup_sudo.sh)"
    exit 1
fi

USERNAME="agamache"
SUDOERS_FILE="/etc/sudoers.d/$USERNAME"

# Check if user exists
if ! id "$USERNAME" &>/dev/null; then
    echo "ERROR: User '$USERNAME' does not exist"
    exit 1
fi

# Create sudoers file for passwordless sudo
echo ""
echo "Configuring passwordless sudo for $USERNAME..."

echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS_FILE"
chmod 440 "$SUDOERS_FILE"

# Validate sudoers file
if visudo -c -f "$SUDOERS_FILE" &>/dev/null; then
    echo "    Created $SUDOERS_FILE"
    echo "    Set permissions to 440"
    echo ""
    echo "=========================================="
    echo "SUCCESS! $USERNAME can now sudo without password"
    echo "=========================================="
else
    echo "ERROR: Invalid sudoers syntax, removing file"
    rm -f "$SUDOERS_FILE"
    exit 1
fi

echo ""
echo "Test with: sudo whoami"
echo "Done!"

