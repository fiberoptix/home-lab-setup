# Cloud-init template (VM 9000), cloning, nofail/_netdev, prod-local NAS rule

Topic reference (not tied to one phase). Loaded ON TOUCH via `phases/INDEX.md`. Blocks below are copied VERBATIM from `MEMORY.md` as of tag `pre-memory-diet` (Nov 24, 2026).

---

## COPIED VERBATIM FROM `MEMORY.md` @ `pre-memory-diet` (lines 1958–2096) — Nov 24, 2026 (memory-diet, copy-first) — CLOUD-INIT TEMPLATE

## CLOUD-INIT TEMPLATE (VM 9000) — how to build any new VM in ~30 seconds

**Created July 25, 2026 (Phase 14, Part 1). This is now the preferred way to build a VM —
do not hand-build from an ISO unless there's a reason.**

`9000 = tmpl-ubuntu-2404-cloudinit`: Ubuntu 24.04 cloud image with `qemu-guest-agent` baked in,
machine-id truncated, cloud-init drive attached. Its disk is `vm-ephemeral/base-9000-disk-0`
(PVE renames a volume to `base-*` when the VM becomes a template).

```bash
# Clone and personalize — that's the whole job
qm clone 9000 <VMID> --name <vm-name> --full --storage <pool>
qm set <VMID> --cores <n> --sockets 1 --memory <MB> --onboot 1
qm resize <VMID> scsi0 <size>G          # cloud-init's growpart expands the fs on first boot
qm set <VMID> --ipconfig0 ip=192.168.1.<VMID>/24,gw=192.168.1.1 --nameserver "8.8.8.8 8.8.4.4"
qm start <VMID>
```

`ciuser` (agamache), `cipassword`, and `sshkeys` are **inherited from the template** — no need to
re-specify. Hostname is taken from `--name`. Standard disk flags are inherited too.

**Rules learned building it:**
- ⚠️ **The template's disk is only 3584M (3.5 GB), so `qm resize` is mandatory, not optional** — and
  it grows the *virtual* disk, while the *filesystem* only follows if cloud-init's `growpart` runs on
  first boot. **Verify from inside the guest with `df -h /`**, not from `qm config`. If growpart
  silently does not fire, the VM dies on its first large `docker pull` with an error about image
  layers rather than about disk space, which is a genuinely confusing 20 minutes.
- **Key source is `/root/cloudinit-keys-all.pub`** on the host (workstation ED25519 + PVE RSA).
  `/root/.ssh/authorized_keys` → `/etc/pve/priv/authorized_keys` has ONLY the cluster RSA key;
  using it produces a VM the workstation can't SSH into.
- **Don't set `--searchdomain`** — the lab resolves internal names via `/etc/hosts`, so a search
  domain only adds failed lookups.
- `--ciupgrade 0` keeps first boot fast and keeps clones identical. Upgrade deliberately instead.
- Modern PVE imports a disk in one step: `qm set <id> --scsi0 <pool>:0,import-from=<path>,...`.
  The two-step `qm importdisk` recipe in most blog posts is obsolete.
- `virt-customize` needs `export LIBGUESTFS_BACKEND=direct` on this host (no libvirt configured).

**SSH password auth is ENABLED in the template** (July 25). Ubuntu cloud images ship
`/etc/ssh/sshd_config.d/60-cloudimg-settings.conf` with `PasswordAuthentication no`, which made
clones key-only and inconsistent with the rest of the fleet (182/184 allow passwords). Changed to
`yes` inside the template disk so all clones match. Login is `agamache` / fleet password.

**Editing the template's disk in place (no need to un-template):** its zvol is writable at
`/dev/zvol/vm-ephemeral/base-9000-disk-0`, so `virt-customize`/`virt-cat` work directly on it:

```bash
zfs snapshot vm-ephemeral/base-9000-disk-0@pre-change     # cheap insurance, delete after validating
export LIBGUESTFS_BACKEND=direct
virt-customize -a /dev/zvol/vm-ephemeral/base-9000-disk-0 --run-command '<your change>'
virt-customize -a /dev/zvol/vm-ephemeral/base-9000-disk-0 --truncate /etc/machine-id   # ALWAYS LAST
virt-cat -a /dev/zvol/vm-ephemeral/base-9000-disk-0 /etc/machine-id | wc -c            # MUST be 0
```

> ⚠️ **`virt-customize` re-populates `/etc/machine-id` on every single run** (it prints
> "Setting the machine ID"). If you don't re-truncate it afterwards, **every future clone gets
> an identical machine-id** — the exact identity collision the template exists to prevent.
> Always finish with `--truncate /etc/machine-id` and verify it reads 0 bytes.
> The `@__base__` snapshot on the template zvol is PVE's own marker — leave it alone.

### 🔁 CLONING AN EXISTING VM (not the template) — proven Aug 20, 2026 doing 200 → 180

🚨 **Proxmox CANNOT re-number a VM in place. "Renumbering" is always a clone**, so treat it as a
copy-and-validate job, not an edit. A full clone of a 100 GB zvol with ~15 GB used took **23 seconds**.

⛔ **The dangerous part is not the clone, it is the two machines afterwards.** Checklist that worked:

1. ⚠️ **If the source has no cloud-init drive, its IP is STATIC INSIDE THE GUEST — the clone claims the
   same address.** Set **`onboot 0` on the original before anything else.** This is load-bearing, not
   tidiness: without it, one host reboot starts both and they fight over the IP.
2. 🚨 **A snapshot stores `onboot` too.** The original's pre-clone snapshot still says `onboot: 1`, so
   **a rollback silently re-arms autostart.** `qm config <id>` shows live; `qm config <id> --snapshot
   <name>` shows the snapshot. Reading the raw `<id>.conf` shows *both* and is easy to misread.
3. ✅ **Netplan here matches on interface NAME, not MAC**, so the clone's new MAC did not break
   networking. ⚠️ **The name is NOT uniform across the fleet — `.180` is `ens18`, `.186` is `eth0`.**
   Check the source VM's actual name before assuming; `ip -o -4 addr` beats guessing. ⭐ **The escape hatch if it ever does: `agent: enabled=1` means `qm guest exec`
   works over virtio-serial with NO network at all.** Check the agent is enabled *before* you boot a
   clone you might not be able to reach.
4. ✅ **A clone keeps the source's SSH host keys**, so if the IP is unchanged, `known_hosts` needs no
   clearing anywhere.
5. ✅ **`refresh.sh` targets hosts by IP, not VMID**, so re-numbering is invisible to it — only its
   comment needed fixing. Check the same before assuming any script cares.
6. **Fix `/etc/fstab` BEFORE cloning** so both copies inherit it. Any network mount needs `nofail`.
   ⭐ **Verify the fix on the generated unit, not the fstab line:** `systemctl show <unit> -p RequiredBy
   -p WantedBy` must show **`RequiredBy=` empty** — that is what proves a dead NAS can no longer
   block boot.
   ✅ **FIXED AT SOURCE Aug 20, 2026:** `www/ubuntu/setup_smb_mount.sh` wrote `_netdev` but **not**
   `nofail`, so *every* VM ever built by it carried it. New builds are safe, and the whole lab was
   swept the same day — **all 9 VMs + the dev workstation now show `RequiredBy=` empty.**
   🧠 **The lesson that generalises:** when a per-VM fix works, go ask whether the *builder* has the
   same bug. Fixing one VM fixes one VM; fixing the script fixes every future one.
   ⚠️ **BUT the severity was overstated and is now corrected — see the `_netdev` note below.**

### 🩹 `nofail` / `_netdev` — what missing `nofail` ACTUALLY costs (corrected Aug 20, 2026)

⚠️ **We claimed it "drops the host to an emergency console, no network, no SSH." That is WRONG.**
`_netdev` already keeps the entry out of `local-fs.target`, and **`.184` is the disproof sitting in
our own lab** — it failed this exact mount at *every* boot from **July 9** onward and still came up
each time with networking and SSH working.

| Entry | Lands in | A dead NAS at boot means |
|---|---|---|
| network mount, **no `_netdev`, no `nofail`** | `local-fs.target` | ⛔ **emergency console** — the scary one |
| `_netdev`, **no `nofail`** | `remote-fs.target`, `RequiredBy=` | ⚠️ bounded **boot delay** (11 s measured on .184, ~90 s worst case) + a permanently failed unit |
| `_netdev,nofail` | `remote-fs.target`, `WantedBy=` | ✅ ignored at boot; still mounts when the NAS is there |

🧠 **The thinking error worth remembering: a plausible mechanism was asserted instead of checked,
while a host that had been running the experiment for six weeks sat one `systemctl status` away.**
Still worth fixing — a failed unit and a boot stall are real — just not a catastrophe.

### 🚫 PROD-LOCAL HOSTS MUST NOT MOUNT THE NAS — `.184` (`vm-www-1`)

🙋 **Andrew, Aug 20 2026: "184 should NOT mount the NAS! It's prod-local."** `.184` is the
internet-facing DMZ box; Phase 12 gave it `OUT DROP -dest 192.168.1.0/24`, so the NAS is unreachable
**by design**. The standard build had mounted it anyway — failing every boot since July **and leaving
`/root/.smbcredentials` on the internet-facing host** for a share it may never reach. All removed
(fstab line, unit, `/mnt/DevShare`, credentials); `.184` now has **zero failed units**.

⭐ **The generalisable point: a uniform build standard will plant credentials on the very hosts your
network design isolates.** The firewall worked perfectly; the **builder** was the leak.

**Two guards now, both in the build:**
- `bash host_setup.sh --no-nas` — deliberate skip for a known prod-local host.
- **`setup_smb_mount.sh` pre-checks `<nas>:445` and refuses** to write fstab or credentials if it
  cannot connect. ⭐ This is the one that matters — it needs no operator knowledge. **Verified by
  running it on `.184` itself:** refused, wrote nothing, host stayed clean.

⚠️ **`SKIP_NAS=1 sudo -E …` DOES NOT WORK here.** sudo has `env_reset`; it warns *"preserving the
entire environment is not supported"* and **silently drops the variable**, so the script runs in
full. Put it after sudo: **`sudo SKIP_NAS=1 bash ./setup_smb_mount.sh`**.

**Validating a template change:** clone to a throwaway VMID, boot, test, `qm destroy --purge`.
Takes ~40 seconds and is the only real proof. Done for the password-auth change: fresh clone
accepted password *and* key SSH, guest agent active, machine-id unique.

**Updating the template:** you can't boot a template. Clone it to a scratch VMID, boot,
`apt upgrade`, shut down, re-template, delete the old one. Refresh a couple times a year.

---
