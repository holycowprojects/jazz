#!/usr/bin/env bash
# Task 11: Theme.qml singleton + one functional-animation proof (a
# window-class-matched border color rule via Hyprland's windowrule,
# confirmed live-reevaluating, not just applied once at window open).
#
# Theme.qml's named color tokens match the workspace palette already agreed
# in Design-Vision.md sec 2 and used in the approved desktop-simulation
# mockup - not arbitrary placeholder colors. Registered as a real QML
# singleton via a local qmldir (`singleton Theme 1.0 Theme.qml`), so any
# .qml file in the same Quickshell config directory can reference `Theme`
# with no explicit import - standard QML directory-module behavior.
#
# shell.qml (from setup-quickshell.sh, Task 10) is REWRITTEN here to bind
# its panel color to Theme.forge instead of a hardcoded hex - proof the
# singleton is actually used, not just present. This script always wins
# over setup-quickshell.sh's initial version since it runs after it in
# install-jazz.sh's chain.
#
# The Hyprland-side border_color windowrule is a SEPARATE system from
# Theme.qml - Hyprland's Lua config and Quickshell's QML runtime don't
# share variables, so the windowrule's color is a literal hex chosen to
# match Theme.forge by convention, not a live binding between the two.
#
# Run this ON THE INSTALLED GUEST, as root.
# Usage: setup-theme.sh <username>
set -eu

USERNAME="${1:?Usage: setup-theme.sh <username>}"
QS_DIR="/home/$USERNAME/.config/quickshell"
THEME_FILE="$QS_DIR/Theme.qml"
QMLDIR_FILE="$QS_DIR/qmldir"
SHELL_FILE="$QS_DIR/shell.qml"
HYPR_CONFIG="/home/$USERNAME/.config/hypr/hyprland.lua"

sudo -u "$USERNAME" mkdir -p "$QS_DIR"

sudo -u "$USERNAME" tee "$THEME_FILE" > /dev/null << 'EOF'
pragma Singleton
import QtQuick

// JAZZ Theme singleton (Task 11) - named color tokens shared across every
// Quickshell widget. Values match the workspace palette agreed in
// Design-Vision.md sec 2 (and already used in the approved desktop-
// simulation mockup) - not arbitrary placeholders.
QtObject {
    readonly property color forge: "#4c6fa0"   // Coding, AI app engineering
    readonly property color lab: "#3e8e76"     // Notebooks, PyTorch/Jupyter
    readonly property color arena: "#c98a34"   // AI red-teaming
    readonly property color observe: "#7c919a" // Logs, metrics, AI Command Centre
    readonly property color vault: "#3a3d44"   // Secrets, sensitive config
    readonly property color range: "#a23a3a"   // Reserved - dormant
}
EOF

if [[ ! -f "$QMLDIR_FILE" ]] || ! grep -q '^singleton Theme ' "$QMLDIR_FILE"; then
    echo "singleton Theme 1.0 Theme.qml" | sudo -u "$USERNAME" tee -a "$QMLDIR_FILE" > /dev/null
fi

sudo -u "$USERNAME" tee "$SHELL_FILE" > /dev/null << 'EOF'
// JAZZ Quickshell config (Tasks 10-11). One widget - a live clock in a top
// panel bar - proving Quickshell renders under this VM's virtio-gpu-pci +
// Mesa software rendering (see vm/boot-dev-vm.ps1), now colored via
// Theme.qml's named singleton token (Task 11) instead of a hardcoded hex -
// proof the pattern works end to end, not just that the file exists.

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
        color: Theme.forge

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

if [[ -f "$HYPR_CONFIG" ]] && ! grep -q 'Added by setup-theme.sh' "$HYPR_CONFIG"; then
    sudo -u "$USERNAME" tee -a "$HYPR_CONFIG" > /dev/null << 'EOF'

-- Added by setup-theme.sh (Task 11): border_color is a "dynamic effect" -
-- re-evaluated live on every property change, not applied once at window
-- open (confirmed against the real window-rules.md wiki source via
-- `gh api`, not guessed). A foot terminal gets Theme.qml's Forge color as
-- its border; editing this value + `hyprctl reload` changes it without
-- restarting Hyprland or the window itself.
hl.window_rule({
    match = { class = "^(foot)$" },
    border_color = "rgb(4c6fa0)",
})
EOF
fi

echo "Theme prepared for $USERNAME:"
ls -la "$THEME_FILE" "$QMLDIR_FILE" "$SHELL_FILE"
echo "-- hyprland.lua tail --"
tail -12 "$HYPR_CONFIG"
