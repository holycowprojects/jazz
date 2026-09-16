#!/usr/bin/env bash
# Installs JAZZ's standalone user-facing scripts to /usr/local/bin.
#
# Real gap found and fixed 14 Sept 2026: jazz-theme-set, jazz-font-set, and
# the four jazz-user-* scripts (Task 32) were built and live-tested against
# the dev machine, but no setup script ever actually installed them there -
# they only existed on the Yoga 6 because they were pscp'd/installed by
# hand during interactive work. Confirmed live via `ls /usr/local/bin`: all
# six existed on the guest, but a `grep -r "install -Dm755"` across the
# whole scripts/ dir only ever found jazz-agent-action's own install line
# (setup-agent-safety.sh). A clean clone (Task 20's own success criterion)
# would have silently produced a system with none of Task 32's UI-wired
# features actually callable. jazz-wallpaper-set is NOT included here - it
# isn't a file in this repo, setup-wallpaper.sh authors it directly via
# heredoc (see that script) and that's unaffected by this fix.
#
# These are system-wide binaries (like jazz-agent-action), not per-user
# desktop config - install once via install-jazz.sh, not per-user via
# jazz-user-add.
#
# Run this ON THE INSTALLED GUEST, as root.
# Usage: setup-jazz-bin.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for script in jazz-theme-set jazz-font-set jazz-user-add jazz-user-remove jazz-user-set jazz-user-passwd jazz-idle-set jazz-user-avatar; do
    install -Dm755 "$SCRIPT_DIR/$script" "/usr/local/bin/$script"
done

echo "Installed to /usr/local/bin:"
ls -la /usr/local/bin/jazz-theme-set /usr/local/bin/jazz-font-set /usr/local/bin/jazz-user-* /usr/local/bin/jazz-idle-set
