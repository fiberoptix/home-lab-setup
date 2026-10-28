#!/usr/bin/env bash
#
# 5-monitoring.sh — rancher-monitoring (Prometheus, Alertmanager, Grafana) on vm-k3s-rancher-1.
# Phase 20, Part 5. Runs ON THE VM as root, with monitoring-values.yaml beside it:
#   sudo bash 5-monitoring.sh [--check]
#
# PRODUCES: rancher-monitoring-crd + rancher-monitoring $MON_VERSION in cattle-monitoring-system,
#           Prometheus on a 20 Gi local-path PVC with retention 7d / 15GiB. Shows up in Rancher as
#           an installed app and lights up the Monitoring menu of the local cluster.
#
# 🚨 The chart version is tied to the Rancher minor (110.x = Rancher 2.15). A Rancher upgrade to
#    2.16 needs the matching 111.x chart — check catalog.cattle.io/rancher-version first.
#
set -euo pipefail

# ───────────────────────────── CONFIGURE ME ─────────────────────────────
MON_VERSION="110.0.2+up80.9.1-rancher.22"
NS=cattle-monitoring-system
# ────────────────────────────────────────────────────────────────────────

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1
[ "${1:-}" = "--help" ] && { sed -n '2,13p' "$0"; exit 0; }

say()  { printf '\n\033[1m━━━ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32mok\033[0m   %s\n' "$*"; }
did()  { printf '  \033[33mdid\033[0m  %s\n' "$*"; CHANGES=$((CHANGES+1)); }
warn() { printf '  \033[33mwarn\033[0m %s\n' "$*"; }
die()  { printf '  \033[31mFAIL\033[0m %s\n' "$*" >&2; exit 1; }
CHANGES=0

[ "$(id -u)" -eq 0 ] || die "run as root (sudo bash $0)"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
HERE=$(cd "$(dirname "$0")" && pwd)
VALUES="$HERE/monitoring-values.yaml"
[ -f "$VALUES" ] || die "missing $VALUES"
command -v helm >/dev/null || die "helm missing — run 4-rancher.sh first"

release_version() {
    helm list -n "$2" --filter "^$1\$" --deployed -o json 2>/dev/null \
        | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d[0]["chart"][len(sys.argv[1])+1:] if d else "")' "$1"
}

say "CHART REPOSITORY"
if helm repo list -o json 2>/dev/null | python3 -c "import json,sys; sys.exit(0 if any(r['name']=='rancher-charts' and r['url']=='https://charts.rancher.io' for r in json.load(sys.stdin)) else 1)"; then
    ok "repo rancher-charts"
elif [ "$CHECK_ONLY" -eq 1 ]; then
    warn "repo rancher-charts missing (would add)"
else
    helm repo add rancher-charts https://charts.rancher.io --force-update >/dev/null; did "added repo rancher-charts"
fi
[ "$CHECK_ONLY" -eq 0 ] && helm repo update rancher-charts >/dev/null && ok "repo index refreshed"

for REL in rancher-monitoring-crd rancher-monitoring; do
    say "$REL $MON_VERSION"
    HAVE=$(release_version "$REL" "$NS")
    if [ "$HAVE" = "$MON_VERSION" ]; then
        ok "$REL $HAVE deployed"
    elif [ "$CHECK_ONLY" -eq 1 ]; then
        warn "$REL is '${HAVE:-absent}' (would install $MON_VERSION)"
    else
        ARGS=()
        [ "$REL" = rancher-monitoring ] && ARGS=(-f "$VALUES")
        helm upgrade --install "$REL" "rancher-charts/$REL" --version "$MON_VERSION" \
            -n "$NS" --create-namespace "${ARGS[@]}" --wait --timeout 15m
        did "$REL $MON_VERSION"
    fi
done

[ "$CHECK_ONLY" -eq 1 ] && ! kubectl get ns "$NS" >/dev/null 2>&1 && { printf '\n  --check: not installed yet.\n\n'; exit 0; }

say "VERIFY"
for _ in $(seq 1 60); do
    NR=$(kubectl get pods -n "$NS" --no-headers 2>/dev/null | awk '$3!="Running" && $3!="Completed"' | wc -l)
    [ "$NR" -eq 0 ] && kubectl get pod -n "$NS" prometheus-rancher-monitoring-prometheus-0 >/dev/null 2>&1 && break
    sleep 5
done
kubectl get pods -n "$NS" --no-headers | awk '{print "       "$1, $2, $3}'
[ "$NR" -eq 0 ] && ok "all $NS pods Running" || warn "$NR pods not Running"

kubectl get pvc -n "$NS" --no-headers | awk '{print "       pvc "$1, $2, $4, $6}'
R=$(kubectl get prometheus -n "$NS" -o jsonpath='{.items[0].spec.retention} {.items[0].spec.retentionSize}')
[ "$R" = "7d 15GiB" ] && ok "Prometheus retention: $R" || warn "Prometheus retention is '$R', want '7d 15GiB'"

# Targets that are down — the first place a K3s-vs-kubeadm scrape difference shows up.
DOWN=$(kubectl exec -n "$NS" prometheus-rancher-monitoring-prometheus-0 -c prometheus -- \
    wget -qO- 'http://localhost:9090/api/v1/targets?state=active' 2>/dev/null \
    | python3 -c 'import json,sys
t=json.load(sys.stdin)["data"]["activeTargets"]
print(len(t), "targets;", ", ".join(sorted({x["labels"].get("job","?") for x in t if x["health"]!="up"})) or "none down")' || echo "query failed")
ok "Prometheus targets: $DOWN"

printf '\n  %d change(s) made. Re-run to confirm it reports 0.\n' "$CHANGES"
printf '  NEXT: D5 — measure the Prometheus PVC after 24 h:\n'
printf '        kubectl exec -n %s prometheus-rancher-monitoring-prometheus-0 -c prometheus -- du -sh /prometheus\n\n' "$NS"
