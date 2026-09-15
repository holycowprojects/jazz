#!/usr/bin/env bash
# Task: real screenshot capture (birdeye review finding, 15 Sept 2026).
# Installs satty (the annotation editor Omarchy itself uses - confirmed
# real via their own bin/omarchy-capture-screenshot source, official
# `extra` repo, not AUR) and jazz-screenshot to /usr/local/bin. grim/
# slurp/wl-copy/dunstify are all already installed (confirmed live)
# so nothing else to add.
#
# Run this ON THE INSTALLED GUEST, as root.
# Usage: setup-screenshot.sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pacman -Sy --noconfirm --needed satty

install -Dm755 "$SCRIPT_DIR/jazz-screenshot" /usr/local/bin/jazz-screenshot

echo "Screenshot capture installed:"
ls -la /usr/local/bin/jazz-screenshot
pacman -Q satty
