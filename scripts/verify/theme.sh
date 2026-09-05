#!/usr/bin/env bash
# Verifies Task 11: Theme.qml exists as a real singleton with named color
# tokens, shell.qml actually uses it (not just present unused), and
# Hyprland accepts the border_color windowrule without breaking anything
# already working (Quickshell still renders, a real window still opens).
#
# Border color itself is NOT checked here - hyprctl doesn't expose a
# window's rendered border color as text, and the task's own verification
# method is a manual visual check (screenshot), done separately, not
# something this repeatable script re-confirms every run.
#
# Run this ON THE INSTALLED GUEST, as root.
# Usage: verify/theme.sh <username>
set -u

USERNAME="${1:?Usage: verify/theme.sh <username>}"
UID_N=$(id -u "$USERNAME")
HOME_DIR="/home/$USERNAME"
RUNTIME_DIR="/run/user/$UID_N"
QS_DIR="$HOME_DIR/.config/quickshell"
HYPR_CONFIG="$HOME_DIR/.config/hypr/hyprland.lua"
HYPR_LOG=/tmp/jazz-hypr-theme-verify.log
pass=0
fail=0

cleanup() {
    pkill -u "$USERNAME" -f quickshell 2>/dev/null
    pkill -u "$USERNAME" -f foot 2>/dev/null
    pkill -u "$USERNAME" -f Hyprland 2>/dev/null
}
trap cleanup EXIT
cleanup
sleep 1
rm -f "$HYPR_LOG"

if grep -q 'pragma Singleton' "$QS_DIR/Theme.qml" 2>/dev/null && grep -q 'property color forge' "$QS_DIR/Theme.qml" 2>/dev/null; then
    echo "PASS: Theme.qml exists as a real singleton with a named color token"
    pass=$((pass + 1))
else
    echo "FAIL: Theme.qml missing or malformed"
    fail=$((fail + 1))
fi

if grep -q '^singleton Theme ' "$QS_DIR/qmldir" 2>/dev/null; then
    echo "PASS: qmldir registers Theme as a singleton"
    pass=$((pass + 1))
else
    echo "FAIL: qmldir does not register Theme"
    fail=$((fail + 1))
fi

if grep -q 'color: Theme.forge' "$QS_DIR/shell.qml" 2>/dev/null; then
    echo "PASS: shell.qml actually binds to Theme.forge, not a hardcoded hex"
    pass=$((pass + 1))
else
    echo "FAIL: shell.qml does not reference Theme"
    fail=$((fail + 1))
fi

if grep -q 'hl.window_rule' "$HYPR_CONFIG" 2>/dev/null && grep -q 'border_color' "$HYPR_CONFIG" 2>/dev/null; then
    echo "PASS: hyprland.lua has a border_color window rule"
    pass=$((pass + 1))
else
    echo "FAIL: hyprland.lua missing the border_color window rule"
    fail=$((fail + 1))
fi

# Now confirm none of the above broke anything live: Hyprland starts,
# Quickshell auto-starts using Theme.qml without a QML error, and a real
# window matching the windowrule's class actually opens.
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

if pgrep -u "$USERNAME" -f quickshell > /dev/null && hyprctl layers | grep -q "namespace: quickshell"; then
    echo "PASS: Quickshell still auto-starts and renders with Theme.qml wired in"
    pass=$((pass + 1))
else
    echo "FAIL: Quickshell did not start cleanly - see $HYPR_LOG"
    tail -30 "$HYPR_LOG" 2>/dev/null
    fail=$((fail + 1))
fi

hyprctl dispatch 'hl.dsp.exec_cmd("foot")' > /dev/null
sleep 3
if hyprctl clients | grep -q "class: foot"; then
    echo "PASS: a real window matching the windowrule's class opened without Hyprland erroring on the new config"
    pass=$((pass + 1))
else
    echo "FAIL: foot did not open - hyprland.lua may have a config error"
    hyprctl clients
    fail=$((fail + 1))
fi

echo "---"
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
