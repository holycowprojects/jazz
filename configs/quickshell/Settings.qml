// JAZZ Settings (Task 28: full expansion). Extracted out of shell.qml's
// heredoc into its own file (loaded via Loader { source: "Settings.qml" })
// once the panel grew past a handful of tabs - see setup-dock.sh's comment
// at the Loader call site. Written by scripts/setup-settings.sh.
//
// Sections marked REAL below are backed by live data/actions confirmed on
// the Yoga 6. Sections marked PENDING are real, distinct pages in the
// navigation (not fake controls) but have no backend wired yet - matches
// the project's existing "honest pending state, never fake data" rule
// (same precedent as the GPU utilization panel before Task 26 landed).
//
// Styling goes through Theme.qml's tokens only (panel/panelInk/forge/
// surfaceRaised/textSecondary) - no new hardcoded hex values - so a future
// Task 25 design pass can restyle by editing Theme.qml, not by touching
// every section here.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "ui"

PanelWindow {
    id: settingsPanel
    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#00000000"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusiveZone: -1

    property string currentPage: "appearance"
    property string searchQuery: ""
    property bool devModeEnabled: false

    // ---------- Settings schema (Task 28 scope, Task 27's "single source
    // of truth for search" idea): id/title/keywords/page. Universal
    // Command (docs/JAZZ-v2.md sec 5d) can reuse this same list later
    // without rework. ----------
    readonly property var schema: [
        { id: "appearance.theme", title: "Dark / Light mode", keywords: ["theme", "dark", "light", "appearance"], page: "appearance" },
        { id: "appearance.wallpaper", title: "Wallpaper", keywords: ["wallpaper", "background"], page: "appearance" },
        { id: "network.status", title: "Wi-Fi status", keywords: ["wifi", "network", "internet", "ssid"], page: "network" },
        { id: "bluetooth.manage", title: "Bluetooth devices", keywords: ["bluetooth", "pair", "headphones"], page: "bluetooth" },
        { id: "sound.volume", title: "Volume", keywords: ["sound", "audio", "volume", "speaker"], page: "sound" },
        { id: "display.brightness", title: "Brightness", keywords: ["display", "brightness", "screen"], page: "display" },
        { id: "storage.usage", title: "Disk usage", keywords: ["storage", "disk", "space", "snapshot", "btrfs"], page: "storage" },
        { id: "power.battery", title: "Battery status", keywords: ["battery", "power", "charging"], page: "power" },
        { id: "agents.ledger", title: "Agent activity ledger", keywords: ["agent", "ai", "undo", "checkpoint", "safety", "permissions"], page: "agents" },
        { id: "agents.policy", title: "Agent permissions", keywords: ["agent", "policy", "allow", "ask", "deny"], page: "agents" },
        { id: "system.about", title: "About this system", keywords: ["about", "system", "hostname", "kernel", "cpu", "gpu", "memory"], page: "system" },
        { id: "desktop.general", title: "Desktop", keywords: ["desktop", "dock", "workspace"], page: "desktop" },
        { id: "input.keyboard", title: "Keyboard & Mouse", keywords: ["keyboard", "mouse", "touchpad", "shortcuts"], page: "input" },
        { id: "apps.general", title: "Applications", keywords: ["applications", "apps", "default"], page: "apps" },
        { id: "ai.general", title: "AI", keywords: ["ai", "ollama", "model"], page: "ai" },
        { id: "privacy.general", title: "Privacy", keywords: ["privacy"], page: "privacy" },
        { id: "security.general", title: "Security", keywords: ["security", "firewall", "ssh", "secure boot"], page: "security" },
        { id: "updates.general", title: "Updates", keywords: ["updates", "pacman", "upgrade"], page: "updates" },
        { id: "accessibility.general", title: "Accessibility", keywords: ["accessibility", "motion", "scale"], page: "accessibility" },
        { id: "developer.general", title: "Developer", keywords: ["developer", "logs", "debug"], page: "developer" }
    ]

    readonly property var sections: [
        { id: "appearance", title: "Appearance", real: true },
        { id: "desktop", title: "Desktop", real: true },
        { id: "display", title: "Displays", real: true },
        { id: "input", title: "Keyboard & Mouse", real: true },
        { id: "sound", title: "Sound", real: true },
        { id: "network", title: "Network", real: true },
        { id: "bluetooth", title: "Bluetooth", real: true },
        { id: "apps", title: "Applications", real: true },
        { id: "ai", title: "AI", real: true },
        { id: "privacy", title: "Privacy", real: true },
        { id: "agents", title: "Agents", real: true },
        { id: "storage", title: "Storage", real: true },
        { id: "power", title: "Battery & Power", real: true },
        { id: "security", title: "Security", real: true },
        { id: "users", title: "Users", real: true },
        { id: "updates", title: "Updates", real: true },
        { id: "accessibility", title: "Accessibility", real: true },
        { id: "system", title: "System", real: true },
        { id: "developer", title: "Developer", real: true, devOnly: true }
    ]

    function visibleSections() {
        var out = []
        for (var i = 0; i < sections.length; i++) {
            if (sections[i].devOnly && !devModeEnabled) continue
            out.push(sections[i])
        }
        return out
    }

    function searchResults() {
        if (searchQuery.length === 0) return []
        // Match per-word (not one contiguous substring) so a query like "dark
        // mode" finds a title like "Dark / Light mode" - each word just needs
        // to appear somewhere across the title + keywords, in any order.
        var words = searchQuery.toLowerCase().split(/\s+/).filter(function(w) { return w.length > 0 })
        var out = []
        for (var i = 0; i < schema.length; i++) {
            var e = schema[i]
            var haystack = e.title.toLowerCase() + " " + e.keywords.join(" ").toLowerCase()
            var allWordsFound = words.every(function(w) { return haystack.indexOf(w) >= 0 })
            if (allWordsFound) out.push(e)
        }
        return out
    }

    Process {
        id: devModeCheck
        command: ["bash", "-c", "test -f @@JAZZ_CONFIG_DIR@@/dev-mode.enabled && echo yes || echo no"]
        stdout: SplitParser { onRead: function (data) { settingsPanel.devModeEnabled = (data === "yes") } }
    }
    Component.onCompleted: devModeCheck.running = true

    Rectangle { anchors.fill: parent; color: "#0a090899" }
    MouseArea { anchors.fill: parent; onClicked: settingsPanel.visible = false }

    Rectangle {
        id: settingsBox
        width: 1290; height: 900
        anchors.centerIn: parent
        radius: 21
        color: Theme.panel
        border.color: Theme.panelInk
        border.width: 1
        clip: true
        MouseArea { anchors.fill: parent }

        property var wallpapers: []
        // Task 27b: real theme picker, replacing the old binary dark/light
        // toggle. Ids/labels match design/tokens/themes.json - hardcoded
        // here rather than parsed from themes.json at runtime since it's
        // a short, rarely-changing list (same judgment call already made
        // elsewhere in this file for other small option lists).
        property var themeList: [
            { id: "forge", label: "Forge" },
            { id: "daylight", label: "Daylight" },
            { id: "midnight", label: "Midnight" },
            { id: "warm", label: "Warm" },
            { id: "sapphire", label: "Sapphire" }
        ]
        // Font-picker follow-up (Task 27) - matches
        // design/tokens/typography.json's curated options exactly.
        property var uiFontList: ["Inter", "IBM Plex Sans", "Mona Sans", "Fira Sans"]
        property var monoFontList: ["JetBrains Mono", "IBM Plex Mono", "Iosevka", "Cascadia Code"]
        Process {
            id: wallListProc
            command: ["bash", "-c", "ls @@JAZZ_DATA_DIR@@/wallpapers/*.png 2>/dev/null"]
            stdout: StdioCollector {
                onStreamFinished: {
                    var lines = this.text.split("\n").filter(function(s) { return s.length > 0 })
                    settingsBox.wallpapers = lines
                }
            }
        }
        Component.onCompleted: wallListProc.running = true

        Column {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 18

            // ---------- Search ----------
            Rectangle {
                width: parent.width; height: 48; radius: 12
                color: Theme.surfaceRaised
                border.color: Theme.panelInk; border.width: 1
                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.margins: 12
                    color: Theme.panelInk
                    font.pixelSize: 20
                    clip: true
                    focus: settingsPanel.visible
                    onTextChanged: settingsPanel.searchQuery = text
                    Keys.onEscapePressed: { text = ""; settingsPanel.searchQuery = "" }
                }
                Text {
                    visible: searchInput.text.length === 0
                    anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                    text: "Search settings..."; color: Theme.textSecondary; font.pixelSize: 20
                }
            }

            // ---------- Search results ----------
            Column {
                visible: settingsPanel.searchQuery.length > 0
                width: parent.width
                spacing: 3
                Repeater {
                    model: settingsPanel.searchResults()
                    delegate: Rectangle {
                        width: parent.width; height: 39; radius: 9
                        color: "#00000000"
                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                            text: modelData.title + "  ›  " + modelData.page
                            color: Theme.panelInk; font.pixelSize: 18
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { settingsPanel.currentPage = modelData.page; searchInput.text = ""; settingsPanel.searchQuery = "" }
                        }
                    }
                }
            }

            Row {
                visible: settingsPanel.searchQuery.length === 0
                width: parent.width
                height: parent.height - 66
                spacing: 30

                // ---------- Sidebar ----------
                Flickable {
                    width: 240; height: parent.height
                    contentHeight: sidebarCol.height
                    clip: true
                    Column {
                        id: sidebarCol
                        width: parent.width
                        spacing: 3
                        Repeater {
                            model: settingsPanel.visibleSections()
                            delegate: ListRow {
                                label: modelData.title
                                selected: settingsPanel.currentPage === modelData.id
                                showMarker: !modelData.real
                                onClicked: settingsPanel.currentPage = modelData.id
                            }
                        }
                    }
                }

                Rectangle { width: 2; height: parent.height; color: Theme.panelInk; opacity: 0.15 }

                // ---------- Content ----------
                Flickable {
                    id: contentArea
                    width: 930; height: parent.height
                    contentHeight: contentCol.height
                    clip: true

                    Column {
                        id: contentCol
                        width: parent.width
                        spacing: 24

                        // ===== Appearance (Task 27b: real theme picker,
                        // replacing the old binary dark/light toggle) =====
                        Column {
                            visible: settingsPanel.currentPage === "appearance"
                            width: parent.width
                            spacing: 24
                            SectionHeader { text: "APPEARANCE" }
                            Text { font.family: Theme.uiFont; text: "Theme"; color: Theme.textSecondary; font.pixelSize: 18 }
                            Flow {
                                width: parent.width
                                spacing: 12
                                Repeater {
                                    model: settingsBox.themeList
                                    delegate: Rectangle {
                                        property bool active: Theme.activeTheme === modelData.id
                                        width: 138; height: 51; radius: 12
                                        color: active ? WorkspaceState.activeColor() : Theme.surfaceRaised
                                        border.color: Theme.textSecondary
                                        border.width: active ? 0 : 1
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: active ? "#ffffff" : Theme.panelInk
                                            font.pixelSize: 18
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: Quickshell.execDetached(["jazz-theme-set", modelData.id])
                                        }
                                    }
                                }
                            }
                            SectionHeader { text: "Fonts" }
                            Row {
                                spacing: 24
                                z: 10
                                Column {
                                    spacing: 6
                                    Text { font.family: Theme.uiFont; text: "Interface"; color: Theme.textSecondary; font.pixelSize: 12 }
                                    Item {
                                        id: uiFontPicker
                                        width: 220; height: 36
                                        property bool open: false
                                        Rectangle {
                                            anchors.fill: parent; radius: 8; color: Theme.surfaceRaised
                                            border.color: Theme.textSecondary; border.width: 1
                                            Row {
                                                anchors.fill: parent; anchors.margins: 8; spacing: 8
                                                Text {
                                                    text: Theme.uiFont; color: Theme.panelInk; font.pixelSize: 16
                                                    width: parent.width - 20; elide: Text.ElideRight
                                                }
                                                Text { font.family: Theme.uiFont; text: uiFontPicker.open ? "\u25B2" : "\u25BC"; color: Theme.textSecondary; font.pixelSize: 10 }
                                            }
                                            MouseArea { anchors.fill: parent; onClicked: uiFontPicker.open = !uiFontPicker.open }
                                        }
                                        Rectangle {
                                            visible: uiFontPicker.open
                                            y: parent.height + 4
                                            width: parent.width
                                            height: uiOptCol.height + 8
                                            radius: 8; color: Theme.surfaceRaised
                                            border.color: Theme.textSecondary; border.width: 1
                                            z: 200
                                            Column {
                                                id: uiOptCol
                                                x: 4; y: 4
                                                width: parent.width - 8
                                                Repeater {
                                                    model: settingsBox.uiFontList
                                                    delegate: Rectangle {
                                                        width: parent.width; height: 32; radius: 6
                                                        color: Theme.uiFont === modelData ? WorkspaceState.activeColor() : "#00000000"
                                                        Text {
                                                            anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                                                            text: modelData
                                                            font.family: modelData
                                                            color: Theme.uiFont === modelData ? "#ffffff" : Theme.panelInk
                                                            font.pixelSize: 15
                                                        }
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            onClicked: {
                                                                Quickshell.execDetached(["jazz-font-set", modelData, Theme.monoFont])
                                                                uiFontPicker.open = false
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                Column {
                                    spacing: 6
                                    Text { font.family: Theme.uiFont; text: "Monospace"; color: Theme.textSecondary; font.pixelSize: 12 }
                                    Item {
                                        id: monoFontPicker
                                        width: 220; height: 36
                                        property bool open: false
                                        Rectangle {
                                            anchors.fill: parent; radius: 8; color: Theme.surfaceRaised
                                            border.color: Theme.textSecondary; border.width: 1
                                            Row {
                                                anchors.fill: parent; anchors.margins: 8; spacing: 8
                                                Text {
                                                    text: Theme.monoFont; color: Theme.panelInk; font.pixelSize: 16
                                                    width: parent.width - 20; elide: Text.ElideRight
                                                }
                                                Text { font.family: Theme.uiFont; text: monoFontPicker.open ? "\u25B2" : "\u25BC"; color: Theme.textSecondary; font.pixelSize: 10 }
                                            }
                                            MouseArea { anchors.fill: parent; onClicked: monoFontPicker.open = !monoFontPicker.open }
                                        }
                                        Rectangle {
                                            visible: monoFontPicker.open
                                            y: parent.height + 4
                                            width: parent.width
                                            height: monoOptCol.height + 8
                                            radius: 8; color: Theme.surfaceRaised
                                            border.color: Theme.textSecondary; border.width: 1
                                            z: 200
                                            Column {
                                                id: monoOptCol
                                                x: 4; y: 4
                                                width: parent.width - 8
                                                Repeater {
                                                    model: settingsBox.monoFontList
                                                    delegate: Rectangle {
                                                        width: parent.width; height: 32; radius: 6
                                                        color: Theme.monoFont === modelData ? WorkspaceState.activeColor() : "#00000000"
                                                        Text {
                                                            anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                                                            text: modelData
                                                            font.family: modelData
                                                            color: Theme.monoFont === modelData ? "#ffffff" : Theme.panelInk
                                                            font.pixelSize: 15
                                                        }
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            onClicked: {
                                                                Quickshell.execDetached(["jazz-font-set", Theme.uiFont, modelData])
                                                                monoFontPicker.open = false
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            SectionHeader { text: "Wallpaper" }
                            Flow {
                                width: parent.width
                                spacing: 12
                                Repeater {
                                    model: settingsBox.wallpapers
                                    delegate: Rectangle {
                                        width: 135; height: 81; radius: 9
                                        border.color: Theme.panelInk; border.width: 1
                                        Image { anchors.fill: parent; anchors.margins: 3; source: "file://" + modelData; fillMode: Image.PreserveAspectCrop }
                                        MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["jazz-wallpaper-set", modelData]) }
                                    }
                                }
                            }
                        }

                        // ===== Desktop (REAL - workspace display-name + color overrides,
                        // Akash's feedback after using Task 28. Renaming/recoloring here is
                        // deliberately DISPLAY-ONLY: it edits a small JSON file
                        // (workspace-overrides.json) that shell.qml's dock/top bar reads
                        // live (FileView watchChanges) - Hyprland's own real workspace name
                        // (and the Super+1..6 keybinds that target it) never changes, so
                        // nothing about how you switch workspaces can break. Layout itself
                        // (dock position, auto-hide, hot corners) is still fixed by design
                        // for v1 - no controls shown for things that wouldn't do anything.
                        Column {
                            id: desktopTab
                            visible: settingsPanel.currentPage === "desktop"
                            width: parent.width; spacing: 15
                            property var overrides: ({})
                            property string statusMsg: ""

                            readonly property var workspaceDefs: [
                                { name: "Forge", desc: "Coding, AI app engineering", color: Theme.forge },
                                { name: "Lab", desc: "Notebooks, PyTorch/Jupyter", color: Theme.lab },
                                { name: "Arena", desc: "AI red-teaming", color: Theme.arena },
                                { name: "Observe", desc: "Logs, metrics, AI Command Centre", color: Theme.observe },
                                { name: "Vault", desc: "Secrets, sensitive config", color: Theme.vault },
                                { name: "Range", desc: "Reserved - dormant", color: Theme.range }
                            ]

                            FileView {
                                id: workspaceOverridesFile
                                path: "@@JAZZ_DATA_DIR@@/workspace-overrides.json"
                                onLoaded: { try { desktopTab.overrides = JSON.parse(workspaceOverridesFile.text()) } catch (e) {} }
                            }
                            Component.onCompleted: workspaceOverridesFile.reload()

                            function labelFor(name) { return (desktopTab.overrides[name] && desktopTab.overrides[name].label) ? desktopTab.overrides[name].label : name }
                            function colorFor(name, fallback) { return (desktopTab.overrides[name] && desktopTab.overrides[name].color) ? desktopTab.overrides[name].color : fallback }
                            function isValidHex(s) { return /^#[0-9A-Fa-f]{6}$/.test(s) }
                            function saveOverride(name, label, color) {
                                var next = JSON.parse(JSON.stringify(desktopTab.overrides))
                                next[name] = { label: label, color: color }
                                desktopTab.overrides = next
                                workspaceOverridesFile.setText(JSON.stringify(next))
                                desktopTab.statusMsg = name + " updated."
                            }
                            function resetOverride(name) {
                                var next = JSON.parse(JSON.stringify(desktopTab.overrides))
                                delete next[name]
                                desktopTab.overrides = next
                                workspaceOverridesFile.setText(JSON.stringify(next))
                                desktopTab.statusMsg = name + " reset to default."
                            }

                            SectionHeader { text: "DESKTOP" }
                            Row {
                                width: parent.width; spacing: 15
                                SectionHeader { anchors.verticalCenter: parent.verticalCenter; text: "Workspaces" }
                                Text { font.family: Theme.uiFont; anchors.verticalCenter: parent.verticalCenter; visible: desktopTab.statusMsg.length > 0; text: desktopTab.statusMsg; color: Theme.textSecondary; font.pixelSize: 15 }
                            }
                            Column {
                                width: parent.width; spacing: 12
                                Repeater {
                                    model: desktopTab.workspaceDefs
                                    delegate: Rectangle {
                                        id: wsRow
                                        property var wsData: modelData
                                        property string nameText: desktopTab.labelFor(wsData.name)
                                        property string colorText: desktopTab.colorFor(wsData.name, wsData.color)
                                        property bool hasOverride: desktopTab.overrides[wsData.name] !== undefined
                                        width: parent.width; height: 93; radius: 12; color: Theme.surfaceRaised
                                        Column {
                                            anchors.fill: parent; anchors.margins: 12; spacing: 6
                                            Row {
                                                width: parent.width; spacing: 12
                                                Text { font.family: Theme.uiFont; text: "Real name: " + wsRow.wsData.name; color: Theme.textSecondary; font.pixelSize: 15; width: 180 }
                                                Text { font.family: Theme.uiFont; text: wsRow.wsData.desc; color: Theme.textSecondary; font.pixelSize: 15 }
                                            }
                                            Row {
                                                width: parent.width; spacing: 12
                                                Rectangle {
                                                    width: 210; height: 33; radius: 6; color: Theme.panel
                                                    border.color: Theme.panelInk; border.width: 1
                                                    TextInput {
                                                        anchors.fill: parent; anchors.margins: 6
                                                        color: Theme.panelInk; font.pixelSize: 16; clip: true
                                                        text: wsRow.nameText
                                                        onTextChanged: wsRow.nameText = text
                                                    }
                                                }
                                                Rectangle {
                                                    width: 135; height: 33; radius: 6; color: Theme.panel
                                                    border.color: desktopTab.isValidHex(wsRow.colorText) ? Theme.panelInk : Theme.range
                                                    border.width: 1
                                                    TextInput {
                                                        anchors.fill: parent; anchors.margins: 6
                                                        color: Theme.panelInk; font.pixelSize: 16; clip: true
                                                        text: wsRow.colorText
                                                        onTextChanged: wsRow.colorText = text
                                                    }
                                                }
                                                Rectangle {
                                                    width: 27; height: 27; radius: 14; anchors.verticalCenter: parent.verticalCenter
                                                    color: desktopTab.isValidHex(wsRow.colorText) ? wsRow.colorText : wsRow.wsData.color
                                                    border.color: Theme.panelInk; border.width: 1
                                                }
                                                Button {
                                                    width: 75; height: 33
                                                    enabled: desktopTab.isValidHex(wsRow.colorText) && wsRow.nameText.trim().length > 0
                                                    label: "Save"
                                                    onClicked: desktopTab.saveOverride(wsRow.wsData.name, wsRow.nameText.trim(), wsRow.colorText)
                                                }
                                                Button {
                                                    visible: wsRow.hasOverride
                                                    width: 82; height: 33
                                                    variant: "neutral"
                                                    label: "Reset"
                                                    onClicked: desktopTab.resetOverride(wsRow.wsData.name)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            Text {
                                text: "Renaming here only changes the display label shown in the dock, top bar, and this list - Hyprland's own workspace identity (and your Super+1..6 keybinds) stay exactly as they are, so nothing about how you switch workspaces can break. Color changes also retint the top bar when that workspace is active. Window-border colors from the existing per-workspace rule stay on the original color for now. Dock/hot-corner/auto-hide behavior is still fixed by design for v1."
                                color: Theme.textSecondary; font.pixelSize: 15; wrapMode: Text.Wrap; width: parent.width
                            }
                        }

                        // ===== Displays (REAL - resolution control + rollback timer, Task 28's required safety mechanism) =====
                        Column {
                            id: displayTab
                            visible: settingsPanel.currentPage === "display"
                            width: parent.width; spacing: 15
                            property var monitorData: null
                            property string originalLuaLine: ""
                            property bool timerActive: false
                            property int secondsLeft: 12

                            Process {
                                id: monitorProc
                                command: ["bash", "-c", "hyprctl monitors -j"]
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        try { displayTab.monitorData = JSON.parse(this.text)[0] } catch (e) {}
                                    }
                                }
                            }
                            function refreshMonitor() { monitorProc.running = true }
                            Component.onCompleted: refreshMonitor()

                            // A revert issued via Quickshell.execDetached is fire-and-forget - querying
                            // hyprctl immediately after can race ahead of the compositor actually
                            // applying it, showing stale data even though the revert itself succeeded.
                            // Give it a moment to land before re-querying.
                            Timer {
                                id: revertRefreshDelay
                                interval: 500; repeat: false
                                onTriggered: displayTab.refreshMonitor()
                            }

                            Timer {
                                interval: 1000; repeat: true; running: displayTab.timerActive
                                onTriggered: {
                                    displayTab.secondsLeft -= 1
                                    if (displayTab.secondsLeft <= 0) {
                                        Quickshell.execDetached(["hyprctl", "eval", displayTab.originalLuaLine])
                                        displayTab.timerActive = false
                                        revertRefreshDelay.restart()
                                    }
                                }
                            }

                            function luaFor(mode) {
                                var m = displayTab.monitorData
                                return 'hl.monitor({ output = "' + m.name + '", mode = "' + mode + '", position = "' + m.x + 'x' + m.y + '", scale = ' + m.scale + ' })'
                            }
                            function applyMode(modeStr) {
                                var m = displayTab.monitorData
                                var clean = modeStr.replace("Hz", "")
                                displayTab.originalLuaLine = luaFor(m.width + "x" + m.height + "@" + m.refreshRate.toFixed(2))
                                Quickshell.execDetached(["hyprctl", "eval", luaFor(clean)])
                                displayTab.secondsLeft = 12
                                displayTab.timerActive = true
                            }

                            SectionHeader { text: "DISPLAYS" }
                            Text {
                                text: displayTab.monitorData
                                    ? (displayTab.monitorData.name + ": " + displayTab.monitorData.width + "x" + displayTab.monitorData.height + "@" + displayTab.monitorData.refreshRate.toFixed(2) + "Hz, scale " + displayTab.monitorData.scale)
                                    : "loading..."
                                color: Theme.panelInk; font.pixelSize: 20
                            }
                            Text { font.family: Theme.uiFont; text: "Same brightness control as the quick-settings flyout."; color: Theme.textSecondary; font.pixelSize: 16 }
                            SectionHeader { text: "AVAILABLE MODES" }
                            Flow {
                                width: parent.width; spacing: 9
                                Repeater {
                                    model: displayTab.monitorData ? displayTab.monitorData.availableModes : []
                                    delegate: Rectangle {
                                        width: 210; height: 39; radius: 9; color: Theme.surfaceRaised
                                        opacity: displayTab.timerActive ? 0.4 : 1
                                        Text { font.family: Theme.uiFont; anchors.centerIn: parent; text: modelData; font.pixelSize: 15; color: Theme.panelInk }
                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: !displayTab.timerActive
                                            onClicked: displayTab.applyMode(modelData)
                                        }
                                    }
                                }
                            }
                            Rectangle {
                                visible: displayTab.timerActive
                                width: parent.width; height: 96; radius: 12; color: Theme.surfaceRaised
                                border.color: WorkspaceState.activeColor(); border.width: 1
                                Column {
                                    anchors.centerIn: parent; spacing: 12
                                    Text {
                                        text: "Keep these display settings? Reverting in " + displayTab.secondsLeft + "s"
                                        color: Theme.panelInk; font.pixelSize: 20
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    Row {
                                        spacing: 15
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        Button {
                                            width: 105; height: 36
                                            fontSize: 11
                                            label: "Keep"
                                            onClicked: { displayTab.timerActive = false; displayTab.refreshMonitor() }
                                        }
                                        Button {
                                            width: 105; height: 36
                                            fontSize: 11
                                            variant: "neutral"
                                            label: "Revert"
                                            onClicked: {
                                                Quickshell.execDetached(["hyprctl", "eval", displayTab.originalLuaLine])
                                                displayTab.timerActive = false
                                                revertRefreshDelay.restart()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ===== Keyboard & Mouse (REAL) =====
                        Column {
                            id: inputTab
                            visible: settingsPanel.currentPage === "input"
                            width: parent.width; spacing: 15
                            property string naturalScroll: "..."
                            property string tapToClick: "..."
                            property string sensitivity: "..."
                            property string keybindsText: "loading..."
                            Process {
                                running: inputTab.visible
                                command: ["bash", "-c", "hyprctl getoption input:touchpad:natural_scroll | head -1 | awk '{print $2}'"]
                                stdout: SplitParser { onRead: function (data) { if (data) inputTab.naturalScroll = data } }
                            }
                            Process {
                                running: inputTab.visible
                                command: ["bash", "-c", "hyprctl getoption input:touchpad:tap-to-click | head -1 | awk '{print $2}'"]
                                stdout: SplitParser { onRead: function (data) { if (data) inputTab.tapToClick = data } }
                            }
                            Process {
                                running: inputTab.visible
                                command: ["bash", "-c", "hyprctl getoption input:sensitivity | head -1 | awk '{print $2}'"]
                                stdout: SplitParser { onRead: function (data) { if (data) inputTab.sensitivity = data } }
                            }
                            Process {
                                id: keybindsProc
                                command: ["cat", "@@JAZZ_DATA_DIR@@/Keybinds.md"]
                                stdout: StdioCollector { onStreamFinished: { inputTab.keybindsText = this.text } }
                            }
                            Component.onCompleted: keybindsProc.running = true
                            SectionHeader { text: "KEYBOARD & MOUSE" }
                            Text { font.family: Theme.uiFont; text: "Touchpad natural scroll: " + inputTab.naturalScroll; color: Theme.panelInk; font.pixelSize: 18 }
                            Text { font.family: Theme.uiFont; text: "Touchpad tap-to-click: " + inputTab.tapToClick; color: Theme.panelInk; font.pixelSize: 18 }
                            Text { font.family: Theme.uiFont; text: "Pointer sensitivity: " + inputTab.sensitivity; color: Theme.panelInk; font.pixelSize: 18 }
                            Text { font.family: Theme.uiFont; text: "(read-only for now - real Hyprland input values; editing lands in a later slice)"; color: Theme.textSecondary; font.pixelSize: 15 }
                            SectionHeader { text: "KEYBINDS" }
                            Text {
                                width: parent.width
                                text: inputTab.keybindsText
                                color: Theme.panelInk; font.pixelSize: 16; font.family: Theme.monoFont
                                wrapMode: Text.Wrap
                            }
                        }

                        // ===== Sound (REAL - was a one-line stub; now a real volume slider +
                        // mute + output device, backed by wpctl same as the quick-settings
                        // flyout, but this time actually reading and showing the real level) =====
                        Column {
                            id: soundTab
                            visible: settingsPanel.currentPage === "sound"
                            width: parent.width; spacing: 15
                            property bool audioAvailable: false
                            property real volumePct: 0
                            property bool muted: false
                            property string outputName: "..."

                            function refresh() {
                                soundCheckProc.running = true
                                soundVolProc.running = true
                                soundOutputProc.running = true
                            }
                            Component.onCompleted: refresh()

                            Process {
                                id: soundCheckProc
                                command: ["bash", "-c", "wpctl status 2>/dev/null | awk '/Sinks:/,/Sources:/' | grep -qE '[0-9]+\\.' && echo yes || echo no"]
                                stdout: SplitParser { onRead: function (data) { soundTab.audioAvailable = (data === "yes") } }
                            }
                            Process {
                                id: soundVolProc
                                command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
                                stdout: SplitParser {
                                    onRead: function (data) {
                                        if (!data) return
                                        soundTab.muted = data.indexOf("MUTED") >= 0
                                        var m = data.match(/([0-9.]+)/)
                                        if (m) soundTab.volumePct = Math.round(parseFloat(m[1]) * 100)
                                    }
                                }
                            }
                            Process {
                                id: soundOutputProc
                                command: ["bash", "-c", "wpctl status 2>/dev/null | awk '/Sinks:/,/Sources:/' | grep '\\*' | sed -E 's/^[^0-9]*[0-9]+\\. *//; s/ *\\[vol.*//'"]
                                stdout: SplitParser { onRead: function (data) { if (data) soundTab.outputName = data } }
                            }
                            Process {
                                id: soundSetProc
                            }
                            function setVolume(pct) {
                                soundTab.volumePct = pct
                                soundSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (pct / 100).toFixed(2)]
                                soundSetProc.running = true
                            }
                            function toggleMute() {
                                soundSetProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
                                soundSetProc.running = true
                                soundTab.muted = !soundTab.muted
                            }

                            SectionHeader { text: "SOUND" }
                            Text {
                                visible: !soundTab.audioAvailable
                                text: "Not available - no audio device detected."
                                color: Theme.textSecondary; font.pixelSize: 18
                            }
                            Column {
                                visible: soundTab.audioAvailable
                                width: parent.width; spacing: 15
                                Text { font.family: Theme.uiFont; text: "Output: " + soundTab.outputName; color: Theme.panelInk; font.pixelSize: 18 }
                                Item {
                                    width: parent.width; height: 39
                                    Text {
                                        id: volLabel
                                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                        text: "Volume"; color: Theme.panelInk; font.pixelSize: 18; width: 82
                                    }
                                    Button {
                                        id: muteBtn
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                        width: 75; height: 33
                                        variant: soundTab.muted ? "danger" : "subtle"
                                        label: soundTab.muted ? "Muted" : "Mute"
                                        onClicked: soundTab.toggleMute()
                                    }
                                    Text {
                                        id: pctLabel
                                        anchors.right: muteBtn.left; anchors.rightMargin: 15; anchors.verticalCenter: parent.verticalCenter
                                        text: soundTab.volumePct + "%"; color: Theme.textSecondary; font.pixelSize: 16
                                        width: 51; horizontalAlignment: Text.AlignRight
                                    }
                                    Rectangle {
                                        anchors.left: volLabel.right; anchors.leftMargin: 15
                                        anchors.right: pctLabel.left; anchors.rightMargin: 15
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 12; radius: 6; color: Theme.surfaceRaised
                                        Rectangle { width: parent.width * (soundTab.muted ? 0 : soundTab.volumePct) / 100; height: parent.height; radius: 6; color: WorkspaceState.activeColor() }
                                        MouseArea {
                                            anchors.fill: parent
                                            onPressed: (mouse) => soundTab.setVolume(Math.max(0, Math.min(100, Math.round(mouse.x / width * 100))))
                                            onPositionChanged: (mouse) => { if (pressed) soundTab.setVolume(Math.max(0, Math.min(100, Math.round(mouse.x / width * 100)))) }
                                        }
                                    }
                                }
                            }
                        }

                        // ===== Network (REAL - live Wi-Fi scan + connect, replaces the old
                        // "open nmtui in a terminal" launcher per Akash's explicit request) =====
                        Column {
                            id: networkTab
                            visible: settingsPanel.currentPage === "network"
                            width: parent.width; spacing: 15
                            property string wifiDevice: ""
                            property var networks: []
                            property string connectingSsid: ""
                            property string pwText: ""
                            property string statusMsg: ""
                            property bool busy: false
                            property bool radioOn: true

                            function refresh() {
                                networkTab.busy = true
                                wifiRadioProc.running = true
                                wifiDeviceProc.running = true
                                wifiListProc.running = true
                            }
                            Component.onCompleted: refresh()

                            Process {
                                id: wifiRadioProc
                                command: ["nmcli", "radio", "wifi"]
                                stdout: SplitParser { onRead: function (data) { if (data) networkTab.radioOn = (data === "enabled") } }
                            }
                            Process {
                                id: wifiRadioToggleProc
                                onExited: function (exitCode, exitStatus) { networkTab.refresh() }
                            }
                            function toggleRadio() {
                                wifiRadioToggleProc.command = ["nmcli", "radio", "wifi", networkTab.radioOn ? "off" : "on"]
                                wifiRadioToggleProc.running = true
                            }
                            Process {
                                id: wifiDeviceProc
                                command: ["bash", "-c", "nmcli -t -f DEVICE,TYPE device status | awk -F: '$2==\"wifi\"{print $1; exit}'"]
                                stdout: SplitParser { onRead: function (data) { if (data) networkTab.wifiDevice = data } }
                            }
                            Process {
                                id: wifiListProc
                                command: ["bash", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null"]
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        var lines = this.text.split("\n").filter(function (l) { return l.length > 0 })
                                        var out = []
                                        for (var i = 0; i < lines.length; i++) {
                                            var parts = lines[i].split(":")
                                            var ssid = parts[1]
                                            if (!ssid) continue
                                            out.push({
                                                connected: parts[0] === "*",
                                                ssid: ssid,
                                                signal: parseInt(parts[2]) || 0,
                                                secured: !!(parts[3] && parts[3] !== "--")
                                            })
                                        }
                                        out.sort(function (a, b) { if (a.connected !== b.connected) return a.connected ? -1 : 1; return b.signal - a.signal })
                                        networkTab.networks = out
                                        networkTab.busy = false
                                    }
                                }
                            }
                            Process {
                                id: connectProc
                                property string outText: ""
                                stdout: StdioCollector { onStreamFinished: connectProc.outText += this.text }
                                stderr: StdioCollector { onStreamFinished: connectProc.outText += this.text }
                                onExited: function (exitCode, exitStatus) {
                                    networkTab.statusMsg = exitCode === 0 ? "Connected." : (connectProc.outText.trim() || "Connection failed.")
                                    networkTab.connectingSsid = ""
                                    networkTab.pwText = ""
                                    networkTab.refresh()
                                }
                            }
                            function connectTo(ssid, password) {
                                connectProc.outText = ""
                                networkTab.statusMsg = ""
                                networkTab.busy = true
                                connectProc.command = password.length > 0
                                    ? ["nmcli", "device", "wifi", "connect", ssid, "password", password]
                                    : ["nmcli", "device", "wifi", "connect", ssid]
                                connectProc.running = true
                            }
                            Process {
                                id: disconnectProc
                                onExited: function (exitCode, exitStatus) { networkTab.refresh() }
                            }
                            function disconnectWifi() {
                                if (!networkTab.wifiDevice) return
                                networkTab.busy = true
                                disconnectProc.command = ["nmcli", "device", "disconnect", networkTab.wifiDevice]
                                disconnectProc.running = true
                            }
                            Process {
                                id: forgetProc
                                onExited: function (exitCode, exitStatus) { networkTab.refresh() }
                            }
                            function forgetNetwork(ssid) {
                                networkTab.busy = true
                                forgetProc.command = ["nmcli", "connection", "delete", ssid]
                                forgetProc.running = true
                            }

                            SectionHeader { text: "NETWORK" }
                            Row {
                                spacing: 15
                                Text { font.family: Theme.uiFont; anchors.verticalCenter: parent.verticalCenter; text: networkTab.radioOn ? "Wi-Fi: On" : "Wi-Fi: Off"; color: Theme.panelInk; font.pixelSize: 20 }
                                Toggle {
                                    checked: networkTab.radioOn
                                    onToggled: networkTab.toggleRadio()
                                }
                            }
                            Row {
                                visible: networkTab.radioOn
                                spacing: 15
                                Button {
                                    width: 105; height: 33
                                    variant: "subtle"
                                    enabled: !networkTab.busy
                                    label: networkTab.busy ? "..." : "Refresh"
                                    onClicked: networkTab.refresh()
                                }
                                Text {
                                    visible: networkTab.statusMsg.length > 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: networkTab.statusMsg; color: Theme.textSecondary; font.pixelSize: 16
                                }
                            }
                            Column {
                                visible: networkTab.radioOn
                                width: parent.width; spacing: 6
                                Text { font.family: Theme.uiFont; visible: networkTab.networks.length === 0; text: networkTab.busy ? "Scanning..." : "No networks found."; color: Theme.textSecondary; font.pixelSize: 16 }
                                Repeater {
                                    model: networkTab.networks
                                    delegate: Column {
                                        width: parent.width
                                        property var netData: modelData
                                        spacing: 6
                                        Rectangle {
                                            width: parent.width; height: 51; radius: 9
                                            color: netData.connected ? Theme.surfaceRaised : "#00000000"
                                            Row {
                                                anchors.fill: parent; anchors.margins: 9; spacing: 12
                                                Item {
                                                    width: 27; height: 33
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Repeater {
                                                        model: 4
                                                        delegate: Rectangle {
                                                            width: 4; height: 5 + index * 3; x: index * 4; y: 14 - height
                                                            color: netData.signal >= (index + 1) * 25 ? WorkspaceState.activeColor() : Theme.panelInk
                                                            opacity: netData.signal >= (index + 1) * 25 ? 1 : 0.25
                                                        }
                                                    }
                                                }
                                                Row {
                                                    width: 345; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                                                    Image {
                                                        visible: netData.secured
                                                        source: Theme.darkMode ? "icons/symbols/lock-ondark.svg" : "icons/symbols/lock-onlight.svg"
                                                        width: 14; height: 14
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                    Text {
                                                        width: netData.secured ? 327 : 345
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: netData.ssid
                                                        color: Theme.panelInk; font.pixelSize: 18; elide: Text.ElideRight
                                                    }
                                                }
                                                Text {
                                                    visible: netData.connected
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "Connected"; color: WorkspaceState.activeColor(); font.pixelSize: 16
                                                }
                                                Button {
                                                    visible: !netData.connected
                                                    width: 105; height: 33
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    label: "Connect"
                                                    onClicked: {
                                                        if (netData.secured) {
                                                            networkTab.connectingSsid = (networkTab.connectingSsid === netData.ssid) ? "" : netData.ssid
                                                            networkTab.pwText = ""
                                                        } else {
                                                            networkTab.connectTo(netData.ssid, "")
                                                        }
                                                    }
                                                }
                                                Button {
                                                    visible: netData.connected
                                                    width: 120; height: 33
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    variant: "danger"
                                                    label: "Disconnect"
                                                    onClicked: networkTab.disconnectWifi()
                                                }
                                                Button {
                                                    visible: netData.connected
                                                    width: 90; height: 33
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    variant: "outlineDanger"
                                                    label: "Forget"
                                                    onClicked: networkTab.forgetNetwork(netData.ssid)
                                                }
                                            }
                                        }
                                        Rectangle {
                                            visible: networkTab.connectingSsid === netData.ssid
                                            width: parent.width; height: 51; radius: 9; color: Theme.surfaceRaised
                                            Row {
                                                anchors.fill: parent; anchors.margins: 9; spacing: 12
                                                Rectangle {
                                                    width: 270; height: 33; radius: 6; color: Theme.panel
                                                    border.color: Theme.panelInk; border.width: 1
                                                    TextInput {
                                                        anchors.fill: parent; anchors.margins: 6
                                                        color: Theme.panelInk; font.pixelSize: 18
                                                        echoMode: TextInput.Password
                                                        clip: true
                                                        focus: networkTab.connectingSsid === netData.ssid
                                                        onTextChanged: networkTab.pwText = text
                                                        Keys.onReturnPressed: networkTab.connectTo(netData.ssid, networkTab.pwText)
                                                    }
                                                }
                                                Button {
                                                    width: 90; height: 33
                                                    label: "Connect"
                                                    onClicked: networkTab.connectTo(netData.ssid, networkTab.pwText)
                                                }
                                                Button {
                                                    width: 75; height: 33
                                                    variant: "neutral"
                                                    label: "Cancel"
                                                    onClicked: { networkTab.connectingSsid = ""; networkTab.pwText = "" }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ===== Bluetooth (REAL - paired/nearby device lists + connect/
                        // disconnect/pair/remove, replaces the old "open bluetoothctl in a
                        // terminal" launcher per Akash's explicit request) =====
                        Column {
                            id: btTab
                            visible: settingsPanel.currentPage === "bluetooth"
                            width: parent.width; spacing: 15
                            property bool powered: false
                            property var paired: []
                            property var nearby: []
                            property bool scanning: false

                            function refresh() { btPowerProc.running = true; btPairedProc.running = true }
                            Component.onCompleted: refresh()

                            Process {
                                id: btPowerProc
                                command: ["bash", "-c", "bluetoothctl show | grep -i Powered | awk '{print $2}'"]
                                stdout: SplitParser { onRead: function (data) { btTab.powered = (data === "yes") } }
                            }
                            Process {
                                id: btPairedProc
                                command: ["bash", "-c", "bluetoothctl devices Paired"]
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        var lines = this.text.split("\n").filter(function (l) { return l.indexOf("Device ") === 0 })
                                        var list = []
                                        for (var i = 0; i < lines.length; i++) {
                                            var m = lines[i].match(/^Device (\S+) (.*)$/)
                                            if (m) list.push({ mac: m[1], name: m[2], connected: false })
                                        }
                                        btTab.paired = list
                                        btConnectedProc.running = true
                                    }
                                }
                            }
                            Process {
                                id: btConnectedProc
                                command: ["bash", "-c", "bluetoothctl devices Connected"]
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        var macs = []
                                        var lines = this.text.split("\n")
                                        for (var i = 0; i < lines.length; i++) {
                                            var m = lines[i].match(/^Device (\S+)/)
                                            if (m) macs.push(m[1])
                                        }
                                        var updated = btTab.paired.map(function (d) { d.connected = macs.indexOf(d.mac) >= 0; return d })
                                        btTab.paired = updated
                                    }
                                }
                            }
                            Process {
                                id: btScanProc
                                command: ["bash", "-c", "bluetoothctl --timeout 6 scan on"]
                                onExited: function (exitCode, exitStatus) { btTab.scanning = false; btNearbyProc.running = true }
                            }
                            Process {
                                id: btNearbyProc
                                command: ["bash", "-c", "bluetoothctl devices"]
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        var lines = this.text.split("\n").filter(function (l) { return l.indexOf("Device ") === 0 })
                                        var pairedMacs = btTab.paired.map(function (d) { return d.mac })
                                        var list = []
                                        for (var i = 0; i < lines.length; i++) {
                                            var m = lines[i].match(/^Device (\S+) (.*)$/)
                                            if (m && pairedMacs.indexOf(m[1]) < 0) list.push({ mac: m[1], name: m[2] })
                                        }
                                        btTab.nearby = list
                                    }
                                }
                            }
                            function startScan() { btTab.scanning = true; btTab.nearby = []; btScanProc.running = true }
                            Process {
                                id: btPowerToggleProc
                                onExited: function (exitCode, exitStatus) { btTab.refresh() }
                            }
                            function togglePower() {
                                btPowerToggleProc.command = ["bluetoothctl", "power", btTab.powered ? "off" : "on"]
                                btPowerToggleProc.running = true
                            }
                            Process {
                                id: btActionProc
                                onExited: function (exitCode, exitStatus) { btTab.refresh() }
                            }
                            function btConnect(mac) { btActionProc.command = ["bluetoothctl", "connect", mac]; btActionProc.running = true }
                            function btDisconnect(mac) { btActionProc.command = ["bluetoothctl", "disconnect", mac]; btActionProc.running = true }
                            function btRemove(mac) { btActionProc.command = ["bluetoothctl", "remove", mac]; btActionProc.running = true }
                            function btPairAndConnect(mac) {
                                btActionProc.command = ["bash", "-c", "bluetoothctl pair " + mac + "; bluetoothctl trust " + mac + "; bluetoothctl connect " + mac]
                                btActionProc.running = true
                            }

                            SectionHeader { text: "BLUETOOTH" }
                            Row {
                                spacing: 15
                                Text { font.family: Theme.uiFont; anchors.verticalCenter: parent.verticalCenter; text: btTab.powered ? "Bluetooth: On" : "Bluetooth: Off"; color: Theme.panelInk; font.pixelSize: 20 }
                                Toggle {
                                    checked: btTab.powered
                                    onToggled: btTab.togglePower()
                                }
                            }
                            SectionHeader { text: "PAIRED DEVICES" }
                            Column {
                                width: parent.width; spacing: 6
                                Text { font.family: Theme.uiFont; visible: btTab.paired.length === 0; text: "No paired devices yet."; color: Theme.textSecondary; font.pixelSize: 16 }
                                Repeater {
                                    model: btTab.paired
                                    delegate: Rectangle {
                                        property var devData: modelData
                                        width: parent.width; height: 48; radius: 9; color: Theme.surfaceRaised
                                        Row {
                                            anchors.fill: parent; anchors.margins: 9; spacing: 12
                                            Text { font.family: Theme.uiFont; width: 300; anchors.verticalCenter: parent.verticalCenter; text: devData.name; color: Theme.panelInk; font.pixelSize: 18; elide: Text.ElideRight }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: devData.connected ? "Connected" : "Paired"
                                                color: devData.connected ? WorkspaceState.activeColor() : Theme.textSecondary; font.pixelSize: 16
                                            }
                                            Button {
                                                width: 120; height: 33
                                                variant: devData.connected ? "danger" : "primary"
                                                label: devData.connected ? "Disconnect" : "Connect"
                                                onClicked: devData.connected ? btTab.btDisconnect(devData.mac) : btTab.btConnect(devData.mac)
                                            }
                                            Button {
                                                width: 90; height: 33
                                                variant: "outlineDanger"
                                                label: "Remove"
                                                onClicked: btTab.btRemove(devData.mac)
                                            }
                                        }
                                    }
                                }
                            }
                            Row {
                                spacing: 12
                                SectionHeader { anchors.verticalCenter: parent.verticalCenter; text: "NEARBY" }
                                Button {
                                    width: 195; height: 33
                                    variant: "subtle"
                                    enabled: !btTab.scanning
                                    label: btTab.scanning ? "Scanning..." : "Scan (6s)"
                                    onClicked: btTab.startScan()
                                }
                            }
                            Column {
                                width: parent.width; spacing: 6
                                Text { font.family: Theme.uiFont; visible: !btTab.scanning && btTab.nearby.length === 0; text: "No nearby devices found yet - tap Scan."; color: Theme.textSecondary; font.pixelSize: 16 }
                                Repeater {
                                    model: btTab.nearby
                                    delegate: Rectangle {
                                        property var devData: modelData
                                        width: parent.width; height: 48; radius: 9; color: "#00000000"
                                        border.color: Theme.panelInk; border.width: 1; opacity: 0.7
                                        Row {
                                            anchors.fill: parent; anchors.margins: 9; spacing: 12
                                            Text { font.family: Theme.uiFont; width: 390; anchors.verticalCenter: parent.verticalCenter; text: devData.name; color: Theme.panelInk; font.pixelSize: 18; elide: Text.ElideRight }
                                            Button {
                                                width: 90; height: 33
                                                label: "Pair"
                                                onClicked: btTab.btPairAndConnect(devData.mac)
                                            }
                                        }
                                    }
                                }
                            }
                            Text {
                                text: "Some devices need a physical confirmation button pressed on the device itself to finish pairing."
                                color: Theme.textSecondary; font.pixelSize: 15; wrapMode: Text.Wrap; width: parent.width
                            }
                        }

                        // ===== Applications (REAL - Task 22's real app catalog) =====
                        Column {
                            id: appsTab
                            visible: settingsPanel.currentPage === "apps"
                            width: parent.width; spacing: 15
                            property var apps: []
                            Process {
                                id: appsProc
                                command: ["python3", "@@JAZZ_DATA_DIR@@/scan-apps.py"]
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        try { appsTab.apps = JSON.parse(this.text) } catch (e) { appsTab.apps = [] }
                                    }
                                }
                            }
                            // Real bug found live, 17 Sept 2026 (Akash: installed
                            // Nibbles via Bazaar, couldn't find it anywhere): this
                            // scan only ever ran once, at Quickshell startup -
                            // Component.onCompleted fires exactly once for the
                            // lifetime of this Loader (it's never re-created), so
                            // any app installed after Quickshell launched was
                            // invisible until the next full Quickshell restart.
                            // Re-scanning on every visit to this page (like every
                            // other live-data tab already does, e.g. Bluetooth's
                            // device poll) keeps it current with zero added
                            // background cost while the page is closed.
                            onVisibleChanged: if (visible) appsProc.running = true
                            Component.onCompleted: appsProc.running = true
                            SectionHeader { text: "APPLICATIONS" }
                            Text { font.family: Theme.uiFont; text: appsTab.apps.length + " installed applications (same catalog the dock/launcher use)"; color: Theme.textSecondary; font.pixelSize: 16 }
                            Column {
                                width: parent.width; spacing: 3
                                Repeater {
                                    model: appsTab.apps
                                    delegate: Rectangle {
                                        width: parent.width; height: 39; radius: 8
                                        color: appRowMouse.containsMouse ? Theme.surfaceRaised : "#00000000"
                                        Text {
                                            anchors.left: parent.left; anchors.leftMargin: 9; anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.name; color: Theme.panelInk; font.pixelSize: 18
                                        }
                                        MouseArea {
                                            id: appRowMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: Quickshell.execDetached(["bash", "-c", modelData.exec])
                                        }
                                    }
                                }
                            }
                        }

                        // ===== AI (REAL - Track C, Ollama) =====
                        Column {
                            id: aiTab
                            visible: settingsPanel.currentPage === "ai"
                            width: parent.width; spacing: 15
                            property var installedModels: []
                            property var runningModels: []
                            Process {
                                id: tagsProc
                                command: ["bash", "-c", "curl -s http://localhost:11434/api/tags"]
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        try { aiTab.installedModels = JSON.parse(this.text).models || [] } catch (e) { aiTab.installedModels = [] }
                                    }
                                }
                            }
                            Process {
                                id: psProc
                                command: ["bash", "-c", "curl -s http://localhost:11434/api/ps"]
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        try { aiTab.runningModels = JSON.parse(this.text).models || [] } catch (e) { aiTab.runningModels = [] }
                                    }
                                }
                            }
                            Component.onCompleted: { tagsProc.running = true; psProc.running = true }
                            SectionHeader { text: "AI" }
                            Text { font.family: Theme.uiFont; text: "Local runtime: Ollama"; color: Theme.panelInk; font.pixelSize: 20 }
                            Text {
                                text: aiTab.runningModels.length > 0
                                    ? ("Running in memory: " + aiTab.runningModels[0].name + " (" + aiTab.runningModels[0].size_vram + " bytes VRAM)")
                                    : "Nothing loaded in memory right now - Ollama unloads idle models automatically after a few minutes. Installed models (below) reload in seconds the next time you use them."
                                color: Theme.textSecondary; font.pixelSize: 18; wrapMode: Text.Wrap; width: parent.width
                            }
                            SectionHeader { text: "INSTALLED MODELS" }
                            Column {
                                width: parent.width; spacing: 6
                                Repeater {
                                    model: aiTab.installedModels
                                    delegate: Rectangle {
                                        width: parent.width; height: 66; radius: 9; color: Theme.surfaceRaised
                                        Column {
                                            anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                                            spacing: 3
                                            Text { font.family: Theme.uiFont; text: modelData.name; color: Theme.panelInk; font.pixelSize: 18 }
                                            Text {
                                                text: modelData.details.parameter_size + " params, " + modelData.details.quantization_level + ", " + modelData.details.context_length + " ctx"
                                                color: Theme.textSecondary; font.pixelSize: 15
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ===== Privacy (REAL - clears real, on-disk activity traces) =====
                        Column {
                            id: privacyTab
                            visible: settingsPanel.currentPage === "privacy"
                            width: parent.width; spacing: 15
                            property int clipboardCount: 0
                            property int recentFilesCount: 0
                            property int shellHistoryCount: 0
                            property string statusMsg: ""

                            function refresh() {
                                clipboardCountProc.running = true
                                recentFilesProc.running = true
                                shellHistoryProc.running = true
                            }
                            Component.onCompleted: refresh()

                            Process {
                                id: clipboardCountProc
                                command: ["bash", "-c", "cliphist list | wc -l"]
                                stdout: SplitParser { onRead: function (data) { if (data) privacyTab.clipboardCount = parseInt(data) || 0 } }
                            }
                            Process {
                                id: recentFilesProc
                                command: ["bash", "-c", "grep -c '<bookmark' ~/.local/share/recently-used.xbel 2>/dev/null || echo 0"]
                                stdout: SplitParser { onRead: function (data) { if (data) privacyTab.recentFilesCount = parseInt(data) || 0 } }
                            }
                            Process {
                                id: shellHistoryProc
                                command: ["bash", "-c", "wc -l < ~/.bash_history 2>/dev/null || echo 0"]
                                stdout: SplitParser { onRead: function (data) { if (data) privacyTab.shellHistoryCount = parseInt(data) || 0 } }
                            }
                            Process {
                                id: privacyActionProc
                                onExited: function (exitCode, exitStatus) { privacyTab.refresh() }
                            }
                            function clearClipboard() { privacyTab.statusMsg = "Clipboard history cleared."; privacyActionProc.command = ["cliphist", "wipe"]; privacyActionProc.running = true }
                            function clearRecentFiles() { privacyTab.statusMsg = "Recent files list cleared."; privacyActionProc.command = ["bash", "-c", "rm -f ~/.local/share/recently-used.xbel"]; privacyActionProc.running = true }
                            function clearShellHistory() { privacyTab.statusMsg = "Command history cleared."; privacyActionProc.command = ["bash", "-c", "cat /dev/null > ~/.bash_history"]; privacyActionProc.running = true }

                            SectionHeader { text: "PRIVACY" }
                            Text {
                                width: parent.width; wrapMode: Text.Wrap
                                text: "JAZZ sends no telemetry. All AI processing runs locally via Ollama - nothing about what you type, ask, or run leaves this machine unless you explicitly configure a cloud service."
                                color: Theme.panelInk; font.pixelSize: 18
                            }
                            Text {
                                visible: privacyTab.statusMsg.length > 0
                                text: privacyTab.statusMsg; color: Theme.textSecondary; font.pixelSize: 16
                            }
                            SectionHeader { text: "ACTIVITY TRACES" }
                            Row {
                                width: parent.width; spacing: 15
                                Text { font.family: Theme.uiFont; width: 390; anchors.verticalCenter: parent.verticalCenter; text: "Clipboard history (" + privacyTab.clipboardCount + " items)"; color: Theme.panelInk; font.pixelSize: 18 }
                                Button {
                                    width: 90; height: 33
                                    variant: "danger"
                                    label: "Clear"
                                    onClicked: privacyTab.clearClipboard()
                                }
                            }
                            Row {
                                width: parent.width; spacing: 15
                                Text { font.family: Theme.uiFont; width: 390; anchors.verticalCenter: parent.verticalCenter; text: "Recent files list (" + privacyTab.recentFilesCount + " entries)"; color: Theme.panelInk; font.pixelSize: 18 }
                                Button {
                                    width: 90; height: 33
                                    variant: "danger"
                                    label: "Clear"
                                    onClicked: privacyTab.clearRecentFiles()
                                }
                            }
                            Row {
                                width: parent.width; spacing: 15
                                Text { font.family: Theme.uiFont; width: 390; anchors.verticalCenter: parent.verticalCenter; text: "Terminal command history (" + privacyTab.shellHistoryCount + " lines)"; color: Theme.panelInk; font.pixelSize: 18 }
                                Button {
                                    width: 90; height: 33
                                    variant: "danger"
                                    label: "Clear"
                                    onClicked: privacyTab.clearShellHistory()
                                }
                            }
                            Text {
                                width: parent.width; wrapMode: Text.Wrap
                                text: "Clearing command history resets the saved file - any terminal windows already open keep their own history in memory until closed."
                                color: Theme.textSecondary; font.pixelSize: 15
                            }
                            SectionHeader { text: "MORE" }
                            Text {
                                width: parent.width; wrapMode: Text.Wrap
                                text: "AI action history and permissions live under Agents. Firewall, SSH, and disk-encryption status live under Security."
                                color: Theme.textSecondary; font.pixelSize: 16
                            }
                        }

                        // ===== Agents (REAL - Task 30) =====
                        Column {
                            id: agentsTab
                            visible: settingsPanel.currentPage === "agents"
                            width: parent.width; spacing: 18
                            property var policyRows: []
                            property string ledgerText: "loading..."

                            Process {
                                id: policyProc
                                command: ["jazz-agent-action", "policy", "list"]
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        try { agentsTab.policyRows = JSON.parse(this.text) } catch (e) { agentsTab.policyRows = [] }
                                    }
                                }
                            }
                            Process {
                                id: ledgerProc
                                command: ["jazz-agent-action", "ledger", "--limit", "10"]
                                stdout: StdioCollector {
                                    onStreamFinished: { agentsTab.ledgerText = this.text.length > 0 ? this.text : "No agent actions logged yet." }
                                }
                            }
                            function refresh() { policyProc.running = true; ledgerProc.running = true }
                            Component.onCompleted: refresh()

                            SectionHeader { text: "AGENT PERMISSIONS" }
                            Column {
                                width: parent.width; spacing: 6
                                Repeater {
                                    model: agentsTab.policyRows
                                    delegate: Rectangle {
                                        id: policyRow
                                        property var rowData: modelData
                                        width: parent.width; height: 45; radius: 9; color: Theme.surfaceRaised
                                        Row {
                                            anchors.fill: parent; anchors.margins: 9; spacing: 12
                                            Text {
                                                width: 240; anchors.verticalCenter: parent.verticalCenter
                                                text: policyRow.rowData.action_type; color: Theme.panelInk; font.pixelSize: 18
                                            }
                                            Item {
                                                id: tierLight
                                                width: 75; height: parent.height
                                                anchors.verticalCenter: parent.verticalCenter
                                                readonly property color lightColor: policyRow.rowData.tier === "green" ? Theme.tierGreen
                                                    : (policyRow.rowData.tier === "yellow" ? Theme.tierYellow : Theme.tierRed)
                                                // Real ask, 17 Sept 2026 (Akash: tier badges should be lights, not
                                                // bracketed text, and must use real traffic-light colors, not the
                                                // workspace palette - Lab/Arena/Range are all too close to each
                                                // other to read as a real tier at a glance). A soft glow halo
                                                // (translucent outer ring) behind a solid dot reads as a genuine
                                                // indicator light rather than a flat colored circle.
                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 26; height: 26; radius: 13
                                                    color: tierLight.lightColor; opacity: 0.22
                                                }
                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 14; height: 14; radius: 7
                                                    color: tierLight.lightColor
                                                }
                                            }
                                            Row {
                                                spacing: 6
                                                visible: policyRow.rowData.overridable
                                                Repeater {
                                                    model: ["allow", "ask", "deny"]
                                                    delegate: Button {
                                                        property string optionValue: modelData
                                                        width: 69; height: 30
                                                        variant: optionValue === policyRow.rowData.policy ? "primary" : "flat"
                                                        label: optionValue
                                                        onClicked: {
                                                            Quickshell.execDetached(["jazz-agent-action", "policy", "set", policyRow.rowData.action_type, optionValue])
                                                            agentsTab.refresh()
                                                        }
                                                    }
                                                }
                                            }
                                            Text {
                                                visible: !policyRow.rowData.overridable
                                                text: "always ask"; color: Theme.textSecondary; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                    }
                                }
                            }
                            SectionHeader { text: "RECENT ACTIVITY" }
                            Text {
                                width: parent.width
                                text: agentsTab.ledgerText
                                color: Theme.panelInk; font.pixelSize: 16; font.family: Theme.monoFont
                                wrapMode: Text.Wrap
                            }
                        }

                        // ===== Storage (REAL - Track A) =====
                        Column {
                            id: storageTab
                            visible: settingsPanel.currentPage === "storage"
                            width: parent.width; spacing: 15
                            property string usedLine: "loading..."
                            Process {
                                running: storageTab.visible
                                command: ["bash", "-c", "df -h / | tail -1 | awk '{print $2\" total, \"$3\" used, \"$4\" available (\"$5\" used)\"}'"]
                                stdout: SplitParser { onRead: function (data) { if (data) storageTab.usedLine = data } }
                            }
                            SectionHeader { text: "STORAGE" }
                            Text { font.family: Theme.uiFont; text: storageTab.usedLine; color: Theme.panelInk; font.pixelSize: 20 }
                            Text { font.family: Theme.uiFont; text: "Btrfs root, Snapper-protected (Track A)."; color: Theme.textSecondary; font.pixelSize: 16 }
                            Button {
                                width: 270; height: 39
                                fontSize: 11
                                label: "Manage snapshots"
                                onClicked: Quickshell.execDetached(["kitty", "-e", "sudo", "snapper", "-c", "root", "list"])
                            }
                        }

                        // ===== Battery & Power (REAL) =====
                        Column {
                            id: powerTab
                            visible: settingsPanel.currentPage === "power"
                            width: parent.width; spacing: 15
                            property int pct: -1
                            property string status: "unknown"
                            property real watts: -1
                            Process {
                                running: powerTab.visible
                                command: ["bash", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1"]
                                stdout: SplitParser { onRead: function (data) { if (data) powerTab.pct = parseInt(data) } }
                            }
                            Process {
                                running: powerTab.visible
                                command: ["bash", "-c", "cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1"]
                                stdout: SplitParser { onRead: function (data) { if (data) powerTab.status = data } }
                            }
                            Process {
                                running: powerTab.visible
                                command: ["bash", "-c", "cat /sys/class/power_supply/BAT*/power_now 2>/dev/null | head -1"]
                                stdout: SplitParser { onRead: function (data) { if (data) powerTab.watts = parseInt(data) / 1000000.0 } }
                            }
                            SectionHeader { text: "BATTERY & POWER" }
                            Text { font.family: Theme.uiFont; text: powerTab.pct >= 0 ? (powerTab.pct + "% - " + powerTab.status) : "reading..."; color: Theme.panelInk; font.pixelSize: 24 }
                            Text { font.family: Theme.uiFont; text: powerTab.watts >= 0 ? ("Power draw: " + powerTab.watts.toFixed(1) + " W") : ""; color: Theme.textSecondary; font.pixelSize: 18 }
                        }

                        // ===== Security (REAL) =====
                        Column {
                            id: securityTab
                            visible: settingsPanel.currentPage === "security"
                            width: parent.width; spacing: 12
                            property string firewallStatus: "checking..."
                            property int firewallRules: 0
                            property string sshStatus: "checking..."
                            property string secureBoot: "checking..."
                            property string diskEncryption: "checking..."
                            Process {
                                running: securityTab.visible
                                command: ["bash", "-c", "sudo -n ufw status verbose 2>/dev/null | head -1 | sed 's/Status: //'"]
                                stdout: SplitParser { onRead: function (data) { if (data) securityTab.firewallStatus = data } }
                            }
                            Process {
                                running: securityTab.visible
                                command: ["bash", "-c", "sudo -n ufw status verbose 2>/dev/null | grep -c ALLOW"]
                                stdout: SplitParser { onRead: function (data) { if (data) securityTab.firewallRules = parseInt(data) } }
                            }
                            Process {
                                running: securityTab.visible
                                command: ["systemctl", "is-active", "sshd"]
                                stdout: SplitParser { onRead: function (data) { if (data) securityTab.sshStatus = data } }
                            }
                            Process {
                                running: securityTab.visible
                                command: ["bash", "-c", "bootctl status 2>/dev/null | grep -i 'Secure Boot' | head -1 | sed 's/.*Secure Boot: //'"]
                                stdout: SplitParser { onRead: function (data) { if (data) securityTab.secureBoot = data } }
                            }
                            Process {
                                running: securityTab.visible
                                command: ["bash", "-c", "lsblk -f -no FSTYPE /dev/nvme0n1p5 2>/dev/null | grep -q crypto_LUKS && echo Enabled || echo Off"]
                                stdout: SplitParser { onRead: function (data) { if (data) securityTab.diskEncryption = data } }
                            }
                            SectionHeader { text: "SECURITY" }
                            Text { font.family: Theme.uiFont; text: "Firewall: " + securityTab.firewallStatus + " (" + securityTab.firewallRules + " allow rules)"; color: Theme.panelInk; font.pixelSize: 20 }
                            Text { font.family: Theme.uiFont; text: "SSH: " + securityTab.sshStatus; color: Theme.panelInk; font.pixelSize: 20 }
                            Text { font.family: Theme.uiFont; text: "Secure Boot: " + securityTab.secureBoot; color: Theme.panelInk; font.pixelSize: 20 }
                            Text { font.family: Theme.uiFont; text: "Disk Encryption: " + securityTab.diskEncryption; color: Theme.panelInk; font.pixelSize: 20 }
                        }

                        // ===== Users (REAL, Task 32) =====
                        // Privileged actions (add/remove/admin-toggle) go through
                        // usersTab.requestSudo() - a small in-app password popup
                        // (declared as an overlay at the end of settingsBox) that runs
                        // `sudo -S <script> ...` and feeds the password via Quickshell's
                        // own Process.stdinEnabled/write() API. First version opened a
                        // real `kitty --hold -e sudo <script>` terminal instead (same
                        // idea, proven in Task 16b/30) - Akash's live feedback was that
                        // it opened behind the Settings panel and was confusing, so this
                        // was replaced with the in-app popup, same underlying sudo/PAM
                        // mechanism either way. pkexec/polkit was tried before either of
                        // these and abandoned: both polkit-kde-agent and
                        // lxqt-policykit-agent register with polkitd but never render a
                        // visible dialog under plain Hyprland, leaving pkexec hanging -
                        // confirmed live, see tasks/todo.md Task 32. Self-service
                        // password change needs no elevation at all (passwd is setuid),
                        // so it runs jazz-user-passwd directly via its own Process.
                        Column {
                            id: usersTab
                            visible: settingsPanel.currentPage === "users"
                            width: parent.width; spacing: 15
                            property var userList: []
                            property string removeTarget: ""
                            property string switchTarget: ""
                            property string pwStatus: ""
                            property string addStatus: ""
                            property string ownUsername: ""
                            readonly property int adminCount: userList.filter(function (u) { return u.admin }).length
                            // Real backend already refuses these for a non-admin viewer -
                            // sudo just rejects anyone not in wheel, correct password or not
                            // (confirmed live, 12 Sept 2026, testing as a non-admin account).
                            // Hiding the buttons too is pure UX - a non-admin was seeing a
                            // "Remove"/"Revoke admin" that would always fail, not a security
                            // gap on its own.
                            readonly property bool viewerIsAdmin: userList.some(function (u) { return u.username === usersTab.ownUsername && u.admin })
                            property var pendingCommand: null
                            property string pendingDescription: ""
                            property string sudoStatus: ""
                            property bool idleEnabled: true
                            property int idleMinutes: 10
                            property string idleStatus: ""
                            property string autoLoginUser: ""
                            property bool hasAvatar: false
                            property string avatarPath: ""
                            property real avatarCacheBust: 0
                            property string avatarStatus: ""

                            function refresh() {
                                userListProc.running = true
                                autoLoginProc.running = true
                            }
                            Process {
                                id: autoLoginProc
                                // /etc/ly/config.ini is world-readable - no sudo needed just to
                                // show which account (if any) currently skips the login prompt.
                                command: ["bash", "-c", "grep '^auto_login_user' /etc/ly/config.ini | sed 's/auto_login_user = //'"]
                                stdout: SplitParser { onRead: function (data) { usersTab.autoLoginUser = (data && data !== "null") ? data : "" } }
                            }

                            // Real, root-requiring actions (add/remove/admin-toggle) go
                            // through this - a small in-app password prompt using
                            // `sudo -S`, rather than opening a terminal (Akash's feedback:
                            // a kitty window popping up behind the Settings panel was
                            // confusing). Same real sudo/PAM stack, just a native-feeling
                            // prompt instead - confirmed Quickshell's Process type really
                            // supports stdin (stdinEnabled + write()), not guessed.
                            function requestSudo(command, description) {
                                usersTab.pendingCommand = command
                                usersTab.pendingDescription = description
                                usersTab.sudoStatus = ""
                            }
                            Process {
                                id: sudoActionProc
                                stdinEnabled: true
                                property string outText: ""
                                property string pw: ""
                                onStarted: sudoActionProc.write(sudoActionProc.pw + "\n")
                                stdout: StdioCollector { onStreamFinished: sudoActionProc.outText += this.text }
                                stderr: StdioCollector { onStreamFinished: sudoActionProc.outText += this.text }
                                onExited: function (exitCode, exitStatus) {
                                    sudoActionProc.pw = ""
                                    if (exitCode === 0) {
                                        usersTab.sudoStatus = "Done."
                                        usersTab.refresh()
                                    } else {
                                        // sudo's own real error text (wrong password, etc.) -
                                        // strip its "[sudo] password for X:" echo, keep the rest.
                                        var msg = sudoActionProc.outText.replace(/^\[sudo\][^\n]*\n?/, "").trim()
                                        usersTab.sudoStatus = msg || "Failed (exit " + exitCode + ")."
                                    }
                                }
                            }
                            function runPendingCommand(password) {
                                sudoActionProc.outText = ""
                                sudoActionProc.pw = password
                                sudoActionProc.command = ["sudo", "-S"].concat(usersTab.pendingCommand)
                                sudoActionProc.running = true
                                usersTab.pendingCommand = null
                                usersTab.pendingDescription = ""
                            }
                            Process {
                                command: ["whoami"]
                                running: true
                                stdout: SplitParser { onRead: function (data) { if (data) usersTab.ownUsername = data } }
                            }
                            Process {
                                id: userListProc
                                command: ["bash", "-c", "getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 && ($7 ~ /bash|zsh|fish|sh$/) {print $1\":\"$5}' | while IFS=: read -r u n; do w=$(groups \"$u\" | grep -qw wheel && echo yes || echo no); echo \"$u:$n:$w\"; done"]
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        var lines = this.text.split("\n").filter(function (s) { return s.length > 0 })
                                        usersTab.userList = lines.map(function (l) {
                                            var parts = l.split(":")
                                            return { username: parts[0], displayName: parts[1] || "", admin: parts[2] === "yes" }
                                        })
                                        // Pre-fill the display-name field from the just-refreshed
                                        // list, but never clobber text the user is actively editing.
                                        if (!displayNameField.activeFocus && displayNameField.text === "") {
                                            var mine = usersTab.userList.find(function (u) { return u.username === usersTab.ownUsername })
                                            if (mine) displayNameField.text = mine.displayName
                                        }
                                    }
                                }
                            }
                            Component.onCompleted: { refresh(); loadIdleStatus(); loadAvatarStatus() }

                            Process {
                                id: passwdProc
                                property string outText: ""
                                stdout: StdioCollector { onStreamFinished: passwdProc.outText += this.text }
                                stderr: StdioCollector { onStreamFinished: passwdProc.outText += this.text }
                                onExited: function (exitCode, exitStatus) {
                                    usersTab.pwStatus = exitCode === 0 ? "Password changed successfully." : (passwdProc.outText.trim() || "Password change failed.")
                                    if (exitCode === 0) { currentPwField.text = ""; newPwField.text = ""; confirmPwField.text = "" }
                                }
                            }

                            SectionHeader { text: "USERS" }
                            Text {
                                font.family: Theme.uiFont; color: Theme.textSecondary; font.pixelSize: 14
                                text: "Everyone with a real login on this machine. \"admin\" means they can install software and change system settings. \"Switch to this user\" logs you out and returns to the login screen."
                                wrapMode: Text.WordWrap; width: usersTab.width
                            }
                            Repeater {
                                model: usersTab.userList
                                delegate: Rectangle {
                                    id: userDelegate
                                    // The real login username always leads - a friendly display
                                    // name is shown alongside it, never in place of it (Akash's
                                    // feedback: the actual account identity must be front and
                                    // center, not hidden behind a GECOS name).
                                    readonly property bool isSelf: modelData.username === usersTab.ownUsername
                                    readonly property bool isLastAdmin: modelData.admin && usersTab.adminCount <= 1
                                    readonly property bool autoLoginOn: modelData.username === usersTab.autoLoginUser && usersTab.autoLoginUser !== ""
                                    width: usersTab.width; height: usersTab.viewerIsAdmin ? 90 : 51; radius: 9; color: Theme.surfaceRaised
                                    Column {
                                        anchors.fill: parent; anchors.margins: 9; spacing: 6
                                    Row {
                                        spacing: 12
                                        Text {
                                            width: 300; anchors.verticalCenter: parent.verticalCenter
                                            font.family: Theme.uiFont; color: Theme.panelInk; font.pixelSize: 18
                                            elide: Text.ElideRight
                                            text: modelData.username
                                                + (userDelegate.isSelf ? " (you)" : "")
                                                + (modelData.displayName ? " — " + modelData.displayName : "")
                                                + (modelData.admin ? " · admin" : "")
                                                + (userDelegate.autoLoginOn ? " · auto-login" : "")
                                        }
                                        Button {
                                            // Real "switch user" - not fake concurrent
                                            // sessions (Hyprland has a documented crash
                                            // risk there, confirmed via research, see
                                            // tasks/todo.md Task 32) - a clean logout via
                                            // the same hl.dsp.exit() the power menu's own
                                            // "Log out" already uses, landing back at ly's
                                            // login screen to type the target user's
                                            // password. Akash's own explicit choice after
                                            // being shown the crash-risk tradeoff.
                                            height: 33; anchors.verticalCenter: parent.verticalCenter
                                            visible: !userDelegate.isSelf
                                            variant: "primary"
                                            label: "Switch to this user"
                                            onClicked: usersTab.switchTarget = modelData.username
                                        }
                                        Button {
                                            height: 33; anchors.verticalCenter: parent.verticalCenter
                                            variant: "neutral"
                                            visible: usersTab.viewerIsAdmin
                                            enabled: !userDelegate.isLastAdmin
                                            label: modelData.admin ? "Revoke admin" : "Make admin"
                                            onClicked: usersTab.requestSudo(
                                                ["/usr/local/bin/jazz-user-set", modelData.username, "--admin", modelData.admin ? "no" : "yes"],
                                                (modelData.admin ? "Revoke admin access from " : "Grant admin access to ") + modelData.username + "?")
                                        }
                                        Button {
                                            height: 33; anchors.verticalCenter: parent.verticalCenter
                                            variant: "outlineDanger"
                                            visible: usersTab.viewerIsAdmin
                                            enabled: !userDelegate.isSelf
                                            label: "Remove"
                                            onClicked: usersTab.removeTarget = modelData.username
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            font.family: Theme.uiFont; color: Theme.textSecondary; font.pixelSize: 13
                                            text: !usersTab.viewerIsAdmin ? "Only admins can manage users" : (userDelegate.isLastAdmin ? "Only admin - can't revoke" : (userDelegate.isSelf ? "Can't remove yourself" : ""))
                                        }
                                    }
                                    Row {
                                        visible: usersTab.viewerIsAdmin
                                        spacing: 12
                                        Text {
                                            width: 300; anchors.verticalCenter: parent.verticalCenter
                                            font.family: Theme.uiFont; color: Theme.textSecondary; font.pixelSize: 13
                                            text: userDelegate.autoLoginOn
                                                ? "Auto-login: skips the password prompt for this account on next boot"
                                                : "Auto-login: off"
                                        }
                                        Button {
                                            height: 27; anchors.verticalCenter: parent.verticalCenter
                                            fontSize: 10
                                            variant: userDelegate.autoLoginOn ? "outlineDanger" : "neutral"
                                            label: userDelegate.autoLoginOn ? "Disable auto-login" : "Enable auto-login"
                                            onClicked: usersTab.requestSudo(
                                                ["/usr/local/bin/jazz-user-set", modelData.username, "--autologin", userDelegate.autoLoginOn ? "no" : "yes"],
                                                userDelegate.autoLoginOn
                                                    ? ("Disable auto-login? " + modelData.username + " will need their password again at the next boot.")
                                                    : ("Enable auto-login for " + modelData.username + "? Anyone who turns this machine on gets straight into their account with NO password prompt - a real security tradeoff, not just a convenience toggle. Takes effect on the next boot, not the next logout. Only one account can have this at a time."))
                                        }
                                    }
                                    }
                                }
                            }
                            Button {
                                label: "Refresh list"
                                variant: "neutral"
                                onClicked: usersTab.refresh()
                            }
                            Text {
                                visible: usersTab.sudoStatus !== ""
                                text: usersTab.sudoStatus
                                color: usersTab.sudoStatus === "Done." ? Theme.textSecondary : Theme.critical
                                font.family: Theme.uiFont; font.pixelSize: 15
                            }

                            // Inline confirmation, shown only when a user picked
                            // "Remove" above - explicit keep-vs-delete home choice,
                            // never a silent default (Task 32's own acceptance bar).
                            Rectangle {
                                visible: usersTab.removeTarget !== ""
                                width: usersTab.width; height: 90; radius: 9
                                color: Theme.surfaceRaised; border.color: Theme.critical; border.width: 1
                                Column {
                                    anchors.fill: parent; anchors.margins: 12; spacing: 8
                                    Text {
                                        font.family: Theme.uiFont; color: Theme.panelInk; font.pixelSize: 16
                                        text: "Remove " + usersTab.removeTarget + "? This cannot be undone."
                                    }
                                    Row {
                                        spacing: 10
                                        Button {
                                            label: "Delete everything"
                                            variant: "danger"
                                            onClicked: {
                                                usersTab.requestSudo(["/usr/local/bin/jazz-user-remove", usersTab.removeTarget, "no"], "Remove " + usersTab.removeTarget + " and delete their home folder?")
                                                usersTab.removeTarget = ""
                                            }
                                        }
                                        Button {
                                            label: "Keep home folder"
                                            variant: "outlineDanger"
                                            onClicked: {
                                                usersTab.requestSudo(["/usr/local/bin/jazz-user-remove", usersTab.removeTarget, "yes"], "Remove " + usersTab.removeTarget + " but keep their home folder?")
                                                usersTab.removeTarget = ""
                                            }
                                        }
                                        Button {
                                            label: "Cancel"
                                            variant: "neutral"
                                            onClicked: usersTab.removeTarget = ""
                                        }
                                    }
                                }
                            }

                            // Inline confirmation for "Switch to this user" - a clean
                            // logout (same hl.dsp.exit() the power menu's own Log Out
                            // uses), not a fake in-place switch. Real work in the
                            // current session closes, same as any normal logout.
                            Rectangle {
                                visible: usersTab.switchTarget !== ""
                                width: usersTab.width; height: 160; radius: 9
                                color: Theme.surfaceRaised; border.color: WorkspaceState.activeColor(); border.width: 1
                                Column {
                                    anchors.fill: parent; anchors.margins: 12; spacing: 8
                                    Text {
                                        font.family: Theme.uiFont; color: Theme.panelInk; font.pixelSize: 16
                                        text: "Log out and switch to " + usersTab.switchTarget + "? Your current session will close - save anything open first."
                                        wrapMode: Text.WordWrap; width: parent.width
                                    }
                                    Text {
                                        font.family: Theme.uiFont; color: Theme.critical; font.pixelSize: 14
                                        text: "At the login screen, it will still show \"" + usersTab.ownUsername + "\" typed in from last time - clear that field first (Backspace), then type \"" + usersTab.switchTarget + "\" and their password. If this account was JUST created and the machine hasn't rebooted since, the login screen won't recognize it yet - reboot first."
                                        wrapMode: Text.WordWrap; width: parent.width
                                    }
                                    Row {
                                        spacing: 10
                                        Button {
                                            label: "Log out now"
                                            variant: "primary"
                                            onClicked: {
                                                Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exit()"])
                                                usersTab.switchTarget = ""
                                            }
                                        }
                                        Button {
                                            label: "Cancel"
                                            variant: "neutral"
                                            onClicked: usersTab.switchTarget = ""
                                        }
                                    }
                                }
                            }

                            SectionHeader { text: "CHANGE MY PASSWORD" }
                            Text {
                                font.family: Theme.uiFont; color: Theme.textSecondary; font.pixelSize: 14
                                text: "Changes the password for your own account (" + usersTab.ownUsername + ") - no admin approval needed."
                            }
                            Column {
                                width: usersTab.width; spacing: 12
                                Column {
                                    spacing: 4
                                    Text { font.family: Theme.uiFont; color: Theme.textSecondary; font.pixelSize: 14; text: "Current password" }
                                    Rectangle {
                                        width: 280; height: 33; radius: 6; color: Theme.panel
                                        border.color: Theme.panelInk; border.width: 1
                                        TextInput {
                                            id: currentPwField
                                            anchors.fill: parent; anchors.margins: 6
                                            color: Theme.panelInk; font.pixelSize: 18; font.family: Theme.uiFont
                                            echoMode: TextInput.Password; clip: true
                                        }
                                    }
                                }
                                Column {
                                    spacing: 4
                                    Text { font.family: Theme.uiFont; color: Theme.textSecondary; font.pixelSize: 14; text: "New password" }
                                    Rectangle {
                                        width: 280; height: 33; radius: 6; color: Theme.panel
                                        border.color: Theme.panelInk; border.width: 1
                                        TextInput {
                                            id: newPwField
                                            anchors.fill: parent; anchors.margins: 6
                                            color: Theme.panelInk; font.pixelSize: 18; font.family: Theme.uiFont
                                            echoMode: TextInput.Password; clip: true
                                        }
                                    }
                                }
                                Column {
                                    spacing: 4
                                    Text { font.family: Theme.uiFont; color: Theme.textSecondary; font.pixelSize: 14; text: "Confirm new password" }
                                    Rectangle {
                                        width: 280; height: 33; radius: 6; color: Theme.panel
                                        border.color: Theme.panelInk; border.width: 1
                                        TextInput {
                                            id: confirmPwField
                                            anchors.fill: parent; anchors.margins: 6
                                            color: Theme.panelInk; font.pixelSize: 18; font.family: Theme.uiFont
                                            echoMode: TextInput.Password; clip: true
                                        }
                                    }
                                }
                                Button {
                                    label: "Change Password"
                                    onClicked: {
                                        if (newPwField.text.length === 0 || newPwField.text !== confirmPwField.text) {
                                            usersTab.pwStatus = "New password and confirmation don't match."
                                            return
                                        }
                                        passwdProc.outText = ""
                                        passwdProc.command = ["jazz-user-passwd", currentPwField.text, newPwField.text]
                                        passwdProc.running = true
                                    }
                                }
                                Text {
                                    visible: usersTab.pwStatus !== ""
                                    text: usersTab.pwStatus
                                    color: usersTab.pwStatus.indexOf("successfully") >= 0 ? Theme.textSecondary : Theme.critical
                                    font.family: Theme.uiFont; font.pixelSize: 15
                                }
                            }

                            SectionHeader { text: "MY DISPLAY NAME" }
                            Text {
                                font.family: Theme.uiFont; color: Theme.textSecondary; font.pixelSize: 14
                                text: "Shown on the lock screen instead of your raw username (\"" + usersTab.ownUsername + "\"). `chfn` (the normal self-service way to do this) is blocked by this system's login policy even for your own account, so this goes through the same admin-password confirmation as the other actions above."
                                wrapMode: Text.WordWrap; width: usersTab.width
                            }
                            Row {
                                spacing: 10
                                Rectangle {
                                    width: 280; height: 33; radius: 6; color: Theme.panel
                                    border.color: Theme.panelInk; border.width: 1
                                    TextInput {
                                        id: displayNameField
                                        anchors.fill: parent; anchors.margins: 6
                                        color: Theme.panelInk; font.pixelSize: 18; font.family: Theme.uiFont
                                        clip: true
                                    }
                                }
                                Button {
                                    height: 33; anchors.verticalCenter: parent.verticalCenter
                                    label: "Save"
                                    onClicked: usersTab.requestSudo(
                                        ["/usr/local/bin/jazz-user-set", usersTab.ownUsername, "--displayname", displayNameField.text],
                                        "Set your display name to \"" + displayNameField.text + "\"?")
                                }
                            }

                            SectionHeader { text: "MY AVATAR" }
                            Text {
                                font.family: Theme.uiFont; color: Theme.textSecondary; font.pixelSize: 14
                                text: "Shown on your lock screen. Enter the full path to an image already on this machine - a real file picker is coming with Jazz Files."
                                wrapMode: Text.WordWrap; width: usersTab.width
                            }
                            Process {
                                id: avatarCheckProc
                                command: ["bash", "-c", "f=\"$HOME/.face.icon\"; [ -f \"$f\" ] && echo \"$f\" || echo ''"]
                                stdout: SplitParser {
                                    onRead: function (data) {
                                        usersTab.hasAvatar = !!data
                                        usersTab.avatarPath = data || ""
                                        usersTab.avatarCacheBust = Date.now()
                                    }
                                }
                            }
                            function loadAvatarStatus() { avatarCheckProc.running = true }
                            Process {
                                id: avatarProc
                                property string outText: ""
                                stdout: StdioCollector { onStreamFinished: avatarProc.outText += this.text }
                                stderr: StdioCollector { onStreamFinished: avatarProc.outText += this.text }
                                onExited: function (exitCode, exitStatus) {
                                    usersTab.avatarStatus = avatarProc.outText.trim() || (exitCode === 0 ? "Done." : "Failed (exit " + exitCode + ").")
                                    if (exitCode === 0) {
                                        avatarPathField.text = ""
                                        usersTab.loadAvatarStatus()
                                        // Regenerates hyprlock.conf's avatar block against the
                                        // now-current ~/.face.icon, without needing a theme switch.
                                        Quickshell.execDetached(["jazz-theme-set", "--restore"])
                                    }
                                }
                            }
                            Row {
                                spacing: 16
                                Rectangle {
                                    width: 80; height: 80; radius: 40
                                    color: Theme.surfaceRaised
                                    border.color: Theme.panelInk; border.width: 1
                                    clip: true
                                    Text {
                                        anchors.centerIn: parent
                                        visible: !usersTab.hasAvatar
                                        text: usersTab.ownUsername.length > 0 ? usersTab.ownUsername[0].toUpperCase() : "?"
                                        font.family: Theme.uiFont; font.pixelSize: 32; font.bold: true; color: Theme.panelInk
                                    }
                                    Image {
                                        anchors.fill: parent
                                        visible: usersTab.hasAvatar
                                        source: usersTab.hasAvatar ? ("file://" + usersTab.avatarPath + "?" + usersTab.avatarCacheBust) : ""
                                        fillMode: Image.PreserveAspectCrop
                                    }
                                }
                                Column {
                                    spacing: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    Row {
                                        spacing: 10
                                        Rectangle {
                                            width: 280; height: 33; radius: 6; color: Theme.panel
                                            border.color: Theme.panelInk; border.width: 1
                                            TextInput {
                                                id: avatarPathField
                                                anchors.fill: parent; anchors.margins: 6
                                                color: Theme.panelInk; font.pixelSize: 18; font.family: Theme.uiFont
                                                clip: true
                                            }
                                        }
                                        Button {
                                            height: 33; anchors.verticalCenter: parent.verticalCenter
                                            label: "Set"
                                            onClicked: {
                                                if (avatarPathField.text.length === 0) { usersTab.avatarStatus = "Enter a file path first."; return }
                                                avatarProc.outText = ""
                                                avatarProc.command = ["jazz-user-avatar", avatarPathField.text]
                                                avatarProc.running = true
                                            }
                                        }
                                        Button {
                                            height: 33; anchors.verticalCenter: parent.verticalCenter
                                            variant: "outlineDanger"
                                            visible: usersTab.hasAvatar
                                            label: "Remove"
                                            onClicked: {
                                                avatarProc.outText = ""
                                                avatarProc.command = ["jazz-user-avatar", "--remove"]
                                                avatarProc.running = true
                                            }
                                        }
                                    }
                                    Text {
                                        visible: usersTab.avatarStatus !== ""
                                        text: usersTab.avatarStatus
                                        color: usersTab.avatarStatus.indexOf("error") >= 0 || usersTab.avatarStatus.indexOf("Failed") >= 0 ? Theme.critical : Theme.textSecondary
                                        font.family: Theme.uiFont; font.pixelSize: 15
                                    }
                                }
                            }

                            SectionHeader { text: "IDLE LOCK" }
                            Text {
                                font.family: Theme.uiFont; color: Theme.textSecondary; font.pixelSize: 14
                                text: usersTab.idleStatus || "loading..."
                                wrapMode: Text.WordWrap; width: usersTab.width
                            }
                            Process {
                                id: idleProc
                                property string outText: ""
                                stdout: StdioCollector { onStreamFinished: idleProc.outText += this.text }
                                stderr: StdioCollector { onStreamFinished: idleProc.outText += this.text }
                                onExited: function (exitCode, exitStatus) {
                                    if (exitCode === 0) {
                                        try {
                                            var parsed = JSON.parse(idleProc.outText.trim().split("\n").pop())
                                            usersTab.idleEnabled = parsed.enabled
                                            usersTab.idleMinutes = parsed.minutes
                                            idleMinutesField.text = String(parsed.minutes)
                                            usersTab.idleStatus = parsed.enabled
                                                ? ("Locks after " + parsed.minutes + " minute" + (parsed.minutes === 1 ? "" : "s") + " of inactivity.")
                                                : "Idle auto-lock is off."
                                        } catch (e) {
                                            usersTab.idleStatus = "Couldn't read idle-lock status."
                                        }
                                    } else {
                                        usersTab.idleStatus = idleProc.outText.trim() || ("Failed (exit " + exitCode + ").")
                                    }
                                }
                            }
                            function loadIdleStatus() {
                                idleProc.outText = ""
                                idleProc.command = ["jazz-idle-set", "--status"]
                                idleProc.running = true
                            }
                            function applyIdle(enabled, minutes) {
                                idleProc.outText = ""
                                idleProc.command = ["jazz-idle-set", "--enabled", enabled ? "true" : "false", "--minutes", String(minutes)]
                                idleProc.running = true
                            }
                            Row {
                                spacing: 12
                                Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.uiFont; color: Theme.panelInk; font.pixelSize: 18; text: "Lock screen after inactivity" }
                                Toggle {
                                    id: idleEnabledToggle
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: usersTab.idleEnabled
                                    onToggled: usersTab.applyIdle(!usersTab.idleEnabled, usersTab.idleMinutes)
                                }
                            }
                            Row {
                                spacing: 10
                                visible: usersTab.idleEnabled
                                Rectangle {
                                    width: 80; height: 33; radius: 6; color: Theme.panel
                                    border.color: Theme.panelInk; border.width: 1
                                    TextInput {
                                        id: idleMinutesField
                                        anchors.fill: parent; anchors.margins: 6
                                        color: Theme.panelInk; font.pixelSize: 18; font.family: Theme.uiFont
                                        clip: true; validator: IntValidator { bottom: 1; top: 180 }
                                    }
                                }
                                Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.uiFont; color: Theme.panelInk; font.pixelSize: 18; text: "minutes" }
                                Button {
                                    height: 33; anchors.verticalCenter: parent.verticalCenter
                                    label: "Save"
                                    onClicked: {
                                        var mins = parseInt(idleMinutesField.text)
                                        if (isNaN(mins) || mins < 1) { usersTab.idleStatus = "Enter a whole number of minutes, at least 1."; return }
                                        usersTab.applyIdle(true, mins)
                                    }
                                }
                            }

                            SectionHeader { text: "ADD USER" }
                            Text {
                                font.family: Theme.uiFont; color: Theme.textSecondary; font.pixelSize: 14
                                text: "Creates a new system account. You'll be asked for YOUR own password to confirm - the same check as running sudo yourself. The login screen won't recognize the new account until you reboot (a real limitation of ly, the login screen software - it only reads the user list once at startup)."
                                wrapMode: Text.WordWrap; width: usersTab.width
                            }
                            Column {
                                width: usersTab.width; spacing: 12
                                Column {
                                    spacing: 4
                                    Text { font.family: Theme.uiFont; color: Theme.textSecondary; font.pixelSize: 14; text: "Username (lowercase, no spaces)" }
                                    Rectangle {
                                        width: 280; height: 33; radius: 6; color: Theme.panel
                                        border.color: Theme.panelInk; border.width: 1
                                        TextInput {
                                            id: newUsernameField
                                            anchors.fill: parent; anchors.margins: 6
                                            color: Theme.panelInk; font.pixelSize: 18; font.family: Theme.uiFont
                                            clip: true
                                        }
                                    }
                                }
                                Column {
                                    spacing: 4
                                    Text { font.family: Theme.uiFont; color: Theme.textSecondary; font.pixelSize: 14; text: "Full name (shown on the lock screen)" }
                                    Rectangle {
                                        width: 280; height: 33; radius: 6; color: Theme.panel
                                        border.color: Theme.panelInk; border.width: 1
                                        TextInput {
                                            id: newFullNameField
                                            anchors.fill: parent; anchors.margins: 6
                                            color: Theme.panelInk; font.pixelSize: 18; font.family: Theme.uiFont
                                            clip: true
                                        }
                                    }
                                }
                                Column {
                                    spacing: 4
                                    Text { font.family: Theme.uiFont; color: Theme.textSecondary; font.pixelSize: 14; text: "Initial password (they can change it later)" }
                                    Rectangle {
                                        width: 280; height: 33; radius: 6; color: Theme.panel
                                        border.color: Theme.panelInk; border.width: 1
                                        TextInput {
                                            id: newUserPwField
                                            anchors.fill: parent; anchors.margins: 6
                                            color: Theme.panelInk; font.pixelSize: 18; font.family: Theme.uiFont
                                            echoMode: TextInput.Password; clip: true
                                        }
                                    }
                                }
                                Row {
                                    spacing: 12
                                    Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.uiFont; color: Theme.panelInk; font.pixelSize: 18; text: "Admin (sudo) access" }
                                    Toggle {
                                        id: newUserAdminToggle
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                Button {
                                    label: "Create User"
                                    onClicked: {
                                        if (newUsernameField.text.length === 0 || newUserPwField.text.length === 0) {
                                            usersTab.addStatus = "Username and initial password are required."
                                            return
                                        }
                                        usersTab.requestSudo(
                                            ["/usr/local/bin/jazz-user-add", newUsernameField.text,
                                             newFullNameField.text || newUsernameField.text,
                                             newUserPwField.text, newUserAdminToggle.checked ? "yes" : "no"],
                                            "Create user " + newUsernameField.text + "?")
                                        newUsernameField.text = ""; newFullNameField.text = ""; newUserPwField.text = ""
                                        newUserAdminToggle.checked = false
                                    }
                                }
                                Text {
                                    visible: usersTab.addStatus !== ""
                                    text: usersTab.addStatus
                                    color: Theme.textSecondary
                                    font.family: Theme.uiFont; font.pixelSize: 15
                                    wrapMode: Text.WordWrap
                                    width: usersTab.width
                                }
                            }
                        }

                        // ===== Updates (REAL) =====
                        Column {
                            id: updatesTab
                            visible: settingsPanel.currentPage === "updates"
                            width: parent.width; spacing: 15
                            property var pending: []
                            property bool checked: false
                            Process {
                                id: updatesProc
                                command: ["bash", "-c", "checkupdates 2>/dev/null"]
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        updatesTab.pending = this.text.split("\n").filter(function(s) { return s.length > 0 })
                                        updatesTab.checked = true
                                    }
                                }
                            }
                            function refresh() { updatesTab.checked = false; updatesProc.running = true }
                            Component.onCompleted: refresh()
                            SectionHeader { text: "UPDATES" }
                            Text {
                                text: !updatesTab.checked ? "Checking..." : (updatesTab.pending.length === 0 ? "System is up to date" : updatesTab.pending.length + " updates available")
                                color: Theme.panelInk; font.pixelSize: 22
                            }
                            Column {
                                width: parent.width; spacing: 3
                                Repeater {
                                    model: updatesTab.pending
                                    delegate: Text { text: modelData; color: Theme.textSecondary; font.pixelSize: 16; font.family: Theme.monoFont }
                                }
                            }
                            Button {
                                width: 165; height: 39
                                fontSize: 11
                                label: "Check Now"
                                onClicked: updatesTab.refresh()
                            }
                        }

                        // ===== Accessibility (REAL - reduced motion + whole-desktop UI scale) =====
                        Column {
                            id: accessTab
                            visible: settingsPanel.currentPage === "accessibility"
                            width: parent.width; spacing: 15
                            property var monitorData: null
                            property string originalScaleLuaLine: ""
                            property bool scaleTimerActive: false
                            property int scaleSecondsLeft: 12

                            Process {
                                id: accessMonitorProc
                                command: ["bash", "-c", "hyprctl monitors -j"]
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        try { accessTab.monitorData = JSON.parse(this.text)[0] } catch (e) {}
                                    }
                                }
                            }
                            function refreshMonitor() { accessMonitorProc.running = true }
                            Component.onCompleted: refreshMonitor()

                            // Same fire-and-forget/race precaution as the Displays tab (Task 28
                            // slice 5) - give the compositor a moment before re-querying state.
                            Timer {
                                id: accessRefreshDelay
                                interval: 500; repeat: false
                                onTriggered: accessTab.refreshMonitor()
                            }
                            Timer {
                                interval: 1000; repeat: true; running: accessTab.scaleTimerActive
                                onTriggered: {
                                    accessTab.scaleSecondsLeft -= 1
                                    if (accessTab.scaleSecondsLeft <= 0) {
                                        Quickshell.execDetached(["hyprctl", "eval", accessTab.originalScaleLuaLine])
                                        accessTab.scaleTimerActive = false
                                        accessRefreshDelay.restart()
                                    }
                                }
                            }
                            function scaleLuaFor(scaleVal) {
                                var m = accessTab.monitorData
                                return 'hl.monitor({ output = "' + m.name + '", mode = "' + m.width + 'x' + m.height + '@' + m.refreshRate.toFixed(2) + '", position = "' + m.x + 'x' + m.y + '", scale = ' + scaleVal + ' })'
                            }
                            function applyScale(scaleVal) {
                                var m = accessTab.monitorData
                                accessTab.originalScaleLuaLine = accessTab.scaleLuaFor(m.scale)
                                Quickshell.execDetached(["hyprctl", "eval", accessTab.scaleLuaFor(scaleVal)])
                                accessTab.scaleSecondsLeft = 12
                                accessTab.scaleTimerActive = true
                            }

                            SectionHeader { text: "ACCESSIBILITY" }
                            SectionHeader { text: "MOTION" }
                            Row {
                                spacing: 15
                                Text { font.family: Theme.uiFont; anchors.verticalCenter: parent.verticalCenter; text: Theme.reducedMotion ? "Reduce motion: On" : "Reduce motion: Off"; color: Theme.panelInk; font.pixelSize: 20 }
                                Toggle {
                                    checked: Theme.reducedMotion
                                    onToggled: Theme.reducedMotion = !Theme.reducedMotion
                                }
                            }
                            Text {
                                width: parent.width; wrapMode: Text.Wrap
                                text: "Turns off JAZZ's own color/transition animations (currently: the top bar's workspace-color change). Native app animations aren't affected."
                                color: Theme.textSecondary; font.pixelSize: 15
                            }
                            SectionHeader { text: "TEXT & UI SIZE" }
                            Text {
                                text: accessTab.monitorData ? ("Current: " + Math.round(accessTab.monitorData.scale * 100) + "%") : "loading..."
                                color: Theme.panelInk; font.pixelSize: 20
                            }
                            Text {
                                width: parent.width; wrapMode: Text.Wrap
                                text: "Scales the entire desktop - dock, top bar, Settings, and every app - not just JAZZ's own panels. Same safety timer as Displays: a bad size always reverts on its own."
                                color: Theme.textSecondary; font.pixelSize: 15
                            }
                            Row {
                                spacing: 9
                                Repeater {
                                    model: [1.0, 1.15, 1.25, 1.5, 1.75]
                                    delegate: Button {
                                        property real scaleVal: modelData
                                        width: 84; height: 39
                                        fontSize: 11
                                        variant: (accessTab.monitorData && Math.abs(accessTab.monitorData.scale - scaleVal) < 0.01) ? "primary" : "subtle"
                                        enabled: !accessTab.scaleTimerActive
                                        label: Math.round(scaleVal * 100) + "%"
                                        onClicked: accessTab.applyScale(scaleVal)
                                    }
                                }
                            }
                            Rectangle {
                                visible: accessTab.scaleTimerActive
                                width: parent.width; height: 96; radius: 12; color: Theme.surfaceRaised
                                border.color: WorkspaceState.activeColor(); border.width: 1
                                Column {
                                    anchors.centerIn: parent; spacing: 12
                                    Text {
                                        text: "Keep this size? Reverting in " + accessTab.scaleSecondsLeft + "s"
                                        color: Theme.panelInk; font.pixelSize: 20
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    Row {
                                        spacing: 15
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        Button {
                                            width: 105; height: 36
                                            fontSize: 11
                                            label: "Keep"
                                            onClicked: { accessTab.scaleTimerActive = false; accessTab.refreshMonitor() }
                                        }
                                        Button {
                                            width: 105; height: 36
                                            fontSize: 11
                                            variant: "neutral"
                                            label: "Revert"
                                            onClicked: {
                                                Quickshell.execDetached(["hyprctl", "eval", accessTab.originalScaleLuaLine])
                                                accessTab.scaleTimerActive = false
                                                accessRefreshDelay.restart()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ===== System (REAL) =====
                        Column {
                            id: systemTab
                            visible: settingsPanel.currentPage === "system"
                            width: parent.width; spacing: 12
                            property string hostname: "..."
                            property string kernel: "..."
                            property string cpu: "..."
                            property string mem: "..."
                            property string gpu: "..."
                            Process {
                                running: systemTab.visible
                                command: ["bash", "-c", "hostnamectl --static"]
                                stdout: SplitParser { onRead: function (data) { if (data) systemTab.hostname = data } }
                            }
                            Process {
                                running: systemTab.visible
                                command: ["uname", "-r"]
                                stdout: SplitParser { onRead: function (data) { if (data) systemTab.kernel = data } }
                            }
                            Process {
                                running: systemTab.visible
                                command: ["bash", "-c", "lscpu | grep 'Model name' | sed 's/Model name:\\s*//'"]
                                stdout: SplitParser { onRead: function (data) { if (data) systemTab.cpu = data } }
                            }
                            Process {
                                running: systemTab.visible
                                command: ["bash", "-c", "free -h | awk '/Mem:/{print $3\" / \"$2}'"]
                                stdout: SplitParser { onRead: function (data) { if (data) systemTab.mem = data } }
                            }
                            Process {
                                running: systemTab.visible
                                command: ["bash", "-c", "lspci | grep VGA | sed 's/.*: //'"]
                                stdout: SplitParser { onRead: function (data) { if (data) systemTab.gpu = data } }
                            }
                            SectionHeader { text: "ABOUT" }
                            Text { font.family: Theme.uiFont; text: "JAZZ"; color: Theme.panelInk; font.pixelSize: 27; font.bold: true }
                            Text { font.family: Theme.uiFont; text: "Arch Linux, hostname " + systemTab.hostname; color: Theme.panelInk; font.pixelSize: 18 }
                            Text { font.family: Theme.uiFont; text: "Kernel " + systemTab.kernel; color: Theme.panelInk; font.pixelSize: 18 }
                            Text { font.family: Theme.uiFont; text: "CPU: " + systemTab.cpu; color: Theme.panelInk; font.pixelSize: 18 }
                            Text { font.family: Theme.uiFont; text: "GPU: " + systemTab.gpu; color: Theme.panelInk; font.pixelSize: 18 }
                            Text { font.family: Theme.uiFont; text: "Memory: " + systemTab.mem; color: Theme.panelInk; font.pixelSize: 18 }
                            Button {
                                width: 255; height: 39
                                label: settingsPanel.devModeEnabled ? "Disable Developer Mode" : "Enable Developer Mode"
                                onClicked: {
                                    var cmd = settingsPanel.devModeEnabled
                                        ? "rm -f @@JAZZ_CONFIG_DIR@@/dev-mode.enabled"
                                        : "mkdir -p @@JAZZ_CONFIG_DIR@@ && touch @@JAZZ_CONFIG_DIR@@/dev-mode.enabled"
                                    Quickshell.execDetached(["bash", "-c", cmd])
                                    settingsPanel.devModeEnabled = !settingsPanel.devModeEnabled
                                }
                            }
                        }

                        // ===== Developer (REAL, hidden by default - Hyprland event log +
                        // D-Bus inspector, reading Hyprland's real .socket2.sock IPC feed
                        // via a tiny stdlib Python script, same "no new dependency" pattern
                        // as scan-apps.py) =====
                        Column {
                            id: developerTab
                            visible: settingsPanel.currentPage === "developer"
                            width: parent.width; spacing: 15
                            property var eventLines: []
                            property var busNames: []
                            property string selectedBusName: ""
                            property string treeText: ""

                            Process {
                                id: hyprEventsProc
                                running: developerTab.visible
                                command: ["python3", "@@JAZZ_DATA_DIR@@/jazz-hypr-events.py"]
                                stdout: SplitParser {
                                    onRead: function (data) {
                                        if (!data) return
                                        var arr = developerTab.eventLines.concat([data])
                                        if (arr.length > 40) arr = arr.slice(arr.length - 40)
                                        developerTab.eventLines = arr
                                    }
                                }
                            }

                            function refreshBus() { busListProc.running = true }
                            Component.onCompleted: refreshBus()
                            Process {
                                id: busListProc
                                command: ["bash", "-c", "busctl --user list --no-legend"]
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        var lines = this.text.split("\n").filter(function (l) { return l.trim().length > 0 })
                                        var out = []
                                        for (var i = 0; i < lines.length; i++) {
                                            var name = lines[i].trim().split(/\s+/)[0]
                                            out.push({ raw: lines[i].trim(), name: name })
                                        }
                                        developerTab.busNames = out
                                    }
                                }
                            }
                            Process {
                                id: busTreeProc
                                stdout: StdioCollector { onStreamFinished: developerTab.treeText = this.text }
                            }
                            function inspectBus(name) {
                                developerTab.selectedBusName = name
                                developerTab.treeText = "loading..."
                                busTreeProc.command = ["bash", "-c", "timeout 3 busctl --user tree '" + name + "' 2>&1"]
                                busTreeProc.running = true
                            }

                            SectionHeader { text: "DEVELOPER" }

                            Row {
                                spacing: 15
                                SectionHeader { anchors.verticalCenter: parent.verticalCenter; text: "HYPRLAND EVENT LOG" }
                                Text { font.family: Theme.uiFont; anchors.verticalCenter: parent.verticalCenter; text: developerTab.visible ? "(live)" : ""; color: WorkspaceState.activeColor(); font.pixelSize: 15 }
                                Button {
                                    width: 75; height: 30
                                    variant: "subtle"
                                    label: "Clear"
                                    onClicked: developerTab.eventLines = []
                                }
                            }
                            Rectangle {
                                width: parent.width; height: 330; radius: 9; color: Theme.surfaceRaised
                                clip: true
                                Flickable {
                                    id: eventFlick
                                    anchors.fill: parent; anchors.margins: 9
                                    contentHeight: eventText.height
                                    contentWidth: width
                                    Text {
                                        id: eventText
                                        width: eventFlick.width
                                        text: developerTab.eventLines.length > 0 ? developerTab.eventLines.join("\n") : "Waiting for events - switch workspaces, open a window, or plug/unplug something to see live IPC events here."
                                        color: Theme.panelInk; font.pixelSize: 15; font.family: Theme.monoFont
                                        wrapMode: Text.Wrap
                                        onTextChanged: eventFlick.contentY = Math.max(0, height - eventFlick.height)
                                    }
                                }
                            }

                            Row {
                                spacing: 15
                                SectionHeader { anchors.verticalCenter: parent.verticalCenter; text: "D-BUS INSPECTOR (session bus)" }
                                Button {
                                    width: 90; height: 30
                                    variant: "subtle"
                                    label: "Refresh"
                                    onClicked: developerTab.refreshBus()
                                }
                            }
                            Text { font.family: Theme.uiFont; text: developerTab.busNames.length + " services on the session bus - click one to inspect its object tree"; color: Theme.textSecondary; font.pixelSize: 15 }
                            Rectangle {
                                width: parent.width; height: 270; radius: 9; color: Theme.surfaceRaised
                                clip: true
                                Flickable {
                                    anchors.fill: parent; anchors.margins: 9
                                    contentHeight: busCol.height
                                    contentWidth: width
                                    Column {
                                        id: busCol
                                        width: parent.width; spacing: 2
                                        Repeater {
                                            model: developerTab.busNames
                                            delegate: Rectangle {
                                                property var svcData: modelData
                                                width: parent.width; height: 27
                                                color: developerTab.selectedBusName === svcData.name ? WorkspaceState.activeColor() : "#00000000"
                                                Text {
                                                    anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter
                                                    text: svcData.raw
                                                    color: developerTab.selectedBusName === svcData.name ? "#ffffff" : Theme.panelInk
                                                    font.pixelSize: 14; font.family: Theme.monoFont
                                                }
                                                MouseArea { anchors.fill: parent; onClicked: developerTab.inspectBus(svcData.name) }
                                            }
                                        }
                                    }
                                }
                            }
                            Column {
                                visible: developerTab.selectedBusName.length > 0
                                width: parent.width; spacing: 6
                                Text { font.family: Theme.uiFont; text: developerTab.selectedBusName; color: Theme.panelInk; font.pixelSize: 16; font.bold: true }
                                Text {
                                    width: parent.width
                                    text: developerTab.treeText
                                    color: Theme.panelInk; font.pixelSize: 15; font.family: Theme.monoFont
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }
                }
            }
        }

        // Task 32: the small in-app sudo-password confirmation used by the
        // Users tab's privileged actions (add/remove/admin-toggle) - a real
        // `sudo -S` Process fed the password via Quickshell's own
        // stdinEnabled/write() API, not a spawned terminal (Akash's
        // feedback: a kitty window opening behind the panel was
        // confusing). Declared last so it renders on top of every tab.
        Rectangle {
            visible: usersTab.pendingCommand !== null
            anchors.fill: parent
            radius: 21
            color: "#0a090899"
            MouseArea { anchors.fill: parent } // swallow clicks to content behind
            Rectangle {
                anchors.centerIn: parent
                width: 360; height: 190; radius: 12
                color: Theme.surfaceRaised
                border.color: Theme.panelInk; border.width: 1
                Column {
                    anchors.fill: parent; anchors.margins: 18; spacing: 12
                    Text {
                        width: parent.width
                        font.family: Theme.uiFont; color: Theme.panelInk; font.pixelSize: 16
                        text: usersTab.pendingDescription
                        wrapMode: Text.WordWrap
                    }
                    Column {
                        spacing: 4
                        Text { font.family: Theme.uiFont; color: Theme.textSecondary; font.pixelSize: 14; text: "Your password (" + usersTab.ownUsername + ")" }
                        Rectangle {
                            width: 320; height: 33; radius: 6; color: Theme.panel
                            border.color: Theme.panelInk; border.width: 1
                            TextInput {
                                id: sudoPwField
                                anchors.fill: parent; anchors.margins: 6
                                color: Theme.panelInk; font.pixelSize: 18; font.family: Theme.uiFont
                                echoMode: TextInput.Password; clip: true
                                focus: usersTab.pendingCommand !== null
                                Keys.onReturnPressed: { usersTab.runPendingCommand(text); text = "" }
                            }
                        }
                    }
                    Row {
                        spacing: 10
                        Button {
                            label: "Confirm"
                            onClicked: { usersTab.runPendingCommand(sudoPwField.text); sudoPwField.text = "" }
                        }
                        Button {
                            label: "Cancel"
                            variant: "neutral"
                            onClicked: { usersTab.pendingCommand = null; usersTab.pendingDescription = ""; sudoPwField.text = "" }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { settingsPanel.visible = !settingsPanel.visible }
    }
}
