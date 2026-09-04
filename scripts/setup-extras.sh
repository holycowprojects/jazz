#!/usr/bin/env bash
# Installs a terminal emulator for Hyprland, OpenCode, and a few terminal
# toys Akash asked for. All from Arch's official repos - a deliberate call:
# hollywood, asciiquarium, and pipes.sh were skipped since they're AUR-only,
# and JAZZ doesn't run an AUR helper (keeps every setup script pacman-only,
# matching setup-snapper.sh/setup-podman.sh/setup-ollama.sh/setup-pyrit.sh).
#
# foot (not kitty/alacritty): Wayland-native, no GPU acceleration required -
# the safer pick given Task 9 hasn't yet confirmed hardware-accelerated
# rendering works at all under WHPX (see Research-Reference-List.md section 0).
#
# Aider is deliberately NOT here - it needs Python <3.13 (Arch's official
# python is 3.14.7), so it gets its own script (setup-aider.sh) with a
# uv-provisioned interpreter instead of a plain venv off system Python.
#
# Run this AS ROOT.
set -eu

pacman -Sy --noconfirm --needed foot opencode cmatrix fastfetch cava sl

echo "Extras installed:"
pacman -Q foot opencode cmatrix fastfetch cava sl
