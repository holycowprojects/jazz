#!/usr/bin/env python3
# Regenerates configs/quickshell/Theme.qml from design/tokens/colors.json
# (Task 27a). Theme.qml is committed to git and deployed via a plain `cp`
# (setup-dock.sh), same pattern as Settings.qml since Task 28 - Quickshell
# needs Theme.qml's values synchronously at startup, so it stays a real
# compiled-in QML file rather than something read from disk at runtime
# (the "generated QML companion" option in Task 27a's acceptance criteria,
# not the "Theme.qml reads the file live" option - avoids a startup flash
# of default colors while an async FileView load completes).
#
# design/tokens/colors.json is the source of truth a human edits; run this
# script afterward and commit both. Don't hand-edit Theme.qml directly -
# it will just be overwritten the next time this runs.
#
# Usage: python3 scripts/generate-theme-qml.py
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
colors = json.loads((ROOT / "design/tokens/colors.json").read_text())
out_path = ROOT / "configs/quickshell/Theme.qml"

workspaces = colors["workspaces"]
dark = colors["chrome"]["dark"]
light = colors["chrome"]["light"]
status = colors["status"]

lines = [
    "pragma Singleton",
    "import QtQuick",
    "",
    "// JAZZ Theme singleton (Task 11, extended Tier 1/22/23/27a).",
    "// GENERATED FILE - edit design/tokens/colors.json and re-run",
    "// scripts/generate-theme-qml.py, don't hand-edit the tokens below.",
    "// Workspace identity colors are deliberately CONSTANT across light/dark -",
    "// Design-Vision.md sec 2 reserves dynamic theming for non-semantic UI",
    "// chrome only, never these.",
    "QtObject {",
    "    property bool darkMode: true",
    "    // Task 28 Accessibility tab: gates JAZZ's own chrome animations (the",
    "    // top bar's workspace-color transition is the one that exists today).",
    "    property bool reducedMotion: false",
    "",
]
for name, entry in workspaces.items():
    lines.append('    readonly property color %s: "%s"   // %s' % (name, entry["value"], entry["description"]))
lines += [
    "",
    '    readonly property color surface: darkMode ? "%s" : "%s"' % (dark["surface"], light["surface"]),
    '    readonly property color surfaceRaised: darkMode ? "%s" : "%s"' % (dark["surfaceRaised"], light["surfaceRaised"]),
    '    readonly property color textPrimary: darkMode ? "%s" : "%s"' % (dark["textPrimary"], light["textPrimary"]),
    '    readonly property color textSecondary: darkMode ? "%s" : "%s"' % (dark["textSecondary"], light["textSecondary"]),
    "",
    "    // panel/panelInk are the original Task 11 names, kept as aliases so every",
    "    // existing reference across shell.qml/Settings.qml keeps working unchanged.",
    "    readonly property color panel: surface",
    "    readonly property color panelInk: textPrimary",
    "",
    "    // Status colors, deliberately reusing workspace colors that already have",
    "    // the right hue rather than inventing new ones - critical already matches",
    "    // what Settings.qml's destructive actions (Disconnect/Forget/Remove/Clear)",
    "    // have been using via Theme.range since Task 28.",
]
for name, entry in status.items():
    lines.append('    readonly property color %s: "%s"' % (name, entry["value"]))
lines.append("}")
lines.append("")

out_path.write_text("\n".join(lines), encoding="utf-8")
print("Wrote", out_path)
