#!/usr/bin/env bash
# Task 33: extends jazz-theme-set's "set once, propagates everywhere" chain
# to ly (the login greeter) - the one desktop-adjacent surface outside any
# single user's own session. Real mechanism: ly's config.ini lives in /etc,
# so no per-user jazz-theme-set invocation (self-service, no root, runs on
# every Appearance-tab theme click) can write it directly. Instead:
# jazz-theme-set (any user) drops the chosen theme's colors in a small
# world-writable state file, and a systemd drop-in on ly@.service applies
# them to config.ini via jazz-ly-theme-sync (root) right before the greeter
# itself starts each time - so ly always reflects whichever theme was MOST
# RECENTLY applied by ANY user on this machine, matching Task 33's own
# framing ("the login screen matches whichever theme was last active").
#
# System-wide, install once (like setup-jazz-bin.sh/setup-agent-safety.sh),
# not per-user.
#
# Run this ON THE INSTALLED GUEST, as root.
# Usage: setup-ly-theme.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="/var/lib/jazz"
STATE_FILE="$STATE_DIR/ly-theme.json"

mkdir -p "$STATE_DIR"
chmod 1777 "$STATE_DIR"
if [[ ! -f "$STATE_FILE" ]]; then
    echo '{}' > "$STATE_FILE"
fi
chmod 666 "$STATE_FILE"

install -Dm755 "$SCRIPT_DIR/jazz-ly-theme-sync" /usr/local/bin/jazz-ly-theme-sync

mkdir -p /etc/systemd/system/ly@.service.d
tee /etc/systemd/system/ly@.service.d/jazz-theme.conf > /dev/null << 'EOF'
[Service]
ExecStartPre=/usr/local/bin/jazz-ly-theme-sync
EOF

systemctl daemon-reload

echo "ly theme sync installed - takes effect the next time ly@<tty>.service (re)starts (login-screen restart or reboot), not live."
