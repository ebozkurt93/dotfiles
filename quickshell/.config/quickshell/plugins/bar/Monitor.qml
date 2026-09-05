import Quickshell
import Quickshell.Io
import QtQuick

import "../../Commons" as Commons

// External-monitor DDC/CI brightness control; polls brightness-ddc via Process since no native Quickshell binding exists for it.
// Untested against real hardware -- this VM has no external monitor.
Item {
    id: root
    property var shell
    property bool popupOpen: false
    property bool kbFocused: false
    readonly property bool kbAvailable: root.monitors.length > 0
    readonly property alias kbNavScope: kbNav
    function kbActivate() {
        root.popupOpen = true
        kbNav.reset()
    }
    property var monitors: [] // [{connector, brightness}]
    property string home: Quickshell.env("HOME")

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight
    visible: root.monitors.length > 0

    function refreshList() {
        listProcess.running = true
    }

    function refreshBrightness() {
        for (var i = 0; i < root.monitors.length; i++) {
            var proc = getProcessComponent.createObject(root, { connector: root.monitors[i].connector })
            proc.running = true
        }
    }

    function setBrightness(connector, percent) {
        var target = Math.round(Math.max(1, Math.min(100, percent)))
        for (var i = 0; i < root.monitors.length; i++) {
            if (root.monitors[i].connector === connector) root.monitors[i].brightness = target
        }
        root.monitors = root.monitors.slice()
        var proc = setProcessComponent.createObject(root, { connector: connector, target: target })
        proc.running = true
    }

    Process {
        id: listProcess
        command: [root.home + "/bin/desktop", "brightness-ddc", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text)
                    if (!Array.isArray(parsed)) parsed = []
                    var next = []
                    for (var i = 0; i < parsed.length; i++) {
                        var connector = String(parsed[i].connector || "")
                        if (!connector) continue
                        var existing = null
                        for (var j = 0; j < root.monitors.length; j++) {
                            if (root.monitors[j].connector === connector) existing = root.monitors[j]
                        }
                        next.push({ connector: connector, brightness: existing ? existing.brightness : -1 })
                    }
                    root.monitors = next
                    root.refreshBrightness()
                } catch (e) {
                    root.monitors = []
                }
            }
        }
    }

    Component {
        id: getProcessComponent
        Process {
            property string connector: ""
            command: [root.home + "/bin/desktop", "brightness-ddc", "get", connector]
            stdout: StdioCollector {
                onStreamFinished: {
                    var value = parseInt(text.trim(), 10)
                    if (isNaN(value)) value = -1
                    var next = root.monitors.slice()
                    for (var i = 0; i < next.length; i++) {
                        if (next[i].connector === connector) next[i].brightness = value
                    }
                    root.monitors = next
                }
            }
            onExited: destroy()
        }
    }

    Component {
        id: setProcessComponent
        Process {
            property string connector: ""
            property int target: 0
            command: [root.home + "/bin/desktop", "brightness-ddc", "set", connector, String(target)]
            onExited: destroy()
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshList()
    }

    Timer {
        interval: 3000
        running: root.popupOpen
        repeat: true
        onTriggered: root.refreshBrightness()
    }

    Rectangle {
        visible: root.kbFocused
        anchors.centerIn: icon
        width: icon.implicitWidth + 10
        height: icon.implicitHeight + 6
        radius: 4
        color: Commons.Color.launcher.selectionBackground
        border.color: Commons.Color.launcher.selectionBorder
        border.width: 1.5
    }

    Text {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        color: Commons.Color.bar.text
        font.pixelSize: 15
        text: "󰃟"

        MouseArea {
            anchors.fill: parent
            onClicked: root.popupOpen = !root.popupOpen
            onWheel: function(wheel) {
                if (root.monitors.length === 0) return
                var delta = (wheel.angleDelta.y / 120) * 5
                var m = root.monitors[0]
                if (m.brightness >= 0) root.setBrightness(m.connector, m.brightness + delta)
            }
        }
    }

    Commons.PopupPanel {
        id: popupPanel
        open: root.popupOpen
        namespace: "dotfiles-monitor-popup"
        cardWidth: 280
        cardHeight: popupColumn.implicitHeight + 24
        onDismissRequested: root.popupOpen = false

        Commons.KbNavScope {
            id: kbNav
            content: popupColumn
        }

        Column {
                id: popupColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 12

                Text {
                    width: parent.width
                    text: "Display Brightness"
                    color: Commons.Color.launcher.text
                    font.pixelSize: 14
                    font.bold: true
                }

                Repeater {
                    model: root.monitors

                    Column {
                        id: monitorRow
                        required property var modelData
                        property bool kbNavTarget: true
                        function kbActivate() {}
                        function kbAdjust(delta) { root.setBrightness(monitorRow.modelData.connector, monitorRow.modelData.brightness + delta * 5) }
                        readonly property bool navFocused: kbNav.focusedItem === monitorRow

                        width: parent.width
                        spacing: 4

                        Item {
                            width: parent.width
                            height: label.implicitHeight

                            Text {
                                id: label
                                anchors.left: parent.left
                                text: modelData.connector
                                color: Commons.Color.launcher.text
                                font.pixelSize: 12
                            }

                            Text {
                                anchors.right: parent.right
                                text: modelData.brightness >= 0 ? (modelData.brightness + "%") : "…"
                                color: Commons.Color.launcher.textMuted
                                font.pixelSize: 12
                            }
                        }

                        Item {
                            width: parent.width
                            height: 20

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 6
                                radius: 3
                                color: Commons.Color.launcher.cardBorder
                                border.color: monitorRow.navFocused ? Commons.Color.launcher.selectionBorder : "transparent"
                                border.width: monitorRow.navFocused ? 2 : 0

                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, modelData.brightness / 100))
                                    height: parent.height
                                    radius: 3
                                    color: Commons.Color.launcher.selection
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onPressed: function(mouse) { root.setBrightness(modelData.connector, (mouse.x / width) * 100) }
                                onPositionChanged: function(mouse) { if (pressed) root.setBrightness(modelData.connector, (mouse.x / width) * 100) }
                            }
                        }
                    }
                }
        }
    }
}
