#!/bin/bash
#
# make_local_kits.sh - build self-contained USB build kits from the served trees
#
#   cd www && ./make_local_kits.sh                    # both distros, no credentials
#   cd www && ./make_local_kits.sh --with-creds       # both, including smb_credentials
#   cd www && ./make_local_kits.sh fedora --with-creds
#   cd www && ./make_local_kits.sh --check            # verify kits match their sources
#
# Produces www/fedora_local/ and www/ubuntu_local/.
#
# ============================================================================
# WHY A GENERATOR RATHER THAN A HAND-MAINTAINED SECOND COPY
#
# The *_local trees are COPIES. Two copies of eight files is a drift machine:
# someone fixes a bug in fedora/ and the kit quietly keeps the old version, so
# you build a host from a bug you already fixed and nothing warns you. The copy
# is therefore GENERATED and never edited by hand, and --check proves an existing
# kit is still faithful.
#
# Edit www/<distro>/. Then re-run this. Never edit www/<distro>_local/.
# ============================================================================
#
# WHY KITS ARE NEEDED AT ALL
#
# The script server is 192.168.1.195 -- a VMware guest on the Z8 workstation. Any
# build that needs that same physical box to be doing something else (dual-boot,
# reinstall) cannot fetch from it, because the server and the client are one
# machine. No ordering fixes that; the scripts have to be carried in.
#
# ⚠️ UBUNTU CARRIES A FILE FEDORA DOES NOT: anysphere.gpg. Cursor's official apt
# key URL 403s, so the Ubuntu tree mirrors it. A kit without it leaves Cursor's
# repo unverifiable. The file list is read from each host_setup.sh rather than
# hardcoded here, so a future asset is picked up automatically instead of being
# silently dropped -- which is exactly how the key would otherwise be missed.

set -u

WITH_CREDS=0
CHECK_ONLY=0
WANT=""

usage() {
    echo "Usage: ./make_local_kits.sh [fedora|ubuntu] [--with-creds] [--check]"
    echo "  (no distro)    build both"
    echo "  --with-creds   also copy www/smb_credentials into each kit (PLAINTEXT)"
    echo "  --check        verify kits match their source trees, change nothing"
}

while [ $# -gt 0 ]; do
    case "$1" in
        fedora|ubuntu) WANT="$WANT $1" ;;
        --with-creds)  WITH_CREDS=1 ;;
        --check)       CHECK_ONLY=1 ;;
        -h|--help)     usage; exit 0 ;;
        *) echo "ERROR: unknown option '$1'"; usage; exit 1 ;;
    esac
    shift
done
[ -n "$WANT" ] || WANT="fedora ubuntu"

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

# Read the manifest from the orchestrator itself. Hardcoding it here would mean
# two lists to keep in step, which is the same drift bug this script exists to
# prevent -- one level up.
manifest() {
    local src="$1"
    local list
    list=$(grep -m1 '^SCRIPTS=' "$src/host_setup.sh" | cut -d'"' -f2)
    if [ -z "$list" ]; then
        echo "ERROR: could not read SCRIPTS= from $src/host_setup.sh" >&2
        return 1
    fi
    echo "host_setup.sh $list"
}

RC=0

for distro in $WANT; do
    SRC="$distro"
    DST="${distro}_local"

    echo "=============================================="
    echo " $distro"
    echo "=============================================="

    if [ ! -d "$SRC" ]; then
        echo "  ERROR: $SRC/ not found."
        RC=1; continue
    fi

    FILES=$(manifest "$SRC") || { RC=1; continue; }

    # ---- check mode --------------------------------------------------------
    if [ "$CHECK_ONLY" -eq 1 ]; then
        if [ ! -d "$DST" ]; then
            echo "  no $DST/ yet -- run without --check to create it"
            RC=1; continue
        fi
        DRIFT=0
        for f in $FILES; do
            if [ ! -f "$DST/$f" ]; then
                echo "  MISSING  $f"; DRIFT=1
            elif ! cmp -s "$SRC/$f" "$DST/$f"; then
                echo "  DRIFTED  $f"; DRIFT=1
            else
                echo "  ok       $f"
            fi
        done
        if [ "$DRIFT" -eq 1 ]; then
            echo "  KIT IS STALE -- re-run: ./make_local_kits.sh $distro"
            RC=1
        else
            echo "  kit matches $SRC/ exactly"
        fi
        echo ""
        continue
    fi

    # ---- build -------------------------------------------------------------
    mkdir -p "$DST"
    BAD=0
    for f in $FILES; do
        if [ ! -s "$SRC/$f" ]; then
            echo "  ERROR: $SRC/$f missing or empty"; BAD=1; continue
        fi
        cp -f "$SRC/$f" "$DST/$f"
        chmod +x "$DST/$f" 2>/dev/null || true
        printf '  copied  %-22s %s bytes\n' "$f" "$(wc -c < "$DST/$f")"
    done
    if [ "$BAD" -eq 1 ]; then
        echo "  ERROR: source tree incomplete -- kit NOT usable"
        RC=1; continue
    fi

    # ---- credentials (opt-in) ----------------------------------------------
    # setup_smb_mount.sh's lookup chain checks "$SCRIPT_DIR/smb_credentials" as
    # well as "../smb_credentials", so a single flat kit folder is valid and is
    # much easier to copy correctly than a two-level layout.
    if [ "$WITH_CREDS" -eq 1 ]; then
        if [ -f "smb_credentials" ]; then
            cp -f "smb_credentials" "$DST/smb_credentials"
            chmod 600 "$DST/smb_credentials" 2>/dev/null || true
            echo "  copied  smb_credentials         (PLAINTEXT NAS PASSWORD)"
        else
            echo "  WARN: www/smb_credentials not found -- kit built without it;"
            echo "        setup_smb_mount.sh will prompt for the password."
        fi
    else
        rm -f "$DST/smb_credentials"
        echo "  no credentials (use --with-creds); the script will prompt instead"
    fi

    # ---- verify the kit is genuinely self-contained -------------------------
    KIT_OK=1
    NEED=$(grep -m1 '^SCRIPTS=' "$DST/host_setup.sh" | cut -d'"' -f2)
    for f in $NEED; do
        [ -s "$DST/$f" ] || { echo "  FAIL  $f missing -- it would be downloaded"; KIT_OK=0; }
    done
    grep -q 'OFFLINE MODE' "$DST/host_setup.sh" \
        || { echo "  FAIL  host_setup.sh has no offline branch"; KIT_OK=0; }

    if [ "$KIT_OK" -ne 1 ]; then
        echo "  KIT IS NOT SELF-CONTAINED -- do not ship it"
        RC=1
    else
        echo "  verified self-contained ($(echo $NEED | wc -w) required files present, offline branch OK)"
    fi
    echo ""
done

if [ "$CHECK_ONLY" -eq 1 ]; then
    exit "$RC"
fi

if [ "$WITH_CREDS" -eq 1 ] && [ "$RC" -eq 0 ]; then
    cat <<'EOF'
!! The kits contain a real credential (the NAS password, plaintext).
!! On a FAT32/exFAT USB stick the 0600 mode will NOT stick -- those filesystems
!! have no Unix permissions, so it is readable by anything that mounts it.
!! Treat the USB as a secret, or rebuild without --with-creds.

EOF
fi

if [ "$RC" -eq 0 ]; then
    cat <<'EOF'
Kits ready. Copy the whole folder to the USB stick, then on the new machine:

    cp -r /run/media/$USER/<LABEL>/fedora_local ~/fedora_local
    cd ~/fedora_local
    bash host_setup.sh --hostname AGAMACHE-FEDORA-WKS

It prints "OFFLINE MODE" and contacts nothing on the lab network.
Internet is still required for Docker, Chrome and Cursor (public repos).
EOF
fi

exit "$RC"
