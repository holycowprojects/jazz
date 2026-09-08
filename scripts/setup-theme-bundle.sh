#!/usr/bin/env bash
# Task 27b: theme-as-bundle system. Deploys design/tokens/themes.json (the
# per-theme chrome/accent/terminal/wallpaper data - jazz-theme-set needs it
# at RUNTIME, unlike colors.json which only feeds generate-theme-qml.py at
# build time) and the jazz-theme-set orchestrator, wires dunst's autostart
# and a Super+L lock keybind (neither existed before this task - confirmed
# empty/missing live, 7 Sept 2026), then runs jazz-theme-set once against
# the current default theme so kitty/hyprlock/dunst aren't left with no
# real config on a fresh install.
#
# kitty/dunst/hyprlock are all already-installed official packages,
# confirmed live - no pacman step needed here.
#
# Run this ON THE INSTALLED GUEST, as root, AFTER setup-wallpaper.sh
# (jazz-theme-set calls jazz-wallpaper-set, which setup-wallpaper.sh
# installs) and setup-dock.sh (Theme.qml's @@JAZZ_DATA_DIR@@ FileView
# needs theme-state.json's directory to exist).
# Usage: setup-theme-bundle.sh <username>
set -eu

USERNAME="${1:?Usage: setup-theme-bundle.sh <username>}"
HOME_DIR="/home/$USERNAME"
DATA_DIR="$HOME_DIR/.local/share/jazz"
HYPR_CONFIG="$HOME_DIR/.config/hypr/hyprland.lua"
THEMES_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../design/tokens" && pwd)/themes.json"
THEME_SET_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/jazz-theme-set"
FONT_SET_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/jazz-font-set"
GEN_WALLPAPER_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../configs/quickshell" && pwd)/gen_wallpaper.py"

sudo -u "$USERNAME" mkdir -p "$DATA_DIR"
sudo -u "$USERNAME" cp "$THEMES_SRC" "$DATA_DIR/themes.json"

install -m 755 "$THEME_SET_SRC" /usr/local/bin/jazz-theme-set
install -m 755 "$FONT_SET_SRC" /usr/local/bin/jazz-font-set

# Fonts (setup-dock.sh installs the packages) - apply the defaults from
# design/tokens/typography.json now, so the fontconfig alias/font-state.json
# exist immediately instead of only Inter/JetBrains Mono looking right by
# accident (they're Quickshell's own hardcoded Theme.qml defaults) while
# GTK/Qt apps stay on whatever fontconfig picked before this ran.
sudo -u "$USERNAME" env JAZZ_DATA_DIR="$DATA_DIR" /usr/local/bin/jazz-font-set "Inter" "JetBrains Mono"

# Bootstrap any theme's wallpaper files that don't exist on disk yet
# (Midnight/Warm have no curated art yet - gen_wallpaper.py fills the gap
# with a real, functional placeholder so jazz-theme-set never points at a
# missing file; Forge/Daylight already have Task 23's originals).
sudo -u "$USERNAME" bash -c "cd '$DATA_DIR/wallpapers' && python3 '$GEN_WALLPAPER_SRC' --all"

# dunst's autostart already exists (added separately for the bell/clipboard
# tray feature, confirmed live 8 Sept 2026 - dunst was already running with
# zero config file, using built-in defaults) - only Super+L is new here.
if [[ -f "$HYPR_CONFIG" ]] && ! grep -q 'Added by setup-theme-bundle.sh' "$HYPR_CONFIG"; then
    sudo -u "$USERNAME" tee -a "$HYPR_CONFIG" > /dev/null << 'EOF'

-- Added by setup-theme-bundle.sh (Task 27b): Super+L to lock, via hyprlock
-- (installed, but never bound to anything before this - confirmed live).
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
EOF
fi

# Apply the persisted (or default) theme now, so kitty/hyprlock/dunst have
# real generated config immediately instead of staying empty until the user
# first opens Settings' theme picker. --restore also handles the reboot
# case going forward (wired into the autostart line below) - without it, a
# reboot would silently revert the wallpaper to Forge's while Theme.qml
# correctly restored the real last-picked theme's chrome, a real mismatch.
sudo -u "$USERNAME" env JAZZ_DATA_DIR="$DATA_DIR" /usr/local/bin/jazz-theme-set --restore

if [[ -f "$HYPR_CONFIG" ]] && grep -q 'swaybg -i.*jazz-wallpaper-dark.png' "$HYPR_CONFIG"; then
    sed -i 's|hl.exec_cmd("swaybg -i [^"]*")|hl.exec_cmd("jazz-theme-set --restore")|' "$HYPR_CONFIG"
fi

echo "Theme bundle system prepared for $USERNAME:"
ls -la "$DATA_DIR/themes.json" /usr/local/bin/jazz-theme-set
