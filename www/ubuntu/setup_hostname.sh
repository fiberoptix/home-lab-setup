#!/bin/bash
#
# setup_hostname.sh - Set the static hostname (Ubuntu / Debian)
#
# Usage: sudo ./setup_hostname.sh <hostname>
#
# ============================================================================
# WHY THIS IS NOT A COPY OF THE FEDORA VERSION
#
# Setting a hostname on Ubuntu is `hostnamectl set-hostname` plus TWO things
# that command does not do, both of which are Debian-family specific:
#
#   1. /etc/hosts. Debian policy puts the hostname on a 127.0.1.1 line (Fedora
#      does not do this at all -- its /etc/hosts lists only localhost). If that
#      line still says the OLD name, the new name does not resolve locally, and
#      the symptom is `sudo: unable to resolve host <name>` printed before
#      EVERY sudo command, plus a multi-second DNS timeout on some tools.
#      hostnamectl never touches /etc/hosts, so this must be done by hand.
#
#   2. cloud-init. Every Ubuntu VM in this lab is a Proxmox clone of template
#      9000, and cloud-init sets the hostname from `qm clone --name`. It keeps
#      doing that on later boots unless told not to, so a hostname set by hand
#      can silently REVERT at the next reboot -- long after the build, when
#      nobody connects the two events. Passing --hostname is an explicit
#      statement that your name wins, so this script makes it stick.
#
# That second point is also why --hostname was Fedora-only until Aug 21, 2026:
# on a cloned Ubuntu VM the hostname is usually already correct. It is needed
# for the cases the clone workflow does not cover -- renaming an existing host,
# or an Ubuntu installed from an ISO rather than cloned (the dev box itself).
# ============================================================================
#
# Deliberately NO `set -e`: this script does three independent things, and if
# one fails the others are still worth attempting and reporting. Aborting on the
# first would hide which of the three actually landed -- and a half-applied
# hostname is precisely the state that is confusing to debug later. Everything
# is measured at the end and the exit code follows the measurements.
#

echo "=========================================="
echo "Hostname Setup (Ubuntu / Debian)"
echo "=========================================="

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root (sudo ./setup_hostname.sh <hostname>)"
    exit 1
fi

# Refuse to run on the wrong distro.
#
# Every OTHER script in this tree is self-guarding by accident: they call apt-get
# and dpkg, so on Fedora they die loudly with "command not found". This one is
# the exception -- hostnamectl, sed and getent all exist everywhere, so it is the
# only script here that would run on Fedora and SUCCEED at doing something,
# adding a 127.0.1.1 line that Fedora deliberately does not use.
if [ -f /etc/fedora-release ]; then
    echo "ERROR: this is the UBUNTU/DEBIAN hostname script, but this host is Fedora."
    echo "       Fedora resolves its own name via nsswitch 'myhostname' and does"
    echo "       not use a 127.0.1.1 line. Use instead:"
    echo "       http://192.168.1.195/fedora/setup_hostname.sh"
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

# Validate before touching anything. hostnamectl would reject a bad name too,
# but only AFTER /etc/hosts had already been rewritten by a later step in an
# earlier draft of this script -- leaving the two disagreeing. Check first.
if ! printf '%s' "$NEW_HOSTNAME" | grep -qE \
     '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'; then
    echo "ERROR: '$NEW_HOSTNAME' is not a valid hostname."
    echo "       Letters, digits, hyphens and dots; each label 1-63 chars and"
    echo "       may not begin or end with a hyphen."
    exit 1
fi

OLD_STATIC="$(hostnamectl --static 2>/dev/null)"
OLD_TRANSIENT="$(hostname 2>/dev/null)"
FAILED=0

echo ""
echo "[1/4] Current state..."
echo "    static    : ${OLD_STATIC:-(empty)}"
echo "    transient : ${OLD_TRANSIENT:-(none)}"
echo "    /etc/hosts: $(grep -E '^127\.0\.1\.1[[:space:]]' /etc/hosts 2>/dev/null || echo '(no 127.0.1.1 line)')"
if [ -d /etc/cloud ]; then
    echo "    cloud-init: present"
else
    echo "    cloud-init: absent (nothing to pin)"
fi

# --- 1. the hostname itself ------------------------------------------------
echo ""
echo "[2/4] Setting static hostname to '$NEW_HOSTNAME'..."
if hostnamectl set-hostname "$NEW_HOSTNAME"; then
    echo "    done"
else
    echo "    FAILED: hostnamectl returned non-zero."
    echo "    Is systemd-hostnamed running? 'systemctl status systemd-hostnamed'"
    FAILED=1
fi

# --- 2. /etc/hosts ---------------------------------------------------------
# The pristine file is preserved with `cp -n`, NOT a plain cp: this script is
# idempotent and gets re-run, and a plain cp would overwrite the good original
# with an already-modified copy on the second run -- destroying the only thing
# a backup exists for.
echo ""
echo "[3/4] Updating /etc/hosts (hostnamectl does not do this)..."
cp -n /etc/hosts /etc/hosts.orig 2>/dev/null && echo "    saved original to /etc/hosts.orig"

if grep -qE '^127\.0\.1\.1[[:space:]]' /etc/hosts; then
    # Replace the whole line. It may carry an FQDN plus a short name; the short
    # name alone is the Debian default and is what we want after a rename.
    if sed -i -E "s|^127\.0\.1\.1[[:space:]].*|127.0.1.1\t${NEW_HOSTNAME}|" /etc/hosts; then
        echo "    rewrote the 127.0.1.1 line"
    else
        echo "    FAILED to rewrite /etc/hosts"
        FAILED=1
    fi
else
    if printf '127.0.1.1\t%s\n' "$NEW_HOSTNAME" >> /etc/hosts; then
        echo "    added a 127.0.1.1 line (there was none)"
    else
        echo "    FAILED to append to /etc/hosts"
        FAILED=1
    fi
fi

# --- 3. stop cloud-init reverting it ---------------------------------------
# Only written when someone explicitly asked for a hostname, which is the whole
# justification: it disables cloud-init's ability to rename this host from
# Proxmox metadata later. That is correct for a deliberate rename and would be
# WRONG as a blanket default, so do not move this into the base build.
echo ""
echo "[4/4] Pinning the hostname against cloud-init..."
if [ -d /etc/cloud/cloud.cfg.d ]; then
    cat > /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg <<EOF
# Written by setup_hostname.sh -- see www/ubuntu/setup_hostname.sh
#
# Without this, cloud-init re-applies the hostname from the Proxmox cloud-init
# drive on later boots and a hostname set by hand REVERTS at the next reboot.
preserve_hostname: true
EOF
    echo "    wrote /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg"
else
    echo "    SKIP: no /etc/cloud/cloud.cfg.d, so cloud-init cannot revert it"
fi

# --- verify ----------------------------------------------------------------
echo ""
echo "=========================================="
echo "Verifying what was ACTUALLY stored:"
echo "=========================================="

STORED="$(hostnamectl --static 2>/dev/null)"
echo "    static    : ${STORED:-(empty)}"
echo "    transient : $(hostname 2>/dev/null)"
echo "    /etc/hosts: $(grep -E '^127\.0\.1\.1[[:space:]]' /etc/hosts 2>/dev/null || echo '(no 127.0.1.1 line)')"

if [ "$STORED" != "$NEW_HOSTNAME" ]; then
    echo ""
    echo "    NOTE: what was stored differs from what was requested."
    echo "          Requested: $NEW_HOSTNAME"
    echo "          Stored   : $STORED"
    echo "          systemd normalises hostnames; this is not necessarily an"
    echo "          error, but the name you will actually see is the stored one."
fi

# The local-resolution check is the one that catches the classic half-applied
# rename, so it is tested rather than assumed. `getent hosts` reads the same
# path sudo does.
if getent hosts "$NEW_HOSTNAME" >/dev/null 2>&1; then
    echo ""
    echo "    ok   '$NEW_HOSTNAME' resolves locally (no sudo warnings expected)"
else
    echo ""
    echo "    WARN '$NEW_HOSTNAME' does not resolve locally."
    echo "         Expect 'sudo: unable to resolve host $NEW_HOSTNAME' on every"
    echo "         sudo call. Check the 127.0.1.1 line in /etc/hosts."
    FAILED=1
fi

echo ""
echo "=========================================="
if [ "$FAILED" -ne 0 ]; then
    echo "Hostname setup reported problems -- see the lines above."
    echo "=========================================="
    exit 1
fi
echo "Done. New shells show the new hostname."
echo "Existing SSH sessions keep the old prompt until reconnect."
echo "=========================================="
