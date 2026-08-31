import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQml.Models

import "../../Commons" as Commons

PanelWindow {
    id: root
    property var shell

    property string home: Quickshell.env("HOME")
    property string launcherMode: "all"
    property bool launcherOpen: false
    property bool launcherLoading: false
    property string launcherQuery: ""
    property int launcherSelected: 0
    property var launcherItems: []
    property var launcherVisibleItems: []
    property var launcherNativeItems: []
    property var launcherHiddenApps: ({})
    property string launcherOutput: ""
    property string calculatorOutput: ""
    property int calculatorSerial: 0
    property bool launcherChoosingAction: false
    property int launcherActionItemIndex: -1

    visible: launcherOpen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: Commons.Color.transparent
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "dotfiles-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: {
        if (visible) {
            launcherSearch.forceActiveFocus()
        }
    }

    function openLauncher(mode) {
        launcherMode = mode || "all"
        launcherQuery = ""
        launcherSelected = 0
        launcherChoosingAction = false
        launcherActionItemIndex = -1
        launcherOpen = true
        reloadLauncher()
    }

    function toggleLauncher(mode) {
        if (launcherOpen) {
            launcherOpen = false
        } else {
            openLauncher(mode)
        }
    }

    function reloadLauncher() {
        launcherLoading = true
        launcherNativeItems = launcherMode === "all" ? desktopAppItems() : []
        if (launcherMode === "apps") {
            launcherItems = desktopAppItems()
            launcherLoading = false
            rebuildLauncherRows()
            return
        }
        launcherItems = launcherNativeItems
        rebuildLauncherRows()
        fetchLauncherItems()
        reloadCalculator()
    }

    // Re-fetches provider items without blanking the visible list or showing
    // the loading state first -- used after a keepOpen action (e.g. closing a
    // window) so the list updates in place instead of flashing empty.
    function refreshLauncherSilently() {
        if (launcherMode === "apps") return
        fetchLauncherItems()
    }

    function fetchLauncherItems() {
        launcherOutput = ""
        var providerMode = launcherMode === "all" ? "non-apps" : (launcherMode || "all")
        var flag = "--" + providerMode
        launcherProvider.command = [home + "/bin/launcher", "items", flag]
        launcherProvider.running = true
    }

    function shellQuote(value) {
        return "'" + String(value || "").replace(/'/g, "'\\''") + "'"
    }

    function loadHiddenApps(text) {
        var next = ({})
        var lines = String(text || "").split(/\r?\n/)
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].replace(/#.*/, "").trim()
            if (!line) continue
            if (line.slice(-8) === ".desktop") line = line.slice(0, -8)
            next[line] = true
        }
        launcherHiddenApps = next
        if (launcherOpen && (launcherMode === "apps" || launcherMode === "all")) reloadLauncher()
    }

    function desktopAppItems() {
        var values = DesktopEntries.applications.values || []
        var items = []
        for (var i = 0; i < values.length; i++) {
            var entry = values[i]
            if (!entry || entry.noDisplay) continue
            var id = String(entry.id || "")
            var name = String(entry.name || id)
            if (!id || !name) continue
            if (launcherHiddenApps[id] === true) continue
            if (entry.terminal === true) continue
            var keywords = []
            try {
                if (entry.keywords && typeof entry.keywords.join === "function") keywords = entry.keywords
            } catch (e) {
            }
            items.push({
                id: "app:" + id,
                kind: "app",
                icon: String(entry.icon || "application-x-executable"),
                title: name,
                subtitle: String(entry.genericName || entry.comment || id),
                keywords: keywords.concat([id, String(entry.genericName || ""), String(entry.comment || "")]),
                actions: [
                    {
                        id: "open",
                        title: "Open (or jump to running)",
                        command: home + "/bin/desktop raise-or-launch " + shellQuote(String(entry.startupClass || id)) + " " + shellQuote(home + "/bin/launcher open-desktop " + shellQuote(id))
                    },
                    {
                        id: "new-window",
                        title: "Open New Window",
                        key: "ctrl+n",
                        command: home + "/bin/launcher open-desktop " + shellQuote(id)
                    }
                ]
            })
        }
        return items
    }

    function searchableText(item) {
        var keywords = Array.isArray(item.keywords) ? item.keywords.join(" ") : ""
        return [item.kind || "", item.title || "", item.subtitle || "", keywords].join(" ").toLowerCase()
    }

    function queryLooksLikeCalculator(query) {
        var q = String(query || "").trim()
        if (q.length < 2) return false
        return /[0-9]/.test(q) && (new RegExp("[+\\-*/^=()%]").test(q) || /\s(to|in)\s/i.test(q))
    }

    function reloadCalculator() {
        calculatorSerial += 1
        calculatorOutput = ""
        if (!queryLooksLikeCalculator(launcherQuery)) {
            rebuildLauncherRows()
            return
        }
        calculatorProvider.serial = calculatorSerial
        calculatorProvider.command = [home + "/bin/launcher", "items", "--calculator", launcherQuery]
        calculatorProvider.running = true
    }

    function fuzzyScore(text, query) {
        if (!query) return 1
        var t = text.toLowerCase()
        var q = query.toLowerCase()
        var contiguous = t.indexOf(q)
        if (contiguous >= 0) return 10000 - contiguous

        var last = -1
        var score = 0
        for (var i = 0; i < q.length; i++) {
            var next = t.indexOf(q[i], last + 1)
            if (next < 0) return -1
            score += next === last + 1 ? 18 : 5
            if (next === 0 || t[next - 1] === " " || t[next - 1] === "-" || t[next - 1] === "_") score += 8
            last = next
        }
        return score - Math.min(last, 200)
    }

    function rebuildLauncherRows() {
        launcherRows.clear()
        if (launcherChoosingAction) {
            var actionItem = launcherVisibleItems[launcherActionItemIndex]
            var actions = actionItem && Array.isArray(actionItem.actions) ? actionItem.actions : []
            for (var a = 0; a < actions.length; a++) {
                var action = actions[a]
                if (!action || !action.title) continue
                launcherRows.append({
                    itemIndex: launcherActionItemIndex,
                    actionIndex: a,
                    title: action.title || "",
                    subtitle: action.command || "",
                    kind: "action",
                    icon: "",
                    address: "",
                    iconUrl: ""
                })
            }
            if (launcherSelected >= launcherRows.count) launcherSelected = Math.max(0, launcherRows.count - 1)
            return
        }

        var query = launcherQuery.trim().toLowerCase()
        var rows = []
        var calculatorItems = []
        try {
            calculatorItems = calculatorOutput ? JSON.parse(calculatorOutput) : []
            if (!Array.isArray(calculatorItems)) calculatorItems = []
        } catch (e) {
            calculatorItems = []
        }
        var allItems = calculatorItems.concat(launcherItems)
        launcherVisibleItems = allItems
        for (var i = 0; i < allItems.length; i++) {
            var item = allItems[i]
            if (!item || !item.title) continue
            var score = fuzzyScore(searchableText(item), query)
            if (query && score < 0) continue
            rows.push({
                itemIndex: i,
                actionIndex: -1,
                title: item.title || "",
                subtitle: item.subtitle || "",
                kind: item.kind || "",
                icon: item.icon || "",
                address: item.address || "",
                iconUrl: item.iconUrl || "",
                score: score
            })
        }
        rows.sort(function(a, b) {
            if (b.score !== a.score) return b.score - a.score
            if (a.kind !== b.kind) {
                var order = { "app": 0, "action": 1, "tool": 1, "setting": 1, "system": 2, "script": 3, "window": 4, "state": 5, "tab": 6 }
                var aOrder = order[a.kind] === undefined ? 50 : order[a.kind]
                var bOrder = order[b.kind] === undefined ? 50 : order[b.kind]
                return aOrder - bOrder
            }
            return a.title.localeCompare(b.title)
        })
        for (var r = 0; r < rows.length; r++) launcherRows.append(rows[r])
        if (launcherSelected >= launcherRows.count) launcherSelected = Math.max(0, launcherRows.count - 1)
    }

    function selectLauncher(delta) {
        if (launcherRows.count <= 0) return
        launcherSelected = (launcherSelected + delta + launcherRows.count) % launcherRows.count
        launcherList.positionViewAtIndex(launcherSelected, ListView.Contain)
    }

    function runLauncherCommand(command, keepOpen) {
        if (!command) return
        if (!keepOpen) launcherOpen = false
        commandRunner.command = ["bash", "-lc", command]
        commandRunner.running = true
        if (keepOpen) refreshAfterActionTimer.restart()
    }

    function activateLauncherRow(actionOffset) {
        if (launcherRows.count <= 0) return
        var row = launcherRows.get(launcherSelected)
        var item = launcherVisibleItems[row.itemIndex]
        if (!item || !Array.isArray(item.actions) || item.actions.length === 0) return

        if (actionOffset !== undefined && actionOffset >= 0 && item.actions.length > actionOffset) {
            var offsetAction = item.actions[actionOffset]
            runLauncherCommand(offsetAction.command || "", !!offsetAction.keepOpen)
            return
        }

        if (row.actionIndex >= 0) {
            var chosenAction = item.actions[row.actionIndex]
            runLauncherCommand(chosenAction.command || "", !!chosenAction.keepOpen)
            return
        }

        if (item.kind === "calculator") {
            runLauncherCommand(item.actions[0].command || "")
            return
        }

        var hasKeyedActions = item.actions.some(function(a) { return a && a.key })
        if (item.actions.length > 1 && !hasKeyedActions) {
            launcherChoosingAction = true
            launcherActionItemIndex = row.itemIndex
            launcherSelected = 0
            launcherQuery = ""
            rebuildLauncherRows()
            return
        }

        runLauncherCommand(item.actions[0].command || "")
    }

    // Parses a "ctrl+w"-style action.key spec and checks it against a key event.
    function keyEventMatchesSpec(event, spec) {
        var parts = String(spec || "").toLowerCase().split("+")
        var letter = parts[parts.length - 1]
        var wantCtrl = parts.indexOf("ctrl") >= 0
        var wantShift = parts.indexOf("shift") >= 0
        var wantAlt = parts.indexOf("alt") >= 0
        var hasCtrl = !!(event.modifiers & Qt.ControlModifier)
        var hasShift = !!(event.modifiers & Qt.ShiftModifier)
        var hasAlt = !!(event.modifiers & Qt.AltModifier)
        if (wantCtrl !== hasCtrl || wantShift !== hasShift || wantAlt !== hasAlt) return false
        if (letter.length !== 1 || letter < "a" || letter > "z") return false
        var keyCode = Qt.Key_A + (letter.charCodeAt(0) - "a".charCodeAt(0))
        return event.key === keyCode
    }

    // Looks up the live Quickshell.Wayland.Toplevel handle for a Hyprland window
    // address (as reported by `hyprctl clients -j` .address), for feeding into
    // ScreencopyView.captureSource. Returns null if the window isn't found (e.g.
    // it closed since the list was fetched).
    function windowThumbnailHandle(address) {
        if (!address) return null
        var target = String(address).replace(/^0x/, "").toLowerCase()
        var list = (Hyprland.toplevels && Hyprland.toplevels.values) || []
        for (var i = 0; i < list.length; i++) {
            var t = list[i]
            var addr = String((t && t.address) || "").replace(/^0x/, "").toLowerCase()
            if (addr && addr === target) return t.wayland
        }
        return null
    }

    // Runs the selected row's action whose declared `key` matches this event,
    // bypassing the action sub-list entirely. Returns true if one was run.
    function tryActionShortcut(event) {
        if (launcherRows.count <= 0 || launcherChoosingAction) return false
        var row = launcherRows.get(launcherSelected)
        var item = launcherVisibleItems[row.itemIndex]
        if (!item || !Array.isArray(item.actions)) return false
        for (var i = 0; i < item.actions.length; i++) {
            var action = item.actions[i]
            if (action && action.key && keyEventMatchesSpec(event, action.key)) {
                runLauncherCommand(action.command || "", !!action.keepOpen)
                return true
            }
        }
        return false
    }

    function backFromActions() {
        if (!launcherChoosingAction) return false
        launcherChoosingAction = false
        launcherActionItemIndex = -1
        launcherSelected = 0
        rebuildLauncherRows()
        return true
    }

    function launcherStatusText() {
        if (launcherLoading) return "Loading " + launcherMode + "..."
        if (launcherChoosingAction) {
            var item = launcherItems[launcherActionItemIndex]
            return "Actions for " + ((item && item.title) ? item.title : "item") + " (" + launcherRows.count + ")"
        }
        return launcherMode + " (" + launcherRows.count + ")"
    }

    function launcherFooterText() {
        if (launcherRows.count <= 0) return launcherStatusText()
        var row = launcherRows.get(launcherSelected)
        var item = launcherVisibleItems[row.itemIndex]
        if (item && item.kind === "calculator") return "Enter: copy result    Ctrl+Enter: copy input"
        if (item && Array.isArray(item.actions) && row.actionIndex < 0) {
            var hints = []
            for (var i = 0; i < item.actions.length; i++) {
                var action = item.actions[i]
                if (!action) continue
                if (i === 0) {
                    hints.push("Enter: " + (action.title || ""))
                } else if (action.key) {
                    var label = action.key.replace(/\bctrl\b/i, "Ctrl").replace(/\bshift\b/i, "Shift")
                        .replace(/\balt\b/i, "Alt").replace(/\+(\w)$/, function(m, c) { return "+" + c.toUpperCase() })
                    hints.push(label + ": " + (action.title || ""))
                }
            }
            if (hints.length > 1) return hints.join("    ")
        }
        return ""
    }

    ListModel {
        id: launcherRows
    }

    Process {
        id: launcherProvider
        stdout: SplitParser {
            onRead: function(data) {
                root.launcherOutput += data + "\n"
            }
        }
        onExited: function(exitCode, exitStatus) {
            root.launcherLoading = false
            if (exitCode !== 0 || exitStatus !== 0) {
                root.launcherItems = root.launcherNativeItems
                root.rebuildLauncherRows()
                return
            }
            try {
                var parsed = JSON.parse(root.launcherOutput)
                root.launcherItems = root.launcherNativeItems.concat(Array.isArray(parsed) ? parsed : [])
            } catch (e) {
                console.warn("launcher provider returned invalid JSON:", e)
                root.launcherItems = root.launcherNativeItems
            }
            root.rebuildLauncherRows()
        }
    }

    Process {
        id: commandRunner
    }

    // Refreshes the item list after a keepOpen action (e.g. closing a window)
    // so the list reflects the new state without dismissing the launcher.
    Timer {
        id: refreshAfterActionTimer
        interval: 200
        repeat: false
        onTriggered: if (root.launcherOpen) root.refreshLauncherSilently()
    }

    Process {
        id: calculatorProvider
        property int serial: 0
        property int runningSerial: 0
        onRunningChanged: {
            if (running) runningSerial = serial
        }
        stdout: SplitParser {
            onRead: function(data) {
                root.calculatorOutput += data + "\n"
            }
        }
        onStarted: root.calculatorOutput = ""
        onExited: function(exitCode, exitStatus) {
            if (runningSerial !== root.calculatorSerial) return
            if (exitCode !== 0 || exitStatus !== 0) root.calculatorOutput = ""
            root.rebuildLauncherRows()
        }
    }

    FileView {
        path: home + "/.config/launcher/hidden-apps"
        watchChanges: true
        printErrors: false
        onLoaded: root.loadHiddenApps(text())
        onFileChanged: reload()
        onLoadFailed: root.loadHiddenApps("")
    }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            if (root.launcherOpen && (root.launcherMode === "apps" || root.launcherMode === "all")) {
                root.reloadLauncher()
            }
        }
    }

    IpcHandler {
        target: "launcher"

        function open(mode: string): string {
            root.openLauncher(mode || "all")
            return "ok"
        }

        function toggle(mode: string): string {
            root.toggleLauncher(mode || "all")
            return "ok"
        }

        function close(): string {
            root.launcherOpen = false
            return "ok"
        }

        function ping(): string {
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
        onClicked: root.launcherOpen = false
    }

    Rectangle {
        id: launcherCard
        visible: root.width > 0 && root.height > 0
        width: Math.min(620, Math.max(320, root.width - 32))
        height: Math.min(520, Math.max(260, root.height - 96))
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 64
        radius: 8
        color: Commons.Color.launcher.cardBackground
        border.color: Commons.Color.launcher.cardBorder
        border.width: 1

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

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
                    id: launcherSearch
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Commons.Color.launcher.text
                    selectionColor: Commons.Color.launcher.selection
                    selectedTextColor: Commons.Color.launcher.textOnAccent
                    font.pixelSize: 17
                    text: root.launcherQuery
                    focus: root.launcherOpen
                    onTextChanged: {
                        if (text !== root.launcherQuery) {
                            root.launcherQuery = text
                            root.launcherSelected = 0
                            root.reloadCalculator()
                        }
                    }
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Escape) {
                            if (!root.backFromActions()) root.launcherOpen = false
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down) {
                            root.selectLauncher(1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            root.selectLauncher(-1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (event.modifiers & Qt.ControlModifier) {
                                root.activateLauncherRow(1)
                            } else {
                                root.activateLauncherRow()
                            }
                            event.accepted = true
                        } else if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) {
                            if (root.tryActionShortcut(event)) event.accepted = true
                        }
                    }
                }
            }

            Text {
                width: parent.width
                color: Commons.Color.launcher.textMuted
                text: root.launcherStatusText()
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            ListView {
                id: launcherList
                width: parent.width
                height: parent.height - 92
                clip: true
                model: launcherRows
                spacing: 6
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    required property int index
                    required property int itemIndex
                    required property string title
                    required property string subtitle
                    required property string kind
                    required property string icon
                    required property string address
                    required property string iconUrl

                    width: ListView.view.width
                    height: kind === "keybind" ? 32 : 56
                    radius: 6
                    color: index === root.launcherSelected ? Commons.Color.launcher.selectionBackground : Commons.Color.transparent
                    border.color: index === root.launcherSelected ? Commons.Color.launcher.selectionBorder : Commons.Color.transparent
                    border.width: 1

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.launcherSelected = index
                        onClicked: root.activateLauncherRow()
                    }

                    // Keybind rows are single-line: description on the left,
                    // the actual key combo right-aligned on the same row --
                    // so a cheat-sheet-style list fits many more rows at once
                    // than the two-line title/subtitle layout below.
                    Row {
                        visible: kind === "keybind"
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Text {
                            width: parent.width - keysText.implicitWidth - parent.spacing
                            text: title
                            color: index === root.launcherSelected ? Commons.Color.launcher.textOnMuted : Commons.Color.launcher.text
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }

                        Text {
                            id: keysText
                            text: subtitle
                            color: index === root.launcherSelected ? Commons.Color.launcher.textOnMuted : Commons.Color.launcher.textMuted
                            font.pixelSize: 12
                        }
                    }

                    Row {
                        visible: kind !== "keybind"
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        // Live/static thumbnail for window rows, via Hyprland's
                        // per-toplevel screencopy. Only the selected row streams
                        // live video; other visible rows show a one-shot snapshot.
                        Rectangle {
                            id: thumbBox
                            visible: kind === "window"
                            width: visible ? 64 : 0
                            height: 40
                            radius: 4
                            color: Commons.Color.launcher.inputBackground
                            border.color: Commons.Color.launcher.inputBorder
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                            clip: true

                            Loader {
                                anchors.fill: parent
                                active: thumbBox.visible && root.windowThumbnailHandle(address) !== null
                                sourceComponent: ScreencopyView {
                                    anchors.fill: parent
                                    captureSource: root.windowThumbnailHandle(address)
                                    live: index === root.launcherSelected
                                    paintCursor: false
                                    Component.onCompleted: captureFrame()
                                    onHasContentChanged: if (hasContent && !live) captureFrame()
                                }
                            }
                        }

                        // Favicon for tab rows -- no OS-level per-tab preview exists
                        // the way Hyprland's screencopy protocol gives windows, so
                        // this is the practical "preview" for a browser tab.
                        Image {
                            id: faviconBox
                            visible: kind === "tab" && iconUrl !== ""
                            width: visible ? 20 : 0
                            height: 20
                            anchors.verticalCenter: parent.verticalCenter
                            source: iconUrl
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }

                        Column {
                            width: parent.width - thumbBox.width - faviconBox.width - ((thumbBox.visible || faviconBox.visible) ? parent.spacing : 0)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Text {
                                width: parent.width
                                text: title
                                color: index === root.launcherSelected ? Commons.Color.launcher.textOnMuted : Commons.Color.launcher.text
                                font.pixelSize: 15
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: subtitle || kind
                                color: index === root.launcherSelected ? Commons.Color.launcher.textOnMuted : Commons.Color.launcher.textMuted
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            Text {
                width: parent.width
                height: 18
                color: Commons.Color.launcher.textMuted
                text: root.launcherFooterText()
                font.pixelSize: 12
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
