#!/usr/bin/env bash
# Sets up rootless Podman for the JAZZ base install (Task 12). AI tooling is
# deliberately layered on after archinstall's base profile (not baked into
# install/base-profile.json) - this is the first script in that separate,
# idempotent layer. Run this AS ROOT (it needs to touch /etc/subuid and
# install packages); it configures a target non-root user to actually run
# Podman rootless.
#
# Usage: setup-podman.sh <username>
set -euo pipefail

USERNAME="${1:?Usage: setup-podman.sh <username>}"

pacman -Sy --noconfirm --needed podman slirp4netns fuse-overlayfs

# Rootless Podman needs a range of sub-UIDs/sub-GIDs delegated to the user
# for user namespaces (one real UID maps to many "fake" UIDs inside
# containers). archinstall's user creation doesn't populate /etc/subuid or
# /etc/subgid automatically - confirm and fix if missing. Idempotent: skips
# if the user already has an entry.
if ! grep -q "^${USERNAME}:" /etc/subuid 2>/dev/null; then
    usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "$USERNAME"
fi

# Podman rootless needs the user's systemd instance running (for cgroups v2
# delegation) even outside an interactive login - enable lingering so it
# starts at boot rather than only while the user is logged in.
loginctl enable-linger "$USERNAME"

echo "Rootless Podman configured for $USERNAME:"
grep "^${USERNAME}:" /etc/subuid /etc/subgid
