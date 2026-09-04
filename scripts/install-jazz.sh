#!/usr/bin/env bash
# Master install script for JAZZ's post-base tooling layer. Chains every
# scripts/setup-*.sh in dependency order so a fresh install (Task 6's
# archinstall profile) can be brought up to a fully-tooled JAZZ system in one
# run - matches the project's own update model (git pull + re-run this
# script, with Snapper's auto-snapshot as the rollback safety net). Each
# sub-script is already idempotent, so this whole script is safe to re-run.
#
# Tracks A (filesystem/recovery) + C (AI engineering) only - Track B
# (desktop/Hyprland) has no setup script yet (deprioritized, see
# docs/Research-Reference-List.md), so it's not chained in here.
#
# Run this ON THE INSTALLED GUEST, as root.
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

echo "=== JAZZ install: Track A (filesystem/recovery) ==="
bash "$SCRIPT_DIR/setup-snapper.sh"

echo "=== JAZZ install: Track C (AI engineering) ==="
bash "$SCRIPT_DIR/setup-podman.sh" "$USERNAME"
bash "$SCRIPT_DIR/setup-ollama.sh" "$MODEL"
bash "$SCRIPT_DIR/setup-pyrit.sh"

echo "=== JAZZ install complete (Tracks A+C) ==="
echo "Track B (desktop) has no setup script yet - not included here."
