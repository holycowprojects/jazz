#!/usr/bin/env bash
# Task 22, rebuilt again 6 Sept 2026 after Akash's second round of feedback
# and a proper research pass (Omarchy/macOS/Windows architecture) - see
# tasks/todo.md for the decided synthesis. Key changes from the previous
# pass:
#
# - Launcher reverted to wofi. Omarchy itself doesn't hand-roll a launcher
#   (uses Walker) - wofi already does real .desktop scanning + real icons
#   correctly out of the box. Hand-rolling one was reinventing something
#   already solved.
# - Real app data everywhere: configs/quickshell/scan-apps.py (a real XDG
#   .desktop scanner, adapted from the confirmed-working pattern in
#   bjarneo/quickshell's AppScan.qml) is the single source of truth for
#   the dock - no more hardcoded app lists. Icons resolved via the
#   confirmed real Quickshell.iconPath(name, "") API, not glyphs.
# - Dock = macOS's model: pinned + currently-running combined into one
#   bar, real icons, a running-dot - not Windows' heavier grouped-preview
#   taskbar (overkill for v1), and richer than Omarchy's "no dock at all".
#   Running windows matched to real icons via the standard cascade every
#   real desktop taskbar uses: StartupWMClass -> .desktop filename ->
#   Exec binary basename.
# - Top bar now retints per active workspace (Design-Vision.md's own
#   "color does real work" philosophy) - the one thing none of
#   Windows/macOS/Omarchy do, JAZZ's actual visual signature.
# - Settings split like Windows: a shallow quick-toggles flyout (wifi/
#   bluetooth/volume/brightness) plus a SEPARATE, real Settings panel
#   (Appearance incl. wallpaper picker/Network/Bluetooth/Sound/Display) -
#   not everything crammed into one popover.
# - Widget edit panel added (Design-Vision.md sec 6 / the approved mockup)
#   - a real per-widget enable/disable toggle list, persisted to disk.
#
# Mechanism confirmed live/via research, not guessed: IpcHandler + `qs ipc
# call`, Quickshell.execDetached, Process+SplitParser (line-streamed) vs
# Process+StdioCollector (whole-output, uses `this.text` in
# onStreamFinished - confirmed exact syntax from bjarneo/quickshell's
# AppScan.qml), Quickshell.iconPath(themeName, fallback).
#
# The shell.qml heredoc below is QUOTED ('SHELLQML') deliberately - an
# earlier unquoted-heredoc version let bash try to expand a literal `$2`
# meant for awk (real bug, hit live: "line 78: $2: unbound variable").
# The handful of real paths that need substituting are done via a
# @@JAZZ_DATA_DIR@@ placeholder + sed afterward, not inline bash expansion.
#
# Run this ON THE INSTALLED GUEST, as root.
# Usage: setup-dock.sh <username>
set -eu

USERNAME="${1:?Usage: setup-dock.sh <username>}"
QS_DIR="/home/$USERNAME/.config/quickshell"
THEME_FILE="$QS_DIR/Theme.qml"
SHELL_FILE="$QS_DIR/shell.qml"
HYPR_CONFIG="/home/$USERNAME/.config/hypr/hyprland.lua"
DATA_DIR="/home/$USERNAME/.local/share/jazz"
SCAN_SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../configs/quickshell" && pwd)/scan-apps.py"
THEME_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../configs/quickshell" && pwd)/Theme.qml"
UI_SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../configs/quickshell" && pwd)/ui"

pacman -Sy --noconfirm --needed brightnessctl hyprlock wofi

sudo -u "$USERNAME" mkdir -p "$QS_DIR" "$DATA_DIR"
sudo -u "$USERNAME" cp "$SCAN_SCRIPT_SRC" "$DATA_DIR/scan-apps.py"
# Task 27a: Theme.qml is now a real, committed, GENERATED file (from
# design/tokens/colors.json via scripts/generate-theme-qml.py) - just
# copied like Settings.qml, not hand-authored inline in this heredoc
# anymore. Regenerate + commit both after editing colors.json, don't
# hand-edit Theme.qml directly.
sudo -u "$USERNAME" cp "$THEME_SRC" "$THEME_FILE"
# Task 27g: shared QML component library (Button/Toggle/ListRow/
# SectionHeader), used by both shell.qml (imports "ui" below) and
# Settings.qml.
sudo -u "$USERNAME" mkdir -p "$QS_DIR/ui"
sudo -u "$USERNAME" cp "$UI_SRC_DIR"/*.qml "$UI_SRC_DIR/qmldir" "$QS_DIR/ui/"

sudo -u "$USERNAME" tee "$SHELL_FILE" > /dev/null << 'SHELLQML'
// JAZZ Quickshell config (Tasks 10-11, Tier 1 widgets, Task 22 rebuilt
// against real research: Omarchy/macOS/Windows architecture - see
// tasks/todo.md). Real app data (scan-apps.py) backs the dock; wofi
// remains the launcher (already correct, not reinvented); the top bar
// retints per active workspace; Settings is split shallow-flyout vs
// real-panel like Windows; a real widget-edit toggle list exists.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "ui"

ShellRoot {
    // ---------- Real app catalog (XDG .desktop scan) ----------
    QtObject {
        id: appCatalog
        property var apps: []
    }
    Process {
        id: scanProc
        command: ["python3", "@@JAZZ_DATA_DIR@@/scan-apps.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { appCatalog.apps = JSON.parse(this.text) } catch (e) { appCatalog.apps = [] }
            }
        }
    }
    Timer { interval: 100; running: true; onTriggered: scanProc.running = true }

    function resolveIcon(rawIcon) {
        if (!rawIcon || rawIcon.length === 0) return ""
        if (rawIcon.charAt(0) === "/") return "file://" + rawIcon
        return Quickshell.iconPath(rawIcon, "")
    }
    function findAppByName(matchSubstr) {
        var lower = matchSubstr.toLowerCase()
        for (var i = 0; i < appCatalog.apps.length; i++) {
            if (appCatalog.apps[i].name.toLowerCase().indexOf(lower) !== -1) return appCatalog.apps[i]
        }
        return null
    }
    function findAppByClass(wclass) {
        var lc = wclass.toLowerCase()
        for (var i = 0; i < appCatalog.apps.length; i++) {
            var a = appCatalog.apps[i]
            if (a.wmClass && a.wmClass.toLowerCase() === lc) return a
        }
        for (var i = 0; i < appCatalog.apps.length; i++) {
            var a = appCatalog.apps[i]
            if (a.desktopFile.toLowerCase() === lc) return a
        }
        for (var i = 0; i < appCatalog.apps.length; i++) {
            var a = appCatalog.apps[i]
            var bin = a.exec.split(" ")[0].split("/").pop().toLowerCase()
            if (bin === lc) return a
        }
        return null
    }

    QtObject {
        id: workspaces
        property var list: [
            { name: "Forge", color: Theme.forge, dormant: false },
            { name: "Lab", color: Theme.lab, dormant: false },
            { name: "Arena", color: Theme.arena, dormant: false },
            { name: "Observe", color: Theme.observe, dormant: false },
            { name: "Vault", color: Theme.vault, dormant: false },
            { name: "Range", color: Theme.range, dormant: true }
        ]
        property string active: "Forge"
        // Task 28 feedback (Akash): let a workspace's DISPLAY name/color be
        // customized without touching its real Hyprland identity - so the
        // Super+1..6 keybinds (which target the real name) never break.
        // Settings.qml's Desktop tab writes this same file; watchChanges
        // picks the edit up live, no restart needed.
        property var overrides: ({})
        function defaultColor(name) {
            for (var i = 0; i < list.length; i++) if (list[i].name === name) return list[i].color
            return Theme.forge
        }
        function labelFor(name) {
            return (overrides[name] && overrides[name].label) ? overrides[name].label : name
        }
        function colorFor(name) {
            return (overrides[name] && overrides[name].color) ? overrides[name].color : defaultColor(name)
        }
        function activeColor() { return colorFor(active) }
    }
    FileView {
        id: workspaceOverridesFile
        path: "@@JAZZ_DATA_DIR@@/workspace-overrides.json"
        watchChanges: true
        onLoaded: { try { workspaces.overrides = JSON.parse(workspaceOverridesFile.text()) } catch (e) {} }
        onFileChanged: workspaceOverridesFile.reload()
    }
    Process {
        id: wsPollProc
        command: ["bash", "-c", "hyprctl -j activeworkspace | python3 -c 'import json,sys; print(json.load(sys.stdin)[\"name\"])'"]
        stdout: SplitParser {
            onRead: function (data) { if (data && data.length > 0) workspaces.active = data }
        }
    }
    Timer { interval: 1000; repeat: true; running: true; onTriggered: wsPollProc.running = true }

    // Real running-window classes, polled - drives the dock's running-dot
    // and pulls in currently-running apps that aren't in the pinned set
    // (macOS/Windows both do this - a running app shows up even unpinned).
    QtObject {
        id: runningState
        property var classes: []
    }
    Process {
        id: clientsPollProc
        command: ["bash", "-c", "hyprctl -j clients | python3 -c 'import json,sys; print(\",\".join(sorted(set(w[\"class\"] for w in json.load(sys.stdin) if w[\"class\"]))))'"]
        stdout: SplitParser {
            onRead: function (data) { runningState.classes = data ? data.split(",") : [] }
        }
    }
    Timer { interval: 1500; repeat: true; running: true; onTriggered: clientsPollProc.running = true }

    property var pinnedMatch: ["Firefox", "Bazaar", "LibreOffice", "GIMP", "Obsidian", "Thunderbird", "VLC", "Steam"]
    property var dockEntries: []
    function rebuildDock() {
        var out = [];
        var usedClasses = {};
        // Pinned apps first, in order, real icon/exec from the scan
        for (var i = 0; i < pinnedMatch.length; i++) {
            var a = findAppByName(pinnedMatch[i]);
            if (!a) continue;
            var running = false;
            for (var c = 0; c < runningState.classes.length; c++) {
                if (a.wmClass && a.wmClass.toLowerCase() === runningState.classes[c].toLowerCase()) { running = true; usedClasses[runningState.classes[c]] = true; }
            }
            out.push({ name: a.name, icon: resolveIcon(a.icon), glyph: "", cmd: ["sh", "-c", a.exec], running: running });
        }
        // Terminal is always pinned - not every distro ships a kitty
        // .desktop entry with a matching StartupWMClass, and JAZZ always
        // needs a terminal regardless of what the scan finds.
        var termRunning = runningState.classes.indexOf("kitty") !== -1;
        if (termRunning) usedClasses["kitty"] = true;
        out.push({ name: "Terminal", icon: resolveIcon("kitty"), glyph: "", cmd: ["kitty"], running: termRunning });
        // Ollama - not a real .desktop app, a deliberate JAZZ shortcut
        out.push({ name: "Ollama", icon: "", glyph: "◈", cmd: ["kitty", "-e", "ollama", "run", "qwen2.5:0.5b"], running: false });
        // App launcher and Settings - always pinned (Akash's request), so
        // the dock alone can reach every app plus real settings without
        // needing to know any keybind. Neither is a real installed app, so
        // both get a deliberate glyph rather than an icon-theme lookup that
        // might not resolve: a saxophone for the JAZZ-branded launcher (not
        // a generic search icon), a universal gear for Settings.
        out.push({ name: "App Launcher", icon: "", glyph: "🎷", cmd: ["qs", "ipc", "call", "launcher", "toggle"], running: false });
        out.push({ name: "Settings", icon: "", glyph: "⚙", cmd: ["qs", "ipc", "call", "settings", "toggle"], running: false });
        // Any other currently-running app not already pinned - real
        // macOS/Windows dock behavior, not invented
        for (var c = 0; c < runningState.classes.length; c++) {
            var cls = runningState.classes[c];
            if (usedClasses[cls]) continue;
            var app = findAppByClass(cls);
            out.push({ name: app ? app.name : cls, icon: resolveIcon(app ? app.icon : cls), glyph: "", cmd: app ? ["sh", "-c", app.exec] : [cls], running: true });
        }
        dockEntries = out;
    }
    Connections { target: appCatalog; function onAppsChanged() { rebuildDock() } }
    Connections { target: runningState; function onClassesChanged() { rebuildDock() } }

    // ---------- Widget catalog (Design-Vision.md sec 6 - real edit panel) ----------
    QtObject {
        id: widgetCatalog
        property var items: [
            { id: "worldclock", label: "World clock", enabled: true },
            { id: "notes", label: "Notes", enabled: true },
            { id: "todo", label: "To-do", enabled: true },
            { id: "pomodoro", label: "Pomodoro", enabled: true }
        ]
    }
    FileView {
        id: widgetPrefsFile
        path: "@@JAZZ_DATA_DIR@@/widget-prefs.json"
        onLoaded: {
            try {
                var saved = JSON.parse(widgetPrefsFile.text());
                var items = widgetCatalog.items.slice();
                for (var i = 0; i < items.length; i++) {
                    if (saved[items[i].id] !== undefined) items[i].enabled = saved[items[i].id];
                }
                widgetCatalog.items = items;
            } catch (e) {}
        }
    }
    function saveWidgetPrefs() {
        var out = {};
        for (var i = 0; i < widgetCatalog.items.length; i++) out[widgetCatalog.items[i].id] = widgetCatalog.items[i].enabled;
        widgetPrefsFile.setText(JSON.stringify(out));
    }
    function isWidgetEnabled(id) {
        for (var i = 0; i < widgetCatalog.items.length; i++) if (widgetCatalog.items[i].id === id) return widgetCatalog.items[i].enabled;
        return true;
    }

    // ---------- Top bar (retints per active workspace) ----------
    PanelWindow {
        id: topBar
        anchors { top: true; left: true; right: true }
        implicitHeight: 34
        color: workspaces.activeColor()
        Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: 250 } }

        QtObject {
            id: sessionUser
            property string name: ""
        }
        Process {
            id: whoamiProc
            command: ["whoami"]
            running: true
            stdout: SplitParser { onRead: function (data) { if (data) sessionUser.name = data } }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

            Text {
                text: "JAZZ"
                color: "#ffffff"
                font.pixelSize: 15
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                visible: sessionUser.name.length > 0
                text: sessionUser.name
                color: "#ffffff"
                opacity: 0.8
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                spacing: 5
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: workspaces.list
                    delegate: Rectangle {
                        property bool active: workspaces.active === modelData.name
                        width: pillText.width + 18; height: 20; radius: 10
                        color: active ? "#ffffff" : "#00000000"
                        border.color: active ? "#00000000" : "#ffffff"
                        border.width: active ? 0 : 1
                        opacity: modelData.dormant ? 0.55 : (active ? 1 : 0.85)

                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            Rectangle { width: 6; height: 6; radius: 3; color: workspaces.colorFor(modelData.name); anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                id: pillText
                                text: workspaces.labelFor(modelData.name)
                                font.pixelSize: 10
                                font.italic: modelData.dormant
                                color: active ? workspaces.colorFor(modelData.name) : "#ffffff"
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: Quickshell.execDetached(["hyprctl", "dispatch",
                                "hl.dsp.focus({workspace = \"name:" + modelData.name + "\"})"])
                        }
                    }
                }
            }
        }

        SystemClock { id: clock; precision: SystemClock.Seconds }
        Column {
            anchors.centerIn: parent
            spacing: 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(clock.date, "hh:mm:ss")
                color: "#ffffff"
                font.pixelSize: 14
                font.family: "monospace"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(clock.date, "ddd, MMM d")
                color: "#ffffff"
                opacity: 0.75
                font.pixelSize: 9
            }
        }

        // Real tray data - each shows nothing/gracefully-empty when there's
        // genuinely nothing to show (no track playing, no notifications),
        // matching Design-Vision.md sec 4's "honest gap, not faked" rule.
        QtObject {
            id: trayState
            property string nowPlaying: ""
            property int notifCount: 0
            property string wifiSsid: ""
            property int batteryPct: -1
        }
        Process {
            id: playerctlProc
            command: ["bash", "-c", "playerctl status 2>/dev/null | grep -q Playing && playerctl metadata --format '{{artist}} - {{title}}' 2>/dev/null || true"]
            stdout: SplitParser { onRead: function (data) { trayState.nowPlaying = data || "" } }
        }
        Process {
            id: notifCountProc
            command: ["bash", "-c", "dunstctl count history 2>/dev/null || echo 0"]
            stdout: SplitParser { onRead: function (data) { trayState.notifCount = parseInt(data) || 0 } }
        }
        Process {
            id: wifiSsidProc
            command: ["bash", "-c", "nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2"]
            stdout: SplitParser { onRead: function (data) { trayState.wifiSsid = data || "" } }
        }
        Process {
            id: batteryProc
            command: ["bash", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1"]
            stdout: SplitParser { onRead: function (data) { trayState.batteryPct = data ? parseInt(data) : -1 } }
        }
        Timer { interval: 3000; repeat: true; running: true; triggeredOnStart: true
            onTriggered: { playerctlProc.running = true; notifCountProc.running = true; wifiSsidProc.running = true; batteryProc.running = true }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            Row {
                visible: trayState.nowPlaying.length > 0
                spacing: 5
                anchors.verticalCenter: parent.verticalCenter
                Text { text: "♪"; color: "#ffffff"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: trayState.nowPlaying; color: "#ffffff"; font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight; width: 140
                }
            }

            Row {
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter
                Text { text: "🔔"; color: "#ffffff"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                Text { visible: trayState.notifCount > 0; text: trayState.notifCount; color: "#ffffff"; opacity: 0.8; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["dunstctl", "history-pop"]) }
            }

            Text {
                text: "⎘"
                color: "#ffffff"
                font.pixelSize: 15
                anchors.verticalCenter: parent.verticalCenter
                MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "cliphist list | wofi --dmenu | cliphist decode | wl-copy"]) }
            }

            Row {
                visible: trayState.wifiSsid.length > 0
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter
                Text { text: "📶"; color: "#ffffff"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                Text { text: trayState.wifiSsid; color: "#ffffff"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
            }

            Row {
                visible: trayState.batteryPct >= 0
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter
                Text { text: "🔋"; color: "#ffffff"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                Text { text: trayState.batteryPct + "%"; color: "#ffffff"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
            }

            Text {
                text: "🎷"
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
                MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["qs", "ipc", "call", "launcher", "toggle"]) }
            }
            Text {
                text: "⚙"
                color: "#ffffff"
                font.pixelSize: 15
                anchors.verticalCenter: parent.verticalCenter
                MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["qs", "ipc", "call", "quicksettings", "toggle"]) }
            }
            Text {
                text: "⏻"
                color: "#ffffff"
                font.pixelSize: 15
                anchors.verticalCenter: parent.verticalCenter
                MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["qs", "ipc", "call", "powermenu", "toggle"]) }
            }
        }
    }

    // ---------- App launcher (native, real icons, workspace-accent themed) ----------
    PanelWindow {
        id: launcher
        visible: false
        anchors { top: true; bottom: true; left: true; right: true }
        color: "#00000000"
        exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle { anchors.fill: parent; color: "#0a090899" }
        MouseArea { anchors.fill: parent; onClicked: launcher.visible = false }

        Rectangle {
            id: launcherBox
            width: 520; height: 400
            anchors.horizontalCenter: parent.horizontalCenter
            y: 70
            radius: 14
            color: Theme.panel
            border.color: workspaces.activeColor()
            border.width: 2
            MouseArea { anchors.fill: parent }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Rectangle {
                    width: parent.width; height: 34; radius: 8
                    color: Theme.panelInk; opacity: 0.08
                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        anchors.margins: 9
                        color: Theme.panelInk
                        font.pixelSize: 13
                        clip: true
                        focus: launcher.visible
                        Text {
                            text: "Search apps..."
                            color: Theme.panelInk
                            opacity: 0.4
                            visible: searchInput.text.length === 0
                            font.pixelSize: 13
                        }
                        Keys.onEscapePressed: launcher.visible = false
                    }
                }

                Flow {
                    width: parent.width
                    height: 300
                    spacing: 6
                    clip: true
                    Repeater {
                        model: appCatalog.apps
                        delegate: Rectangle {
                            visible: searchInput.text.length === 0 || modelData.name.toLowerCase().indexOf(searchInput.text.toLowerCase()) !== -1
                            width: 76; height: visible ? 74 : 0; radius: 8
                            color: launchMouse.containsMouse ? workspaces.activeColor() : "#00000000"
                            opacity: launchMouse.containsMouse ? 0.18 : 1
                            Column {
                                anchors.centerIn: parent
                                spacing: 4
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 34; height: 34; radius: 9
                                    color: workspaces.activeColor()
                                    opacity: 0.85
                                    Image {
                                        anchors.centerIn: parent
                                        width: 24; height: 24
                                        source: resolveIcon(modelData.icon)
                                        fillMode: Image.PreserveAspectFit
                                        visible: resolveIcon(modelData.icon).length > 0
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: resolveIcon(modelData.icon).length === 0
                                        text: modelData.name.charAt(0)
                                        color: "#ffffff"; font.pixelSize: 14; font.bold: true
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.name; color: Theme.panelInk; font.pixelSize: 9
                                    width: 74; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                                    elide: Text.ElideRight; maximumLineCount: 2
                                }
                            }
                            MouseArea {
                                id: launchMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: { Quickshell.execDetached(["sh", "-c", modelData.exec]); launcher.visible = false }
                            }
                        }
                    }
                }

                Text {
                    text: "Esc closes · " + appCatalog.apps.length + " apps"
                    color: Theme.panelInk; opacity: 0.4; font.pixelSize: 9
                }
            }
        }

        IpcHandler {
            target: "launcher"
            function toggle(): void { launcher.visible = !launcher.visible; searchInput.text = "" }
        }
    }

    // ---------- Quick settings (shallow flyout) ----------
    PanelWindow {
        id: quickSettings
        visible: false
        anchors { top: true; right: true }
        margins { top: 38; right: 8 }
        implicitWidth: 230
        implicitHeight: 260
        exclusiveZone: -1
        color: Theme.panel

        property string btStatus: "checking"
        property real brightnessVal: 100
        property bool audioAvailable: false
        property real volumeVal: 0

        onVisibleChanged: {
            if (visible) { btProc.running = true; briProc.running = true; volCheckProc.running = true; volReadProc.running = true }
        }

        Process {
            id: btProc
            command: ["bash", "-c", "bluetoothctl show 2>/dev/null | grep Powered | awk '{print $2}'"]
            stdout: SplitParser { onRead: function (data) { if (data) quickSettings.btStatus = data } }
        }
        Process {
            id: briProc
            command: ["bash", "-c", "brightnessctl -m | cut -d, -f4 | tr -d '%'"]
            stdout: SplitParser { onRead: function (data) { if (data) quickSettings.brightnessVal = parseFloat(data) } }
        }
        Process {
            id: volCheckProc
            command: ["bash", "-c", "wpctl status 2>/dev/null | awk '/Sinks:/,/Sources:/' | grep -qE '[0-9]+\\.' && echo yes || echo no"]
            stdout: SplitParser { onRead: function (data) { quickSettings.audioAvailable = (data === "yes") } }
        }
        Process {
            id: volReadProc
            command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
            stdout: SplitParser {
                onRead: function (data) {
                    if (!data) return
                    var m = data.match(/([0-9.]+)/)
                    if (m) quickSettings.volumeVal = Math.round(parseFloat(m[1]) * 100)
                }
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            Row {
                width: parent.width
                Text { text: "Wi-Fi"; color: Theme.panelInk; font.pixelSize: 12; width: parent.width - 50 }
                Text { text: "on"; color: Theme.panelInk; opacity: 0.6; font.pixelSize: 11 }
            }
            Row {
                width: parent.width
                spacing: 8
                Text { text: "Bluetooth"; color: Theme.panelInk; font.pixelSize: 12; width: 110 }
                Rectangle {
                    width: 34; height: 18; radius: 9
                    color: quickSettings.btStatus === "yes" ? Theme.forge : Theme.panelInk
                    opacity: quickSettings.btStatus === "yes" ? 1 : 0.25
                    Rectangle {
                        width: 14; height: 14; radius: 7; color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                        x: quickSettings.btStatus === "yes" ? parent.width - width - 2 : 2
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            Quickshell.execDetached(["bash", "-c", quickSettings.btStatus === "yes" ? "bluetoothctl power off" : "bluetoothctl power on"])
                            btProc.running = true
                        }
                    }
                }
            }
            Column {
                width: parent.width
                spacing: 4
                Text { text: "Volume"; color: Theme.panelInk; font.pixelSize: 12 }
                Text {
                    visible: !quickSettings.audioAvailable
                    text: "Not available - no audio device"
                    color: Theme.panelInk; opacity: 0.5; font.pixelSize: 10; font.italic: true
                }
                Rectangle {
                    visible: quickSettings.audioAvailable
                    width: parent.width; height: 6; radius: 3; color: Theme.panelInk; opacity: 0.2
                    Rectangle { width: parent.width * quickSettings.volumeVal / 100; height: parent.height; radius: 3; color: Theme.forge }
                    MouseArea {
                        anchors.fill: parent
                        onPressed: (mouse) => { var pct = Math.max(0, Math.min(100, mouse.x / width * 100)); quickSettings.volumeVal = pct; Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (pct / 100).toFixed(2)]) }
                        onPositionChanged: (mouse) => { if (pressed) { var pct = Math.max(0, Math.min(100, mouse.x / width * 100)); quickSettings.volumeVal = pct; Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (pct / 100).toFixed(2)]) } }
                    }
                }
            }
            Column {
                width: parent.width
                spacing: 4
                Text { text: "Brightness"; color: Theme.panelInk; font.pixelSize: 12 }
                Rectangle {
                    width: parent.width; height: 6; radius: 3; color: Theme.panelInk; opacity: 0.2
                    Rectangle { width: parent.width * quickSettings.brightnessVal / 100; height: parent.height; radius: 3; color: Theme.forge }
                    MouseArea {
                        anchors.fill: parent
                        onPressed: (mouse) => { var pct = Math.max(1, Math.min(100, mouse.x / width * 100)); quickSettings.brightnessVal = pct; Quickshell.execDetached(["brightnessctl", "set", Math.round(pct) + "%"]) }
                        onPositionChanged: (mouse) => { if (pressed) { var pct = Math.max(1, Math.min(100, mouse.x / width * 100)); quickSettings.brightnessVal = pct; Quickshell.execDetached(["brightnessctl", "set", Math.round(pct) + "%"]) } }
                    }
                }
            }
            Rectangle {
                width: parent.width; height: 26; radius: 6; color: Theme.forge
                Text { anchors.centerIn: parent; text: "More settings..."; font.pixelSize: 11; color: "#ffffff" }
                MouseArea { anchors.fill: parent; onClicked: { quickSettings.visible = false; Quickshell.execDetached(["qs", "ipc", "call", "settings", "toggle"]) } }
            }
        }

        IpcHandler {
            target: "quicksettings"
            function toggle(): void { quickSettings.visible = !quickSettings.visible }
        }
    }

    // ---------- Full Settings app (Task 28: grown out to its own file, Settings.qml - see that file for all sections) ----------
    Loader { source: "Settings.qml" }

    // ---------- Power menu ----------
    PanelWindow {
        id: powerMenu
        visible: false
        anchors { top: true; right: true }
        margins { top: 38; right: 8 }
        implicitWidth: 150
        implicitHeight: 140
        exclusiveZone: -1
        color: Theme.panel

        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 2
            Repeater {
                model: [
                    { label: "Lock", cmd: ["hyprlock"] },
                    { label: "Log out", cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
                    { label: "Restart", cmd: ["systemctl", "reboot"] },
                    { label: "Shut down", cmd: ["systemctl", "poweroff"] }
                ]
                delegate: Rectangle {
                    width: parent.width; height: 28; radius: 6
                    color: powerMouse.containsMouse ? Theme.panelInk : "#00000000"
                    opacity: powerMouse.containsMouse ? 0.08 : 1
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: modelData.label === "Shut down" ? "#c0392b" : Theme.panelInk
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: powerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { Quickshell.execDetached(modelData.cmd); powerMenu.visible = false }
                    }
                }
            }
        }

        IpcHandler {
            target: "powermenu"
            function toggle(): void { powerMenu.visible = !powerMenu.visible }
        }
    }

    // ---------- Dock (always visible, macOS-style: pinned + running combined) ----------
    PanelWindow {
        anchors { bottom: true; left: true; right: true }
        implicitHeight: 52
        color: Theme.panel

        Row {
            anchors.centerIn: parent
            spacing: 10
            Repeater {
                model: dockEntries
                delegate: Column {
                    spacing: 2
                    Rectangle {
                        width: 36; height: 36; radius: 9
                        color: dockMouse.containsMouse ? Theme.forge : "#00000000"
                        anchors.horizontalCenter: parent.horizontalCenter
                        scale: dockMouse.containsMouse ? 1.15 : 1.0
                        Behavior on scale { NumberAnimation { duration: 120 } }
                        Image {
                            anchors.centerIn: parent
                            width: 26; height: 26
                            source: modelData.icon
                            fillMode: Image.PreserveAspectFit
                            visible: modelData.icon.length > 0
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: modelData.icon.length === 0 && modelData.glyph.length > 0
                            text: modelData.glyph
                            color: Theme.panelInk; font.pixelSize: 17
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: modelData.icon.length === 0 && modelData.glyph.length === 0
                            text: modelData.name.charAt(0)
                            color: Theme.panelInk; font.pixelSize: 14; font.bold: true
                        }
                        MouseArea {
                            id: dockMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Quickshell.execDetached(modelData.cmd)
                        }
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 4; height: 4; radius: 2
                        color: Theme.forge
                        visible: modelData.running
                    }
                }
            }
        }
    }

    // ---------- Tier 1 widget panel + edit toggle (unchanged content, now individually toggle-able) ----------
    PanelWindow {
        id: widgetPanel
        anchors { bottom: true; right: true }
        margins { bottom: 60; right: 16 }
        implicitWidth: 220
        implicitHeight: 350
        exclusiveZone: -1
        color: Theme.panel
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        SystemClock { id: worldBase; precision: SystemClock.Minutes }

        FileView {
            id: notesFile
            path: "@@JAZZ_DATA_DIR@@/notes.txt"
            onLoaded: notesEdit.text = notesFile.text()
        }
        FileView {
            id: todoFile
            path: "@@JAZZ_DATA_DIR@@/todo.txt"
            onLoaded: {
                todoModel.clear();
                var lines = todoFile.text().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i];
                    if (line.length === 0) continue;
                    todoModel.append({ label: line.substring(2), done: line.charAt(0) === "1" });
                }
            }
            onLoadFailed: {
                todoModel.append({ label: "Send logo", done: true });
                todoModel.append({ label: "Task 10: clock widget", done: true });
                todoModel.append({ label: "Task 11: Theme.qml", done: true });
                todoModel.append({ label: "Tier 1 widgets", done: false });
            }
        }
        ListModel { id: todoModel }
        function saveTodo() {
            var out = "";
            for (var i = 0; i < todoModel.count; i++) {
                var item = todoModel.get(i);
                out += (item.done ? "1" : "0") + "|" + item.label + "\n";
            }
            todoFile.setText(out);
        }

        QtObject {
            id: pomo
            property int totalSeconds: 25 * 60
            property int remaining: 25 * 60
            property bool running: false
        }
        Timer {
            interval: 1000; repeat: true; running: pomo.running
            onTriggered: { if (pomo.remaining > 0) pomo.remaining -= 1; else pomo.running = false; }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Row {
                width: parent.width
                Text { text: "WIDGETS"; color: Theme.panelInk; opacity: 0.6; font.pixelSize: 10; font.bold: true; width: parent.width - 40 }
                Text {
                    text: "✎ Edit"; color: Theme.panelInk; font.pixelSize: 10
                    MouseArea { anchors.fill: parent; onClicked: widgetEditPopup.visible = !widgetEditPopup.visible }
                }
            }

            Column {
                visible: isWidgetEnabled("worldclock")
                spacing: 2
                width: parent.width
                Text { text: "WORLD CLOCK"; color: Theme.panelInk; opacity: 0.6; font.pixelSize: 10; font.bold: true }
                Row { spacing: 8
                    Text { text: "Goa"; width: 34; color: Theme.panelInk; font.pixelSize: 11 }
                    Text { color: Theme.panelInk; font.pixelSize: 11; font.family: "monospace"; text: Qt.formatTime(worldBase.date, "hh:mm") }
                }
                Row { spacing: 8
                    Text { text: "UTC"; width: 34; color: Theme.panelInk; font.pixelSize: 11 }
                    Text { color: Theme.panelInk; font.pixelSize: 11; font.family: "monospace"; text: Qt.formatTime(new Date(worldBase.date.getTime() + worldBase.date.getTimezoneOffset() * 60000), "hh:mm") }
                }
                Row { spacing: 8
                    Text { text: "SF"; width: 34; color: Theme.panelInk; font.pixelSize: 11 }
                    Text { color: Theme.panelInk; font.pixelSize: 11; font.family: "monospace"; text: Qt.formatTime(new Date(worldBase.date.getTime() + worldBase.date.getTimezoneOffset() * 60000 - 7 * 3600000), "hh:mm") }
                }
            }

            Column {
                visible: isWidgetEnabled("notes")
                width: parent.width
                spacing: 2
                Text { text: "NOTES"; color: Theme.panelInk; opacity: 0.6; font.pixelSize: 10; font.bold: true }
                Rectangle {
                    width: parent.width; height: 50
                    color: "#00000000"; border.color: Theme.panelInk; border.width: 1; radius: 4
                    TextEdit {
                        id: notesEdit
                        anchors.fill: parent; anchors.margins: 5
                        color: Theme.panelInk; font.pixelSize: 11; wrapMode: TextEdit.Wrap
                        onTextChanged: saveNotesTimer.restart()
                    }
                }
                Timer { id: saveNotesTimer; interval: 800; onTriggered: notesFile.setText(notesEdit.text) }
            }

            Column {
                visible: isWidgetEnabled("todo")
                width: parent.width
                spacing: 3
                Text { text: "TO-DO"; color: Theme.panelInk; opacity: 0.6; font.pixelSize: 10; font.bold: true }
                Repeater {
                    model: todoModel
                    delegate: Row {
                        spacing: 6
                        Rectangle {
                            width: 12; height: 12; radius: 2
                            border.color: Theme.panelInk; border.width: 1
                            color: model.done ? Theme.lab : "#00000000"
                            MouseArea { anchors.fill: parent; onClicked: { todoModel.setProperty(index, "done", !model.done); widgetPanel.saveTodo(); } }
                        }
                        Text { text: model.label; color: Theme.panelInk; font.pixelSize: 11; font.strikeout: model.done }
                    }
                }
            }

            Row {
                visible: isWidgetEnabled("pomodoro")
                spacing: 8
                Text {
                    color: Theme.panelInk; font.pixelSize: 14; font.family: "monospace"
                    text: {
                        var m = Math.floor(pomo.remaining / 60);
                        var s = pomo.remaining % 60;
                        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
                    }
                }
                Rectangle {
                    width: 44; height: 18; radius: 4; color: Theme.arena
                    Text { anchors.centerIn: parent; text: pomo.running ? "Pause" : "Start"; font.pixelSize: 9; color: "#ffffff" }
                    MouseArea { anchors.fill: parent; onClicked: pomo.running = !pomo.running }
                }
                Rectangle {
                    width: 44; height: 18; radius: 4; color: Theme.vault
                    Text { anchors.centerIn: parent; text: "Reset"; font.pixelSize: 9; color: "#ffffff" }
                    MouseArea { anchors.fill: parent; onClicked: { pomo.running = false; pomo.remaining = pomo.totalSeconds; } }
                }
            }
        }

        Rectangle {
            id: widgetEditPopup
            visible: false
            anchors.bottom: parent.top
            anchors.right: parent.right
            anchors.bottomMargin: 6
            width: 160; height: widgetEditCol.height + 16
            radius: 8
            color: Theme.panel
            border.color: Theme.panelInk
            border.width: 1
            Column {
                id: widgetEditCol
                anchors.centerIn: parent
                width: parent.width - 16
                spacing: 6
                Repeater {
                    model: widgetCatalog.items
                    delegate: Row {
                        width: parent.width
                        Text { text: modelData.label; color: Theme.panelInk; font.pixelSize: 11; width: parent.width - 30 }
                        Rectangle {
                            width: 24; height: 14; radius: 7
                            color: modelData.enabled ? Theme.forge : Theme.panelInk
                            opacity: modelData.enabled ? 1 : 0.25
                            Rectangle { width: 10; height: 10; radius: 5; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter; x: modelData.enabled ? parent.width - width - 2 : 2 }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    var items = widgetCatalog.items.slice();
                                    items[index].enabled = !items[index].enabled;
                                    widgetCatalog.items = items;
                                    saveWidgetPrefs();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
SHELLQML

sed -i "s|@@JAZZ_DATA_DIR@@|$DATA_DIR|g" "$SHELL_FILE"

if [[ -f "$HYPR_CONFIG" ]] && ! grep -q 'Added by setup-dock.sh' "$HYPR_CONFIG"; then
    # setup-hyprland.sh's own SUPER+R bind (wofi) must be removed - Akash
    # wants the native, workspace-themed launcher grid back (real icons via
    # the app scan this time, not the earlier hardcoded/glyph version) -
    # two binds on the same combo is undefined/risky, not left to chance.
    sudo -u "$USERNAME" sed -i '/hl\.bind(mainMod \.\. " + R", hl\.dsp\.exec_cmd(menu))/d' "$HYPR_CONFIG"

    sudo -u "$USERNAME" tee -a "$HYPR_CONFIG" > /dev/null << 'EOF'

-- Added by setup-dock.sh (Task 22): keyboard shortcuts for the launcher/
-- quick-settings/full-Settings-panel/power-menu, on top of the top-bar
-- icons/mouse clicks Quickshell itself provides. Reassigns SUPER+R from
-- wofi to the native launcher (setup-hyprland.sh's original bind removed
-- above, not left duplicated alongside this one).
hl.bind("SUPER + R", hl.dsp.exec_cmd("qs ipc call launcher toggle"))
hl.bind("SUPER + S", hl.dsp.exec_cmd("qs ipc call quicksettings toggle"))
hl.bind("SUPER + Comma", hl.dsp.exec_cmd("qs ipc call settings toggle"))
hl.bind("SUPER + Escape", hl.dsp.exec_cmd("qs ipc call powermenu toggle"))

-- Real notification daemon + clipboard history recorder, backing the top
-- bar's bell/clipboard tray icons - both need a running background
-- process, not just a UI icon with nothing behind it.
hl.on("hyprland.start", function()
    hl.exec_cmd("dunst")
    hl.exec_cmd("wl-paste --watch cliphist store")
end)
EOF
fi

echo "Dock/settings/powermenu prepared for $USERNAME:"
ls -la "$THEME_FILE" "$SHELL_FILE"
