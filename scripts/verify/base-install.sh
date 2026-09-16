#!/usr/bin/env bash
# Verifies a JAZZ base install (Task 5/6) reached a healthy, correctly
# configured state. Run this ON THE INSTALLED GUEST (over serial or SSH),
# not on the Windows host - it checks systemd state, mounts, and packages
# that only exist inside the target VM.
set -uo pipefail

pass=0
fail=0

check() {
    local desc="$1"
    local actual="$2"
    local expected="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo "PASS: $desc"
        pass=$((pass + 1))
    else
        echo "FAIL: $desc (expected '$expected', got '$actual')"
        fail=$((fail + 1))
    fi
}

state=$(systemctl is-system-running 2>/dev/null)
check "systemctl is-system-running" "$state" "running"

check "hostname is jazz" "$(uname -n)" "jazz"

if [[ -d /sys/firmware/efi ]]; then
    echo "PASS: booted UEFI (/sys/firmware/efi present)"
    pass=$((pass + 1))
else
    echo "FAIL: /sys/firmware/efi missing - not a UEFI boot"
    fail=$((fail + 1))
fi

check "kernel is linux-lts" "$(uname -r | grep -o lts || true)" "lts"

for mnt in / /home /.snapshots /boot; do
    if mountpoint -q "$mnt"; then
        echo "PASS: $mnt is mounted"
        pass=$((pass + 1))
    else
        echo "FAIL: $mnt is not mounted"
        fail=$((fail + 1))
    fi
done

for pkg in hyprland base-devel git; do
    if pacman -Qq "$pkg" &>/dev/null; then
        echo "PASS: package $pkg installed"
        pass=$((pass + 1))
    else
        echo "FAIL: package $pkg missing"
        fail=$((fail + 1))
    fi
done

echo "---"
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
