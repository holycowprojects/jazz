# JAZZ Keybinds

**Status:** Living reference. Update this file the moment a keybind in `scripts/setup-hyprland.sh` or `scripts/setup-dock.sh`/`scripts/setup-theme-bundle.sh` changes - this must never drift from the real config. (Full pass done 15 Sept 2026, closing out the drift flagged 8 Sept 2026 - every bind below was re-confirmed directly against the real source, not assumed.)

JAZZ is keyboard-first by design (`Design-Vision.md` sec 1/5) - no window title bars, no close/minimize/maximize buttons. Every action below is a real, working keybind, confirmed against Hyprland's own dispatcher API (`hyprwm/hyprland-wiki`), not guessed.

All binds use **Super** (the Windows key) as the main modifier.

## Launching

| Keybind | Action |
|---|---|
| Super + Return | Open a terminal (kitty) |
| Super + R | Open the App Launcher - JAZZ's own colored icon grid (Task 25); type to switch to a fast ranked search list, Up/Down + Enter to pick, **Escape to dismiss without launching**. This bind was originally wired to wofi in `setup-hyprland.sh` - `setup-dock.sh` rebinds the same combo to the real launcher later in the install chain, which is what actually runs. |
| Super + E | Open Jazz Files - JAZZ's own file manager (Task 29), replaced the Dolphin placeholder 15 Sept 2026 |

## Panels

| Keybind | Action |
|---|---|
| Super + S | Toggle Quick Settings (the shallow flyout - volume/wifi/bluetooth/brightness at a glance) |
| Super + , (Comma) | Toggle Jazz Settings (the full settings app) |
| Super + Escape | Toggle the power menu (Lock / Log out / Restart / Shut down) |

## Window state

| Keybind | Action |
|---|---|
| Super + Q | Close the focused window |
| Super + V | Toggle floating for the focused window |
| Super + M | Maximize (fills the screen, keeps the top bar/margins visible) |
| Super + F | Fullscreen (hides everything, true fullscreen) |
| Super + H | Minimize - moves the focused window to a hidden `special:minimized` workspace, remembering which real workspace it came from. Also appears in the dock with a hollow running-dot (Task 25) instead of disappearing from it. |
| Super + Shift + H | Restore - brings back the most recently minimized window to the real workspace it came from (LIFO order, keyboard-only). To restore one *specific* window instead of last-in-first-out, click its hollow-dot icon in the dock (Task 25) - it moves that exact window to your current workspace and focuses it, real macOS-dock behavior, not just an undo stack. Both mechanisms share the same underlying `special:minimized` workspace. Super+Shift+H resets on `hyprctl reload` (a window minimized before a reload is still recoverable manually via Super+Shift+1..6 or its dock icon, just no longer tracked by the LIFO stack). |

## Navigation

| Keybind | Action |
|---|---|
| Super + Left/Right/Up/Down | Move focus to the window in that direction |
| Super + Shift + Left/Right/Up/Down | Move the focused window in that direction |
| Super + 1..6 | Switch to workspace Forge / Lab / Arena / Observe / Vault / Range |
| Super + Shift + 1..6 | Move the focused window to that workspace |
| Super + Tab | Jump back to the previously-focused workspace |
| Super + Shift + Q | Exit Hyprland (back to the ly login screen) |

## Screenshots

| Keybind | Action |
|---|---|
| Print | Region capture - drag to select an area (`slurp`), Escape cancels |
| Shift + Print | Capture the focused window only |
| Ctrl + Print | Capture the full display |

Every mode saves to `~/Pictures/Screenshots/screenshot-<timestamp>.png`, copies the image to the clipboard immediately, and shows a notification with an **Edit** action that opens the capture in `satty` for annotation (arrows/boxes/text/blur) before you'd share it. Mirrors Omarchy's own real screenshot scheme (confirmed against their current `bin/omarchy-capture-screenshot` source), simplified for a v1 pass.

## System

| Keybind | Action |
|---|---|
| Super + L | Lock the screen (hyprlock) - added by `setup-theme-bundle.sh` (Task 27b) |

## Notes

- Forge/Lab/Arena/Observe/Vault/Range are named workspaces per `Design-Vision.md` sec 2 - the colors and the AI Command Centre for the Observe workspace are real and built (Task 26); the other five stay plain-named workspaces, nothing more, by design.
- Maximize and fullscreen are genuinely different Hyprland states (`mode = "maximized"` vs `mode = "fullscreen"` on the same `window.fullscreen` dispatcher), not two names for the same thing.
- The dock (Task 22, built) sits at the bottom of the screen with a transparent background (Task 25) - four fixed icons (App Launcher, Files, Terminal, Settings) always first/first/last/last, any other currently-running app shown in between, capped at 15 total. Clicking a running app's icon focuses it (or restores it if minimized) rather than launching a duplicate.
