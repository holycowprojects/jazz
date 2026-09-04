#!/usr/bin/env bash
# Configures Snapper on the base JAZZ install (Task 7). archinstall's manual
# partitioning already created and mounted a @snapshots subvolume at
# /.snapshots - `snapper -c root create-config` would try to make its own
# .snapshots subvolume there instead, which conflicts with the existing
# mount. The fix (standard for pre-existing @/@home/@snapshots layouts):
# unmount the existing subvolume, let snapper create (and then discard) its
# own, then remount the real one in its place. Idempotent - safe to re-run.
#
# Run this ON THE INSTALLED GUEST, as root.
set -eu

pacman -Sy --noconfirm --needed snapper snap-pac

if snapper list-configs 2>/dev/null | grep -q '^root '; then
    echo "Snapper 'root' config already exists, skipping create-config."
else
    umount /.snapshots
    rm -rf /.snapshots
    snapper -c root create-config /
    btrfs subvolume delete /.snapshots
    mkdir /.snapshots
    mount -a
    chmod 750 /.snapshots
fi

systemctl enable --now snapper-timeline.timer snapper-cleanup.timer

echo "Snapper configured:"
snapper list-configs
