#!/usr/bin/env bash
# Task 33: first-boot Welcome app. Same Loader-based pattern as Settings.qml
# (Task 28) - a separate QML file, copied into place and loaded from
# shell.qml (setup-dock.sh's own heredoc now includes
# `Loader { source: "Welcome.qml" }` right after the Settings Loader).
#
# Shown once per account via a marker file ($JAZZ_DATA_DIR/welcome-shown) -
# the same FileView onLoaded/onLoadFailed convention already used for
# Notes/To-do (setup-dock.sh): onLoadFailed means the marker was never
# written (genuinely first boot), onLoaded means it's already been
# dismissed. Nothing in this script pre-seeds that marker - the file
# simply doesn't exist until Welcome.qml's own "Let's go" button writes it,
# so a fresh account always sees it once.
#
# Run this ON THE INSTALLED GUEST, as root. Run AFTER setup-settings.sh
# (needs Keybinds.md already copied to $JAZZ_DATA_DIR) and AFTER
# setup-dock.sh (needs the Welcome Loader line already in shell.qml).
# Usage: setup-welcome.sh <username>
set -euo pipefail

USERNAME="${1:?Usage: setup-welcome.sh <username>}"

# `less` isn't guaranteed present on every install (confirmed live, 16 Sept
# 2026: it's not part of Arch's base package set, and base-profile.json only
# started listing it after this was found) - the Welcome app's "View
# keybinds" button opens Keybinds.md in `less`, so make sure it exists
# regardless of whether this is a fresh install or a `git pull` + re-run on
# an existing system.
pacman -Sy --noconfirm --needed less

QS_DIR="/home/$USERNAME/.config/quickshell"
WELCOME_FILE="$QS_DIR/Welcome.qml"
DATA_DIR="/home/$USERNAME/.local/share/jazz"
WELCOME_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../configs/quickshell" && pwd)/Welcome.qml"

sudo -u "$USERNAME" mkdir -p "$QS_DIR" "$DATA_DIR"
sudo -u "$USERNAME" cp "$WELCOME_SRC" "$WELCOME_FILE"
sed -i "s|@@JAZZ_DATA_DIR@@|$DATA_DIR|g" "$WELCOME_FILE"

echo "Welcome app installed to $WELCOME_FILE"
