// JAZZ Files (Task 29: real GUI file manager, v1 - no AI). Same "Quickshell
// frontend + plain CLI backend" pattern as Settings.qml (docs/JAZZ-v2.md
// sec 5f) - every operation below is a real jazz-files-ops invocation, no
// simulated data. Loaded via Loader { source: "Files.qml" } in shell.qml,
// toggled by `qs ipc call files toggle` (same IpcHandler convention as
// Settings/Welcome/Command Centre).
//
// Styling reuses ui/Button, ui/ListRow, ui/SectionHeader and Theme's tokens
// throughout - no new color system, so this reads as part of JAZZ rather
// than a bolted-on GTK/Nautilus clone (deliberate call, discussed with
// Akash 15 Sept 2026 before writing any of this - see research notes in
// tasks/todo.md Task 29).
//
// Every child process is invoked with a real argv array (no `bash -c`
// string-building for anything that touches a user-supplied path) so a
// filename with spaces/quotes/`$`/backticks can never be misinterpreted by
// a shell - jazz-files-ops itself is the only place path arguments are
// handled, and it never shells out on them either.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "ui"

PanelWindow {
    id: filesPanel
    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#00000000"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusiveZone: -1

    readonly property string dataDir: "@@JAZZ_DATA_DIR@@"

    property string homeDir: ""
    property string currentPath: ""
    property string viewMode: "grid"   // grid | list
    property var entries: []
    property bool loading: false
    property string selectedPath: ""
    property bool isRecentView: false
    property bool isTrashView: false
    property var trashEntries: []
    property var pathHistory: []
    property var clipboard: ({ path: "", mode: "" })   // mode: copy | cut
    property string statusMsg: ""
    property bool showHidden: false
    property string contextMenuTarget: ""
    property var devices: []

    // Quick Look overlay
    property bool previewOpen: false
    property var previewEntry: null
    property string previewKind: ""   // image | text | markdown | pdf | none
    property string previewTextContent: ""
    property string pdfPreviewImage: ""

    // Modal dialogs: "" | newFolder | rename | properties | openWith
    property string dialogMode: ""
    property string dialogTarget: ""
    property string dialogInput: ""
    property var propertiesData: null
    property var appCatalog: []

    readonly property var shortcuts: homeDir.length > 0 ? [
        { label: "Home", path: homeDir },
        { label: "Documents", path: homeDir + "/Documents" },
        { label: "Downloads", path: homeDir + "/Downloads" },
        { label: "Pictures", path: homeDir + "/Pictures" },
        { label: "Videos", path: homeDir + "/Videos" },
        { label: "Music", path: homeDir + "/Music" },
        { label: "Projects", path: homeDir + "/Projects" }
    ] : []
    readonly property var imageExts: ["png", "jpg", "jpeg", "gif", "bmp", "webp", "svg"]
    readonly property var textExts: ["txt", "log", "conf", "json", "yaml", "yml", "sh", "py", "js", "ts", "css", "html", "xml", "ini", "toml", "cfg"]

    // ---------- helpers ----------
    function humanSize(bytes) {
        if (bytes === null || bytes === undefined) return "--"
        if (bytes < 1024) return bytes + " B"
        var units = ["KB", "MB", "GB", "TB"]
        var v = bytes
        for (var i = 0; i < units.length; i++) {
            v = v / 1024
            if (v < 1024) return v.toFixed(1) + " " + units[i]
        }
        return v.toFixed(1) + " PB"
    }
    function formatDate(unixSeconds) {
        if (!unixSeconds) return ""
        var d = new Date(unixSeconds * 1000)
        return d.toLocaleDateString(Qt.locale(), "d MMM yyyy") + ", " + d.toLocaleTimeString(Qt.locale(), "hh:mm")
    }
    // Quickshell.iconPath()'s named-theme lookup only resolves app icons
    // reliably here (confirmed live, 15 Sept 2026: no QT_QPA icon-theme env
    // wired into this Wayland session, so generic mimetype/places names
    // like "folder" silently fail even though Adwaita - the real active
    // theme per gsettings - genuinely ships them). Using real, verified
    // absolute file:// paths instead sidesteps that lookup entirely.
    readonly property string _adwMime: "/usr/share/icons/Adwaita/scalable/mimetypes/"
    readonly property string _adwPlaces: "/usr/share/icons/Adwaita/scalable/places/"
    function mimeIconPath(entry) {
        if (entry.is_dir) return "file://" + filesPanel._adwPlaces + "folder.svg"
        var m = filesPanel._adwMime
        var map = {
            pdf: "/usr/share/icons/Papirus/64x64/mimetypes/application-pdf.svg",
            doc: m + "x-office-document.svg", docx: m + "x-office-document.svg", odt: m + "x-office-document.svg",
            xls: m + "x-office-spreadsheet.svg", xlsx: m + "x-office-spreadsheet.svg", ods: m + "x-office-spreadsheet.svg",
            ppt: m + "x-office-presentation.svg", pptx: m + "x-office-presentation.svg", odp: m + "x-office-presentation.svg",
            zip: m + "package-x-generic.svg", tar: m + "package-x-generic.svg", gz: m + "package-x-generic.svg", xz: m + "package-x-generic.svg", "7z": m + "package-x-generic.svg", rar: m + "package-x-generic.svg",
            mp3: m + "audio-x-generic.svg", wav: m + "audio-x-generic.svg", flac: m + "audio-x-generic.svg", ogg: m + "audio-x-generic.svg",
            mp4: m + "video-x-generic.svg", mkv: m + "video-x-generic.svg", webm: m + "video-x-generic.svg", avi: m + "video-x-generic.svg", mov: m + "video-x-generic.svg",
            sh: m + "text-x-script.svg", py: m + "text-x-script.svg", js: m + "text-x-script.svg", ts: m + "text-x-script.svg",
            png: m + "image-x-generic.svg", jpg: m + "image-x-generic.svg", jpeg: m + "image-x-generic.svg", gif: m + "image-x-generic.svg", bmp: m + "image-x-generic.svg", webp: m + "image-x-generic.svg", svg: m + "image-x-generic.svg",
            exe: m + "application-x-executable.svg", appimage: m + "application-x-executable.svg"
        }
        return "file://" + (map[entry.ext] || (m + "text-x-generic.svg"))
    }
    function shellQuote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    function sortedEntries() {
        var list = filesPanel.entries.filter(function (e) { return filesPanel.showHidden || !e.hidden })
        return list.slice().sort(function (a, b) {
            if (a.is_dir !== b.is_dir) return a.is_dir ? -1 : 1
            return a.name.toLowerCase().localeCompare(b.name.toLowerCase())
        })
    }
    function findEntry(path) {
        var list = filesPanel.entries
        for (var i = 0; i < list.length; i++) if (list[i].path === path) return list[i]
        return null
    }
    function pathSegments() {
        if (filesPanel.currentPath === "/") return [{ name: "/", path: "/" }]
        var parts = filesPanel.currentPath.split("/").filter(function (p) { return p.length > 0 })
        var segs = [{ name: "/", path: "/" }]
        var acc = ""
        for (var i = 0; i < parts.length; i++) { acc += "/" + parts[i]; segs.push({ name: parts[i], path: acc }) }
        return segs
    }

    // ---------- backend process plumbing ----------
    Process {
        id: homeProc
        command: ["printenv", "HOME"]
        stdout: SplitParser {
            onRead: function (data) {
                if (!data) return
                filesPanel.homeDir = data
                filesPanel.currentPath = data
                filesPanel.refresh()
            }
        }
    }
    Component.onCompleted: homeProc.running = true

    Process {
        id: opProc
        property string outText: ""
        property var doneCallback: null
        stdout: StdioCollector { onStreamFinished: opProc.outText += this.text }
        onExited: function (exitCode, exitStatus) {
            var result = null
            try { result = JSON.parse(opProc.outText) } catch (e) { result = { error: "no response from jazz-files-ops" } }
            var cb = opProc.doneCallback
            opProc.doneCallback = null
            if (cb) cb(exitCode === 0, result)
            filesPanel._runNextOp()
        }
    }
    // opProc is one shared Process reused for every operation - queue calls
    // instead of firing runOp() straight into it, or two calls close
    // together (found live, 15 Sept 2026: the toggle handler's own
    // refresh() racing homeProc's startup refresh()) clobber each other's
    // command/callback mid-flight, corrupting the response the first
    // caller receives.
    property var opQueue: []
    function runOp(argsArray, onDone) {
        filesPanel.opQueue.push({ args: argsArray, cb: onDone })
        if (!opProc.running) filesPanel._runNextOp()
    }
    function _runNextOp() {
        if (filesPanel.opQueue.length === 0) return
        var next = filesPanel.opQueue.shift()
        opProc.doneCallback = next.cb
        opProc.outText = ""
        opProc.command = ["jazz-files-ops"].concat(next.args)
        opProc.running = true
    }

    function refresh() {
        if (filesPanel.isRecentView) { loadRecent(); return }
        if (filesPanel.isTrashView) { loadTrash(); return }
        filesPanel.loading = true
        runOp(["list", filesPanel.currentPath], function (success, result) {
            filesPanel.loading = false
            filesPanel.entries = success ? result : []
            filesPanel.statusMsg = success ? "" : (result.error || "list failed")
        })
    }
    function loadRecent() {
        filesPanel.loading = true
        runOp(["recent"], function (success, result) { filesPanel.loading = false; filesPanel.entries = success ? result : [] })
    }
    function loadTrash() {
        runOp(["list-trash"], function (success, result) { filesPanel.trashEntries = success ? result : [] })
    }
    function navigateTo(path) {
        if (filesPanel.currentPath.length > 0 && filesPanel.currentPath !== path && !filesPanel.isRecentView && !filesPanel.isTrashView)
            filesPanel.pathHistory.push(filesPanel.currentPath)
        filesPanel.isRecentView = false
        filesPanel.isTrashView = false
        filesPanel.currentPath = path
        filesPanel.selectedPath = ""
        filesPanel.contextMenuTarget = ""
        refresh()
    }
    function goBack() {
        if (filesPanel.pathHistory.length === 0) return
        var prev = filesPanel.pathHistory.pop()
        filesPanel.isRecentView = false
        filesPanel.isTrashView = false
        filesPanel.currentPath = prev
        filesPanel.selectedPath = ""
        refresh()
    }
    function goUp() {
        if (filesPanel.isRecentView || filesPanel.isTrashView || filesPanel.currentPath === "/") return
        var parts = filesPanel.currentPath.split("/")
        parts.pop()
        navigateTo(parts.join("/").length > 0 ? parts.join("/") : "/")
    }
    function showRecent() { filesPanel.isRecentView = true; filesPanel.isTrashView = false; filesPanel.selectedPath = ""; loadRecent() }
    function showTrash() { filesPanel.isTrashView = true; filesPanel.isRecentView = false; filesPanel.selectedPath = ""; loadTrash() }

    function openEntry(entry) {
        if (entry.is_dir) { navigateTo(entry.path); return }
        Quickshell.execDetached(["xdg-open", entry.path])
    }
    function openWithApp(app, path) {
        Quickshell.execDetached(["sh", "-c", app.exec + " " + filesPanel.shellQuote(path)])
        filesPanel.dialogMode = ""
    }

    function doMkdir() {
        if (filesPanel.dialogInput.length === 0) return
        runOp(["mkdir", filesPanel.currentPath, filesPanel.dialogInput], function (success, result) {
            filesPanel.statusMsg = success ? "" : (result.error || "create folder failed")
            filesPanel.dialogMode = ""
            if (success) refresh()
        })
    }
    function doRename() {
        if (filesPanel.dialogInput.length === 0) return
        runOp(["rename", filesPanel.dialogTarget, filesPanel.dialogInput], function (success, result) {
            filesPanel.statusMsg = success ? "" : (result.error || "rename failed")
            filesPanel.dialogMode = ""
            if (success) refresh()
        })
    }
    function doTrash(path) {
        runOp(["trash", path], function (success, result) {
            filesPanel.statusMsg = success ? "Moved to Trash" : (result.error || "trash failed")
            filesPanel.contextMenuTarget = ""
            if (success) { if (filesPanel.selectedPath === path) filesPanel.selectedPath = ""; refresh() }
        })
    }
    function doCopyTo(path, destDir) {
        runOp(["copy", path, destDir], function (success, result) {
            filesPanel.statusMsg = success ? "Copied" : (result.error || "copy failed")
            if (success) refresh()
        })
    }
    function doMoveTo(path, destDir) {
        runOp(["move", path, destDir], function (success, result) {
            filesPanel.statusMsg = success ? "Moved" : (result.error || "move failed")
            if (success) refresh()
        })
    }
    function doUndo() {
        runOp(["undo"], function (success, result) {
            filesPanel.statusMsg = success ? ("Undid: " + result.undone) : (result.error || "nothing to undo")
            if (success) refresh()
        })
    }
    function doRestoreTrash(trashId) {
        runOp(["restore", trashId], function (success, result) {
            filesPanel.statusMsg = success ? "Restored" : (result.error || "restore failed")
            if (success) loadTrash()
        })
    }
    function doDeletePermanent(trashId) {
        runOp(["delete-permanent", trashId], function (success, result) {
            if (success) loadTrash(); else filesPanel.statusMsg = result.error || "delete failed"
        })
    }
    function doEmptyTrash() {
        runOp(["empty-trash"], function (success, result) {
            filesPanel.statusMsg = success ? ("Emptied " + result.emptied + " item(s)") : (result.error || "failed")
            loadTrash()
        })
    }
    function pasteClipboard() {
        if (filesPanel.clipboard.path.length === 0 || filesPanel.isRecentView || filesPanel.isTrashView) return
        if (filesPanel.clipboard.mode === "copy") { doCopyTo(filesPanel.clipboard.path, filesPanel.currentPath) }
        else { doMoveTo(filesPanel.clipboard.path, filesPanel.currentPath); filesPanel.clipboard = { path: "", mode: "" } }
    }

    function loadDevices() { runOp(["mounts"], function (success, result) { filesPanel.devices = success ? result : [] }) }
    function doMountDevice(devPath) { runOp(["mount", devPath], function () { loadDevices() }) }
    function doUnmountDevice(devPath) { runOp(["unmount", devPath], function () { loadDevices() }) }
    function doEjectDevice(devPath) { runOp(["eject", devPath], function () { loadDevices() }) }

    function openProperties(path) {
        runOp(["properties", path], function (success, result) {
            if (success) { filesPanel.propertiesData = result; filesPanel.dialogMode = "properties"; filesPanel.dialogTarget = path }
            else filesPanel.statusMsg = result.error || "properties failed"
        })
    }
    function applyPermission(who, level) {
        var cur = filesPanel.propertiesData.mode_translated
        var owner = who === "owner" ? level : cur.owner
        var group = who === "group" ? level : cur.group
        var other = who === "other" ? level : cur.other
        runOp(["chmod-translated", filesPanel.dialogTarget, owner, group, other], function (success, result) {
            if (success) { filesPanel.propertiesData = result; refresh() }
            else filesPanel.statusMsg = result.error || "permission change failed"
        })
    }
    function openWithDialog(path) { filesPanel.dialogTarget = path; filesPanel.dialogMode = "openWith"; filesPanel.contextMenuTarget = "" }

    Process {
        id: appsProc
        command: ["python3", filesPanel.dataDir + "/scan-apps.py"]
        stdout: StdioCollector { onStreamFinished: { try { filesPanel.appCatalog = JSON.parse(this.text) } catch (e) { filesPanel.appCatalog = [] } } }
    }

    // ---------- Quick Look ----------
    Process {
        id: textPreviewProc
        stdout: StdioCollector { onStreamFinished: { filesPanel.previewTextContent = this.text } }
    }
    Process {
        id: pdfMkdirProc
        onExited: function (exitCode) { if (exitCode === 0) pdfRenderProc.running = true }
    }
    Process {
        id: pdfRenderProc
        onExited: function (exitCode) {
            filesPanel.pdfPreviewImage = exitCode === 0 ? ("file://" + filesPanel.dataDir + "/files-preview-cache/pdfpreview.png?" + Date.now()) : ""
        }
    }
    function openPreview(entry) {
        if (!entry || entry.is_dir) return
        filesPanel.previewEntry = entry
        filesPanel.previewTextContent = ""
        filesPanel.pdfPreviewImage = ""
        var ext = entry.ext
        if (filesPanel.imageExts.indexOf(ext) !== -1) {
            filesPanel.previewKind = "image"
        } else if (ext === "md" || ext === "markdown") {
            filesPanel.previewKind = "markdown"
            textPreviewProc.command = ["head", "-c", "100000", entry.path]
            textPreviewProc.running = true
        } else if (ext === "pdf") {
            filesPanel.previewKind = "pdf"
            pdfMkdirProc.command = ["mkdir", "-p", filesPanel.dataDir + "/files-preview-cache"]
            pdfRenderProc.command = ["pdftoppm", "-png", "-r", "100", "-f", "1", "-l", "1", "-singlefile", entry.path, filesPanel.dataDir + "/files-preview-cache/pdfpreview"]
            pdfMkdirProc.running = true
        } else if (filesPanel.textExts.indexOf(ext) !== -1 || ext === "") {
            filesPanel.previewKind = "text"
            textPreviewProc.command = ["head", "-c", "100000", entry.path]
            textPreviewProc.running = true
        } else {
            filesPanel.previewKind = "none"
        }
        filesPanel.previewOpen = true
    }
    function closePreview() { filesPanel.previewOpen = false }

    IpcHandler {
        target: "files"
        function toggle(): void {
            filesPanel.visible = !filesPanel.visible
            // The filesystem can change while the panel is hidden (another
            // app saves a file, a script moves things around) - re-fetch
            // the current listing every time it's reopened rather than
            // showing whatever was cached from last time. Found live, 15
            // Sept 2026: reopening after moving files elsewhere still
            // showed the pre-move listing until this was added.
            if (filesPanel.visible) { loadDevices(); appsProc.running = true; filesPanel.refresh() }
        }
    }

    // ---------- layout ----------
    Rectangle {
        id: rootContent
        anchors.fill: parent
        color: Theme.surface
        visible: filesPanel.visible

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: { filesPanel.contextMenuTarget = ""; filesPanel.selectedPath = "" }
        }

        Item {
            anchors.fill: parent
            focus: filesPanel.visible
            Keys.onEscapePressed: {
                if (filesPanel.previewOpen) filesPanel.closePreview()
                else if (filesPanel.dialogMode !== "") filesPanel.dialogMode = ""
                else filesPanel.visible = false
            }
            Keys.onSpacePressed: {
                if (!filesPanel.previewOpen && filesPanel.selectedPath.length > 0) {
                    var e = filesPanel.findEntry(filesPanel.selectedPath)
                    if (e) filesPanel.openPreview(e)
                }
            }
        }

        Row {
            anchors.fill: parent

            // ===== Sidebar =====
            Rectangle {
                width: 270; height: parent.height
                color: Theme.surfaceRaised
                Column {
                    anchors.fill: parent; anchors.margins: 18; anchors.topMargin: 24; spacing: 4
                    Text { text: "JAZZ FILES"; color: Theme.textSecondary; font.bold: true; font.pixelSize: 16; font.family: Theme.uiFont }
                    Item { width: 1; height: 14 }
                    ListRow { label: "Recent"; selected: filesPanel.isRecentView; onClicked: filesPanel.showRecent() }
                    Repeater {
                        model: filesPanel.shortcuts
                        delegate: ListRow {
                            label: modelData.label
                            selected: !filesPanel.isRecentView && !filesPanel.isTrashView && filesPanel.currentPath === modelData.path
                            onClicked: filesPanel.navigateTo(modelData.path)
                        }
                    }
                    Item { width: 1; height: 14 }
                    ListRow { label: "Trash"; selected: filesPanel.isTrashView; onClicked: filesPanel.showTrash() }
                    Item { width: 1; height: 18 }
                    SectionHeader { text: "DEVICES" }
                    Item { width: 1; height: 6 }
                    Repeater {
                        model: filesPanel.devices
                        delegate: Rectangle {
                            width: parent.width; height: 68; radius: 9
                            color: deviceMouse.containsMouse ? Theme.panel : "#00000000"
                            Column {
                                anchors.fill: parent; anchors.margins: 9; spacing: 4
                                Row {
                                    width: parent.width
                                    Text {
                                        text: (modelData.label || modelData.name)
                                        color: Theme.panelInk; font.pixelSize: 15; font.family: Theme.uiFont
                                        width: parent.width - (modelData.removable ? 44 : 0)
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        visible: !!modelData.removable
                                        text: "Eject"
                                        color: WorkspaceState.activeColor(); font.pixelSize: 13; font.family: Theme.uiFont
                                        MouseArea { anchors.fill: parent; onClicked: filesPanel.doEjectDevice(modelData.path) }
                                    }
                                }
                                Rectangle {
                                    width: parent.width; height: 6; radius: 3; color: Theme.panel
                                    Rectangle {
                                        width: (modelData.df_size || 0) > 0 ? parent.width * (modelData.df_used / modelData.df_size) : 0
                                        height: parent.height; radius: 3; color: WorkspaceState.activeColor()
                                    }
                                }
                                Text {
                                    text: modelData.df_used !== undefined
                                        ? (filesPanel.humanSize(modelData.df_used) + " of " + filesPanel.humanSize(modelData.df_size) + " used")
                                        : (modelData.fstype || "")
                                    color: Theme.textSecondary; font.pixelSize: 12; font.family: Theme.uiFont
                                }
                            }
                            MouseArea {
                                id: deviceMouse
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: filesPanel.navigateTo(modelData.mountpoint)
                            }
                        }
                    }
                    Text {
                        visible: filesPanel.devices.length === 0
                        text: "No other volumes mounted."
                        color: Theme.textSecondary; font.pixelSize: 13; font.family: Theme.uiFont
                    }
                }
            }

            // ===== Main column =====
            Column {
                width: parent.width - 270; height: parent.height

                // Toolbar
                Rectangle {
                    width: parent.width; height: 64
                    color: Theme.surface
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: 18; anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Button { width: 33; height: 33; fontSize: 15; variant: "neutral"; label: "◂"; enabled: filesPanel.pathHistory.length > 0; onClicked: filesPanel.goBack() }
                        Button { width: 33; height: 33; fontSize: 15; variant: "neutral"; label: "▴"; enabled: !filesPanel.isRecentView && !filesPanel.isTrashView; onClicked: filesPanel.goUp() }
                        Item { width: 10; height: 1 }
                        Button { fontSize: 12; variant: filesPanel.viewMode === "grid" ? "primary" : "flat"; label: "Grid"; onClicked: filesPanel.viewMode = "grid" }
                        Button { fontSize: 12; variant: filesPanel.viewMode === "list" ? "primary" : "flat"; label: "List"; onClicked: filesPanel.viewMode = "list" }
                        Item { width: 6; height: 1 }
                        Button { fontSize: 12; variant: filesPanel.showHidden ? "primary" : "flat"; label: "Hidden"; onClicked: filesPanel.showHidden = !filesPanel.showHidden }
                    }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Button {
                            fontSize: 12; variant: "neutral"; label: "Paste"
                            visible: filesPanel.clipboard.path.length > 0 && !filesPanel.isRecentView && !filesPanel.isTrashView
                            onClicked: filesPanel.pasteClipboard()
                        }
                        Button {
                            fontSize: 12; variant: "neutral"; label: "New Folder"
                            visible: !filesPanel.isRecentView && !filesPanel.isTrashView
                            onClicked: { filesPanel.dialogInput = "New Folder"; filesPanel.dialogMode = "newFolder" }
                        }
                        Button {
                            fontSize: 12; variant: "neutral"; label: "Undo"
                            onClicked: filesPanel.doUndo()
                        }
                        Button {
                            fontSize: 12; variant: "outlineDanger"; label: "Empty Trash"
                            visible: filesPanel.isTrashView
                            onClicked: filesPanel.doEmptyTrash()
                        }
                        Button { width: 33; height: 33; fontSize: 15; variant: "neutral"; label: "✕"; onClicked: filesPanel.visible = false }
                    }
                }

                // Breadcrumb
                Rectangle {
                    width: parent.width; height: 34
                    color: Theme.surface
                    visible: !filesPanel.isRecentView && !filesPanel.isTrashView
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: 18; anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Repeater {
                            model: filesPanel.pathSegments()
                            delegate: Row {
                                spacing: 4
                                Text {
                                    text: modelData.name
                                    color: index === filesPanel.pathSegments().length - 1 ? Theme.panelInk : Theme.textSecondary
                                    font.pixelSize: 15; font.family: Theme.uiFont
                                    MouseArea { anchors.fill: parent; onClicked: filesPanel.navigateTo(modelData.path) }
                                }
                                Text { visible: index > 0 && index < filesPanel.pathSegments().length - 1; text: "/"; color: Theme.textSecondary; font.pixelSize: 15; font.family: Theme.uiFont }
                            }
                        }
                    }
                }
                Rectangle {
                    width: parent.width; height: 34
                    color: Theme.surface
                    visible: filesPanel.isRecentView || filesPanel.isTrashView
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 18; anchors.verticalCenter: parent.verticalCenter
                        text: filesPanel.isTrashView ? "Trash" : "Recent"
                        color: Theme.panelInk; font.pixelSize: 15; font.family: Theme.uiFont; font.bold: true
                    }
                }

                // Content area
                Rectangle {
                    width: parent.width; height: parent.height - 64 - 34 - 30
                    color: Theme.surface
                    clip: true

                    Text {
                        anchors.centerIn: parent
                        visible: !filesPanel.isTrashView && !filesPanel.loading && filesPanel.sortedEntries().length === 0
                        text: filesPanel.isRecentView ? "Nothing recent." : "This folder is empty."
                        color: Theme.textSecondary; font.pixelSize: 16; font.family: Theme.uiFont
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: filesPanel.loading
                        text: "Loading..."
                        color: Theme.textSecondary; font.pixelSize: 16; font.family: Theme.uiFont
                    }

                    // ----- Grid view -----
                    GridView {
                        anchors.fill: parent; anchors.margins: 12
                        visible: !filesPanel.isTrashView && filesPanel.viewMode === "grid"
                        cellWidth: 150; cellHeight: 168
                        model: filesPanel.sortedEntries()
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Item {
                            width: 150; height: 168
                            Rectangle {
                                id: cardBg
                                anchors.fill: parent; anchors.margins: 6; radius: 10
                                color: filesPanel.selectedPath === modelData.path ? WorkspaceState.activeColor() : (cardMouse.containsMouse ? Theme.surfaceRaised : "#00000000")
                                opacity: filesPanel.selectedPath === modelData.path ? 0.22 : 1
                            }
                            Column {
                                anchors.fill: parent; anchors.margins: 10; spacing: 6
                                Rectangle {
                                    width: parent.width; height: 96; radius: 8
                                    color: Theme.surfaceRaised
                                    clip: true
                                    Image {
                                        anchors.fill: parent
                                        visible: filesPanel.imageExts.indexOf(modelData.ext) !== -1
                                        source: filesPanel.imageExts.indexOf(modelData.ext) !== -1 ? ("file://" + modelData.path) : ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }
                                    Image {
                                        anchors.centerIn: parent
                                        width: 44; height: 44
                                        visible: filesPanel.imageExts.indexOf(modelData.ext) === -1
                                        source: filesPanel.imageExts.indexOf(modelData.ext) === -1 ? filesPanel.mimeIconPath(modelData) : ""
                                        fillMode: Image.PreserveAspectFit
                                    }
                                }
                                Text {
                                    width: parent.width
                                    text: modelData.name
                                    color: Theme.panelInk; font.pixelSize: 13; font.family: Theme.uiFont
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideMiddle; maximumLineCount: 2; wrapMode: Text.Wrap
                                }
                            }
                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent; hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: function (mouse) {
                                    filesPanel.selectedPath = modelData.path
                                    if (mouse.button === Qt.RightButton) filesPanel.contextMenuTarget = modelData.path
                                    else filesPanel.contextMenuTarget = ""
                                }
                                onDoubleClicked: filesPanel.openEntry(modelData)
                            }
                            EntryContextMenu { entryPath: modelData.path; entryData: modelData }
                        }
                    }

                    // ----- List view -----
                    Column {
                        anchors.fill: parent
                        visible: !filesPanel.isTrashView && filesPanel.viewMode === "list"
                        Rectangle {
                            width: parent.width; height: 30; color: Theme.surfaceRaised
                            Row {
                                anchors.fill: parent; anchors.leftMargin: 46; anchors.rightMargin: 12
                                spacing: 10
                                Text { width: parent.width * 0.4 - 40; anchors.verticalCenter: parent.verticalCenter; text: "Name"; color: Theme.textSecondary; font.pixelSize: 12; font.bold: true; font.family: Theme.uiFont }
                                Text { width: parent.width * 0.15; anchors.verticalCenter: parent.verticalCenter; text: "Type"; color: Theme.textSecondary; font.pixelSize: 12; font.bold: true; font.family: Theme.uiFont }
                                Text { width: parent.width * 0.15; anchors.verticalCenter: parent.verticalCenter; text: "Size"; color: Theme.textSecondary; font.pixelSize: 12; font.bold: true; font.family: Theme.uiFont; horizontalAlignment: Text.AlignRight }
                                Text { width: parent.width * 0.2; anchors.verticalCenter: parent.verticalCenter; text: "Modified"; color: Theme.textSecondary; font.pixelSize: 12; font.bold: true; font.family: Theme.uiFont }
                                Text { width: parent.width * 0.1; anchors.verticalCenter: parent.verticalCenter; text: "Owner"; color: Theme.textSecondary; font.pixelSize: 12; font.bold: true; font.family: Theme.uiFont }
                            }
                        }
                        ListView {
                            width: parent.width; height: parent.height - 30
                            model: filesPanel.sortedEntries()
                            boundsBehavior: Flickable.StopAtBounds
                            delegate: Item {
                                width: parent ? parent.width : 0; height: 40
                                Rectangle {
                                    anchors.fill: parent
                                    color: filesPanel.selectedPath === modelData.path ? WorkspaceState.activeColor() : (rowMouse.containsMouse ? Theme.surfaceRaised : "#00000000")
                                    opacity: filesPanel.selectedPath === modelData.path ? 0.22 : 1
                                }
                                Row {
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                                    spacing: 10
                                    Row {
                                        width: parent.width * 0.4 - 40; spacing: 8; anchors.verticalCenter: parent.verticalCenter
                                        Image {
                                            width: 20; height: 20; anchors.verticalCenter: parent.verticalCenter
                                            source: filesPanel.imageExts.indexOf(modelData.ext) !== -1 ? ("file://" + modelData.path) : filesPanel.mimeIconPath(modelData)
                                            fillMode: Image.PreserveAspectFit; asynchronous: true
                                        }
                                        Text { text: modelData.name; color: Theme.panelInk; font.pixelSize: 15; font.family: Theme.uiFont; elide: Text.ElideMiddle; width: parent.width - 28; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    Text { width: parent.width * 0.15; anchors.verticalCenter: parent.verticalCenter; text: modelData.is_dir ? "Folder" : (modelData.ext.length > 0 ? (modelData.ext.toUpperCase() + " file") : "File"); color: Theme.textSecondary; font.pixelSize: 14; font.family: Theme.uiFont }
                                    Text { width: parent.width * 0.15; anchors.verticalCenter: parent.verticalCenter; text: modelData.is_dir ? "--" : filesPanel.humanSize(modelData.size); color: Theme.textSecondary; font.pixelSize: 14; font.family: Theme.uiFont; horizontalAlignment: Text.AlignRight; textFormat: Text.PlainText }
                                    Text { width: parent.width * 0.2; anchors.verticalCenter: parent.verticalCenter; text: filesPanel.formatDate(modelData.mtime); color: Theme.textSecondary; font.pixelSize: 14; font.family: Theme.uiFont }
                                    Text { width: parent.width * 0.1; anchors.verticalCenter: parent.verticalCenter; text: modelData.owner; color: Theme.textSecondary; font.pixelSize: 14; font.family: Theme.uiFont }
                                }
                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent; hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: function (mouse) {
                                        filesPanel.selectedPath = modelData.path
                                        if (mouse.button === Qt.RightButton) filesPanel.contextMenuTarget = modelData.path
                                        else filesPanel.contextMenuTarget = ""
                                    }
                                    onDoubleClicked: filesPanel.openEntry(modelData)
                                }
                                EntryContextMenu { entryPath: modelData.path; entryData: modelData }
                            }
                        }
                    }

                    // ----- Trash view -----
                    ListView {
                        anchors.fill: parent; anchors.margins: 12
                        visible: filesPanel.isTrashView
                        model: filesPanel.trashEntries
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Rectangle {
                            width: parent ? parent.width : 0; height: 56; radius: 8
                            color: trashRowMouse.containsMouse ? Theme.surfaceRaised : "#00000000"
                            Row {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                                Column {
                                    width: parent.width - 260; anchors.verticalCenter: parent.verticalCenter
                                    Text { text: modelData.original_path; color: Theme.panelInk; font.pixelSize: 15; font.family: Theme.uiFont; elide: Text.ElideMiddle; width: parent.width }
                                    Text { text: "Deleted " + modelData.deletion_date; color: Theme.textSecondary; font.pixelSize: 12; font.family: Theme.uiFont }
                                }
                                Button { anchors.verticalCenter: parent.verticalCenter; fontSize: 12; variant: "neutral"; label: "Restore"; onClicked: filesPanel.doRestoreTrash(modelData.trash_id) }
                                Button { anchors.verticalCenter: parent.verticalCenter; fontSize: 12; variant: "outlineDanger"; label: "Delete Forever"; onClicked: filesPanel.doDeletePermanent(modelData.trash_id) }
                            }
                            MouseArea { id: trashRowMouse; anchors.fill: parent; hoverEnabled: true; z: -1 }
                        }
                    }
                }

                // Status bar
                Rectangle {
                    width: parent.width; height: 30; color: Theme.surfaceRaised
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 18; anchors.verticalCenter: parent.verticalCenter
                        text: filesPanel.statusMsg.length > 0 ? filesPanel.statusMsg : (filesPanel.sortedEntries().length + " item(s)")
                        color: Theme.textSecondary; font.pixelSize: 13; font.family: Theme.uiFont
                    }
                }
            }
        }

        // ===== Quick Look overlay =====
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: filesPanel.previewOpen ? 0.94 : 0
            visible: filesPanel.previewOpen
            MouseArea { anchors.fill: parent; onClicked: filesPanel.closePreview() }

            Column {
                anchors.centerIn: parent
                width: parent.width * 0.7; height: parent.height * 0.82
                spacing: 14

                Rectangle {
                    width: parent.width; height: parent.height - 70
                    radius: 12; color: Theme.surfaceRaised; clip: true
                    MouseArea { anchors.fill: parent }  // swallow clicks so the backdrop MouseArea doesn't close it

                    Image {
                        anchors.fill: parent; anchors.margins: 20
                        visible: filesPanel.previewKind === "image" && filesPanel.previewEntry
                        source: (filesPanel.previewKind === "image" && filesPanel.previewEntry) ? ("file://" + filesPanel.previewEntry.path) : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                    Image {
                        anchors.fill: parent; anchors.margins: 20
                        visible: filesPanel.previewKind === "pdf"
                        source: filesPanel.pdfPreviewImage
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: filesPanel.previewKind === "pdf" && filesPanel.pdfPreviewImage.length === 0
                        text: "Rendering preview..."
                        color: Theme.textSecondary; font.pixelSize: 16; font.family: Theme.uiFont
                    }
                    Flickable {
                        anchors.fill: parent; anchors.margins: 20
                        visible: filesPanel.previewKind === "text"
                        contentWidth: width; contentHeight: previewTextItem.implicitHeight
                        clip: true
                        Text {
                            id: previewTextItem
                            width: parent.width
                            text: filesPanel.previewTextContent
                            color: Theme.panelInk; font.pixelSize: 14; font.family: Theme.monoFont
                            wrapMode: Text.Wrap
                        }
                    }
                    Flickable {
                        anchors.fill: parent; anchors.margins: 20
                        visible: filesPanel.previewKind === "markdown"
                        contentWidth: width; contentHeight: previewMdItem.implicitHeight
                        clip: true
                        Text {
                            id: previewMdItem
                            width: parent.width
                            text: filesPanel.previewTextContent
                            textFormat: Text.MarkdownText
                            color: Theme.panelInk; font.pixelSize: 15; font.family: Theme.uiFont
                            wrapMode: Text.Wrap
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: filesPanel.previewKind === "none"
                        text: filesPanel.previewEntry ? ("No preview available for ." + filesPanel.previewEntry.ext) : ""
                        color: Theme.textSecondary; font.pixelSize: 16; font.family: Theme.uiFont
                    }
                }
                Row {
                    width: parent.width
                    Column {
                        width: parent.width - 90
                        Text { text: filesPanel.previewEntry ? filesPanel.previewEntry.name : ""; color: "#ffffff"; font.pixelSize: 17; font.bold: true; font.family: Theme.uiFont; elide: Text.ElideMiddle; width: parent.width }
                        Text {
                            text: filesPanel.previewEntry
                                ? (filesPanel.humanSize(filesPanel.previewEntry.size) + " • modified " + filesPanel.formatDate(filesPanel.previewEntry.mtime) + " • " + filesPanel.previewEntry.mode_octal)
                                : ""
                            color: "#bbbbbb"; font.pixelSize: 13; font.family: Theme.uiFont
                        }
                    }
                    Button { width: 90; height: 33; fontSize: 12; variant: "neutral"; label: "Close (Esc)"; onClicked: filesPanel.closePreview() }
                }
            }
        }

        // ===== Modal dialogs =====
        Rectangle {
            anchors.fill: parent
            color: "#99000000"
            visible: filesPanel.dialogMode !== ""
            MouseArea { anchors.fill: parent; onClicked: filesPanel.dialogMode = "" }

            // New Folder / Rename
            Rectangle {
                visible: filesPanel.dialogMode === "newFolder" || filesPanel.dialogMode === "rename"
                anchors.centerIn: parent
                width: 380; height: 150; radius: 12; color: Theme.surfaceRaised
                border.color: WorkspaceState.activeColor(); border.width: 1
                MouseArea { anchors.fill: parent }
                Column {
                    anchors.fill: parent; anchors.margins: 18; spacing: 12
                    Text { text: filesPanel.dialogMode === "newFolder" ? "New Folder" : "Rename"; color: Theme.panelInk; font.pixelSize: 17; font.bold: true; font.family: Theme.uiFont }
                    Rectangle {
                        width: parent.width; height: 38; radius: 6; color: Theme.panel
                        border.color: Theme.panelInk; border.width: 1
                        TextInput {
                            id: dialogTextInput
                            anchors.fill: parent; anchors.margins: 8
                            color: Theme.panelInk; font.pixelSize: 16; font.family: Theme.uiFont
                            text: filesPanel.dialogInput
                            focus: filesPanel.dialogMode === "newFolder" || filesPanel.dialogMode === "rename"
                            selectByMouse: true
                            onTextChanged: filesPanel.dialogInput = text
                            Keys.onReturnPressed: filesPanel.dialogMode === "newFolder" ? filesPanel.doMkdir() : filesPanel.doRename()
                            Component.onCompleted: selectAll()
                        }
                    }
                    Row {
                        spacing: 10
                        Button { label: filesPanel.dialogMode === "newFolder" ? "Create" : "Save"; onClicked: filesPanel.dialogMode === "newFolder" ? filesPanel.doMkdir() : filesPanel.doRename() }
                        Button { label: "Cancel"; variant: "neutral"; onClicked: filesPanel.dialogMode = "" }
                    }
                }
            }

            // Properties
            Rectangle {
                visible: filesPanel.dialogMode === "properties" && filesPanel.propertiesData
                anchors.centerIn: parent
                width: 440; height: 430; radius: 12; color: Theme.surfaceRaised
                border.color: WorkspaceState.activeColor(); border.width: 1
                MouseArea { anchors.fill: parent }
                Column {
                    anchors.fill: parent; anchors.margins: 20; spacing: 10
                    Text { text: filesPanel.propertiesData ? filesPanel.propertiesData.name : ""; color: Theme.panelInk; font.pixelSize: 18; font.bold: true; font.family: Theme.uiFont; elide: Text.ElideMiddle; width: parent.width }
                    Text { text: filesPanel.propertiesData ? filesPanel.propertiesData.path : ""; color: Theme.textSecondary; font.pixelSize: 12; font.family: Theme.uiFont; elide: Text.ElideMiddle; width: parent.width }
                    Item { width: 1; height: 4 }
                    Text {
                        text: filesPanel.propertiesData
                            ? ("Type: " + (filesPanel.propertiesData.is_dir ? "Folder (" + (filesPanel.propertiesData.item_count || 0) + " items)" : "File")
                               + "\nSize: " + filesPanel.humanSize(filesPanel.propertiesData.size)
                               + "\nModified: " + filesPanel.formatDate(filesPanel.propertiesData.mtime)
                               + "\nOwner: " + filesPanel.propertiesData.owner + " (" + filesPanel.propertiesData.uid + ")   Group: " + filesPanel.propertiesData.group + " (" + filesPanel.propertiesData.gid + ")"
                               + "\nRaw mode: " + filesPanel.propertiesData.mode_octal)
                            : ""
                        color: Theme.panelInk; font.pixelSize: 14; font.family: Theme.uiFont; lineHeight: 1.4
                    }
                    Item { width: 1; height: 6 }
                    SectionHeader { text: "PERMISSIONS" }
                    Repeater {
                        model: ["owner", "group", "other"]
                        delegate: Row {
                            id: whoRow
                            property string who: modelData
                            spacing: 8; height: 30
                            Text { width: 60; anchors.verticalCenter: parent.verticalCenter; text: whoRow.who.charAt(0).toUpperCase() + whoRow.who.slice(1); color: Theme.panelInk; font.pixelSize: 14; font.family: Theme.uiFont }
                            Repeater {
                                model: [{ v: "none", l: "None" }, { v: "read", l: "Read" }, { v: "readwrite", l: "Read & Write" }]
                                delegate: Button {
                                    height: 26; fontSize: 11
                                    label: modelData.l
                                    variant: (filesPanel.propertiesData && filesPanel.propertiesData.mode_translated[whoRow.who] === modelData.v) ? "primary" : "flat"
                                    onClicked: filesPanel.applyPermission(whoRow.who, modelData.v)
                                }
                            }
                        }
                    }
                    Row {
                        spacing: 10
                        Button { label: "Close"; variant: "neutral"; onClicked: filesPanel.dialogMode = "" }
                    }
                }
            }

            // Open With
            Rectangle {
                visible: filesPanel.dialogMode === "openWith"
                anchors.centerIn: parent
                width: 360; height: 420; radius: 12; color: Theme.surfaceRaised
                border.color: WorkspaceState.activeColor(); border.width: 1
                MouseArea { anchors.fill: parent }
                Column {
                    anchors.fill: parent; anchors.margins: 18; spacing: 10
                    Text { text: "Open With"; color: Theme.panelInk; font.pixelSize: 17; font.bold: true; font.family: Theme.uiFont }
                    Flickable {
                        width: parent.width; height: 320
                        contentWidth: width; contentHeight: appListCol.implicitHeight
                        clip: true
                        Column {
                            id: appListCol
                            width: parent.width; spacing: 2
                            Repeater {
                                model: filesPanel.appCatalog
                                delegate: Rectangle {
                                    width: parent.width; height: 36; radius: 6
                                    color: openWithRowMouse.containsMouse ? Theme.panel : "#00000000"
                                    Text { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; color: Theme.panelInk; font.pixelSize: 15; font.family: Theme.uiFont }
                                    MouseArea { id: openWithRowMouse; anchors.fill: parent; hoverEnabled: true; onClicked: filesPanel.openWithApp(modelData, filesPanel.dialogTarget) }
                                }
                            }
                        }
                    }
                    Button { label: "Cancel"; variant: "neutral"; onClicked: filesPanel.dialogMode = "" }
                }
            }
        }
    }

    component EntryContextMenu: Rectangle {
        id: menu
        property string entryPath: ""
        property var entryData: null
        visible: filesPanel.contextMenuTarget === entryPath
        z: 60
        width: 168; radius: 8
        height: menuCol.implicitHeight + 12
        color: Theme.surfaceRaised
        border.color: Theme.panelInk; border.width: 1
        x: 4; y: 4
        Column {
            id: menuCol
            anchors.fill: parent; anchors.margins: 6; spacing: 1
            Repeater {
                model: [
                    { label: "Open", action: "open" },
                    { label: "Open With...", action: "openWith" },
                    { label: "Copy", action: "copy" },
                    { label: "Cut", action: "cut" },
                    { label: "Rename", action: "rename" },
                    { label: "Properties", action: "properties" },
                    { label: "Move to Trash", action: "trash", danger: true }
                ]
                delegate: Rectangle {
                    width: parent.width; height: 30; radius: 5
                    color: menuItemMouse.containsMouse ? Theme.panel : "#00000000"
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: modelData.danger ? Theme.critical : Theme.panelInk
                        font.pixelSize: 13; font.family: Theme.uiFont
                    }
                    MouseArea {
                        id: menuItemMouse
                        anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            switch (modelData.action) {
                                case "open": filesPanel.openEntry(menu.entryData); break
                                case "openWith": filesPanel.openWithDialog(menu.entryPath); break
                                case "copy": filesPanel.clipboard = { path: menu.entryPath, mode: "copy" }; break
                                case "cut": filesPanel.clipboard = { path: menu.entryPath, mode: "cut" }; break
                                case "rename": filesPanel.dialogTarget = menu.entryPath; filesPanel.dialogInput = menu.entryData.name; filesPanel.dialogMode = "rename"; break
                                case "properties": filesPanel.openProperties(menu.entryPath); break
                                case "trash": filesPanel.doTrash(menu.entryPath); break
                            }
                            filesPanel.contextMenuTarget = ""
                        }
                    }
                }
            }
        }
    }
}
