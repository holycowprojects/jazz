#!/usr/bin/env python3
# Regenerates configs/quickshell/Theme.qml from design/tokens/colors.json
# (workspace/status colors, Task 27a) and design/tokens/themes.json
# (per-theme chrome/accent tokens, Task 27b). Theme.qml is committed to
# git and deployed via a plain `cp` (setup-dock.sh) - Quickshell needs its
# values synchronously at startup, so it stays a real compiled-in QML file.
#
# Task 27b: Theme.qml now bakes ALL themes' data in as a lookup table with
# a live `activeTheme` property, instead of the old two-branch dark/light
# ternary. Switching themes is a live property change (Quickshell re-paints
# instantly, same as any other QML binding) - it does NOT need a Quickshell
# relaunch, because the active choice is read back via a FileView with
# watchChanges: true, the exact same pattern WorkspaceState.qml already
# uses for workspace-overrides.json. jazz-theme-set (the orchestrator) only
# needs to write theme-state.json; Theme.qml's own FileView picks it up.
#
# design/tokens/{colors,themes}.json are the sources of truth a human edits;
# run this script afterward and commit both plus the regenerated Theme.qml.
# Don't hand-edit Theme.qml directly - it will just be overwritten.
#
# Usage: python3 scripts/generate-theme-qml.py
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
colors = json.loads((ROOT / "design/tokens/colors.json").read_text())
themes = json.loads((ROOT / "design/tokens/themes.json").read_text())["themes"]
out_path = ROOT / "configs/quickshell/Theme.qml"

workspaces = colors["workspaces"]
status = colors["status"]

lines = [
    "pragma Singleton",
    "import QtQuick",
    "import Quickshell.Io",
    "",
    "// JAZZ Theme singleton (Task 11, extended Tier 1/22/23/27a/27b).",
    "// GENERATED FILE - edit design/tokens/{colors,themes}.json and re-run",
    "// scripts/generate-theme-qml.py, don't hand-edit the tokens below.",
    "// Workspace identity colors are deliberately CONSTANT across every",
    "// theme - Design-Vision.md sec 2 reserves theming for non-semantic UI",
    "// chrome only (surface/text/accent), never these.",
    "QtObject {",
    "    id: root",
    "    property string activeTheme: \"forge\"",
    "    // Task 28 Accessibility tab: gates JAZZ's own chrome animations (the",
    "    // top bar's workspace-color transition is the one that exists today).",
    "    property bool reducedMotion: false",
    "",
]
for name, entry in workspaces.items():
    lines.append('    readonly property color %s: "%s"   // %s' % (name, entry["value"], entry["description"]))

lines.append("")
lines.append("    // Per-theme chrome/accent lookup table (Task 27b) - one entry per")
lines.append("    // design/tokens/themes.json theme. Terminal (kitty) palettes and")
lines.append("    // wallpapers live only in themes.json/jazz-theme-set, not here -")
lines.append("    // Quickshell's own chrome never needs the full 16-color ANSI set.")
lines.append("    readonly property var _themes: ({")
theme_ids = list(themes.keys())
for i, tid in enumerate(theme_ids):
    t = themes[tid]
    c = t["chrome"]
    comma = "," if i < len(theme_ids) - 1 else ""
    lines.append(
        '        "%s": { mode: "%s", surface: "%s", surfaceRaised: "%s", textPrimary: "%s", textSecondary: "%s", accent: "%s" }%s'
        % (tid, t["mode"], c["surface"], c["surfaceRaised"], c["textPrimary"], c["textSecondary"], t["accent"], comma)
    )
lines.append("    })")
lines += [
    "",
    '    readonly property var _active: root._themes[root.activeTheme] || root._themes["forge"]',
    '    readonly property bool darkMode: root._active.mode === "dark"',
    "    readonly property color surface: root._active.surface",
    "    readonly property color surfaceRaised: root._active.surfaceRaised",
    "    readonly property color textPrimary: root._active.textPrimary",
    "    readonly property color textSecondary: root._active.textSecondary",
    "    // Used by kitty/hyprlock/dunst (external, non-workspace-aware apps) via",
    "    // jazz-theme-set. Quickshell's own chrome keeps using the active",
    "    // WORKSPACE's color as its accent (WorkspaceState.activeColor()),",
    "    // unchanged - a theme's accent is a separate, narrower concept.",
    "    readonly property color themeAccent: root._active.accent",
    "",
    "    // panel/panelInk are the original Task 11 names, kept as aliases so every",
    "    // existing reference across shell.qml/Settings.qml keeps working unchanged.",
    "    readonly property color panel: surface",
    "    readonly property color panelInk: textPrimary",
    "",
    "    // Status colors, deliberately reusing workspace colors that already have",
    "    // the right hue rather than inventing new ones - critical already matches",
    "    # what Settings.qml's destructive actions (Disconnect/Forget/Remove/Clear)",
    "    // have been using via Theme.range since Task 28.",
]
for name, entry in status.items():
    lines.append('    readonly property color %s: "%s"' % (name, entry["value"]))

lines += [
    "",
    "    // Persisted active-theme choice (Task 27b). jazz-theme-set writes this",
    "    // file after regenerating kitty/hyprlock/dunst - watchChanges makes the",
    "    // switch apply here live, no Quickshell relaunch. Same pattern as",
    "    // WorkspaceState.qml's overridesFile.",
    "    property FileView themeStateFile: FileView {",
    '        path: "@@JAZZ_DATA_DIR@@/theme-state.json"',
    "        watchChanges: true",
    "        onLoaded: { try { var s = JSON.parse(root.themeStateFile.text()); if (s.activeTheme) root.activeTheme = s.activeTheme } catch (e) {} }",
    "        onFileChanged: root.themeStateFile.reload()",
    "    }",
    "}",
    "",
]

# fix accidental '#' typo from hand-editing above (must stay '//' for QML)
lines = [ln.replace('    # what Settings.qml', '    // what Settings.qml') for ln in lines]

out_path.write_text("\n".join(lines), encoding="utf-8")
print("Wrote", out_path)
