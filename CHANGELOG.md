# Changelog

All notable changes to JAZZ are recorded here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); JAZZ has no versioned
releases yet, so entries are grouped by date instead of a version number.

## [Unreleased]

### 2026-09-17
- Polished the top bar's power menu and quick-settings flyout: real hover/
  press 3D feedback on every button (shared `ui/Button.qml`/`ui/Toggle.qml`
  components, so it applies everywhere those are used, not just these two
  panels), a real Wi-Fi toggle alongside the existing Bluetooth one, +/-
  step buttons for volume/brightness with an animated fill bar, a solid
  red Shut Down button, and all four top-bar overlays (launcher/quick
  settings/power menu/widgets) now auto-close each other instead of
  stacking. Verified live on both the Yoga 6 and the Pavilion.
- Fixed a real bug: newly installed apps (via Bazaar/Flatpak or plain
  `pacman`) never showed up in the app launcher until a full Quickshell
  restart - the app catalog was only ever scanned once, at startup. Now
  re-scans every time the launcher opens.
- Replaced the Agents tab's bracketed `[green]`/`[yellow]`/`[red]` tier
  text with real colored indicator lights, using new dedicated traffic-
  light color tokens deliberately distinct from the workspace palette
  (added to `design/tokens/colors.json`, regenerated into `Theme.qml`).
- **Task 16 done - the last of SPEC.md's 12 success criteria.** Rented a
  real RTX 4090 (Vast.ai), found and fixed a real gap live (the rented
  template's "NVIDIA Container Toolkit pre-installed" claim was false for
  that host - installed and configured it manually), then ran Task 13's
  exact unmodified AI-core container: `scripts/verify/gpu-cuda.sh` passed
  6/6, `torch.cuda.is_available()` returned `True`. A real GPU-vs-CPU
  benchmark in the same container (4096x4096 float32 matmul) showed a
  64.3x speedup (155.64ms CPU vs 2.42ms GPU per iteration). Instance
  destroyed immediately after. JAZZ now meets all 12 of SPEC.md's success
  criteria - only the explicit go-ahead for the first public push remains.
- Also diagnosed and fixed a real (self-inflicted, not a code bug) issue:
  the shutdown/restart buttons stopped working on both machines because
  Quickshell had been manually restarted over SSH during earlier testing
  sessions, landing it in the wrong login session for Linux's permission
  system to grant power actions without a password prompt - fixed by
  restarting it correctly (via Hyprland's own exec mechanism) on both.
  Confirmed this can't happen from a normal login; nothing in the
  repo's own scripts does what caused it.

### 2026-09-16
- Code-level review of every `scripts/setup-*.sh` and `scripts/verify/*.sh`
  file (ShellCheck + manual audit): added `pipefail` project-wide, fixed a
  real exit-code-masking bug (`verify/matugen.sh`), a missing readiness
  check (`setup-ollama.sh`), a stale-comment/dead-code mismatch
  (`verify/widgets-tier1.sh`), and a cosmetic `sed`-vs-bash-builtin swap -
  tested live on the Yoga 6 through a real reboot before committing.
- Pushed the repo to GitHub for real (private) and ran Task 20 (clean-clone
  rebuild test) on a genuinely fresh HP Pavilion (Intel i3 8th-gen) that had
  never run Arch before - the first true stranger's-machine test this
  project has ever done. Found and fixed seven real bugs invisible on the
  original dev VM and the Yoga 6: missing `git` on the live ISO, a
  QEMU-only hardcoded disk device in `install/base-profile.json`, EFI
  boot-branding breaking on stale NVRAM entries, a Btrfs subvolume-layout
  mismatch breaking Snapper, an uninitialized pacman keyring, a stale
  pacman lock, and a missing `less` dependency breaking the Welcome app's
  keybind button. Full install completed end-to-end, verified via a real
  reboot into the finished desktop (`systemctl is-system-running` ->
  running, zero failed units).
- Rewrote the README's entire install-steps section for a genuine
  first-time Linux user, verified against the exact sequence that worked
  live on the Pavilion.
- Project status: 11 of SPEC.md's 12 success criteria now met - only
  Task 16 (GPU rental, gated on Akash's own money/timing) remains open.
  Decided: build Task 30's Settings UI (the Agents tab) next, before
  Task 16. Plymouth's boot splash is deferred to whenever the custom-ISO
  work (`docs/JAZZ-v2.md` sec 2) gets scoped, not revisited standalone.

### 2026-09-15
- Shipped Jazz Files v1 (Task 29) - a real GUI file manager, replacing the
  Dolphin placeholder, with real undo/redo and multi-pane browsing.
- Design polish pass (Task 25): rebuilt the app launcher (grid + search,
  real icon resolution, proper spacing), redesigned the dock (transparent,
  four fixed slots + up to 15 running apps, minimize/restore via a hidden
  workspace), fixed an opacity bug affecting hover states across the
  launcher and power menu. Adopted a researched luxury "Sapphire" theme
  and a gemstone-motif workspace color palette as the new defaults,
  end-to-end tested on a fresh user account and a real reboot.
- Added the public-facing `README.md` (Task 17).
- Completed the hygiene gate (Task 19): full-history Gitleaks scan clean,
  `configs/`/`scripts/`/`install/` confirmed free of hardcoded personal
  paths - and, separately, found and permanently scrubbed two real
  plaintext dev-machine passwords that had persisted in `tasks/todo.md`
  since they were first typed, by rewriting git history (safe since no
  remote had ever been configured for this repo).

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
