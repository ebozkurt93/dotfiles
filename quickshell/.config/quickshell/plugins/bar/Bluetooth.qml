import Quickshell
import Quickshell.Bluetooth
import QtQuick

import "../../Commons" as Commons

Item {
    id: root
    property var shell
    property bool popupOpen: false
    property bool kbFocused: false
    readonly property alias kbNavScope: kbNav

    function kbActivate() {
        root.popupOpen = true
        kbNav.reset()
    }

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool hasAdapter: adapter !== null
    readonly property bool kbAvailable: hasAdapter
    readonly property bool isOn: hasAdapter && adapter.enabled

    readonly property var allDevices: Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property var pairedDevices: allDevices.filter(function(d) { return d && d.paired })
    readonly property var connectedDevices: pairedDevices.filter(function(d) { return d.connected })
    readonly property var availableDevices: pairedDevices.filter(function(d) { return !d.connected })
    readonly property int connectedCount: connectedDevices.length

    function togglePower() {
        if (!root.adapter) return
        root.adapter.enabled = !root.adapter.enabled
    }

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

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
        opacity: root.isOn ? 1.0 : 0.45
        text: !root.hasAdapter ? "" : (root.isOn ? (root.connectedCount > 0 ? "󰂱" : "󰂯") : "󰂲")
        visible: root.hasAdapter

        MouseArea {
            anchors.fill: parent
            onClicked: root.popupOpen = !root.popupOpen
        }
    }

    Commons.PopupPanel {
        id: popupPanel
        open: root.popupOpen
        namespace: "dotfiles-bluetooth-popup"
        cardWidth: 300
        cardHeight: Math.min(440, popupColumn.implicitHeight + 24)
        onDismissRequested: root.popupOpen = false

        Commons.KbNavScope {
            id: kbNav
            content: popupColumn
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
                                    var status = !root.hasAdapter ? "NO ADAPTER" : (!root.isOn ? "OFF" : (root.connectedCount > 0 ? (root.connectedCount + " CONNECTED") : "ON"))
                                    return root.kbFocused ? status + "  ·  ↑↓ Enter" : status
                                }
                                color: Commons.Color.launcher.textMuted
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }

                        Commons.ToggleSwitch {
                            id: powerSwitch
                            property bool kbNavTarget: true
                            function kbActivate() { root.togglePower() }
                            visible: root.hasAdapter
                            anchors.verticalCenter: parent.verticalCenter
                            checked: root.isOn
                            border.color: kbNav.focusedItem === powerSwitch ? Commons.Color.launcher.selectionBorder : "transparent"
                            border.width: kbNav.focusedItem === powerSwitch ? 2 : 0
                            onToggled: root.togglePower()
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
                        visible: root.hasAdapter && root.pairedDevices.length === 0
                        text: "No paired devices"
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
                        delegate: DeviceRow {
                            id: connectedRow
                            navFocused: kbNav.focusedItem === connectedRow
                        }
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
                        delegate: DeviceRow {
                            id: availableRow
                            navFocused: kbNav.focusedItem === availableRow
                        }
                    }
                }
        }
    }

    component DeviceRow: Rectangle {
        id: deviceRow
        required property var modelData
        property bool navFocused: false
        property bool kbNavTarget: true
        function kbActivate() {
            if (deviceRow.modelData.connected) deviceRow.modelData.disconnect()
            else deviceRow.modelData.connect()
        }

        width: parent ? parent.width : 0
        height: rowInner.implicitHeight + 12
        radius: 6
        color: rowMouse.containsMouse ? Commons.Color.launcher.selectionBackground : "transparent"
        border.color: deviceRow.navFocused ? Commons.Color.launcher.selectionBorder : "transparent"
        border.width: deviceRow.navFocused ? 2 : 0

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
                text: deviceRow.modelData.connected ? "󰂱" : "󰂯"
                color: deviceRow.modelData.connected ? Commons.Color.launcher.selection : Commons.Color.launcher.textMuted
                font.pixelSize: 16
            }

            Column {
                width: parent.width - 24
                spacing: 2

                Text {
                    width: parent.width
                    text: deviceRow.modelData.name || deviceRow.modelData.deviceName || ""
                    color: rowMouse.containsMouse ? Commons.Color.launcher.textOnMuted : Commons.Color.launcher.text
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: deviceRow.modelData.address + (deviceRow.modelData.connected ? " · Connected" : "")
                    color: rowMouse.containsMouse ? Commons.Color.launcher.textOnMuted : Commons.Color.launcher.textMuted
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (deviceRow.modelData.connected) deviceRow.modelData.disconnect()
                else deviceRow.modelData.connect()
            }
        }
    }
}
