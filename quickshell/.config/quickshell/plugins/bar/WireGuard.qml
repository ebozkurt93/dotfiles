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
    property var interfaces: []

    readonly property bool anyUp: {
        for (var i = 0; i < interfaces.length; i++) {
            if (interfaces[i].up) return true
        }
        return false
    }

    function refresh() {
        statusProvider.running = false
        statusProvider.command = [home + "/bin/wg-manager", "status-json"]
        statusProvider.running = true
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 10000
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
            try {
                var parsed = JSON.parse(statusProvider.buffer)
                root.interfaces = Array.isArray(parsed) ? parsed : []
            } catch (e) {
                console.warn("wg-manager status-json returned invalid JSON:", e)
            }
        }
    }

    Process {
        id: wgAction
        onExited: root.refresh()
    }

    function runToggle(name, up) {
        wgAction.command = [home + "/bin/wg-manager", up ? "down" : "up", name]
        wgAction.running = true
    }

    implicitWidth: icon.visible ? icon.implicitWidth : 0
    implicitHeight: icon.visible ? icon.implicitHeight : 0

    Text {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        visible: root.interfaces.length > 0
        color: Commons.Color.bar.text
        opacity: root.anyUp ? 1.0 : 0.45
        text: "󰖂"

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
        WlrLayershell.namespace: "dotfiles-wireguard-popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: root.popupOpen = false
        }

        Rectangle {
            id: popupCard
            width: 260
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
                spacing: 4

                Text {
                    width: parent.width
                    text: "WireGuard"
                    color: Commons.Color.launcher.text
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    width: parent.width
                    visible: root.interfaces.length === 0
                    text: "No interfaces configured"
                    color: Commons.Color.launcher.textMuted
                    font.pixelSize: 12
                }

                Repeater {
                    model: root.interfaces

                    Rectangle {
                        id: ifaceRow
                        required property var modelData

                        width: popupColumn.width
                        height: 30
                        radius: 6
                        color: ifaceMouse.containsMouse ? Commons.Color.launcher.selectionBackground : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6

                            Text {
                                width: parent.width - 70
                                text: ifaceRow.modelData.name || ""
                                color: Commons.Color.launcher.text
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                            Text {
                                width: 70
                                horizontalAlignment: Text.AlignRight
                                text: ifaceRow.modelData.up ? "Up" : "Down"
                                color: ifaceRow.modelData.up ? Commons.Color.launcher.text : Commons.Color.launcher.textMuted
                                font.pixelSize: 12
                            }
                        }

                        MouseArea {
                            id: ifaceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.runToggle(ifaceRow.modelData.name, ifaceRow.modelData.up)
                        }
                    }
                }
            }
        }
    }
}
