import Quickshell
import Quickshell.Hyprland
import QtQuick

ShellRoot {
    PanelWindow {
        anchors {
            top: true
            left: true
            right: true
        }
        height: 32
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
}
