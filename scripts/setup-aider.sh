#!/usr/bin/env bash
# Installs Aider (AI pair-programming CLI) for Task-adjacent AI tooling.
# Aider isn't in Arch's official repos, and its PyPI package (aider-chat)
# requires Python <3.13 - Arch's official `python` is 3.14.7, so a plain
# venv off system Python (the PyRIT approach in setup-pyrit.sh) won't work
# here. Fix: uv (official repo) provisions its own isolated Python 3.12
# build independent of pacman, then builds the venv against that - still no
# AUR helper needed, matching the setup-extras.sh decision.
#
# Run this ON THE INSTALLED GUEST, as root.
set -euo pipefail

VENV=/opt/jazz-aider/venv

pacman -Sy --noconfirm --needed uv

if [[ ! -d "$VENV" ]]; then
    uv venv --python 3.12 "$VENV"
fi
uv pip install --python "$VENV/bin/python" aider-chat==0.86.2

ln -sf "$VENV/bin/aider" /usr/local/bin/aider

echo "Aider installed:"
"$VENV/bin/aider" --version
