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
        { id: "privacy", title: "Privacy", real: false },
        { id: "agents", title: "Agents", real: true },
        { id: "storage", title: "Storage", real: true },
        { id: "power", title: "Battery & Power", real: true },
        { id: "security", title: "Security", real: true },
        { id: "updates", title: "Updates", real: true },
        { id: "accessibility", title: "Accessibility", real: false },
        { id: "system", title: "System", real: true },
        { id: "developer", title: "Developer", real: false, devOnly: true }
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
        width: 860; height: 600
        anchors.centerIn: parent
        radius: 14
        color: Theme.panel
        border.color: Theme.panelInk
        border.width: 1
        clip: true
        MouseArea { anchors.fill: parent }

        property var wallpapers: []
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
            anchors.margins: 16
            spacing: 12

            // ---------- Search ----------
            Rectangle {
                width: parent.width; height: 32; radius: 8
                color: Theme.surfaceRaised
                border.color: Theme.panelInk; border.width: 1
                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.margins: 8
                    color: Theme.panelInk
                    font.pixelSize: 13
                    clip: true
                    focus: settingsPanel.visible
                    onTextChanged: settingsPanel.searchQuery = text
                    Keys.onEscapePressed: { text = ""; settingsPanel.searchQuery = "" }
                }
                Text {
                    visible: searchInput.text.length === 0
                    anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                    text: "Search settings..."; color: Theme.textSecondary; font.pixelSize: 13
                }
            }

            // ---------- Search results ----------
            Column {
                visible: settingsPanel.searchQuery.length > 0
                width: parent.width
                spacing: 2
                Repeater {
                    model: settingsPanel.searchResults()
                    delegate: Rectangle {
                        width: parent.width; height: 26; radius: 6
                        color: "#00000000"
                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                            text: modelData.title + "  ›  " + modelData.page
                            color: Theme.panelInk; font.pixelSize: 12
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
                height: parent.height - 44
                spacing: 20

                // ---------- Sidebar ----------
                Flickable {
                    width: 160; height: parent.height
                    contentHeight: sidebarCol.height
                    clip: true
                    Column {
                        id: sidebarCol
                        width: parent.width
                        spacing: 2
                        Repeater {
                            model: settingsPanel.visibleSections()
                            delegate: Rectangle {
                                width: parent.width; height: 30; radius: 6
                                color: settingsPanel.currentPage === modelData.id ? Theme.forge : "#00000000"
                                Text {
                                    anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.title
                                    color: settingsPanel.currentPage === modelData.id ? "#ffffff" : Theme.panelInk
                                    font.pixelSize: 12
                                }
                                Text {
                                    visible: !modelData.real
                                    anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                                    text: "•"; color: Theme.textSecondary; font.pixelSize: 12
                                }
                                MouseArea { anchors.fill: parent; onClicked: settingsPanel.currentPage = modelData.id }
                            }
                        }
                    }
                }

                Rectangle { width: 1; height: parent.height; color: Theme.panelInk; opacity: 0.15 }

                // ---------- Content ----------
                Flickable {
                    id: contentArea
                    width: 620; height: parent.height
                    contentHeight: contentCol.height
                    clip: true

                    Column {
                        id: contentCol
                        width: parent.width
                        spacing: 16

                        // ===== Appearance (existing, unchanged) =====
                        Column {
                            visible: settingsPanel.currentPage === "appearance"
                            width: parent.width
                            spacing: 16
                            Text { text: "APPEARANCE"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Row {
                                spacing: 10
                                Text { text: Theme.darkMode ? "Dark mode" : "Light mode"; color: Theme.panelInk; font.pixelSize: 13 }
                                Rectangle {
                                    width: 38; height: 20; radius: 10
                                    color: Theme.darkMode ? Theme.forge : Theme.panelInk
                                    opacity: Theme.darkMode ? 1 : 0.25
                                    Rectangle { width: 16; height: 16; radius: 8; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter; x: Theme.darkMode ? parent.width - width - 2 : 2 }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            Theme.darkMode = !Theme.darkMode
                                            var wp = Theme.darkMode ? "@@JAZZ_DATA_DIR@@/wallpapers/jazz-wallpaper-dark.png" : "@@JAZZ_DATA_DIR@@/wallpapers/jazz-wallpaper-light.png"
                                            Quickshell.execDetached(["jazz-wallpaper-set", wp])
                                        }
                                    }
                                }
                            }
                            Text { text: "Wallpaper"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Flow {
                                width: parent.width
                                spacing: 8
                                Repeater {
                                    model: settingsBox.wallpapers
                                    delegate: Rectangle {
                                        width: 90; height: 54; radius: 6
                                        border.color: Theme.panelInk; border.width: 1
                                        Image { anchors.fill: parent; anchors.margins: 2; source: "file://" + modelData; fillMode: Image.PreserveAspectCrop }
                                        MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["jazz-wallpaper-set", modelData]) }
                                    }
                                }
                            }
                        }

                        // ===== Desktop (REAL - informational; layout is fixed by design for v1) =====
                        Column {
                            visible: settingsPanel.currentPage === "desktop"
                            width: parent.width; spacing: 10
                            Text { text: "DESKTOP"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Text { text: "Workspaces"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Column {
                                width: parent.width; spacing: 4
                                Repeater {
                                    model: [
                                        { name: "Forge", desc: "Coding, AI app engineering", color: Theme.forge },
                                        { name: "Lab", desc: "Notebooks, PyTorch/Jupyter", color: Theme.lab },
                                        { name: "Arena", desc: "AI red-teaming", color: Theme.arena },
                                        { name: "Observe", desc: "Logs, metrics, AI Command Centre", color: Theme.observe },
                                        { name: "Vault", desc: "Secrets, sensitive config", color: Theme.vault },
                                        { name: "Range", desc: "Reserved - dormant", color: Theme.range }
                                    ]
                                    delegate: Row {
                                        spacing: 8
                                        Rectangle { width: 10; height: 10; radius: 5; anchors.verticalCenter: parent.verticalCenter; color: modelData.color }
                                        Text { text: modelData.name; color: Theme.panelInk; font.pixelSize: 12; width: 70 }
                                        Text { text: modelData.desc; color: Theme.textSecondary; font.pixelSize: 11 }
                                    }
                                }
                            }
                            Text {
                                text: "Workspace identity, the dock, and top bar are fixed by JAZZ's design for v1 - no auto-hide/hot-corner/icon toggles exist yet, so none are shown here as controls that wouldn't do anything."
                                color: Theme.textSecondary; font.pixelSize: 11; wrapMode: Text.Wrap; width: parent.width
                            }
                        }

                        // ===== Displays (REAL - resolution control + rollback timer, Task 28's required safety mechanism) =====
                        Column {
                            id: displayTab
                            visible: settingsPanel.currentPage === "display"
                            width: parent.width; spacing: 10
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

                            Text { text: "DISPLAYS"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Text {
                                text: displayTab.monitorData
                                    ? (displayTab.monitorData.name + ": " + displayTab.monitorData.width + "x" + displayTab.monitorData.height + "@" + displayTab.monitorData.refreshRate.toFixed(2) + "Hz, scale " + displayTab.monitorData.scale)
                                    : "loading..."
                                color: Theme.panelInk; font.pixelSize: 13
                            }
                            Text { text: "Same brightness control as the quick-settings flyout."; color: Theme.textSecondary; font.pixelSize: 11 }
                            Text { text: "AVAILABLE MODES"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Flow {
                                width: parent.width; spacing: 6
                                Repeater {
                                    model: displayTab.monitorData ? displayTab.monitorData.availableModes : []
                                    delegate: Rectangle {
                                        width: 140; height: 26; radius: 6; color: Theme.surfaceRaised
                                        opacity: displayTab.timerActive ? 0.4 : 1
                                        Text { anchors.centerIn: parent; text: modelData; font.pixelSize: 10; color: Theme.panelInk }
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
                                width: parent.width; height: 64; radius: 8; color: Theme.surfaceRaised
                                border.color: Theme.forge; border.width: 1
                                Column {
                                    anchors.centerIn: parent; spacing: 8
                                    Text {
                                        text: "Keep these display settings? Reverting in " + displayTab.secondsLeft + "s"
                                        color: Theme.panelInk; font.pixelSize: 13
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    Row {
                                        spacing: 10
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        Rectangle {
                                            width: 70; height: 24; radius: 6; color: Theme.forge
                                            Text { anchors.centerIn: parent; text: "Keep"; color: "#ffffff"; font.pixelSize: 11 }
                                            MouseArea { anchors.fill: parent; onClicked: { displayTab.timerActive = false; displayTab.refreshMonitor() } }
                                        }
                                        Rectangle {
                                            width: 70; height: 24; radius: 6; color: Theme.panel
                                            border.color: Theme.panelInk; border.width: 1
                                            Text { anchors.centerIn: parent; text: "Revert"; color: Theme.panelInk; font.pixelSize: 11 }
                                            MouseArea {
                                                anchors.fill: parent
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
                        }

                        // ===== Keyboard & Mouse (REAL) =====
                        Column {
                            id: inputTab
                            visible: settingsPanel.currentPage === "input"
                            width: parent.width; spacing: 10
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
                            Text { text: "KEYBOARD & MOUSE"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Text { text: "Touchpad natural scroll: " + inputTab.naturalScroll; color: Theme.panelInk; font.pixelSize: 12 }
                            Text { text: "Touchpad tap-to-click: " + inputTab.tapToClick; color: Theme.panelInk; font.pixelSize: 12 }
                            Text { text: "Pointer sensitivity: " + inputTab.sensitivity; color: Theme.panelInk; font.pixelSize: 12 }
                            Text { text: "(read-only for now - real Hyprland input values; editing lands in a later slice)"; color: Theme.textSecondary; font.pixelSize: 10 }
                            Text { text: "KEYBINDS"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Text {
                                width: parent.width
                                text: inputTab.keybindsText
                                color: Theme.panelInk; font.pixelSize: 11; font.family: "monospace"
                                wrapMode: Text.Wrap
                            }
                        }

                        // ===== Sound (existing, unchanged) =====
                        Column {
                            visible: settingsPanel.currentPage === "sound"
                            width: parent.width; spacing: 10
                            Text { text: "SOUND"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Text { text: "Same volume control as the quick-settings flyout."; color: Theme.textSecondary; font.pixelSize: 12; wrapMode: Text.Wrap; width: parent.width }
                        }

                        // ===== Network (REAL - live Wi-Fi scan + connect, replaces the old
                        // "open nmtui in a terminal" launcher per Akash's explicit request) =====
                        Column {
                            id: networkTab
                            visible: settingsPanel.currentPage === "network"
                            width: parent.width; spacing: 10
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

                            Text { text: "NETWORK"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Row {
                                spacing: 10
                                Text { anchors.verticalCenter: parent.verticalCenter; text: networkTab.radioOn ? "Wi-Fi: On" : "Wi-Fi: Off"; color: Theme.panelInk; font.pixelSize: 13 }
                                Rectangle {
                                    width: 38; height: 20; radius: 10
                                    color: networkTab.radioOn ? Theme.forge : Theme.panelInk
                                    opacity: networkTab.radioOn ? 1 : 0.25
                                    Rectangle { width: 16; height: 16; radius: 8; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter; x: networkTab.radioOn ? parent.width - width - 2 : 2 }
                                    MouseArea { anchors.fill: parent; onClicked: networkTab.toggleRadio() }
                                }
                            }
                            Row {
                                visible: networkTab.radioOn
                                spacing: 10
                                Rectangle {
                                    width: 70; height: 22; radius: 6; color: Theme.surfaceRaised
                                    Text { anchors.centerIn: parent; text: networkTab.busy ? "..." : "Refresh"; font.pixelSize: 10; color: Theme.panelInk }
                                    MouseArea { anchors.fill: parent; enabled: !networkTab.busy; onClicked: networkTab.refresh() }
                                }
                                Text {
                                    visible: networkTab.statusMsg.length > 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: networkTab.statusMsg; color: Theme.textSecondary; font.pixelSize: 11
                                }
                            }
                            Column {
                                visible: networkTab.radioOn
                                width: parent.width; spacing: 4
                                Text { visible: networkTab.networks.length === 0; text: networkTab.busy ? "Scanning..." : "No networks found."; color: Theme.textSecondary; font.pixelSize: 11 }
                                Repeater {
                                    model: networkTab.networks
                                    delegate: Column {
                                        width: parent.width
                                        property var netData: modelData
                                        spacing: 4
                                        Rectangle {
                                            width: parent.width; height: 34; radius: 6
                                            color: netData.connected ? Theme.surfaceRaised : "#00000000"
                                            Row {
                                                anchors.fill: parent; anchors.margins: 6; spacing: 8
                                                Item {
                                                    width: 18; height: 22
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Repeater {
                                                        model: 4
                                                        delegate: Rectangle {
                                                            width: 3; height: 5 + index * 3; x: index * 4; y: 14 - height
                                                            color: netData.signal >= (index + 1) * 25 ? Theme.forge : Theme.panelInk
                                                            opacity: netData.signal >= (index + 1) * 25 ? 1 : 0.25
                                                        }
                                                    }
                                                }
                                                Text {
                                                    width: 230; anchors.verticalCenter: parent.verticalCenter
                                                    text: netData.ssid + (netData.secured ? "  🔒" : "")
                                                    color: Theme.panelInk; font.pixelSize: 12; elide: Text.ElideRight
                                                }
                                                Text {
                                                    visible: netData.connected
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "Connected"; color: Theme.forge; font.pixelSize: 11
                                                }
                                                Rectangle {
                                                    visible: !netData.connected
                                                    width: 70; height: 22; radius: 4; color: Theme.forge
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Text { anchors.centerIn: parent; text: "Connect"; font.pixelSize: 10; color: "#ffffff" }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: {
                                                            if (netData.secured) {
                                                                networkTab.connectingSsid = (networkTab.connectingSsid === netData.ssid) ? "" : netData.ssid
                                                                networkTab.pwText = ""
                                                            } else {
                                                                networkTab.connectTo(netData.ssid, "")
                                                            }
                                                        }
                                                    }
                                                }
                                                Rectangle {
                                                    visible: netData.connected
                                                    width: 80; height: 22; radius: 4; color: Theme.range
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Text { anchors.centerIn: parent; text: "Disconnect"; font.pixelSize: 10; color: "#ffffff" }
                                                    MouseArea { anchors.fill: parent; onClicked: networkTab.disconnectWifi() }
                                                }
                                                Rectangle {
                                                    visible: netData.connected
                                                    width: 60; height: 22; radius: 4; color: Theme.panel
                                                    border.color: Theme.range; border.width: 1
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Text { anchors.centerIn: parent; text: "Forget"; font.pixelSize: 10; color: Theme.range }
                                                    MouseArea { anchors.fill: parent; onClicked: networkTab.forgetNetwork(netData.ssid) }
                                                }
                                            }
                                        }
                                        Rectangle {
                                            visible: networkTab.connectingSsid === netData.ssid
                                            width: parent.width; height: 34; radius: 6; color: Theme.surfaceRaised
                                            Row {
                                                anchors.fill: parent; anchors.margins: 6; spacing: 8
                                                Rectangle {
                                                    width: 180; height: 22; radius: 4; color: Theme.panel
                                                    border.color: Theme.panelInk; border.width: 1
                                                    TextInput {
                                                        anchors.fill: parent; anchors.margins: 4
                                                        color: Theme.panelInk; font.pixelSize: 12
                                                        echoMode: TextInput.Password
                                                        clip: true
                                                        focus: networkTab.connectingSsid === netData.ssid
                                                        onTextChanged: networkTab.pwText = text
                                                        Keys.onReturnPressed: networkTab.connectTo(netData.ssid, networkTab.pwText)
                                                    }
                                                }
                                                Rectangle {
                                                    width: 60; height: 22; radius: 4; color: Theme.forge
                                                    Text { anchors.centerIn: parent; text: "Connect"; font.pixelSize: 10; color: "#ffffff" }
                                                    MouseArea { anchors.fill: parent; onClicked: networkTab.connectTo(netData.ssid, networkTab.pwText) }
                                                }
                                                Rectangle {
                                                    width: 50; height: 22; radius: 4; color: Theme.panel
                                                    border.color: Theme.panelInk; border.width: 1
                                                    Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 10; color: Theme.panelInk }
                                                    MouseArea { anchors.fill: parent; onClicked: { networkTab.connectingSsid = ""; networkTab.pwText = "" } }
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
                            width: parent.width; spacing: 10
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

                            Text { text: "BLUETOOTH"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Row {
                                spacing: 10
                                Text { anchors.verticalCenter: parent.verticalCenter; text: btTab.powered ? "Bluetooth: On" : "Bluetooth: Off"; color: Theme.panelInk; font.pixelSize: 13 }
                                Rectangle {
                                    width: 38; height: 20; radius: 10
                                    color: btTab.powered ? Theme.forge : Theme.panelInk
                                    opacity: btTab.powered ? 1 : 0.25
                                    Rectangle { width: 16; height: 16; radius: 8; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter; x: btTab.powered ? parent.width - width - 2 : 2 }
                                    MouseArea { anchors.fill: parent; onClicked: btTab.togglePower() }
                                }
                            }
                            Text { text: "PAIRED DEVICES"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Column {
                                width: parent.width; spacing: 4
                                Text { visible: btTab.paired.length === 0; text: "No paired devices yet."; color: Theme.textSecondary; font.pixelSize: 11 }
                                Repeater {
                                    model: btTab.paired
                                    delegate: Rectangle {
                                        property var devData: modelData
                                        width: parent.width; height: 32; radius: 6; color: Theme.surfaceRaised
                                        Row {
                                            anchors.fill: parent; anchors.margins: 6; spacing: 8
                                            Text { width: 200; anchors.verticalCenter: parent.verticalCenter; text: devData.name; color: Theme.panelInk; font.pixelSize: 12; elide: Text.ElideRight }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: devData.connected ? "Connected" : "Paired"
                                                color: devData.connected ? Theme.forge : Theme.textSecondary; font.pixelSize: 11
                                            }
                                            Rectangle {
                                                width: 80; height: 22; radius: 4; color: devData.connected ? Theme.range : Theme.forge
                                                Text { anchors.centerIn: parent; text: devData.connected ? "Disconnect" : "Connect"; font.pixelSize: 10; color: "#ffffff" }
                                                MouseArea { anchors.fill: parent; onClicked: devData.connected ? btTab.btDisconnect(devData.mac) : btTab.btConnect(devData.mac) }
                                            }
                                            Rectangle {
                                                width: 60; height: 22; radius: 4; color: Theme.panel
                                                border.color: Theme.range; border.width: 1
                                                Text { anchors.centerIn: parent; text: "Remove"; font.pixelSize: 10; color: Theme.range }
                                                MouseArea { anchors.fill: parent; onClicked: btTab.btRemove(devData.mac) }
                                            }
                                        }
                                    }
                                }
                            }
                            Row {
                                spacing: 8
                                Text { anchors.verticalCenter: parent.verticalCenter; text: "NEARBY"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                                Rectangle {
                                    width: 130; height: 22; radius: 6; color: Theme.surfaceRaised
                                    Text { anchors.centerIn: parent; text: btTab.scanning ? "Scanning..." : "Scan (6s)"; font.pixelSize: 10; color: Theme.panelInk }
                                    MouseArea { anchors.fill: parent; enabled: !btTab.scanning; onClicked: btTab.startScan() }
                                }
                            }
                            Column {
                                width: parent.width; spacing: 4
                                Text { visible: !btTab.scanning && btTab.nearby.length === 0; text: "No nearby devices found yet - tap Scan."; color: Theme.textSecondary; font.pixelSize: 11 }
                                Repeater {
                                    model: btTab.nearby
                                    delegate: Rectangle {
                                        property var devData: modelData
                                        width: parent.width; height: 32; radius: 6; color: "#00000000"
                                        border.color: Theme.panelInk; border.width: 1; opacity: 0.7
                                        Row {
                                            anchors.fill: parent; anchors.margins: 6; spacing: 8
                                            Text { width: 260; anchors.verticalCenter: parent.verticalCenter; text: devData.name; color: Theme.panelInk; font.pixelSize: 12; elide: Text.ElideRight }
                                            Rectangle {
                                                width: 60; height: 22; radius: 4; color: Theme.forge
                                                Text { anchors.centerIn: parent; text: "Pair"; font.pixelSize: 10; color: "#ffffff" }
                                                MouseArea { anchors.fill: parent; onClicked: btTab.btPairAndConnect(devData.mac) }
                                            }
                                        }
                                    }
                                }
                            }
                            Text {
                                text: "Some devices need a physical confirmation button pressed on the device itself to finish pairing."
                                color: Theme.textSecondary; font.pixelSize: 10; wrapMode: Text.Wrap; width: parent.width
                            }
                        }

                        // ===== Applications (REAL - Task 22's real app catalog) =====
                        Column {
                            id: appsTab
                            visible: settingsPanel.currentPage === "apps"
                            width: parent.width; spacing: 10
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
                            Component.onCompleted: appsProc.running = true
                            Text { text: "APPLICATIONS"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Text { text: appsTab.apps.length + " installed applications (same catalog the dock/launcher use)"; color: Theme.textSecondary; font.pixelSize: 11 }
                            Column {
                                width: parent.width; spacing: 2
                                Repeater {
                                    model: appsTab.apps
                                    delegate: Rectangle {
                                        width: parent.width; height: 26; radius: 5
                                        color: appRowMouse.containsMouse ? Theme.surfaceRaised : "#00000000"
                                        Text {
                                            anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.name; color: Theme.panelInk; font.pixelSize: 12
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
                            width: parent.width; spacing: 10
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
                            Text { text: "AI"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Text { text: "Local runtime: Ollama"; color: Theme.panelInk; font.pixelSize: 13 }
                            Text {
                                text: aiTab.runningModels.length > 0
                                    ? ("Running: " + aiTab.runningModels[0].name + " (" + aiTab.runningModels[0].size_vram + " bytes VRAM)")
                                    : "No model currently loaded"
                                color: Theme.textSecondary; font.pixelSize: 12
                            }
                            Text { text: "INSTALLED MODELS"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Column {
                                width: parent.width; spacing: 4
                                Repeater {
                                    model: aiTab.installedModels
                                    delegate: Rectangle {
                                        width: parent.width; height: 44; radius: 6; color: Theme.surfaceRaised
                                        Column {
                                            anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                                            spacing: 2
                                            Text { text: modelData.name; color: Theme.panelInk; font.pixelSize: 12 }
                                            Text {
                                                text: modelData.details.parameter_size + " params, " + modelData.details.quantization_level + ", " + modelData.details.context_length + " ctx"
                                                color: Theme.textSecondary; font.pixelSize: 10
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ===== Privacy (PENDING) =====
                        Column {
                            visible: settingsPanel.currentPage === "privacy"
                            width: parent.width; spacing: 10
                            Text { text: "PRIVACY"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Text { text: "Not built yet - no AI feature tracks file/clipboard/screen access yet, so this page has nothing real to show until one does."; color: Theme.textSecondary; font.pixelSize: 12; wrapMode: Text.Wrap; width: parent.width }
                        }

                        // ===== Agents (REAL - Task 30) =====
                        Column {
                            id: agentsTab
                            visible: settingsPanel.currentPage === "agents"
                            width: parent.width; spacing: 12
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

                            Text { text: "AGENT PERMISSIONS"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Column {
                                width: parent.width; spacing: 4
                                Repeater {
                                    model: agentsTab.policyRows
                                    delegate: Rectangle {
                                        id: policyRow
                                        property var rowData: modelData
                                        width: parent.width; height: 30; radius: 6; color: Theme.surfaceRaised
                                        Row {
                                            anchors.fill: parent; anchors.margins: 6; spacing: 8
                                            Text {
                                                width: 160; anchors.verticalCenter: parent.verticalCenter
                                                text: policyRow.rowData.action_type; color: Theme.panelInk; font.pixelSize: 12
                                            }
                                            Text {
                                                width: 50; anchors.verticalCenter: parent.verticalCenter
                                                text: "[" + policyRow.rowData.tier + "]"; color: Theme.textSecondary; font.pixelSize: 11
                                            }
                                            Row {
                                                spacing: 4
                                                visible: policyRow.rowData.overridable
                                                Repeater {
                                                    model: ["allow", "ask", "deny"]
                                                    delegate: Rectangle {
                                                        property string optionValue: modelData
                                                        width: 46; height: 20; radius: 4
                                                        color: optionValue === policyRow.rowData.policy ? Theme.forge : Theme.panel
                                                        Text {
                                                            anchors.centerIn: parent; text: optionValue; font.pixelSize: 10
                                                            color: optionValue === policyRow.rowData.policy ? "#ffffff" : Theme.panelInk
                                                        }
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            onClicked: {
                                                                Quickshell.execDetached(["jazz-agent-action", "policy", "set", policyRow.rowData.action_type, optionValue])
                                                                agentsTab.refresh()
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            Text {
                                                visible: !policyRow.rowData.overridable
                                                text: "always ask"; color: Theme.textSecondary; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                    }
                                }
                            }
                            Text { text: "RECENT ACTIVITY"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Text {
                                width: parent.width
                                text: agentsTab.ledgerText
                                color: Theme.panelInk; font.pixelSize: 11; font.family: "monospace"
                                wrapMode: Text.Wrap
                            }
                        }

                        // ===== Storage (REAL - Track A) =====
                        Column {
                            id: storageTab
                            visible: settingsPanel.currentPage === "storage"
                            width: parent.width; spacing: 10
                            property string usedLine: "loading..."
                            Process {
                                running: storageTab.visible
                                command: ["bash", "-c", "df -h / | tail -1 | awk '{print $2\" total, \"$3\" used, \"$4\" available (\"$5\" used)\"}'"]
                                stdout: SplitParser { onRead: function (data) { if (data) storageTab.usedLine = data } }
                            }
                            Text { text: "STORAGE"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Text { text: storageTab.usedLine; color: Theme.panelInk; font.pixelSize: 13 }
                            Text { text: "Btrfs root, Snapper-protected (Track A)."; color: Theme.textSecondary; font.pixelSize: 11 }
                            Rectangle {
                                width: 180; height: 26; radius: 6; color: Theme.forge
                                Text { anchors.centerIn: parent; text: "Manage snapshots"; font.pixelSize: 11; color: "#ffffff" }
                                MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["kitty", "-e", "sudo", "snapper", "-c", "root", "list"]) }
                            }
                        }

                        // ===== Battery & Power (REAL) =====
                        Column {
                            id: powerTab
                            visible: settingsPanel.currentPage === "power"
                            width: parent.width; spacing: 10
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
                            Text { text: "BATTERY & POWER"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Text { text: powerTab.pct >= 0 ? (powerTab.pct + "% - " + powerTab.status) : "reading..."; color: Theme.panelInk; font.pixelSize: 16 }
                            Text { text: powerTab.watts >= 0 ? ("Power draw: " + powerTab.watts.toFixed(1) + " W") : ""; color: Theme.textSecondary; font.pixelSize: 12 }
                        }

                        // ===== Security (REAL) =====
                        Column {
                            id: securityTab
                            visible: settingsPanel.currentPage === "security"
                            width: parent.width; spacing: 8
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
                            Text { text: "SECURITY"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Text { text: "Firewall: " + securityTab.firewallStatus + " (" + securityTab.firewallRules + " allow rules)"; color: Theme.panelInk; font.pixelSize: 13 }
                            Text { text: "SSH: " + securityTab.sshStatus; color: Theme.panelInk; font.pixelSize: 13 }
                            Text { text: "Secure Boot: " + securityTab.secureBoot; color: Theme.panelInk; font.pixelSize: 13 }
                            Text { text: "Disk Encryption: " + securityTab.diskEncryption; color: Theme.panelInk; font.pixelSize: 13 }
                        }

                        // ===== Updates (REAL) =====
                        Column {
                            id: updatesTab
                            visible: settingsPanel.currentPage === "updates"
                            width: parent.width; spacing: 10
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
                            Text { text: "UPDATES"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Text {
                                text: !updatesTab.checked ? "Checking..." : (updatesTab.pending.length === 0 ? "System is up to date" : updatesTab.pending.length + " updates available")
                                color: Theme.panelInk; font.pixelSize: 15
                            }
                            Column {
                                width: parent.width; spacing: 2
                                Repeater {
                                    model: updatesTab.pending
                                    delegate: Text { text: modelData; color: Theme.textSecondary; font.pixelSize: 11; font.family: "monospace" }
                                }
                            }
                            Rectangle {
                                width: 110; height: 26; radius: 6; color: Theme.forge
                                Text { anchors.centerIn: parent; text: "Check Now"; font.pixelSize: 11; color: "#ffffff" }
                                MouseArea { anchors.fill: parent; onClicked: updatesTab.refresh() }
                            }
                        }

                        // ===== Accessibility (PENDING) =====
                        Column {
                            visible: settingsPanel.currentPage === "accessibility"
                            width: parent.width; spacing: 10
                            Text { text: "ACCESSIBILITY"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Text { text: "Not built yet - reduced motion and UI scaling (required by Task 28's acceptance criteria) land in a later slice, as real working controls, not stubs."; color: Theme.textSecondary; font.pixelSize: 12; wrapMode: Text.Wrap; width: parent.width }
                        }

                        // ===== System (REAL) =====
                        Column {
                            id: systemTab
                            visible: settingsPanel.currentPage === "system"
                            width: parent.width; spacing: 8
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
                            Text { text: "ABOUT"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Text { text: "JAZZ"; color: Theme.panelInk; font.pixelSize: 18; font.bold: true }
                            Text { text: "Arch Linux, hostname " + systemTab.hostname; color: Theme.panelInk; font.pixelSize: 12 }
                            Text { text: "Kernel " + systemTab.kernel; color: Theme.panelInk; font.pixelSize: 12 }
                            Text { text: "CPU: " + systemTab.cpu; color: Theme.panelInk; font.pixelSize: 12 }
                            Text { text: "GPU: " + systemTab.gpu; color: Theme.panelInk; font.pixelSize: 12 }
                            Text { text: "Memory: " + systemTab.mem; color: Theme.panelInk; font.pixelSize: 12 }
                            Rectangle {
                                width: 170; height: 26; radius: 6; color: Theme.forge
                                Text {
                                    anchors.centerIn: parent
                                    text: settingsPanel.devModeEnabled ? "Disable Developer Mode" : "Enable Developer Mode"
                                    font.pixelSize: 10; color: "#ffffff"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        var cmd = settingsPanel.devModeEnabled
                                            ? "rm -f @@JAZZ_CONFIG_DIR@@/dev-mode.enabled"
                                            : "mkdir -p @@JAZZ_CONFIG_DIR@@ && touch @@JAZZ_CONFIG_DIR@@/dev-mode.enabled"
                                        Quickshell.execDetached(["bash", "-c", cmd])
                                        settingsPanel.devModeEnabled = !settingsPanel.devModeEnabled
                                    }
                                }
                            }
                        }

                        // ===== Developer (PENDING, hidden by default) =====
                        Column {
                            visible: settingsPanel.currentPage === "developer"
                            width: parent.width; spacing: 10
                            Text { text: "DEVELOPER"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true }
                            Text { text: "Developer Mode is on. Deeper tools (Hyprland event log, D-Bus inspector) land in a later Task 28 slice - for now, use the Agents tab's ledger and a terminal."; color: Theme.textSecondary; font.pixelSize: 12; wrapMode: Text.Wrap; width: parent.width }
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
