#!/usr/bin/env bash
#
# 4-rancher.sh — Helm CLI, cert-manager and Rancher Manager on vm-k3s-rancher-1. Phase 20, Part 4.
# Runs ON THE VM as root, with rancher-values.yaml beside it:
#   sudo bash 4-rancher.sh [--check]
#
# PRODUCES: Helm $HELM_VERSION (tarball, sha256-verified), cert-manager $CM_VERSION, Rancher
#           $RANCHER_VERSION (1 replica, Rancher-generated CA) at https://$RANCHER_HOST, first-login
#           settings applied, admin password changed away from the bootstrap value.
#
# SECRETS: /root/rancher-secrets.env (mode 0600, root-only, NEVER in git) supplies
#            BOOTSTRAP_PASSWORD=...   needed only for the first install
#            ADMIN_PASSWORD=...       the real admin password (PASSWORDS.md)
#          Delete the file once Rancher is up; re-runs on an installed Rancher do not need it.
#
# 🚨 Helm v3, NOT v4: Rancher's docs say "The installation instructions assume you are using
#    Helm 3" and the version-requirements page only defines a v3 rule.
# 🚨 Upgrades: change RANCHER_VERSION and re-run with the SAME rancher-values.yaml.
#
set -euo pipefail

# ───────────────────────────── CONFIGURE ME ─────────────────────────────
HELM_VERSION="v3.22.1"
CM_VERSION="v1.21.3"
RANCHER_VERSION="2.15.2"
RANCHER_REPO_URL="https://releases.rancher.com/server-charts/latest"
RANCHER_HOST="rancher.gothamtechnologies.com"
SECRETS=/root/rancher-secrets.env
# ────────────────────────────────────────────────────────────────────────

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1
[ "${1:-}" = "--help" ] && { sed -n '2,19p' "$0"; exit 0; }

say()  { printf '\n\033[1m━━━ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32mok\033[0m   %s\n' "$*"; }
did()  { printf '  \033[33mdid\033[0m  %s\n' "$*"; CHANGES=$((CHANGES+1)); }
warn() { printf '  \033[33mwarn\033[0m %s\n' "$*"; }
die()  { printf '  \033[31mFAIL\033[0m %s\n' "$*" >&2; exit 1; }
CHANGES=0

[ "$(id -u)" -eq 0 ] || die "run as root (sudo bash $0)"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
HERE=$(cd "$(dirname "$0")" && pwd)
VALUES="$HERE/rancher-values.yaml"
[ -f "$VALUES" ] || die "missing $VALUES"
kubectl get node >/dev/null 2>&1 || die "K3s is not answering — run 3-k3s.sh first"

if [ -f "$SECRETS" ]; then
    [ "$(stat -c %a "$SECRETS")" = "600" ] || die "$SECRETS must be mode 600"
    # shellcheck disable=SC1090
    . "$SECRETS"
fi

# release_version <release> <namespace> -> chart version, or empty if not deployed
release_version() {
    helm list -n "$2" --filter "^$1\$" --deployed -o json 2>/dev/null \
        | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d[0]["chart"].rsplit("-",1)[1] if d else "")'
}

say "HELM $HELM_VERSION"
HAVE=$(helm version --short 2>/dev/null | cut -d+ -f1 || true)
if [ "$HAVE" = "$HELM_VERSION" ]; then
    ok "helm $HAVE"
elif [ "$CHECK_ONLY" -eq 1 ]; then
    warn "helm is '${HAVE:-absent}' (would install $HELM_VERSION)"
else
    T=$(mktemp -d)
    curl -fsSL -o "$T/helm.tgz" "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"
    curl -fsSL -o "$T/helm.sha" "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz.sha256sum"
    [ "$(sha256sum "$T/helm.tgz" | cut -d' ' -f1)" = "$(cut -d' ' -f1 "$T/helm.sha")" ] \
        || die "helm tarball sha256 mismatch"
    ok "helm tarball sha256 verified"
    tar -xzf "$T/helm.tgz" -C "$T"
    install -m 0755 "$T/linux-amd64/helm" /usr/local/bin/helm
    rm -rf "$T"
    did "installed helm $(helm version --short)"
fi
command -v helm >/dev/null || { printf '\n  --check: helm absent, stopping.\n\n'; exit 0; }

say "CHART REPOSITORIES"
add_repo() {
    if helm repo list -o json 2>/dev/null | python3 -c "import json,sys; sys.exit(0 if any(r['name']=='$1' and r['url']=='$2' for r in json.load(sys.stdin)) else 1)"; then
        ok "repo $1"
    elif [ "$CHECK_ONLY" -eq 1 ]; then
        warn "repo $1 missing (would add)"
    else
        helm repo add "$1" "$2" --force-update >/dev/null; did "added repo $1 -> $2"
    fi
}
add_repo jetstack https://charts.jetstack.io
add_repo rancher-latest "$RANCHER_REPO_URL"
[ "$CHECK_ONLY" -eq 0 ] && helm repo update >/dev/null && ok "repo index refreshed"

say "CERT-MANAGER $CM_VERSION"
HAVE=$(release_version cert-manager cert-manager)
if [ "$HAVE" = "$CM_VERSION" ]; then
    ok "cert-manager $HAVE deployed"
elif [ "$CHECK_ONLY" -eq 1 ]; then
    warn "cert-manager is '${HAVE:-absent}' (would install $CM_VERSION)"
else
    helm upgrade --install cert-manager jetstack/cert-manager --version "$CM_VERSION" \
        -n cert-manager --create-namespace --set crds.enabled=true --wait --timeout 10m
    did "cert-manager $CM_VERSION"
fi
kubectl get pods -n cert-manager --no-headers 2>/dev/null | awk '{print "       "$1, $3}'

say "RANCHER $RANCHER_VERSION"
HAVE=$(release_version rancher cattle-system)
if [ "$HAVE" = "$RANCHER_VERSION" ]; then
    ok "rancher $HAVE deployed"
elif [ "$CHECK_ONLY" -eq 1 ]; then
    warn "rancher is '${HAVE:-absent}' (would install/upgrade to $RANCHER_VERSION)"
else
    EXTRA=()
    if [ -z "$HAVE" ]; then
        [ -n "${BOOTSTRAP_PASSWORD:-}" ] || die "first install needs BOOTSTRAP_PASSWORD in $SECRETS"
        # A values file, not --set, so the password never appears in the process list.
        BS=$(mktemp); chmod 600 "$BS"
        printf 'bootstrapPassword: "%s"\n' "$BOOTSTRAP_PASSWORD" > "$BS"
        EXTRA=(-f "$BS")
    fi
    helm upgrade --install rancher rancher-latest/rancher --version "$RANCHER_VERSION" \
        -n cattle-system --create-namespace -f "$VALUES" "${EXTRA[@]}"
    [ -n "${BS:-}" ] && rm -f "$BS"
    did "rancher $RANCHER_VERSION (helm)"
fi

[ "$CHECK_ONLY" -eq 1 ] && ! kubectl get deploy -n cattle-system rancher >/dev/null 2>&1 \
    && { printf '\n  --check: rancher not installed yet.\n\n'; exit 0; }

say "WAIT FOR RANCHER"
kubectl -n cattle-system rollout status deploy/rancher --timeout=15m
ok "deploy/rancher rolled out ($(kubectl -n cattle-system get deploy rancher -o jsonpath='{.status.availableReplicas}') available)"
for _ in $(seq 1 60); do
    [ "$(curl -sk --max-time 5 "https://$RANCHER_HOST/ping")" = "pong" ] && break
    sleep 5
done
[ "$(curl -sk --max-time 5 "https://$RANCHER_HOST/ping")" = "pong" ] && ok "https://$RANCHER_HOST/ping -> pong" \
    || die "https://$RANCHER_HOST/ping does not answer pong"

say "FIRST-LOGIN SETTINGS"
set_setting() {
    local cur
    kubectl get settings.management.cattle.io "$1" >/dev/null 2>&1 \
        || { warn "setting $1 does not exist in this Rancher version — skipped"; return 0; }
    cur=$(kubectl get settings.management.cattle.io "$1" -o jsonpath='{.value}' 2>/dev/null || true)
    if [ "$cur" = "$2" ] || { [ "$1" = eula-agreed ] && [ -n "$cur" ]; }; then
        ok "setting $1 = ${cur}"
    elif [ "$CHECK_ONLY" -eq 1 ]; then
        warn "setting $1 = '${cur}' (would set '$2')"
    else
        kubectl patch settings.management.cattle.io "$1" --type merge -p "{\"value\":\"$2\"}" >/dev/null
        did "setting $1 -> $2"
    fi
}
for _ in $(seq 1 60); do kubectl get settings.management.cattle.io server-url >/dev/null 2>&1 && break; sleep 5; done
set_setting server-url "https://$RANCHER_HOST"
set_setting eula-agreed "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
set_setting first-login "false"

say "ADMIN PASSWORD"
login() {  # prints a token or nothing
    curl -sk --max-time 10 "https://$RANCHER_HOST/v3-public/localProviders/local?action=login" \
        -H 'content-type: application/json' \
        -d "$(python3 -c 'import json,sys; print(json.dumps({"username":"admin","password":sys.argv[1],"responseType":"json"}))' "$1")" \
        | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("token",""))
except Exception: print("")'
}
if [ -z "${ADMIN_PASSWORD:-}" ]; then
    warn "ADMIN_PASSWORD not in $SECRETS — skipping the password check"
elif [ -n "$(login "$ADMIN_PASSWORD")" ]; then
    ok "admin logs in with ADMIN_PASSWORD"
elif [ "$CHECK_ONLY" -eq 1 ]; then
    warn "admin does not log in with ADMIN_PASSWORD (would change it)"
else
    TOKEN=$(login "${BOOTSTRAP_PASSWORD:-}")
    [ -n "$TOKEN" ] || die "neither ADMIN_PASSWORD nor BOOTSTRAP_PASSWORD logs in as admin"
    BODY=$(python3 -c 'import json,sys; print(json.dumps({"currentPassword":sys.argv[1],"newPassword":sys.argv[2]}))' \
        "$BOOTSTRAP_PASSWORD" "$ADMIN_PASSWORD")
    CODE=$(curl -sk -o /tmp/rancher-pw.out -w '%{http_code}' --max-time 10 \
        "https://$RANCHER_HOST/v3/users?action=changepassword" \
        -H "Authorization: Bearer $TOKEN" -H 'content-type: application/json' -d "$BODY")
    [ "$CODE" = "200" ] || { cat /tmp/rancher-pw.out; rm -f /tmp/rancher-pw.out; die "changepassword returned $CODE"; }
    rm -f /tmp/rancher-pw.out
    [ -n "$(login "$ADMIN_PASSWORD")" ] && did "admin password changed (bootstrap value no longer works)" \
        || die "password change reported 200 but ADMIN_PASSWORD does not log in"
fi

say "VERIFY THE local CLUSTER"
for _ in $(seq 1 60); do
    R=$(kubectl get clusters.management.cattle.io local \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
    [ "$R" = "True" ] && break
    sleep 10
done
[ "$R" = "True" ] && ok "management cluster 'local' Ready=True (Active in the UI)" || warn "cluster 'local' Ready='$R'"
kubectl get pods -A --no-headers | awk '$4!="Running" && $4!="Completed"{print "       not running: "$1"/"$2" "$4}'
kubectl get pods -A --no-headers | awk '{print $1}' | sort | uniq -c | awk '{print "       "$2": "$1" pods"}'

printf '\n  %d change(s) made. Re-run to confirm it reports 0.\n' "$CHANGES"
printf '  NEXT: delete %s once PASSWORDS.md has both values; snapshot r02-rancher-up; 5-monitoring.sh\n\n' "$SECRETS"
