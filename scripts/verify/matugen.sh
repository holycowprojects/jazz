#!/usr/bin/env bash
# Verifies Task 27d: matugen installed, a real wallpaper-derived accent
# candidate gets validated (not applied raw), and both outcomes actually
# happen for real - Forge's own curated wallpaper (saturated, mid-tone)
# is expected to be ACCEPTED, Daylight's flat procedural placeholder
# (near-white, low-saturation) is expected to be REJECTED. Both fixtures
# are read from the theme's own first wallpaper entry, not hardcoded
# filenames, so this stays valid if either wallpaper is later replaced.
# Restores both themes to their canonical (non-derived) accent afterward,
# and confirms that restore actually took effect - --from-wallpaper must
# never leave themes.json's own configured accent permanently overridden.
#
# Run this ON THE INSTALLED GUEST, as the desktop user (matugen needs no
# root, jazz-theme-set writes to the user's own ~/.config).
# Usage: verify/matugen.sh <username>
set -u

USERNAME="${1:?Usage: verify/matugen.sh <username>}"
HOME_DIR="/home/$USERNAME"
DATA_DIR="$HOME_DIR/.local/share/jazz"
KVANTUM_DIR="$HOME_DIR/.config/Kvantum"
pass=0
fail=0

# jazz-theme-set's wallpaper step (jazz-wallpaper-set) silently crashes
# without a real Wayland connection - a real bug hit twice this session
# (Task 27e's process note, then again writing this very script) - export
# both unconditionally so this verify script can never repeat it.
export XDG_RUNTIME_DIR="/run/user/$(id -u "$USERNAME")"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

wallpaper_for() {
    python3 -c "
import json
t = json.load(open('$DATA_DIR/themes.json'))['themes']['$1']
print('$DATA_DIR/wallpapers/' + t['wallpapers'][0]['path'])
"
}
accent_for() {
    python3 -c "import json; print(json.load(open('$DATA_DIR/themes.json'))['themes']['$1']['accent'])"
}

if pacman -Qi matugen >/dev/null 2>&1; then
    echo "PASS: matugen installed"
    pass=$((pass + 1))
else
    echo "FAIL: matugen not installed"
    fail=$((fail + 1))
fi

FORGE_WP=$(wallpaper_for forge)
FORGE_ACCENT=$(accent_for forge)
OUT=$(jazz-theme-set forge --from-wallpaper "$FORGE_WP" 2>&1)
if echo "$OUT" | grep -q "accepted as accent"; then
    echo "PASS: Forge's own wallpaper produced an accepted matugen candidate"
    pass=$((pass + 1))
else
    echo "FAIL: expected Forge's wallpaper to be accepted, got: $OUT"
    fail=$((fail + 1))
fi
if grep -q "highlight.color=$FORGE_ACCENT" "$KVANTUM_DIR/Jazz-forge/Jazz-forge.kvconfig" 2>/dev/null; then
    echo "FAIL: accepted candidate did not actually change the generated theme"
    fail=$((fail + 1))
else
    echo "PASS: accepted candidate genuinely changed Jazz-forge.kvconfig's accent"
    pass=$((pass + 1))
fi

DAYLIGHT_WP=$(wallpaper_for daylight)
DAYLIGHT_ACCENT=$(accent_for daylight)
OUT=$(jazz-theme-set daylight --from-wallpaper "$DAYLIGHT_WP" 2>&1)
if echo "$OUT" | grep -q "REJECTED"; then
    echo "PASS: Daylight's flat placeholder was rejected by the validation layer"
    pass=$((pass + 1))
else
    echo "FAIL: expected Daylight's flat wallpaper to be rejected, got: $OUT"
    fail=$((fail + 1))
fi
if grep -q "highlight.color=$DAYLIGHT_ACCENT" "$KVANTUM_DIR/Jazz-daylight/Jazz-daylight.kvconfig" 2>/dev/null; then
    echo "PASS: rejected candidate correctly kept the theme's own configured accent"
    pass=$((pass + 1))
else
    echo "FAIL: rejected candidate still changed Jazz-daylight.kvconfig's accent"
    fail=$((fail + 1))
fi

jazz-theme-set forge >/dev/null 2>&1
if grep -q "highlight.color=$FORGE_ACCENT" "$KVANTUM_DIR/Jazz-forge/Jazz-forge.kvconfig" 2>/dev/null; then
    echo "PASS: a plain jazz-theme-set forge (no override) restores the canonical accent"
    pass=$((pass + 1))
else
    echo "FAIL: canonical accent did not restore after the derived-accent test"
    fail=$((fail + 1))
fi

echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
