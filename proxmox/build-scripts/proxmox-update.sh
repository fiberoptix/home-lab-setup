#!/bin/bash
#
# proxmox-update.sh - Update Proxmox and disable subscription nag
#
# Lives at: /usr/local/bin/proxmox-update.sh on the Proxmox host (192.168.1.150)
# Invoked as: `update` (alias in /root/.bashrc). Run by hand only - nothing schedules it.
#
# 🚨 full-upgrade, never `apt upgrade`: on Proxmox, `apt upgrade` holds back any
# package that needs a NEW dependency. Measured Sep 28, 2026: it would have kept
# back pve-firewall and both kernel meta-packages while upgrading pve-manager,
# leaving the PVE stack at mixed versions.
#
# The kernel that BOOTS is decided by `proxmox-boot-tool kernel pin`, not by what
# is installed. This script installs new kernels but never touches the pin;
# adopting one is the phase1b procedure (one-shot --next-boot trial first).
# See phases/phase1b_proxmox_kernel_upgrade_safe_try.md.
#

set -u

pinned() { proxmox-boot-tool kernel list 2>/dev/null | awk '/^Pinned kernel:/{getline; print $1}'; }

PIN_BEFORE=$(pinned)

echo "========================================"
echo "Proxmox Update Script"
echo "========================================"
echo ""

# Step 1: Update package lists
echo "[1/4] Updating package lists..."
if ! apt update; then
    echo "🚨 apt update FAILED - stopping, nothing was upgraded"
    exit 1
fi

echo ""

# Step 2: Full-upgrade packages (with DEBIAN_FRONTEND to avoid debconf prompts)
echo "[2/4] Full-upgrading packages..."
if ! DEBIAN_FRONTEND=noninteractive apt full-upgrade -y; then
    echo "🚨 apt full-upgrade FAILED - stopping before the nag patch. Read the error, fix, re-run."
    exit 1
fi

echo ""

# Step 3: Disable subscription nag (in case proxmox-widget-toolkit was updated)
echo "[3/4] Disabling subscription nag..."
if [ -f /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js ]; then
    perl -0777 -pi -e "s/(res === undefined \|\|\s*!res \|\|\s*)res\.data\.status\.toLowerCase\(\) !== 'active'/\${1}false/s" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
    systemctl restart pveproxy.service 2>/dev/null || true
    echo "    Subscription nag disabled"
else
    echo "    WARNING: proxmoxlib.js not found"
fi

echo ""

# Step 4: What the NEXT boot will do
echo "[4/4] Boot check..."
PIN_AFTER=$(pinned)
RUNNING_KERNEL=$(uname -r)
NEWEST_KERNEL=$(ls /boot/vmlinuz-*-pve 2>/dev/null | sed 's|/boot/vmlinuz-||' | sort -V | tail -1)
echo "    Running kernel : $RUNNING_KERNEL"
echo "    Pinned kernel  : ${PIN_AFTER:-NONE}"
echo "    Newest on disk : ${NEWEST_KERNEL:-?}"
echo ""
if [ -z "$PIN_AFTER" ]; then
    echo "🚨 NO KERNEL PIN - the next reboot boots the NEWEST kernel ($NEWEST_KERNEL)."
    echo "   Do not reboot until that is intended."
elif [ "$PIN_AFTER" != "$PIN_BEFORE" ]; then
    echo "🚨 PIN CHANGED during the upgrade: ${PIN_BEFORE:-NONE} -> $PIN_AFTER. Do not reboot until explained."
else
    echo "    Pin unchanged - the next reboot boots $PIN_AFTER."
    if [ -n "$NEWEST_KERNEL" ] && [ "$NEWEST_KERNEL" != "$PIN_AFTER" ]; then
        echo "    $NEWEST_KERNEL is installed but NOT booted. Adopt it only via the phase1b --next-boot trial."
    fi
fi
echo ""
echo "    Kernels on the boot partitions (fallbacks if a boot fails):"
proxmox-boot-tool kernel list 2>/dev/null | sed -n '/^Manually selected kernels:/,/^$/p;/^Automatically selected kernels:/,/^$/p' \
    | grep -vE '^(Manually|Automatically) selected kernels:|^None\.$|^$' | sort -uV | sed 's/^/      /'
echo "    ⚠️  Is a kernel that has already BOOTED on this hardware in that list, besides the pin?"
echo "       New kernels push older ones off the ESPs (Sep 28, 2026: 7.0.6-2 was dropped)."
echo "       If not: proxmox-boot-tool kernel add <known-good> && proxmox-boot-tool refresh"

echo ""
echo "========================================"
echo "Update complete!"
echo "========================================"
echo ""

if [ -f /var/run/reboot-required ]; then
    echo "⚠️  REBOOT REQUIRED (flagged by an upgraded package)"
    echo ""
fi
echo "Note: running VMs keep the QEMU binary they started with until each is stopped"
echo "and started (or the host reboots). A reboot boots the PINNED kernel above."
echo ""
