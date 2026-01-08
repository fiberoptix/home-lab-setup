#!/bin/bash
#
# run_www.sh - Start/restart the script server
#
# Usage: ./run_www.sh
#
# This will tear down, rebuild, and launch the nginx container
# serving scripts at http://<this-machine>:80/scripts/
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "  Script Server (re)start"
echo "=========================================="

# Step 1: Stop and remove existing container
echo ""
echo "[1/3] Stopping existing container..."
docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true
docker rm -f script-server 2>/dev/null || true
echo "    Done"

# Step 2: Rebuild
echo ""
echo "[2/3] Rebuilding container..."
docker compose build 2>/dev/null || docker-compose build 2>/dev/null

# Step 3: Start
echo ""
echo "[3/3] Starting container..."
docker compose up -d 2>/dev/null || docker-compose up -d 2>/dev/null

# Verify
echo ""
echo "=========================================="
sleep 1
if docker ps | grep -q script-server; then
    IP_ADDR=$(hostname -I | awk '{print $1}')
    echo "  ✓ Script server running!"
    echo ""
    echo "  URL: http://${IP_ADDR}/scripts/"
    echo ""
    echo "  Available scripts:"
    ls -1 scripts/*.sh 2>/dev/null | sed 's/scripts\//    • /'
    echo ""
    echo "  Master setup command:"
    echo "    bash <(curl -s http://${IP_ADDR}/scripts/host_setup.sh)"
else
    echo "  ✗ Failed to start script server"
    echo ""
    echo "  Check logs with: docker logs script-server"
    exit 1
fi
echo "=========================================="

