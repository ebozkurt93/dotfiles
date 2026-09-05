import Quickshell.Networking
import QtQuick

import "../../Commons" as Commons

Rectangle {
    id: wifiRow
    required property var modelData
    property bool navFocused: false

    signal activateRequested()
    signal forgetRequested()

    function wifiIconFor(strength) {
        var icons = ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]
        var index = Math.max(0, Math.min(4, Math.ceil(strength / 20) - 1))
        return icons[index]
    }

    function requiresCredentials(security) {
        return security !== WifiSecurityType.Open && security !== WifiSecurityType.Owe
    }

    width: parent ? parent.width : 0
    height: rowInner.implicitHeight + 12
    radius: 6
    color: rowMouse.containsMouse ? Commons.Color.launcher.selectionBackground : "transparent"
    border.color: wifiRow.navFocused ? Commons.Color.launcher.selectionBorder : "transparent"
    border.width: wifiRow.navFocused ? 2 : 0

    Row {
        id: rowInner
        anchors.left: parent.left
        anchors.right: forgetIcon.visible ? forgetIcon.left : parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: wifiRow.wifiIconFor(wifiRow.modelData.signal)
            color: wifiRow.modelData.connected ? Commons.Color.launcher.selection : Commons.Color.launcher.textMuted
            font.pixelSize: 15
        }

        Text {
            width: parent.width - 20 - (lockIcon.visible ? lockIcon.width + 4 : 0)
            text: wifiRow.modelData.ssid
            color: rowMouse.containsMouse ? Commons.Color.launcher.textOnMuted : Commons.Color.launcher.text
            font.pixelSize: 13
            font.bold: wifiRow.modelData.connected
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: lockIcon
            visible: wifiRow.requiresCredentials(wifiRow.modelData.security)
            anchors.verticalCenter: parent.verticalCenter
            text: "󰌾"
            color: Commons.Color.launcher.textMuted
            font.pixelSize: 11
        }
    }

    Text {
        id: forgetIcon
        visible: wifiRow.modelData.known && !wifiRow.modelData.connected
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: "󰅗"
        color: Commons.Color.launcher.textMuted
        font.pixelSize: 13

        MouseArea {
            anchors.fill: parent
            onClicked: wifiRow.forgetRequested()
        }
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: wifiRow.activateRequested()
    }
}
