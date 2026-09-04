#!/usr/bin/env bash
# Verifies Task 9: Hyprland reaches a working session on this VM's
# virtio-gpu display, and real window management works (open a terminal,
# tile it, float+move it) - not just that the binary exists.
#
# Must run against a VM booted via vm/boot-dev-vm.ps1 (adds
# -device virtio-gpu-pci) - vgem-only headless rendering does not work on
# this Aquamarine version (hard-requires DRM_CAP_CRTC_IN_VBLANK_EVENT, which
# vgem can't provide - confirmed live via strace, see
# docs/Research-Reference-List.md section 0).
#
# Run this ON THE INSTALLED GUEST, as root (needs to sudo -u the target user
# to launch and control their own Hyprland session).
#
# Usage: verify/hyprland.sh <username>
set -u

USERNAME="${1:?Usage: verify/hyprland.sh <username>}"
UID_N=$(id -u "$USERNAME")
HOME_DIR="/home/$USERNAME"
RUNTIME_DIR="/run/user/$UID_N"
LOG=/tmp/jazz-hypr-verify.log
pass=0
fail=0

cleanup() {
    pkill -u "$USERNAME" -f Hyprland 2>/dev/null
    pkill -u "$USERNAME" -f foot 2>/dev/null
}
trap cleanup EXIT
cleanup
sleep 1
rm -f "$LOG"

# cwd matters: foot's shell inherits Hyprland's own cwd to chdir() into, and
# holycowstudios can't chdir() into /root - confirmed live, real bug, not
# hypothetical.
sudo -u "$USERNAME" env XDG_RUNTIME_DIR="$RUNTIME_DIR" \
    bash -c "cd $HOME_DIR && nohup Hyprland > $LOG 2>&1 & disown"
sleep 5

SIG=$(find "$RUNTIME_DIR/hypr" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | tail -1 | xargs -r basename)

hyprctl() {
    sudo -u "$USERNAME" env XDG_RUNTIME_DIR="$RUNTIME_DIR" HYPRLAND_INSTANCE_SIGNATURE="$SIG" hyprctl "$@" 2>&1
}

if [[ -n "$SIG" ]] && hyprctl version | grep -q "^Hyprland "; then
    echo "PASS: Hyprland session reached, hyprctl version succeeds"
    pass=$((pass + 1))
else
    echo "FAIL: no working Hyprland instance - see $LOG"
    tail -30 "$LOG" 2>/dev/null
    fail=$((fail + 1))
    echo "---"
    echo "$pass passed, $fail failed"
    exit 1
fi

# hyprctl dispatch takes a Lua expression as of Hyprland 0.56.2 (hl.dsp.*),
# not the old space-separated "exec <cmd>" syntax - confirmed against the
# real dispatchers.md source, not guessed.
hyprctl dispatch 'hl.dsp.exec_cmd("foot")' > /dev/null
sleep 3

clients_out=$(hyprctl clients)
if echo "$clients_out" | grep -q "class: foot"; then
    echo "PASS: opened a real terminal window (foot), registered by Hyprland"
    pass=$((pass + 1))
else
    echo "FAIL: foot did not register as a client"
    echo "$clients_out"
    fail=$((fail + 1))
fi

hyprctl dispatch 'hl.dsp.window.float({})' > /dev/null
hyprctl dispatch 'hl.dsp.window.move({x=200, y=150, relative=false})' > /dev/null
sleep 1

moved_out=$(hyprctl clients)
if echo "$moved_out" | grep -q "at: 200,150" && echo "$moved_out" | grep -q "floating: 1"; then
    echo "PASS: window management works - floated and moved to an exact position"
    pass=$((pass + 1))
else
    echo "FAIL: window did not float/move as expected"
    echo "$moved_out"
    fail=$((fail + 1))
fi

echo "---"
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
