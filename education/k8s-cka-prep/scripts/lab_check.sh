#!/usr/bin/env bash
#
# lab_check.sh — is the CKA cluster still in its baseline (c03-equipped-cluster) state?
# Run from the dev box: key auth to agamache@192.168.1.201-205, passwordless sudo on the nodes.
#
# Compares the live cluster with a recorded fingerprint and names the LOWEST layer that drifted:
#   L1 node OS   kernel, swap, modules, sysctls, services, update units, apt holds
#   L2 config    sha256 of kubelet / containerd / systemd / sysctl / apt config, static-pod
#                manifests, and the PUBLIC certificates under /etc/kubernetes/pki
#   L3 control   etcd members healthy, Calico tigerastatus, aggregated APIs Available
#   L4 objects   nodes, namespaces, workloads + images, Services, RBAC, storage, routing, Helm
#                releases, the kube-system ConfigMaps kubeadm and the add-ons read — and each node's
#                home-dir entries, where exercise answers land
# ⭐ Drift at L1-L3 → hard reset (reset_cluster.sh). Drift at L4 only → that exercise's Reset line
#    from exercises.md, or --clean for the usual leftovers.
#
# USAGE
#   bash lab_check.sh            # compare. Exit 0 clean, 1 drift, 2 cannot reach the cluster
#   bash lab_check.sh --clean    # remove exercise leftovers first, then compare: namespaces x01..,
#                                # ~/answers and ~/x01.. on every node, and any cordon
#   bash lab_check.sh --record   # write the fingerprint from the live cluster. ⛔ ONLY straight after
#                                # a reset to the baseline — recording drift makes it the new "clean"
#   FP=<file> bash lab_check.sh  # another fingerprint (default: c03-equipped-cluster.fingerprint)
#
# READS ONLY, except --clean. No private key and no Secret's data is read: certificates are hashed
# (public halves only), Secrets and ConfigMaps outside kube-system are listed by NAME.
# Writes nothing outside this directory (CURSOR_RULES: directory rules) — the comparison runs in memory.
#
set -uo pipefail
export LC_ALL=C
HERE=$(cd "$(dirname "$0")" && pwd)
FP=${FP:-$HERE/c03-equipped-cluster.fingerprint}
NODES="201 202 203 204 205"; CP=201
MODE=${1:-}
node() { ssh -o BatchMode=yes -o ConnectTimeout=5 agamache@192.168.1.$1 "${@:2}"; }

collect_node() {
  node "$1" 'bash -s' <<'EOF'
h=$(hostname -s); shopt -s nullglob
p() { echo "$1 $h ${*:2}"; }
p L1 kernel "$(uname -r)"
p L1 swap-devices "$(swapon --noheadings | wc -l)"
for m in overlay br_netfilter; do p L1 module $m "$(lsmod | awk -v m=$m '$1==m{f=1} END{print f?"loaded":"MISSING"}')"; done
for s in net.ipv4.ip_forward net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables; do
  p L1 sysctl "$s=$(sysctl -n $s 2>/dev/null)"; done
for u in containerd kubelet; do p L1 service $u "$(systemctl is-active $u)" "$(systemctl is-enabled $u)"; done
for u in apt-daily.timer apt-daily-upgrade.timer unattended-upgrades.service; do
  p L1 unit $u "$(systemctl is-enabled $u 2>/dev/null)"; done
p L1 apt-holds "$(apt-mark showhold | sort | paste -sd, -)"
p L4 home "$(ls ~ | sort | paste -sd, -)"
for f in /var/lib/kubelet/config.yaml /var/lib/kubelet/kubeadm-flags.env /etc/default/kubelet \
         /etc/containerd/config.toml /etc/crictl.yaml /usr/lib/systemd/system/kubelet.service \
         /usr/lib/systemd/system/kubelet.service.d/*.conf /etc/systemd/system/kubelet.service.d/*.conf \
         /etc/modules-load.d/*.conf /etc/sysctl.d/*.conf /etc/apt/sources.list.d/* \
         /etc/kubernetes/manifests/* /etc/kubernetes/pki/*.crt /etc/kubernetes/pki/etcd/*.crt; do
  p L2 sha "$f" "$(sudo -n sha256sum "$f" | cut -c1-16)"; done
p L2 manifests "$(ls /etc/kubernetes/manifests 2>/dev/null | paste -sd, -)"
EOF
}

collect_api() {
  node $CP 'bash -s' <<'EOF'
k() { kubectl "$@" 2>/dev/null; }
E="--cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key"
echo "L3 etcd-healthy-members $(k -n kube-system exec etcd-vm-k8s-cka-control-1 -- etcdctl $E endpoint health --cluster 2>&1 | grep -c 'is healthy')"
echo "L3 etcd-members $(k -n kube-system exec etcd-vm-k8s-cka-control-1 -- etcdctl $E member list | grep -c started)"
k get tigerastatus --no-headers | awk '{print "L3 tigerastatus", $1, "available="$2, "degraded="$4}'
echo "L3 apiservices-not-available $(k get apiservices --no-headers | awk '$3!="True"' | wc -l)"
k get nodes --no-headers -o custom-columns=N:.metadata.name,V:.status.nodeInfo.kubeletVersion,U:.spec.unschedulable,T:.spec.taints[*].effect \
  | awk '{print "L4 node", $1, $2, "unschedulable="$3, "taints="$4}'
k get nodes --no-headers | awk '{print "L4 node-status", $1, $2}'
echo "L4 namespaces $(k get ns --no-headers -o custom-columns=:metadata.name | sort | paste -sd, -)"
k get deploy,ds,sts -A --no-headers -o custom-columns=NS:.metadata.namespace,K:.kind,N:.metadata.name,R:.spec.replicas,I:.spec.template.spec.containers[*].image \
  | awk '{print "L4 workload", $0}'
k get pods -A --no-headers | awk '{n[$1]++; split($3,r,"/"); if (($4!="Running" && $4!="Completed") || ($4=="Running" && r[1]!=r[2])) bad++}
  END {for (x in n) print "L4 pods", x, n[x]; print "L4 pods-not-ready", bad+0}'
k get svc -A --no-headers -o custom-columns=NS:.metadata.namespace,N:.metadata.name,T:.spec.type,P:.spec.ports[*].port | awk '{print "L4 service", $0}'
for r in serviceaccounts roles rolebindings configmaps secrets networkpolicies resourcequotas limitranges \
         persistentvolumeclaims ingresses gateways.gateway.networking.k8s.io httproutes.gateway.networking.k8s.io \
         poddisruptionbudgets horizontalpodautoscalers jobs cronjobs; do
  k get $r -A --no-headers -o custom-columns=NS:.metadata.namespace,N:.metadata.name | awk -v r=$r '{print "L4", r, $1"/"$2}'; done
for r in clusterroles clusterrolebindings customresourcedefinitions; do
  n=$(k get $r -o name | sort); echo "L4 $r count=$(grep -c . <<<"$n") names-sha=$(sha256sum <<<"$n" | cut -c1-12)"; done
for r in storageclasses persistentvolumes certificatesigningrequests priorityclasses ingressclasses gatewayclasses \
         validatingadmissionpolicies validatingwebhookconfigurations mutatingwebhookconfigurations; do
  echo "L4 $r $(k get $r -o name | sed 's|.*/||' | sort | paste -sd, -)"; done
echo "L4 default-storageclass $(k get sc --no-headers | awk '$2=="(default)"{print $1}' | paste -sd, -)"
for c in kubeadm-config kubelet-config kube-proxy coredns; do
  echo "L4 kube-system-configmap $c $(k -n kube-system get cm $c -o jsonpath='{.data}' | sha256sum | cut -c1-16)"; done
helm list -A --no-headers 2>/dev/null | awk '{print "L4 helm", $1, $2, "rev="$3, $(NF-2), $(NF-1)}'
EOF
}

collect() {
  for n in $NODES; do collect_node $n || echo "L1 unreachable 192.168.1.$n"; done
  collect_api
}

clean() {
  echo "── --clean: exercise leftovers ──"
  for ns in $(node $CP "kubectl get ns --no-headers -o custom-columns=:metadata.name" | grep -E '^x[0-9]+$'); do
    echo "  delete namespace $ns"; node $CP "kubectl delete ns $ns --timeout=120s" >/dev/null; done
  for n in $(node $CP "kubectl get nodes --no-headers" | awk '/SchedulingDisabled/{print $1}'); do
    echo "  uncordon $n"; node $CP "kubectl uncordon $n" >/dev/null; done
  for n in $NODES; do
    out=$(node $n 'shopt -s nullglob; for d in ~/answers ~/x[0-9][0-9]; do [ -e "$d" ] && rm -rf "$d" && echo "~/${d##*/}"; done' | paste -sd' ' -)
    [ -n "$out" ] && echo "  .$n: removed $out"; done
  echo
}

node $CP true 2>/dev/null || { echo "🛑 cannot ssh to 192.168.1.$CP"; exit 2; }

case $MODE in
  --record)
    LIVE=$(collect | sort)
    { echo "# lab_check.sh fingerprint — recorded $(date -u +%FT%TZ) from the live cluster"
      echo "# Regenerate ONLY straight after a reset to the snapshot it describes."
      echo "$LIVE"; } > "$FP"
    echo "recorded $(grep -vc '^#' "$FP") lines → $FP"; exit 0 ;;
  --clean) clean ;;
  "") ;;
  *) awk '/^# USAGE/,/FP=<file>/' "$0"; exit 2 ;;
esac

[ -f "$FP" ] || { echo "🛑 no fingerprint at $FP — run --record straight after a reset"; exit 2; }
BASE=$(grep -v '^#' "$FP" | sort)
LIVE=$(collect | sort)
GONE=$(comm -23 <(echo "$BASE") <(echo "$LIVE"))
NEW=$(comm -13 <(echo "$BASE") <(echo "$LIVE"))

if [ -z "$GONE$NEW" ]; then
  echo "✅ CLEAN — matches $(basename "$FP") ($(grep -c . <<<"$BASE") checks). Carry on."; exit 0; fi

for L in L1 L2 L3 L4; do
  g=$(grep "^$L " <<<"$GONE"); a=$(grep "^$L " <<<"$NEW")
  [ -z "$g$a" ] && continue
  case $L in L1) t="node OS";; L2) t="config files";; L3) t="control plane";; L4) t="API objects and exercise leftovers";; esac
  echo "── $L $t ──"
  [ -n "$g" ] && sed 's/^L[1-4] /  - expected: /' <<<"$g"
  [ -n "$a" ] && sed 's/^L[1-4] /  + found:    /' <<<"$a"
done
LOW=$(printf '%s\n%s\n' "$GONE" "$NEW" | grep -o '^L[1-4]' | sort | head -1)
echo
case $LOW in
  L4) echo "⚠️ DRIFT in API objects only — run that exercise's Reset line, or --clean, then check again." ;;
  *)  echo "🛑 DRIFT at $LOW — below the API. Hard reset: bash reset_cluster.sh --check, then --yes." ;;
esac
exit 1
