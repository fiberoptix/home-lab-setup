# Ubuntu build kit — self-contained, no script server needed

⛔ **DO NOT EDIT THE SCRIPTS IN THIS FOLDER.** They are **generated copies** of `www/ubuntu/`.
Edit `www/ubuntu/*.sh`, then regenerate:

```bash
cd www && ./make_local_kits.sh ubuntu --with-creds
cd www && ./make_local_kits.sh --check     # is an existing kit still current?
```

---

## Why this kit exists

The script server is at **`192.168.1.195`** — a **VMware guest on the Z8 workstation**. Any build that
needs that same physical box to be doing something else (dual-booting it, reinstalling it) cannot
fetch from it, because **the server and the client are the same machine**.

## 🔑 Ubuntu carries one file Fedora does not

`anysphere.gpg` — **Cursor's apt signing key, mirrored locally because the official URL returns 403.**

⚠️ **This is the trap in an Ubuntu kit.** Copy "all the scripts" and you get eight `.sh` files that
*look* complete, but without the key Cursor's repo cannot be verified. The offline check counts it as
a required file, so a scripts-only copy correctly refuses to claim offline and names the missing key
instead of proceeding. Verified — see the table below.

---

## Use it

```bash
cp -r /run/media/$USER/<LABEL>/ubuntu_local ~/ubuntu_local
cd ~/ubuntu_local
bash host_setup.sh --hostname <name>
```

It prints **`OFFLINE MODE - using local files`** and lists all 8 files. If you see
`Downloading all scripts` instead, the copy is incomplete and the next line names what's missing.

**Flags:** `--hostname <name>`, `--no-nas` (skip the NAS mount), `--server` (headless: skip Chrome,
Cursor and GNOME settings).

## What it still needs

🌐 **Internet, but not the lab** — Docker, Chrome and Cursor come from public repos.

⚠️ **`wget` must exist.** This tree bootstraps with `wget`, unlike the Fedora tree which uses `curl`
precisely because stock Fedora has no `wget`. A bare `ubuntu:24.04` image has no `wget` either —
Desktop and Server ISOs do, but if you ever hit `wget: command not found`, that is why.
In offline mode `wget` is never called, so a kit build works without it.

🔑 Sudo password at the start, and the NAS password unless `smb_credentials` is in this folder.

## The credential file

🚨 If present, it is the **NAS password in plaintext**, and on FAT32/exFAT the `0600` mode **does not
stick** — those filesystems have no Unix permissions. Treat the USB as a secret, or omit
`--with-creds` and let `setup_smb_mount.sh` prompt.

✅ Not served by nginx (`docker-compose.yml` mounts only `./ubuntu` and `./fedora`), and covered by the
`www/*/smb_credentials` gitignore rule. Both verified, not assumed.

## Verified

Tested on **Ubuntu 24.04** in a container with **`--network none`**:

| Test | Result |
|---|---|
| Full kit (8 files), no network, read-only mount | ✅ `OFFLINE MODE`, all 8 found |
| Kit missing `anysphere.gpg` | ✅ refuses offline, **names the missing key** |
| `host_setup.sh` alone, real server | ✅ downloads all 8 — normal path unaffected |
