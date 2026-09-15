pragma Singleton
import QtQuick
import Quickshell.Io

// JAZZ Theme singleton (Task 11, extended Tier 1/22/23/27a/27b).
// GENERATED FILE - edit design/tokens/{colors,themes}.json and re-run
// scripts/generate-theme-qml.py, don't hand-edit the tokens below.
// Workspace identity colors are deliberately CONSTANT across every
// theme - Design-Vision.md sec 2 reserves theming for non-semantic UI
// chrome only (surface/text/accent), never these.
QtObject {
    id: root
    property string activeTheme: "sapphire"  // default theme, 15 Sept 2026 (was forge) - see design/tokens/themes.json sapphire entry
    // Task 28 Accessibility tab: gates JAZZ's own chrome animations (the
    // top bar's workspace-color transition is the one that exists today).
    property bool reducedMotion: false

    readonly property color forge: "#2C5F94"   // Coding, AI app engineering
    readonly property color lab: "#1F6F54"   // Notebooks, PyTorch/Jupyter
    readonly property color arena: "#B8823C"   // AI red-teaming
    readonly property color observe: "#8B8478"   // Logs, metrics, AI Command Centre
    readonly property color vault: "#24211D"   // Secrets, sensitive config
    readonly property color range: "#7A1F2B"   // Reserved - dormant

    // Per-theme chrome/accent lookup table (Task 27b) - one entry per
    // design/tokens/themes.json theme. Terminal (kitty) palettes and
    // wallpapers live only in themes.json/jazz-theme-set, not here -
    // Quickshell's own chrome never needs the full 16-color ANSI set.
    readonly property var _themes: ({
        "forge": { mode: "dark", surface: "#1e1d24", surfaceRaised: "#26252d", textPrimary: "#ede9e2", textSecondary: "#9b968c", accent: "#4c6fa0" },
        "daylight": { mode: "light", surface: "#e9eaec", surfaceRaised: "#dcdde0", textPrimary: "#23262b", textSecondary: "#6b6e73", accent: "#3d5c8a" },
        "midnight": { mode: "dark", surface: "#0a0a0d", surfaceRaised: "#131319", textPrimary: "#e8e6e0", textSecondary: "#7d7a72", accent: "#5c86ad" },
        "warm": { mode: "dark", surface: "#201c18", surfaceRaised: "#2a2420", textPrimary: "#ede6da", textSecondary: "#a89a89", accent: "#b8783f" },
        "sapphire": { mode: "dark", surface: "#102542", surfaceRaised: "#1e3a5f", textPrimary: "#faf8f5", textSecondary: "#d8c3a5", accent: "#c9a84c" }
    })

    readonly property var _active: root._themes[root.activeTheme] || root._themes["forge"]
    readonly property bool darkMode: root._active.mode === "dark"
    readonly property color surface: root._active.surface
    readonly property color surfaceRaised: root._active.surfaceRaised
    readonly property color textPrimary: root._active.textPrimary
    readonly property color textSecondary: root._active.textSecondary
    // Used by kitty/hyprlock/dunst (external, non-workspace-aware apps) via
    // jazz-theme-set. Quickshell's own chrome keeps using the active
    // WORKSPACE's color as its accent (WorkspaceState.activeColor()),
    // unchanged - a theme's accent is a separate, narrower concept.
    readonly property color themeAccent: root._active.accent

    // panel/panelInk are the original Task 11 names, kept as aliases so every
    // existing reference across shell.qml/Settings.qml keeps working unchanged.
    readonly property color panel: surface
    readonly property color panelInk: textPrimary

    // Status colors, deliberately reusing workspace colors that already have
    // the right hue rather than inventing new ones - critical already matches
    // what Settings.qml's destructive actions (Disconnect/Forget/Remove/Clear)
    // have been using via Theme.range since Task 28.
    readonly property color positive: "#1F6F54"
    readonly property color warning: "#B8823C"
    readonly property color critical: "#7A1F2B"

    // Persisted active-theme choice (Task 27b). jazz-theme-set writes this
    // file after regenerating kitty/hyprlock/dunst - watchChanges makes the
    // switch apply here live, no Quickshell relaunch. Same pattern as
    // WorkspaceState.qml's overridesFile.
    property FileView themeStateFile: FileView {
        path: "@@JAZZ_DATA_DIR@@/theme-state.json"
        watchChanges: true
        onLoaded: { try { var s = JSON.parse(root.themeStateFile.text()); if (s.activeTheme) root.activeTheme = s.activeTheme } catch (e) {} }
        onFileChanged: root.themeStateFile.reload()
    }

    // Fonts (Task 27 font-picker follow-up) - a separate, orthogonal choice
    // from theme: stays constant across a theme switch, same principle as
    // the workspace colors. Persisted the same way as activeTheme above -
    // jazz-font-set writes font-state.json, this FileView picks it up live.
    property string uiFont: "Inter"
    property string monoFont: "JetBrains Mono"
    property FileView fontStateFile: FileView {
        path: "@@JAZZ_DATA_DIR@@/font-state.json"
        watchChanges: true
        onLoaded: {
            try {
                var s = JSON.parse(root.fontStateFile.text())
                if (s.uiFont) root.uiFont = s.uiFont
                if (s.monoFont) root.monoFont = s.monoFont
            } catch (e) {}
        }
        onFileChanged: root.fontStateFile.reload()
    }
}
