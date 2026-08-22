#!/bin/bash
#
# setup_docker.sh - Install Docker, Docker Compose, and Git
#
# Usage: sudo ./setup_docker.sh
#
# This script will:
# 1. Install Git and configure user
# 2. Install Docker Engine (official repo)
# 3. Install Docker Compose plugin
# 4. Point Docker at the insecure GitLab registry, turn the containerd image store
#    OFF, and VERIFY the daemon actually loaded both
# 5. Add current user to docker group
#

set -e

echo "=========================================="
echo "Docker + Git Setup"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root (sudo ./setup_docker.sh)"
    exit 1
fi

# Get the actual user (not root)
ACTUAL_USER=${SUDO_USER:-$USER}
if [ "$ACTUAL_USER" = "root" ]; then
    echo "WARNING: Could not determine non-root user"
    ACTUAL_USER="agamache"
fi
echo "Setting up for user: $ACTUAL_USER"

# Step 1: Install Git
echo ""
echo "[1/5] Installing Git..."
apt-get update -qq
apt-get install -y git
echo "    Git installed: $(git --version)"

# Configure git for the user
echo "    Configuring git for $ACTUAL_USER..."
sudo -u "$ACTUAL_USER" git config --global user.name "Andrew Gamache"
sudo -u "$ACTUAL_USER" git config --global user.email "agamache@gothamtechnologies.com"
sudo -u "$ACTUAL_USER" git config --global init.defaultBranch main
sudo -u "$ACTUAL_USER" git config --global pull.rebase false
echo "    Git configured (user.name, user.email, defaultBranch=main)"

# Step 2: Install Docker prerequisites
echo ""
echo "[2/5] Installing Docker prerequisites..."
apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null || true
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "    Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Step 3: Install Docker Engine
echo ""
echo "[3/5] Installing Docker Engine..."
apt-get update -qq
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker
systemctl start docker
systemctl enable docker
echo "    Docker installed: $(docker --version)"
echo "    Docker Compose installed: $(docker compose version)"

# Configure insecure registry for GitLab
echo "    Configuring GitLab Container Registry..."
mkdir -p /etc/docker

# ---------------------------------------------------------------------------
# containerd-snapshotter: false is NOT optional, and it is not tidiness.
#
# Docker 29.7.x defaults to the containerd image store, which makes `docker build`
# emit OCI image INDEXES. Its push path can send the parent index BEFORE the child
# manifest that index references, and the GitLab registry correctly rejects that:
#     error from registry: blob unknown to registry
#
# This broke CI on the runner (.182) on Aug 17 2026 and was fixed there BY HAND.
# The fix was never folded back into this script, so every host built between then
# and Aug 21 2026 shipped the broken default. Same shape as the `nofail` bug:
# fixing one VM fixes one VM; fixing the BUILDER fixes every future one.
#
# It is a RACE, not a certainty, so it hides. It only bites when several images
# have genuinely new content in one pipeline -- a job that changes one image passes
# and looks like proof the daemon is fine.
#
# WARNING: on a host that already has images in the OLD store, they become
# invisible to the new driver (`docker images` reads empty). That is expected on a
# retrofit; rebuild or repull. On a fresh build there is nothing to lose.
# ---------------------------------------------------------------------------
REGISTRY="gitlab.gothamtechnologies.com:5050"
cat > /etc/docker/daemon.json << EOF
{
  "insecure-registries": ["${REGISTRY}"],
  "features": { "containerd-snapshotter": false }
}
EOF
systemctl restart docker
echo "    Wrote /etc/docker/daemon.json (insecure registry + containerd store OFF)"

# ---------------------------------------------------------------------------
# Step 4: VERIFY the daemon loaded that config.
#
# Writing a config file is a claim; `docker info` is the daemon's own report of
# what it actually loaded. A malformed daemon.json makes Docker fail to start, and
# a restart that silently kept the old config looks identical to success.
# ---------------------------------------------------------------------------
echo ""
echo "[4/5] Verifying the daemon loaded that config..."
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
# the daemon's own report, because the flag can be silently lost by a later edit to
# daemon.json and nothing else will tell you until a push fails.
DRIVER=$(docker info 2>/dev/null | awk -F': ' '/Storage Driver/ {print $2}' | tr -d ' ')
if [ "$DRIVER" = "overlay2" ]; then
    echo "    Confirmed: storage driver is overlay2 (containerd image store OFF)"
else
    echo "ERROR: storage driver is '$DRIVER', expected 'overlay2'."
    echo "       The containerd-snapshotter flag did not take effect. Pushes to the"
    echo "       GitLab registry will intermittently fail with"
    echo "       'blob unknown to registry'."
    docker info 2>/dev/null | grep -iE 'storage driver|driver-type'
    exit 1
fi

# Step 5: Add user to docker group
echo ""
echo "[5/5] Adding $ACTUAL_USER to docker group..."
usermod -aG docker "$ACTUAL_USER"
echo "    User $ACTUAL_USER added to docker group"

# Verify installation
echo ""
echo "=========================================="
echo "SUCCESS! Docker + Git installed"
echo "=========================================="
echo ""
echo "Installed:"
echo "  ✓ Git $(git --version | awk '{print $3}')"
echo "  ✓ Docker $(docker --version | awk '{print $3}' | tr -d ',')"
echo "  ✓ Docker Compose $(docker compose version | awk '{print $4}')"
echo "  ✓ Storage driver $DRIVER (containerd image store OFF, verified)"
echo "  ✓ Registry $REGISTRY (insecure, verified via docker info)"
if id -nG "$ACTUAL_USER" | tr ' ' '\n' | grep -qx docker; then
    echo "  ✓ User $ACTUAL_USER is in the docker group"
else
    echo "  ✗ User $ACTUAL_USER is NOT in the docker group"
fi
echo ""
echo "IMPORTANT: Log out and back in for docker group to take effect!"
echo "Or run: newgrp docker"
echo ""
echo "Test with: docker run hello-world"
echo "Done!"

