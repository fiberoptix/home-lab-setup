#!/bin/bash
#
# setup_desktop.sh - Configure an Ubuntu host for VM use
#
# Usage: ./setup_desktop.sh [--server]   (run as regular user, NOT sudo)
#
# Everything, in order:
#   1. Timezone America/New_York                     both modes
#   2. DNS 8.8.8.8 / 1.1.1.1                         both modes
#   3. CLI tools (curl wget htop btop vim jq ...)    both modes
#   4. Google Chrome                                 DESKTOP ONLY  ~431 MB
#   5. Cursor + its AppArmor profile                 DESKTOP ONLY  ~1012 MB
#   6. Display resolution 1920x1080 (+ persistence)  DESKTOP ONLY
#   7. Home icon, file manager preferences           DESKTOP ONLY
#   8. Screen lock / screensaver / power             DESKTOP ONLY
#   9. "Andrew" terminal profile                     DESKTOP ONLY
#  10. Dock icons                                    DESKTOP ONLY
#  11. Login keyring auto-unlock                     DESKTOP ONLY
#  12. Bash aliases (godev, update, sysbench)        both modes
#
# ============================================================================
# --server  (added Aug 21, 2026)
#
# Skips every DESKTOP ONLY step above. The two that matter are Chrome and
# Cursor: measured at 430.8 MB and 1012.4 MB installed on vm-jenkins-1, so
# 1.44 GB per server that then had to be purged by hand to get the space back.
#
# It does NOT skip the CLI tools or the aliases, because those are wanted MORE
# on a server than on a desktop -- htop, jq, vim and the `update` alias are how
# you work on a headless box.
#
# host_setup.sh passes --server automatically when gnome-shell is absent, so
# this flag is only needed to force server treatment on a host that HAS a
# desktop. The old auto-detection tested `gnome-shell || gsettings`, and
# gsettings is present on headless hosts via libglib2.0-bin -- which is exactly
# how servers ended up with a browser and an IDE on them.
# ============================================================================
#

SERVER_MODE=0
for arg in "$@"; do
    case "$arg" in
        --server) SERVER_MODE=1 ;;
        -h|--help)
            echo "Usage: ./setup_desktop.sh [--server]"
            echo "  --server   headless host: skip Chrome, Cursor and GNOME settings."
            echo "             Still does timezone, DNS, CLI tools and aliases."
            exit 0 ;;
        *)
            echo "ERROR: unknown option '$arg'"
            echo "Usage: ./setup_desktop.sh [--server]"
            exit 1 ;;
    esac
done

echo "=========================================="
if [ "$SERVER_MODE" -eq 1 ]; then
    echo "Ubuntu SERVER Configuration (--server)"
    echo "=========================================="
    echo "Skipping Chrome, Cursor and all GNOME settings."
    echo "Doing: timezone, DNS, CLI tools, shell aliases."
else
    echo "Ubuntu Desktop Configuration"
fi
echo "=========================================="

# Check if running as root (should NOT be)
if [ "$EUID" -eq 0 ]; then
    echo "WARNING: Run as regular user, not root!"
    echo "Usage: ./setup_desktop.sh [--server]"
    exit 1
fi

# Step labels are generated, not written by hand. The hardcoded ones had already
# drifted out of sync with their own comments -- "# Step 3: Install Google
# Chrome" printed "[4/12]", "# Step 5" printed "[6/12]" -- and a --server mode
# with a different step count would have made that worse in both modes at once.
if [ "$SERVER_MODE" -eq 1 ]; then STEP_TOTAL=4; else STEP_TOTAL=12; fi
STEP_N=0
step() {
    STEP_N=$((STEP_N + 1))
    echo ""
    echo "[$STEP_N/$STEP_TOTAL] $1"
}

step "Setting timezone to America/New_York..."
sudo timedatectl set-timezone America/New_York 2>/dev/null && \
    echo "    Timezone set to America/New_York" || \
    echo "    WARNING: Could not set timezone"

# Step 2: Set DNS to Google/Cloudflare
step "Setting DNS to Google (8.8.8.8) and Cloudflare (1.1.1.1)..."
# nmcli is absent on a netplan/systemd-networkd server (confirmed on .185), so
# this is guarded rather than assumed. Without the guard the bare `nmcli` below
# printed "command not found" and the step looked broken rather than N/A.
CONN_NAME=""
if command -v nmcli >/dev/null 2>&1; then
    CONN_NAME=$(nmcli -t -f NAME,DEVICE con show --active 2>/dev/null | grep -v lo | head -1 | cut -d: -f1)
else
    echo "    SKIPPED: NetworkManager (nmcli) is not installed on this host."
    echo "             DNS here is managed by netplan / systemd-resolved."
fi
if [ -n "$CONN_NAME" ]; then
    sudo nmcli con mod "$CONN_NAME" ipv4.dns "8.8.8.8 1.1.1.1"
    sudo nmcli con mod "$CONN_NAME" ipv4.ignore-auto-dns yes
    sudo nmcli con down "$CONN_NAME" && sudo nmcli con up "$CONN_NAME"
    echo "    DNS set to 8.8.8.8, 1.1.1.1 for connection: $CONN_NAME"
elif command -v nmcli >/dev/null 2>&1; then
    echo "    WARNING: Could not detect active network connection"
fi

# Step 3: Install CLI tools
step "Installing CLI tools..."
sudo apt-get update -qq
sudo apt-get install -y curl wget htop btop vim jq net-tools tree unzip sysbench 2>/dev/null && \
    echo "    Installed: curl, wget, htop, btop, vim, jq, net-tools, tree, unzip, sysbench" || \
    echo "    WARNING: Some tools may have failed to install"

# apt-get installs NOTHING if any single name in the list is unavailable, so the
# warning above can mean "one package is missing" or "you got none of them".
# Check each binary so the difference is visible.
CLI_MISSING=""
for c in curl wget htop btop vim jq netstat tree unzip sysbench; do
    command -v "$c" >/dev/null 2>&1 || CLI_MISSING="$CLI_MISSING $c"
done
if [ -n "$CLI_MISSING" ]; then
    echo "    WARNING: still missing after install:$CLI_MISSING"
fi

# ===========================================================================
# DESKTOP-ONLY STEPS BEGIN HERE
#
# Everything from Chrome down to the login keyring is skipped by --server. The
# single `if` wrapping them all is deliberate: individual per-step guards were
# the alternative, and with eleven steps that is eleven chances to forget one --
# which is how a headless host would quietly acquire a browser again.
# ===========================================================================
if [ "$SERVER_MODE" -eq 1 ]; then
echo ""
echo "--- Skipping desktop-only steps (--server) ---"
echo "    Chrome (~431 MB), Cursor (~1012 MB), resolution, GNOME settings,"
echo "    terminal profile, dock icons, login keyring."
else

# Step 4: Install Google Chrome
step "Installing Google Chrome..."
if command -v google-chrome &> /dev/null; then
    echo "    Chrome already installed"
else
    echo "    Downloading Chrome..."
    wget -q -O /tmp/google-chrome.deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
    echo "    Installing Chrome (will prompt for password)..."
    sudo dpkg -i /tmp/google-chrome.deb 2>/dev/null || sudo apt-get install -f -y
    rm -f /tmp/google-chrome.deb
    if command -v google-chrome &> /dev/null; then
        echo "    Chrome installed successfully"
    else
        echo "    WARNING: Chrome installation may have failed"
    fi
fi

# Step 5: Install Cursor (AI code editor) via apt
step "Installing Cursor..."
if command -v cursor &> /dev/null; then
    echo "    Cursor already installed: $(dpkg -l cursor 2>/dev/null | tail -1 | awk '{print $3}')"
else
    echo "    Adding Cursor apt repository..."
    
    # Download GPG key from our script server (official URL requires auth)
    sudo wget -q -O /usr/share/keyrings/anysphere.gpg http://192.168.1.195/ubuntu/anysphere.gpg
    
    # Add repository
    echo "Types: deb
URIs: https://downloads.cursor.com/aptrepo
Suites: stable
Components: main
Architectures: amd64,arm64
Signed-By: /usr/share/keyrings/anysphere.gpg" | sudo tee /etc/apt/sources.list.d/cursor.sources > /dev/null
    
    # Install Cursor
    echo "    Installing Cursor via apt..."
    sudo apt-get update -qq
    sudo apt-get install -y cursor
    
    if command -v cursor &> /dev/null; then
        echo "    Cursor installed successfully via apt"
    else
        echo "    WARNING: Cursor installation may have failed"
    fi
fi

# Fix AppArmor blocking Cursor terminal sandbox (Ubuntu 24.04+)
if [ -f /usr/share/cursor/cursor ]; then
    echo "    Configuring AppArmor profile for Cursor terminal sandbox..."
    sudo tee /etc/apparmor.d/cursor > /dev/null <<'APPARMOR'
abi <abi/4.0>,

profile cursor /usr/share/cursor/cursor flags=(unconfined) {
  userns,
}
APPARMOR
    sudo apparmor_parser -r /etc/apparmor.d/cursor 2>/dev/null && \
        echo "    AppArmor profile loaded for Cursor" || \
        echo "    WARNING: Could not load AppArmor profile (may not be needed)"
fi

# Step 6: Set resolution to 1920x1080
step "Setting display resolution to 1920x1080..."
if command -v xrandr &> /dev/null; then
    # Get primary display name
    DISPLAY_NAME=$(xrandr | grep " connected" | head -1 | awk '{print $1}')
    if [ -n "$DISPLAY_NAME" ]; then
        xrandr --output "$DISPLAY_NAME" --mode 1920x1080 2>/dev/null && \
            echo "    Set $DISPLAY_NAME to 1920x1080" || \
            echo "    WARNING: 1920x1080 mode not available, trying to add it..."
        
        # If mode doesn't exist, try adding it
        if ! xrandr | grep -q "1920x1080"; then
            echo "    Adding 1920x1080 mode..."
            xrandr --newmode "1920x1080_60.00" 173.00 1920 2048 2248 2576 1080 1083 1088 1120 -hsync +vsync 2>/dev/null
            xrandr --addmode "$DISPLAY_NAME" "1920x1080_60.00" 2>/dev/null
            xrandr --output "$DISPLAY_NAME" --mode "1920x1080_60.00" 2>/dev/null
        fi
    else
        echo "    WARNING: Could not detect display"
    fi
else
    echo "    WARNING: xrandr not found"
fi

# Step 7: Hide Home folder on desktop (GNOME)
step "Hiding Home folder icon on desktop..."
if command -v gsettings &> /dev/null; then
    # For GNOME 40+ (Ubuntu 22.04+)
    gsettings set org.gnome.shell.extensions.ding show-home false 2>/dev/null && \
        echo "    Hidden via ding extension" || true
    
    # For older GNOME / Nautilus
    gsettings set org.gnome.nautilus.desktop home-icon-visible false 2>/dev/null || true
    
    # Alternative: gnome-shell-extension-desktop-icons-ng
    gsettings set org.gnome.shell.extensions.desktop-icons show-home false 2>/dev/null || true
    
    echo "    Home folder icon hidden (if supported)"
    
    # Disable Panel Mode for dock (floating dock instead of full-width bar)
    gsettings set org.gnome.shell.extensions.dash-to-dock extend-height false 2>/dev/null && \
        echo "    Disabled dock panel mode (floating dock)" || true
    
    # Set dock icon size to 32
    gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 32 2>/dev/null && \
        echo "    Set dock icon size to 32" || true
    
    # Configure Nautilus file manager preferences
    # Set default view to list view
    gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view' 2>/dev/null && \
        echo "    Set default file view to list view" || true
    
    # Show hidden files by default
    gsettings set org.gtk.Settings.FileChooser show-hidden true 2>/dev/null && \
        echo "    Enabled showing hidden files" || true
else
    echo "    WARNING: gsettings not found (not GNOME?)"
fi

# Step 8: Disable screen lock and screen saver
step "Disabling screen lock and screen saver..."
if command -v gsettings &> /dev/null; then
    # Disable screen lock
    gsettings set org.gnome.desktop.screensaver lock-enabled false 2>/dev/null && \
        echo "    Disabled screen lock" || true
    
    # Disable automatic screen lock
    gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null && \
        echo "    Disabled idle timeout (no auto-lock)" || true
    
    # Disable screen blanking
    gsettings set org.gnome.desktop.screensaver idle-activation-enabled false 2>/dev/null && \
        echo "    Disabled screensaver activation" || true
    
    # Disable lock on suspend
    gsettings set org.gnome.desktop.screensaver ubuntu-lock-on-suspend false 2>/dev/null || true
    
    # Power settings - never blank screen
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' 2>/dev/null || true
    gsettings set org.gnome.settings-daemon.plugins.power idle-dim false 2>/dev/null || true
    
    echo "    Screen saver and power settings configured"
else
    echo "    WARNING: gsettings not found"
fi

# Step 9: Create "Andrew" terminal profile
step "Creating 'Andrew' terminal profile..."
if command -v dconf &> /dev/null; then
    # Generate a new UUID for the profile
    PROFILE_UUID=$(uuidgen)
    
    # Add profile to the list
    EXISTING_PROFILES=$(gsettings get org.gnome.Terminal.ProfilesList list 2>/dev/null)
    if [ "$EXISTING_PROFILES" = "@as []" ] || [ -z "$EXISTING_PROFILES" ]; then
        gsettings set org.gnome.Terminal.ProfilesList list "['$PROFILE_UUID']"
    else
        # Check if Andrew profile already exists
        if ! dconf dump /org/gnome/terminal/legacy/profiles:/ | grep -q "visible-name='Andrew'"; then
            NEW_LIST=$(echo "$EXISTING_PROFILES" | sed "s/]$/, '$PROFILE_UUID']/")
            gsettings set org.gnome.Terminal.ProfilesList list "$NEW_LIST"
        else
            echo "    Andrew profile already exists"
            PROFILE_UUID=$(dconf dump /org/gnome/terminal/legacy/profiles:/ | grep -B20 "visible-name='Andrew'" | grep "^\[:" | head -1 | tr -d '[]' | tr -d ':')
        fi
    fi
    
    # Set profile as default
    gsettings set org.gnome.Terminal.ProfilesList default "$PROFILE_UUID"
    
    # Configure the profile settings
    PROFILE_PATH="/org/gnome/terminal/legacy/profiles:/:$PROFILE_UUID/"
    dconf write ${PROFILE_PATH}visible-name "'Andrew'"
    dconf write ${PROFILE_PATH}background-color "'rgb(22,23,21)'"
    dconf write ${PROFILE_PATH}foreground-color "'rgb(221,217,234)'"
    dconf write ${PROFILE_PATH}background-transparency-percent "15"
    dconf write ${PROFILE_PATH}use-transparent-background "true"
    dconf write ${PROFILE_PATH}use-theme-colors "false"
    dconf write ${PROFILE_PATH}use-theme-transparency "false"
    dconf write ${PROFILE_PATH}bold-color-same-as-fg "true"
    dconf write ${PROFILE_PATH}bold-is-bright "true"
    dconf write ${PROFILE_PATH}cursor-blink-mode "'on'"
    dconf write ${PROFILE_PATH}default-size-columns "200"
    dconf write ${PROFILE_PATH}default-size-rows "50"
    dconf write ${PROFILE_PATH}scroll-on-output "true"
    dconf write ${PROFILE_PATH}palette "['rgb(46,52,54)', 'rgb(204,0,0)', 'rgb(78,154,6)', 'rgb(196,160,0)', 'rgb(52,101,164)', 'rgb(117,80,123)', 'rgb(6,152,154)', 'rgb(211,215,207)', 'rgb(85,87,83)', 'rgb(239,41,41)', 'rgb(138,226,52)', 'rgb(252,233,79)', 'rgb(114,159,207)', 'rgb(173,127,168)', 'rgb(52,226,226)', 'rgb(238,238,236)']"
    
    echo "    Created 'Andrew' terminal profile (200x50, transparent dark theme)"
else
    echo "    WARNING: dconf not found"
fi

# Step 10: Configure dock icons
step "Configuring dock icons..."
if command -v gsettings &> /dev/null; then
    gsettings set org.gnome.shell favorite-apps "['org.gnome.Nautilus.desktop', 'google-chrome.desktop', 'firefox_firefox.desktop', 'cursor.desktop', 'org.gnome.Terminal.desktop', 'org.gnome.SystemMonitor.desktop', 'org.gnome.Settings.desktop', 'org.gnome.TextEditor.desktop']"
    echo "    Dock configured: Files, Chrome, Firefox, Cursor, Terminal, System Monitor, Settings, Text Editor"
else
    echo "    WARNING: gsettings not found"
fi

# Step 11: Disable login keyring prompt
step "Disabling login keyring prompt..."
# Remove existing keyring to reset it with no password
if [ -d ~/.local/share/keyrings ]; then
    rm -f ~/.local/share/keyrings/login.keyring
    rm -f ~/.local/share/keyrings/user.keystore
    echo "    Removed existing keyring files"
fi
# Create empty password keyring (auto-unlocks on login)
mkdir -p ~/.local/share/keyrings
cat > ~/.local/share/keyrings/default << 'EOF'
login
EOF
echo "    Set default keyring to 'login' with no password"
echo "    (Keyring will auto-unlock on next login)"

fi   # ← end of the desktop-only block opened before Chrome (--server skips it all)

# ===========================================================================
# BOTH MODES AGAIN. The aliases are last because they are wanted everywhere:
# `update` and `godev` are arguably more useful on a headless box than on a
# desktop, so --server must not skip them.
# ===========================================================================

# Step 12 (or 4 in server mode): Add bash aliases
step "Adding bash aliases..."
BASHRC="$HOME/.bashrc"

# Add godev alias
if ! grep -q "alias godev=" "$BASHRC" 2>/dev/null; then
    echo "" >> "$BASHRC"
    echo "# Custom aliases added by setup_desktop.sh" >> "$BASHRC"
    echo "alias godev='cd ~/DevShare'" >> "$BASHRC"
    echo "    Added alias: godev -> cd ~/DevShare"
else
    echo "    Alias godev already exists"
fi

# Add update alias
if ! grep -q "alias update=" "$BASHRC" 2>/dev/null; then
    echo "alias update='sudo apt update && sudo apt upgrade -y'" >> "$BASHRC"
    echo "    Added alias: update -> sudo apt update && sudo apt upgrade -y"
else
    echo "    Alias update already exists"
fi

# Add sysbench alias
if ! grep -q "alias sysbench=" "$BASHRC" 2>/dev/null; then
    echo "alias sysbench='sysbench --threads=$(nproc) cpu run'" >> "$BASHRC"
    echo "    Added alias: sysbench -> sysbench --threads=$(nproc) cpu run"
else
    echo "    Alias sysbench already exists"
fi

# Make resolution persistent (create autostart entry)
#
# This entry used to hardcode `--output Virtual-1` while the step above detected
# the output name dynamically into $DISPLAY_NAME. On any host whose output is not
# named Virtual-1 the resolution was correct for that session and then SILENTLY
# REVERTED at next login -- and because the detection above worked, it looked like
# GNOME forgetting the setting rather than a bug here. Found Aug 21, 2026 while
# auditing this script against the Fedora rewrite.
#
# Two further honest limits, stated rather than papered over:
#   - This only works on X11. Under Wayland xrandr sees only XWayland and cannot
#     set a mode, so the entry is inert. The Fedora script skips this step for
#     exactly that reason instead of writing a dead file.
#   - Nothing here verifies the entry ever takes effect; the only real test is a
#     re-login. The summary below says "requested", not "applied".
echo ""
echo "[Bonus] Making resolution persistent..."
if [ "$SERVER_MODE" -eq 1 ]; then
    # Explicit branch rather than falling through to the "no display detected"
    # message below, which would say "detected above" about a step that never
    # ran -- an accurate-sounding sentence describing something that did not
    # happen is worse than no message.
    echo "    SKIPPED: server mode, there is no display to pin."
    RES_PERSIST="skipped (server mode)"
elif [ -z "${DISPLAY_NAME:-}" ]; then
    echo "    SKIPPED: no display was detected above, so there is no output name to"
    echo "             pin. Writing an entry naming the wrong output is worse than"
    echo "             writing none - it fails silently at every login."
    RES_PERSIST="skipped (no display detected)"
elif [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
    echo "    SKIPPED: this is a Wayland session; xrandr cannot set a mode, so an"
    echo "             autostart entry would never do anything. Use Settings >"
    echo "             Displays, or resize the hypervisor window."
    RES_PERSIST="skipped (Wayland)"
else
    mkdir -p ~/.config/autostart
    cat > ~/.config/autostart/set-resolution.desktop << EOF
[Desktop Entry]
Type=Application
Name=Set Resolution
Exec=xrandr --output ${DISPLAY_NAME} --mode 1920x1080
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
    echo "    Created autostart entry pinning ${DISPLAY_NAME} to 1920x1080"
    RES_PERSIST="autostart entry written for ${DISPLAY_NAME}"
fi

# ===========================================================================
# SUMMARY - measured, not asserted.
#
# This block used to print fifteen hardcoded checkmarks. Every gsettings call
# above ends in `2>/dev/null || true`, and three of the schemas they write to do
# not exist on all hosts (ding, desktop-icons, dash-to-dock) -- so the write
# failed, the error was swallowed, and this summary still printed
#     "✓ Home folder: Hidden"   and   "✓ Dock panel mode: Disabled"
# having changed nothing. A false green in our own tooling is worse than a red,
# because a red gets investigated.
#
# Rewritten Aug 21, 2026 to read every value back, matching the Fedora script.
# "--" means the schema is not present on this host, which is an honest outcome
# and not counted as a problem; WARN means we wrote something and it did not stick.
# ===========================================================================
WARN_COUNT=0
say_ok()   { echo "  ok   $1"; }
say_warn() { echo "  WARN $1"; WARN_COUNT=$((WARN_COUNT + 1)); }
say_na()   { echo "  --   $1"; }

_norm() { printf '%s' "$1" | tr -d "[:space:]'\"" ; }

# check_gset <schema> <key> <expected> <label>
check_gset() {
    local schema="$1" key="$2" want="$3" label="$4" got
    if ! gsettings list-schemas 2>/dev/null | grep -qx "$schema"; then
        say_na "$label (no schema $schema on this host)"
        return
    fi
    got=$(gsettings get "$schema" "$key" 2>/dev/null)
    if [ "$(_norm "$got")" = "$(_norm "$want")" ]; then
        say_ok "$label"
    else
        say_warn "$label -- reads '$got', wanted '$want'"
    fi
}

check_cmd() {
    if command -v "$1" >/dev/null 2>&1; then say_ok "$2"; else say_warn "$2 -- not installed"; fi
}

echo ""
echo "=========================================="
if [ "$SERVER_MODE" -eq 1 ]; then
    echo "Server configuration - measured results"
else
    echo "Desktop configuration - measured results"
fi
echo "=========================================="
echo ""

NOW_TZ=$(timedatectl show -p Timezone --value 2>/dev/null)
[ "$NOW_TZ" = "America/New_York" ] \
    && say_ok "Timezone: $NOW_TZ" \
    || say_warn "Timezone reads '$NOW_TZ', wanted America/New_York"

DNS_NOW=$(nmcli -g IP4.DNS dev show 2>/dev/null | tr '\n' ' ' | tr -s ' ')
case "$DNS_NOW" in
    *8.8.8.8*) say_ok "DNS: $DNS_NOW" ;;
    "")        say_na "DNS: no NetworkManager device reported one (netplan/systemd-networkd host)" ;;
    *)         say_warn "DNS reads '$DNS_NOW', wanted 8.8.8.8 + 1.1.1.1" ;;
esac

CLI_MISSING=""
for c in curl wget htop btop vim jq netstat tree unzip sysbench; do
    command -v "$c" >/dev/null 2>&1 || CLI_MISSING="$CLI_MISSING $c"
done
[ -z "$CLI_MISSING" ] \
    && say_ok "CLI tools: all ten present" \
    || say_warn "CLI tools missing:$CLI_MISSING"

# In server mode every check below describes something we deliberately did not
# do. Running them anyway would produce a screen of WARN lines for a build that
# went exactly to plan -- the false RED that is the mirror image of the false
# green this summary was rewritten to eliminate. A skipped step is reported as
# "--", which is an outcome, not a problem.
if [ "$SERVER_MODE" -eq 1 ]; then
    say_na "Google Chrome: not installed (--server, ~431 MB saved)"
    say_na "Cursor: not installed (--server, ~1012 MB saved)"
    say_na "GNOME settings, terminal profile, dock, keyring: skipped (--server)"
    say_na "Resolution persistence: $RES_PERSIST"

    # The one thing worth actively checking on a server: that a PREVIOUS build
    # did not leave the desktop apps behind. This script did not install them,
    # but on this fleet it used to, and that is the state you are trying to find.
    LEFTOVER=""
    command -v google-chrome >/dev/null 2>&1 && LEFTOVER="$LEFTOVER google-chrome"
    command -v cursor        >/dev/null 2>&1 && LEFTOVER="$LEFTOVER cursor"
    if [ -n "$LEFTOVER" ]; then
        say_warn "desktop apps left over from an EARLIER build:$LEFTOVER"
        echo "       Not installed by this run. Reclaim ~1.4 GB with:"
        echo "         sudo apt-get purge -y google-chrome-stable cursor && sudo apt-get autoremove -y"
    else
        say_ok "No desktop apps present (as intended on a server)"
    fi
else
check_cmd google-chrome "Google Chrome installed"
check_cmd cursor        "Cursor installed"

say_na "Resolution persistence: $RES_PERSIST"

check_gset org.gnome.shell.extensions.ding show-home false \
    "Desktop: Home icon hidden"
check_gset org.gnome.shell.extensions.dash-to-dock extend-height false \
    "Dock: floating (panel mode off)"
check_gset org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 32 \
    "Dock: 32px icons"
check_gset org.gnome.nautilus.preferences default-folder-viewer "'list-view'" \
    "Files: list view"
check_gset org.gtk.Settings.FileChooser show-hidden true \
    "Files: show hidden"
check_gset org.gnome.desktop.screensaver lock-enabled false \
    "Screen lock disabled"
check_gset org.gnome.desktop.screensaver idle-activation-enabled false \
    "Screensaver disabled"
check_gset org.gnome.desktop.session idle-delay "uint32 0" \
    "Idle timeout disabled"

# The terminal profile lives in dconf, not in a gsettings schema, so it is read
# back from the profile path rather than through check_gset.
if [ -n "${PROFILE_UUID:-}" ]; then
    TERM_NAME=$(dconf read "/org/gnome/terminal/legacy/profiles:/:${PROFILE_UUID}/visible-name" 2>/dev/null)
    [ "$(_norm "$TERM_NAME")" = "Andrew" ] \
        && say_ok "Terminal profile 'Andrew' (200x50, transparent dark)" \
        || say_warn "Terminal profile visible-name reads '$TERM_NAME', wanted 'Andrew'"
else
    say_warn "Terminal profile: no UUID was resolved, profile not written"
fi

# GNOME silently DROPS favourites whose .desktop file is missing, so the value
# read back is the truth and the value written is only a request.
if gsettings list-schemas 2>/dev/null | grep -qx org.gnome.shell; then
    FAV_N=$(gsettings get org.gnome.shell favorite-apps 2>/dev/null | grep -o '\.desktop' | wc -l)
    [ "$FAV_N" -ge 1 ] \
        && say_ok "Dock icons: $FAV_N pinned (GNOME drops any whose .desktop is absent)" \
        || say_warn "Dock icons: none pinned"
else
    say_na "Dock icons (no org.gnome.shell schema)"
fi

[ "$(cat ~/.local/share/keyrings/default 2>/dev/null)" = "login" ] \
    && say_ok "Login keyring: default 'login', auto-unlock" \
    || say_warn "Login keyring: ~/.local/share/keyrings/default is not 'login'"
fi

ALIAS_MISSING=""
for a in godev update sysbench; do
    grep -q "alias ${a}=" "$HOME/.bashrc" 2>/dev/null || ALIAS_MISSING="$ALIAS_MISSING $a"
done
[ -z "$ALIAS_MISSING" ] \
    && say_ok "Bash aliases: godev, update, sysbench" \
    || say_warn "Bash aliases missing:$ALIAS_MISSING"

echo ""
if [ "$WARN_COUNT" -eq 0 ]; then
    echo "All checks passed. ('--' lines are not applicable to this host.)"
else
    echo "$WARN_COUNT setting(s) did not read back as written - see WARN above."
fi
echo ""
if [ "$SERVER_MODE" -eq 1 ]; then
    echo "Server mode: no desktop apps installed."
else
    echo "Note: Log out and back in if changes don't take effect."
fi
echo "Run 'source ~/.bashrc' to use aliases immediately."

# Exit non-zero so host_setup.sh can report this honestly instead of assuming.
[ "$WARN_COUNT" -eq 0 ] || exit 1

