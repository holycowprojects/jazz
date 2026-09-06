#!/usr/bin/env bash
# Prepares Hyprland for Task 9 (desktop). archinstall's base profile already
# installed hyprland/aquamarine/mesa/seatd (Task 4) - this script does the
# one real fix found live: the target user needs `video` group membership.
# card0 is root:video, and Mesa's EGL/DRI2 init opens it directly (not
# seatd-mediated for this specific call), so without it every session dies
# instantly with "failed to open /dev/dri/card0: Permission denied".
#
# Also authors JAZZ's own hyprland.lua (Hyprland 0.56.2's config moved to
# Lua - no more hyprland.conf), unconditionally - see Task 21
# (docs/Research-Reference-List.md / tasks/todo.md): Hyprland's own package
# auto-generates a stock example hyprland.lua the first time the compositor
# ever launches (e.g. a curious login before install-jazz.sh runs), so a
# "only write if missing" guard silently loses to that stock file and every
# later Track B script ends up appending onto Hyprland's own examples
# instead of JAZZ's config. Fixed here: always author JAZZ's version,
# backing up whatever was there first (rollback safety, not silently
# discarded).
#
# Real keybinds from the start (not a placeholder scaffold): a real
# terminal + launcher (wofi, the package actually installed - Design-
# Vision.md sec 6 Tier 2 covers restyling this later, not replacing it),
# basic window management, and workspace-switching keybinds pre-named for
# the six workspace identities in Design-Vision.md sec 2 (Forge/Lab/Arena/
# Observe/Vault/Range) - the colors/AI Command Centre for those are still
# unbuilt backlog, but the keybinds/names exist now so they don't need
# reinventing later.
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

if [[ -f "$CONFIG_FILE" ]] && ! grep -q 'JAZZ base Hyprland config' "$CONFIG_FILE"; then
    sudo -u "$USERNAME" cp "$CONFIG_FILE" "$CONFIG_FILE.stock-backup-$(date +%s)"
fi

if [[ ! -f "$CONFIG_FILE" ]] || ! grep -q 'JAZZ base Hyprland config' "$CONFIG_FILE"; then
    sudo -u "$USERNAME" tee "$CONFIG_FILE" > /dev/null << 'EOF'
-- JAZZ base Hyprland config (Task 9/21). Real keybinds and workspace names
-- from the start - not a placeholder scaffold ceded to Hyprland's own
-- stock auto-generated example config. Theme.qml/widgets/dock (Tasks
-- 10/11/22) append onto this file; the AI Command Centre + workspace
-- identity colors (Design-Vision.md sec 2/4) are still unbuilt backlog.

hl.config({ debug = { enable_stdout_logs = true } })

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

local terminal    = "kitty"
local fileManager = "dolphin"
local menu        = "wofi --show drun"
local mainMod     = "SUPER"

-- Every dispatcher call below confirmed against the real
-- hyprwm/hyprland-wiki source (content/configuring/core/dispatchers.md and
-- naming-conventions.md) via `gh api`, not guessed - the general
-- exit()/named-workspace-selector/toggle_special syntax in particular is
-- easy to get wrong by analogy to the old hyprland.conf dispatcher names.
-- Full reference kept in docs/Keybinds.md - update that file too if any
-- bind here changes.

-- Launching
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))

-- Window state: close/float/maximize/fullscreen are four distinct dynamic
-- effects in the real dispatcher list, not one generic "toggle" - maximize
-- keeps the bar/margins (mode = "maximized"), fullscreen hides everything
-- (mode = "fullscreen"). Minimize has no native Hyprland concept (tiling
-- WM, no taskbar) - implemented as moving the window to a special
-- "minimized" scratchpad workspace, which the dock (Task 22) will list and
-- let you click to restore, same mechanism either way.
hl.bind(mainMod .. " + Q", hl.dsp.window.close({}))
hl.bind(mainMod .. " + V", hl.dsp.window.float({}))
hl.bind(mainMod .. " + M", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mainMod .. " + H", hl.dsp.window.move({ workspace = "special:minimized" }))
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.workspace.toggle_special("minimized"))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit())
hl.bind(mainMod .. " + Tab", hl.dsp.focus({ workspace = "previous" }))

-- Moving focus between tiled windows, and moving a window itself, in a
-- direction - core tiling-WM navigation, missing from the first draft.
local directions = { l = "Left", r = "Right", u = "Up", d = "Down" }
for dir, key in pairs(directions) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = dir }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }))
end

-- Design-Vision.md sec 2's six workspace identities - named now so the
-- colors/AI Command Centre (still backlog) have somewhere real to attach
-- later, not invented from scratch then. Workspace switching is a `focus`
-- dispatcher, not a `workspace.*` one - hl.dsp.workspace only covers
-- change_id/rename/move-to-monitor/swap_monitors/toggle_special, confirmed
-- from the real dispatcher list. Named workspaces are selected via the
-- "name:X" selector string (naming-conventions.md), not a bare name.
local workspaces = { "Forge", "Lab", "Arena", "Observe", "Vault", "Range" }
for i, name in ipairs(workspaces) do
    hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = "name:" .. name }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = "name:" .. name }))
end
EOF
fi

echo "Hyprland prepared for $USERNAME:"
id "$USERNAME"
ls -la "$CONFIG_FILE"
