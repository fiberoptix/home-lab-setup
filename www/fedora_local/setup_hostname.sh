#!/bin/bash
#
# setup_hostname.sh - Set the static hostname (Fedora)
#
# Usage: sudo ./setup_hostname.sh <hostname>
#
# ============================================================================
# WHY THIS EXISTS, AND HOW IT DIFFERS FROM THE UBUNTU ONE
#
# Originally this was Fedora-only, because every Ubuntu VM in this lab is a
# Proxmox clone of template 9000 and cloud-init sets the hostname from
# `qm clone --name`, whereas a VMware guest installed from an ISO has no such
# mechanism and keeps whatever Anaconda left behind.
#
# Measured on .196 before this first ran (Aug 21 2026):
#   static hostname   : (empty)
#   transient hostname: localhost-live
# `localhost-live` is the LIVE ISO's hostname. Anaconda installs from the live
# environment, and if no hostname is set during install the transient one is
# simply inherited. It does NOT mean the system is still running from the ISO --
# check `findmnt -no SOURCE /` if you need to tell the difference.
#
# There IS an Ubuntu counterpart as of Aug 21, 2026 (www/ubuntu/setup_hostname.sh),
# because "usually already correct" is not the same as "cannot need changing" --
# renames and ISO-installed Ubuntu hosts were both unserved. The two scripts are
# NOT interchangeable, and the differences are real rather than cosmetic:
#
#   * /etc/hosts. Debian policy puts the hostname on a 127.0.1.1 line and the
#     Ubuntu script maintains it. Fedora deliberately does NOT do this: its
#     nsswitch `hosts:` line includes systemd's `myhostname` module, which
#     resolves the local hostname with no /etc/hosts entry at all. So this
#     script does not CREATE such a line -- it only rewrites one that already
#     exists and has gone stale, which is the case that actually breaks things.
#
#   * cloud-init. Fedora Workstation does not ship it, so the pin below is
#     normally a no-op here. It is still attempted, because Fedora Cloud images
#     do have it and would revert a hand-set hostname on reboot exactly as
#     Ubuntu does.
# ============================================================================
#
# Deliberately NO `set -e` (it had one until Aug 21, 2026). This script does
# several independent things, and aborting on the first failure skipped the
# verification block at the end -- which is the only part that tells you WHICH
# of them landed. A half-applied hostname is the confusing state, so it is the
# one worth reporting precisely.
#

echo "=========================================="
echo "Hostname Setup (Fedora)"
echo "=========================================="

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root (sudo ./setup_hostname.sh <hostname>)"
    exit 1
fi

# Refuse to run on the wrong distro.
#
# Every OTHER script in this tree is self-guarding by accident: they call dnf,
# rpm and firewall-cmd, so on a Debian host they die loudly with "command not
# found". This one is the exception -- hostnamectl, sed and getent all exist
# everywhere, so it is the only Fedora script that will run on Ubuntu and
# SUCCEED at doing something, applying Fedora's /etc/hosts policy to a Debian
# host. Proven on Aug 21, 2026 by running it on the Ubuntu dev box by mistake.
if [ ! -f /etc/fedora-release ]; then
    echo "ERROR: this is the FEDORA hostname script. /etc/fedora-release not found."
    echo "       Debian-family hosts need the 127.0.1.1 line in /etc/hosts, which"
    echo "       this script deliberately does not create. Use instead:"
    echo "       http://192.168.1.195/ubuntu/setup_hostname.sh"
    exit 1
fi

NEW_HOSTNAME="${1:-}"
if [ -z "$NEW_HOSTNAME" ]; then
    echo "ERROR: no hostname given"
    echo "Usage: sudo ./setup_hostname.sh <hostname>"
    exit 1
fi

# Refuse extra arguments instead of silently using only the first. This is not a
# theoretical nicety: on Aug 21, 2026 an unquoted shell variable expanded to two
# words, this script took word one as a perfectly valid hostname, and RENAMED THE
# DEV BOX. It did exactly what it was asked; the failure was that "$1 plus junk"
# was indistinguishable from "$1". A hostname with a typo'd space now stops here
# rather than becoming a real, wrong hostname.
if [ "$#" -gt 1 ]; then
    echo "ERROR: too many arguments ($#). A hostname is a single word."
    echo "       Got: $*"
    echo "       If the name contains a space it is not a valid hostname."
    echo "       If a variable was passed, quote it: \"\$NAME\""
    exit 1
fi

# Validate before touching anything, so a bad name cannot leave the hostname and
# /etc/hosts disagreeing with each other.
if ! printf '%s' "$NEW_HOSTNAME" | grep -qE \
     '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'; then
    echo "ERROR: '$NEW_HOSTNAME' is not a valid hostname."
    echo "       Letters, digits, hyphens and dots; each label 1-63 chars and"
    echo "       may not begin or end with a hyphen."
    exit 1
fi

OLD_STATIC="$(hostnamectl --static 2>/dev/null)"
OLD_TRANSIENT="$(hostnamectl --transient 2>/dev/null)"
FAILED=0

echo ""
echo "[1/4] Current state..."
echo "    static    : ${OLD_STATIC:-(empty)}"
echo "    transient : ${OLD_TRANSIENT:-(none)}"

echo ""
echo "[2/4] Setting static hostname to '$NEW_HOSTNAME'..."
if hostnamectl set-hostname "$NEW_HOSTNAME"; then
    echo "    done"
else
    echo "    FAILED: hostnamectl returned non-zero."
    echo "    Is systemd-hostnamed running? 'systemctl status systemd-hostnamed'"
    FAILED=1
fi

# --- stale /etc/hosts entries ----------------------------------------------
# Fedora does not put the hostname in /etc/hosts, so there is usually nothing
# here. But if a previous admin (or another tool) added one, it now points at
# the OLD name, and a stale entry is worse than no entry: `myhostname` would
# have resolved correctly, and the stale file wins over it.
echo ""
echo "[3/4] Checking /etc/hosts for a stale entry..."
if [ -n "$OLD_STATIC" ] && grep -qE "^[0-9a-fA-F.:]+[[:space:]].*[[:space:]]${OLD_STATIC}([[:space:]]|$)" /etc/hosts; then
    cp -n /etc/hosts /etc/hosts.orig 2>/dev/null && echo "    saved original to /etc/hosts.orig"
    # The delimiter is '#', not '|'. With '|' as the s### delimiter, the
    # alternation inside the pattern has to be written '\|' to avoid terminating
    # the expression early -- and '\|' inside an ERE is a GNU extension whose
    # meaning is not portable (POSIX ERE reads it as a literal pipe). It happens
    # to work on GNU sed 4.9, which is exactly the kind of accidental correctness
    # that breaks somewhere else. A delimiter that cannot appear in a hostname
    # lets the alternation be written plainly.
    if sed -i -E "s#([[:space:]])${OLD_STATIC}([[:space:]]|\$)#\1${NEW_HOSTNAME}\2#g" /etc/hosts; then
        echo "    replaced '$OLD_STATIC' with '$NEW_HOSTNAME'"
    else
        echo "    FAILED to rewrite /etc/hosts"
        FAILED=1
    fi
else
    echo "    nothing stale (Fedora resolves the local name via nsswitch myhostname)"
fi

# --- stop cloud-init reverting it -------------------------------------------
echo ""
echo "[4/4] Pinning the hostname against cloud-init..."
if [ -d /etc/cloud/cloud.cfg.d ]; then
    cat > /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg <<EOF
# Written by setup_hostname.sh -- see www/fedora/setup_hostname.sh
#
# Without this, cloud-init re-applies the hostname from instance metadata on
# later boots and a hostname set by hand REVERTS at the next reboot.
preserve_hostname: true
EOF
    echo "    wrote /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg"
else
    echo "    SKIP: no /etc/cloud/cloud.cfg.d (expected on Fedora Workstation)"
fi

# --- verify ----------------------------------------------------------------
echo ""
echo "=========================================="
echo "Verifying what was ACTUALLY stored:"
echo "=========================================="

STORED="$(hostnamectl --static 2>/dev/null)"
echo "    static    : ${STORED:-(empty)}"
echo "    transient : $(hostnamectl --transient 2>/dev/null)"

if [ "$STORED" != "$NEW_HOSTNAME" ]; then
    echo ""
    echo "    NOTE: what was stored differs from what was requested."
    echo "          Requested: $NEW_HOSTNAME"
    echo "          Stored   : $STORED"
    echo "          systemd normalises hostnames; this is not necessarily an"
    echo "          error, but the name you will actually see is the stored one."
fi

if getent hosts "$NEW_HOSTNAME" >/dev/null 2>&1; then
    echo ""
    echo "    ok   '$NEW_HOSTNAME' resolves locally"
else
    echo ""
    echo "    WARN '$NEW_HOSTNAME' does not resolve locally."
    echo "         Check 'grep hosts: /etc/nsswitch.conf' for the myhostname"
    echo "         module, and /etc/hosts for a conflicting entry."
    FAILED=1
fi

echo ""
echo "=========================================="
if [ "$FAILED" -ne 0 ]; then
    echo "Hostname setup reported problems -- see the lines above."
    echo "=========================================="
    exit 1
fi
echo "Done. New shells will show the new hostname."
echo "Existing SSH sessions keep the old prompt until reconnect."
echo "=========================================="
