#!/usr/bin/env bash
#
# 3-k3s.sh — single-node K3s, pinned, on vm-k3s-rancher-1. Phase 20, Part 3.
# Runs ON THE VM as root:  sudo bash 3-k3s.sh [--check]
#
# PRODUCES: K3s $K3S_VERSION as one server node with the bundled Traefik, local-path and
#           metrics-server; the cluster-admin kubeconfig at /etc/rancher/k3s/k3s.yaml, mode 0600.
#
# 🚨 Rules this script enforces:
#   - The installer is downloaded to a file from the PINNED TAG and then run — never `curl | sh`.
#   - write-kubeconfig-mode 0600 (Phase 14 used 644 = world-readable cluster-admin).
#   - The kubeconfig stays on this VM. Never copy it to .195 (wrong-context risk vs the CKA cluster).
#   - K3s is NOT apt-managed, so refresh.sh can never upgrade it. Upgrades are a deliberate drill:
#     change K3S_VERSION and re-run (check Rancher's support matrix first: 2.15 = K3s 1.34-1.36).
#
# USAGE
#   sudo bash 3-k3s.sh --check     # report only
#   sudo bash 3-k3s.sh             # install / converge (idempotent; re-run must report 0 changes)
#
set -euo pipefail

# ───────────────────────────── CONFIGURE ME ─────────────────────────────
K3S_VERSION="v1.35.9+k3s1"
NODE_IP="192.168.1.187"
TLS_SANS=("rancher.gothamtechnologies.com" "192.168.1.187" "vm-k3s-rancher-1")
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

say "PRE-FLIGHT"
ip -4 -o addr show | grep -q " $NODE_IP/" && ok "this host owns $NODE_IP" || die "this host is not $NODE_IP"
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
    warn "ufw is ACTIVE — K3s needs 6443, 10250, 80/443 and the flannel VXLAN; check rules"
else
    ok "ufw inactive"
fi
command -v docker >/dev/null && warn "docker is installed — a second runtime is not wanted on a k8s node" || ok "no docker (K3s brings containerd)"

say "CONFIG /etc/rancher/k3s/config.yaml"
WANT=$(
    echo 'write-kubeconfig-mode: "0600"'
    echo "node-ip: $NODE_IP"
    echo 'tls-san:'
    for s in "${TLS_SANS[@]}"; do echo "  - \"$s\""; done
)
if [ -f /etc/rancher/k3s/config.yaml ] && [ "$(cat /etc/rancher/k3s/config.yaml)" = "$WANT" ]; then
    ok "config.yaml already as wanted"
    CONFIG_CHANGED=0
else
    CONFIG_CHANGED=1
    if [ "$CHECK_ONLY" -eq 1 ]; then
        warn "config.yaml differs or is missing (would write)"
    else
        install -d -m 0755 /etc/rancher/k3s
        printf '%s\n' "$WANT" > /etc/rancher/k3s/config.yaml
        chmod 0600 /etc/rancher/k3s/config.yaml
        did "wrote config.yaml"
    fi
fi

say "K3S $K3S_VERSION"
HAVE=$(k3s --version 2>/dev/null | awk 'NR==1{print $3}' || true)
if [ "$HAVE" = "$K3S_VERSION" ]; then
    ok "k3s $HAVE installed"
    if [ "$CONFIG_CHANGED" -eq 1 ] && [ "$CHECK_ONLY" -eq 0 ]; then
        systemctl restart k3s; did "restarted k3s to apply config.yaml"
    fi
else
    [ -n "$HAVE" ] && warn "k3s $HAVE installed, want $K3S_VERSION — this is an UPGRADE/DOWNGRADE"
    if [ "$CHECK_ONLY" -eq 1 ]; then
        warn "would install k3s $K3S_VERSION"
    else
        TAG_URL=${K3S_VERSION//+/%2B}
        INSTALLER="/root/k3s-install-${K3S_VERSION}.sh"
        curl -fsSL -o "$INSTALLER" "https://raw.githubusercontent.com/k3s-io/k3s/${TAG_URL}/install.sh"
        ok "installer saved: $INSTALLER ($(sha256sum "$INSTALLER" | cut -c1-16)…)"
        # install.sh verifies the binary against the release's sha256sum file itself.
        INSTALL_K3S_VERSION="$K3S_VERSION" sh "$INSTALLER" server
        did "installed k3s $K3S_VERSION"
    fi
fi

[ "$CHECK_ONLY" -eq 1 ] && ! command -v k3s >/dev/null && { printf '\n  --check: k3s not installed yet.\n\n'; exit 0; }

say "VERIFY"
for _ in $(seq 1 60); do
    kubectl get node vm-k3s-rancher-1 2>/dev/null | grep -q ' Ready ' && break
    sleep 5
done
kubectl get node -o wide
kubectl get node vm-k3s-rancher-1 | grep -q ' Ready ' && ok "node Ready" || die "node not Ready"

M=$(stat -c %a /etc/rancher/k3s/k3s.yaml)
[ "$M" = "600" ] && ok "kubeconfig mode 600" || die "kubeconfig mode is $M"

for _ in $(seq 1 60); do
    NOTREADY=$(kubectl get pods -n kube-system --no-headers 2>/dev/null \
        | awk '$3!="Running" && $3!="Completed"' | wc -l)
    [ "$NOTREADY" -eq 0 ] && kubectl get deploy -n kube-system traefik >/dev/null 2>&1 && break
    sleep 5
done
kubectl get pods -n kube-system
[ "$NOTREADY" -eq 0 ] && ok "all kube-system pods Running/Completed" || warn "$NOTREADY kube-system pods not Running"

kubectl get storageclass local-path -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}' \
    | grep -q true && ok "local-path is the default StorageClass" || warn "local-path is not default"

TV=$(kubectl get deploy -n kube-system traefik -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
ok "traefik image: ${TV:-?}"
for p in 80 443; do
    CODE=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 5 "$( [ $p = 443 ] && echo https || echo http )://$NODE_IP:$p/" || true)
    [ "$CODE" = "404" ] && ok "Traefik answers on :$p (404 = no route yet, expected)" || warn "port $p returned '$CODE'"
done

kubectl get svc -n default kubernetes -o jsonpath='{.spec.clusterIP}' | grep -q '^10\.43\.' \
    && ok "service CIDR 10.43.0.0/16 (no overlap with 192.168.1.0/24)" || warn "unexpected service CIDR"

printf '\n  %d change(s) made. Re-run to confirm it reports 0.\n' "$CHANGES"
printf '  NEXT: 4-rancher.sh (Helm, cert-manager, Rancher)\n\n'
