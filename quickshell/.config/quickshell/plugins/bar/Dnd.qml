import Quickshell
import Quickshell.Io
import QtQuick

import "../../Commons" as Commons

Item {
    id: root
    property var shell
    property string home: Quickshell.env("HOME")
    property bool active: false

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight
    visible: root.active

    function refresh() {
        statusProvider.running = false
        statusProvider.command = [home + "/bin/desktop", "notifications-dnd", "status"]
        statusProvider.running = true
    }

    Component.onCompleted: refresh()

    IpcHandler {
        target: "notificationsDnd"

        function refresh(): string {
            root.refresh()
            return "ok"
        }
    }

    Process {
        id: statusProvider
        stdout: StdioCollector {
            onStreamFinished: root.active = text.trim() === "on"
        }
    }

    Process {
        id: disableAction
        command: [home + "/bin/desktop", "notifications-dnd", "off"]
    }

    Text {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        color: Commons.Color.bar.text
        text: "\u{F0F65}"

        MouseArea {
            anchors.fill: parent
            onDoubleClicked: disableAction.running = true
        }
    }
}
