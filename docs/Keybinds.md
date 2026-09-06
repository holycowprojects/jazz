# JAZZ Keybinds

**Status:** Living reference. Update this file the moment a keybind in `scripts/setup-hyprland.sh` changes - this must never drift from the real config.

JAZZ is keyboard-first by design (`Design-Vision.md` sec 1/5) - no window title bars, no close/minimize/maximize buttons. Every action below is a real, working keybind, confirmed against Hyprland's own dispatcher API (`hyprwm/hyprland-wiki`), not guessed.

All binds use **Super** (the Windows key) as the main modifier.

## Launching

| Keybind | Action |
|---|---|
| Super + Return | Open a terminal (kitty) |
| Super + R | Open the app launcher (wofi) - type a name, Enter to launch, **Escape to dismiss without launching** |
| Super + E | Open the file manager (dolphin) |

## Window state

| Keybind | Action |
|---|---|
| Super + Q | Close the focused window |
| Super + V | Toggle floating for the focused window |
| Super + M | Maximize (fills the screen, keeps the top bar/margins visible) |
| Super + F | Fullscreen (hides everything, true fullscreen) |
| Super + H | Minimize - moves the window to a hidden "stash" workspace. There's no true minimize in a tiling WM (no taskbar); this is the closest equivalent. The dock (Task 22, not yet built) will list stashed windows and let you click to restore one. |
| Super + Shift + H | Show/hide the stash - toggles the special "minimized" workspace into view on the current monitor so you can see and use whatever's stashed there |

## Navigation

| Keybind | Action |
|---|---|
| Super + Left/Right/Up/Down | Move focus to the window in that direction |
| Super + Shift + Left/Right/Up/Down | Move the focused window in that direction |
| Super + 1..6 | Switch to workspace Forge / Lab / Arena / Observe / Vault / Range |
| Super + Shift + 1..6 | Move the focused window to that workspace |
| Super + Tab | Jump back to the previously-focused workspace |
| Super + Shift + Q | Exit Hyprland (back to the ly login screen) |

## Notes

- Forge/Lab/Arena/Observe/Vault/Range are named workspaces per `Design-Vision.md` sec 2 - the colors and the AI Command Centre for them are still unbuilt backlog (Task 22+); right now they're plain workspaces with real names, nothing more.
- Maximize and fullscreen are genuinely different Hyprland states (`mode = "maximized"` vs `mode = "fullscreen"` on the same `window.fullscreen` dispatcher), not two names for the same thing.
