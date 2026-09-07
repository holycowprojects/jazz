pragma Singleton
import QtQuick
import Quickshell.Io

// JAZZ WorkspaceState singleton. Added 8 Sept 2026 after Akash noticed the
// "color does real work" workspace-retint philosophy (Task 22) only ever
// reached the top bar and native launcher - shell.qml's `workspaces` object
// was a file-local id, invisible to Settings.qml (a separate loaded
// component), so every accent color in Settings and a few spots in
// shell.qml itself (dock hover/running-dot, quick-settings toggle/sliders,
// the To-do widget's checked-item color) stayed hardcoded to Forge blue
// instead of following the active workspace like the top bar does.
//
// This singleton is the one real source of "what's the active workspace's
// color right now" - registered in configs/quickshell/qmldir exactly like
// Theme, so both shell.qml and Settings.qml (and ui/Button.qml, ui/Toggle.qml)
// read the same live value with no cross-file wiring needed. Being a
// singleton, its Process/Timer/FileView below run ONCE globally no matter
// how many files reference it, not once per consumer.
QtObject {
    id: root
    property string active: "Forge"
    property var overrides: ({})

    readonly property var list: [
        { name: "Forge", color: Theme.forge, dormant: false },
        { name: "Lab", color: Theme.lab, dormant: false },
        { name: "Arena", color: Theme.arena, dormant: false },
        { name: "Observe", color: Theme.observe, dormant: false },
        { name: "Vault", color: Theme.vault, dormant: false },
        { name: "Range", color: Theme.range, dormant: true }
    ]

    function defaultColor(name) {
        for (var i = 0; i < list.length; i++) if (list[i].name === name) return list[i].color
        return Theme.forge
    }
    function labelFor(name) {
        return (root.overrides[name] && root.overrides[name].label) ? root.overrides[name].label : name
    }
    function colorFor(name) {
        return (root.overrides[name] && root.overrides[name].color) ? root.overrides[name].color : defaultColor(name)
    }
    function activeColor() { return colorFor(root.active) }

    property Process pollProc: Process {
        command: ["bash", "-c", "hyprctl -j activeworkspace | python3 -c 'import json,sys; print(json.load(sys.stdin)[\"name\"])'"]
        stdout: SplitParser {
            onRead: function (data) { if (data && data.length > 0) root.active = data }
        }
    }
    property Timer pollTimer: Timer {
        interval: 1000; repeat: true; running: true
        onTriggered: root.pollProc.running = true
    }

    property FileView overridesFile: FileView {
        path: "@@JAZZ_DATA_DIR@@/workspace-overrides.json"
        watchChanges: true
        onLoaded: { try { root.overrides = JSON.parse(root.overridesFile.text()) } catch (e) {} }
        onFileChanged: root.overridesFile.reload()
    }
}
