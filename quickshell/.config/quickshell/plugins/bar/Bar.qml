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
                    color: modelData.active ? Commons.Color.bar.textOnWorkspaceActive : Commons.Color.bar.textOnWorkspaceInactive
                }
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 14

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Commons.Color.bar.text
            text: Qt.formatDateTime(clock.date, "ddd MMM d  hh:mm:ss")

            SystemClock {
                id: clock
                precision: SystemClock.Seconds
            }
        }

        NowPlaying {
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 8
        spacing: 10

        NotificationPrivacy {
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }

        Dnd {
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }

        NotificationHistory {
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }

        Network {
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }

        WireGuard {
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }

        Tailscale {
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }

        Bluetooth {
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }

        Audio {
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }

        Monitor {
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }

        MonitorProfile {
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }

        Weather {
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }

        Power {
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }

        Sleep {
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
