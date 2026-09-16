#!/usr/bin/env bash
# Verifies the Tier 1 widget panel (World clock, Notes, To-do, Pomodoro -
# Design-Vision.md sec 6) - the first batch broken out of the widget
# backlog now that Task 10/11 proved Quickshell+Theme.qml works.
#
# NOTE: the setup script that originally wrote this content
# (setup-widgets-tier1.sh) was retired 12 Sept 2026 - it was fully
# superseded by setup-dock.sh, which now writes shell.qml (including this
# panel) instead. This verify script still checks the right thing (the
# tokens below still land in shell.qml via setup-dock.sh), just via a
# different setup script than the one named above.
#
# Full interaction (typing a note, clicking a checkbox/timer button) isn't
# scripted here - there's no Hyprland IPC for synthetic pointer input, and
# a real screenshot (grim) already confirmed live rendering + correct World
# Clock math during development. This script checks structure (the config
# actually contains what it should) and that adding this panel didn't
# break anything already working (Quickshell still auto-starts, both
# PanelWindows register as real layer-shell surfaces).
#
# Run this ON THE INSTALLED GUEST, as root.
# Usage: verify/widgets-tier1.sh <username>
set -uo pipefail

USERNAME="${1:?Usage: verify/widgets-tier1.sh <username>}"
UID_N=$(id -u "$USERNAME")
HOME_DIR="/home/$USERNAME"
RUNTIME_DIR="/run/user/$UID_N"
QS_DIR="$HOME_DIR/.config/quickshell"
HYPR_LOG=/tmp/jazz-hypr-widgets-verify.log
pass=0
fail=0

cleanup() {
    pkill -u "$USERNAME" -f quickshell 2>/dev/null
    pkill -u "$USERNAME" -f Hyprland 2>/dev/null
}
trap cleanup EXIT
cleanup
sleep 1
rm -f "$HYPR_LOG"

for token in "FileView" "ListModel" "WORLD CLOCK" "NOTES" "TO-DO" "pomo"; do
    if grep -q "$token" "$QS_DIR/shell.qml" 2>/dev/null; then
        echo "PASS: shell.qml contains '$token'"
        pass=$((pass + 1))
    else
        echo "FAIL: shell.qml missing '$token'"
        fail=$((fail + 1))
    fi
done

if grep -q 'property color panel:' "$QS_DIR/Theme.qml" 2>/dev/null; then
    echo "PASS: Theme.qml has the neutral panel color token"
    pass=$((pass + 1))
else
    echo "FAIL: Theme.qml missing the panel token"
    fail=$((fail + 1))
fi

sudo -u "$USERNAME" env XDG_RUNTIME_DIR="$RUNTIME_DIR" \
    bash -c "cd $HOME_DIR && nohup Hyprland > $HYPR_LOG 2>&1 & disown"
sleep 8

SIG=$(find "$RUNTIME_DIR/hypr" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | tail -1 | xargs -r basename)

hyprctl() {
    sudo -u "$USERNAME" env XDG_RUNTIME_DIR="$RUNTIME_DIR" HYPRLAND_INSTANCE_SIGNATURE="$SIG" hyprctl "$@" 2>&1
}

if [[ -z "$SIG" ]] || ! hyprctl version | grep -q "^Hyprland "; then
    echo "FAIL: no working Hyprland instance - see $HYPR_LOG"
    tail -30 "$HYPR_LOG" 2>/dev/null
    echo "---"
    echo "$pass passed, $((fail + 1)) failed"
    exit 1
fi

if pgrep -u "$USERNAME" -f quickshell > /dev/null; then
    echo "PASS: Quickshell still auto-starts with the widget panel added"
    pass=$((pass + 1))
else
    echo "FAIL: Quickshell did not start - see $HYPR_LOG"
    tail -30 "$HYPR_LOG" 2>/dev/null
    fail=$((fail + 1))
fi

layer_count=$(hyprctl layers | grep -c "namespace: quickshell")
if [[ "$layer_count" -ge 2 ]]; then
    echo "PASS: both PanelWindows (top bar + widget panel) registered as real layer-shell surfaces ($layer_count found)"
    pass=$((pass + 1))
else
    echo "FAIL: expected 2 quickshell layers, found $layer_count"
    hyprctl layers
    fail=$((fail + 1))
fi

echo "---"
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
