#!/usr/bin/env bash
# Tier 1 daily-life widgets (Design-Vision.md sec 6): World clock, Notes,
# To-do, Pomodoro. All "pure local, no external dependency" per that doc's
# own tiering - the first batch broken out of the backlog now that Task
# 10/11 proved the Quickshell+Theme.qml mechanism works end to end.
#
# Rewrites shell.qml (superseding setup-quickshell.sh/setup-theme.sh's
# versions - always the latest writer wins, same pattern as Task 11) to add
# a second PanelWindow: a small floating panel, bottom-right, persistent
# across every workspace (not tied to one workspace's identity color,
# matching Design-Vision.md sec 6's own framing).
#
# Notes/To-do use Quickshell's real Quickshell.Io FileView component for
# actual disk persistence - confirmed via its installed .qmltypes (path,
# .text(), .setText(), onLoaded/onLoadFailed), not guessed. World clock
# computes other cities' time via plain UTC-offset arithmetic on the local
# SystemClock (Asia/Kolkata, per Task 4's base-profile.json) rather than
# relying on Qt's ICU/timezone-database support, which isn't confirmed
# present - simpler, and accurate enough for a Tier 1 proof (ignores DST
# edge cases). Pomodoro uses a plain QML Timer - no extra dependency.
#
# Deliberately avoids QtQuick.Controls (CheckBox/Button) - not a confirmed
# dependency of this install, so checkboxes/buttons are hand-rolled from
# Rectangle + MouseArea, matching only what's already proven working.
#
# Run this ON THE INSTALLED GUEST, as root.
# Usage: setup-widgets-tier1.sh <username>
set -eu

USERNAME="${1:?Usage: setup-widgets-tier1.sh <username>}"
QS_DIR="/home/$USERNAME/.config/quickshell"
THEME_FILE="$QS_DIR/Theme.qml"
SHELL_FILE="$QS_DIR/shell.qml"
DATA_DIR="/home/$USERNAME/.local/share/jazz"

sudo -u "$USERNAME" mkdir -p "$QS_DIR" "$DATA_DIR"

sudo -u "$USERNAME" tee "$THEME_FILE" > /dev/null << 'EOF'
pragma Singleton
import QtQuick

// JAZZ Theme singleton (Task 11, extended for Tier 1 widgets). Named color
// tokens shared across every Quickshell widget. Workspace tokens match the
// palette agreed in Design-Vision.md sec 2 / the approved desktop-sim
// mockup; panel/panelInk are a neutral background+text pair for the
// persistent cross-workspace widget panel (sec 6), which isn't tied to any
// one workspace's identity color.
QtObject {
    readonly property color forge: "#4c6fa0"   // Coding, AI app engineering
    readonly property color lab: "#3e8e76"     // Notebooks, PyTorch/Jupyter
    readonly property color arena: "#c98a34"   // AI red-teaming
    readonly property color observe: "#7c919a" // Logs, metrics, AI Command Centre
    readonly property color vault: "#3a3d44"   // Secrets, sensitive config
    readonly property color range: "#a23a3a"   // Reserved - dormant

    readonly property color panel: "#1e1d24"     // persistent widget panel background
    readonly property color panelInk: "#ede9e2"  // persistent widget panel text
}
EOF

sudo -u "$USERNAME" tee "$SHELL_FILE" > /dev/null << 'EOF'
// JAZZ Quickshell config (Tasks 10-11 + Tier 1 widgets). Top bar: a live
// clock using Theme.qml's Forge token (Tasks 10-11). Bottom-right floating
// panel: the first 4 widgets broken out of the Design-Vision.md sec 6
// backlog (World clock, Notes, To-do, Pomodoro) - persistent across every
// workspace, not styled to any one workspace's identity color.

import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    PanelWindow {
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: 32
        color: Theme.forge

        SystemClock {
            id: clock
            precision: SystemClock.Seconds
        }

        Text {
            anchors.centerIn: parent
            text: Qt.formatTime(clock.date, "hh:mm:ss")
            color: "#ede9e2"
            font.pixelSize: 16
        }
    }

    PanelWindow {
        id: widgetPanel
        anchors {
            bottom: true
            right: true
        }
        margins {
            bottom: 16
            right: 16
        }
        implicitWidth: 220
        implicitHeight: 320
        exclusiveZone: -1
        color: Theme.panel

        SystemClock {
            id: worldBase
            precision: SystemClock.Minutes
        }

        FileView {
            id: notesFile
            path: "/home/holycowstudios/.local/share/jazz/notes.txt"
            onLoaded: notesEdit.text = notesFile.text()
        }
        FileView {
            id: todoFile
            path: "/home/holycowstudios/.local/share/jazz/todo.txt"
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
            interval: 1000
            repeat: true
            running: pomo.running
            onTriggered: {
                if (pomo.remaining > 0) pomo.remaining -= 1;
                else pomo.running = false;
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            // World clock
            Column {
                spacing: 2
                width: parent.width
                Text { text: "WORLD CLOCK"; color: Theme.panelInk; opacity: 0.6; font.pixelSize: 10; font.bold: true }
                Row { spacing: 8
                    Text { text: "Goa"; width: 34; color: Theme.panelInk; font.pixelSize: 11 }
                    Text {
                        color: Theme.panelInk; font.pixelSize: 11; font.family: "monospace"
                        text: Qt.formatTime(worldBase.date, "hh:mm")
                    }
                }
                Row { spacing: 8
                    Text { text: "UTC"; width: 34; color: Theme.panelInk; font.pixelSize: 11 }
                    Text {
                        color: Theme.panelInk; font.pixelSize: 11; font.family: "monospace"
                        text: Qt.formatTime(new Date(worldBase.date.getTime() + worldBase.date.getTimezoneOffset() * 60000), "hh:mm")
                    }
                }
                Row { spacing: 8
                    Text { text: "SF"; width: 34; color: Theme.panelInk; font.pixelSize: 11 }
                    Text {
                        color: Theme.panelInk; font.pixelSize: 11; font.family: "monospace"
                        text: Qt.formatTime(new Date(worldBase.date.getTime() + worldBase.date.getTimezoneOffset() * 60000 - 7 * 3600000), "hh:mm")
                    }
                }
            }

            // Notes
            Column {
                width: parent.width
                spacing: 2
                Text { text: "NOTES"; color: Theme.panelInk; opacity: 0.6; font.pixelSize: 10; font.bold: true }
                Rectangle {
                    width: parent.width; height: 50
                    color: "#00000000"; border.color: Theme.panelInk; border.width: 1; radius: 4
                    TextEdit {
                        id: notesEdit
                        anchors.fill: parent
                        anchors.margins: 5
                        color: Theme.panelInk
                        font.pixelSize: 11
                        wrapMode: TextEdit.Wrap
                        onTextChanged: saveNotesTimer.restart()
                    }
                }
                Timer { id: saveNotesTimer; interval: 800; onTriggered: notesFile.setText(notesEdit.text) }
            }

            // To-do
            Column {
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
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { todoModel.setProperty(index, "done", !model.done); widgetPanel.saveTodo(); }
                            }
                        }
                        Text {
                            text: model.label; color: Theme.panelInk; font.pixelSize: 11
                            font.strikeout: model.done
                        }
                    }
                }
            }

            // Pomodoro
            Row {
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
    }
}
EOF

echo "Tier 1 widgets prepared for $USERNAME:"
ls -la "$THEME_FILE" "$SHELL_FILE" "$DATA_DIR"
