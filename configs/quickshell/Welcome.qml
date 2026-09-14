// JAZZ first-boot Welcome app (Task 33). Loaded via Loader { source:
// "Welcome.qml" } from shell.qml (setup-dock.sh), right after the Settings
// Loader - same pattern, separate file. Written by scripts/setup-welcome.sh.
//
// Shown exactly once per account: the marker file ($JAZZ_DATA_DIR/welcome-
// shown) uses the same FileView onLoaded/onLoadFailed convention already
// established for Notes/To-do (setup-dock.sh) - onLoadFailed means the
// marker was never written, i.e. genuinely first boot; onLoaded means it
// was already dismissed, stay hidden. Unlike Settings' dim-click-to-close,
// there is deliberately NO click-outside-to-dismiss here - the only way to
// close this is the explicit "Let's go" button, which is also the only
// thing that writes the marker. That keeps "shown once, never again after
// being dismissed" (this task's own acceptance bar) unambiguous - an
// accidental outside click can't silently burn the one-time showing.
//
// Real content only, no placeholder/fake filler (Design-Vision.md's
// "functional honesty" precedent, already applied to the GPU/audio panels
// in Tasks 24/26): the theme picker button and the user-count nudge both
// reflect this specific machine's real state, not generic copy.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "ui"

PanelWindow {
    id: welcomePanel
    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#00000000"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusiveZone: -1

    property int realUserCount: 0

    Rectangle { anchors.fill: parent; color: "#0a090899" }

    FileView {
        id: welcomeMarker
        path: "@@JAZZ_DATA_DIR@@/welcome-shown"
        onLoaded: welcomePanel.visible = false
        onLoadFailed: welcomePanel.visible = true
    }
    function dismiss() {
        welcomeMarker.setText("1")
        welcomePanel.visible = false
    }

    Process {
        id: userCountProc
        running: welcomePanel.visible
        command: ["bash", "-c", "getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 && ($7 ~ /bash|zsh|fish|sh$/)' | wc -l"]
        stdout: SplitParser { onRead: function (data) { if (data) welcomePanel.realUserCount = parseInt(data) } }
    }

    Rectangle {
        id: welcomeBox
        width: 620
        // Sized to its own content, not a guessed fixed height - this card
        // has more text than Settings' fixed-size tabs, and a hardcoded
        // height risked clipping the bottom button (the exact bug class
        // Task 31 already hit once with fixed dimensions).
        height: welcomeContent.implicitHeight + 72
        anchors.centerIn: parent
        radius: 21
        color: Theme.panel
        border.color: Theme.panelInk
        border.width: 1

        Column {
            id: welcomeContent
            anchors.top: parent.top
            anchors.topMargin: 36
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 72
            spacing: 20

            Text {
                font.family: Theme.uiFont; font.pixelSize: 32; font.bold: true
                color: Theme.panelInk
                text: "Welcome to JAZZ"
            }
            Text {
                font.family: Theme.uiFont; font.pixelSize: 16
                color: Theme.textSecondary
                width: parent.width
                wrapMode: Text.WordWrap
                text: "This is a real Arch Linux desktop built around Hyprland and Quickshell, tuned for AI engineering work - local models, red-teaming tools, and agent-driven workflows live alongside a normal desktop. Everything you see is fully configurable from Settings."
            }

            Rectangle { width: parent.width; height: 1; color: Theme.panelInk; opacity: 0.3 }

            Column {
                width: parent.width; spacing: 12
                Text { font.family: Theme.uiFont; font.pixelSize: 18; font.bold: true; color: Theme.panelInk; text: "Pick a look" }
                Text {
                    font.family: Theme.uiFont; font.pixelSize: 14; color: Theme.textSecondary
                    width: parent.width; wrapMode: Text.WordWrap
                    text: "Four real themes - Forge, Daylight, Midnight, Warm - each with its own wallpaper, terminal palette, and accent. Switch anytime from Settings."
                }
                Button {
                    label: "Open theme picker"
                    onClicked: Quickshell.execDetached(["qs", "ipc", "call", "settings", "toggle"])
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.panelInk; opacity: 0.3 }

            Column {
                width: parent.width; spacing: 12
                Text { font.family: Theme.uiFont; font.pixelSize: 18; font.bold: true; color: Theme.panelInk; text: "Know the keybinds" }
                Text {
                    font.family: Theme.uiFont; font.pixelSize: 14; color: Theme.textSecondary
                    width: parent.width; wrapMode: Text.WordWrap
                    text: "JAZZ is a tiling window manager - Super+Return for a terminal, Super+R to launch apps, Super+1-6 to switch workspaces. The full list is one click away."
                }
                Button {
                    label: "View keybinds"
                    onClicked: Quickshell.execDetached(["kitty", "-e", "less", "@@JAZZ_DATA_DIR@@/Keybinds.md"])
                }
            }

            Text {
                visible: welcomePanel.realUserCount <= 1
                font.family: Theme.uiFont; font.pixelSize: 14; color: Theme.textSecondary
                width: parent.width; wrapMode: Text.WordWrap
                text: "This machine only has one real account so far - Settings > Users lets you add more, each with their own theme, password, and admin status."
            }

            Item {
                width: parent.width; height: getStartedButton.height
                Button {
                    id: getStartedButton
                    anchors.right: parent.right
                    label: "Let's go"
                    variant: "primary"
                    onClicked: welcomePanel.dismiss()
                }
            }
        }
    }
}
