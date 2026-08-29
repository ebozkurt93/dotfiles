import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

import "../../Commons" as Commons

Item {
    id: root
    property var shell
    property string home: Quickshell.env("HOME")
    property bool popupOpen: false
    property var items: []
    onItemsChanged: listView.contentY = 0

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    function refresh() {
        historyProvider.running = false
        historyProvider.command = [home + "/bin/desktop", "notifications-history", "show"]
        historyProvider.running = true
    }

    function open() {
        root.popupOpen = true
        root.refresh()
    }

    function close() {
        root.popupOpen = false
    }

    function toggle() {
        if (root.popupOpen) {
            root.close()
        } else {
            root.open()
        }
    }

    function formatAgo(epochSeconds) {
        if (epochSeconds === null || epochSeconds === undefined) return ""
        var diffSec = Math.round(Date.now() / 1000 - epochSeconds)
        if (diffSec < 5) return "just now"
        if (diffSec < 60) return diffSec + "s ago"
        if (diffSec < 3600) return Math.round(diffSec / 60) + "m ago"
        if (diffSec < 86400) return Math.round(diffSec / 3600) + "h ago"
        return Math.round(diffSec / 86400) + "d ago"
    }

    IpcHandler {
        target: "notificationHistory"

        function open(): string {
            root.open()
            return "ok"
        }

        function close(): string {
            root.close()
            return "ok"
        }

        function toggle(): string {
            root.toggle()
            return "ok"
        }

        function refresh(): string {
            if (root.popupOpen) root.refresh()
            return "ok"
        }
    }

    Process {
        id: historyProvider
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text)
                    root.items = Array.isArray(parsed) ? parsed : []
                } catch (e) {
                    root.items = []
                }
            }
        }
    }

    Process {
        id: restoreAction
        command: [home + "/bin/desktop", "notifications-history", "restore"]
        onExited: root.close()
    }

    Process {
        id: clearAction
        command: [home + "/bin/desktop", "notifications-history", "clear"]
        onExited: root.refresh()
    }

    Text {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        color: Commons.Color.bar.text
        opacity: root.items.length > 0 ? 1.0 : 0.45
        text: "\u{F009C}"

        MouseArea {
            anchors.fill: parent
            onClicked: root.toggle()
        }
    }

    // Keeps "just now" / "Xs ago" labels moving while the panel is open.
    Timer {
        interval: 15000
        running: root.popupOpen
        repeat: true
        onTriggered: root.items = root.items.slice()
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
        WlrLayershell.namespace: "dotfiles-notification-history-popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.popupOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Rectangle {
            id: popupCard
            width: 340
            // listView's own height is derived from this height (anchored to popupCard.bottom below), so
            // sizing off listView.contentHeight here would be circular -- it only resolves correctly after
            // some other relayout (e.g. scrolling) forces Qt to re-settle the binding. Estimate from
            // items.length instead, which is known synchronously with no layout feedback involved.
            readonly property real estimatedRowHeight: 54
            readonly property real listAreaHeight: root.items.length === 0 ? 40 : Math.min(root.items.length * estimatedRowHeight, 420)
            height: headerColumn.implicitHeight + 24 + listAreaHeight + 12
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 36
            anchors.rightMargin: 8
            radius: 10
            color: Commons.Color.launcher.cardBackground
            border.color: Commons.Color.launcher.cardBorder
            border.width: 1

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            Column {
                id: headerColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 10

                Row {
                    width: parent.width
                    spacing: 10

                    Text {
                        id: headerIcon
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u{F009C}"
                        color: Commons.Color.launcher.text
                        font.pixelSize: 18
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - headerIcon.implicitWidth - restoreLabel.implicitWidth - clearLabel.implicitWidth - 40
                        spacing: 0

                        Text {
                            width: parent.width
                            text: "Notifications"
                            color: Commons.Color.launcher.text
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.items.length === 1 ? "1 recent" : root.items.length + " recent"
                            color: Commons.Color.launcher.textMuted
                            font.pixelSize: 10
                        }
                    }

                    Text {
                        id: restoreLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Restore"
                        color: restoreArea.containsMouse ? Commons.Color.launcher.selection : Commons.Color.launcher.textMuted
                        font.pixelSize: 11

                        MouseArea {
                            id: restoreArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: restoreAction.running = true
                        }
                    }

                    Text {
                        id: clearLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Clear"
                        color: clearArea.containsMouse ? Commons.Color.danger : Commons.Color.launcher.textMuted
                        font.pixelSize: 11

                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: clearAction.running = true
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Commons.Color.launcher.cardBorder
                }
            }

            Text {
                anchors.top: headerColumn.bottom
                anchors.topMargin: 16
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.items.length === 0
                text: "No recent notifications"
                color: Commons.Color.launcher.textMuted
                font.pixelSize: 12
            }

            ListView {
                id: listView
                anchors.top: headerColumn.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 12
                anchors.topMargin: 8
                clip: true
                spacing: 1
                boundsBehavior: Flickable.StopAtBounds
                model: root.items

                delegate: Rectangle {
                    id: rowDelegate
                    required property var modelData
                    readonly property bool hasImage: typeof modelData.app_icon === "string" && modelData.app_icon.indexOf("/") === 0
                    property bool tooltipShowsTitle: false
                    readonly property bool tooltipVisible: (titleHover.containsMouse && titleText.truncated)
                        || (bodyHover.containsMouse && bodyText.truncated)
                    width: listView.width
                    height: rowContent.implicitHeight + 16
                    // z:10 on just the tooltip child only wins against its own siblings within this
                    // delegate -- it doesn't paint above the *next* delegate (a ListView sibling one level
                    // up), which is why the row below was bleeding through. Lift the whole delegate instead.
                    z: tooltipVisible ? 10 : 0
                    radius: 6
                    color: rowArea.containsMouse ? Commons.Color.launcher.selectionBackground : Commons.Color.transparent

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    Row {
                        id: rowContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        // Fixed-width slot regardless of whether this row has a real icon, so every
                        // row's text column starts at the same x -- letting Image collapse to 0 width
                        // when absent (the previous approach) misaligned icon vs. non-icon rows.
                        // Matches how macOS/Android/GNOME notification lists always reserve this slot
                        // and fall back to a generic icon rather than collapsing it.
                        Item {
                            id: iconSlot
                            width: 28
                            height: 28
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                visible: rowDelegate.hasImage
                                anchors.fill: parent
                                source: rowDelegate.hasImage ? "file://" + rowDelegate.modelData.app_icon : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            Text {
                                visible: !rowDelegate.hasImage
                                anchors.centerIn: parent
                                text: "\u{F009C}"
                                color: Commons.Color.launcher.textMuted
                                opacity: 0.6
                                font.pixelSize: 14
                            }
                        }

                        Column {
                            width: parent.width - iconSlot.width - parent.spacing
                            spacing: 2

                            Row {
                                width: parent.width
                                spacing: 6

                                Text {
                                    id: titleText
                                    width: parent.width - timeLabel.implicitWidth - 6
                                    text: rowDelegate.modelData.summary || "Notification"
                                    color: rowDelegate.modelData.urgency === "critical" ? Commons.Color.danger : Commons.Color.launcher.text
                                    font.pixelSize: 12
                                    font.bold: true
                                    elide: Text.ElideRight

                                    MouseArea {
                                        id: titleHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onContainsMouseChanged: if (containsMouse) rowDelegate.tooltipShowsTitle = true
                                    }
                                }

                                Text {
                                    id: timeLabel
                                    text: root.formatAgo(rowDelegate.modelData.received_at)
                                    color: Commons.Color.launcher.textMuted
                                    font.pixelSize: 9
                                }
                            }

                            Text {
                                width: parent.width
                                visible: !!rowDelegate.modelData.app_name
                                text: rowDelegate.modelData.app_name || ""
                                color: Commons.Color.launcher.textMuted
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }

                            Text {
                                id: bodyText
                                width: parent.width
                                visible: !!rowDelegate.modelData.body
                                text: rowDelegate.modelData.body || ""
                                color: Commons.Color.launcher.textMuted
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight

                                MouseArea {
                                    id: bodyHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onContainsMouseChanged: if (containsMouse) rowDelegate.tooltipShowsTitle = false
                                }
                            }
                        }
                    }

                    // Only appears when the hovered text is actually truncated -- untruncated rows never
                    // pop this up. Floats over neighboring rows (z above the ListView content) rather than
                    // pushing layout, since a delegate can't resize itself to fit a hover-only overlay.
                    Rectangle {
                        visible: rowDelegate.tooltipVisible
                        z: 10
                        anchors.top: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 2
                        radius: 6
                        color: Commons.Color.launcher.cardBackground
                        border.color: Commons.Color.launcher.cardBorder
                        border.width: 1
                        height: tooltipText.implicitHeight + 12

                        Text {
                            id: tooltipText
                            anchors.fill: parent
                            anchors.margins: 6
                            text: rowDelegate.tooltipShowsTitle ? (rowDelegate.modelData.summary || "") : (rowDelegate.modelData.body || "")
                            color: Commons.Color.launcher.text
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
