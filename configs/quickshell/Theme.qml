pragma Singleton
import QtQuick

// JAZZ Theme singleton (Task 11, extended Tier 1/22/23/27a).
// GENERATED FILE - edit design/tokens/colors.json and re-run
// scripts/generate-theme-qml.py, don't hand-edit the tokens below.
// Workspace identity colors are deliberately CONSTANT across light/dark -
// Design-Vision.md sec 2 reserves dynamic theming for non-semantic UI
// chrome only, never these.
QtObject {
    property bool darkMode: true
    // Task 28 Accessibility tab: gates JAZZ's own chrome animations (the
    // top bar's workspace-color transition is the one that exists today).
    property bool reducedMotion: false

    readonly property color forge: "#4c6fa0"   // Coding, AI app engineering
    readonly property color lab: "#3e8e76"   // Notebooks, PyTorch/Jupyter
    readonly property color arena: "#c98a34"   // AI red-teaming
    readonly property color observe: "#7c919a"   // Logs, metrics, AI Command Centre
    readonly property color vault: "#3a3d44"   // Secrets, sensitive config
    readonly property color range: "#a23a3a"   // Reserved - dormant

    readonly property color surface: darkMode ? "#1e1d24" : "#e9eaec"
    readonly property color surfaceRaised: darkMode ? "#26252d" : "#dcdde0"
    readonly property color textPrimary: darkMode ? "#ede9e2" : "#23262b"
    readonly property color textSecondary: darkMode ? "#9b968c" : "#6b6e73"

    // panel/panelInk are the original Task 11 names, kept as aliases so every
    // existing reference across shell.qml/Settings.qml keeps working unchanged.
    readonly property color panel: surface
    readonly property color panelInk: textPrimary

    // Status colors, deliberately reusing workspace colors that already have
    // the right hue rather than inventing new ones - critical already matches
    // what Settings.qml's destructive actions (Disconnect/Forget/Remove/Clear)
    // have been using via Theme.range since Task 28.
    readonly property color positive: "#3e8e76"
    readonly property color warning: "#c98a34"
    readonly property color critical: "#a23a3a"
}
