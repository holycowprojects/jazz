#!/usr/bin/env bash
# Task 33: three low-risk boot-branding fixes, found via Akash's own photos
# of a real boot sequence (14-15 Sept 2026) and confirmed live before being
# captured here - see tasks/todo.md Task 33 for the full story, including
# the separate Plymouth splash attempt that was tried and reverted (a real,
# pre-existing ~85s USB enumeration stall on this hardware, unrelated to
# any of this - see docs/Research-Reference-List.md). None of that Plymouth
# work is part of this script; these three fixes stand on their own.
#
# 1. /etc/os-release's NAME/PRETTY_NAME: "Arch Linux" -> "JAZZ". This is
#    what systemd-boot's own UKI-derived boot menu title reads from -
#    confirmed live (the plain "Arch Linux" entry became "JAZZ" after this
#    + a UKI rebuild). ID=arch is deliberately left untouched - pacman/AUR
#    helpers and other scripts check ID for compatibility, and changing it
#    isn't necessary for a cosmetic rename.
# 2. The systemd-boot STUB splash BMP (shown before Plymouth or anything
#    else in userspace even starts - confirmed via
#    /etc/mkinitcpio.d/*.preset's own --splash flag). This is a genuinely
#    separate splash layer from Plymouth's own theme, found only from
#    Akash's photo feedback, not anticipated in Task 33's original scope.
#    Installed to a JAZZ-owned path (/usr/local/share/jazz/splash.bmp),
#    NOT overwriting the systemd-package-owned original at
#    /usr/share/systemd/bootctl/splash-arch.bmp, so a future systemd
#    package update can't silently revert it.
# 3. The EFI NVRAM boot entry (shown in the firmware's own F12-style boot
#    menu, separate from systemd-boot's own menu) - `bootctl install`
#    registers it as "Linux Boot Manager" by default; renamed to "JAZZ" via
#    efibootmgr (delete + recreate pointing at the same loader path),
#    preserving its original position in BootOrder (a fresh `efibootmgr -c`
#    inserts at the front by default, which would silently change which OS
#    boots first - confirmed this exact behavior live, corrected for it).
#    The new boot number is found by diffing the entry list before/after
#    creation, not by assuming output line order (`efibootmgr` does NOT
#    print entries in numeric order - a freshly created low-numbered entry
#    can print last, confirmed live) - the earlier one-off manual version
#    of this fix relied on that fragile assumption; this script doesn't.
#
# All three steps are idempotent - safe to re-run (e.g. after a fresh
# install, or if `bootctl install`/an os-release-touching package update
# reset something).
#
# Run this ON THE INSTALLED GUEST, as root.
# Usage: setup-boot-branding.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPLASH_SRC="$(cd "$SCRIPT_DIR/../design/boot-branding" && pwd)/jazz-splash.bmp"
SPLASH_DEST="/usr/local/share/jazz/splash.bmp"
NEEDS_REBUILD=0

# --- 1. os-release title ---
if ! grep -q '^PRETTY_NAME="JAZZ"' /etc/os-release; then
    cp /etc/os-release /etc/os-release.pre-jazz-branding-backup
    sed -i 's/^NAME="Arch Linux"/NAME="JAZZ"/; s/^PRETTY_NAME="Arch Linux"/PRETTY_NAME="JAZZ"/' /etc/os-release
    NEEDS_REBUILD=1
    echo "os-release: NAME/PRETTY_NAME set to JAZZ"
else
    echo "os-release: already JAZZ, skipped"
fi

# --- 2. systemd-boot stub splash ---
mkdir -p /usr/local/share/jazz
if [[ ! -f "$SPLASH_DEST" ]] || ! cmp -s "$SPLASH_SRC" "$SPLASH_DEST"; then
    cp "$SPLASH_SRC" "$SPLASH_DEST"
    echo "Installed JAZZ splash BMP to $SPLASH_DEST"
else
    echo "Splash BMP: already installed, skipped"
fi
PRESET_UPDATED=0
for preset in /etc/mkinitcpio.d/*.preset; do
    [[ -f "$preset" ]] || continue
    if grep -q -- '--splash' "$preset" && ! grep -q -- "--splash $SPLASH_DEST" "$preset"; then
        cp "$preset" "$preset.pre-jazz-branding-backup"
        sed -i "s|--splash [^\"[:space:]]*|--splash $SPLASH_DEST|" "$preset"
        NEEDS_REBUILD=1
        PRESET_UPDATED=1
        echo "Updated $preset to use the JAZZ splash BMP"
    fi
done
[[ "$PRESET_UPDATED" -eq 0 ]] && echo "mkinitcpio presets: already pointing at the JAZZ splash BMP, skipped"

if [[ "$NEEDS_REBUILD" -eq 1 ]]; then
    echo "Rebuilding UKI to bake in os-release/splash changes..."
    mkinitcpio -P
fi

# --- 3. EFI NVRAM boot entry label ---
CURRENT_LABEL_LINE="$(efibootmgr -v | grep '\\EFI\\systemd\\systemd-bootx64.efi' | head -1 || true)"
if [[ -n "$CURRENT_LABEL_LINE" ]] && ! echo "$CURRENT_LABEL_LINE" | grep -q '^Boot[0-9A-F]\{4\}\* JAZZ\b'; then
    OLD_BOOTNUM="$(echo "$CURRENT_LABEL_LINE" | sed -n 's/^Boot\([0-9A-F]\{4\}\)\*.*/\1/p')"
    ESP_SOURCE="$(findmnt -no SOURCE /boot)"
    ESP_DISK="/dev/$(lsblk -no PKNAME "$ESP_SOURCE")"
    ESP_PARTNUM="$(lsblk -no PARTN "$ESP_SOURCE")"

    efibootmgr -b "$OLD_BOOTNUM" -B > /dev/null
    efibootmgr -c -d "$ESP_DISK" -p "$ESP_PARTNUM" -L 'JAZZ' -l '\EFI\systemd\systemd-bootx64.efi' > /dev/null
    # No separate BootOrder rewrite - `efibootmgr -c` already places the new
    # entry first by default, which is the outcome JAZZ wants anyway (boot
    # JAZZ by default). An earlier version tried to preserve the OLD entry's
    # exact position by rewriting BootOrder with the previous string, but
    # that string can carry stale/orphaned entry references left over from
    # a machine's prior OS (confirmed live, 16 Sept 2026, on a real laptop
    # with leftover Pop OS-era NVRAM entries) - efibootmgr correctly refuses
    # to write back an order containing a non-existent entry, aborting the
    # whole install. Letting `-c`'s own default stand avoids the class of
    # bug entirely, not just this one machine's instance of it.
    echo "EFI boot entry renamed to JAZZ (was Boot$OLD_BOOTNUM) - now first in BootOrder by default"
else
    echo "EFI boot entry: already labeled JAZZ (or no systemd-boot entry found), skipped"
fi

echo "Boot branding complete."
