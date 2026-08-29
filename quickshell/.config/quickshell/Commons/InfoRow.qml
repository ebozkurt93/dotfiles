import QtQuick

Item {
    property string label: ""
    property string value: ""

    width: parent ? parent.width : 0
    height: visible ? labelText.implicitHeight : 0

    Text {
        id: labelText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: label
        color: Color.launcher.textMuted
        font.pixelSize: 11
    }

    Text {
        anchors.left: labelText.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        text: value
        color: Color.launcher.text
        font.pixelSize: 11
        elide: Text.ElideRight
    }
}
