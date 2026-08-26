# Fedora build kit — self-contained, no script server needed

⛔ **DO NOT EDIT THE SCRIPTS IN THIS FOLDER.** They are **generated copies** of `www/fedora/`.
Edit `www/fedora/*.sh`, then regenerate:

```bash
cd www && ./make_local_kits.sh --with-creds
```

Check an existing kit is still current before you trust it:

```bash
cd www && ./make_local_kits.sh --check
```

⚠️ Two copies of eight scripts is a drift machine. If you hand-edit here, you will one day build a
host from a version you already fixed, and nothing will warn you. That is why `--check` exists.

---

## Why this kit exists

The script server lives at **`192.168.1.195`**, which is a **VMware guest on the Z8 workstation**.
Dual-booting that Z8 into Fedora means Windows is not running, so VMware is not running, so the
script server is **down** — at exactly the moment a fresh Fedora install wants to fetch from it.

**The machine being built and the machine serving the scripts are the same physical box.** No amount
of ordering or retrying fixes that. The scripts have to be carried in.

---

## Use it

Copy the **whole folder** to a USB stick. On the new Fedora box:

```bash
cp -r /run/media/$USER/<LABEL>/fedora_local ~/fedora_local
cd ~/fedora_local
bash host_setup.sh --hostname AGAMACHE-FEDORA-WKS
```

It prints **`OFFLINE MODE`** and lists the seven sub-scripts it found. If you see
`-- Downloading all scripts` instead, the copy is incomplete — see *Troubleshooting*.

**Flags:** `--hostname <name>` (use it — Fedora ISO installs inherit `localhost-live`),
`--no-nas` (skip the NAS mount), `--server` (headless: skip Chrome, Cursor and GNOME settings —
**not** what you want on Fedora Workstation).

### Running straight off the USB

Works. Offline mode writes nothing into the kit folder, so a read-only stick is fine — verified
against a read-only mount. Copying to `~` first is still the recommendation, because it survives you
pulling the stick out mid-build.

---

## What it still needs

🌐 **Internet, but not the lab.** The seven sub-scripts come from this folder; everything they
*install* comes from the public internet:

- `download.docker.com` — Docker CE
- `dl.google.com` — Chrome
- `downloads.cursor.com` — Cursor RPM repo and key

This is where the Fedora tree is better off than Ubuntu's, which has to mirror Cursor's apt key
locally because the official URL 403s. Fedora's repo and key are both publicly fetchable, so nothing
here depends on the lab being up.

🔑 **Sudo password** at the start, and **the NAS password** unless `smb_credentials` is in this
folder.

---

## The credential file

If `smb_credentials` is present, `setup_smb_mount.sh` finds it automatically — its lookup chain
checks `$SCRIPT_DIR/smb_credentials` as well as `../smb_credentials`, so this flat layout is valid.

🚨 **It is the NAS password in plaintext.** On a FAT32/exFAT stick the `0600` mode **does not stick**,
because those filesystems have no Unix permissions — anything that mounts the stick can read it.
Treat the USB as a secret, or leave the credential out and let the script prompt:

```bash
cd www && ./make_local_kits.sh          # no --with-creds
```

The prompt path is fully supported and costs one typed password.

✅ This folder is **not** served by nginx — `docker-compose.yml` bind-mounts only `./ubuntu` and
`./fedora`. And `smb_credentials` here is covered by the `www/*/smb_credentials` gitignore rule, so it
cannot be committed. Both were verified rather than assumed.

---

## Verified

Tested on **Fedora 44** in a container with **`--network none`** — no network path existed at all:

| Test | Result |
|---|---|
| Full kit, no network | ✅ `OFFLINE MODE`, all 7 found, reached the confirm prompt |
| Full kit, read-only mount | ✅ works — writes nothing to the kit |
| `host_setup.sh` alone, no network | ✅ correctly falls back to downloading, fails, points here |
| Partial kit (3 of 8 files) | ✅ refuses to claim offline, **names the missing files** |

That last one matters most: the offline check is **all-or-nothing on purpose**. A half-copied USB
must not silently run three real scripts and skip five, which is the kind of failure that looks like
success.

---

## Troubleshooting

**It says `-- Downloading all scripts` instead of `OFFLINE MODE`.** The copy is incomplete. The line
below names the missing files. Re-copy the whole folder.

**`ERROR: this is the FEDORA build.`** You are on Ubuntu/Debian. Use the `ubuntu` tree instead.

**`STOPPING: passwordless sudo is not working.`** A hard gate, on purpose — every later step runs
under sudo, so continuing would bury the real cause under a wall of unrelated failures. Fix it and
re-run; every script here is idempotent.

**Something failed mid-run.** The run does not abort on the first error; it records each step and
prints a measured summary at the end, then exits non-zero. Read the `SCRIPTS THAT FAILED:` line, fix
that one, and re-run the whole thing — that is safe.
