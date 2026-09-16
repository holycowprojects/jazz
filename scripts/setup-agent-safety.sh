#!/usr/bin/env bash
# Installs jazz-agent-action (Task 30) - the permission-tier + Checkpoint ->
# Act -> Undo safety wrapper every future AI-driven JAZZ feature calls
# instead of acting directly. Plain script + a Snapper wrapper, no daemon
# (per the confirmed 7 Sept 2026 architecture decision: stay lightweight,
# promote to a real service only if it earns it).
#
# Run this ON THE INSTALLED GUEST, as root (installs to /usr/local/bin).
#
# Usage: setup-agent-safety.sh <username>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USERNAME="${1:?Usage: setup-agent-safety.sh <username>}"

install -Dm755 "$SCRIPT_DIR/jazz-agent-action" /usr/local/bin/jazz-agent-action

USER_HOME=$(getent passwd "$USERNAME" | cut -d: -f6)
sudo -u "$USERNAME" mkdir -p "$USER_HOME/.local/share/jazz" "$USER_HOME/.config/jazz"

echo "jazz-agent-action installed to /usr/local/bin/jazz-agent-action"
jazz-agent-action classify launch_app
jazz-agent-action classify install_package
jazz-agent-action classify sudo_exec
