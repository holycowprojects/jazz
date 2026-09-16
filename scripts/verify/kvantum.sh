#!/usr/bin/env bash
# Verifies Task 27e: Kvantum/GTK3 compat layer. Config-state checks only -
# no process kill/relaunch needed, unlike the earlier VM-era verify
# scripts, since this just confirms generated files are correct and
# match the active theme's real tokens, not live rendering (that part is
# a manual screenshot check, same convention as Task 11's border-color).
#
# Run this ON THE INSTALLED GUEST, as root or the desktop user.
# Usage: verify/kvantum.sh <username>
set -uo pipefail

USERNAME="${1:?Usage: verify/kvantum.sh <username>}"
HOME_DIR="/home/$USERNAME"
DATA_DIR="$HOME_DIR/.local/share/jazz"
KVANTUM_DIR="$HOME_DIR/.config/Kvantum"
GTK3_CONF="$HOME_DIR/.config/gtk-3.0/settings.ini"
HYPR_CONFIG="$HOME_DIR/.config/hypr/hyprland.lua"
pass=0
fail=0

if pacman -Qi kvantum >/dev/null 2>&1 && pacman -Qi kvantum-qt5 >/dev/null 2>&1 && pacman -Qi adw-gtk-theme >/dev/null 2>&1; then
    echo "PASS: kvantum, kvantum-qt5, adw-gtk-theme all installed"
    pass=$((pass + 1))
else
    echo "FAIL: one or more of kvantum/kvantum-qt5/adw-gtk-theme not installed"
    fail=$((fail + 1))
fi

ACTIVE_THEME=$(python3 -c "import json,sys; print(json.load(open('$DATA_DIR/theme-state.json')).get('activeTheme','forge'))" 2>/dev/null || echo forge)
ACCENT=$(python3 -c "import json,sys; print(json.load(open('$DATA_DIR/themes.json'))['themes']['$ACTIVE_THEME']['accent'])" 2>/dev/null)

if [[ -f "$KVANTUM_DIR/Jazz-$ACTIVE_THEME/Jazz-$ACTIVE_THEME.kvconfig" ]] && grep -qi "highlight.color=$ACCENT" "$KVANTUM_DIR/Jazz-$ACTIVE_THEME/Jazz-$ACTIVE_THEME.kvconfig"; then
    echo "PASS: Jazz-$ACTIVE_THEME.kvconfig exists and carries the real active accent ($ACCENT)"
    pass=$((pass + 1))
else
    echo "FAIL: Jazz-$ACTIVE_THEME.kvconfig missing or doesn't carry $ACCENT as highlight.color"
    fail=$((fail + 1))
fi

if [[ -f "$KVANTUM_DIR/Jazz-$ACTIVE_THEME/Jazz-$ACTIVE_THEME.svg" ]]; then
    echo "PASS: matching .svg asset present alongside the .kvconfig"
    pass=$((pass + 1))
else
    echo "FAIL: .svg asset missing"
    fail=$((fail + 1))
fi

if grep -q "theme=Jazz-$ACTIVE_THEME" "$KVANTUM_DIR/kvantum.kvconfig" 2>/dev/null; then
    echo "PASS: kvantum.kvconfig selects Jazz-$ACTIVE_THEME as the active theme"
    pass=$((pass + 1))
else
    echo "FAIL: kvantum.kvconfig does not select Jazz-$ACTIVE_THEME"
    fail=$((fail + 1))
fi

if [[ -f "$GTK3_CONF" ]] && grep -q 'gtk-theme-name=adw-gtk3' "$GTK3_CONF"; then
    echo "PASS: gtk-3.0/settings.ini selects an adw-gtk3 variant"
    pass=$((pass + 1))
else
    echo "FAIL: gtk-3.0/settings.ini missing or not pointing at adw-gtk3"
    fail=$((fail + 1))
fi

if grep -q 'QT_STYLE_OVERRIDE.*kvantum' "$HYPR_CONFIG" 2>/dev/null; then
    echo "PASS: hyprland.lua forces QT_STYLE_OVERRIDE=kvantum for Qt apps"
    pass=$((pass + 1))
else
    echo "FAIL: hyprland.lua missing QT_STYLE_OVERRIDE"
    fail=$((fail + 1))
fi

echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
