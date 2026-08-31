import QtQuick

Rectangle {
    id: toggleSwitch
    property bool checked: false
    signal toggled()

    width: 40
    height: 22
    radius: 11
    color: checked ? Color.launcher.selection : Color.launcher.cardBorder

    Rectangle {
        width: 18
        height: 18
        radius: 9
        color: Color.launcher.cardBackground
        anchors.verticalCenter: parent.verticalCenter
        x: toggleSwitch.checked ? parent.width - width - 2 : 2

        Behavior on x {
            NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: toggleSwitch.toggled()
    }
}
