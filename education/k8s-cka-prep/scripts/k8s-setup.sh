#!/usr/bin/env bash
#
# k8s-setup.sh — turn a fresh Ubuntu/Debian host into a kubeadm-ready Kubernetes node.
#
# SELF-CONTAINED ON PURPOSE. It calls no other script and needs no script server, so the
# same file works on a home-lab clone and on a VM someone else built and handed you.
#
# ⚠️ IT PREPARES A NODE. It does NOT create a cluster — no kubeadm init, no kubeadm join,
#    no CNI. Those are separate, deliberate steps.
#
# ─────────────────────────────────────────────────────────────────────────────────────
# DELIBERATE DUPLICATION — read this before "fixing" it
# ─────────────────────────────────────────────────────────────────────────────────────
# The hostname, sudo and Cockpit sections are COPIES of logic from this lab's build
# standard (www/ubuntu/setup_hostname.sh, setup_sudo.sh, setup_cockpit.sh). That is a
# knowing trade: this script's whole purpose is to work where those files do not exist.
# ⛔ It is NOT expected to track them, and it should NOT be turned back into a caller.
# If you change something here that also matters there, change it there too — "fix one
# tree, forget the other" is this project's most repeated mistake.
# setup_ssh.sh is deliberately NOT copied: SSH already works on a lab clone and on any
# host handed to you, so changing sshd here would add risk for no benefit.
#
# ─────────────────────────────────────────────────────────────────────────────────────
# 🚨 THE ONE STEP EVERYONE GETS WRONG
# ─────────────────────────────────────────────────────────────────────────────────────
# The containerd.io package ships /etc/containerd/config.toml containing
#   disabled_plugins = ["cri"]
# because Docker has no use for the CRI plugin. The kubelet talks to containerd THROUGH
# the CRI. Leave that default and `kubeadm init` hangs waiting for a kubelet that can
# never reach a runtime — and the error names the kubelet, not containerd. Step 4 below
# replaces the file with `containerd config default` and sets SystemdCgroup = true.
#
# ─────────────────────────────────────────────────────────────────────────────────────
# USAGE
#   sudo bash k8s-setup.sh                              # node prep only (safe default)
#   sudo bash k8s-setup.sh --hostname k8s-cp-1          # also set the hostname properly
#   sudo bash k8s-setup.sh --cockpit --sudo-nopasswd agamache   # lab conveniences
#   sudo bash k8s-setup.sh --k8s-version 1.34           # a different minor
#   sudo bash k8s-setup.sh --check                      # verify only, change nothing
#
# The lab extras are OPT-IN so the default is safe to run at work, where passwordless
# sudo may be against policy and Cockpit may not be wanted.
#
set -euo pipefail

K8S_VERSION="1.35"       # matches the CKA exam environment as of Sep 2026 — re-check before an exam
NEW_HOSTNAME=""
SUDO_USER_NOPASSWD=""
WANT_COCKPIT=0
CHECK_ONLY=0
CHANGED=0

while [ $# -gt 0 ]; do
    case "$1" in
        --hostname)        shift; NEW_HOSTNAME="${1:?--hostname needs a name}" ;;
        --sudo-nopasswd)   shift; SUDO_USER_NOPASSWD="${1:?--sudo-nopasswd needs a username}" ;;
        --cockpit)         WANT_COCKPIT=1 ;;
        --k8s-version)     shift; K8S_VERSION="${1:?--k8s-version needs e.g. 1.35}" ;;
        --check)           CHECK_ONLY=1 ;;
        -h|--help)         sed -n '2,45p' "$0"; exit 0 ;;
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

say "PRE-FLIGHT"
[ -r /etc/os-release ] || die "no /etc/os-release"
# shellcheck disable=SC1091
. /etc/os-release
[ -f /etc/fedora-release ] && die "this is the Ubuntu/Debian script; this host is Fedora"
case "${ID:-}" in ubuntu|debian) ok "os: ${PRETTY_NAME:-$ID} ($(uname -r), $(dpkg --print-architecture))" ;;
                  *) die "expected Ubuntu/Debian, found ${ID:-unknown}" ;; esac
CPUS=$(nproc)
[ "$CPUS" -ge 2 ] && ok "cpus: $CPUS" || warn "cpus: $CPUS — kubeadm preflight FAILS below 2 on a control plane"
ok "memory: $(free -m | awk '/^Mem:/{print $2}') MB"
ok "target Kubernetes minor: v$K8S_VERSION"

# ═════════════════════════════════════════════════════════════════════════════════════
# 1. HOSTNAME  (copied from www/ubuntu/setup_hostname.sh — see the duplication note)
# ═════════════════════════════════════════════════════════════════════════════════════
if [ -n "$NEW_HOSTNAME" ]; then
    say "1. HOSTNAME -> $NEW_HOSTNAME"
    printf '%s' "$NEW_HOSTNAME" | grep -qE \
      '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$' \
      || die "'$NEW_HOSTNAME' is not a valid hostname"

    if [ "$(hostnamectl --static 2>/dev/null)" = "$NEW_HOSTNAME" ]; then
        ok "static hostname already $NEW_HOSTNAME"
    elif mutate; then
        hostnamectl set-hostname "$NEW_HOSTNAME"; did "set static hostname"
    else warn "static hostname is $(hostnamectl --static)"; fi

    # hostnamectl NEVER touches /etc/hosts. A stale 127.0.1.1 line makes every later
    # sudo print "unable to resolve host", which sends people hunting the wrong fault.
    if grep -qE "^127\.0\.1\.1[[:space:]]+$NEW_HOSTNAME(\s|$)" /etc/hosts; then
        ok "/etc/hosts 127.0.1.1 line correct"
    elif mutate; then
        cp -n /etc/hosts /etc/hosts.bak-k8s-setup 2>/dev/null || true
        if grep -qE '^127\.0\.1\.1[[:space:]]' /etc/hosts; then
            sed -i -E "s/^127\.0\.1\.1[[:space:]].*/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts
        else
            printf '127.0.1.1\t%s\n' "$NEW_HOSTNAME" >> /etc/hosts
        fi
        did "fixed the 127.0.1.1 line in /etc/hosts"
    else warn "/etc/hosts 127.0.1.1 line does not match"; fi

    # cloud-init resets the hostname from the clone name at every boot unless pinned.
    # The symptom appears days later, long after anyone connects it to the build.
    if [ -d /etc/cloud ]; then
        if grep -qs '^preserve_hostname: true' /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg; then
            ok "cloud-init preserve_hostname pinned"
        elif mutate; then
            mkdir -p /etc/cloud/cloud.cfg.d
            echo 'preserve_hostname: true' > /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg
            did "pinned preserve_hostname for cloud-init"
        else warn "cloud-init present and preserve_hostname NOT pinned"; fi
    else
        ok "no cloud-init on this host — nothing to pin"
    fi
fi

# ═════════════════════════════════════════════════════════════════════════════════════
# 2. PASSWORDLESS SUDO  (opt-in; copied from www/ubuntu/setup_sudo.sh)
# ═════════════════════════════════════════════════════════════════════════════════════
if [ -n "$SUDO_USER_NOPASSWD" ]; then
    say "2. PASSWORDLESS SUDO for $SUDO_USER_NOPASSWD"
    id "$SUDO_USER_NOPASSWD" >/dev/null 2>&1 || die "user '$SUDO_USER_NOPASSWD' does not exist"
    F="/etc/sudoers.d/$SUDO_USER_NOPASSWD"
    if [ -f "$F" ] && grep -q 'NOPASSWD: ALL' "$F"; then
        ok "$F already grants NOPASSWD"
    elif mutate; then
        echo "$SUDO_USER_NOPASSWD ALL=(ALL) NOPASSWD: ALL" > "$F"
        chmod 440 "$F"
        # Validate before trusting it. A malformed sudoers file can lock out sudo
        # entirely, so it is removed again rather than left in place.
        if visudo -c -f "$F" >/dev/null 2>&1; then did "wrote $F (0440, syntax verified)"
        else rm -f "$F"; die "invalid sudoers syntax — removed $F, nothing changed"; fi
    else warn "$F absent or without NOPASSWD"; fi
fi

# ═════════════════════════════════════════════════════════════════════════════════════
# 3. COCKPIT  (opt-in; copied from www/ubuntu/setup_cockpit.sh, guard included)
# ═════════════════════════════════════════════════════════════════════════════════════
if [ "$WANT_COCKPIT" -eq 1 ]; then
    say "3. COCKPIT (web console on :9090)"
    if systemctl is-enabled --quiet cockpit.socket 2>/dev/null; then
        ok "cockpit.socket already enabled"
    else
        PKGS="cockpit-ws cockpit-bridge cockpit-system cockpit-storaged cockpit-packagekit"
        NM_ACTIVE=0; systemctl is-active --quiet NetworkManager 2>/dev/null && NM_ACTIVE=1
        [ "$NM_ACTIVE" -eq 1 ] && PKGS="$PKGS cockpit-networkmanager"
        # 🚨 Never install the `cockpit` METAPACKAGE. It Recommends cockpit-networkmanager,
        # which drags in network-manager, dnsmasq-base, ppp and wpasupplicant. On a host
        # running netplan + systemd-networkd that risks losing the network you administer
        # it over. Simulate first and refuse if NetworkManager appears unexpectedly.
        if mutate; then
            apt-get update -qq
            if [ "$NM_ACTIVE" -eq 0 ] && apt-get install -s $PKGS 2>/dev/null \
                 | awk '/^Inst/{print $2}' | grep -qx network-manager; then
                die "refusing: this install would pull network-manager onto a netplan host"
            fi
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $PKGS
            systemctl enable --now cockpit.socket >/dev/null 2>&1 || true
            did "installed Cockpit (explicit packages, not the metapackage)"
        else warn "cockpit not enabled"; fi
    fi
    # Cockpit logs in via PAM, so a key-only account cannot use it.
    if [ -n "$SUDO_USER_NOPASSWD" ]; then
        case "$(passwd -S "$SUDO_USER_NOPASSWD" 2>/dev/null | awk '{print $2}')" in
            P) ok "$SUDO_USER_NOPASSWD has a usable password (Cockpit login will work)" ;;
            *) warn "$SUDO_USER_NOPASSWD has NO usable password — Cockpit login will fail (PAM)" ;;
        esac
    fi
fi

# ═════════════════════════════════════════════════════════════════════════════════════
# 4. KUBERNETES NODE PREPARATION — upstream procedure, no lab dependencies
# ═════════════════════════════════════════════════════════════════════════════════════
say "4a. SWAP OFF"
# The kubelet refuses to start with swap enabled unless explicitly told to tolerate it.
if [ -n "$(swapon --show)" ]; then
    if mutate; then
        swapoff -a
        cp -n /etc/fstab /etc/fstab.bak-k8s-setup 2>/dev/null || true
        sed -i -E 's@^([^#].*[[:space:]]swap[[:space:]])@#\1@' /etc/fstab
        did "swap off and commented out of /etc/fstab"
    else warn "swap is ON"; fi
else
    ok "swap already off"
fi

say "4b. KERNEL MODULES (overlay, br_netfilter)"
# overlay      : the snapshotter's filesystem
# br_netfilter : lets iptables see bridged traffic. Without it, Service routing between
#                pods fails in ways that look like a CNI bug.
if [ -f /etc/modules-load.d/k8s.conf ]; then ok "/etc/modules-load.d/k8s.conf present"
elif mutate; then printf 'overlay\nbr_netfilter\n' > /etc/modules-load.d/k8s.conf; did "wrote /etc/modules-load.d/k8s.conf"
else warn "/etc/modules-load.d/k8s.conf missing"; fi
for m in overlay br_netfilter; do
    if lsmod | grep -q "^$m"; then ok "module loaded: $m"
    elif mutate; then modprobe "$m"; did "loaded module $m"
    else warn "module NOT loaded: $m"; fi
done

say "4c. SYSCTLS"
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

say "4d. CONTAINERD — configured FOR KUBERNETES (see the header warning)"
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
        # containerd.io ONLY. No docker-ce and no docker-cli: a Kubernetes node has no
        # use for the Docker daemon, and installing it is what disables the CRI plugin.
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq containerd.io
        did "installed containerd.io (deliberately without Docker)"
    else warn "containerd NOT installed"; fi
else
    ok "containerd present: $(containerd --version 2>/dev/null | awk '{print $3}')"
fi

if command -v containerd >/dev/null 2>&1; then
    NEEDS=0
    grep -qs 'disabled_plugins.*cri' /etc/containerd/config.toml && NEEDS=1
    grep -qs 'SystemdCgroup = true'  /etc/containerd/config.toml || NEEDS=1
    if [ "$NEEDS" -eq 1 ]; then
        if mutate; then
            cp -n /etc/containerd/config.toml /etc/containerd/config.toml.orig-packaged 2>/dev/null || true
            containerd config default > /etc/containerd/config.toml
            # The cgroup driver MUST match the kubelet's, which is systemd on Ubuntu.
            # A mismatch does not fail at install time — it fails later, intermittently,
            # under load, which is far harder to diagnose than an outright refusal.
            sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
            systemctl restart containerd
            did "regenerated containerd config (CRI enabled, SystemdCgroup=true)"
        else warn "containerd config is NOT kubelet-ready"; fi
    else
        ok "containerd config already kubelet-ready"
    fi
    mutate && ! systemctl is-enabled --quiet containerd && { systemctl enable --quiet containerd; did "enabled containerd"; } || true
    systemctl is-active --quiet containerd && ok "containerd running" || warn "containerd NOT running"
fi

say "4e. KUBEADM / KUBELET / KUBECTL (v$K8S_VERSION, held)"
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
        # Hold them. An unplanned kubelet minor bump is a cluster incident, and this lab
        # has already been bitten once by an unattended Docker upgrade breaking CI.
        apt-mark hold kubelet kubeadm kubectl >/dev/null
        systemctl enable --quiet kubelet
        did "installed and held kubelet/kubeadm/kubectl v$K8S_VERSION; kubelet enabled"
    else warn "kubeadm NOT installed"; fi
else
    ok "kubeadm present: $(kubeadm version -o short 2>/dev/null || echo '?')"
    apt-mark showhold 2>/dev/null | grep -q kubeadm \
        && ok "packages held" \
        || warn "packages NOT held — run: apt-mark hold kubelet kubeadm kubectl"
fi

say "4f. EXAM-PARITY TOOLING (yq, k alias, completion)"
# The CKA environment provides kubectl with a `k` alias and bash completion already set
# up, plus yq, curl, wget and man. It does NOT list jq, so jq is deliberately absent
# here: practising with a tool the exam lacks is a trap you only discover under a clock.
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
# 🚨 Report honestly. `systemctl is-active` PRINTS "inactive"/"not-found" AND exits
# non-zero, so a naive `cmd || echo absent` prints BOTH. And claiming "CRI enabled: yes"
# when containerd is not installed is a false green — the config file simply is not there.
val() { local out; out="$("$@" 2>/dev/null)" || true; [ -n "$out" ] && printf '%s' "$out" || printf '%s' '?'; }

if [ -f /etc/containerd/config.toml ]; then
    grep -qs 'disabled_plugins.*cri' /etc/containerd/config.toml \
        && CRI_STATE='NO — kubeadm init WILL HANG' || CRI_STATE='yes'
    grep -qs 'SystemdCgroup = true' /etc/containerd/config.toml \
        && SCG_STATE='true' || SCG_STATE='NOT true'
else
    CRI_STATE='n/a — no containerd config yet'
    SCG_STATE='n/a — no containerd config yet'
fi

printf '  host            : %s (%s)\n' "$(hostname)" "$(ip -o -4 addr show | awk '!/ lo /{print $4}' | paste -sd,)"
printf '  swap            : %s\n' "$([ -z "$(swapon --show)" ] && echo off || echo 'ON — kubelet will refuse to start')"
printf '  containerd      : %s\n' "$(val systemctl is-active containerd)"
printf '  CRI enabled     : %s\n' "$CRI_STATE"
printf '  SystemdCgroup   : %s\n' "$SCG_STATE"
printf '  kubeadm         : %s\n' "$(val kubeadm version -o short)"
printf '  kubelet enabled : %s\n' "$(val systemctl is-enabled kubelet)"
printf '  yq              : %s\n' "$(yq --version 2>/dev/null | awk '{print $NF}' || echo absent)"
printf '  cockpit         : %s\n' "$(val systemctl is-enabled cockpit.socket)"
if [ "$CHECK_ONLY" -eq 1 ]; then
    printf '\n  --check: nothing was changed.\n'
else
    printf '\n  %d change(s) made. Re-run to confirm it reports 0 — that is the idempotency test.\n' "$CHANGED"
fi
cat <<'EOF'

  NEXT (deliberately NOT done by this script):
    kube-vip must be answering on the VIP BEFORE kubeadm init, because
    --control-plane-endpoint fixes the apiserver certificate SANs at init time.
    Get that wrong and additional control planes can never join.

  EXPECTED: the kubelet crash-loops until kubeadm init or kubeadm join runs.
  That is normal and is not a fault.
EOF
