#!/usr/bin/env bash
# Task 29: Jazz Files (real GUI file manager, v1). Installs the backend
# (jazz-files-ops, system-wide like jazz-theme-set/jazz-user-set - see
# setup-jazz-bin.sh's own note on why these live outside per-user
# provisioning), enables udisks2 (device sidebar's mount/unmount/eject -
# confirmed live, no polkit/pkexec needed, unlike Task 32's abandoned
# attempt for user management), and deploys Files.qml per-user, same
# Loader-based pattern and same copy+sed technique as Welcome.qml
# (setup-welcome.sh) - shell.qml's own `Loader { source: "Files.qml" }`
# line (setup-dock.sh) is what actually wires it into the running shell.
#
# Run this ON THE INSTALLED GUEST, as root. Run AFTER setup-dock.sh (needs
# the Files Loader line already in shell.qml).
# Usage: setup-files.sh <username>
set -eu

USERNAME="${1:?Usage: setup-files.sh <username>}"
HOME_DIR="/home/$USERNAME"
QS_DIR="$HOME_DIR/.config/quickshell"
DATA_DIR="$HOME_DIR/.local/share/jazz"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES_QML_SRC="$(cd "$SCRIPT_DIR/../configs/quickshell" && pwd)/Files.qml"

install -Dm755 "$SCRIPT_DIR/jazz-files-ops" /usr/local/bin/jazz-files-ops
systemctl enable --now udisks2.service

sudo -u "$USERNAME" mkdir -p "$QS_DIR" "$DATA_DIR"
sudo -u "$USERNAME" cp "$FILES_QML_SRC" "$QS_DIR/Files.qml"
sed -i "s|@@JAZZ_DATA_DIR@@|$DATA_DIR|g" "$QS_DIR/Files.qml"

echo "Jazz Files installed for $USERNAME:"
ls -la /usr/local/bin/jazz-files-ops "$QS_DIR/Files.qml"
systemctl is-active udisks2.service
