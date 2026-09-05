import Quickshell
import Quickshell.Io
import QtQuick

import "../../Commons" as Commons
import "HyprmoncfgModel.js" as Model

// hyprmoncfg profile switcher + live layout editor, talking to hyprmoncfgd's socket directly; color/HDR and workspace planning stay TUI-only via "Open Editor".
Item {
    id: root
    property var shell
    property bool popupOpen: false
    property bool kbFocused: false
    readonly property bool kbAvailable: root.daemonRunning || root.statusProfiles.length > 0
    readonly property alias kbNavScope: kbNav
    function kbActivate() {
        root.open()
        root.refreshEditor()
        kbNav.reset()
    }
    property string home: Quickshell.env("HOME")

    property var editorDocument: null
    property var transaction: null
    property int transactionSecondsLeft: 0
    property string selectedKey: ""

    readonly property bool daemonRunning: sock.connected
    readonly property var statusProfiles: (sock.status && sock.status.profiles) || []
    readonly property string activeProfileName: (sock.status && sock.status.active_profile && sock.status.active_profile.name) || ""

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight
    // hyprmoncfg isn't installed/managing yet until a first profile exists.
    visible: root.daemonRunning || root.statusProfiles.length > 0

    HyprmoncfgSocket {
        id: sock
    }

    function open() { root.popupOpen = true }
    function close() { root.popupOpen = false }
    function toggle() { root.popupOpen = !root.popupOpen }

    IpcHandler {
        target: "monitorProfile"

        function open(): string { root.open(); return "ok" }
        function close(): string { root.close(); return "ok" }
        function toggle(): string { root.toggle(); return "ok" }
    }

    Connections {
        target: sock
        function onStatusChanged() {
            if (root.popupOpen && !root.transaction) root.refreshEditor()
        }
    }

    Timer {
        // Always-on: gating `running` on `!sock.connected` risks getting stuck if the notify signal doesn't fire on every failure mode.
        interval: 5000
        running: true
        repeat: true
        onTriggered: if (!sock.connected) sock.reconnect()
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        running: root.transaction !== null
        onTriggered: {
            if (!root.transaction) return
            var deadline = new Date(root.transaction.deadline).getTime()
            var left = Math.round((deadline - Date.now()) / 1000)
            if (left <= 0) {
                root.transaction = null
                root.refreshEditor()
            } else {
                root.transactionSecondsLeft = left
            }
        }
    }

    function refreshEditor() {
        sock.call("editor_state", undefined, function(result) {
            if (result) root.editorDocument = result
        })
    }

    onPopupOpenChanged: if (popupOpen) root.refreshEditor()

    function applyProfile(name) {
        sock.call("preview", { profile_name: name, timeout_seconds: 8 }, function(result) {
            if (!result) return
            sock.call("confirm", { transaction_id: result.id }, function() { root.refreshEditor() })
        })
    }

    function handleOutputMoved(key, x, y, snap) {
        if (!root.editorDocument) return
        sock.call("edit_profile", {
            profile: root.editorDocument.profile,
            edit: { output_key: key, x: x, y: y, snap_distance: snap }
        }, function(editResult) {
            if (!editResult) return
            var doc = Model.clone(root.editorDocument)
            doc.profile = editResult.profile
            doc.workspace_plan = editResult.workspace_plan
            root.editorDocument = doc
            sock.call("preview", { profile: editResult.profile, timeout_seconds: 8 }, function(transactionResult) {
                if (transactionResult) root.transaction = transactionResult
            })
        })
    }

    function confirmTransaction() {
        if (!root.transaction) return
        var id = root.transaction.id
        root.transaction = null
        sock.call("confirm", { transaction_id: id }, function() { root.refreshEditor() })
    }

    function revertTransaction() {
        if (!root.transaction) return
        var id = root.transaction.id
        root.transaction = null
        sock.call("revert", { transaction_id: id }, function() { root.refreshEditor() })
    }

    function openEditor() {
        root.popupOpen = false
        editorProcess.running = true
    }

    Process {
        id: editorProcess
        command: [root.home + "/bin/desktop", "monitor-profile-editor"]
    }

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
        font.pixelSize: 15
        text: "\u{F0379}"

        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.popupOpen = !root.popupOpen
                if (root.popupOpen) root.refreshEditor()
            }
        }
    }

    Commons.PopupPanel {
        id: popupPanel
        open: root.popupOpen
        namespace: "dotfiles-monitor-profile-popup"
        cardWidth: 320
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

                Text {
                    width: parent.width
                    text: "Monitor Layout"
                    color: Commons.Color.launcher.text
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    width: parent.width
                    visible: !root.daemonRunning
                    text: "hyprmoncfgd not running"
                    color: Commons.Color.launcher.textMuted
                    font.pixelSize: 11
                }

                MonitorCanvas {
                    width: parent.width
                    visible: root.daemonRunning && root.editorDocument !== null
                    profile: root.editorDocument ? root.editorDocument.profile : ({ outputs: [] })
                    editorDisplays: root.editorDocument ? root.editorDocument.displays : []
                    workspacePlan: root.editorDocument ? root.editorDocument.workspace_plan : []
                    selectedKey: root.selectedKey
                    interactive: root.transaction === null
                    onOutputSelected: function(key) { root.selectedKey = key }
                    onOutputMoved: function(key, x, y, snap) { root.handleOutputMoved(key, x, y, snap) }
                }

                Row {
                    width: parent.width
                    visible: root.transaction !== null
                    spacing: 8

                    Text {
                        width: parent.width - confirmBtn.width - revertBtn.width - 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Previewing -- reverts in " + root.transactionSecondsLeft + "s"
                        color: Commons.Color.launcher.textMuted
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        id: confirmBtn
                        property bool kbNavTarget: true
                        function kbActivate() { root.confirmTransaction() }
                        width: 60
                        height: 24
                        radius: 5
                        color: Commons.Color.launcher.selectionBackground
                        border.color: kbNav.focusedItem === confirmBtn ? Commons.Color.launcher.selection : Commons.Color.launcher.selectionBorder
                        border.width: kbNav.focusedItem === confirmBtn ? 2 : 1

                        Text {
                            anchors.centerIn: parent
                            text: "Confirm"
                            color: Commons.Color.launcher.textOnMuted
                            font.pixelSize: 10
                            font.bold: true
                        }

                        MouseArea { anchors.fill: parent; onClicked: root.confirmTransaction() }
                    }

                    Rectangle {
                        id: revertBtn
                        property bool kbNavTarget: true
                        function kbActivate() { root.revertTransaction() }
                        width: 50
                        height: 24
                        radius: 5
                        color: "transparent"
                        border.color: kbNav.focusedItem === revertBtn ? Commons.Color.launcher.selectionBorder : Commons.Color.launcher.cardBorder
                        border.width: kbNav.focusedItem === revertBtn ? 2 : 1

                        Text {
                            anchors.centerIn: parent
                            text: "Revert"
                            color: Commons.Color.launcher.text
                            font.pixelSize: 10
                        }

                        MouseArea { anchors.fill: parent; onClicked: root.revertTransaction() }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Commons.Color.launcher.cardBorder
                }

                Text {
                    width: parent.width
                    text: "Profiles"
                    color: Commons.Color.launcher.text
                    font.pixelSize: 12
                    font.bold: true
                }

                Text {
                    width: parent.width
                    visible: root.daemonRunning && root.statusProfiles.length === 0
                    text: "No saved profiles -- drag displays above and Confirm, or open the editor to save one"
                    color: Commons.Color.launcher.textMuted
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: root.statusProfiles

                    Rectangle {
                        id: profileRow
                        required property var modelData
                        property bool kbNavTarget: !modelData.active
                        function kbActivate() { root.applyProfile(profileRow.modelData.name) }
                        readonly property bool navFocused: kbNav.focusedItem === profileRow

                        width: parent.width
                        height: 36
                        radius: 6
                        color: modelData.active ? Commons.Color.launcher.selectionBackground : "transparent"
                        border.color: profileRow.navFocused ? Commons.Color.launcher.selection : (modelData.active ? Commons.Color.launcher.selectionBorder : Commons.Color.launcher.cardBorder)
                        border.width: profileRow.navFocused ? 2 : 1

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 8
                            spacing: 8

                            Text {
                                width: parent.width - (recommendedTag.visible ? recommendedTag.width + 8 : 0)
                                text: modelData.name
                                color: modelData.active ? Commons.Color.launcher.textOnMuted : Commons.Color.launcher.text
                                font.pixelSize: 12
                                font.bold: modelData.active
                                elide: Text.ElideRight
                            }

                            Text {
                                id: recommendedTag
                                visible: modelData.recommended && !modelData.active
                                text: "suggested"
                                color: Commons.Color.launcher.textMuted
                                font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !parent.modelData.active
                            onClicked: root.applyProfile(parent.modelData.name)
                        }
                    }
                }

                Rectangle {
                    id: openEditorButton
                    property bool kbNavTarget: true
                    function kbActivate() { root.openEditor() }
                    width: parent.width
                    height: openEditorColumn.implicitHeight + 16
                    radius: 6
                    color: "transparent"
                    border.color: kbNav.focusedItem === openEditorButton ? Commons.Color.launcher.selectionBorder : Commons.Color.launcher.cardBorder
                    border.width: kbNav.focusedItem === openEditorButton ? 2 : 1

                    Column {
                        id: openEditorColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 10
                        spacing: 2

                        Text {
                            width: parent.width
                            text: "Open Editor"
                            color: Commons.Color.launcher.text
                            font.pixelSize: 12
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            width: parent.width
                            text: "Save profiles, color/HDR, workspace planner"
                            color: Commons.Color.launcher.textMuted
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.openEditor()
                    }
                }
        }
    }
}
