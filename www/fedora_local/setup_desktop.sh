#!/bin/bash
#
# setup_desktop.sh - Configure a Fedora host for VM use
#
# Usage: ./setup_desktop.sh [--server]   (run as the regular user, NOT sudo)
#
# ============================================================================
# --server  (added Aug 21, 2026, matching www/ubuntu/setup_desktop.sh)
#
# Headless host: skips Chrome, Cursor, the resolution and GNOME steps, the
# terminal profile, the dock, the keyring, the GDM greeter config and autologin.
#
# It KEEPS four things, and one of them is not obvious:
#   - timezone, DNS, CLI tools, shell aliases  -- wanted everywhere
#   - MASKING THE SYSTEMD SLEEP TARGETS        -- wanted MORE on a server
# A server that suspends is worse than a desktop that suspends: nobody is
# sitting in front of it to wiggle the mouse. So the enforcement half of step 13
# runs in both modes and only the GDM-greeter half, which needs a greeter to
# apply to, is skipped.
#
# The D-Bus session bus requirement below is also lifted in server mode, because
# nothing in server mode touches gsettings -- and a headless host has no session
# bus, so requiring one would make --server refuse to run on exactly the
# machines it exists for.
#
# ⭐ Unlike Ubuntu, the Fedora orchestrator NEVER had the "gsettings implies a
# desktop" bug: its gate has always tested `gnome-shell` alone. So no Fedora host
# was ever given Chrome and Cursor by accident. --server here is for explicit
# control and parity, not a repair.
# ============================================================================
#
# Fedora counterpart of www/ubuntu/setup_desktop.sh. This is the script that is
# mostly a REWRITE rather than a translation, because Fedora ships vanilla GNOME
# and Ubuntu does not.
#
# ============================================================================
# THE DESIGN RULE FOR THIS FILE, AND WHY IT DIFFERS FROM THE UBUNTU ORIGINAL
#
# Every gsettings call in the Ubuntu script ends in `2>/dev/null || true`, and
# its closing summary prints a hardcoded checkmark for all twelve steps. On
# Ubuntu that is merely untidy. On Fedora it would be actively dishonest: three
# of the schemas it writes to DO NOT EXIST here (measured on .196 Aug 21 2026 --
# dash-to-dock, ding and desktop-icons are all absent from a stock install), so
# the writes fail, the errors are swallowed, and the script prints
#     "Home folder: Hidden"  and  "Dock panel mode: Disabled"
# having changed nothing whatsoever.
#
# A false green in our own tooling is worse than a red, because a red gets
# investigated. So in this script:
#   - every setting is written and then READ BACK, and
#   - the summary reports what was measured: OK / SKIP / FAIL, never a constant.
# A SKIP with a stated reason is a perfectly good outcome. A fake OK is not.
# ============================================================================
#

SERVER_MODE=0
for arg in "$@"; do
    case "$arg" in
        --server) SERVER_MODE=1 ;;
        -h|--help)
            echo "Usage: ./setup_desktop.sh [--server]"
            echo "  --server   headless host: skip Chrome, Cursor, GNOME settings,"
            echo "             keyring and autologin. Keeps timezone, DNS, CLI"
            echo "             tools, aliases and the systemd sleep masking."
            exit 0 ;;
        *)
            echo "ERROR: unknown option '$arg'"
            echo "Usage: ./setup_desktop.sh [--server]"
            exit 1 ;;
    esac
done

echo "=========================================="
if [ "$SERVER_MODE" -eq 1 ]; then
    echo "Fedora SERVER Configuration (--server)"
    echo "=========================================="
    echo "Skipping Chrome, Cursor, GNOME settings, keyring, autologin."
    echo "Doing: timezone, DNS, CLI tools, aliases, sleep masking."
else
    echo "Fedora Workstation Configuration"
fi
echo "=========================================="

if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Run as the regular user, not root."
    echo "       gsettings/dconf write to YOUR session; as root they would go to"
    echo "       root's profile and silently do nothing for you."
    echo "Usage: ./setup_desktop.sh [--server]"
    exit 1
fi

# ---------------------------------------------------------------------------
# A session bus is mandatory. Over SSH there is no DBUS_SESSION_BUS_ADDRESS, and
# without it gsettings falls back to a memory backend: every write "succeeds"
# and every value evaporates when the process exits. That is the purest possible
# false green, so refuse to run rather than produce one.
# ---------------------------------------------------------------------------
#
# Server mode is EXEMPT, and must be: a headless host has no session bus, and
# nothing in server mode touches gsettings. Enforcing the requirement there would
# make --server refuse to run on precisely the machines it was added for.
if [ "$SERVER_MODE" -eq 0 ] && [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    BUS_PATH="/run/user/$(id -u)/bus"
    if [ -S "$BUS_PATH" ]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=${BUS_PATH}"
        echo "Attached to the existing session bus at $BUS_PATH"
    else
        echo ""
        echo "ERROR: no D-Bus session bus found at $BUS_PATH."
        echo "       gsettings would silently write to a throwaway memory backend"
        echo "       and report success while changing nothing."
        echo ""
        echo "       Log in to the desktop at least once, then re-run this script."
        echo "       If this host has no desktop at all, use --server."
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Result tracking. Nothing prints a checkmark it did not earn.
# ---------------------------------------------------------------------------
RESULTS=()
res_ok()   { RESULTS+=("  [ OK ]  $1"); }
res_skip() { RESULTS+=("  [SKIP]  $1"); }
res_fail() { RESULTS+=("  [FAIL]  $1"); }

# Strip quotes and whitespace so 'list-view' and list-view compare equal.
_norm() { printf '%s' "$1" | tr -d "[:space:]'\"" ; }

schema_exists() { gsettings list-schemas 2>/dev/null | grep -qx "$1"; }

# ---------------------------------------------------------------------------
# Install with dnf, quiet on success and USEFUL on failure.
#
# The design rule of this file cuts both ways. Sending dnf to /dev/null keeps a
# clean run readable, but it also means a [FAIL] line arrives with no cause
# attached -- which is unactionable, in the one script whose whole purpose is
# honest reporting. So the transcript is CAPTURED rather than discarded, and the
# lines that explain the failure are printed when there is one.
# ---------------------------------------------------------------------------
DNF_LOG=""
dnf_install() {
    DNF_LOG=$(sudo dnf install -y "$@" 2>&1)
}

# Print the part of the last dnf transcript that says why it failed.
dnf_why() {
    printf '%s\n' "$DNF_LOG" \
        | grep -Ei 'error|cannot|conflict|nothing provides|no match|problem|failure' \
        | tail -5 | sed 's/^/          /'
    printf '%s\n' "          (full transcript: re-run 'sudo dnf install <pkg>' by hand)"
}

# gset <schema> <key> <value> <label>
# Writes, reads back, and records the MEASURED outcome.
gset() {
    local schema="$1" key="$2" value="$3" label="$4"

    if ! schema_exists "$schema"; then
        res_skip "$label -- schema '$schema' not present on this system"
        echo "    SKIP: $label (no schema $schema)"
        return 1
    fi

    if ! gsettings set "$schema" "$key" "$value" 2>/dev/null; then
        res_fail "$label -- gsettings set rejected the value"
        echo "    FAIL: $label (set rejected)"
        return 1
    fi

    local got
    got=$(gsettings get "$schema" "$key" 2>/dev/null)
    if [ "$(_norm "$got")" = "$(_norm "$value")" ]; then
        res_ok "$label"
        echo "    OK:   $label"
        return 0
    fi

    res_fail "$label -- wrote '$value' but read back '$got'"
    echo "    FAIL: $label (read back '$got')"
    return 1
}

# Generated step labels, matching the Ubuntu script. Two modes with different
# step counts is exactly the situation where hand-written "[4/14]" labels drift.
if [ "$SERVER_MODE" -eq 1 ]; then STEP_TOTAL=5; else STEP_TOTAL=14; fi
STEP_N=0
step() {
    STEP_N=$((STEP_N + 1))
    echo ""
    echo "[$STEP_N/$STEP_TOTAL] $1"
}

# ===========================================================================
step "Setting timezone to America/New_York..."
if sudo timedatectl set-timezone America/New_York 2>/dev/null; then
    NOW_TZ=$(timedatectl show -p Timezone --value)
    if [ "$NOW_TZ" = "America/New_York" ]; then
        res_ok "Timezone: America/New_York"
        echo "    OK:   timezone is now $NOW_TZ"
    else
        res_fail "Timezone -- requested America/New_York, system reports $NOW_TZ"
        echo "    FAIL: timezone reads $NOW_TZ"
    fi
else
    res_fail "Timezone -- timedatectl call failed"
    echo "    FAIL: could not set timezone"
fi

# ===========================================================================
step "Setting DNS to Google (8.8.8.8) + Cloudflare (1.1.1.1)..."
# NetworkManager is genuinely the network stack on Fedora Workstation, so unlike
# on an Ubuntu server this is the correct and only place to set DNS.
CONN_NAME=$(nmcli -t -f NAME,DEVICE con show --active | grep -v '^lo:' | head -1 | cut -d: -f1)
if [ -n "$CONN_NAME" ]; then
    sudo nmcli con mod "$CONN_NAME" ipv4.dns "8.8.8.8 1.1.1.1"
    sudo nmcli con mod "$CONN_NAME" ipv4.ignore-auto-dns yes

    # Do NOT `con down` then `con up` over SSH -- that drops the link this script
    # is running over. The Ubuntu original does exactly that and gets away with it
    # only because it is normally run at the console. `reapply` applies the change
    # in place without bouncing the interface.
    sudo nmcli dev reapply "$(nmcli -t -f NAME,DEVICE con show --active | grep -v '^lo:' | head -1 | cut -d: -f2)" 2>/dev/null || true

    APPLIED=$(nmcli -g ipv4.dns con show "$CONN_NAME")
    if [ "$APPLIED" = "8.8.8.8,1.1.1.1" ]; then
        res_ok "DNS: 8.8.8.8 + 1.1.1.1 on '$CONN_NAME'"
        echo "    OK:   connection '$CONN_NAME' now has $APPLIED"
    else
        res_fail "DNS -- connection reports '$APPLIED'"
        echo "    FAIL: reads back '$APPLIED'"
    fi
else
    res_fail "DNS -- no active connection detected"
    echo "    FAIL: could not detect active connection"
fi

# ===========================================================================
step "Installing CLI tools..."
# Package name differences from Ubuntu: `vim` is vim-enhanced on Fedora (only
# vim-minimal ships by default). curl, jq, tree, unzip, net-tools and cifs-utils
# are already present on a stock Workstation install.
#
# NOTE: dnf fails the WHOLE transaction if any one name is unavailable, so a
# single bad package name silently costs you every tool in this list. That is
# why the loop below checks each binary individually instead of trusting the
# install to have done what was asked.
CLI_PKGS="curl wget htop btop vim-enhanced jq net-tools tree unzip sysbench"
if dnf_install $CLI_PKGS; then
    MISSING=""
    for c in curl wget htop btop vim jq netstat tree unzip sysbench; do
        command -v "$c" >/dev/null 2>&1 || MISSING="$MISSING $c"
    done
    if [ -z "$MISSING" ]; then
        res_ok "CLI tools: curl wget htop btop vim jq net-tools tree unzip sysbench"
        echo "    OK:   all CLI tools present"
    else
        res_fail "CLI tools -- still missing:$MISSING"
        echo "    FAIL: missing$MISSING"
    fi
else
    res_fail "CLI tools -- dnf install failed"
    echo "    FAIL: dnf install failed"
    dnf_why
fi

# ===========================================================================
# ===========================================================================
# DESKTOP-ONLY STEPS BEGIN HERE (Chrome through autologin, minus the aliases and
# the sleep masking, which are pulled out below because both modes want them).
#
# One `if` around the whole run rather than a guard per step: with ten steps that
# would be ten chances to forget one, and forgetting one means a headless host
# quietly acquires a browser again.
# ===========================================================================
if [ "$SERVER_MODE" -eq 1 ]; then
echo ""
echo "--- Skipping desktop-only steps (--server) ---"
echo "    Chrome, Cursor, resolution, GNOME settings, terminal profile,"
echo "    dock, keyring, GDM greeter config, autologin."
res_skip "Chrome, Cursor and all GNOME/GDM configuration -- skipped (--server)"
else

step "Installing Google Chrome..."
# Easier than Ubuntu: Google ships an RPM that registers its own yum repo, so
# there is no manual key/repo dance and no dpkg dependency repair step.
if command -v google-chrome >/dev/null 2>&1; then
    res_ok "Google Chrome: already installed ($(google-chrome --version 2>/dev/null))"
    echo "    OK:   already installed"
else
    if dnf_install https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm \
       && command -v google-chrome >/dev/null 2>&1; then
        res_ok "Google Chrome: $(google-chrome --version 2>/dev/null)"
        echo "    OK:   installed"
    else
        res_fail "Google Chrome -- install failed"
        echo "    FAIL: install failed"
        dnf_why
    fi
fi

# ===========================================================================
step "Installing Cursor..."
# Worth noting: the Ubuntu build cannot fetch Cursor's apt key directly (it 403s,
# so the key is mirrored on the script server at 192.168.1.195). The Fedora side
# has no such problem -- both the RPM repo and the key return HTTP 200, verified
# Aug 21 2026 -- so we point straight at the official source.
if command -v cursor >/dev/null 2>&1; then
    res_ok "Cursor: already installed"
    echo "    OK:   already installed"
else
    sudo tee /etc/yum.repos.d/cursor.repo >/dev/null <<'REPO'
[cursor]
name=Cursor
baseurl=https://downloads.cursor.com/yumrepo
enabled=1
gpgcheck=1
gpgkey=https://downloads.cursor.com/keys/anysphere.asc
REPO
    if dnf_install cursor && command -v cursor >/dev/null 2>&1; then
        res_ok "Cursor: installed from the official DNF repo"
        echo "    OK:   installed"
    else
        res_fail "Cursor -- install failed (check /etc/yum.repos.d/cursor.repo)"
        echo "    FAIL: install failed"
        dnf_why
    fi
fi

# The Ubuntu script writes an AppArmor profile here so Cursor's sandbox can use
# unprivileged user namespaces. Fedora has no AppArmor -- it uses SELinux, and
# unprivileged userns are permitted by default. Measure instead of assuming.
USERNS_MAX=$(sysctl -n user.max_user_namespaces 2>/dev/null || echo 0)
if [ "${USERNS_MAX:-0}" -gt 0 ]; then
    res_ok "Cursor sandbox: unprivileged userns allowed (max=$USERNS_MAX), no profile needed"
    echo "    OK:   userns permitted (Fedora needs no AppArmor equivalent)"
else
    res_fail "Cursor sandbox: user.max_user_namespaces=$USERNS_MAX -- sandbox may fail"
    echo "    FAIL: userns disabled"
fi

# ===========================================================================
step "Display resolution..."
# The Ubuntu step drives xrandr and then writes an autostart entry pinning
# `--output Virtual-1`. Neither works here, for two independent reasons:
#   1. This session is WAYLAND. xrandr only sees XWayland and cannot set a mode.
#   2. open-vm-tools-desktop is installed, so the VMware SVGA driver resizes the
#      guest to fit the window automatically -- which is what you actually want.
# Writing a permanently-dead autostart entry so the summary can claim
# "Resolution: 1920x1080" is precisely the false green this file exists to avoid.
# Find the GRAPHICAL session, not merely the first one listed. Taking the first
# reported 'tty' when this script was run over SSH, which made the summary line
# claim a tty session on a machine sitting at a Wayland desktop.
SESSION_TYPE=""
for _s in $(loginctl --no-legend list-sessions | tr -s ' ' | sed 's/^ //' | cut -d' ' -f1); do
    _t=$(loginctl show-session "$_s" -p Type --value 2>/dev/null)
    case "$_t" in wayland|x11) SESSION_TYPE="$_t"; break ;; esac
done
[ -n "$SESSION_TYPE" ] || SESSION_TYPE="no graphical session found"
if rpm -q --quiet open-vm-tools-desktop; then
    res_skip "Resolution: not forced -- VMware guest auto-fit handles it (session=${SESSION_TYPE:-unknown})"
    echo "    SKIP: open-vm-tools-desktop present; the display follows the VMware window"
    echo "          Set the size by resizing the VMware window, or in GNOME Settings > Displays."
else
    res_skip "Resolution: not forced -- Wayland session, xrandr cannot set modes"
    echo "    SKIP: Wayland session; use GNOME Settings > Displays"
fi

# ===========================================================================
step "Desktop icons and file manager..."
# Fedora ships vanilla GNOME: there is no desktop-icons extension at all, so
# there is no Home icon to hide. The Ubuntu script's goal (no Home icon on the
# desktop) is already satisfied -- by absence rather than by configuration.
if schema_exists org.gnome.shell.extensions.ding; then
    gset org.gnome.shell.extensions.ding show-home false "Desktop: Home icon hidden"
else
    res_skip "Desktop: no Home icon to hide -- vanilla GNOME has no desktop icons"
    echo "    SKIP: no desktop-icons extension on Fedora; nothing is drawn on the desktop"
fi

gset org.gnome.nautilus.preferences default-folder-viewer "'list-view'" "Files: list view"
gset org.gtk.Settings.FileChooser show-hidden true "Files: show hidden files"

# ===========================================================================
step "Disabling screen lock and screen saver..."
gset org.gnome.desktop.screensaver lock-enabled false "Screen lock disabled"
gset org.gnome.desktop.session idle-delay "uint32 0" "Idle timeout disabled"
gset org.gnome.desktop.screensaver idle-activation-enabled false "Screensaver disabled"
gset org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type "'nothing'" "Never sleep on AC"
gset org.gnome.settings-daemon.plugins.power idle-dim false "Never dim when idle"
# A VM has no battery, so this key looks irrelevant -- but it ships as 'suspend',
# and if upower ever reports a battery (some hypervisor configs present one) that
# becomes the active policy. Cheap to close.
gset org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type "'nothing'" "Never sleep on battery"
# org.gnome.desktop.screensaver ubuntu-lock-on-suspend is an Ubuntu downstream
# patch and does not exist here; deliberately not attempted.

# ===========================================================================
step "Creating the 'Andrew' terminal profile..."
# Fedora replaced GNOME Terminal with Ptyxis in F41, and Ptyxis has a completely
# different settings model (org.gnome.Ptyxis, no dconf legacy profile tree). To
# keep the terminal identical to every other box in the lab we install
# gnome-terminal and reuse the exact same profile definition. Ptyxis is left
# installed as the system default; this adds a second terminal, it removes nothing.
if ! rpm -q --quiet gnome-terminal; then
    echo "    Installing gnome-terminal (Fedora ships Ptyxis instead)..."
    dnf_install gnome-terminal || dnf_why
fi

if schema_exists org.gnome.Terminal.ProfilesList; then
    PROFILE_UUID=""
    if dconf dump /org/gnome/terminal/legacy/profiles:/ 2>/dev/null | grep -q "visible-name='Andrew'"; then
        PROFILE_UUID=$(dconf dump /org/gnome/terminal/legacy/profiles:/ \
                        | grep -B30 "visible-name='Andrew'" \
                        | grep "^\[:" | tail -1 | tr -d '[]:')
        echo "    'Andrew' profile already exists ($PROFILE_UUID)"
    else
        PROFILE_UUID=$(uuidgen)
        EXISTING=$(gsettings get org.gnome.Terminal.ProfilesList list 2>/dev/null)
        if [ "$EXISTING" = "@as []" ] || [ -z "$EXISTING" ]; then
            gsettings set org.gnome.Terminal.ProfilesList list "['$PROFILE_UUID']"
        else
            gsettings set org.gnome.Terminal.ProfilesList list \
                "$(echo "$EXISTING" | sed "s/]$/, '$PROFILE_UUID']/")"
        fi
    fi

    gsettings set org.gnome.Terminal.ProfilesList default "$PROFILE_UUID"
    P="/org/gnome/terminal/legacy/profiles:/:$PROFILE_UUID/"
    dconf write ${P}visible-name "'Andrew'"
    dconf write ${P}background-color "'rgb(22,23,21)'"
    dconf write ${P}foreground-color "'rgb(221,217,234)'"
    dconf write ${P}background-transparency-percent "15"
    dconf write ${P}use-transparent-background "true"
    dconf write ${P}use-theme-colors "false"
    dconf write ${P}use-theme-transparency "false"
    dconf write ${P}bold-color-same-as-fg "true"
    dconf write ${P}bold-is-bright "true"
    dconf write ${P}cursor-blink-mode "'on'"
    dconf write ${P}default-size-columns "200"
    dconf write ${P}default-size-rows "50"
    dconf write ${P}scroll-on-output "true"
    dconf write ${P}palette "['rgb(46,52,54)', 'rgb(204,0,0)', 'rgb(78,154,6)', 'rgb(196,160,0)', 'rgb(52,101,164)', 'rgb(117,80,123)', 'rgb(6,152,154)', 'rgb(211,215,207)', 'rgb(85,87,83)', 'rgb(239,41,41)', 'rgb(138,226,52)', 'rgb(252,233,79)', 'rgb(114,159,207)', 'rgb(173,127,168)', 'rgb(52,226,226)', 'rgb(238,238,236)']"

    READBACK=$(dconf read ${P}visible-name 2>/dev/null)
    if [ "$(_norm "$READBACK")" = "Andrew" ]; then
        res_ok "Terminal: 'Andrew' profile (200x50, transparent dark) via gnome-terminal"
        echo "    OK:   profile written and verified"
    else
        res_fail "Terminal -- profile written but visible-name reads '$READBACK'"
        echo "    FAIL: read back '$READBACK'"
    fi
else
    res_fail "Terminal -- gnome-terminal install did not provide org.gnome.Terminal.ProfilesList"
    echo "    FAIL: schema still absent"
fi

# ===========================================================================
step "Configuring the dock..."
# Vanilla GNOME has no always-visible dock; Ubuntu patches in dash-to-dock. It is
# packaged in Fedora, so install it and enable it to match the Ubuntu layout.
DTD_UUID="dash-to-dock@micxgx.gmail.com"
if ! rpm -q --quiet gnome-shell-extension-dash-to-dock; then
    echo "    Installing gnome-shell-extension-dash-to-dock..."
    dnf_install gnome-shell-extension-dash-to-dock || dnf_why
fi

DTD_DIR="/usr/share/gnome-shell/extensions/$DTD_UUID"
if [ -d "$DTD_DIR" ]; then

    # Refuse to enable an extension the running Shell cannot load. An
    # incompatible extension is silently ignored at login, which looks exactly
    # like this script having done nothing.
    SHELL_MAJOR=$(gnome-shell --version | awk '{print $3}' | cut -d. -f1)
    if jq -e --arg v "$SHELL_MAJOR" '.["shell-version"] | index($v)' "$DTD_DIR/metadata.json" >/dev/null 2>&1; then
        echo "    dash-to-dock v$(jq -r .version "$DTD_DIR/metadata.json") supports GNOME $SHELL_MAJOR"

        # --------------------------------------------------------------------
        # Do NOT use `gnome-extensions enable` here. It is a RUNTIME api: it asks
        # the RUNNING gnome-shell over D-Bus, and the shell only scans the
        # extensions directory at startup. An extension installed seconds ago
        # therefore reports
        #     Extension "dash-to-dock@micxgx.gmail.com" doesn't exist
        # even though the files are on disk and the version is compatible. That
        # is what happened on the first run of this script (Aug 21 2026).
        #
        # org.gnome.shell enabled-extensions is the durable CONFIGURATION the
        # shell reads at startup, so writing it works from an SSH session and
        # survives to the next login -- which is when the dock appears anyway,
        # since a Wayland shell cannot be restarted in place.
        # --------------------------------------------------------------------
        CUR=$(gsettings get org.gnome.shell enabled-extensions)
        if printf '%s' "$CUR" | grep -q "$DTD_UUID"; then
            echo "    already in enabled-extensions"
        elif [ "$CUR" = "@as []" ]; then
            gsettings set org.gnome.shell enabled-extensions "['$DTD_UUID']"
        else
            gsettings set org.gnome.shell enabled-extensions \
                "$(printf '%s' "$CUR" | sed "s/]$/, '$DTD_UUID']/")"
        fi

        if gsettings get org.gnome.shell enabled-extensions | grep -q "$DTD_UUID"; then
            res_ok "Dock: dash-to-dock enabled (appears after next login)"
            echo "    OK:   listed in enabled-extensions"
        else
            res_fail "Dock: could not add dash-to-dock to enabled-extensions"
            echo "    FAIL: not listed after write"
        fi
    else
        res_fail "Dock: dash-to-dock does not support GNOME $SHELL_MAJOR"
        echo "    FAIL: version mismatch, refusing to enable"
    fi

    # dash-to-dock ships its own schema, so these keys only exist once the
    # package is installed -- which is why they are set after, never before.
    gset org.gnome.shell.extensions.dash-to-dock extend-height false "Dock: floating (panel mode off)"
    gset org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 32 "Dock: 32px icons"
    # Upstream dash-to-dock defaults to BOTTOM. Ubuntu patches the default to LEFT,
    # which is why the Ubuntu script never sets this key and why the Fedora dock
    # came up on the bottom edge looking wrong. Set it explicitly rather than
    # inheriting whichever default the distro happens to ship.
    gset org.gnome.shell.extensions.dash-to-dock dock-position "'LEFT'" "Dock: on the left edge"
else
    res_fail "Dock: dash-to-dock package did not install"
    echo "    FAIL: extension directory missing"
fi

# Pin only apps that ACTUALLY EXIST. GNOME silently drops favourites pointing at
# a missing .desktop, so `gsettings set` succeeds and the dock just quietly shows
# fewer icons. Note the Fedora IDs differ from Ubuntu's: Firefox is
# org.mozilla.firefox.desktop here, not the snap's firefox_firefox.desktop.
WANTED=(org.gnome.Nautilus.desktop google-chrome.desktop org.mozilla.firefox.desktop \
        cursor.desktop org.gnome.Terminal.desktop org.gnome.SystemMonitor.desktop \
        org.gnome.Settings.desktop org.gnome.TextEditor.desktop)
PRESENT=()
DROPPED=()
for app in "${WANTED[@]}"; do
    if [ -f "/usr/share/applications/$app" ] || [ -f "$HOME/.local/share/applications/$app" ]; then
        PRESENT+=("'$app'")
    else
        DROPPED+=("$app")
    fi
done
FAV_LIST="[$(IFS=,; echo "${PRESENT[*]}")]"
gset org.gnome.shell favorite-apps "$FAV_LIST" "Dock icons: ${#PRESENT[@]} pinned"
if [ ${#DROPPED[@]} -gt 0 ]; then
    echo "    NOTE: not pinned because no .desktop file exists: ${DROPPED[*]}"
    RESULTS+=("  [NOTE]  Dock: skipped missing apps -- ${DROPPED[*]}")
fi

# ===========================================================================
step "Disabling the login keyring prompt..."
mkdir -p ~/.local/share/keyrings
rm -f ~/.local/share/keyrings/login.keyring ~/.local/share/keyrings/user.keystore
echo "login" > ~/.local/share/keyrings/default
if [ "$(cat ~/.local/share/keyrings/default 2>/dev/null)" = "login" ]; then
    res_ok "Keyring: default set to 'login' with no password (auto-unlock)"
    echo "    OK:   keyring reset"
else
    res_fail "Keyring -- could not write ~/.local/share/keyrings/default"
    echo "    FAIL: write failed"
fi

fi   # ← end of the desktop-only block opened before Chrome (--server skips it)

# ===========================================================================
# BOTH MODES AGAIN from here down.
# ===========================================================================
step "Adding bash aliases..."
BASHRC="$HOME/.bashrc"
add_alias() {
    local name="$1" body="$2"
    if grep -q "alias ${name}=" "$BASHRC" 2>/dev/null; then
        echo "    alias $name already present"
        return 0
    fi
    printf '%s\n' "$body" >> "$BASHRC"
    grep -q "alias ${name}=" "$BASHRC"
}

grep -q "# Custom aliases added by setup_desktop.sh" "$BASHRC" 2>/dev/null || \
    printf '\n# Custom aliases added by setup_desktop.sh\n' >> "$BASHRC"

ALIAS_OK=1
add_alias godev    "alias godev='cd ~/DevShare'" || ALIAS_OK=0
# The one alias whose BODY genuinely differs from Ubuntu's apt version.
add_alias update   "alias update='sudo dnf upgrade --refresh -y'" || ALIAS_OK=0
add_alias sysbench "alias sysbench='sysbench --threads=\$(nproc) cpu run'" || ALIAS_OK=0

if [ "$ALIAS_OK" = "1" ]; then
    res_ok "Aliases: godev, update (dnf), sysbench"
    echo "    OK:   aliases present in ~/.bashrc"
else
    res_fail "Aliases -- one or more could not be added to $BASHRC"
    echo "    FAIL: alias write failed"
fi

# ===========================================================================
if [ "$SERVER_MODE" -eq 1 ]; then
    step "Preventing sleep at the SYSTEM level..."
else
    step "Preventing sleep at the SYSTEM and LOGIN-SCREEN level..."
fi
#
# ⭐ THIS STEP RUNS IN SERVER MODE TOO, which is worth stating because it is the
# one desktop-looking step that a headless host needs MORE, not less: a server
# that suspends has nobody sitting in front of it to wake it up. Only the GDM
# greeter half below is skipped, because it configures a greeter that a headless
# host does not run.
#
# Step 8 already disabled sleep for THIS user's session, and those settings read
# back correctly -- yet the machine still showed a sleep screen. Two reasons, and
# neither is reachable from the user's gsettings:
#
#   1. THE LOGIN SCREEN IS A DIFFERENT USER. GDM's greeter runs as the `gdm` user
#      with its own dconf profile. Nothing you set in Andrew's session applies to
#      it, so the machine blanks while sitting at the login screen. This is the
#      one that actually bites on a VM you leave at the greeter.
#   2. gsettings are POLICY, not enforcement. systemd's sleep targets are still
#      reachable, so anything that asks for suspend still gets it.
#
# Masking the targets is the enforcement layer: a masked target cannot be started
# by anyone, including logind and including a stray `systemctl suspend`.

SLEEP_TARGETS="sleep.target suspend.target hibernate.target hybrid-sleep.target"
sudo systemctl mask $SLEEP_TARGETS >/dev/null 2>&1
MASK_FAIL=""
for t in $SLEEP_TARGETS; do
    [ "$(systemctl is-enabled "$t" 2>/dev/null)" = "masked" ] || MASK_FAIL="$MASK_FAIL $t"
done
if [ -z "$MASK_FAIL" ]; then
    res_ok "Suspend/hibernate masked at systemd level (cannot be started at all)"
    echo "    OK:   all four sleep targets report 'masked'"
else
    res_fail "Sleep targets NOT masked:$MASK_FAIL"
    echo "    FAIL: not masked:$MASK_FAIL"
fi

# The GDM greeter's own dconf database. `dconf update` compiles /etc/dconf/db/gdm.d/
# into the binary db the greeter reads at start.
#
# Desktop only: there is no greeter to configure on a headless host, and writing
# an /etc/dconf profile for a display manager that is not installed would be
# clutter that looks like configuration.
if [ "$SERVER_MODE" -eq 1 ]; then
    echo "    SKIP: GDM greeter config (--server, no greeter on this host)"
    res_skip "GDM greeter sleep settings -- skipped (--server)"
else
sudo install -d /etc/dconf/profile /etc/dconf/db/gdm.d
if [ ! -f /etc/dconf/profile/gdm ]; then
    printf 'user-db:user\nsystem-db:gdm\n' | sudo tee /etc/dconf/profile/gdm >/dev/null
fi
sudo tee /etc/dconf/db/gdm.d/01-lab-no-sleep >/dev/null <<'GDMCONF'
# Lab standard: the login screen must never blank, dim or suspend.
# The greeter runs as the `gdm` user, so the desktop user's settings do not apply.
[org/gnome/desktop/session]
idle-delay=uint32 0

[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-type='nothing'
sleep-inactive-battery-type='nothing'
idle-dim=false

[org/gnome/desktop/screensaver]
idle-activation-enabled=false
lock-enabled=false
GDMCONF

if sudo dconf update 2>/dev/null && [ -f /etc/dconf/db/gdm ]; then
    res_ok "Login screen (GDM greeter) will not blank or sleep"
    echo "    OK:   /etc/dconf/db/gdm compiled"
else
    res_fail "GDM greeter sleep settings -- dconf update failed"
    echo "    FAIL: dconf update failed or /etc/dconf/db/gdm missing"
fi
fi   # ← end of the greeter-only half of this step

# ===========================================================================
if [ "$SERVER_MODE" -eq 1 ]; then
    echo ""
    echo "--- Skipping autologin (--server) ---"
    echo "    A headless host has no graphical session to log in to, and enabling"
    echo "    autologin on a server would be a security downgrade for no benefit."
    res_skip "Autologin -- skipped (--server)"
else
step "Enabling passwordless automatic login at boot..."
#
# This works cleanly ONLY because step 11 reset the login keyring to no password.
# With autologin and a password-protected keyring, PAM never receives a password
# to unlock it with, so the user gets a keyring prompt at every boot -- which is
# exactly the prompt this build is trying to remove. The two steps are a pair.
#
# Trade-off, stated plainly: anyone with console access to this VM gets a logged-in
# desktop. Appropriate for a lab VM behind the LAN, NOT for anything internet-facing.

GDM_CONF=/etc/gdm/custom.conf
TARGET_USER="$(id -un)"

if [ ! -f "$GDM_CONF" ]; then
    res_fail "Autologin -- $GDM_CONF does not exist (is GDM the display manager?)"
    echo "    FAIL: $GDM_CONF missing"
else
    # Keep one pristine copy of the distro default, never overwritten on re-run.
    sudo cp -n "$GDM_CONF" "${GDM_CONF}.orig" 2>/dev/null || true

    # Delete any existing AutomaticLogin* lines and re-add them under [daemon].
    # Rewriting rather than appending keeps this idempotent -- appending would
    # stack duplicate keys on every run and GDM honours only the first.
    sudo sed -i '/^[[:space:]]*AutomaticLogin/d' "$GDM_CONF"
    sudo sed -i "0,/^\[daemon\]/s//[daemon]\nAutomaticLoginEnable=True\nAutomaticLogin=${TARGET_USER}/" "$GDM_CONF"

    if sudo grep -q '^AutomaticLoginEnable=True' "$GDM_CONF" && \
       sudo grep -q "^AutomaticLogin=${TARGET_USER}$" "$GDM_CONF"; then
        res_ok "Autologin enabled for '$TARGET_USER' (takes effect at next boot)"
        echo "    OK:   $GDM_CONF now sets AutomaticLogin=$TARGET_USER"
        echo "    NOTE: the real test is a reboot; this verifies the config only."
    else
        res_fail "Autologin -- edited $GDM_CONF but the keys did not read back"
        echo "    FAIL: keys not found after edit"
        sudo sed -n '1,12p' "$GDM_CONF" | sed 's/^/      /'
    fi
fi
fi   # ← end of the autologin step (desktop only)

# ===========================================================================
echo ""
echo "=========================================="
echo "RESULTS - measured, not assumed"
echo "=========================================="
printf '%s\n' "${RESULTS[@]}"

N_OK=$(printf '%s\n'   "${RESULTS[@]}" | grep -c '\[ OK \]'  || true)
N_SKIP=$(printf '%s\n' "${RESULTS[@]}" | grep -c '\[SKIP\]'  || true)
N_FAIL=$(printf '%s\n' "${RESULTS[@]}" | grep -c '\[FAIL\]'  || true)

echo ""
echo "  $N_OK ok, $N_SKIP skipped (with reasons above), $N_FAIL failed"
echo ""
if [ "$SERVER_MODE" -eq 1 ]; then
    echo "Server mode: no desktop applications were installed."
else
    echo "Log out and back in for the dock, the terminal profile and the keyring"
    echo "to take effect. On Wayland the GNOME Shell cannot be restarted in place."
fi
echo "Run 'source ~/.bashrc' to use the aliases immediately."
echo ""

[ "$N_FAIL" -eq 0 ] || exit 1
