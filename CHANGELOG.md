# Changelog

All notable changes to JAZZ are recorded here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); JAZZ has no versioned
releases yet, so entries are grouped by date instead of a version number.

## [Unreleased]

### 2026-09-07
- Fixed a real boot failure on the Yoga 6 caused by FAT32 corruption on the shared
  EFI System Partition (cross-linked clusters had silently corrupted the systemd-boot
  binary and the LTS kernel's UKI); repaired via `arch-chroot` + `mkinitcpio -P` + a
  fresh `bootctl install`, confirmed with a clean `fsck.vfat` pass and a successful boot.
- Fixed AMD ACP audio (Task 24) — real sinks/sources work via the plain HDA path;
  Task 22's volume control now shows live data instead of "not available."
- Scoped Task 28 (Jazz Settings), Task 29 (Jazz Files v1), and Task 30 (agent
  permission tiers + Checkpoint→Act→Undo) from `docs/JAZZ-v2.md`.
- Split Task 27 (theme-as-bundle) into subtasks 27a-27f, calibrated against a
  design-system reference doc and confirmed pacman-repo tool availability.
- Locked in the build sequence for all remaining tasks.

### 2026-09-06
- Rebuilt JAZZ's own Hyprland config and full keybind scheme (Task 21), replacing
  Hyprland's stock auto-generated config that earlier scripts had only appended to.
- Shipped a real dock/launcher/Settings panel (Task 22) and JAZZ-branded wallpaper
  with dark/light sync (Task 23), both live-verified on the Yoga 6.
- Completed Task 16b: JAZZ installed bare-metal on Akash's Lenovo Yoga 6 (dual-boot
  with Windows), all 42 Track A/B/C verify checks passing on real hardware.

### 2026-09-04 – 2026-09-05
- Completed the Core-tracks checkpoint: Track A (Btrfs/Snapper), Track B (Hyprland,
  Quickshell, Theme.qml, Tier 1 widgets), and Track C (Podman, Ollama, PyRIT) all
  verified end-to-end in a QEMU dev VM — 31/31 checks passing.

### 2026-08-28 – 2026-09-03
- Project started. Base Arch + Hyprland install automated via `archinstall`,
  reproducibility confirmed byte-for-byte across two independent installs.
