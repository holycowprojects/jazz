#!/usr/bin/env bash
# Installs the "everyday desktop OS" package layer Akash asked for - a normal
# consumer/productivity/creator/gaming desktop sitting alongside JAZZ's
# AI-engineering tooling, not replacing it. Every package here was confirmed
# live against Arch's official package API on 5 Sept 2026 - no AUR, matching
# every other setup-*.sh.
#
# Deliberately left out, per Akash's own call:
#   - LocalSend: AUR-only (localsend-bin); KDE Connect already covers
#     phone<->PC transfer/notifications, so it's redundant.
#   - Timeshift: overlaps with Snapper (setup-snapper.sh, already installed
#     and wired into JAZZ's rollback story) - two snapshot tools would be
#     confusing, so Snapper stays the only one.
#   - Pamac / Bauh ("app store" candidates): AUR-only.
#   - gnome-software: considered, then cut (5 Sept 2026 trim pass) - it
#     pulls a real GNOME/GTK4/libadwaita dependency chain just to wrap
#     `flatpak install` in a GUI, which doesn't fit a keyboard-first
#     Hyprland desktop (Design-Vision.md sec 1). Replaced by Bazaar
#     (added back 5 Sept 2026): a newer, Flatpak-only store built without
#     gnome-software's PackageKit/pacman-backend baggage - the app-store
#     GUI Akash actually wanted, without the dependency weight.
#   - Krita, Kdenlive, OBS Studio: cut in the trim pass. Krita overlaps GIMP
#     for raster work; Kdenlive drags in a large KDE Frameworks/MLT/FFmpeg
#     dependency tree for video editing unlikely to see daily use here; OBS
#     (streaming/recording) went with it. Creator Pack is trimmed to
#     GIMP + Inkscape + Audacity (raster/vector/audio core).
#   - Gamescope, MangoHud: cut per Akash's request (5 Sept 2026) - Steam +
#     GameMode stay, the compositor/overlay extras don't.
#   - Virtual machines (virt-manager, libvirt, qemu-desktop): cut entirely
#     (5 Sept 2026) - Akash first asked to drop qemu-desktop alone, but that
#     would've left virt-manager/libvirt with no hypervisor backend at all
#     (a non-functional shell), so the whole line was dropped together
#     instead of shipping something broken.
#
# gnome-calendar was considered and rejected (needs a real CalDAV backend
# to be more than decoration - Design-Vision.md sec 6) in favor of
# gsimplecal: a minimal GTK popup date-grid with near-zero dependency
# weight, and honest about what it does - just a calendar view, no
# events/backend it can't deliver on.
#
# PDF viewer / file manager / archive manager weren't named as specific
# apps in the request, so picked lightweight ones that fit a Hyprland
# desktop rather than pulling in GNOME's stack: zathura, thunar, xarchiver
# (lighter than file-roller - no GNOME/Nautilus integration dependency
# chain).
#
# Steam needs Arch's [multilib] repo, which isn't enabled by default - this
# script uncomments it in pacman.conf (idempotent - skips if already on)
# before syncing.
#
# Run this ON THE INSTALLED GUEST, as root.
set -euo pipefail

if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    echo "Enabling [multilib] repo for Steam..."
    sed -i '/^#\[multilib\]/,+1 s/^#//' /etc/pacman.conf
fi

pacman -Sy --noconfirm --needed \
    firefox flatpak bazaar vlc zathura thunar xarchiver bitwarden kdeconnect gsimplecal \
    libreoffice-fresh thunderbird obsidian \
    gimp inkscape audacity \
    steam gamemode \
    syncthing

echo "Desktop apps installed:"
pacman -Q firefox flatpak bazaar vlc zathura thunar xarchiver bitwarden kdeconnect gsimplecal \
    libreoffice-fresh thunderbird obsidian \
    gimp inkscape audacity \
    steam gamemode \
    syncthing
