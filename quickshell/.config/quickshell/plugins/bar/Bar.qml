import Quickshell
import Quickshell.Hyprland
import QtQuick

import "../../Commons" as Commons

PanelWindow {
    id: root
    property var shell

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 32
    color: Commons.Color.bar.background

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
                color: modelData.active ? Commons.Color.bar.workspaceActive : Commons.Color.bar.workspaceInactive
                Text {
                    anchors.centerIn: parent
                    text: modelData.name
                    color: Commons.Color.bar.text
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        color: Commons.Color.bar.text
        text: Qt.formatDateTime(clock.date, "ddd MMM d  hh:mm:ss")

        SystemClock {
            id: clock
            precision: SystemClock.Seconds
        }
    }
}
