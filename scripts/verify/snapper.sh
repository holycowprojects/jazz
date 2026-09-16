#!/usr/bin/env bash
# Verifies Snapper is configured (Task 7) and that snap-pac actually
# triggers automatic snapshots on a real pacman transaction, not just that
# the config exists. Run this ON THE INSTALLED GUEST, as root.
set -uo pipefail

pass=0
fail=0

if snapper list-configs 2>/dev/null | grep -q '^root '; then
    echo "PASS: snapper 'root' config exists"
    pass=$((pass + 1))
else
    echo "FAIL: no snapper 'root' config"
    fail=$((fail + 1))
fi

pacman -Rns --noconfirm tree >/dev/null 2>&1 || true

before=$(snapper -c root list 2>/dev/null | grep -cE '^[0-9]+ ')
pacman -S --noconfirm tree >/dev/null
after=$(snapper -c root list 2>/dev/null | grep -cE '^[0-9]+ ')

if (( after > before )); then
    echo "PASS: pacman transaction triggered new snapshot(s) ($before -> $after)"
    pass=$((pass + 1))
else
    echo "FAIL: no new snapshot after pacman -S (before=$before after=$after)"
    fail=$((fail + 1))
fi

echo "---"
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
