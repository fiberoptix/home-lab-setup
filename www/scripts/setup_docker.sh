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
# 4. Add current user to docker group
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
echo "[1/4] Installing Git..."
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
echo "[2/4] Installing Docker prerequisites..."
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
echo "[3/4] Installing Docker Engine..."
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
cat > /etc/docker/daemon.json << 'EOF'
{
  "insecure-registries": ["gitlab.gothamtechnologies.com:5050"]
}
EOF
systemctl restart docker
echo "    Insecure registry configured for gitlab.gothamtechnologies.com:5050"

# Step 4: Add user to docker group
echo ""
echo "[4/4] Adding $ACTUAL_USER to docker group..."
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
echo "  ✓ User $ACTUAL_USER added to docker group"
echo ""
echo "IMPORTANT: Log out and back in for docker group to take effect!"
echo "Or run: newgrp docker"
echo ""
echo "Test with: docker run hello-world"
echo "Done!"

