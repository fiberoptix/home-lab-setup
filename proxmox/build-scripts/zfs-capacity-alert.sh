#!/bin/bash
#
# zfs-capacity-alert.sh - email when any ZFS pool's REAL allocation crosses a threshold,
# or when a pool is not ONLINE.
#
# Lives at: /usr/local/bin/zfs-capacity-alert.sh on the Proxmox host (192.168.1.150)
# Run by:   zfs-capacity-alert.timer (hourly). Run by hand any time - it only reads and mails.
#
# 🚨 It reads `zpool list` CAP = blocks actually allocated. NOT the PVE GUI or `zfs list` USED,
# which count reservations: on Sep 28, 2026 the GUI said vm-critical was 71% "used" while 6% was
# written. With thin provisioning (Phase 19) nothing is reserved, so zpool CAP is the only number
# that predicts trouble - a thin pool that fills stalls EVERY VM on it at once.
#
# One email per pool per level per day, so the hourly timer cannot flood the inbox.
# Mail goes to root, which postfix relays to Gmail (set up in Phase 13).
#
# Test without waiting for a full pool (sends a real email, does not touch real alert state):
#   WARN=1 CRIT=2 STATE=/tmp/zfs-alert-test /usr/local/bin/zfs-capacity-alert.sh
#
set -u

WARN=${WARN:-70}
CRIT=${CRIT:-80}
TO=${TO:-root}
STATE=${STATE:-/var/lib/zfs-capacity-alert}
mkdir -p "$STATE"
today=$(date +%F)

lines=""
worst=""
while read -r name cap health; do
    cap=${cap%\%}
    level=""
    if [ "$health" != "ONLINE" ]; then level="UNHEALTHY"
    elif [ "$cap" -ge "$CRIT" ]; then level="CRITICAL"
    elif [ "$cap" -ge "$WARN" ]; then level="WARNING"
    fi
    if [ -z "$level" ]; then
        echo "ok        $name ${cap}% $health"
        continue
    fi
    stamp="$STATE/$name.$level"
    if [ "$(cat "$stamp" 2>/dev/null)" = "$today" ]; then
        echo "already-sent-today $level $name ${cap}% $health"
        continue
    fi
    echo "$today" > "$stamp"
    echo "ALERT     $level $name ${cap}% $health"
    lines="${lines}${level}: pool ${name} is ${cap}% allocated, health ${health}\n"
    case "$level:$worst" in
        UNHEALTHY:*|CRITICAL:|CRITICAL:WARNING|WARNING:) worst=$level ;;
    esac
done < <(zpool list -H -o name,cap,health)

[ -z "$lines" ] && exit 0

{
    printf 'To: %s\n' "$TO"
    printf 'Subject: [pve] ZFS %s: pool allocation/health alert\n\n' "$worst"
    printf "$lines"
    printf '\nThresholds: warn %s%%, critical %s%%. ZFS slows sharply past ~80%% allocated.\n' "$WARN" "$CRIT"
    printf 'This reads zpool CAP (real allocation), not the PVE GUI.\n\nzpool list:\n'
    zpool list
    printf '\nzpool status -x:\n'
    zpool status -x
} | /usr/sbin/sendmail -t
echo "mail sent to $TO (worst: $worst)"
