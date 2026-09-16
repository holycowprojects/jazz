#!/usr/bin/env bash
# Verifies Task 10: Quickshell actually runs under the real Hyprland session
# from Task 9, auto-started the real way (Hyprland's own
# hl.on("hyprland.start", ...) - see setup-quickshell.sh), and the one clock
# widget renders - not just that the binary exists.
#
# Must run against a VM booted via vm/boot-dev-vm.ps1 (-device
# virtio-gpu-pci) with Hyprland prepared (setup-hyprland.sh) and Quickshell
# seeded (setup-quickshell.sh).
#
# Note: PanelWindow uses the wlr-layer-shell protocol (bars/panels), not a
# regular toplevel window - `hyprctl clients` will never show it. Use
# `hyprctl layers` instead - confirmed live, not guessed.
#
# Run this ON THE INSTALLED GUEST, as root.
# Usage: verify/quickshell.sh <username>
set -uo pipefail

USERNAME="${1:?Usage: verify/quickshell.sh <username>}"
UID_N=$(id -u "$USERNAME")
HOME_DIR="/home/$USERNAME"
RUNTIME_DIR="/run/user/$UID_N"
HYPR_LOG=/tmp/jazz-hypr-qs-verify.log
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

# cwd matters here too (see setup-hyprland.sh / verify/hyprland.sh) - launch
# from a directory holycowstudios can actually chdir() into. Quickshell is
# NOT launched manually here - hyprland.lua's own hl.on("hyprland.start",
# ...) is what starts it, exactly as a real session would.
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
    echo "0 passed, 1 failed"
    exit 1
fi

if pgrep -u "$USERNAME" -f quickshell > /dev/null; then
    echo "PASS: Quickshell auto-started via hl.on(\"hyprland.start\", ...) and is running"
    pass=$((pass + 1))
else
    echo "FAIL: no quickshell process found - see $HYPR_LOG"
    tail -30 "$HYPR_LOG" 2>/dev/null
    fail=$((fail + 1))
fi

layers_out=$(hyprctl layers)
if echo "$layers_out" | grep -q "namespace: quickshell"; then
    echo "PASS: Quickshell's panel widget is a real, visible layer-shell surface"
    echo "$layers_out" | grep "namespace: quickshell"
    pass=$((pass + 1))
else
    echo "FAIL: no quickshell layer surface seen in hyprctl layers"
    echo "$layers_out"
    fail=$((fail + 1))
fi

echo "---"
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
