import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

import "../../Commons" as Commons

PanelWindow {
    id: root
    property var shell

    Commons.BarKbNav {
        id: kbNav
        // Every keyboard-navigable bar icon; each exposes kbAvailable/kbFocused/kbActivate (+ popupOpen/kbNavScope if it has a popup).
        candidates: [
            notificationHistoryItem, networkItem, wireGuardItem, tailscaleItem,
            bluetoothItem, audioItem, monitorItem, monitorProfileItem,
            weatherItem, powerItem, sleepItem, nowPlayingItem,
            notificationsPrivacyItem, notificationsDndItem
        ]
    }

    IpcHandler {
        target: "barNav"

        function toggle(): string {
            if (kbNav.active) kbNav.close()
            else { kbNav.open(); navFocusItem.forceActiveFocus() }
            return "ok"
        }
    }

    WlrLayershell.keyboardFocus: kbNav.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item {
        id: navFocusItem
        anchors.fill: parent
        focus: kbNav.active

        Keys.onPressed: function(event) { kbNav.handleKey(event) }
    }

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
            id: nowPlayingItem
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 8
        spacing: 10

        Commons.DesktopToggleIcon {
            id: notificationsPrivacyItem
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
            ipcTarget: "notificationsPrivacy"
            desktopCommand: "notifications-privacy"
            glyph: "\u{F009B}"
        }

        Commons.DesktopToggleIcon {
            id: notificationsDndItem
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
            ipcTarget: "notificationsDnd"
            desktopCommand: "notifications-dnd"
            glyph: "\u{F0F65}"
        }

        NotificationHistory {
            id: notificationHistoryItem
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }

        Network {
            id: networkItem
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }

        WireGuard {
            id: wireGuardItem
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }

        Tailscale {
            id: tailscaleItem
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }

        Bluetooth {
            id: bluetoothItem
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }

        Audio {
            id: audioItem
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }

        Monitor {
            id: monitorItem
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }

        MonitorProfile {
            id: monitorProfileItem
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }

        Weather {
            id: weatherItem
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }

        Power {
            id: powerItem
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }

        Sleep {
            id: sleepItem
            shell: root.shell
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
