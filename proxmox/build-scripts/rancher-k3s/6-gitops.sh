#!/usr/bin/env bash
#
# 6-gitops.sh — wire vm-k3s-rancher-1 to GitLab production/rancher-k3s. Phase 20, Part 6.
# Runs ON THE VM as root, with fleet-gitrepo.yaml and push-rbac.yaml beside it:
#   sudo bash 6-gitops.sh [--check]
#   sudo bash 6-gitops.sh --push-kubeconfig     # (re)write /root/push-kubeconfig.yaml, 1-year token
#
# PRODUCES:
#   - /etc/rancher/k3s/registries.yaml (0600): HTTP endpoint + read_registry deploy token for
#     gitlab.gothamtechnologies.com:5050. K3s does NOT read Docker's daemon.json; without this the
#     first deploy fails as ImagePullBackOff with an error that reads like auth or DNS.
#   - Secret fleet-local/gitlab-rancher-k3s-read (read_repository deploy token) + GitRepo hello-lab.
#   - Namespace hello-lab-push + ServiceAccount/Role/RoleBinding for the push-model CI job.
#
# SECRETS: /root/phase20-gitops.env (0600, root-only, NEVER in git):
#            PULL_USER= PULL_TOKEN= GIT_USER= GIT_TOKEN=
#          Needed only when registries.yaml or the git Secret must be (re)written. Values: PASSWORDS.md.
#
set -euo pipefail

REGISTRY="gitlab.gothamtechnologies.com:5050"
SECRETS=/root/phase20-gitops.env
API_SERVER="https://192.168.1.187:6443"

MODE=apply
[ "${1:-}" = "--check" ] && MODE=check
[ "${1:-}" = "--push-kubeconfig" ] && MODE=kubeconfig
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

if [ -f "$SECRETS" ]; then
    [ "$(stat -c %a "$SECRETS")" = "600" ] || die "$SECRETS must be mode 600"
    # shellcheck disable=SC1090
    . "$SECRETS"
fi

# kubectl apply that counts real changes: "unchanged" is not a change.
kapply() {
    local out
    if [ "$MODE" = check ]; then
        out=$(kubectl diff -f - >/dev/null 2>&1 && echo same || echo differs)
        [ "$out" = same ] && ok "$1 in sync" || warn "$1 differs (would apply)"
        return 0
    fi
    out=$(kubectl apply -f - 2>&1) || { echo "$out"; die "apply $1 failed"; }
    if echo "$out" | grep -qvE ' unchanged$'; then did "$1: $(echo "$out" | grep -vE ' unchanged$' | tr '\n' ';')"; else ok "$1 unchanged"; fi
}

if [ "$MODE" = kubeconfig ]; then
    say "PUSH-MODEL KUBECONFIG"
    kubectl get sa -n hello-lab-push gitlab-deployer >/dev/null || die "run 6-gitops.sh first"
    TOKEN=$(kubectl create token gitlab-deployer -n hello-lab-push --duration=8760h)
    CA=$(base64 -w0 /var/lib/rancher/k3s/server/tls/server-ca.crt)
    umask 077
    cat > /root/push-kubeconfig.yaml <<EOF
apiVersion: v1
kind: Config
clusters:
  - name: vm-k3s-rancher-1
    cluster:
      server: $API_SERVER
      certificate-authority-data: $CA
users:
  - name: gitlab-deployer
    user:
      token: $TOKEN
contexts:
  - name: gitlab-deployer@vm-k3s-rancher-1
    context:
      cluster: vm-k3s-rancher-1
      user: gitlab-deployer
      namespace: hello-lab-push
current-context: gitlab-deployer@vm-k3s-rancher-1
EOF
    EXP=$(printf '%s' "$TOKEN" | python3 -c 'import base64,json,sys,datetime
p=sys.stdin.read().split(".")[1]; p+="="*(-len(p)%4)
print(datetime.datetime.fromtimestamp(json.loads(base64.urlsafe_b64decode(p))["exp"], datetime.UTC).date())' 2>/dev/null || echo "?")
    did "wrote /root/push-kubeconfig.yaml (0600), token expires $EXP"
    # can-i exits 1 on "no", so read its answer rather than its exit status (pipefail).
    cani() { KUBECONFIG=/root/push-kubeconfig.yaml kubectl auth can-i "$@" 2>/dev/null || true; }
    [ "$(cani create deployments -n hello-lab-push)" = yes ] \
        && ok "can create deployments in hello-lab-push" || die "SA cannot create deployments"
    [ "$(cani get secrets -n hello-lab-push)" = no ] \
        && ok "cannot read secrets in hello-lab-push" || warn "SA can read secrets"
    [ "$(cani create deployments -n hello-lab)" = no ] \
        && ok "cannot touch namespace hello-lab (Fleet's)" || warn "SA reaches beyond hello-lab-push"
    printf '\n  Upload it as the protected FILE variable PUSH_KUBECONFIG, then: shred -u /root/push-kubeconfig.yaml\n\n'
    exit 0
fi

say "REGISTRY ACCESS — /etc/rancher/k3s/registries.yaml"
REG=/etc/rancher/k3s/registries.yaml
if [ -n "${PULL_USER:-}" ] && [ -n "${PULL_TOKEN:-}" ]; then
    WANT=$(cat <<EOF
mirrors:
  "$REGISTRY":
    endpoint:
      - "http://$REGISTRY"
configs:
  "$REGISTRY":
    auth:
      username: "$PULL_USER"
      password: "$PULL_TOKEN"
EOF
)
    if [ -f "$REG" ] && [ "$(cat "$REG")" = "$WANT" ]; then
        ok "registries.yaml as wanted"
    elif [ "$MODE" = check ]; then
        warn "registries.yaml differs or is missing (would write + restart k3s)"
    else
        umask 077; printf '%s\n' "$WANT" > "$REG"; chmod 0600 "$REG"
        did "wrote registries.yaml"
        systemctl restart k3s
        for _ in $(seq 1 60); do kubectl get node 2>/dev/null | grep -q ' Ready ' && break; sleep 3; done
        did "restarted k3s (registries.yaml is read only at start)"
    fi
elif [ -f "$REG" ]; then
    ok "registries.yaml present (no secrets file — not compared)"
else
    die "registries.yaml missing and no PULL_USER/PULL_TOKEN in $SECRETS"
fi
[ "$(stat -c %a "$REG" 2>/dev/null)" = "600" ] && ok "registries.yaml mode 600" || warn "registries.yaml mode is not 600"

say "FLEET GIT CREDENTIAL + GitRepo"
if [ -n "${GIT_USER:-}" ] && [ -n "${GIT_TOKEN:-}" ]; then
    kubectl create secret generic gitlab-rancher-k3s-read -n fleet-local --type=kubernetes.io/basic-auth \
        --from-literal=username="$GIT_USER" --from-literal=password="$GIT_TOKEN" \
        --dry-run=client -o yaml | kapply "secret fleet-local/gitlab-rancher-k3s-read"
elif kubectl get secret -n fleet-local gitlab-rancher-k3s-read >/dev/null 2>&1; then
    ok "secret fleet-local/gitlab-rancher-k3s-read present (no secrets file — not compared)"
else
    die "git secret missing and no GIT_USER/GIT_TOKEN in $SECRETS"
fi
kapply "gitrepo fleet-local/hello-lab" < "$HERE/fleet-gitrepo.yaml"

say "PUSH-MODEL RBAC"
kapply "namespace/sa/role/rolebinding hello-lab-push" < "$HERE/push-rbac.yaml"

[ "$MODE" = check ] && { printf '\n  --check done.\n\n'; exit 0; }

say "VERIFY"
for _ in $(seq 1 40); do
    COMMIT=$(kubectl get gitrepo -n fleet-local hello-lab -o jsonpath='{.status.commit}' 2>/dev/null || true)
    READY=$(kubectl get gitrepo -n fleet-local hello-lab -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
    [ -n "$COMMIT" ] && [ "$READY" = "True" ] && break
    sleep 6
done
kubectl get gitrepo -n fleet-local hello-lab
[ -n "$COMMIT" ] && ok "Fleet fetched commit ${COMMIT:0:8}" || warn "Fleet has not fetched the repo — check: kubectl get gitrepo -n fleet-local hello-lab -o yaml"
[ "$READY" = "True" ] && ok "GitRepo Ready" || warn "GitRepo Ready='$READY'"
kubectl get bundles -n fleet-local 2>/dev/null | grep -E 'NAME|hello' || true
kubectl get pods -n hello-lab -o wide 2>/dev/null || true
OUT=$(curl -s --max-time 5 http://hello-rancher.gothamtechnologies.com/ || true)
[ -n "$OUT" ] && ok "http://hello-rancher.gothamtechnologies.com/ -> $OUT" || warn "hello-rancher does not answer yet"

printf '\n  %d change(s) made. Re-run to confirm it reports 0.\n' "$CHANGES"
printf '  NEXT: shred -u %s; --push-kubeconfig for the push-model job; snapshot r03-gitops-wired\n\n' "$SECRETS"
