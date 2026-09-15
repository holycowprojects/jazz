# JAZZ Keybinds

**Status:** Living reference. Update this file the moment a keybind in `scripts/setup-hyprland.sh` changes - this must never drift from the real config.

JAZZ is keyboard-first by design (`Design-Vision.md` sec 1/5) - no window title bars, no close/minimize/maximize buttons. Every action below is a real, working keybind, confirmed against Hyprland's own dispatcher API (`hyprwm/hyprland-wiki`), not guessed.

All binds use **Super** (the Windows key) as the main modifier.

## Launching

| Keybind | Action |
|---|---|
| Super + Return | Open a terminal (kitty) |
| Super + R | Open the app launcher (wofi) - type a name, Enter to launch, **Escape to dismiss without launching** |
| Super + E | Open Jazz Files (Task 29's own file manager - replaced the Dolphin placeholder 15 Sept 2026) |

## Window state

| Keybind | Action |
|---|---|
| Super + Q | Close the focused window |
| Super + V | Toggle floating for the focused window |
| Super + M | Maximize (fills the screen, keeps the top bar/margins visible) |
| Super + F | Fullscreen (hides everything, true fullscreen) |
| Super + H | Minimize - moves the focused window to a hidden "stash" workspace, remembering which real workspace it came from |
| Super + Shift + H | Restore - brings back the most recently minimized window to the real workspace it came from (LIFO order). Only restores one at a time, and only in the order they were minimized - the dock (Task 22, not yet built) replaces this with clicking any specific stashed window directly. Resets on `hyprctl reload` (a window minimized before a reload is still recoverable manually via Super+Shift+1..6, just no longer tracked). |

## Navigation

| Keybind | Action |
|---|---|
| Super + Left/Right/Up/Down | Move focus to the window in that direction |
| Super + Shift + Left/Right/Up/Down | Move the focused window in that direction |
| Super + 1..6 | Switch to workspace Forge / Lab / Arena / Observe / Vault / Range |
| Super + Shift + 1..6 | Move the focused window to that workspace |
| Super + Tab | Jump back to the previously-focused workspace |
| Super + Shift + Q | Exit Hyprland (back to the ly login screen) |

## System

| Keybind | Action |
|---|---|
| Super + L | Lock the screen (hyprlock) - added by `setup-theme-bundle.sh` (Task 27b), first real binding for it |

**This file has drifted from `setup-hyprland.sh`/`setup-dock.sh` beyond just the line above** (e.g. Task 22's Super+R/S/Comma/Escape rebinds and the dock aren't reflected here yet) - flagged 8 Sept 2026 while adding Super+L, not fixed in this pass since it's pre-existing debt outside Task 27b's scope. Worth a full pass before Task 19 (hygiene gate).

## Notes

- Forge/Lab/Arena/Observe/Vault/Range are named workspaces per `Design-Vision.md` sec 2 - the colors and the AI Command Centre for them are still unbuilt backlog (Task 22+); right now they're plain workspaces with real names, nothing more.
- Maximize and fullscreen are genuinely different Hyprland states (`mode = "maximized"` vs `mode = "fullscreen"` on the same `window.fullscreen` dispatcher), not two names for the same thing.
