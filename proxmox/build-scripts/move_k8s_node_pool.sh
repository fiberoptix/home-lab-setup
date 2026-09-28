#!/usr/bin/env bash
#
# move_k8s_node_pool.sh - move ONE Phase 18 k8s node's disks to another ZFS pool WITH its snapshots.
#
# Run from:  the dev box (ssh key auth to root@pve and agamache@<node>).
# Usage:     move_k8s_node_pool.sh <201..205> [--prove-rollback | --dry-run]
#            --dry-run runs ONLY the pre-flight and stops. 🚨 Test pre-flight guards with --dry-run, never
#            with a real run you EXPECT to abort: on Sep 28 a "known-fail" test in the reverse direction
#            was a VALID move, passed pre-flight, and drained + shut down worker-2 (`| head` only hid it).
#            SRC=vm-ephemeral DST=vm-critical ROLLBACK_TO=c02-virgin-cluster  (defaults shown)
# Written:   Phase 19, Sep 28, 2026 - all five nodes moved with it. Record: phases/phase19_storage_tiers.md
#
# 🚨 PVE's own move-disk DROPS snapshots ("moving disk with snapshots, snapshots will not be moved!",
# PVE/API2/Qemu.pm). This drains the node, shuts it down, zfs send -R's disk + cloudinit, proves every
# snapshot by GUID, destroys the transfer snapshot (ZFS rolls back only to the MOST RECENT snapshot),
# rewrites every storage ref in the conf (current + snapshot sections), starts it and waits for its
# node Lease. The SOURCE zvols are left in place as the fallback - destroy them after the whole batch.
#
set -uo pipefail
ID=${1:?node id 201..205}; PROVE=${2:-}
SRC=${SRC:-vm-ephemeral}; DST=${DST:-vm-critical}; ROLLBACK_TO=${ROLLBACK_TO:-c02-virgin-cluster}
PVE=root@192.168.1.150
XFER=xfer-$(date +%Y%m%d%H%M%S)
declare -A NAME=([201]=vm-k8s-cka-control-1 [202]=vm-k8s-cka-control-2 [203]=vm-k8s-cka-control-3 [204]=vm-k8s-cka-worker-1 [205]=vm-k8s-cka-worker-2)
N=${NAME[$ID]:?not a Phase 18 k8s node}
KN=201; [ "$ID" = 201 ] && KN=202
pve()  { ssh -o BatchMode=yes $PVE "$@"; }
node() { ssh -o BatchMode=yes -o ConnectTimeout=5 agamache@192.168.1.$1 "${@:2}"; }
k()    { node $KN "sudo -n kubectl --kubeconfig /etc/kubernetes/admin.conf $*"; }
die()  { echo "🛑 ABORT: $*"; exit 1; }
ETCD="--cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key"
ready_count() { k get nodes --no-headers 2>/dev/null | awk '$2=="Ready"' | wc -l; }
# 🚨 "Ready" alone lies: a node down for less than the 50 s grace period is STILL reported Ready.
# Require its kube-node-lease renewTime (renewed ~10 s) to be NEWER than the VM start ($1 = epoch).
# Not the node conditions' lastHeartbeatTime: re-posted only every few minutes when nothing changes.
wait_ready() {
  for i in $(seq 1 60); do
    hb=$(k -n kube-node-lease get lease $N -o yaml 2>/dev/null | grep -o 'renewTime: "[^"]*"' | cut -d'"' -f2)
    if [ -n "$hb" ] && [ "$(date -d "$hb" +%s)" -gt "$1" ] && k get node $N --no-headers 2>/dev/null | awk '{print $2}' | grep -qE '^Ready'; then
      echo "  lease renewed $hb (after start) + Ready"; return 0; fi
    sleep 5
  done; return 1; }
etcd_table() { k -n kube-system exec etcd-${NAME[$KN]} -- etcdctl $ETCD endpoint status --cluster -w table 2>&1 | grep -E "https|deadline|error" | awk -F'|' '{print "   ", $2, "leader=" $10, "term=" $12, "index=" $13, $15}'; }

# A second concurrent run once hit the pre-flight (Sep 28): refuse to run twice. Locks the script file
# itself, so nothing is written outside the project directory (CURSOR_RULES: DIRECTORY RULES).
exec 9<"$0"
flock -n 9 || { echo "🛑 ANOTHER move_k8s_node_pool.sh IS RUNNING — refusing to start a second"; exit 1; }
T0=$(date +%s)

echo "════════ $ID ($N): $SRC -> $DST — 1. PRE-FLIGHT ════════"
[ "$(ready_count)" = 5 ] || die "cluster not 5/5 Ready"
pve "zfs list $DST/vm-$ID-disk-0 >/dev/null 2>&1" && die "target $DST/vm-$ID-disk-0 already exists"
pve "zfs list $SRC/vm-$ID-disk-0 >/dev/null 2>&1" || die "source $SRC/vm-$ID-disk-0 does not exist"
REFS=$(pve "grep -c '$SRC:vm-$ID-' /etc/pve/qemu-server/$ID.conf")
[ "${REFS:-0}" -gt 0 ] || die "no '$SRC:vm-$ID-' refs in $ID.conf — is it already moved?"
DISKS=$(pve "for d in disk-0 cloudinit; do zfs list $SRC/vm-$ID-\$d >/dev/null 2>&1 && echo \$d; done" | paste -sd' ')
case $ID in 201|202|203)
  h=$(k -n kube-system exec etcd-${NAME[$KN]} -- etcdctl $ETCD endpoint health --cluster 2>&1 | grep -c "is healthy")
  [ "$h" = 3 ] || die "etcd reports $h healthy members, need 3 before taking a control plane down"
  echo "  etcd: 3/3 healthy";;
esac
echo "  5/5 Ready, target free, $REFS conf refs to rewrite, volumes: $DISKS"
[ "$PROVE" = "--dry-run" ] && { echo "  --dry-run: pre-flight PASSED, stopping here. Nothing was changed."; exit 0; }

echo "════════ 2. DRAIN + SHUT DOWN ════════"
k drain $N --ignore-daemonsets --delete-emptydir-data --timeout=180s 2>&1 | grep -E "drained|error|cannot" | sed 's/^/  /' || true
k get node $N --no-headers | grep -q SchedulingDisabled || die "drain did not cordon $N"
{ pve "qm shutdown $ID --timeout 180" && pve "qm status $ID" | grep -q stopped; } || die "$ID did not stop"
echo "  stopped"

echo "════════ 3. SEND/RECV with snapshots ════════"
pve "bash -s" <<EOF || die "send/recv failed — source untouched, VM still configured on $SRC"
set -euo pipefail
for d in $DISKS; do
  zfs snapshot $SRC/vm-$ID-\$d@$XFER
  zfs send -R $SRC/vm-$ID-\$d@$XFER | zfs recv -u $DST/vm-$ID-\$d
done
echo "  sent: $DISKS"
EOF

echo "════════ 4. PROVE — every snapshot identical by GUID, same volsize ════════"
out=$(pve "for d in $DISKS; do for s in \$(zfs list -H -t snapshot -o name -r $SRC/vm-$ID-\$d); do t=\${s/$SRC/$DST}; a=\$(zfs get -H -o value guid \$s); b=\$(zfs get -H -o value guid \$t 2>/dev/null); echo \"\$([ \"\$a\" = \"\$b\" ] && echo SAME || echo DIFF) \${s#*/}\"; done; done; echo \"volsize \$(zfs get -H -o value volsize $SRC/vm-$ID-disk-0) -> \$(zfs get -H -o value volsize $DST/vm-$ID-disk-0)\"")
echo "$out" | sed 's/^/  /'
echo "$out" | grep -q DIFF && die "snapshot GUID mismatch"
nsnap=$(echo "$out" | grep -cE '^(SAME|DIFF) ')
[ "$nsnap" -ge 1 ] && [ "$(echo "$out" | grep -c '^SAME ')" = "$nsnap" ] || die "no snapshots compared"
v=$(echo "$out" | awk '/^volsize/{print ($2==$4) ? "same" : "DIFF"}'); [ "$v" = same ] || die "volsize differs"

echo "════════ 5. DESTROY the transfer snapshot (the real ones must stay MOST RECENT for rollback) ════════"
pve "for p in $DST $SRC; do for d in $DISKS; do zfs destroy \$p/vm-$ID-\$d@$XFER; done; done; zfs list -H -t snapshot -o name -s creation -r $DST/vm-$ID-disk-0 | sed 's/^/  now on $DST: /'"

echo "════════ 6. REWRITE the conf (backup kept in /root) ════════"
BK=/root/$ID.conf.pre-move-$(date +%Y%m%d%H%M)
pve "cp /etc/pve/qemu-server/$ID.conf $BK && c=\$(cat /etc/pve/qemu-server/$ID.conf) && printf '%s\n' \"\${c//$SRC:vm-$ID-/$DST:vm-$ID-}\" > /etc/pve/qemu-server/$ID.conf"
refs=$(pve "echo \$(grep -c '$SRC:' /etc/pve/qemu-server/$ID.conf) \$(grep -c '$DST:vm-$ID-' /etc/pve/qemu-server/$ID.conf)")
echo "  refs $SRC/$DST: $refs   (expect 0 $REFS)"
[ "$refs" = "0 $REFS" ] || die "conf rewrite wrong — restore with: cp $BK /etc/pve/qemu-server/$ID.conf"
pve "qm listsnapshot $ID" | sed 's/^/  /'

echo "════════ 7. START from $DST, Ready, uncordon ════════"
S=$(date +%s); pve "qm start $ID" >/dev/null
wait_ready $S || die "$N not Ready after 5 min"
k uncordon $N >/dev/null && echo "  $N Ready + uncordoned; disk: $(pve "qm config $ID | grep ^scsi0 | cut -d, -f1")"

if [ "$PROVE" = "--prove-rollback" ]; then
  echo "════════ 8. PROVE THE SNAPSHOT WORKS ON $DST — rollback to $ROLLBACK_TO, boot, Ready ════════"
  k drain $N --ignore-daemonsets --delete-emptydir-data --timeout=180s >/dev/null 2>&1
  pve "qm shutdown $ID --timeout 180 && qm rollback $ID $ROLLBACK_TO && echo '  rollback OK'" || die "rollback failed"
  S=$(date +%s); pve "qm start $ID" >/dev/null
  wait_ready $S || die "$N not Ready after rollback"
  k uncordon $N >/dev/null && echo "  $N Ready after rollback on $DST"
fi

echo "════════ 9. CLUSTER after $ID ════════"
for i in $(seq 1 24); do [ "$(ready_count)" = 5 ] && break; sleep 5; done
echo "  Ready: $(ready_count)/5   cordoned: $(k get nodes --no-headers | grep -c SchedulingDisabled)"
case $ID in 201|202|203) etcd_table ;; esac
echo "  $ID done in $(( $(date +%s) - T0 ))s. Source zvols remain on $SRC until you destroy them."
