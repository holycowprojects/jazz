#!/usr/bin/env bash
# Installs Jazz Settings' extracted Settings.qml (Task 28). Run AFTER
# setup-dock.sh in install-jazz.sh - setup-dock.sh's shell.qml now just
# Loader{}s this file instead of defining the Settings panel inline (it
# outgrew a single 1000+ line heredoc, matching the task's own plan).
#
# Uses the same @@PLACEHOLDER@@ + sed convention as setup-dock.sh (a quoted
# heredoc, not inline bash expansion - see that script's header comment for
# why unquoted heredocs are a real, previously-hit bug here).
#
# Run this ON THE INSTALLED GUEST, as root.
# Usage: setup-settings.sh <username>
set -euo pipefail

USERNAME="${1:?Usage: setup-settings.sh <username>}"
QS_DIR="/home/$USERNAME/.config/quickshell"
SETTINGS_FILE="$QS_DIR/Settings.qml"
DATA_DIR="/home/$USERNAME/.local/share/jazz"
CONFIG_DIR="/home/$USERNAME/.config/jazz"
SETTINGS_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../configs/quickshell" && pwd)/Settings.qml"
KEYBINDS_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../docs" && pwd)/Keybinds.md"
HYPR_EVENTS_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../configs/quickshell" && pwd)/jazz-hypr-events.py"

sudo -u "$USERNAME" mkdir -p "$QS_DIR" "$CONFIG_DIR" "$DATA_DIR"
sudo -u "$USERNAME" cp "$SETTINGS_SRC" "$SETTINGS_FILE"
sudo -u "$USERNAME" cp "$KEYBINDS_SRC" "$DATA_DIR/Keybinds.md"
sudo -u "$USERNAME" cp "$HYPR_EVENTS_SRC" "$DATA_DIR/jazz-hypr-events.py"

sed -i "s|@@JAZZ_DATA_DIR@@|$DATA_DIR|g; s|@@JAZZ_CONFIG_DIR@@|$CONFIG_DIR|g" "$SETTINGS_FILE"

echo "Jazz Settings installed to $SETTINGS_FILE"
echo "Reload Quickshell (or restart Hyprland) to pick up the new Settings panel."
