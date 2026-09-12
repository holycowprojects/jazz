#!/usr/bin/env bash
# Task 23: JAZZ's own wallpaper, replacing Hyprland's stock example one.
# Generates a dark/light pair (calm neutral base, a subtle Forge-blue glow -
# Forge is the default/highest-traffic workspace per Design-Vision.md -
# and a restrained waveform motif nodding to "Jazz" as music) via Pillow,
# not a loud rainbow gradient across all six workspace colors, which would
# read as generic/AI-templated and contradict the project's "calm by
# default" philosophy (Design-Vision.md sec 1).
#
# Uses swaybg, not hyprpaper - hyprpaper's IPC (`hyprctl hyprpaper ...`)
# genuinely fails ("invalid hyprpaper request") against this Hyprland
# build, confirmed live, not assumed. swaybg is simpler (one CLI process,
# no IPC) and is what Omarchy itself actually uses for wallpaper -
# confirmed via its real source, not guessed.
#
# Run this ON THE INSTALLED GUEST, as root.
# Usage: setup-wallpaper.sh <username>
set -eu

USERNAME="${1:?Usage: setup-wallpaper.sh <username>}"
HOME_DIR="/home/$USERNAME"
WALL_DIR="$HOME_DIR/.local/share/jazz/wallpapers"
GEN_SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../configs/quickshell" && pwd)/gen_wallpaper.py"
HYPR_CONFIG="$HOME_DIR/.config/hypr/hyprland.lua"
SET_SCRIPT="/usr/local/bin/jazz-wallpaper-set"

pacman -Sy --noconfirm --needed swaybg python-pillow

sudo -u "$USERNAME" mkdir -p "$WALL_DIR"
if [[ ! -f "$WALL_DIR/jazz-wallpaper-dark.png" ]] || [[ ! -f "$WALL_DIR/jazz-wallpaper-light.png" ]]; then
    # Real regression fixed 12 Sept 2026: gen_wallpaper.py stopped taking no
    # arguments once Task 27b theme-parameterized it (base/accent/mode per
    # theme instead of hardcoded dark/light) - this call was never updated
    # to match, invisible on the existing dev machine since its wallpapers
    # already existed so this branch never actually ran there. --all
    # regenerates every theme missing a real file, same as
    # setup-theme-bundle.sh's own (already-correct) bootstrap call.
    sudo -u "$USERNAME" bash -c "cd '$WALL_DIR' && python3 '$GEN_SCRIPT_SRC' --all"
fi

tee "$SET_SCRIPT" > /dev/null << 'EOF'
#!/usr/bin/env bash
# JAZZ wallpaper setter (Task 23). swaybg has no IPC to swap images live -
# the only way to change wallpaper is kill the old process and start a
# new one, confirmed live against this swaybg version.
# Usage: jazz-wallpaper-set <path-to-image>
set -eu
IMG="${1:?Usage: jazz-wallpaper-set <path-to-image>}"
pkill -u "$(whoami)" swaybg 2>/dev/null || true
sleep 0.3
nohup swaybg -i "$IMG" -m fill > /tmp/jazz-swaybg.log 2>&1 < /dev/null &
disown
EOF
chmod +x "$SET_SCRIPT"

if [[ -f "$HYPR_CONFIG" ]] && ! grep -q 'Added by setup-wallpaper.sh' "$HYPR_CONFIG"; then
    sudo -u "$USERNAME" tee -a "$HYPR_CONFIG" > /dev/null << EOF

-- Added by setup-wallpaper.sh (Task 23): autostart the JAZZ wallpaper
-- (dark by default, matching Theme.qml's own default darkMode=true).
-- The Settings app's dark/light toggle also calls jazz-wallpaper-set to
-- keep the wallpaper in sync when switching modes.
hl.on("hyprland.start", function()
    hl.exec_cmd("swaybg -i $WALL_DIR/jazz-wallpaper-dark.png -m fill")
end)
EOF
fi

echo "Wallpaper prepared for $USERNAME:"
ls -la "$WALL_DIR"
