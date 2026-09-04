#!/usr/bin/env bash
# Prepares Hyprland for Task 9 (desktop). archinstall's base profile already
# installed hyprland/aquamarine/mesa/seatd (Task 4) - this script does the
# one real fix found live: the target user needs `video` group membership.
# card0 is root:video, and Mesa's EGL/DRI2 init opens it directly (not
# seatd-mediated for this specific call), so without it every session dies
# instantly with "failed to open /dev/dri/card0: Permission denied".
#
# Also seeds a minimal hyprland.lua (Hyprland 0.56.2's config moved to Lua -
# no more hyprland.conf) with stdout logging left on, since the
# auto-generated default silences it right before backend creation, which is
# exactly the diagnostic info needed when something goes wrong. This is a
# scaffold, not the final desktop config - Theme.qml/keybinds/widgets are
# Tasks 10/11's job.
#
# Needs a VM booted via vm/boot-dev-vm.ps1 (adds -device virtio-gpu-pci) to
# actually be usable afterward - vgem-only headless rendering does not work
# on this Aquamarine version (see docs/Research-Reference-List.md section 0).
#
# Run this ON THE INSTALLED GUEST, as root.
#
# Usage: setup-hyprland.sh <username>
set -eu

USERNAME="${1:?Usage: setup-hyprland.sh <username>}"
CONFIG_DIR="/home/$USERNAME/.config/hypr"
CONFIG_FILE="$CONFIG_DIR/hyprland.lua"

usermod -aG video "$USERNAME"

sudo -u "$USERNAME" mkdir -p "$CONFIG_DIR"
if [[ ! -f "$CONFIG_FILE" ]]; then
    sudo -u "$USERNAME" tee "$CONFIG_FILE" > /dev/null << 'EOF'
-- JAZZ minimal Hyprland config (Task 9 scaffold - Theme.qml/keybinds/widgets
-- come later in Tasks 10/11). Kept deliberately small: this exists to prove
-- Hyprland reaches a working, manageable session, not to be the final
-- desktop config.

hl.config({ debug = { enable_stdout_logs = true } })

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
EOF
fi

echo "Hyprland prepared for $USERNAME:"
id "$USERNAME"
ls -la "$CONFIG_FILE"
