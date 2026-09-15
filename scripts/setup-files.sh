#!/usr/bin/env bash
# Task 29: Jazz Files (real GUI file manager, v1). Installs the backend
# (jazz-files-ops, system-wide like jazz-theme-set/jazz-user-set - see
# setup-jazz-bin.sh's own note on why these live outside per-user
# provisioning) and enables udisks2, needed for the device sidebar's
# mount/unmount/eject actions.
#
# udisksctl already has its own polkit rule letting the active seat user
# manage removable media with no password prompt - confirmed live, 15 Sept
# 2026 (`pacman -Q udisks2` present, `udisksctl` binary present, service
# just needed enabling - no pkexec/agent dependency, unlike Task 32's
# abandoned polkit-for-user-management attempt).
#
# Run this ON THE INSTALLED GUEST, as root.
# Usage: setup-files.sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install -Dm755 "$SCRIPT_DIR/jazz-files-ops" /usr/local/bin/jazz-files-ops

systemctl enable --now udisks2.service

echo "Jazz Files backend installed:"
ls -la /usr/local/bin/jazz-files-ops
systemctl is-active udisks2.service
