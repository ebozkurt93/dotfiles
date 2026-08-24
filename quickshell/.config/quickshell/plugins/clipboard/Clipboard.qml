import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

import "../../Commons" as Commons

// Clipboard history panel, backed by cliphist (capture/storage/dedup) with
// our own UI on top -- deliberately not the Launcher's flat list layout
// (per user request), a two-pane list+preview shape instead, closer to
// Omarchy's clipboard panel in spirit but not in code. Image support comes
// from cliphist itself (it mime-sniffs stdin automatically, no separate
// text/image capture paths needed the way Omarchy's own capture.sh does).
PanelWindow {
    id: root
    property var shell

    property string home: Quickshell.env("HOME")
    property bool opened: false
    property string query: ""
    property int selectedIndex: 0
    property var entries: []
    property string listOutput: ""
    property bool confirmingWipe: false
    property string previewImagePath: ""
    property int previewSerial: 0

    visible: opened
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: Commons.Color.transparent
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "dotfiles-clipboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property string previewCacheDir: (Quickshell.env("XDG_CACHE_HOME") || (home + "/.cache")) + "/quickshell-clipboard"

    function open() {
        opened = true
        query = ""
        selectedIndex = 0
        confirmingWipe = false
        refresh()
        Qt.callLater(function() { searchInput.forceActiveFocus() })
    }

    function close() {
        opened = false
        confirmingWipe = false
    }

    function toggle() {
        if (opened) close()
        else open()
    }

    function refresh() {
        listProcess.running = true
    }

    function parseEntries(text) {
        var lines = String(text || "").split("\n")
        var result = []
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (!line) continue
            var tabIndex = line.indexOf("\t")
            if (tabIndex < 0) continue
            var id = line.slice(0, tabIndex)
            var preview = line.slice(tabIndex + 1)
            var isImage = preview.indexOf("[[ binary data") === 0
            result.push({ id: id, preview: preview, isImage: isImage, raw: line })
        }
        return result
    }

    function filteredEntries() {
        var q = query.trim().toLowerCase()
        if (!q) return entries
        var out = []
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].preview.toLowerCase().indexOf(q) >= 0) out.push(entries[i])
        }
        return out
    }

    function selectedEntry() {
        var rows = filteredEntries()
        if (selectedIndex < 0 || selectedIndex >= rows.length) return null
        return rows[selectedIndex]
    }

    function move(delta) {
        var count = filteredEntries().length
        if (count <= 0) return
        selectedIndex = (selectedIndex + delta + count) % count
    }

    function copySelected() {
        var entry = selectedEntry()
        if (!entry) return
        copyProcess.command = ["bash", "-lc", "cliphist decode " + entry.id + " | wl-copy"]
        copyProcess.running = true
        close()
    }

    function deleteSelected() {
        var entry = selectedEntry()
        if (!entry) return
        deleteProcess.command = ["bash", "-lc", "printf '%s' " + shellQuote(entry.raw) + " | cliphist delete"]
        deleteProcess.running = true
    }

    function shellQuote(value) {
        return "'" + String(value || "").replace(/'/g, "'\\''") + "'"
    }

    function requestWipe() {
        if (entries.length === 0) return
        confirmingWipe = true
    }

    function confirmWipe() {
        wipeProcess.running = true
        confirmingWipe = false
    }

    function cancelWipe() {
        confirmingWipe = false
    }

    function updatePreviewImage() {
        var entry = selectedEntry()
        previewImagePath = ""
        if (!entry || !entry.isImage) return
        previewSerial += 1
        var serial = previewSerial
        var path = previewCacheDir + "/" + entry.id + ".img"
        decodeProcess.targetSerial = serial
        decodeProcess.targetPath = path
        decodeProcess.command = ["bash", "-lc", "mkdir -p " + shellQuote(previewCacheDir) + " && cliphist decode " + entry.id + " > " + shellQuote(path)]
        decodeProcess.running = true
    }

    onSelectedIndexChanged: updatePreviewImage()
    onQueryChanged: {
        selectedIndex = 0
        updatePreviewImage()
    }

    Process {
        id: listProcess
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.listOutput = text
                root.entries = root.parseEntries(text)
                if (root.selectedIndex >= root.filteredEntries().length) root.selectedIndex = 0
                root.updatePreviewImage()
            }
        }
    }

    Process { id: copyProcess }
    Process { id: wipeProcess; command: ["cliphist", "wipe"]; onExited: root.refresh() }
    Process { id: deleteProcess; onExited: root.refresh() }
    Process {
        id: decodeProcess
        property int targetSerial: 0
        property string targetPath: ""
        onExited: if (targetSerial === root.previewSerial) root.previewImagePath = "file://" + targetPath
    }

    // Persistent clipboard watcher: cliphist mime-sniffs stdin itself, so one
    // process handles both text and images (unlike Omarchy's own capture.sh,
    // which needs separate text/image watches because it does its own type
    // detection). Piped through clipboard-capture rather than straight into
    // `cliphist store` -- cliphist has no per-item size cap, only an
    // entry-count one, so that wrapper drops oversized pastes before they'd
    // sit in the db forever. Restarted if it ever dies -- a dead watcher
    // takes clipboard history with it silently otherwise.
    Process {
        id: watchProcess
        command: ["wl-paste", "--watch", home + "/dotfiles/helper_scripts/libexec/desktop/clipboard-capture"]
        onExited: watchRestartTimer.restart()
    }

    Timer {
        id: watchRestartTimer
        interval: 1000
        repeat: false
        onTriggered: if (!watchProcess.running) watchProcess.running = true
    }

    Component.onCompleted: watchProcess.running = true

    IpcHandler {
        target: "clipboard"

        function open(): string {
            root.open()
            return "ok"
        }

        function toggle(): string {
            root.toggle()
            return "ok"
        }

        function close(): string {
            root.close()
            return "ok"
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Commons.Color.launcher.scrim
        opacity: 0.34
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        id: card
        visible: root.width > 0 && root.height > 0
        width: Math.min(860, Math.max(480, root.width - 32))
        height: Math.min(560, Math.max(320, root.height - 96))
        anchors.centerIn: parent
        radius: 8
        color: Commons.Color.launcher.cardBackground
        border.color: Commons.Color.launcher.cardBorder
        border.width: 1

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Rectangle {
                width: parent.width
                height: 42
                radius: 6
                color: Commons.Color.launcher.inputBackground
                border.color: Commons.Color.launcher.inputBorder
                border.width: 1

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Commons.Color.launcher.text
                    selectionColor: Commons.Color.launcher.selection
                    selectedTextColor: Commons.Color.launcher.textOnAccent
                    font.pixelSize: 16
                    text: root.query
                    focus: root.opened
                    onTextChanged: if (text !== root.query) root.query = text
                    Keys.onPressed: function(event) {
                        if (root.confirmingWipe) {
                            if (event.key === Qt.Key_Escape) { root.cancelWipe(); event.accepted = true }
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.confirmWipe(); event.accepted = true }
                            return
                        }
                        if (event.key === Qt.Key_Escape) {
                            if (root.query) root.query = ""
                            else root.close()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down) {
                            root.move(1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            root.move(-1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.copySelected()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Backspace && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
                            root.requestWipe()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Backspace && (event.modifiers & Qt.ControlModifier)) {
                            root.deleteSelected()
                            event.accepted = true
                        }
                    }
                }
            }

            Text {
                width: parent.width
                color: Commons.Color.launcher.textMuted
                text: root.confirmingWipe
                    ? "Delete entire clipboard history? Enter to confirm, Esc to cancel"
                    : "Clipboard (" + root.filteredEntries().length + ")    Enter: copy    Ctrl+Backspace: remove    Ctrl+Shift+Backspace: clear all"
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Row {
                width: parent.width
                height: parent.height - 92
                spacing: 12

                ListView {
                    id: entryList
                    width: parent.width * 0.42
                    height: parent.height
                    clip: true
                    model: root.filteredEntries()
                    spacing: 4
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        required property int index
                        required property var modelData

                        width: ListView.view.width
                        height: 32
                        radius: 6
                        color: index === root.selectedIndex ? Commons.Color.launcher.selectionBackground : Commons.Color.transparent
                        border.color: index === root.selectedIndex ? Commons.Color.launcher.selectionBorder : Commons.Color.transparent
                        border.width: 1

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.selectedIndex = index
                            onClicked: root.copySelected()
                        }

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: Text.AlignVCenter
                            text: modelData.isImage ? ("🖼 " + modelData.preview) : modelData.preview
                            color: Commons.Color.launcher.text
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    width: parent.width * 0.58 - 12
                    height: parent.height
                    radius: 6
                    color: Commons.Color.launcher.inputBackground
                    border.color: Commons.Color.launcher.inputBorder
                    border.width: 1
                    clip: true

                    property var current: root.selectedEntry()

                    Text {
                        visible: !parent.current
                        anchors.centerIn: parent
                        text: "No selection"
                        color: Commons.Color.launcher.textMuted
                        font.pixelSize: 13
                    }

                    Image {
                        visible: parent.current && parent.current.isImage && root.previewImagePath !== ""
                        anchors.fill: parent
                        anchors.margins: 12
                        source: root.previewImagePath
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    Text {
                        visible: parent.current && !parent.current.isImage
                        anchors.fill: parent
                        anchors.margins: 12
                        text: parent.current ? parent.current.preview : ""
                        color: Commons.Color.launcher.text
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                        verticalAlignment: Text.AlignTop
                    }
                }
            }
        }
    }
}
