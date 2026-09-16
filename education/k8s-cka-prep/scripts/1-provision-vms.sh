#!/usr/bin/env bash
#
# 1-provision-vms.sh — create N Ubuntu VMs from a cloud-init template. PROXMOX-SPECIFIC.
#
# ═════════════════════════════════════════════════════════════════════════════════════
# THE CONTRACT — this is the part that transfers; the implementation is not
# ═════════════════════════════════════════════════════════════════════════════════════
# PRODUCES: N Ubuntu hosts, each with a known hostname and static IPv4, a disk of at
#           least DISK size with the ROOT FILESYSTEM ACTUALLY GROWN to match, SSH
#           reachable by key as $ADMIN_USER, and a guest agent running.
#
# ⚠️ AT WORK THE SUBSTRATE CHANGES AND ONLY THE CONTRACT SURVIVES. Replace the `qm`
#    calls with whatever creates machines there — vSphere/govc, Terraform, a cloud CLI,
#    PXE, or a ticket to someone else. Scripts 2 and 3 do not care how the host appeared.
#    ⭐ If a host is handed to you, SKIP THIS SCRIPT ENTIRELY and start at script 2.
#
# 🚨 TWO THINGS THAT ARE EASY TO GET WRONG AND EXPENSIVE TO DISCOVER LATE
#   1. A resized VIRTUAL disk is not a resized FILESYSTEM. `qm resize` grows the block
#      device; only cloud-init's growpart grows the partition. If it silently does not
#      fire, the box dies on its first big image pull with an error about image layers
#      rather than about disk space. This script verifies `df` FROM INSIDE the guest.
#   2. "Free" IP addresses. A ping sweep proves an address is QUIET, not UNCLAIMED — a
#      host can be alive and drop ICMP. This script probes with ARP, which a host's IP
#      firewall cannot decline on a local subnet.
#
# USAGE
#   bash 1-provision-vms.sh --check      # preflight only: template, VMIDs, addresses, space
#   bash 1-provision-vms.sh              # create anything missing (idempotent)
#
set -euo pipefail

# ───────────────────────────── CONFIGURE ME ─────────────────────────────
PVE_HOST="root@192.168.1.150"     # where qm runs; "" means run locally on the PVE node
TEMPLATE_ID=9000                  # a cloud-init template, NOT a plain VM
STORAGE="vm-ephemeral"
ADMIN_USER="agamache"             # inherited from the template's ciuser
GATEWAY="192.168.1.1"
NAMESERVERS="8.8.8.8 8.8.4.4"
ONBOOT=0                          # 0 = lab/POC tier: does NOT restart after a host reboot
NETMASK_BITS=24

# vmid  hostname                ip              cores  mem_mb  disk
NODES=(
  "201  vm-k8s-cka-control-1    192.168.1.201   2      4096    40G"
  "202  vm-k8s-cka-control-2    192.168.1.202   2      4096    40G"
  "203  vm-k8s-cka-control-3    192.168.1.203   2      4096    40G"
  "204  vm-k8s-cka-worker-1     192.168.1.204   2      4096    40G"
  "205  vm-k8s-cka-worker-2     192.168.1.205   2      4096    40G"
)
# ⚠️ kubeadm preflight FAILS below 2 cores on a control plane. Do not trim that.
# ────────────────────────────────────────────────────────────────────────

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1
[ "${1:-}" = "--help" ] && { sed -n '2,35p' "$0"; exit 0; }

say()  { printf '\n\033[1m━━━ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32mok\033[0m   %s\n' "$*"; }
did()  { printf '  \033[33mdid\033[0m  %s\n' "$*"; }
warn() { printf '  \033[33mwarn\033[0m %s\n' "$*"; }
die()  { printf '  \033[31mFAIL\033[0m %s\n' "$*" >&2; exit 1; }

# Run a command on the Proxmox node, wherever this script happens to be.
pve() { if [ -n "$PVE_HOST" ]; then ssh -o BatchMode=yes "$PVE_HOST" "$@"; else eval "$@"; fi; }

# Is an address occupied? ARP, not ping — a live host may drop ICMP entirely.
# Returns 0 (occupied) if a MAC answers for it.
addr_occupied() {
    local ip="$1" iface mac
    iface=$(ip -o -4 route show to default | awk '{print $5}' | head -1)
    [ -n "$iface" ] || { warn "cannot determine default interface; falling back to ping"; ping -c1 -W1 "$ip" >/dev/null 2>&1; return; }
    ip neigh del "$ip" dev "$iface" 2>/dev/null || true
    ping -c1 -W1 "$ip" >/dev/null 2>&1 || true
    sleep 0.3
    mac=$(ip neigh show "$ip" dev "$iface" 2>/dev/null | grep -oE '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)
    [ -n "$mac" ]
}

# ═════════════════════════════════════════════════════════════════════════════════════
say "PRE-FLIGHT"
pve "qm config $TEMPLATE_ID" >/dev/null 2>&1 || die "template $TEMPLATE_ID not found on $PVE_HOST"
pve "qm config $TEMPLATE_ID" | grep -q '^template: 1' \
    && ok "template $TEMPLATE_ID is a template" \
    || die "VM $TEMPLATE_ID exists but is NOT a template — clone would behave differently"
TSIZE=$(pve "qm config $TEMPLATE_ID" | grep -oE 'size=[0-9]+[MG]' | head -1)
ok "template disk $TSIZE — every node is resized, growpart verified from inside"
ok "storage: $STORAGE  ($(pve "zfs list -H -o avail $STORAGE" 2>/dev/null || echo '?') available)"

TO_CREATE=()
for spec in "${NODES[@]}"; do
    read -r ID NAME IP CORES MEM DISK <<<"$spec"
    if pve "qm config $ID" >/dev/null 2>&1; then
        EXNAME=$(pve "qm config $ID" | awk -F': ' '/^name:/{print $2}')
        if [ "$EXNAME" = "$NAME" ]; then ok "VMID $ID already exists as $NAME — will skip"
        else die "VMID $ID exists but is named '$EXNAME', not '$NAME'. Refusing to touch it."; fi
    else
        if addr_occupied "$IP"; then die "$IP is OCCUPIED (answered ARP) — refusing to assign it to $NAME"; fi
        ok "VMID $ID free, $IP unclaimed (ARP)"
        TO_CREATE+=("$spec")
    fi
done

[ "${#TO_CREATE[@]}" -eq 0 ] && { say "NOTHING TO DO — all nodes exist"; exit 0; }
say "WILL CREATE ${#TO_CREATE[@]} NODE(S)"
printf '  %s\n' "${TO_CREATE[@]}"
[ "$CHECK_ONLY" -eq 1 ] && { printf '\n  --check: nothing was created.\n\n'; exit 0; }

# ═════════════════════════════════════════════════════════════════════════════════════
for spec in "${TO_CREATE[@]}"; do
    read -r ID NAME IP CORES MEM DISK <<<"$spec"
    say "CREATE $ID  $NAME  $IP"
    pve "qm clone $TEMPLATE_ID $ID --name $NAME --full --storage $STORAGE" >/dev/null
    did "cloned from template $TEMPLATE_ID"
    pve "qm set $ID --cores $CORES --sockets 1 --memory $MEM --onboot $ONBOOT" >/dev/null
    did "cores=$CORES memory=${MEM}MB onboot=$ONBOOT"
    pve "qm resize $ID scsi0 $DISK" >/dev/null
    did "virtual disk -> $DISK (filesystem verified below, not here)"
    pve "qm set $ID --ipconfig0 ip=$IP/$NETMASK_BITS,gw=$GATEWAY --nameserver '$NAMESERVERS'" >/dev/null
    did "address $IP/$NETMASK_BITS gw $GATEWAY"
    pve "qm start $ID" >/dev/null
    did "started"
done

# ═════════════════════════════════════════════════════════════════════════════════════
say "VERIFY FROM INSIDE EACH GUEST (never from the hypervisor's view)"
for spec in "${TO_CREATE[@]}"; do
    read -r ID NAME IP CORES MEM DISK <<<"$spec"
    printf '  %-22s ' "$IP"
    for _ in $(seq 1 40); do
        ssh -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new \
            "$ADMIN_USER@$IP" true 2>/dev/null && break
        sleep 3
    done
    OUT=$(ssh -o BatchMode=yes -o ConnectTimeout=8 "$ADMIN_USER@$IP" \
        'printf "host=%s fs=%s cpus=%s mem=%sMB agent=%s swap=%s" \
           "$(hostname)" "$(df -h / | awk "NR==2{print \$2}")" "$(nproc)" \
           "$(free -m | awk "/^Mem:/{print \$2}")" \
           "$(systemctl is-active qemu-guest-agent 2>/dev/null || echo n/a)" \
           "$(swapon --show >/dev/null 2>&1 && [ -n "$(swapon --show)" ] && echo ON || echo off)"' 2>/dev/null) \
        || { warn "unreachable"; continue; }
    echo "$OUT"
    # The filesystem must actually have grown. A 3.5G root here means growpart did not fire.
    FS=$(printf '%s' "$OUT" | grep -oE 'fs=[0-9.]+[MG]' | cut -d= -f2)
    case "$FS" in
        *G) [ "${FS%G}" -ge 10 ] 2>/dev/null && ok "    root filesystem grew to $FS" \
              || warn "    root filesystem is only $FS — growpart may not have run" ;;
        *)  warn "    root filesystem is $FS — growpart did NOT run" ;;
    esac
done

cat <<'EOF'

  NEXT: 2-personalize.sh   (environment: hostname, time, users, base packages)
  THEN: 3-k8s-base.sh      (kubeadm-ready node, still with no role)

  NOTE ON SIZES: a 40G disk reports ~38G of root filesystem. The EFI and /boot
  partitions come out of the same disk. 38G is correct; there is no missing 2G.
EOF
