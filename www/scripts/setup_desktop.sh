#!/bin/bash
#
# setup_desktop.sh - Configure Ubuntu Desktop for VM use
#
# Usage: ./setup_desktop.sh (run as regular user, NOT sudo)
#
# This script will:
# 1. Set timezone to America/New_York
# 2. Set DNS to Google (8.8.8.8) and Cloudflare (1.1.1.1)
# 3. Install CLI tools (curl, wget, htop, vim, jq, net-tools, tree, sysbench)
# 4. Install Google Chrome
# 5. Install Cursor (AI code editor)
# 6. Set display resolution to 1920x1080
# 7. Hide Home folder icon on desktop, configure file manager (list view, show hidden)
# 8. Disable screen lock and screen saver
# 9. Create "Andrew" terminal profile
# 10. Configure dock icons
# 11. Disable login keyring prompt
# 12. Add bash aliases (godev, update, sysbench)
#

echo "=========================================="
echo "Ubuntu Desktop Configuration"
echo "=========================================="

# Check if running as root (should NOT be)
if [ "$EUID" -eq 0 ]; then
    echo "WARNING: Run as regular user, not root!"
    echo "Usage: ./setup_desktop.sh"
    exit 1
fi

# Step 1: Set timezone
echo ""
echo "[1/12] Setting timezone to America/New_York..."
sudo timedatectl set-timezone America/New_York 2>/dev/null && \
    echo "    Timezone set to America/New_York" || \
    echo "    WARNING: Could not set timezone"

# Step 2: Set DNS to Google/Cloudflare
echo ""
echo "[2/12] Setting DNS to Google (8.8.8.8) and Cloudflare (1.1.1.1)..."
# Get the active connection name
CONN_NAME=$(nmcli -t -f NAME,DEVICE con show --active | grep -v lo | head -1 | cut -d: -f1)
if [ -n "$CONN_NAME" ]; then
    sudo nmcli con mod "$CONN_NAME" ipv4.dns "8.8.8.8 1.1.1.1"
    sudo nmcli con mod "$CONN_NAME" ipv4.ignore-auto-dns yes
    sudo nmcli con down "$CONN_NAME" && sudo nmcli con up "$CONN_NAME"
    echo "    DNS set to 8.8.8.8, 1.1.1.1 for connection: $CONN_NAME"
else
    echo "    WARNING: Could not detect active network connection"
fi

# Step 3: Install CLI tools
echo ""
echo "[3/12] Installing CLI tools..."
sudo apt-get update -qq
sudo apt-get install -y curl wget htop vim jq net-tools tree unzip sysbench 2>/dev/null && \
    echo "    Installed: curl, wget, htop, vim, jq, net-tools, tree, unzip, sysbench" || \
    echo "    WARNING: Some tools may have failed to install"

# Step 3: Install Google Chrome
echo ""
echo "[4/12] Installing Google Chrome..."
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

# Step 4: Install Cursor (AI code editor) via apt
echo ""
echo "[5/12] Installing Cursor..."
if command -v cursor &> /dev/null; then
    echo "    Cursor already installed: $(dpkg -l cursor 2>/dev/null | tail -1 | awk '{print $3}')"
else
    echo "    Adding Cursor apt repository..."
    
    # Download GPG key from our script server (official URL requires auth)
    sudo wget -q -O /usr/share/keyrings/anysphere.gpg http://192.168.1.195/scripts/anysphere.gpg
    
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

# Step 5: Set resolution to 1920x1080
echo ""
echo "[6/12] Setting display resolution to 1920x1080..."
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

# Step 6: Hide Home folder on desktop (GNOME)
echo ""
echo "[7/12] Hiding Home folder icon on desktop..."
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

# Step 7: Disable screen lock and screen saver
echo ""
echo "[8/12] Disabling screen lock and screen saver..."
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

# Step 8: Create "Andrew" terminal profile
echo ""
echo "[9/12] Creating 'Andrew' terminal profile..."
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

# Step 9: Configure dock icons
echo ""
echo "[10/12] Configuring dock icons..."
if command -v gsettings &> /dev/null; then
    gsettings set org.gnome.shell favorite-apps "['org.gnome.Nautilus.desktop', 'google-chrome.desktop', 'firefox_firefox.desktop', 'cursor.desktop', 'org.gnome.Terminal.desktop', 'org.gnome.SystemMonitor.desktop', 'org.gnome.Settings.desktop', 'org.gnome.TextEditor.desktop']"
    echo "    Dock configured: Files, Chrome, Firefox, Cursor, Terminal, System Monitor, Settings, Text Editor"
else
    echo "    WARNING: gsettings not found"
fi

# Step 10: Disable login keyring prompt
echo ""
echo "[11/12] Disabling login keyring prompt..."
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

# Step 11: Add bash aliases
echo ""
echo "[12/12] Adding bash aliases..."
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
echo ""
echo "[Bonus] Making resolution persistent..."
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/set-resolution.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Set Resolution
Exec=xrandr --output Virtual-1 --mode 1920x1080
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
echo "    Created autostart entry for resolution"

echo ""
echo "=========================================="
echo "Done! Desktop configured."
echo "=========================================="
echo ""
echo "Settings applied:"
echo "  ✓ Timezone: America/New_York"
echo "  ✓ DNS: Google (8.8.8.8) + Cloudflare (1.1.1.1)"
echo "  ✓ CLI tools: curl, wget, htop, vim, jq, net-tools, tree, unzip, sysbench"
echo "  ✓ Google Chrome: Installed"
echo "  ✓ Cursor: Installed (AI code editor)"
echo "  ✓ Resolution: 1920x1080"
echo "  ✓ Home folder: Hidden"
echo "  ✓ Dock panel mode: Disabled (floating, 32px icons)"
echo "  ✓ File manager: List view, show hidden files"
echo "  ✓ Screen lock: Disabled"
echo "  ✓ Screen saver: Disabled"
echo "  ✓ Terminal profile: Andrew (200x50, transparent dark)"
echo "  ✓ Dock icons: Files, Chrome, Firefox, Cursor, Terminal, SysMon, Settings, Editor"
echo "  ✓ Login keyring: Auto-unlock (no password prompt)"
echo "  ✓ Bash aliases: godev, update, sysbench"
echo ""
echo "Note: Log out and back in if changes don't take effect."
echo "Run 'source ~/.bashrc' to use aliases immediately."

