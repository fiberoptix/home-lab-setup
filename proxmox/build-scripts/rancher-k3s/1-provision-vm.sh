#!/usr/bin/env bash
#
# 1-provision-vm.sh — create vm-k3s-rancher-1 (VMID 187) from the cloud-init template.
# PROXMOX-SPECIFIC. Phase 20. Same recipe and contract as
# education/k8s-cka-prep/scripts/1-provision-vms.sh, which is deliberately left untouched
# (Andrew, Oct 27, 2026: "make a new script for this project").
#
# PRODUCES: one Ubuntu host with a known hostname and static IPv4, the ROOT FILESYSTEM
#           actually grown to the disk size, SSH by key as $ADMIN_USER, guest agent running,
#           onboot=1 and started after GitLab (whose registry it pulls from).
#
# 🚨 Differences from the CKA script, on purpose:
#   - ONBOOT=1 + startup order=4: this is a service VM, not a POC node that stays down.
#   - Placement vm-ephemeral: Phase 19 rule — this project can rebuild it, so no backup job.
#
# USAGE
#   bash 1-provision-vm.sh --check     # preflight only
#   bash 1-provision-vm.sh             # create it if missing (idempotent)
#
set -euo pipefail

# ───────────────────────────── CONFIGURE ME ─────────────────────────────
PVE_HOST="root@192.168.1.150"
TEMPLATE_ID=9000
STORAGE="vm-ephemeral"
ADMIN_USER="agamache"
GATEWAY="192.168.1.1"
NAMESERVERS="8.8.8.8 8.8.4.4"
NETMASK_BITS=24
ONBOOT=1
STARTUP="order=4"
# vmid hostname           ip              cores mem_mb disk
NODE="187  vm-k3s-rancher-1  192.168.1.187   6     24576  120G"
# ────────────────────────────────────────────────────────────────────────

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1
[ "${1:-}" = "--help" ] && { sed -n '2,19p' "$0"; exit 0; }

say()  { printf '\n\033[1m━━━ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32mok\033[0m   %s\n' "$*"; }
did()  { printf '  \033[33mdid\033[0m  %s\n' "$*"; }
warn() { printf '  \033[33mwarn\033[0m %s\n' "$*"; }
die()  { printf '  \033[31mFAIL\033[0m %s\n' "$*" >&2; exit 1; }

pve() { ssh -o BatchMode=yes "$PVE_HOST" "$@"; }

# ARP, not ping — a live host may drop ICMP. Returns 0 (occupied) if a MAC answers.
addr_occupied() {
    local ip="$1" iface mac
    iface=$(ip -o -4 route show to default | awk '{print $5}' | head -1)
    ip neigh del "$ip" dev "$iface" 2>/dev/null || true
    ping -c1 -W1 "$ip" >/dev/null 2>&1 || true
    sleep 0.3
    mac=$(ip neigh show "$ip" dev "$iface" 2>/dev/null | grep -oE '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)
    [ -n "$mac" ]
}

read -r ID NAME IP CORES MEM DISK <<<"$NODE"

say "PRE-FLIGHT"
pve "qm config $TEMPLATE_ID" | grep -q '^template: 1' \
    && ok "template $TEMPLATE_ID is a template" || die "template $TEMPLATE_ID missing or not a template"
ok "storage $STORAGE: $(pve "zfs list -H -o avail $STORAGE") available"
ok "pool CAP: $(pve "zpool list -H -o name,cap" | tr '\t\n' ' ')"
ok "host RAM free: $(pve "free -g | awk '/^Mem:/{print \$7}'") GiB (need $((MEM/1024)))"

if pve "qm config $ID" >/dev/null 2>&1; then
    EXNAME=$(pve "qm config $ID" | awk -F': ' '/^name:/{print $2}')
    [ "$EXNAME" = "$NAME" ] || die "VMID $ID exists as '$EXNAME', not '$NAME'. Refusing to touch it."
    ok "VMID $ID already exists as $NAME — nothing to create"
    exit 0
fi
addr_occupied "$IP" && die "$IP is OCCUPIED (answered ARP) — refusing"
ok "VMID $ID free, $IP unclaimed (ARP)"

say "WILL CREATE: $NODE  onboot=$ONBOOT startup=$STARTUP"
[ "$CHECK_ONLY" -eq 1 ] && { printf '\n  --check: nothing was created.\n\n'; exit 0; }

say "CREATE $ID $NAME $IP"
pve "qm clone $TEMPLATE_ID $ID --name $NAME --full --storage $STORAGE" >/dev/null;  did "cloned"
pve "qm set $ID --cores $CORES --sockets 1 --memory $MEM --onboot $ONBOOT --startup $STARTUP" >/dev/null
did "cores=$CORES memory=${MEM}MB onboot=$ONBOOT startup=$STARTUP"
pve "qm resize $ID scsi0 $DISK" >/dev/null;  did "virtual disk -> $DISK"
pve "qm set $ID --ipconfig0 ip=$IP/$NETMASK_BITS,gw=$GATEWAY --nameserver '$NAMESERVERS'" >/dev/null
did "address $IP/$NETMASK_BITS"
pve "qm start $ID" >/dev/null;  did "started"

say "VERIFY FROM INSIDE THE GUEST"
for _ in $(seq 1 60); do
    ssh -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new "$ADMIN_USER@$IP" true 2>/dev/null && break
    sleep 3
done
OUT=$(ssh -o BatchMode=yes "$ADMIN_USER@$IP" \
    'printf "host=%s fs=%s cpus=%s mem=%sMB agent=%s" "$(hostname)" "$(df -h / | awk "NR==2{print \$2}")" \
     "$(nproc)" "$(free -m | awk "/^Mem:/{print \$2}")" "$(systemctl is-active qemu-guest-agent)"') \
    || die "guest unreachable over SSH"
echo "  $OUT"
FS=$(printf '%s' "$OUT" | grep -oE 'fs=[0-9.]+G' | grep -oE '[0-9]+' | head -1)
[ "${FS:-0}" -ge 100 ] && ok "root filesystem grew to ${FS}G" || warn "root filesystem is ${FS:-?}G — growpart may not have run"

# refresh.sh SSHes from the PVE host with accept-new; record the key now so a later
# rebuild at this IP is the only thing that can trip it.
pve "ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new $ADMIN_USER@$IP true" \
    && ok "PVE host has $IP in known_hosts (refresh.sh preflight)" || warn "PVE host could not SSH to $IP"

printf '\n  NEXT: copy + run education/k8s-cka-prep/scripts/2-personalize.sh on the VM, then 3-k3s.sh\n\n'
