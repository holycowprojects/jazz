#!/usr/bin/env bash
# Master install script for JAZZ's post-base tooling layer. Chains every
# scripts/setup-*.sh in dependency order so a fresh install (Task 6's
# archinstall profile) can be brought up to a fully-tooled JAZZ system in one
# run - matches the project's own update model (git pull + re-run this
# script, with Snapper's auto-snapshot as the rollback safety net). Each
# sub-script is already idempotent, so this whole script is safe to re-run.
#
# Tracks A (filesystem/recovery) + B (desktop: Hyprland, Quickshell, Theme,
# Tier 1 widgets) + C (AI engineering) + a small preinstalled extras layer +
# a normal desktop app layer (consumer/productivity/creator/gaming).
# Tier 2-4 widgets (Design-Vision.md sec 6) still have no setup script -
# extend THIS file when they do, don't add a second master installer.
#
# Run this ON THE INSTALLED GUEST, as root. Note: setup-hyprland.sh itself
# needs no GPU access to run (just usermod + writing a config file), but
# actually USING the resulting Hyprland session needs the VM booted via
# vm/boot-dev-vm.ps1 (adds -device virtio-gpu-pci).
#
# Usage: install-jazz.sh <username> [ollama-model]
#   <username>      the non-root sudo user rootless Podman gets configured
#                    for - matches install/base-profile.json's user (e.g.
#                    holycowstudios)
#   [ollama-model]  passed straight to setup-ollama.sh, defaults to
#                    qwen2.5:0.5b
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USERNAME="${1:?Usage: install-jazz.sh <username> [ollama-model]}"
MODEL="${2:-qwen2.5:0.5b}"

echo "=== JAZZ install: persist repo at /opt/jazz (for per-user re-provisioning, Task 32) ==="
bash "$SCRIPT_DIR/setup-jazz-repo.sh"

echo "=== JAZZ install: standalone /usr/local/bin scripts (theme/font/user/idle helpers) ==="
bash "$SCRIPT_DIR/setup-jazz-bin.sh"

echo "=== JAZZ install: Jazz Files backend (Task 29) ==="
bash "$SCRIPT_DIR/setup-files.sh"

echo "=== JAZZ install: ly login-screen theming (Task 33) ==="
bash "$SCRIPT_DIR/setup-ly-theme.sh"

echo "=== JAZZ install: boot branding (os-release title, stub splash, EFI entry label - Task 33) ==="
bash "$SCRIPT_DIR/setup-boot-branding.sh"

echo "=== JAZZ install: Track A (filesystem/recovery) ==="
bash "$SCRIPT_DIR/setup-snapper.sh"

echo "=== JAZZ install: Agent safety (permission tiers + Checkpoint -> Act -> Undo) ==="
bash "$SCRIPT_DIR/setup-agent-safety.sh" "$USERNAME"

echo "=== JAZZ install: Track B (desktop) ==="
bash "$SCRIPT_DIR/setup-hyprland.sh" "$USERNAME"
bash "$SCRIPT_DIR/setup-quickshell.sh" "$USERNAME"
bash "$SCRIPT_DIR/setup-theme.sh" "$USERNAME"
bash "$SCRIPT_DIR/setup-dock.sh" "$USERNAME"
bash "$SCRIPT_DIR/setup-settings.sh" "$USERNAME"
bash "$SCRIPT_DIR/setup-welcome.sh" "$USERNAME"
bash "$SCRIPT_DIR/setup-wallpaper.sh" "$USERNAME"
bash "$SCRIPT_DIR/setup-kvantum.sh" "$USERNAME"
bash "$SCRIPT_DIR/setup-theme-bundle.sh" "$USERNAME"
bash "$SCRIPT_DIR/setup-hypridle.sh" "$USERNAME"

echo "=== JAZZ install: Track C (AI engineering) ==="
bash "$SCRIPT_DIR/setup-podman.sh" "$USERNAME"
bash "$SCRIPT_DIR/setup-ollama.sh" "$MODEL"
bash "$SCRIPT_DIR/setup-pyrit.sh"

echo "=== JAZZ install: Extras (terminal, CLI toys, AI coding tools) ==="
bash "$SCRIPT_DIR/setup-extras.sh"
bash "$SCRIPT_DIR/setup-aider.sh"

echo "=== JAZZ install: Desktop apps (consumer/productivity/creator/gaming) ==="
bash "$SCRIPT_DIR/setup-desktop-apps.sh"

echo "=== JAZZ install complete (Tracks A+B+C + extras + desktop apps) ==="
echo "Tier 2-4 widgets (Design-Vision.md sec 6) have no setup script yet - not included here."
