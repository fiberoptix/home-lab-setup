#!/usr/bin/env bash
#
# Post-personalization trim for the Docker Swarm nodes.
# Runs ON each node as the agamache user (passwordless sudo already in place).
#
# host_setup.sh is a workstation script. It detects gsettings on the Ubuntu cloud
# image and therefore installs Chrome + Cursor on what are headless nodes.
#
# It also freezes automatic package updates. Package churn during a study phase
# manufactures failures that teach nothing, and makes a real failure ambiguous.
#
# Safe to re-run.
#
set -euo pipefail

echo "--- disk before ---"
df -h / | tail -1

echo
echo "--- purging desktop packages ---"
sudo apt-get purge -y google-chrome-stable cursor 2>/dev/null || true
sudo apt-get autoremove --purge -y
sudo apt-get clean

echo
echo "--- freezing automatic updates ---"
for unit in unattended-upgrades.service apt-daily.timer apt-daily-upgrade.timer; do
    if systemctl list-unit-files "$unit" >/dev/null 2>&1; then
        sudo systemctl disable --now "$unit" 2>/dev/null || true
        sudo systemctl mask "$unit" 2>/dev/null || true
        echo "  masked $unit"
    fi
done

echo
echo "--- verification ---"
echo -n "  chrome/cursor: "
dpkg -l google-chrome-stable cursor 2>/dev/null | grep -q '^ii' && echo "STILL PRESENT" || echo "removed"
for unit in unattended-upgrades.service apt-daily.timer apt-daily-upgrade.timer; do
    printf '  %-28s %s\n' "$unit" "$(systemctl is-enabled "$unit" 2>&1)"
done
echo "--- disk after ---"
df -h / | tail -1
