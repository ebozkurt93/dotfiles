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
    property var items: []

    readonly property bool hasAdapter: items.length > 0 && items[0].id !== "bt:no-adapter"
    readonly property bool isOn: items.length > 0 && items[0].id !== "bt:no-adapter" && items[0].id !== "bt:power-on"
    readonly property var powerItem: items.length > 0 ? items[0] : null
    readonly property var deviceItems: {
        var list = []
        for (var i = 0; i < items.length; i++) {
            var it = items[i]
            if (it.id && it.id.indexOf("bt:") === 0 && it !== root.powerItem) list.push(it)
        }
        return list
    }
    readonly property var connectedDevices: deviceItems.filter(function(d) { return d.subtitle && d.subtitle.indexOf("Connected") !== -1 })
    readonly property var availableDevices: deviceItems.filter(function(d) { return !(d.subtitle && d.subtitle.indexOf("Connected") !== -1) })
    readonly property int connectedCount: connectedDevices.length

    function refresh() {
        bluetoothProvider.running = false
        bluetoothProvider.command = [home + "/bin/launcher", "items", "--bluetooth"]
        bluetoothProvider.running = true
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: bluetoothProvider
        property string buffer: ""
        stdout: SplitParser {
            onRead: function(data) { bluetoothProvider.buffer += data + "\n" }
        }
        onStarted: bluetoothProvider.buffer = ""
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0 || exitStatus !== 0) return
            try {
                var parsed = JSON.parse(bluetoothProvider.buffer)
                root.items = Array.isArray(parsed) ? parsed : []
            } catch (e) {
                console.warn("bluetooth provider returned invalid JSON:", e)
            }
        }
    }

    Process {
        id: bluetoothAction
        onExited: root.refresh()
    }

    function runAction(command) {
        if (!command) return
        bluetoothAction.command = ["bash", "-lc", command]
        bluetoothAction.running = true
    }

    function togglePower() {
        if (!root.powerItem || !root.powerItem.actions || root.powerItem.actions.length === 0) return
        root.runAction(root.powerItem.actions[0].command)
    }

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    Text {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        color: Commons.Color.bar.text
        opacity: root.isOn ? 1.0 : 0.45
        text: !root.hasAdapter ? "" : (root.isOn ? (root.connectedCount > 0 ? "󰂱" : "󰂯") : "󰂲")
        visible: root.hasAdapter

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
        WlrLayershell.namespace: "dotfiles-bluetooth-popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: root.popupOpen = false
        }

        Rectangle {
            id: popupCard
            width: 300
            height: Math.min(440, popupColumn.implicitHeight + 24)
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

            Flickable {
                anchors.fill: parent
                anchors.margins: 12
                contentHeight: popupColumn.implicitHeight
                clip: true

                Column {
                    id: popupColumn
                    width: parent.width
                    spacing: 10

                    Row {
                        width: parent.width
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: !root.hasAdapter ? "󰂲" : (root.isOn ? (root.connectedCount > 0 ? "󰂱" : "󰂯") : "󰂲")
                            color: Commons.Color.launcher.text
                            font.pixelSize: 22
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 22 - 44 - 20
                            spacing: 1

                            Text {
                                width: parent.width
                                text: "Bluetooth"
                                color: Commons.Color.launcher.text
                                font.pixelSize: 14
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: {
                                    if (!root.hasAdapter) return "NO ADAPTER"
                                    if (!root.isOn) return "OFF"
                                    return root.connectedCount > 0 ? (root.connectedCount + " CONNECTED") : "ON"
                                }
                                color: Commons.Color.launcher.textMuted
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            id: powerSwitch
                            visible: root.hasAdapter
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 22
                            radius: 11
                            color: root.isOn ? Commons.Color.launcher.selection : Commons.Color.launcher.cardBorder

                            Rectangle {
                                width: 18
                                height: 18
                                radius: 9
                                color: Commons.Color.launcher.cardBackground
                                anchors.verticalCenter: parent.verticalCenter
                                x: root.isOn ? parent.width - width - 2 : 2

                                Behavior on x {
                                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.togglePower()
                            }
                        }
                    }

                    Rectangle {
                        visible: root.hasAdapter
                        width: parent.width
                        height: 1
                        color: Commons.Color.launcher.cardBorder
                    }

                    Text {
                        width: parent.width
                        visible: root.items.length === 0
                        text: "Loading…"
                        color: Commons.Color.launcher.textMuted
                        font.pixelSize: 12
                    }

                    Text {
                        width: parent.width
                        visible: root.connectedDevices.length > 0
                        text: "CONNECTED"
                        color: Commons.Color.launcher.textMuted
                        font.pixelSize: 10
                    }

                    Repeater {
                        model: root.connectedDevices
                        delegate: DeviceRow {}
                    }

                    Text {
                        width: parent.width
                        visible: root.availableDevices.length > 0
                        text: "AVAILABLE"
                        color: Commons.Color.launcher.textMuted
                        font.pixelSize: 10
                    }

                    Repeater {
                        model: root.availableDevices
                        delegate: DeviceRow {}
                    }
                }
            }
        }
    }

    component DeviceRow: Rectangle {
        id: deviceRow
        required property var modelData

        readonly property bool isConnected: modelData.subtitle && modelData.subtitle.indexOf("Connected") !== -1

        width: parent ? parent.width : 0
        height: rowInner.implicitHeight + 12
        radius: 6
        color: rowMouse.containsMouse ? Commons.Color.launcher.selectionBackground : "transparent"

        Row {
            id: rowInner
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: deviceRow.isConnected ? "󰂱" : "󰂯"
                color: deviceRow.isConnected ? Commons.Color.launcher.selection : Commons.Color.launcher.textMuted
                font.pixelSize: 16
            }

            Column {
                width: parent.width - 24
                spacing: 2

                Text {
                    width: parent.width
                    text: deviceRow.modelData.title || ""
                    color: Commons.Color.launcher.text
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: deviceRow.modelData.subtitle || ""
                    color: Commons.Color.launcher.textMuted
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: deviceRow.modelData.actions && deviceRow.modelData.actions.length > 0
            onClicked: {
                var actions = deviceRow.modelData.actions
                if (actions && actions.length > 0) root.runAction(actions[0].command)
            }
        }
    }
}
