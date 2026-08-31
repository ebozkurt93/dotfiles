import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root
    property var shell
    property string home: Quickshell.env("HOME")
    property bool active: false

    property string ipcTarget: ""
    property string desktopCommand: ""
    property string glyph: ""

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight
    visible: root.active

    function refresh() {
        statusProvider.running = false
        statusProvider.command = [home + "/bin/desktop", desktopCommand, "status"]
        statusProvider.running = true
    }

    Component.onCompleted: refresh()

    IpcHandler {
        target: root.ipcTarget

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
        command: [home + "/bin/desktop", desktopCommand, "off"]
    }

    Text {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        color: Color.bar.text
        text: root.glyph

        MouseArea {
            anchors.fill: parent
            onDoubleClicked: disableAction.running = true
        }
    }
}
