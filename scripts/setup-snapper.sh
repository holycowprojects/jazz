#!/usr/bin/env bash
# Configures Snapper on the base JAZZ install (Task 7). Two real disk_config
# shapes exist across JAZZ installs, confirmed live 16 Sept 2026: a
# hand-crafted @/@home/@snapshots layout (archinstall pre-creates and mounts
# @snapshots at /.snapshots, which conflicts with `snapper create-config`'s
# own default behavior) vs. archinstall's own interactive "best-effort
# default" Btrfs layout (@/@home/@pkg/@log - no @snapshots at all, nothing
# pre-mounted at /.snapshots, no conflict to begin with). Only the first
# case needs the unmount/discard/remount reconcile dance; the second case
# just works if `snapper create-config` is called directly. Idempotent -
# safe to re-run either way.
#
# Run this ON THE INSTALLED GUEST, as root.
set -euo pipefail

pacman -Sy --noconfirm --needed snapper snap-pac

if snapper list-configs 2>/dev/null | grep -q '^root '; then
    echo "Snapper 'root' config already exists, skipping create-config."
elif mountpoint -q /.snapshots 2>/dev/null; then
    umount /.snapshots
    rm -rf /.snapshots
    snapper -c root create-config /
    btrfs subvolume delete /.snapshots
    mkdir /.snapshots
    mount -a
    chmod 750 /.snapshots
else
    snapper -c root create-config /
    chmod 750 /.snapshots
fi

systemctl enable --now snapper-timeline.timer snapper-cleanup.timer

echo "Snapper configured:"
snapper list-configs
