#!/usr/bin/env bash
# Manual Btrfs rollback for the JAZZ base install (Task 8).
#
# `snapper rollback` does NOT work on this system: archinstall's default
# fstab mounts root by a fixed subvolume PATH (`subvol=/@`), not via btrfs's
# "default subvolume" mechanism that snapper's automatic ambit-detection
# needs (confirmed 4 Sept 2026 - `snapper rollback` fails with "Cannot
# detect ambit since default subvolume is unknown", and `--ambit` isn't
# even a valid flag on this snapper version). This script does the standard
# manual recovery instead: rename the current (broken) @ out of the way,
# create a new writable @ from the target snapshot, and let the next boot
# pick it up naturally - fstab's `subvol=/@` mounts whatever is NAMED @ at
# the top level, regardless of its underlying subvolume ID, so no fstab
# edit is needed.
#
# Usage: rollback-manual.sh <snapshot-number>   (see: snapper list)
# Run this ON THE INSTALLED GUEST, as root. Reboot afterward for it to take
# effect - this script does NOT reboot for you.
#
# IMPORTANT: reboot via a fresh cold boot of the VM (stop the QEMU process,
# relaunch vm/launch-dev-vm.ps1-style), NOT via `reboot` typed inside the
# guest. A live in-guest `reboot` was confirmed (4 Sept 2026) to crash OVMF
# with a page fault during the ACPI warm-reset under WHPX on this host - a
# separate bug from the already-documented graphics rendering issue. The
# filesystem is safely unmounted before the crash happens, so no data is
# at risk, but the guest hangs and the QEMU process needs a hard kill.
set -eu

NUM="${1:?Usage: rollback-manual.sh <snapshot-number> (see: snapper list)}"
ROOT_UUID=$(findmnt -no UUID /)
MARK="@_broken_$(date +%s)"

mkdir -p /mnt/btrfs-top
mount -o subvolid=5 "UUID=$ROOT_UUID" /mnt/btrfs-top

if [[ ! -d "/mnt/btrfs-top/@snapshots/$NUM/snapshot" ]]; then
    umount /mnt/btrfs-top
    echo "No snapshot #$NUM found under @snapshots." >&2
    exit 1
fi

mv /mnt/btrfs-top/@ "/mnt/btrfs-top/$MARK"
btrfs subvolume snapshot "/mnt/btrfs-top/@snapshots/$NUM/snapshot" /mnt/btrfs-top/@
umount /mnt/btrfs-top

echo "Restored snapshot #$NUM as the new @ subvolume."
echo "Old (broken) subvolume kept as '$MARK' for inspection - delete it"
echo "manually (btrfs subvolume delete, from a subvolid=5 mount) once"
echo "you've confirmed the rollback worked."
echo "Now cold-boot the VM (do NOT use 'reboot') for this to take effect."
