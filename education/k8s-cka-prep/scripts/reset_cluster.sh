#!/usr/bin/env bash
#
# reset_cluster.sh — roll all five CKA nodes back to the baseline snapshot, boot them, and prove the
# cluster is back. PROXMOX-SPECIFIC. Run from the dev box: key auth to root@pve and agamache@<node>.
#
# USAGE
#   bash reset_cluster.sh --check   # pre-flight only: changes nothing
#   bash reset_cluster.sh --yes     # DISCARDS everything since the snapshot, on all five VMs
#   SNAP=<name> bash reset_cluster.sh --check   # another snapshot (default c03-equipped-cluster)
#
# WHEN: after an exercise that broke the cluster below the API (etcd, certificates, the kubelet, a
# control-plane manifest, a node), or whenever lab_check.sh reports drift at L1-L3. Workload exercises
# are undone with their own Reset line instead — see exercises.md.
#
# 🚨 ZFS rolls back only to the MOST RECENT snapshot. Pre-flight refuses unless $SNAP is the newest
#    snapshot on every snapshotted volume of every VM — otherwise `qm rollback` fails AFTER the VMs
#    are already stopped, and the cluster is down with nothing restored.
# ⭐ HARD STOP, NOT A GRACEFUL SHUTDOWN: everything on the disks is about to be discarded, so there is
#    nothing to flush. What makes the result consistent is the snapshot, which was taken with all five
#    powered off together (chapters 4 and 6). It also saves the ~5 min a workers-first shutdown takes.
# ⛔ Never takes, deletes or renames a snapshot. A new baseline is a deliberate step by hand (ch 4 §4),
#    followed by `lab_check.sh --record`.
#
set -uo pipefail
export LC_ALL=C
HERE=$(cd "$(dirname "$0")" && pwd)
SNAP=${SNAP:-c03-equipped-cluster}
PVE=root@192.168.1.150
IDS="201 202 203 204 205"; CP=201
declare -A NAME=([201]=vm-k8s-cka-control-1 [202]=vm-k8s-cka-control-2 [203]=vm-k8s-cka-control-3 [204]=vm-k8s-cka-worker-1 [205]=vm-k8s-cka-worker-2)
pve()  { ssh -o BatchMode=yes $PVE "$@"; }
node() { ssh -o BatchMode=yes -o ConnectTimeout=5 agamache@192.168.1.$1 "${@:2}"; }
die()  { echo "🛑 ABORT: $*"; exit 1; }
el()   { echo "$(( $(date +%s) - $1 ))s"; }

case ${1:-} in --check|--yes) ;; *) awk '/^# USAGE/,/SNAP=<name>/' "$0"; exit 2;; esac

exec 9<"$0"
flock -n 9 || die "another reset_cluster.sh is running"
T0=$(date +%s)

echo "════════ 1. PRE-FLIGHT — snapshot '$SNAP' ════════"
pve true || die "cannot ssh to $PVE"
for id in $IDS; do
  out=$(pve "bash -s" <<EOF
n=\$(qm config $id 2>/dev/null | awk '/^name:/{print \$2}')
[ "\$n" = "${NAME[$id]}" ] || { echo "BAD name '\$n', expected ${NAME[$id]}"; exit; }
qm listsnapshot $id | grep -q " $SNAP " || { echo "BAD no snapshot $SNAP"; exit; }
qm config $id --snapshot $SNAP | grep -q '^vmstate' && echo "BAD $SNAP holds RAM state — not an offline snapshot"
have=0
for v in \$(qm config $id | grep -E '^(scsi|virtio|sata|ide|efidisk|tpmstate)[0-9]+:' | grep -oE '[a-z0-9-]+:vm-$id-[a-z0-9-]+'); do
  ds=\$(pvesm path \$v); ds=\${ds#/dev/zvol/}
  last=\$(zfs list -H -t snapshot -o name -s creation "\$ds" 2>/dev/null | tail -1)
  [ -z "\$last" ] && continue
  have=1
  [ "\$last" = "\$ds@$SNAP" ] || echo "BAD newest snapshot of \$ds is \${last#*@}, not $SNAP"
done
[ \$have = 1 ] || echo "BAD no snapshotted volume found"
echo "OK \$(qm status $id | awk '{print \$2}') · taken \$(qm listsnapshot $id | awk '\$2=="$SNAP"{print \$3, \$4}')"
EOF
)
  echo "  $id ${NAME[$id]}: $(grep -v '^BAD' <<<"$out" | sed 's/^OK //')"
  grep '^BAD' <<<"$out" | sed 's/^BAD/      ✗/'
  grep -q '^BAD' <<<"$out" && FAIL=1
done
[ -z "${FAIL:-}" ] || die "pre-flight failed — nothing was changed"
if [ "$1" = "--check" ]; then
  echo "  --check: pre-flight PASSED. Nothing was changed."
  echo "  --yes would DISCARD everything on all five VMs since the snapshot above."; exit 0; fi

echo "════════ 2. STOP all five (hard — the disks are about to be discarded) ════════"
T=$(date +%s)
for id in 204 205 201 202 203; do
  pve "qm status $id" | grep -q running && pve "qm stop $id" >/dev/null; done
for id in $IDS; do pve "qm status $id" | grep -q stopped || die "$id did not stop"; done
echo "  all stopped in $(el $T)"

echo "════════ 3. ROLL BACK all five to $SNAP ════════"
T=$(date +%s)
for id in $IDS; do pve "qm rollback $id $SNAP" >/dev/null 2>&1 || die "rollback of $id failed — VMs are stopped; investigate on the host"; done
echo "  rolled back in $(el $T)"

echo "════════ 4. START — control planes, then workers ════════"
S=$(date +%s)
for id in 201 202 203 204 205; do pve "qm start $id" >/dev/null || die "qm start $id failed"; done
for i in $(seq 1 60); do
  up=0; for id in $IDS; do node $id true 2>/dev/null && up=$((up+1)); done
  [ $up = 5 ] && break; sleep 5; done
[ $up = 5 ] || die "only $up/5 reachable over SSH after 5 min"
echo "  5/5 reachable over SSH $(el $S) after start"

echo "════════ 5. NODES Ready, with a lease renewed AFTER the start ════════"
# 🚨 "Ready" alone lies straight after a boot: the API can still be reporting the snapshot's last state.
for i in $(seq 1 60); do
  fresh=$(node $CP "kubectl get lease -n kube-node-lease --no-headers -o custom-columns=N:.metadata.name,R:.spec.renewTime 2>/dev/null" |
          while read -r n r; do [ "$r" != "<none>" ] && [ "$(date -d "$r" +%s 2>/dev/null || echo 0)" -gt "$S" ] && echo "$n"; done | wc -l)
  ready=$(node $CP "kubectl get nodes --no-headers 2>/dev/null" | awk '$2=="Ready"' | wc -l)
  [ "$fresh" = 5 ] && [ "$ready" = 5 ] && break; sleep 5; done
[ "$fresh" = 5 ] && [ "$ready" = 5 ] || die "after 5 min: $ready/5 Ready, $fresh/5 fresh leases"
echo "  5/5 Ready with fresh leases $(el $S) after start"

echo "════════ 6. MATCHES THE FINGERPRINT? (lab_check.sh, retried while pods settle) ════════"
for i in $(seq 1 24); do
  out=$(bash "$HERE/lab_check.sh" 2>&1); rc=$?
  [ $rc = 0 ] && break; sleep 15; done
echo "$out" | sed 's/^/  /'
echo
echo "  done in $(el $T0) from launch, pre-flight included ($(el $S) since start)."
[ $rc = 0 ] || die "cluster is up but does not match the fingerprint — read the drift above"
