import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

import "../../Commons" as Commons

Item {
    id: root
    property var shell
    property bool popupOpen: false
    property string home: Quickshell.env("HOME")

    property bool active: false
    property var remaining: null
    property string flags: ""

    property bool customDurationOpen: false
    property string customDurationText: ""

    readonly property var presets: [
        { label: "Full awake", flags: "idle:sleep:handle-lid-switch" },
        { label: "No suspend", flags: "idle:sleep" },
        { label: "Idle only", flags: "idle" }
    ]

    readonly property var durations: [
        { label: "30m", value: "30m" },
        { label: "1h", value: "1h" },
        { label: "2h", value: "2h" },
        { label: "Custom", value: "" }
    ]

    function refresh() {
        statusProvider.running = false
        statusProvider.command = [home + "/bin/helpers/amphetamine.sh", "status"]
        statusProvider.running = true
    }

    Component.onCompleted: refresh()

    Timer {
        interval: root.active && root.remaining !== null ? 1000 : 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: statusProvider
        property string buffer: ""
        stdout: SplitParser {
            onRead: function(data) { statusProvider.buffer += data + "\n" }
        }
        onStarted: statusProvider.buffer = ""
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0 || exitStatus !== 0) return
            var activeMatch = statusProvider.buffer.match(/active=([^\n]*)/)
            var remainingMatch = statusProvider.buffer.match(/remaining=([^\n]*)/)
            var flagsMatch = statusProvider.buffer.match(/flags=([^\n]*)/)

            root.active = !!activeMatch && activeMatch[1] === "1"

            var remainingRaw = remainingMatch ? remainingMatch[1].trim() : ""
            root.remaining = /^[0-9]+$/.test(remainingRaw) ? parseInt(remainingRaw, 10) : null

            root.flags = flagsMatch ? flagsMatch[1].trim() : ""
        }
    }

    Process {
        id: sleepAction
        onExited: root.refresh()
    }

    function runAction(args) {
        sleepAction.command = [home + "/bin/helpers/amphetamine.sh"].concat(args)
        sleepAction.running = true
    }

    function toggle() {
        root.runAction(["toggle"])
    }

    function start(duration) {
        if (duration && duration.length > 0) {
            root.runAction(["start", duration])
        } else {
            root.runAction(["start"])
        }
    }

    function stop() {
        root.runAction(["stop"])
    }

    function setProfile(flagsValue) {
        root.runAction(["profile", flagsValue])
    }

    function openCustomDuration() {
        root.customDurationText = ""
        root.customDurationOpen = true
        Qt.callLater(function() { customDurationInput.forceActiveFocus() })
    }

    function cancelCustomDuration() {
        root.customDurationOpen = false
    }

    function submitCustomDuration() {
        var value = root.customDurationText.trim()
        if (value.length === 0) return
        root.start(value)
        root.customDurationOpen = false
    }

    function formatRemaining(seconds) {
        if (seconds === null || seconds === undefined) return "Indefinite"
        function pad(n) { return (n < 10 ? "0" : "") + n }
        var h = Math.floor(seconds / 3600)
        var m = Math.floor((seconds % 3600) / 60)
        var s = seconds % 60
        return h > 0 ? (h + ":" + pad(m) + ":" + pad(s)) : (pad(m) + ":" + pad(s))
    }

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    Text {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        color: Commons.Color.bar.text
        opacity: root.active ? 1.0 : 0.45
        text: root.active ? "󰹑" : "󰶐"

        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.popupOpen = !root.popupOpen
                if (root.popupOpen) root.refresh()
            }
        }
    }

    PanelWindow {
        id: popupPanel
        visible: root.popupOpen
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: Commons.Color.transparent
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "dotfiles-sleep-popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.popupOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: root.popupOpen = false
        }

        Rectangle {
            id: popupCard
            width: 280
            height: popupColumn.implicitHeight + 24
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 36
            anchors.rightMargin: 8
            radius: 8
            color: Commons.Color.launcher.cardBackground
            border.color: Commons.Color.launcher.cardBorder
            border.width: 1

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            Column {
                id: popupColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 10

                Row {
                    width: parent.width
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.active ? "󰹑" : "󰶐"
                        color: Commons.Color.launcher.text
                        font.pixelSize: 22
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 22 - 44 - 20
                        spacing: 1

                        Text {
                            width: parent.width
                            text: "Sleep Prevention"
                            color: Commons.Color.launcher.text
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.active ? "ACTIVE" : "INACTIVE"
                            color: Commons.Color.launcher.textMuted
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        id: activeSwitch
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 22
                        radius: 11
                        color: root.active ? Commons.Color.launcher.selection : Commons.Color.launcher.cardBorder

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: Commons.Color.launcher.cardBackground
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.active ? parent.width - width - 2 : 2

                            Behavior on x {
                                NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.toggle()
                        }
                    }
                }

                InfoRow {
                    visible: root.active
                    label: "Remaining"
                    value: root.formatRemaining(root.remaining)
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Commons.Color.launcher.cardBorder
                }

                Text {
                    width: parent.width
                    text: "MODE"
                    color: Commons.Color.launcher.textMuted
                    font.pixelSize: 10
                }

                Row {
                    id: presetRow
                    width: parent.width
                    spacing: 6

                    readonly property real cellWidth: (width - spacing * (root.presets.length - 1)) / root.presets.length

                    Repeater {
                        model: root.presets

                        Rectangle {
                            id: presetCell
                            required property var modelData

                            readonly property bool isActive: root.flags === modelData.flags

                            width: presetRow.cellWidth
                            height: 36
                            radius: 6
                            color: isActive ? Commons.Color.launcher.selectionBackground : "transparent"
                            border.color: isActive ? Commons.Color.launcher.selectionBorder : Commons.Color.launcher.cardBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: presetCell.modelData.label
                                color: Commons.Color.launcher.text
                                font.pixelSize: 10
                                horizontalAlignment: Text.AlignHCenter
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.setProfile(presetCell.modelData.flags)
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: "START FOR"
                    color: Commons.Color.launcher.textMuted
                    font.pixelSize: 10
                }

                Row {
                    id: durationRow
                    width: parent.width
                    spacing: 6

                    readonly property real cellWidth: (width - spacing * (root.durations.length - 1)) / root.durations.length

                    Repeater {
                        model: root.durations

                        Rectangle {
                            id: durationCell
                            required property var modelData

                            width: durationRow.cellWidth
                            height: 30
                            radius: 6
                            color: "transparent"
                            border.color: Commons.Color.launcher.cardBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: durationCell.modelData.label
                                color: Commons.Color.launcher.text
                                font.pixelSize: 11
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (durationCell.modelData.value.length === 0) {
                                        root.openCustomDuration()
                                    } else {
                                        root.start(durationCell.modelData.value)
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    visible: root.customDurationOpen
                    width: parent.width
                    height: visible ? customDurationColumn.implicitHeight : 0

                    Column {
                        id: customDurationColumn
                        width: parent.width
                        spacing: 6

                        Text {
                            width: parent.width
                            text: "Custom duration (e.g. 90m, 3h, 45s)"
                            color: Commons.Color.launcher.textMuted
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            width: parent.width
                            height: 30
                            radius: 6
                            color: Commons.Color.launcher.inputBackground
                            border.color: Commons.Color.launcher.inputBorder
                            border.width: 1

                            TextInput {
                                id: customDurationInput
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                color: Commons.Color.launcher.text
                                font.pixelSize: 12
                                focus: root.customDurationOpen
                                text: root.customDurationText
                                onTextChanged: root.customDurationText = text
                                onAccepted: root.submitCustomDuration()
                                Keys.onEscapePressed: root.cancelCustomDuration()
                            }
                        }

                        Row {
                            spacing: 8
                            anchors.right: parent.right

                            Text {
                                text: "Cancel"
                                color: Commons.Color.launcher.textMuted
                                font.pixelSize: 11
                                MouseArea { anchors.fill: parent; onClicked: root.cancelCustomDuration() }
                            }

                            Text {
                                text: "Start"
                                color: Commons.Color.launcher.selection
                                font.pixelSize: 11
                                font.bold: true
                                MouseArea { anchors.fill: parent; onClicked: root.submitCustomDuration() }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: root.active
                    width: parent.width
                    height: 30
                    radius: 6
                    color: "transparent"
                    border.color: Commons.Color.launcher.cardBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Stop"
                        color: Commons.Color.danger
                        font.pixelSize: 11
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.stop()
                    }
                }
            }
        }
    }

    component InfoRow: Item {
        property string label: ""
        property string value: ""

        width: parent ? parent.width : 0
        height: labelText.implicitHeight

        Text {
            id: labelText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: label
            color: Commons.Color.launcher.textMuted
            font.pixelSize: 11
        }

        Text {
            anchors.left: labelText.right
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: value
            color: Commons.Color.launcher.text
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }
}
