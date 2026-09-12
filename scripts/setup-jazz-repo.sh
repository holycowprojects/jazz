#!/usr/bin/env bash
# Persists a copy of the JAZZ repo's scripts/configs/design/docs at
# /opt/jazz on the installed guest (matching the existing /opt/jazz-aider,
# /opt/jazz-pyrit convention from Task 15/15b), so per-user provisioning
# (jazz-user-add, Task 32) can invoke the real setup-*.sh scripts for an
# ADDITIONAL user added after the initial install, not just the one
# archinstall created.
#
# Real finding this fixes (12 Sept 2026): before this script existed,
# scripts/ only ever reached the guest transiently (pushed to /tmp per
# SSH session from the dev machine's own checkout, never kept) - a new
# user created via jazz-user-add got a bare Linux account with none of
# JAZZ's own desktop config, just Hyprland's generic stock setup.
#
# Idempotent - safe to re-run (e.g. after `git pull`, to refresh /opt/jazz
# with whatever's currently in the repo). Run this FIRST in install-jazz.sh,
# from within a real repo checkout (uses this script's own location to find
# the repo root), as root.
#
# Usage: setup-jazz-repo.sh
set -eu

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="/opt/jazz"

mkdir -p "$DEST"
for dir in scripts configs design docs; do
    rm -rf "${DEST:?}/$dir"
    cp -r "$REPO_ROOT/$dir" "$DEST/$dir"
done
chmod -R a+rX "$DEST"

echo "JAZZ repo persisted at $DEST (scripts/configs/design/docs)"
