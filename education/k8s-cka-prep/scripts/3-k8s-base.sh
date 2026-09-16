#!/usr/bin/env bash
#
# 3-k8s-base.sh — make a personalized Ubuntu host KUBEADM-READY. Assigns NO role.
#
# ═════════════════════════════════════════════════════════════════════════════════════
# WHAT THIS PRODUCES — and what it deliberately does NOT
# ═════════════════════════════════════════════════════════════════════════════════════
# AFTER this script a host has: swap off, the kernel modules and sysctls Kubernetes
# needs, containerd running with the CRI plugin ENABLED and SystemdCgroup=true, and
# kubeadm/kubelet/kubectl installed at a pinned minor and apt-held.
#
# ⛔ IT CREATES NO CLUSTER. No kubeadm init. No kubeadm join. No CNI. No kubeconfig.
#
# ⭐ THE POINT, AND IT IS THE BEST THING TO UNDERSTAND EARLY: after this runs, every node
#    is IDENTICAL AND ROLE-LESS. A control plane and a worker differ by exactly ONE
#    command run later:
#         kubeadm init                                     -> first control plane
#         kubeadm join --control-plane --certificate-key .. -> another control plane
#         kubeadm join                                      -> worker
#    Hostnames like "…-control-1" are LABELS A HUMAN CHOSE. Nothing enforces them: run
#    init on the box called "worker-2" and it becomes a control plane while its name
#    becomes a lie every future reader will believe.
#
# ⭐ AND THE COROLLARY THAT PAYS OFF WHEN THINGS BREAK: the kubelet is IDENTICAL on both
#    roles. A control plane is just a node whose kubelet ALSO runs four static pods
#    (etcd, apiserver, controller-manager, scheduler) read straight off local disk from
#    /etc/kubernetes/manifests — not scheduled by the API server, not managed by it.
#    That is why a dead API server is repaired by editing a FILE and waiting, and why
#    kubectl cannot help you: the thing to fix is the thing that serves kubectl.
#
# ═════════════════════════════════════════════════════════════════════════════════════
# 🚨 THE ONE STEP EVERYONE GETS WRONG
#    The containerd.io package ships /etc/containerd/config.toml containing
#        disabled_plugins = ["cri"]
#    because Docker has no use for the CRI plugin. The kubelet talks to containerd
#    THROUGH the CRI. Leave that default and `kubeadm init` hangs waiting for a kubelet
#    that can never reach a runtime — and the error names the KUBELET, not containerd.
#    This script replaces the file with `containerd config default` and sets
#    SystemdCgroup = true.
#
#    ⛔ Related: do NOT install Docker on a Kubernetes node. It is what puts that config
#    there, and it leaves you with two image stores where `docker ps` and `crictl` show
#    different realities.
#
# USAGE
#   sudo bash 3-k8s-base.sh                     # pinned default below
#   sudo bash 3-k8s-base.sh --k8s-version 1.34
#   sudo bash 3-k8s-base.sh --check             # verify only, change nothing
#
set -euo pipefail

K8S_VERSION="1.35"   # ⚠️ match the environment you are targeting. The CKA exam tracked
                     #    v1.35 in Sep 2026 while upstream was v1.37 — RE-CHECK before an exam.
CHECK_ONLY=0
CHANGED=0

while [ $# -gt 0 ]; do
    case "$1" in
        --k8s-version) shift; K8S_VERSION="${1:?--k8s-version needs e.g. 1.35}" ;;
        --check)       CHECK_ONLY=1 ;;
        -h|--help)     sed -n '2,46p' "$0"; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done

say()  { printf '\n\033[1m━━━ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32mok\033[0m   %s\n' "$*"; }
did()  { printf '  \033[33mdid\033[0m  %s\n' "$*"; CHANGED=$((CHANGED+1)); }
warn() { printf '  \033[33mwarn\033[0m %s\n' "$*"; }
die()  { printf '  \033[31mFAIL\033[0m %s\n' "$*" >&2; exit 1; }
mutate(){ [ "$CHECK_ONLY" -eq 0 ]; }

[ "$(id -u)" -eq 0 ] || die "run with sudo"
[ -r /etc/os-release ] || die "no /etc/os-release"
# shellcheck disable=SC1091
. /etc/os-release
case "${ID:-}" in ubuntu|debian) ;; *) die "expected Ubuntu/Debian, found ${ID:-unknown}" ;; esac

say "PRE-FLIGHT"
ok "os: ${PRETTY_NAME:-$ID} ($(uname -r), $(dpkg --print-architecture))"
CPUS=$(nproc)
# kubeadm's own preflight FAILS below 2 CPUs on a control plane. Warn now, not later.
[ "$CPUS" -ge 2 ] && ok "cpus: $CPUS" || warn "cpus: $CPUS — kubeadm preflight FAILS below 2 on a control plane"
ok "memory: $(free -m | awk '/^Mem:/{print $2}') MB"
ok "target Kubernetes minor: v$K8S_VERSION"

say "1. SWAP OFF"
# The kubelet refuses to start with swap enabled unless explicitly configured otherwise.
if [ -n "$(swapon --show)" ]; then
    if mutate; then
        swapoff -a
        cp -n /etc/fstab /etc/fstab.bak-k8s 2>/dev/null || true
        sed -i -E 's@^([^#].*[[:space:]]swap[[:space:]])@#\1@' /etc/fstab
        did "swap off and commented out of /etc/fstab (survives reboot)"
    else warn "swap is ON"; fi
else ok "swap already off"; fi

say "2. KERNEL MODULES"
# overlay      : the snapshotter's filesystem
# br_netfilter : lets iptables see bridged traffic. Without it, Service routing between
#                pods fails in ways that present as a CNI bug.
if [ -f /etc/modules-load.d/k8s.conf ]; then ok "/etc/modules-load.d/k8s.conf present"
elif mutate; then printf 'overlay\nbr_netfilter\n' > /etc/modules-load.d/k8s.conf; did "wrote /etc/modules-load.d/k8s.conf"
else warn "/etc/modules-load.d/k8s.conf missing"; fi
for m in overlay br_netfilter; do
    if lsmod | grep -q "^$m"; then ok "loaded: $m"
    elif mutate; then modprobe "$m"; did "loaded $m"
    else warn "NOT loaded: $m"; fi
done

say "3. SYSCTLS"
if [ -f /etc/sysctl.d/k8s.conf ]; then ok "/etc/sysctl.d/k8s.conf present"
elif mutate; then
    cat > /etc/sysctl.d/k8s.conf <<'EOF'
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    sysctl --system >/dev/null; did "wrote /etc/sysctl.d/k8s.conf and reloaded"
else warn "/etc/sysctl.d/k8s.conf missing"; fi
for k in net.ipv4.ip_forward net.bridge.bridge-nf-call-iptables; do
    v=$(sysctl -n "$k" 2>/dev/null || echo missing)
    [ "$v" = "1" ] && ok "$k = 1" || warn "$k = $v (want 1)"
done

say "4. CONTAINERD (see the header — this is the step that bites)"
if ! command -v containerd >/dev/null 2>&1; then
    if mutate; then
        apt-get install -y -qq ca-certificates curl gnupg
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
          | gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
          > /etc/apt/sources.list.d/docker.list
        apt-get update -qq
        # containerd.io ONLY — no docker-ce, no docker-ce-cli. See the header.
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq containerd.io
        did "installed containerd.io (deliberately WITHOUT Docker)"
    else warn "containerd NOT installed"; fi
else ok "containerd present: $(containerd --version 2>/dev/null | awk '{print $3}')"; fi

if command -v containerd >/dev/null 2>&1; then
    NEEDS=0
    grep -qs 'disabled_plugins.*cri' /etc/containerd/config.toml && NEEDS=1
    grep -qs 'SystemdCgroup = true'  /etc/containerd/config.toml || NEEDS=1
    if [ "$NEEDS" -eq 1 ]; then
        if mutate; then
            cp -n /etc/containerd/config.toml /etc/containerd/config.toml.orig-packaged 2>/dev/null || true
            containerd config default > /etc/containerd/config.toml
            # The cgroup driver MUST match the kubelet's, which is systemd on Ubuntu. A
            # mismatch does not fail at install time — it fails later, intermittently,
            # under load, which is far harder to diagnose than an outright refusal.
            sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
            systemctl restart containerd
            did "regenerated containerd config (CRI enabled, SystemdCgroup=true)"
        else warn "containerd config is NOT kubelet-ready"; fi
    else ok "containerd config already kubelet-ready"; fi
    if mutate && ! systemctl is-enabled --quiet containerd; then systemctl enable --quiet containerd; did "enabled containerd"; fi
    systemctl is-active --quiet containerd && ok "containerd running" || warn "containerd NOT running"
    # ⭐ Probe the CAPABILITY, not the config file: the CRI plugin must report ok.
    if command -v ctr >/dev/null 2>&1; then
        ctr plugin ls 2>/dev/null | awk '$1=="io.containerd.grpc.v1" && $2=="cri"{print $NF}' | grep -qx ok \
            && ok "CRI plugin reports ok (capability, not config)" \
            || warn "CRI plugin is NOT ok — kubeadm init will hang"
    fi
fi

say "5. KUBEADM / KUBELET / KUBECTL (v$K8S_VERSION, held)"
if ! command -v kubeadm >/dev/null 2>&1; then
    if mutate; then
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/Release.key" \
          | gpg --batch --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        chmod a+r /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/ /" \
          > /etc/apt/sources.list.d/kubernetes.list
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq kubelet kubeadm kubectl
        # 🚨 HOLD them. An unplanned kubelet minor bump is a cluster incident. This lab has
        # already been bitten once by an unattended Docker upgrade silently breaking CI a
        # week later, where nothing connected the failure to the upgrade.
        apt-mark hold kubelet kubeadm kubectl >/dev/null
        systemctl enable --quiet kubelet
        did "installed and held kubelet/kubeadm/kubectl v$K8S_VERSION; kubelet enabled"
    else warn "kubeadm NOT installed"; fi
else
    ok "kubeadm present: $(kubeadm version -o short 2>/dev/null || echo '?')"
    apt-mark showhold 2>/dev/null | grep -q kubeadm && ok "packages held" \
        || warn "packages NOT held — run: apt-mark hold kubelet kubeadm kubectl"
fi

say "6. EXAM-PARITY TOOLING"
# The CKA environment provides kubectl with a `k` alias and bash completion ALREADY set
# up, plus yq, curl, wget and man. It does NOT list jq. Do not install jq here.
if command -v yq >/dev/null 2>&1; then ok "yq present: $(yq --version 2>/dev/null | awk '{print $NF}')"
elif mutate; then
    curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_$(dpkg --print-architecture)" \
      -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq
    did "installed yq $(/usr/local/bin/yq --version 2>/dev/null | awk '{print $NF}')"
else warn "yq NOT installed"; fi
if [ -f /etc/profile.d/kubectl-alias.sh ]; then ok "k alias profile present"
elif mutate; then
    cat > /etc/profile.d/kubectl-alias.sh <<'EOF'
# Match the CKA exam environment, which ships `k` and completion pre-configured.
alias k=kubectl
if [ -n "${BASH_VERSION:-}" ] && command -v kubectl >/dev/null 2>&1; then
    source <(kubectl completion bash)
    complete -o default -F __start_kubectl k
fi
EOF
    did "wrote /etc/profile.d/kubectl-alias.sh"
else warn "k alias profile missing"; fi

# ═════════════════════════════════════════════════════════════════════════════════════
say "SUMMARY"
# 🚨 Report honestly. `systemctl is-active` PRINTS a value AND exits non-zero, so a naive
# `cmd || echo absent` prints BOTH. And claiming "CRI enabled: yes" when containerd is not
# installed is a false green — the config file simply is not there.
val() { local out; out="$("$@" 2>/dev/null)" || true; [ -n "$out" ] && printf '%s' "$out" || printf '%s' '?'; }
if [ -f /etc/containerd/config.toml ]; then
    grep -qs 'disabled_plugins.*cri' /etc/containerd/config.toml && CRI='NO — kubeadm init WILL HANG' || CRI='yes'
    grep -qs 'SystemdCgroup = true'  /etc/containerd/config.toml && SCG='true' || SCG='NOT true'
else CRI='n/a — no containerd config yet'; SCG='n/a — no containerd config yet'; fi
printf '  host            : %s (%s)\n' "$(hostname)" "$(ip -o -4 addr show | awk '!/ lo /{print $4}' | paste -sd,)"
printf '  swap            : %s\n' "$([ -z "$(swapon --show)" ] && echo off || echo 'ON — kubelet will refuse')"
printf '  containerd      : %s\n' "$(val systemctl is-active containerd)"
printf '  CRI enabled     : %s\n' "$CRI"
printf '  SystemdCgroup   : %s\n' "$SCG"
printf '  kubeadm         : %s\n' "$(val kubeadm version -o short)"
printf '  kubelet         : %s / %s\n' "$(val systemctl is-active kubelet)" "$(val systemctl is-enabled kubelet)"
printf '  held packages   : %s\n' "$(apt-mark showhold 2>/dev/null | paste -sd, || echo none)"
printf '  yq              : %s\n' "$(yq --version 2>/dev/null | awk '{print $NF}' || echo absent)"
printf '  ROLE            : none — identical to every other node\n'
if [ "$CHECK_ONLY" -eq 1 ]; then printf '\n  --check: nothing was changed.\n'
else printf '\n  %d change(s) made. Re-run to confirm it reports 0 — that is the idempotency test.\n' "$CHANGED"; fi
cat <<'EOF'

  EXPECTED: kubelet is INACTIVE. It has nothing to do until a cluster exists, and that
  is not a fault. It will start when kubeadm init or kubeadm join runs.

  NEXT — and the order is NOT optional:
    1. A control-plane endpoint (load balancer / kube-vip / DNS) must ANSWER FIRST.
    2. kubeadm init --control-plane-endpoint <that endpoint> --upload-certs
       ⚠️ Set the endpoint AT INIT. It fixes the apiserver certificate's SANs, and
          without it additional control planes can NEVER join.
       ⚠️ The --upload-certs certificate key EXPIRES AFTER 2 HOURS.
          Regenerate: kubeadm init phase upload-certs --upload-certs
       ⚠️ The join token expires after 24 HOURS: kubeadm token create
    3. Install a CNI. Nodes stay NotReady and CoreDNS stays Pending until you do —
       Kubernetes ships no pod network.
EOF
