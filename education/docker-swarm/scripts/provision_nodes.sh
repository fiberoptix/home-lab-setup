#!/usr/bin/env bash
#
# Provision the Docker Swarm node VMs from template 9000.
# Runs ON the Proxmox host (192.168.1.150) as root.
#
# Safe to re-run: every step checks the current state first, so a partial run
# can simply be repeated rather than unpicked.
#
set -euo pipefail

TEMPLATE=9000
STORAGE=vm-ephemeral
NODES="1 2 3"
CORES=2
MEMORY=4096
DISK=40G
GATEWAY=192.168.1.1
NAMESERVER="8.8.8.8 8.8.4.4"

for n in $NODES; do
    id=$((190 + n))
    name="docker-swarm-$n"
    ip="192.168.1.$id"

    echo "=============================================="
    echo "[$id] $name  ($ip)"
    echo "=============================================="

    if qm config "$id" >/dev/null 2>&1; then
        echo "[$id] VM already exists - skipping clone"
    else
        echo "[$id] cloning template $TEMPLATE -> $name on $STORAGE"
        qm clone "$TEMPLATE" "$id" --name "$name" --full --storage "$STORAGE"
    fi

    echo "[$id] applying cores/memory/onboot/network"
    qm set "$id" \
        --cores "$CORES" \
        --memory "$MEMORY" \
        --onboot 1 \
        --ipconfig0 "ip=$ip/24,gw=$GATEWAY" \
        --nameserver "$NAMESERVER"

    # Template 9000's disk is 3584M. qm resize only ever grows, so re-running is
    # harmless, but check anyway so the log says what actually happened.
    size=$(qm config "$id" | sed -n 's/^scsi0:.*size=\([0-9]*[MG]\).*/\1/p')
    if [ "$size" = "$DISK" ]; then
        echo "[$id] disk already $DISK"
    else
        echo "[$id] resizing disk $size -> $DISK"
        qm resize "$id" scsi0 "$DISK"
    fi

    if [ "$(qm status "$id" | awk '{print $2}')" = "running" ]; then
        echo "[$id] already running"
    else
        echo "[$id] starting"
        qm start "$id"
    fi
done

echo
echo "=============================================="
echo "Result"
echo "=============================================="
qm list | awk 'NR==1 || $1 ~ /^19[123]$/'
