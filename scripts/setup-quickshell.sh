#!/usr/bin/env bash
# Installs Quickshell (Task 10) and seeds one minimal clock widget - the
# research addendum's own recommended first step (a small widget from the
# Getting Started guide, not the full AI Command Centre yet - that's later
# once the widget backlog gets broken into real tasks).
#
# Quickshell (v0.3.1) is official-repo (extra/quickshell), confirmed live
# against Arch's package API - no AUR needed. Its real QML API was confirmed
# directly from the installed .qmltypes files on this VM, not guessed or
# taken from a (possibly stale) blog post: `import Quickshell` gets
# PanelWindow (re-exported via Quickshell._Window's default import) and
# SystemClock (Quickshell/SystemClock) - both confirmed via
# /usr/lib/qt6/qml/Quickshell/**/*.qmltypes.
#
# Run this ON THE INSTALLED GUEST, as root.
# Usage: setup-quickshell.sh <username>
set -eu

USERNAME="${1:?Usage: setup-quickshell.sh <username>}"
CONFIG_DIR="/home/$USERNAME/.config/quickshell"
CONFIG_FILE="$CONFIG_DIR/shell.qml"

pacman -Sy --noconfirm --needed quickshell

sudo -u "$USERNAME" mkdir -p "$CONFIG_DIR"
if [[ ! -f "$CONFIG_FILE" ]]; then
    sudo -u "$USERNAME" tee "$CONFIG_FILE" > /dev/null << 'EOF'
// JAZZ minimal Quickshell config (Task 10 scaffold). One widget - a live
// clock in a top panel bar - proving Quickshell renders under this VM's
// virtio-gpu-pci + Mesa software rendering (see vm/boot-dev-vm.ps1). The
// full widget backlog (Design-Vision.md sec 6) and Theme.qml (Task 11)
// come later - this exists to prove the mechanism works, not to be the
// final desktop shell.

import Quickshell
import QtQuick

ShellRoot {
    PanelWindow {
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: 32
        color: "#1e1d24"

        SystemClock {
            id: clock
            precision: SystemClock.Seconds
        }

        Text {
            anchors.centerIn: parent
            text: Qt.formatTime(clock.date, "hh:mm:ss")
            color: "#ede9e2"
            font.pixelSize: 16
        }
    }
}
EOF
fi

HYPR_CONFIG="/home/$USERNAME/.config/hypr/hyprland.lua"
if [[ -f "$HYPR_CONFIG" ]] && ! grep -q 'exec_cmd("quickshell")' "$HYPR_CONFIG"; then
    sudo -u "$USERNAME" tee -a "$HYPR_CONFIG" > /dev/null << 'EOF'

-- Added by setup-quickshell.sh (Task 10): Qt Quick's OpenGL/EGL scenegraph
-- fails here ("failed to create dri2 screen") - this VM's virtio-gpu-pci
-- only supports Mesa's software rasterizer (kms_swrast), confirmed already
-- for Aquamarine itself in Task 9. QT_QUICK_BACKEND=software is Qt's own
-- documented pure-software renderer, sidestepping EGL/DRI2 entirely -
-- confirmed live, not guessed. hl.env() sets these before the display
-- server initializes, so hl.exec_cmd()'d children inherit them correctly -
-- confirmed against the real environment-variables.md/autostart.md wiki
-- source via `gh api`, not guessed.
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QUICK_BACKEND", "software")

hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell")
end)
EOF
fi

echo "Quickshell prepared for $USERNAME:"
pacman -Q quickshell
ls -la "$CONFIG_FILE"
tail -15 "$HYPR_CONFIG"
