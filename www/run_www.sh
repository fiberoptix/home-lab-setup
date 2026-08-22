#!/bin/bash
#
# run_www.sh - Start/restart the script server
#
# Usage: ./run_www.sh
#
# This will tear down, rebuild, and launch the nginx container serving the
# build-script library at http://<this-machine>/ -- a landing page (www/index.html)
# with the copy-paste bootstrap commands, over the two distro trees /ubuntu/ and
# /fedora/, which stay browsable for grabbing individual scripts by hand.
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
    echo "  ➜  START HERE    : http://${IP_ADDR}/"
    echo "     The landing page carries these same commands with copy buttons, and"
    echo "     rewrites the address to whatever host you browsed it on. Send people"
    echo "     there rather than pasting commands into chat."
    echo ""
    echo "  Ubuntu / Debian : http://${IP_ADDR}/ubuntu/"
    echo "  Fedora          : http://${IP_ADDR}/fedora/"
    echo ""
    echo "  Ubuntu scripts:"
    ls -1 ubuntu/*.sh 2>/dev/null | sed 's/ubuntu\//    • /'
    echo ""
    echo "  Fedora scripts:"
    ls -1 fedora/*.sh 2>/dev/null | sed 's/fedora\//    • /'
    echo ""
    # ---------------------------------------------------------------------
    # RUN IT IN TWO STEPS. Do not "simplify" this back to a one-liner.
    #
    # This used to print `bash <(curl -s .../host_setup.sh)`, which is BROKEN
    # for these scripts, in two independent ways (both measured Aug 21, 2026):
    #
    #   1. host_setup.sh downloads its sub-scripts next to itself, using
    #      dirname "${BASH_SOURCE[0]}". Under process substitution BASH_SOURCE
    #      is /dev/fd/63, so SCRIPT_DIR becomes /dev/fd -- which is NOT
    #      writable, and every download fails.
    #   2. `curl ... | bash` avoids that but breaks the confirmation prompt:
    #      the script arrives ON STDIN, so `read -p` consumes the next BYTE OF
    #      THE SCRIPT ITSELF. Observed: REPLY='e' taken from the following
    #      `echo`, the run aborted, and bash then reported `cho: command not
    #      found` because the line had been eaten.
    #
    # Downloading to a real file first fixes both, and leaves the scripts on
    # the host afterwards, which is where you want them for a re-run.
    # ---------------------------------------------------------------------
    echo "  Master setup command — UBUNTU / DEBIAN:"
    echo "    wget http://${IP_ADDR}/ubuntu/host_setup.sh"
    echo "    bash host_setup.sh          # NOT sudo; it handles sudo itself"
    echo ""
    echo "  Master setup command — FEDORA (curl: stock Fedora has no wget):"
    echo "    curl -fsSLO http://${IP_ADDR}/fedora/host_setup.sh"
    echo "    bash host_setup.sh"
    echo ""
    echo "  Add --no-nas on a DMZ / prod-local host that must not reach the NAS."
    echo "  Add --hostname <name> on EITHER distro to set the hostname (also fixes"
    echo "  /etc/hosts and pins it against cloud-init). Fedora ISO installs inherit"
    echo "  'localhost-live', so they generally need it."
    echo ""
    echo "  Add --server on EITHER distro for a headless host: no Chrome (431 MB), no"
    echo "  Cursor (1012 MB), no GNOME settings, no autologin; CLI tools and aliases"
    echo "  are still installed. On Fedora the systemd sleep targets are still masked,"
    echo "  which a server needs MORE than a desktop does."
    echo "  Usually unnecessary - a host with no gnome-shell now gets this treatment"
    echo "  automatically. The flag forces it on a machine that HAS a desktop."
else
    echo "  ✗ Failed to start script server"
    echo ""
    echo "  Check logs with: docker logs script-server"
    exit 1
fi
echo "=========================================="

