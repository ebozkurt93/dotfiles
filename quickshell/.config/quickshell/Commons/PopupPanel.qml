import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    property bool open: false
    property string namespace: "dotfiles-popup"
    property bool wantsKeyboardFocus: false
    property int cardWidth: 280
    property real cardHeight: 200
    property int cardRadius: 8
    property int topMargin: 36
    property int rightMargin: 8

    default property alias content: contentItem.data

    signal dismissRequested()

    visible: root.open
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: Color.transparent
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: root.namespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.wantsKeyboardFocus ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissRequested()
    }

    Rectangle {
        id: card
        width: root.cardWidth
        height: root.cardHeight
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: root.topMargin
        anchors.rightMargin: root.rightMargin
        radius: root.cardRadius
        color: Color.launcher.cardBackground
        border.color: Color.launcher.cardBorder
        border.width: 1

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Item {
            id: contentItem
            anchors.fill: parent
        }
    }
}
