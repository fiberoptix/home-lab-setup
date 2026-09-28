#!/bin/bash
#
# pve-host-config-backup.sh - nightly archive of the Proxmox HOST's own configuration to the NAS.
#
# Lives at: /usr/local/bin/pve-host-config-backup.sh on the Proxmox host (192.168.1.150)
# Run by:   pve-host-config-backup.timer (01:30 nightly). Safe to run by hand.
# Writes:   <nas-critical>/host-config/pve-host-config-<date>.tar.zst, keeps the newest 30.
#
# Why: vzdump backs up VMs, not the host. Every VM config, storage.cfg, the backup jobs, firewall,
# notifications, network, kernel pin and our scripts live on rpool - lose it (bad upgrade, mistake,
# both boot drives) and the VM disks survive with nothing describing them.
#
# 🚨 The archive CONTAINS SECRETS (/etc/pve/priv: storage passwords, auth keys). It goes only to the
# private NAS share, which already holds full VM backups. Never copy it anywhere public.
# 🚨 Refuses to run unless the NAS is really mounted: writing into an unmounted /mnt/pve/<x> silently
# fills rpool instead (the CIFS trap in MEMORY.md). A failure emails root; success is silent.
#
# Restore one file:  tar --zstd -xOf <archive> etc/pve/storage.cfg
# Restore the PVE config DB (host rebuild): see manifest/RESTORE.txt inside the archive.
#
set -uo pipefail

STORAGE=${STORAGE:-nas-critical}
MNT=${MNT:-/mnt/pve/$STORAGE}
KEEP=${KEEP:-30}
DEST="$MNT/host-config"
STAMP=$(date +%Y-%m-%d_%H%M)
WORK=$(mktemp -d /tmp/pve-host-config.XXXXXX)
trap 'rm -rf "$WORK"' EXIT

fail() {
    echo "FAILED: $*" >&2
    printf 'To: root\nSubject: [pve] HOST CONFIG BACKUP FAILED\n\n%s\n\nHost: %s  Time: %s\n' \
        "$*" "$(hostname)" "$(date)" | /usr/sbin/sendmail -t
    exit 1
}

pvesm status --storage "$STORAGE" >/dev/null 2>&1 || true
mountpoint -q "$MNT" || fail "$MNT is NOT mounted - refusing to write the archive onto rpool"
mkdir -p "$DEST" || fail "cannot create $DEST"

# 1. A consistent copy of the cluster config database (the real source of /etc/pve)
mkdir -p "$WORK/db"
sqlite3 /var/lib/pve-cluster/config.db ".backup '$WORK/db/config.db'" || fail "sqlite3 backup of config.db failed"

# 2. A manifest of what the host looked like, for a rebuild by hand
mkdir -p "$WORK/manifest"
{
    echo "== $(date) on $(hostname)"; pveversion -v
    echo; echo "== kernels"; proxmox-boot-tool kernel list
    echo; echo "== pools"; zpool list; zpool status
    echo; echo "== datasets"; zfs list -o name,used,avail,refer,mountpoint
    echo; echo "== storage"; pvesm status
    echo; echo "== VMs"; qm list
    echo; echo "== backup jobs"; cat /etc/pve/jobs.cfg
    echo; echo "== timers"; systemctl list-timers --all --no-legend
} > "$WORK/manifest/host-state.txt" 2>&1
dpkg --get-selections > "$WORK/manifest/dpkg-selections.txt"
apt-mark showhold > "$WORK/manifest/apt-holds.txt"
cat > "$WORK/manifest/RESTORE.txt" <<'EOF'
Restoring the PVE config onto a freshly installed host (same hostname "pve"):
  systemctl stop pve-cluster
  cp db/config.db /var/lib/pve-cluster/config.db   (chmod 600, owner root)
  systemctl start pve-cluster        -> /etc/pve (VM configs, storage.cfg, jobs, firewall) is back
Then restore from etc/ as needed: network/interfaces, postfix, kernel pin (proxmox-boot-tool kernel pin),
modprobe.d/zfs.conf (ARC cap), zfs/zed.d/zed.rc, systemd/system/*.timer, and usr/local/bin scripts.
Import the VM pools: zpool import vm-critical; zpool import vm-ephemeral.
EOF

# 3. The files themselves
tar --zstd -cf "$WORK/archive.tar.zst" \
    -C "$WORK" db manifest \
    -C / --ignore-failed-read \
    etc/pve etc/network/interfaces etc/hosts etc/hostname etc/resolv.conf etc/fstab \
    etc/postfix etc/aliases etc/apt/sources.list etc/apt/sources.list.d \
    etc/kernel etc/modprobe.d etc/modules-load.d etc/sysctl.d \
    etc/zfs/zed.d/zed.rc etc/smartd.conf etc/vzdump.conf etc/cron.d \
    etc/systemd/system etc/ssh/sshd_config etc/ssh/sshd_config.d \
    usr/local/bin root/.bashrc root/.ssh/authorized_keys root/.ssh/authorized_keys2 \
    2> "$WORK/tar.err"
rc=$?
# tar exit 1 = "a file changed while being read" (a warning); only 2+ is fatal.
[ $rc -le 1 ] || fail "tar failed (exit $rc): $(tail -3 "$WORK/tar.err")"

OUT="$DEST/pve-host-config-$STAMP.tar.zst"
cp "$WORK/archive.tar.zst" "$OUT.part" && mv "$OUT.part" "$OUT" || fail "copy to $DEST failed"
tar --zstd -tf "$OUT" >/dev/null 2>&1 || fail "archive written but does not read back: $OUT"

ls -1t "$DEST"/pve-host-config-*.tar.zst 2>/dev/null | tail -n +$((KEEP + 1)) | xargs -r rm -f
echo "OK $OUT ($(du -h "$OUT" | cut -f1)), $(ls -1 "$DEST"/pve-host-config-*.tar.zst | wc -l) kept"
