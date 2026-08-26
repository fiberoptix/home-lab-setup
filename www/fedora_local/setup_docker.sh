#!/bin/bash
#
# setup_docker.sh - Install Docker CE, Docker Compose, and Git (Fedora)
#
# Usage: sudo ./setup_docker.sh
#
# Fedora counterpart of www/ubuntu/setup_docker.sh. Differences from Ubuntu:
#   1. dnf5, and the repo is a .repo file in /etc/yum.repos.d/ rather than a
#      signed-by apt source + a dearmored keyring.
#   2. Podman ships preinstalled on Fedora Workstation and is LEFT ALONE. It does
#      not conflict with Docker and it does not provide a `docker` binary, so the
#      "already installed" check below cannot be fooled by it (measured on .196:
#      podman 5.8.1 present, `command -v docker` -> nothing).
#   3. This version VERIFIES the insecure-registry setting took effect by reading
#      it back out of `docker info`. The Ubuntu original writes daemon.json and
#      assumes. Writing a config file is not the same as the daemon loading it --
#      a malformed daemon.json makes Docker fail to start, and a restart that
#      silently kept the old config looks identical to success.
#
# The insecure-registries entry is the load-bearing line in this script. Phase 17
# confirmed on Aug 20 that .185 already had it *because the standard build wrote
# it*, closing a question that had previously been asserted wrongly.
#

set -e

echo "=========================================="
echo "Docker + Git Setup (Fedora)"
echo "=========================================="

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root (sudo ./setup_docker.sh)"
    exit 1
fi

ACTUAL_USER=${SUDO_USER:-$USER}
if [ "$ACTUAL_USER" = "root" ]; then
    echo "WARNING: Could not determine non-root user"
    ACTUAL_USER="agamache"
fi
echo "Setting up for user: $ACTUAL_USER"

REGISTRY="gitlab.gothamtechnologies.com:5050"

# ---------------------------------------------------------------------------
echo ""
echo "[1/6] Installing Git..."
if rpm -q --quiet git; then
    echo "    Already installed: $(git --version)"
else
    dnf install -y git
    echo "    Git installed: $(git --version)"
fi

echo "    Configuring git for $ACTUAL_USER..."
runuser -u "$ACTUAL_USER" -- git config --global user.name "Andrew Gamache"
runuser -u "$ACTUAL_USER" -- git config --global user.email "agamache@gothamtechnologies.com"
runuser -u "$ACTUAL_USER" -- git config --global init.defaultBranch main
runuser -u "$ACTUAL_USER" -- git config --global pull.rebase false
echo "    Git configured (user.name, user.email, defaultBranch=main)"

# ---------------------------------------------------------------------------
echo ""
echo "[2/6] Adding the Docker CE repository..."

# Confirm Docker actually publishes for THIS Fedora release before adding a repo
# that resolves $releasever. Docker's Fedora repo can lag a new release, and the
# failure mode is a confusing "no match for argument: docker-ce" much later.
RELEASEVER=$(rpm -E %fedora)
if curl -sfI "https://download.docker.com/linux/fedora/${RELEASEVER}/x86_64/stable/" >/dev/null; then
    echo "    Docker CE publishes for Fedora ${RELEASEVER}"
else
    echo "ERROR: Docker CE has no repository for Fedora ${RELEASEVER} yet."
    echo "       Check https://download.docker.com/linux/fedora/ for available releases."
    exit 1
fi

if [ -f /etc/yum.repos.d/docker-ce.repo ]; then
    echo "    Repo file already present"
else
    curl -fsSL https://download.docker.com/linux/fedora/docker-ce.repo \
        -o /etc/yum.repos.d/docker-ce.repo
    echo "    Wrote /etc/yum.repos.d/docker-ce.repo"
fi

# ---------------------------------------------------------------------------
echo ""
echo "[3/6] Installing Docker Engine..."
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ---------------------------------------------------------------------------
echo ""
echo "[4/6] Configuring the GitLab container registry (insecure, plain HTTP)..."
mkdir -p /etc/docker

# ---------------------------------------------------------------------------
# containerd-snapshotter: false is NOT optional here, and it is not tidiness.
#
# Docker 29.7.x defaults to the containerd image store, which makes `docker
# build` emit OCI image INDEXES. Its push path can send the parent index BEFORE
# the child manifest that index references, and the GitLab registry correctly
# rejects that with:
#     error from registry: blob unknown to registry
#
# This broke CI on the runner (.182) on Aug 17 2026 and was fixed there BY HAND.
# The Ubuntu build script never learned the fix, so every host built since has
# shipped the broken default. Same shape as the `nofail` bug: a per-VM fix that
# was never folded back into the builder.
#
# It is a RACE, not a certainty, so it hides. It only bites when several images
# have genuinely new content in one pipeline -- a job that changes one image
# passes and looks like proof the daemon is fine.
#
# WARNING: after toggling this, images in the OLD store are invisible to the new
# driver (`docker images` reads empty). That is expected. Rebuild/repull.
# ---------------------------------------------------------------------------
cat > /etc/docker/daemon.json << EOF
{
  "insecure-registries": ["${REGISTRY}"],
  "features": { "containerd-snapshotter": false }
}
EOF
echo "    Wrote /etc/docker/daemon.json (insecure registry + containerd store OFF)"

echo ""
echo "[5/6] Enabling and starting Docker..."
systemctl enable --now docker
systemctl restart docker

# ---------------------------------------------------------------------------
# VERIFY. A written config file is a claim; docker info is the daemon's own
# report of what it actually loaded.
# ---------------------------------------------------------------------------
echo ""
echo "[6/6] Verifying the daemon loaded that config..."
if ! systemctl is-active --quiet docker; then
    echo "ERROR: docker is not running after restart."
    systemctl status docker --no-pager | head -20
    journalctl -u docker -n 20 --no-pager
    exit 1
fi

if docker info 2>/dev/null | grep -q "$REGISTRY"; then
    echo "    Confirmed: daemon reports $REGISTRY as an insecure registry"
else
    echo "ERROR: daemon.json was written but the daemon does NOT report it."
    echo "       Check for a malformed daemon.json:"
    cat /etc/docker/daemon.json
    docker info 2>/dev/null | sed -n '/Insecure Registries/,+5p'
    exit 1
fi

# The storage driver is the observable consequence of the feature flag. Assert on
# the daemon's own report, because the flag can be silently lost by a later edit
# to daemon.json and nothing else will tell you until a push fails.
DRIVER=$(docker info 2>/dev/null | awk -F': ' '/Storage Driver/ {print $2}' | tr -d ' ')
if [ "$DRIVER" = "overlay2" ]; then
    echo "    Confirmed: storage driver is overlay2 (containerd image store OFF)"
else
    echo "ERROR: storage driver is '$DRIVER', expected 'overlay2'."
    echo "       The containerd-snapshotter flag did not take effect. Pushes to"
    echo "       the GitLab registry will intermittently fail with"
    echo "       'blob unknown to registry'."
    docker info 2>/dev/null | grep -iE 'storage driver|driver-type'
    exit 1
fi

echo ""
echo "    Adding $ACTUAL_USER to the docker group..."
usermod -aG docker "$ACTUAL_USER"
echo "    Done (takes effect on next login)"

echo ""
echo "=========================================="
echo "SUCCESS! Docker + Git installed"
echo "=========================================="
echo ""
echo "  Git            $(git --version | awk '{print $3}')"
echo "  Docker         $(docker --version | awk '{print $3}' | tr -d ',')"
echo "  Docker Compose $(docker compose version | awk '{print $4}')"
echo "  Podman         $(podman --version 2>/dev/null | awk '{print $3}' || echo 'not installed') (left in place, does not conflict)"
echo "  Registry       ${REGISTRY} (insecure, verified via docker info)"
echo ""
echo "IMPORTANT: log out and back in for the docker group to take effect,"
echo "           or run: newgrp docker"
echo ""
echo "Test with: docker run hello-world"
echo "Done!"
