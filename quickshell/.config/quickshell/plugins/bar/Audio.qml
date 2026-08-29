import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick

import "../../Commons" as Commons

Item {
    id: root
    property var shell
    property bool popupOpen: false

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []

    readonly property var sinkNodes: {
        var list = []
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (n && n.isSink && !n.isStream && n.audio) list.push(n)
        }
        return list
    }

    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property bool hasInput: !!(source && source.audio)
    readonly property bool inputMuted: hasInput ? source.audio.muted : false

    // PwNode.audio is inert until the node is tracked here.
    PwObjectTracker { objects: root.sinkNodes }
    PwObjectTracker { objects: root.source ? [root.source] : [] }

    function volumeIcon() {
        if (!sink || !sink.audio) return "󰸈"
        if (muted) return "󰝟"
        if (volume >= 0.67) return "󰕾"
        if (volume >= 0.34) return "󰖀"
        if (volume > 0) return "󰕿"
        return "󰕿"
    }

    function setVolume(v) {
        if (!sink || !sink.audio) return
        sink.audio.volume = Math.max(0, Math.min(1, v))
    }

    function toggleMute() {
        if (sink && sink.audio) sink.audio.muted = !sink.audio.muted
    }

    function toggleInputMute() {
        if (source && source.audio) source.audio.muted = !source.audio.muted
    }

    function setDefaultSink(node) {
        if (!node) return
        Pipewire.preferredDefaultAudioSink = node
    }

    function nodeLabel(node) {
        if (!node) return ""
        return node.description || node.nickname || node.name || ""
    }

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    Text {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        color: Commons.Color.bar.text
        opacity: root.muted ? 0.45 : 1.0
        // These speaker glyphs render smaller than other bar icons at the same pixelSize; bumped to compensate.
        font.pixelSize: 15
        text: root.volumeIcon()

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) root.toggleMute()
                else {
                    root.popupOpen = !root.popupOpen
                }
            }
            onWheel: function(wheel) {
                root.setVolume(root.volume + (wheel.angleDelta.y / 120) * 0.05)
            }
        }
    }

    PanelWindow {
        id: popupPanel
        visible: root.popupOpen
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: Commons.Color.transparent
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "dotfiles-audio-popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: root.popupOpen = false
        }

        Rectangle {
            id: popupCard
            width: 280
            height: popupColumn.implicitHeight + 24
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 36
            anchors.rightMargin: 8
            radius: 8
            color: Commons.Color.launcher.cardBackground
            border.color: Commons.Color.launcher.cardBorder
            border.width: 1

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            Column {
                id: popupColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 10

                Item {
                    id: headerRow
                    width: parent.width
                    height: Math.max(headerIcon.implicitHeight, headerText.implicitHeight, headerPercent.implicitHeight)

                    Text {
                        id: headerIcon
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.volumeIcon()
                        color: Commons.Color.launcher.text
                        font.pixelSize: 22
                    }

                    Text {
                        id: headerPercent
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(root.volume * 100) + "%"
                        color: Commons.Color.launcher.text
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Column {
                        id: headerText
                        anchors.left: headerIcon.right
                        anchors.leftMargin: 10
                        anchors.right: headerPercent.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: "Audio"
                            color: Commons.Color.launcher.text
                            font.pixelSize: 14
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            text: root.muted ? "MUTED" : root.nodeLabel(root.sink)
                            color: Commons.Color.launcher.textMuted
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }
                }

                Item {
                    id: volumeSliderRow
                    width: parent.width
                    height: 20
                    opacity: root.muted ? 0.5 : 1.0

                    Rectangle {
                        id: sliderTrack
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 6
                        radius: 3
                        color: Commons.Color.launcher.cardBorder

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, root.volume))
                            height: parent.height
                            radius: 3
                            color: Commons.Color.launcher.selection
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onPressed: function(mouse) { root.setVolume(mouse.x / width) }
                        onPositionChanged: function(mouse) { if (pressed) root.setVolume(mouse.x / width) }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Commons.Color.launcher.cardBorder
                }

                Text {
                    width: parent.width
                    text: "OUTPUT"
                    color: Commons.Color.launcher.textMuted
                    font.pixelSize: 10
                }

                Repeater {
                    model: root.sinkNodes

                    Rectangle {
                        id: sinkRow
                        required property var modelData

                        readonly property bool isActive: root.sink && modelData.id === root.sink.id

                        width: parent ? parent.width : 0
                        height: sinkInner.implicitHeight + 12
                        radius: 6
                        color: sinkMouse.containsMouse ? Commons.Color.launcher.selectionBackground : "transparent"

                        Row {
                            id: sinkInner
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 8

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: sinkRow.isActive ? "󰓃" : "󰓄"
                                color: sinkRow.isActive ? Commons.Color.launcher.selection : Commons.Color.launcher.textMuted
                                font.pixelSize: 16
                            }

                            Text {
                                width: parent.width - 24
                                text: root.nodeLabel(sinkRow.modelData)
                                color: Commons.Color.launcher.text
                                font.pixelSize: 13
                                font.bold: sinkRow.isActive
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: sinkMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.setDefaultSink(sinkRow.modelData)
                        }
                    }
                }

                Rectangle {
                    visible: root.hasInput
                    width: parent.width
                    height: 1
                    color: Commons.Color.launcher.cardBorder
                }

                Item {
                    visible: root.hasInput
                    width: parent.width
                    height: Math.max(micIcon.implicitHeight, micLabel.implicitHeight, micSwitch.height)

                    Text {
                        id: micIcon
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.inputMuted ? "󰍭" : "󰍬"
                        color: Commons.Color.launcher.text
                        font.pixelSize: 16
                    }

                    Text {
                        id: micLabel
                        anchors.left: micIcon.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Microphone"
                        color: Commons.Color.launcher.text
                        font.pixelSize: 13
                    }

                    Rectangle {
                        id: micSwitch
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 22
                        radius: 11
                        color: root.inputMuted ? Commons.Color.launcher.cardBorder : Commons.Color.launcher.selection

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: Commons.Color.launcher.cardBackground
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.inputMuted ? 2 : parent.width - width - 2

                            Behavior on x {
                                NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.toggleInputMute()
                        }
                    }
                }
            }
        }
    }
}
