#!/usr/bin/env bash
#
# 2-personalize.sh — make a fresh Ubuntu/Debian host fit its ENVIRONMENT.
#
# ═════════════════════════════════════════════════════════════════════════════════════
# SCOPE: everything that is about WHERE the host lives, not about what it will run.
#        Hostname, time, base tooling, admin access, update policy.
#        ⛔ Nothing Kubernetes-specific belongs here. That is script 3.
#
# PORTABLE. No dependencies on any other script, no script server, no lab assumptions.
# Safe defaults: it changes as little as possible unless asked. Every switch is opt-in
# EXCEPT the hostname (which you pass explicitly) and the base packages.
#
# ⚠️ AT WORK, READ THE FLAGS BEFORE RUNNING. Passwordless sudo and frozen automatic
#    updates are both POLICY decisions at a firm, not technical ones. Defaults here are
#    off for that reason.
#
# USAGE
#   sudo bash 2-personalize.sh --hostname k8s-cp-1
#   sudo bash 2-personalize.sh --hostname k8s-cp-1 --timezone America/New_York \
#        --sudo-nopasswd agamache --cockpit --freeze-updates
#   sudo bash 2-personalize.sh --check
#
set -euo pipefail

NEW_HOSTNAME=""
TIMEZONE=""
SUDO_USER_NOPASSWD=""
WANT_COCKPIT=0
FREEZE_UPDATES=0
CHECK_ONLY=0
CHANGED=0

# Base tooling. 🚨 jq is DELIBERATELY ABSENT: the CKA environment provides yq and does
# not list jq, and practising with a tool the exam lacks is a trap you meet under a clock.
BASE_PKGS="curl wget vim less tree unzip htop man-db bash-completion ca-certificates gnupg"

while [ $# -gt 0 ]; do
    case "$1" in
        --hostname)       shift; NEW_HOSTNAME="${1:?--hostname needs a name}" ;;
        --timezone)       shift; TIMEZONE="${1:?--timezone needs e.g. America/New_York}" ;;
        --sudo-nopasswd)  shift; SUDO_USER_NOPASSWD="${1:?--sudo-nopasswd needs a username}" ;;
        --cockpit)        WANT_COCKPIT=1 ;;
        --freeze-updates) FREEZE_UPDATES=1 ;;
        --check)          CHECK_ONLY=1 ;;
        -h|--help)        sed -n '2,28p' "$0"; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done

say()  { printf '\n\033[1m━━━ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32mok\033[0m   %s\n' "$*"; }
did()  { printf '  \033[33mdid\033[0m  %s\n' "$*"; CHANGED=$((CHANGED+1)); }
warn() { printf '  \033[33mwarn\033[0m %s\n' "$*"; }
die()  { printf '  \033[31mFAIL\033[0m %s\n' "$*" >&2; exit 1; }
mutate(){ [ "$CHECK_ONLY" -eq 0 ]; }

[ "$(id -u)" -eq 0 ] || die "run with sudo"
[ -r /etc/os-release ] || die "no /etc/os-release"
# shellcheck disable=SC1091
. /etc/os-release
[ -f /etc/fedora-release ] && die "this is the Ubuntu/Debian script; this host is Fedora"
case "${ID:-}" in ubuntu|debian) ;; *) die "expected Ubuntu/Debian, found ${ID:-unknown}" ;; esac

say "PRE-FLIGHT"
ok "os: ${PRETTY_NAME:-$ID} ($(uname -r), $(dpkg --print-architecture))"
ok "current hostname: $(hostname)  |  timezone: $(timedatectl show -p Timezone --value 2>/dev/null || echo '?')"

# ═════════════════════════════════════════════════════════════════════════════════════
# HOSTNAME — three jobs, and two of them are the ones people miss
# ═════════════════════════════════════════════════════════════════════════════════════
if [ -n "$NEW_HOSTNAME" ]; then
    say "HOSTNAME -> $NEW_HOSTNAME"
    printf '%s' "$NEW_HOSTNAME" | grep -qE \
      '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$' \
      || die "'$NEW_HOSTNAME' is not a valid hostname"

    if [ "$(hostnamectl --static 2>/dev/null)" = "$NEW_HOSTNAME" ]; then ok "static hostname already correct"
    elif mutate; then hostnamectl set-hostname "$NEW_HOSTNAME"; did "set static hostname"
    else warn "static hostname is $(hostnamectl --static)"; fi

    # 🚨 hostnamectl NEVER touches /etc/hosts. A stale 127.0.1.1 line makes every later
    # `sudo` print "unable to resolve host", which sends people hunting the wrong fault.
    if grep -qE "^127\.0\.1\.1[[:space:]]+.*\b$NEW_HOSTNAME\b" /etc/hosts; then
        ok "/etc/hosts already resolves $NEW_HOSTNAME"
    elif mutate; then
        cp -n /etc/hosts /etc/hosts.bak-personalize 2>/dev/null || true
        if grep -qE '^127\.0\.1\.1[[:space:]]' /etc/hosts; then
            sed -i -E "s/^127\.0\.1\.1[[:space:]].*/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts
        else
            printf '127.0.1.1\t%s\n' "$NEW_HOSTNAME" >> /etc/hosts
        fi
        did "fixed the 127.0.1.1 line in /etc/hosts"
    else warn "/etc/hosts does not resolve $NEW_HOSTNAME"; fi

    # 🚨 cloud-init re-applies the hostname from instance metadata at EVERY boot unless
    # pinned. The symptom appears days later, long after anyone connects it to the build.
    if [ -d /etc/cloud ]; then
        if grep -qs '^preserve_hostname: true' /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg; then
            ok "cloud-init preserve_hostname pinned"
        elif mutate; then
            mkdir -p /etc/cloud/cloud.cfg.d
            echo 'preserve_hostname: true' > /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg
            did "pinned preserve_hostname (survives reboot)"
        else warn "cloud-init present, preserve_hostname NOT pinned"; fi
    else
        ok "no cloud-init — nothing to pin"
    fi
fi

# ═════════════════════════════════════════════════════════════════════════════════════
# TIME — worth more on a cluster than it looks
# ═════════════════════════════════════════════════════════════════════════════════════
say "TIME"
# ⭐ Clock skew between nodes breaks TLS and makes etcd/raft misbehave in ways that read
# as network faults. On any distributed system, rule out skew by MEASURING it, early.
if [ -n "$TIMEZONE" ]; then
    if [ "$(timedatectl show -p Timezone --value 2>/dev/null)" = "$TIMEZONE" ]; then ok "timezone already $TIMEZONE"
    elif mutate; then timedatectl set-timezone "$TIMEZONE"; did "timezone -> $TIMEZONE"
    else warn "timezone is $(timedatectl show -p Timezone --value)"; fi
fi
SYNC=$(timedatectl show -p NTPSynchronized --value 2>/dev/null || echo unknown)
[ "$SYNC" = "yes" ] && ok "clock synchronised (NTP)" || warn "clock NOT synchronised — fix before building a cluster"
ok "time now: $(date '+%F %T %Z')"

# ═════════════════════════════════════════════════════════════════════════════════════
# BASE PACKAGES
# ═════════════════════════════════════════════════════════════════════════════════════
say "BASE PACKAGES"
MISSING=""
for p in $BASE_PKGS; do dpkg -s "$p" >/dev/null 2>&1 || MISSING="$MISSING $p"; done
if [ -z "$MISSING" ]; then ok "all present: $BASE_PKGS"
elif mutate; then
    apt-get update -qq
    # shellcheck disable=SC2086
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $MISSING
    did "installed:$MISSING"
else warn "missing:$MISSING"; fi
ok "jq deliberately NOT installed (exam ships yq — see script 3)"

# ═════════════════════════════════════════════════════════════════════════════════════
# ADMIN ACCESS — opt-in, because at a firm this is a policy decision
# ═════════════════════════════════════════════════════════════════════════════════════
if [ -n "$SUDO_USER_NOPASSWD" ]; then
    say "PASSWORDLESS SUDO for $SUDO_USER_NOPASSWD"
    id "$SUDO_USER_NOPASSWD" >/dev/null 2>&1 || die "user '$SUDO_USER_NOPASSWD' does not exist"
    F="/etc/sudoers.d/$SUDO_USER_NOPASSWD"
    if [ -f "$F" ] && grep -q 'NOPASSWD: ALL' "$F"; then ok "$F already grants NOPASSWD"
    elif mutate; then
        echo "$SUDO_USER_NOPASSWD ALL=(ALL) NOPASSWD: ALL" > "$F"; chmod 440 "$F"
        # Validate before trusting it — a malformed sudoers file can lock out sudo entirely,
        # so it is removed again rather than left in place.
        if visudo -c -f "$F" >/dev/null 2>&1; then did "wrote $F (0440, syntax verified)"
        else rm -f "$F"; die "invalid sudoers syntax — removed $F, nothing changed"; fi
    else warn "$F absent or without NOPASSWD"; fi
fi

# ═════════════════════════════════════════════════════════════════════════════════════
# COCKPIT — opt-in web console, with the guard that matters
# ═════════════════════════════════════════════════════════════════════════════════════
if [ "$WANT_COCKPIT" -eq 1 ]; then
    say "COCKPIT (:9090)"
    if systemctl is-enabled --quiet cockpit.socket 2>/dev/null; then ok "already enabled"
    elif mutate; then
        PKGS="cockpit-ws cockpit-bridge cockpit-system cockpit-storaged cockpit-packagekit"
        NM=0; systemctl is-active --quiet NetworkManager 2>/dev/null && NM=1
        [ "$NM" -eq 1 ] && PKGS="$PKGS cockpit-networkmanager"
        apt-get update -qq
        # 🚨 NEVER install the `cockpit` METAPACKAGE. It Recommends cockpit-networkmanager,
        # which drags in network-manager, dnsmasq-base, ppp and wpasupplicant. On a host
        # running netplan/systemd-networkd that risks losing the network you administer it
        # over. Simulate first and refuse if NetworkManager appears unexpectedly.
        # shellcheck disable=SC2086
        if [ "$NM" -eq 0 ] && apt-get install -s $PKGS 2>/dev/null | awk '/^Inst/{print $2}' | grep -qx network-manager; then
            die "refusing: this install would pull network-manager onto a netplan host"
        fi
        # shellcheck disable=SC2086
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $PKGS
        systemctl enable --now cockpit.socket >/dev/null 2>&1 || true
        did "installed Cockpit (explicit packages, not the metapackage)"
    else warn "not enabled"; fi
    # Cockpit authenticates via PAM: a key-only account cannot log in.
    if [ -n "$SUDO_USER_NOPASSWD" ]; then
        case "$(passwd -S "$SUDO_USER_NOPASSWD" 2>/dev/null | awk '{print $2}')" in
            P) ok "$SUDO_USER_NOPASSWD has a usable password (Cockpit login will work)" ;;
            *) warn "$SUDO_USER_NOPASSWD has NO usable password — Cockpit login will FAIL (PAM)" ;;
        esac
    fi
fi

# ═════════════════════════════════════════════════════════════════════════════════════
# UPDATE POLICY — opt-in, and genuinely important on a cluster node
# ═════════════════════════════════════════════════════════════════════════════════════
if [ "$FREEZE_UPDATES" -eq 1 ]; then
    say "FREEZE AUTOMATIC UPDATES"
    # ⭐ Why this matters more on a Kubernetes node than on a general server: script 3
    # apt-holds kubelet/kubeadm/kubectl, but NOT containerd — and an unattended containerd
    # restart under a running cluster is an incident. Two upgrade paths where one is
    # uncontrolled is worse than either alone, because the state you believe you froze
    # can move on its own.
    # 🚨 MASK, do not disable: a masked unit cannot be started even as another unit's
    # dependency, which is the whole point since the timer would otherwise pull it in.
    for u in unattended-upgrades.service apt-daily.timer apt-daily-upgrade.timer; do
        STATE=$(systemctl is-enabled "$u" 2>/dev/null || echo absent)
        if [ "$STATE" = "masked" ]; then ok "$u already masked"
        elif [ "$STATE" = "absent" ]; then ok "$u not present"
        elif mutate; then systemctl mask "$u" >/dev/null 2>&1 && did "masked $u"
        else warn "$u is $STATE"; fi
    done
    # 🚨 Reading /etc/apt/apt.conf.d/20auto-upgrades will LIE to you: it still says
    # Unattended-Upgrade "1" on a masked host. The TIMERS decide; the config only describes.
    ok 'note: 20auto-upgrades still reads "1" even when masked — the timers decide'
fi

# ═════════════════════════════════════════════════════════════════════════════════════
say "SUMMARY"
val() { local out; out="$("$@" 2>/dev/null)" || true; [ -n "$out" ] && printf '%s' "$out" || printf '%s' '?'; }
printf '  hostname        : %s\n' "$(hostname)"
printf '  address         : %s\n' "$(ip -o -4 addr show | awk '!/ lo /{print $4}' | paste -sd,)"
printf '  resolves itself : %s\n' "$(getent hosts "$(hostname)" >/dev/null && echo yes || echo 'NO — sudo will warn')"
printf '  timezone        : %s (NTP synced: %s)\n' "$(val timedatectl show -p Timezone --value)" "$(val timedatectl show -p NTPSynchronized --value)"
printf '  cockpit         : %s\n' "$(val systemctl is-enabled cockpit.socket)"
printf '  auto-updates    : %s\n' "$(val systemctl is-enabled apt-daily-upgrade.timer)"
if [ "$CHECK_ONLY" -eq 1 ]; then printf '\n  --check: nothing was changed.\n'
else printf '\n  %d change(s) made. Re-run to confirm it reports 0 — that is the idempotency test.\n' "$CHANGED"; fi
printf '\n  NEXT: 3-k8s-base.sh  (kubeadm-ready node, still with NO role)\n\n'
