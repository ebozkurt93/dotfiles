import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

import "../../Commons" as Commons

Item {
    id: root
    property var shell
    property bool popupOpen: false
    property bool kbFocused: false
    readonly property bool kbAvailable: true
    readonly property alias kbNavScope: kbNav
    function kbActivate() {
        root.popupOpen = true
        kbNav.reset()
    }

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

    readonly property var sourceNodes: {
        var list = []
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            // type is a plain ordinal, not a bitmask -- strict equality, not `&`.
            if (n && !n.isStream && n.audio
                && (n.type === PwNodeType.AudioSource || n.type === PwNodeType.AudioDuplex)) list.push(n)
        }
        return list
    }

    // Playback streams only -- per-app mic gain isn't a thing either OS mixer exposes.
    readonly property var appStreamNodes: {
        var list = []
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (n && n.isStream && n.audio && n.type === PwNodeType.AudioOutStream) list.push(n)
        }
        return list
    }

    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property bool hasInput: !!(source && source.audio)
    readonly property bool inputMuted: hasInput ? source.audio.muted : false
    readonly property real inputVolume: hasInput ? source.audio.volume : 0

    // PwNode.audio is inert until the node is tracked here.
    PwObjectTracker { objects: root.sinkNodes }
    PwObjectTracker { objects: root.sourceNodes }
    PwObjectTracker { objects: root.appStreamNodes }

    IpcHandler {
        target: "audio"

        function open(): string {
            root.popupOpen = true
            return "ok"
        }

        function close(): string {
            root.popupOpen = false
            return "ok"
        }

        function toggle(): string {
            root.popupOpen = !root.popupOpen
            return "ok"
        }
    }

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

    function setInputVolume(v) {
        if (!source || !source.audio) return
        source.audio.volume = Math.max(0, Math.min(1, v))
    }

    function setAppVolume(node, v) {
        if (!node || !node.audio) return
        node.audio.volume = Math.max(0, Math.min(1, v))
    }

    function toggleAppMute(node) {
        if (node && node.audio) node.audio.muted = !node.audio.muted
    }

    function appLabel(node) {
        if (!node) return ""
        var props = node.properties || {}
        return props["application.name"] || nodeLabel(node)
    }

    function setDefaultSink(node) {
        if (!node) return
        Pipewire.preferredDefaultAudioSink = node
    }

    function setDefaultSource(node) {
        if (!node) return
        Pipewire.preferredDefaultAudioSource = node
    }

    function nodeLabel(node) {
        if (!node) return ""
        return node.description || node.nickname || node.name || ""
    }

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    Rectangle {
        visible: root.kbFocused
        anchors.centerIn: icon
        width: icon.implicitWidth + 10
        height: icon.implicitHeight + 6
        radius: 4
        color: Commons.Color.launcher.selectionBackground
        border.color: Commons.Color.launcher.selectionBorder
        border.width: 1.5
    }

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

    Commons.PopupPanel {
        id: popupPanel
        open: root.popupOpen
        namespace: "dotfiles-audio-popup"
        cardWidth: 280
        cardHeight: popupColumn.implicitHeight + 24
        onDismissRequested: root.popupOpen = false

        Commons.KbNavScope {
            id: kbNav
            content: popupColumn
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
                    property bool kbNavTarget: true
                    function kbActivate() { root.toggleMute() }
                    function kbAdjust(delta) { root.setVolume(root.volume + delta * 0.05) }
                    readonly property bool navFocused: kbNav.focusedItem === volumeSliderRow
                    width: parent.width
                    height: 20
                    opacity: root.muted ? 0.5 : 1.0

                    Rectangle {
                        id: sliderTrack
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: volumeSliderRow.navFocused ? 8 : 6
                        radius: 4
                        color: Commons.Color.launcher.cardBorder
                        border.color: volumeSliderRow.navFocused ? Commons.Color.launcher.selectionBorder : "transparent"
                        border.width: volumeSliderRow.navFocused ? 1.5 : 0

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
                        property bool kbNavTarget: true
                        function kbActivate() { root.setDefaultSink(sinkRow.modelData) }
                        readonly property bool navFocused: kbNav.focusedItem === sinkRow

                        readonly property bool isActive: root.sink && modelData.id === root.sink.id

                        width: parent ? parent.width : 0
                        height: sinkInner.implicitHeight + 12
                        radius: 6
                        color: sinkMouse.containsMouse ? Commons.Color.launcher.selectionBackground : "transparent"
                        border.color: sinkRow.navFocused ? Commons.Color.launcher.selectionBorder : "transparent"
                        border.width: sinkRow.navFocused ? 2 : 0

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
                                color: sinkMouse.containsMouse ? Commons.Color.launcher.textOnMuted : Commons.Color.launcher.text
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
                    id: micRow
                    visible: root.hasInput
                    width: parent.width
                    height: Math.max(micIcon.implicitHeight, micLabel.implicitHeight, micPercent.implicitHeight, micSwitch.height)

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
                        text: root.nodeLabel(root.source)
                        color: Commons.Color.launcher.text
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        width: parent.width - micIcon.width - 8 - micPercent.implicitWidth - 8 - micSwitch.width - 8
                    }

                    Text {
                        id: micPercent
                        anchors.right: micSwitch.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(root.inputVolume * 100) + "%"
                        color: Commons.Color.launcher.textMuted
                        font.pixelSize: 11
                    }

                    Commons.ToggleSwitch {
                        id: micSwitch
                        property bool kbNavTarget: root.hasInput
                        function kbActivate() { root.toggleInputMute() }
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        checked: !root.inputMuted
                        border.color: kbNav.focusedItem === micSwitch ? Commons.Color.launcher.selectionBorder : "transparent"
                        border.width: kbNav.focusedItem === micSwitch ? 2 : 0
                        onToggled: root.toggleInputMute()
                    }
                }

                Item {
                    id: inputVolumeSliderRow
                    property bool kbNavTarget: root.hasInput
                    function kbActivate() { root.toggleInputMute() }
                    function kbAdjust(delta) { root.setInputVolume(root.inputVolume + delta * 0.05) }
                    readonly property bool navFocused: kbNav.focusedItem === inputVolumeSliderRow
                    visible: root.hasInput
                    width: parent.width
                    height: 20
                    opacity: root.inputMuted ? 0.5 : 1.0

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: inputVolumeSliderRow.navFocused ? 8 : 6
                        radius: 4
                        color: Commons.Color.launcher.cardBorder
                        border.color: inputVolumeSliderRow.navFocused ? Commons.Color.launcher.selectionBorder : "transparent"
                        border.width: inputVolumeSliderRow.navFocused ? 1.5 : 0

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, root.inputVolume))
                            height: parent.height
                            radius: 3
                            color: Commons.Color.launcher.selection
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onPressed: function(mouse) { root.setInputVolume(mouse.x / width) }
                        onPositionChanged: function(mouse) { if (pressed) root.setInputVolume(mouse.x / width) }
                    }
                }

                Text {
                    visible: root.hasInput
                    width: parent.width
                    text: "INPUT"
                    color: Commons.Color.launcher.textMuted
                    font.pixelSize: 10
                }

                Repeater {
                    model: root.hasInput ? root.sourceNodes : []

                    Rectangle {
                        id: sourceRow
                        required property var modelData
                        property bool kbNavTarget: true
                        function kbActivate() { root.setDefaultSource(sourceRow.modelData) }
                        readonly property bool navFocused: kbNav.focusedItem === sourceRow

                        readonly property bool isActive: root.source && modelData.id === root.source.id

                        width: parent ? parent.width : 0
                        height: sourceInner.implicitHeight + 12
                        radius: 6
                        color: sourceMouse.containsMouse ? Commons.Color.launcher.selectionBackground : "transparent"
                        border.color: sourceRow.navFocused ? Commons.Color.launcher.selectionBorder : "transparent"
                        border.width: sourceRow.navFocused ? 2 : 0

                        Row {
                            id: sourceInner
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 8

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰍬"
                                color: sourceRow.isActive ? Commons.Color.launcher.selection : Commons.Color.launcher.textMuted
                                font.pixelSize: 16
                            }

                            Text {
                                width: parent.width - 24
                                text: root.nodeLabel(sourceRow.modelData)
                                color: sourceMouse.containsMouse ? Commons.Color.launcher.textOnMuted : Commons.Color.launcher.text
                                font.pixelSize: 13
                                font.bold: sourceRow.isActive
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: sourceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.setDefaultSource(sourceRow.modelData)
                        }
                    }
                }

                Rectangle {
                    visible: root.appStreamNodes.length > 0
                    width: parent.width
                    height: 1
                    color: Commons.Color.launcher.cardBorder
                }

                Text {
                    visible: root.appStreamNodes.length > 0
                    width: parent.width
                    text: "APPS"
                    color: Commons.Color.launcher.textMuted
                    font.pixelSize: 10
                }

                Repeater {
                    model: root.appStreamNodes

                    Column {
                        id: appRow
                        required property var modelData
                        property bool kbNavTarget: true
                        function kbActivate() { root.toggleAppMute(appRow.modelData) }
                        function kbAdjust(delta) { root.setAppVolume(appRow.modelData, appRow.appVolume + delta * 0.05) }
                        readonly property bool navFocused: kbNav.focusedItem === appRow
                        width: parent ? parent.width : 0
                        spacing: 4

                        readonly property real appVolume: modelData.audio ? modelData.audio.volume : 0
                        readonly property bool appMuted: modelData.audio ? modelData.audio.muted : false

                        Item {
                            width: parent.width
                            height: Math.max(appIcon.implicitHeight, appNameText.implicitHeight, appPercent.implicitHeight)

                            Text {
                                id: appIcon
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: appRow.appMuted ? "󰝟" : "󰎈"
                                color: appRow.appMuted ? Commons.Color.launcher.textMuted : Commons.Color.launcher.text
                                font.pixelSize: 14

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.toggleAppMute(appRow.modelData)
                                }
                            }

                            Text {
                                id: appNameText
                                anchors.left: appIcon.right
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - appIcon.width - 8 - appPercent.implicitWidth - 8
                                text: root.appLabel(appRow.modelData)
                                color: Commons.Color.launcher.text
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }

                            Text {
                                id: appPercent
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round(appRow.appVolume * 100) + "%"
                                color: Commons.Color.launcher.textMuted
                                font.pixelSize: 11
                            }
                        }

                        Item {
                            width: parent.width
                            height: 14
                            opacity: appRow.appMuted ? 0.5 : 1.0

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: appRow.navFocused ? 7 : 5
                                radius: height / 2
                                color: Commons.Color.launcher.cardBorder
                                border.color: appRow.navFocused ? Commons.Color.launcher.selectionBorder : "transparent"
                                border.width: appRow.navFocused ? 1.5 : 0

                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, appRow.appVolume))
                                    height: parent.height
                                    radius: height / 2
                                    color: Commons.Color.launcher.selection
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onPressed: function(mouse) { root.setAppVolume(appRow.modelData, mouse.x / width) }
                                onPositionChanged: function(mouse) { if (pressed) root.setAppVolume(appRow.modelData, mouse.x / width) }
                            }
                        }
                    }
                }
        }
    }
}
