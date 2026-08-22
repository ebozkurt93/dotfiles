import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: shell

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
    property bool lockRequested: false
    property bool lockPreviewOpen: false
    property bool lockAuthenticating: false
    property string lockPassword: ""
    property string lockPendingPassword: ""
    property string lockFailure: ""
    property int lockFailedAttempts: 0
    property string currentUser: Quickshell.env("USER") || Quickshell.env("LOGNAME")
    property var lockPasswordField: null

    function focusLockPassword() {
        if (lockPasswordField) lockPasswordField.forceActiveFocus()
    }

    function beginLock() {
        lockPassword = ""
        lockPendingPassword = ""
        lockFailure = ""
        lockFailedAttempts = 0
        lockAuthenticating = false
        lockRequested = true
        sessionLock.locked = true
        Qt.callLater(focusLockPassword)
        return true
    }

    function finishUnlock() {
        lockRequested = false
        lockAuthenticating = false
        lockPassword = ""
        lockPendingPassword = ""
        lockFailure = ""
        sessionLock.locked = false
    }

    function submitLockPassword() {
        var password = String(lockPassword || "")
        if (!lockRequested || lockAuthenticating || password.length === 0) return
        lockPendingPassword = password
        lockPassword = ""
        lockFailure = ""
        lockAuthenticating = true
        if (!lockPam.start()) handleLockFailure()
        else Qt.callLater(respondToLockPasswordPrompt)
    }

    function respondToLockPasswordPrompt() {
        if (lockAuthenticating && lockPam.active && lockPam.responseRequired) {
            lockPam.respond(lockPendingPassword)
        }
    }

    function handleLockFailure() {
        lockAuthenticating = false
        lockPendingPassword = ""
        lockFailedAttempts += 1
        lockFailure = "Authentication failed"
        Qt.callLater(focusLockPassword)
    }

    function runLockPowerAction(command) {
        if (!command) return
        lockPowerRunner.command = ["bash", "-lc", command]
        lockPowerRunner.running = true
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
        launcherOutput = ""
        launcherNativeItems = launcherMode === "all" ? desktopAppItems() : []
        if (launcherMode === "apps") {
            launcherItems = desktopAppItems()
            launcherLoading = false
            rebuildLauncherRows()
            return
        }
        launcherItems = launcherNativeItems
        rebuildLauncherRows()

        var providerMode = launcherMode === "all" ? "non-apps" : (launcherMode || "all")
        var flag = "--" + providerMode
        launcherProvider.command = [home + "/bin/launcher-items", flag]
        launcherProvider.running = true
        reloadCalculator()
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
                        title: "Open",
                        command: home + "/bin/launcher-open-desktop " + shellQuote(id)
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
        calculatorProvider.command = [home + "/bin/launcher-items", "--calculator", launcherQuery]
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
                    icon: ""
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

    function runLauncherCommand(command) {
        if (!command) return
        launcherOpen = false
        commandRunner.command = ["bash", "-lc", command]
        commandRunner.running = true
    }

    function activateLauncherRow(actionOffset) {
        if (launcherRows.count <= 0) return
        var row = launcherRows.get(launcherSelected)
        var item = launcherVisibleItems[row.itemIndex]
        if (!item || !Array.isArray(item.actions) || item.actions.length === 0) return

        if (actionOffset !== undefined && actionOffset >= 0 && item.actions.length > actionOffset) {
            runLauncherCommand(item.actions[actionOffset].command || "")
            return
        }

        if (row.actionIndex >= 0) {
            runLauncherCommand(item.actions[row.actionIndex].command || "")
            return
        }

        if (item.kind === "calculator") {
            runLauncherCommand(item.actions[0].command || "")
            return
        }

        if (item.actions.length > 1) {
            launcherChoosingAction = true
            launcherActionItemIndex = row.itemIndex
            launcherSelected = 0
            launcherQuery = ""
            rebuildLauncherRows()
            return
        }

        runLauncherCommand(item.actions[0].command || "")
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
        return ""
    }

    ListModel {
        id: launcherRows
    }

    Process {
        id: launcherProvider
        stdout: SplitParser {
            onRead: function(data) {
                shell.launcherOutput += data + "\n"
            }
        }
        onExited: function(exitCode, exitStatus) {
            shell.launcherLoading = false
            if (exitCode !== 0 || exitStatus !== 0) {
                shell.launcherItems = shell.launcherNativeItems
                shell.rebuildLauncherRows()
                return
            }
            try {
                var parsed = JSON.parse(shell.launcherOutput)
                shell.launcherItems = shell.launcherNativeItems.concat(Array.isArray(parsed) ? parsed : [])
            } catch (e) {
                console.warn("launcher provider returned invalid JSON:", e)
                shell.launcherItems = shell.launcherNativeItems
            }
            shell.rebuildLauncherRows()
        }
    }

    Process {
        id: commandRunner
    }

    Process {
        id: lockPowerRunner
    }

    PamContext {
        id: lockPam
        config: "dotfiles-lock"
        user: shell.currentUser
        onResponseRequiredChanged: shell.respondToLockPasswordPrompt()
        onPamMessage: shell.respondToLockPasswordPrompt()
        onCompleted: function(result) {
            shell.lockAuthenticating = false
            shell.lockPendingPassword = ""
            if (!shell.lockRequested) return
            if (result === PamResult.Success) shell.finishUnlock()
            else shell.handleLockFailure()
        }
        onError: function(error) {
            shell.handleLockFailure()
        }
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
                shell.calculatorOutput += data + "\n"
            }
        }
        onStarted: shell.calculatorOutput = ""
        onExited: function(exitCode, exitStatus) {
            if (runningSerial !== shell.calculatorSerial) return
            if (exitCode !== 0 || exitStatus !== 0) shell.calculatorOutput = ""
            shell.rebuildLauncherRows()
        }
    }

    FileView {
        path: home + "/.config/launcher/hidden-apps"
        watchChanges: true
        printErrors: false
        onLoaded: shell.loadHiddenApps(text())
        onFileChanged: reload()
        onLoadFailed: shell.loadHiddenApps("")
    }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            if (shell.launcherOpen && (shell.launcherMode === "apps" || shell.launcherMode === "all")) {
                shell.reloadLauncher()
            }
        }
    }

    IpcHandler {
        target: "launcher"

        function open(mode: string): string {
            shell.openLauncher(mode || "all")
            return "ok"
        }

        function toggle(mode: string): string {
            shell.toggleLauncher(mode || "all")
            return "ok"
        }

        function close(): string {
            shell.launcherOpen = false
            return "ok"
        }

        function ping(): string {
            return "ok"
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): string {
            if (!shell.lockRequested) shell.beginLock()
            return "ok"
        }

        function status(): string {
            return JSON.stringify({
                requested: shell.lockRequested,
                preview: shell.lockPreviewOpen,
                locked: sessionLock.locked,
                secure: sessionLock.secure,
                authenticating: shell.lockAuthenticating
            })
        }

        function preview(): string {
            shell.lockPreviewOpen = true
            return "ok"
        }

        function hidePreview(): string {
            shell.lockPreviewOpen = false
            return "ok"
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        WlSessionLockSurface {
            color: "#11111b"

            Rectangle {
                anchors.fill: parent
                color: "#11111b"

                MouseArea {
                    anchors.fill: parent
                    onClicked: lockPasswordInput.forceActiveFocus()
                }

                Column {
                    id: lockStack
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 48, 560)
                    spacing: 12

                    Text {
                        width: parent.width
                        text: Qt.formatDateTime(lockClock.date, "dddd, d MMMM")
                        color: "#cdd6f4"
                        opacity: 0.72
                        font.pixelSize: 22
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        width: parent.width
                        text: Qt.formatDateTime(lockClock.date, "hh:mm")
                        color: "#cdd6f4"
                        font.pixelSize: 116
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        width: parent.width
                        text: shell.currentUser
                        color: "#cdd6f4"
                        opacity: 0.72
                        font.pixelSize: 24
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Rectangle {
                        width: 340
                        height: 58
                        radius: 12
                        color: "#181825"
                        border.color: shell.lockFailure ? "#f38ba8" : "#45475a"
                        border.width: 1
                        anchors.horizontalCenter: parent.horizontalCenter

                        TextInput {
                            id: lockPasswordInput
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 18
                            verticalAlignment: TextInput.AlignVCenter
                            horizontalAlignment: TextInput.AlignHCenter
                            color: "#cdd6f4"
                            selectionColor: "#89b4fa"
                            selectedTextColor: "#11111b"
                            echoMode: TextInput.Password
                            passwordCharacter: "●"
                            passwordMaskDelay: 0
                            enabled: shell.lockRequested && !shell.lockAuthenticating
                            focus: shell.lockRequested
                            text: shell.lockPassword
                            font.pixelSize: text.length > 0 ? 24 : 17
                            Component.onCompleted: shell.lockPasswordField = lockPasswordInput
                            onTextChanged: {
                                if (text !== shell.lockPassword) shell.lockPassword = text
                                if (text.length > 0) shell.lockFailure = ""
                            }
                            onAccepted: shell.submitLockPassword()
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
                                    shell.lockPassword = ""
                                    event.accepted = true
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: lockPasswordInput.text.length === 0 && (shell.lockAuthenticating || shell.lockFailure.length > 0)
                            text: shell.lockAuthenticating ? "Checking..." : shell.lockFailure
                            color: shell.lockFailure ? "#f38ba8" : "#a6adc8"
                            font.pixelSize: 17
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12
                        topPadding: 18

                        Repeater {
                            model: [
                                { label: "Sleep", command: "systemctl suspend", color: "#313244", border: "#45475a", text: "#cdd6f4" },
                                { label: "Restart", command: "systemctl reboot", color: "#313244", border: "#45475a", text: "#cdd6f4" },
                                { label: "Shutdown", command: "systemctl poweroff", color: "#3a2432", border: "#f38ba8", text: "#f5c2e7" }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                width: 124
                                height: 44
                                radius: 12
                                color: powerButtonMouse.containsMouse ? "#45475a" : modelData.color
                                border.color: modelData.border
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: modelData.text
                                    font.pixelSize: 15
                                }

                                MouseArea {
                                    id: powerButtonMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: shell.runLockPowerAction(modelData.command)
                                }
                            }
                        }
                    }
                }

                SystemClock {
                    id: lockClock
                    precision: SystemClock.Seconds
                }
            }
        }
    }

    PanelWindow {
        id: lockPreviewPanel
        visible: shell.lockPreviewOpen
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "dotfiles-lock-preview"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Rectangle {
            anchors.fill: parent
            color: "#11111b"

            MouseArea {
                anchors.fill: parent
                onClicked: shell.lockPreviewOpen = false
            }

            Column {
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 560)
                spacing: 12

                Text {
                    width: parent.width
                    text: Qt.formatDateTime(lockPreviewClock.date, "dddd, d MMMM")
                    color: "#cdd6f4"
                    opacity: 0.72
                    font.pixelSize: 22
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: Qt.formatDateTime(lockPreviewClock.date, "hh:mm")
                    color: "#cdd6f4"
                    font.pixelSize: 116
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: shell.currentUser
                    color: "#cdd6f4"
                    opacity: 0.72
                    font.pixelSize: 24
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    width: 340
                    height: 58
                    radius: 12
                    color: "#181825"
                    border.color: "#45475a"
                    border.width: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    topPadding: 18

                    Repeater {
                        model: [
                            { label: "Sleep", color: "#313244", border: "#45475a", text: "#cdd6f4" },
                            { label: "Restart", color: "#313244", border: "#45475a", text: "#cdd6f4" },
                            { label: "Shutdown", color: "#3a2432", border: "#f38ba8", text: "#f5c2e7" }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            width: 124
                            height: 44
                            radius: 12
                            color: previewButtonMouse.containsMouse ? "#45475a" : modelData.color
                            border.color: modelData.border
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: modelData.text
                                font.pixelSize: 15
                            }

                            MouseArea {
                                id: previewButtonMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: shell.lockPreviewOpen = false
                            }
                        }
                    }
                }
            }

            SystemClock {
                id: lockPreviewClock
                precision: SystemClock.Seconds
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 18
                text: "Preview"
                color: "#cdd6f4"
                opacity: 0.36
                font.pixelSize: 12
            }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    shell.lockPreviewOpen = false
                    event.accepted = true
                }
            }

            Component.onCompleted: forceActiveFocus()
        }
    }

    PanelWindow {
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: 32
        color: "#1e1e2e"

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 8
            spacing: 6

            Repeater {
                model: Hyprland.workspaces
                delegate: Rectangle {
                    width: 24
                    height: 24
                    radius: 4
                    color: modelData.active ? "#89b4fa" : "#313244"
                    Text {
                        anchors.centerIn: parent
                        text: modelData.name
                        color: "#cdd6f4"
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            color: "#cdd6f4"
            text: Qt.formatDateTime(clock.date, "ddd MMM d  hh:mm:ss")

            SystemClock {
                id: clock
                precision: SystemClock.Seconds
            }
        }
    }

    PanelWindow {
        id: launcherPanel
        visible: shell.launcherOpen
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "dotfiles-launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        onVisibleChanged: {
            if (visible) {
                launcherSearch.forceActiveFocus()
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.34
        }

        MouseArea {
            anchors.fill: parent
            onClicked: shell.launcherOpen = false
        }

        Rectangle {
            id: launcherCard
            visible: launcherPanel.width > 0 && launcherPanel.height > 0
            width: Math.min(620, Math.max(320, launcherPanel.width - 32))
            height: Math.min(520, Math.max(260, launcherPanel.height - 96))
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 64
            radius: 8
            color: "#181825"
            border.color: "#45475a"
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
                    color: "#11111b"
                    border.color: "#313244"
                    border.width: 1

                    TextInput {
                        id: launcherSearch
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: "#cdd6f4"
                        selectionColor: "#89b4fa"
                        selectedTextColor: "#11111b"
                        font.pixelSize: 17
                        text: shell.launcherQuery
                        focus: shell.launcherOpen
                        onTextChanged: {
                            if (text !== shell.launcherQuery) {
                                shell.launcherQuery = text
                                shell.launcherSelected = 0
                                shell.reloadCalculator()
                            }
                        }
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Escape) {
                                if (!shell.backFromActions()) shell.launcherOpen = false
                                event.accepted = true
                            } else if (event.key === Qt.Key_Down) {
                                shell.selectLauncher(1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                shell.selectLauncher(-1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (event.modifiers & Qt.ControlModifier) {
                                    shell.activateLauncherRow(1)
                                } else {
                                    shell.activateLauncherRow()
                                }
                                event.accepted = true
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    color: "#a6adc8"
                    text: shell.launcherStatusText()
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

                        width: ListView.view.width
                        height: 56
                        radius: 6
                        color: index === shell.launcherSelected ? "#313244" : "transparent"
                        border.color: index === shell.launcherSelected ? "#89b4fa" : "transparent"
                        border.width: 1

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: shell.launcherSelected = index
                            onClicked: shell.activateLauncherRow()
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 4

                            Text {
                                width: parent.width
                                text: title
                                color: "#cdd6f4"
                                font.pixelSize: 15
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: subtitle || kind
                                color: "#a6adc8"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    height: 18
                    color: "#a6adc8"
                    text: shell.launcherFooterText()
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
