import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
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
    property string launcherOutput: ""

    function openLauncher(mode) {
        launcherMode = mode || "all"
        launcherQuery = ""
        launcherSelected = 0
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
        var flag = "--" + (launcherMode || "all")
        launcherProvider.command = [home + "/bin/launcher-items", flag]
        launcherProvider.running = true
    }

    function searchableText(item) {
        var keywords = Array.isArray(item.keywords) ? item.keywords.join(" ") : ""
        return [item.kind || "", item.title || "", item.subtitle || "", keywords].join(" ").toLowerCase()
    }

    function rebuildLauncherRows() {
        launcherRows.clear()
        var query = launcherQuery.trim().toLowerCase()
        for (var i = 0; i < launcherItems.length; i++) {
            var item = launcherItems[i]
            if (!item || !item.title) continue
            if (query && searchableText(item).indexOf(query) < 0) continue
            launcherRows.append({
                itemIndex: i,
                title: item.title || "",
                subtitle: item.subtitle || "",
                kind: item.kind || "",
                icon: item.icon || ""
            })
        }
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

    function activateLauncherRow() {
        if (launcherRows.count <= 0) return
        var row = launcherRows.get(launcherSelected)
        var item = launcherItems[row.itemIndex]
        if (!item || !Array.isArray(item.actions) || item.actions.length === 0) return
        runLauncherCommand(item.actions[0].command || "")
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
                shell.launcherItems = []
                shell.rebuildLauncherRows()
                return
            }
            try {
                var parsed = JSON.parse(shell.launcherOutput)
                shell.launcherItems = Array.isArray(parsed) ? parsed : []
            } catch (e) {
                console.warn("launcher provider returned invalid JSON:", e)
                shell.launcherItems = []
            }
            shell.rebuildLauncherRows()
        }
    }

    Process {
        id: commandRunner
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
            width: Math.min(620, launcherPanel.width - 32)
            height: Math.min(520, launcherPanel.height - 96)
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(48, Math.round((launcherPanel.height - height) / 3))
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
                                shell.rebuildLauncherRows()
                            }
                        }
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Escape) {
                                shell.launcherOpen = false
                                event.accepted = true
                            } else if (event.key === Qt.Key_Down) {
                                shell.selectLauncher(1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                shell.selectLauncher(-1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                shell.activateLauncherRow()
                                event.accepted = true
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    color: "#a6adc8"
                    text: shell.launcherLoading ? "Loading " + shell.launcherMode + "..." : shell.launcherMode + " (" + launcherRows.count + ")"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                ListView {
                    id: launcherList
                    width: parent.width
                    height: parent.height - 64
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
            }
        }
    }
}
