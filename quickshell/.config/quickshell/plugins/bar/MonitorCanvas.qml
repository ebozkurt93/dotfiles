import QtQuick

import "../../Commons" as Commons
import "HyprmoncfgModel.js" as Model

// Adapted from crmne/omarchy-hyprmoncfg's DisplayCanvas.qml (MIT) onto this repo's Commons.Color tokens.
Item {
    id: root

    property var profile: ({ outputs: [] })
    property var editorDisplays: []
    property var workspacePlan: []
    property string selectedKey: ""
    property bool interactive: true

    signal outputSelected(string key)
    signal outputMoved(string key, int x, int y, int snapDistance)

    readonly property var displays: Model.profileLayoutDisplays(root.profile, root.editorDisplays)
    readonly property var bounds: Model.layoutBounds(root.displays)
    readonly property var metrics: Model.layoutMetrics(root.bounds, canvas.width, canvas.height, 10)
    readonly property string hiddenDisplays: Model.hiddenProfileDisplays(root.profile)

    implicitHeight: 170

    Text {
        id: hiddenLabel
        visible: root.hiddenDisplays !== ""
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        text: root.hiddenDisplays
        color: Commons.Color.launcher.textMuted
        font.pixelSize: 10
        elide: Text.ElideRight
    }

    Item {
        id: canvas
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: hiddenLabel.visible ? hiddenLabel.bottom : parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: hiddenLabel.visible ? 4 : 0

        Repeater {
            model: root.displays

            Rectangle {
                id: card
                required property var modelData
                readonly property var previewRect: Model.layoutRect(modelData, root.bounds, canvas.width, canvas.height, 6)
                property real dragOffsetX: 0
                property real dragOffsetY: 0
                readonly property bool selected: String(modelData.key || "") === root.selectedKey

                x: previewRect.x + dragOffsetX
                y: previewRect.y + dragOffsetY
                width: previewRect.width
                height: previewRect.height
                radius: 5
                color: selected ? Commons.Color.launcher.selectionBackground : Commons.Color.launcher.cardBackground
                border.width: selected ? 2 : 1
                border.color: selected ? Commons.Color.launcher.selectionBorder : Commons.Color.launcher.cardBorder

                Column {
                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - 8)
                    spacing: 1

                    Text {
                        width: parent.width
                        text: String(card.modelData.name || "Display")
                        color: card.selected ? Commons.Color.launcher.textOnMuted : Commons.Color.launcher.text
                        font.pixelSize: 10
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: parent.parent.height >= 56
                        width: parent.width
                        text: Model.displayModelLabel(card.modelData, true)
                        color: card.selected ? Commons.Color.launcher.textOnMuted : Commons.Color.launcher.textMuted
                        font.pixelSize: 9
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: parent.parent.height >= 70
                        width: parent.width
                        text: Model.displayScaleLayoutLabel(card.modelData)
                        color: Commons.Color.launcher.textMuted
                        font.pixelSize: 9
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    enabled: root.interactive
                    hoverEnabled: true
                    cursorShape: dragStarted ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                    property real pointerStartX: 0
                    property real pointerStartY: 0
                    property bool dragStarted: false

                    onPressed: function(mouse) {
                        root.outputSelected(String(card.modelData.key || ""))
                        var point = dragArea.mapToItem(canvas, mouse.x, mouse.y)
                        pointerStartX = point.x
                        pointerStartY = point.y
                        dragStarted = false
                        card.dragOffsetX = 0
                        card.dragOffsetY = 0
                    }
                    onPositionChanged: function(mouse) {
                        if (!pressed) return
                        var point = dragArea.mapToItem(canvas, mouse.x, mouse.y)
                        var deltaX = point.x - pointerStartX
                        var deltaY = point.y - pointerStartY
                        if (!dragStarted) {
                            var threshold = 5
                            if (deltaX * deltaX + deltaY * deltaY < threshold * threshold) return
                            dragStarted = true
                        }
                        card.dragOffsetX = deltaX
                        card.dragOffsetY = deltaY
                    }
                    onReleased: function(mouse) {
                        if (!dragStarted) {
                            card.dragOffsetX = 0
                            card.dragOffsetY = 0
                            return
                        }
                        var scale = Math.max(0.0001, Number(root.metrics.scale || 1))
                        var nextX = Math.round(Number(card.modelData.x || 0) + card.dragOffsetX / scale)
                        var nextY = Math.round(Number(card.modelData.y || 0) + card.dragOffsetY / scale)
                        var snap = Math.max(1, Math.round(12 / scale))
                        card.dragOffsetX = 0
                        card.dragOffsetY = 0
                        dragStarted = false
                        root.outputMoved(String(card.modelData.key || ""), nextX, nextY, snap)
                    }
                    onCanceled: {
                        dragStarted = false
                        card.dragOffsetX = 0
                        card.dragOffsetY = 0
                    }
                }
            }
        }

        Text {
            visible: root.displays.length === 0
            anchors.centerIn: parent
            text: "No enabled displays"
            color: Commons.Color.launcher.textMuted
            font.pixelSize: 11
        }
    }
}
