#!/bin/bash
# refresh.sh - Update and reboot all home-lab VMs in parallel with live status.
#
# Lives at: /usr/local/bin/refresh.sh on the Proxmox host (192.168.1.150)
# Invoked as: `refresh` (alias in /root/.bashrc)
#
# Behavior:
#   - SSHes into each VM as agamache (key auth, no password)
#   - Records current uptime BEFORE update (used to detect reboot)
#   - Runs apt update + apt upgrade non-interactively
#   - On success, runs `sudo init 6` to reboot
#   - All VMs are refreshed in parallel; per-VM logs in /tmp/refresh-<ip>.log
#   - Redraws a live status screen every 30s until all VMs reach a terminal state
#
# Per-VM status:
#   RUNNING  - SSH session active, apt is working
#   SHUTDOWN - SSH ended (init 6 fired) but VM is still up (mid-shutdown)
#   BOOTING  - SSH ended, host unreachable (reboot in progress)
#   DONE     - Host back online with fresh uptime (reboot complete)
#   FAILED   - SSH ended; host stayed up with unchanged uptime past grace window
#              (apt likely failed before init 6 could fire)
#
# VMs targeted (vm-openclaw-1 @ .185 is intentionally excluded):
#   .180  vm-kubernetes-1 (Proxmox VM ID 200)
#   .181  vm-gitlab-1
#   .182  vm-gitrun-1
#   .183  vm-sonarqube-1
#   .184  vm-www-1

set -u

VMS=(
    "192.168.1.180"
    "192.168.1.181"
    "192.168.1.182"
    "192.168.1.183"
    "192.168.1.184"
)

SSH_USER="agamache"

# Long-running SSH (the actual upgrade session)
SSH_OPTS=(
    -o BatchMode=yes
    -o StrictHostKeyChecking=accept-new
    -o ConnectTimeout=10
    -o ServerAliveInterval=15
    -o ServerAliveCountMax=3
    -o LogLevel=ERROR
)

# Fast probe SSH (used by the status loop)
PROBE_OPTS=(
    -o BatchMode=yes
    -o StrictHostKeyChecking=accept-new
    -o ConnectTimeout=3
    -o LogLevel=ERROR
)

REMOTE_CMD='set -e
export DEBIAN_FRONTEND=noninteractive
sudo -n apt-get update -y -qq
sudo -n apt-get -y -qq \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold \
    upgrade
sudo -n init 6'

POLL_SECS=30
MAX_WAIT_SECS=$((40 * 60))   # 40 min hard cap (GitLab can take ~15)
GRACE_SECS=180               # After ssh ends, allow this long for the VM to
                             # actually shut down before declaring FAILED.
                             # (GitLab's systemd shutdown can take ~60-90s.)

stamp() { date '+%H:%M:%S'; }

# State directory holds sentinel files (one per VM, written when its ssh subprocess exits)
STATE_DIR=$(mktemp -d /tmp/refresh-state.XXXXXX)
trap 'rm -rf "$STATE_DIR"' EXIT

# Per-VM log files (persistent across runs, in /tmp)
declare -A LOGS
for VM in "${VMS[@]}"; do
    LOGS[$VM]="/tmp/refresh-${VM}.log"
    : > "${LOGS[$VM]}"
done

# Preflight: record each VM's uptime BEFORE update (used to detect reboot completion)
declare -A PRE_UPTIME
echo "==> $(stamp) Pre-flight: recording current uptime of each VM..."
for VM in "${VMS[@]}"; do
    up=$(ssh "${PROBE_OPTS[@]}" "${SSH_USER}@${VM}" 'cat /proc/uptime | cut -d. -f1' 2>/dev/null || echo "")
    if [ -z "$up" ]; then
        echo "    ERROR: cannot SSH-probe $VM as ${SSH_USER}. Aborting." >&2
        exit 1
    fi
    PRE_UPTIME[$VM]=$up
    printf "    %-15s  pre-uptime=%ss\n" "$VM" "$up"
done
echo

# Launch parallel SSH (update + reboot) for each VM
echo "==> $(stamp) Launching parallel refresh on ${#VMS[@]} VMs (vm-openclaw-1/.185 excluded)..."
for VM in "${VMS[@]}"; do
    SENTINEL="$STATE_DIR/done-${VM}"
    (
        echo "=== refresh started $(stamp) on $VM ==="
        ssh "${SSH_OPTS[@]}" "${SSH_USER}@${VM}" "$REMOTE_CMD" </dev/null
        rc=$?
        echo "=== ssh subprocess exit=$rc at $(stamp) on $VM ==="
        # Sentinel: created AFTER ssh exits. The status loop uses its existence
        # (not PID checks) to know when each subshell is done.
        printf '%s\n' "$rc" > "$SENTINEL"
    ) >> "${LOGS[$VM]}" 2>&1 &
done

echo
echo "==> $(stamp) All ssh sessions launched. Live status begins below."
sleep 1

# ---------------------------------------------------------------------------
# Live status loop: redraws every POLL_SECS until every VM is DONE or FAILED.
# ---------------------------------------------------------------------------

TICK=0
START=$(date +%s)

# Detect if stdout is a real terminal (so we know whether to use `clear`)
IS_TTY=0
[ -t 1 ] && IS_TTY=1

render() {
    local elapsed_fmt vm status pad
    elapsed_fmt=$(printf "%02d:%02d" $((ELAPSED / 60)) $((ELAPSED % 60)))

    if [ "$IS_TTY" -eq 1 ]; then
        clear
    else
        printf '\n\n'
    fi

    cat <<HDR
================================================================
  refresh.sh   tick #$TICK   elapsed $elapsed_fmt   $(stamp)
================================================================
HDR

    for vm in "${VMS[@]}"; do
        status="${STATUSES[$vm]}"
        printf "\n  [%-8s] %s   (log: %s)\n" "$status" "$vm" "${LOGS[$vm]}"
        echo  "  ----------------------------------------------------------------"
        tail -n 4 "${LOGS[$vm]}" 2>/dev/null | sed 's/^/      /'
    done
    echo
}

declare -A STATUSES=()
# Initialize all to RUNNING; status loop will update on each tick
for VM in "${VMS[@]}"; do STATUSES[$VM]="RUNNING"; done

while true; do
    TICK=$((TICK + 1))
    NOW=$(date +%s)
    ELAPSED=$((NOW - START))

    all_terminal=1
    for VM in "${VMS[@]}"; do
        SENTINEL="$STATE_DIR/done-${VM}"
        cur="${STATUSES[$VM]}"

        # Don't re-probe terminal states
        if [ "$cur" = "DONE" ] || [ "$cur" = "FAILED" ]; then
            continue
        fi

        if [ ! -f "$SENTINEL" ]; then
            # SSH subshell still running -> RUNNING
            STATUSES[$VM]="RUNNING"
            all_terminal=0
            continue
        fi

        # SSH subshell has exited. Probe to determine final state.
        up=$(ssh "${PROBE_OPTS[@]}" "${SSH_USER}@${VM}" 'cat /proc/uptime | cut -d. -f1' 2>/dev/null || echo "")

        if [ -z "$up" ]; then
            # Unreachable -> reboot in progress
            STATUSES[$VM]="BOOTING"
            all_terminal=0
        elif [ "$up" -lt "${PRE_UPTIME[$VM]}" ] 2>/dev/null; then
            # Reachable with fresher uptime -> rebooted successfully
            STATUSES[$VM]="DONE"
        else
            # Reachable, uptime >= pre-update uptime. Two possibilities:
            #   (a) `init 6` just fired and the VM hasn't actually started
            #       tearing down sshd yet (typical race window: 5-90s).
            #   (b) apt failed before `init 6` could fire (real failure).
            # Tell them apart by how long ago the ssh subshell exited
            # (sentinel file's mtime captures that moment).
            sentinel_age=$(( $(date +%s) - $(stat -c %Y "$SENTINEL" 2>/dev/null || echo 0) ))
            if [ "$sentinel_age" -lt "$GRACE_SECS" ]; then
                STATUSES[$VM]="SHUTDOWN"
                all_terminal=0
            else
                STATUSES[$VM]="FAILED"
            fi
        fi
    done

    render

    if [ "$all_terminal" -eq 1 ]; then
        echo "================================================================"
        echo "  All VMs reached a terminal state. Final summary:"
        echo "================================================================"
        for VM in "${VMS[@]}"; do
            printf "    %-15s  %s\n" "$VM" "${STATUSES[$VM]}"
        done
        echo
        echo "  Logs: ${LOGS[${VMS[0]}]%/*}/refresh-<ip>.log"
        break
    fi

    if [ "$ELAPSED" -ge "$MAX_WAIT_SECS" ]; then
        echo "================================================================"
        echo "  TIMEOUT after ${MAX_WAIT_SECS}s. Non-terminal hosts:"
        echo "================================================================"
        for VM in "${VMS[@]}"; do
            s="${STATUSES[$VM]}"
            if [ "$s" != "DONE" ] && [ "$s" != "FAILED" ]; then
                printf "    %-15s  %s\n" "$VM" "$s"
            fi
        done
        break
    fi

    # Friendly "next refresh in N s" countdown -- skip if non-tty (no clear)
    if [ "$IS_TTY" -eq 1 ]; then
        for s in $(seq "$POLL_SECS" -1 1); do
            printf "\r  next refresh in %2ds (Ctrl-C to detach -- logs continue in /tmp)" "$s"
            sleep 1
        done
        printf "\r%-80s\r" ""
    else
        sleep "$POLL_SECS"
    fi
done

# Reap any leftover ssh subprocesses (sentinels exist, but processes may not be wait()ed)
wait 2>/dev/null || true

# Exit non-zero if any VM failed
for VM in "${VMS[@]}"; do
    [ "${STATUSES[$VM]}" = "FAILED" ] && exit 1
done
exit 0
