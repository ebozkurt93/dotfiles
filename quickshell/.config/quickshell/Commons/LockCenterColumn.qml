import Quickshell
import QtQuick

Column {
    id: root
    anchors.centerIn: parent
    width: Math.min(parent.width - 48, 560)
    spacing: 12

    property string username: ""
    property color passwordBoxBorderColor: Color.lock.border
    property var onPowerAction: function(command) {}
    default property alias passwordBoxContent: passwordBoxContentItem.data

    readonly property var powerButtons: [
        { label: "Sleep", command: "systemctl suspend", color: Color.lock.powerButtonBackground, border: Color.lock.powerButtonBorder, text: Color.lock.textOnMuted },
        { label: "Restart", command: "systemctl reboot", color: Color.lock.powerButtonBackground, border: Color.lock.powerButtonBorder, text: Color.lock.textOnMuted },
        { label: "Shutdown", command: "systemctl poweroff", color: Color.lock.dangerButtonBackground, border: Color.lock.dangerButtonBorder, text: Color.lock.dangerButtonText }
    ]

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Text {
        width: parent.width
        text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
        color: Color.lock.text
        opacity: 0.72
        font.pixelSize: 22
        horizontalAlignment: Text.AlignHCenter
    }

    Text {
        width: parent.width
        text: Qt.formatDateTime(clock.date, "hh:mm")
        color: Color.lock.text
        font.pixelSize: 116
        horizontalAlignment: Text.AlignHCenter
    }

    Text {
        width: parent.width
        text: root.username
        color: Color.lock.text
        opacity: 0.72
        font.pixelSize: 24
        horizontalAlignment: Text.AlignHCenter
    }

    Rectangle {
        width: 340
        height: 58
        radius: 12
        color: Color.lock.passwordBoxBackground
        border.color: root.passwordBoxBorderColor
        border.width: 1
        anchors.horizontalCenter: parent.horizontalCenter

        Item {
            id: passwordBoxContentItem
            anchors.fill: parent
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12
        topPadding: 18

        Repeater {
            model: root.powerButtons

            delegate: Rectangle {
                required property var modelData
                width: 124
                height: 44
                radius: 12
                color: buttonMouse.containsMouse ? Color.lock.powerButtonHover : modelData.color
                border.color: modelData.border
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: modelData.text
                    font.pixelSize: 15
                }

                MouseArea {
                    id: buttonMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.onPowerAction(modelData.command)
                }
            }
        }
    }
}
