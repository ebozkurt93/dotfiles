import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import QtQuick

import "../../Commons" as Commons

Item {
    id: root
    property var shell

    property bool lockRequested: false
    property bool lockPreviewOpen: false
    property bool lockAuthenticating: false
    property string lockPassword: ""
    property string lockPendingPassword: ""
    property string lockFailure: ""
    property int lockFailedAttempts: 0
    property string currentUser: Quickshell.env("USER") || Quickshell.env("LOGNAME")
    property var lockPasswordField: null

    function focusLockPassword() {
        if (lockPasswordField) lockPasswordField.forceActiveFocus()
    }

    function beginLock() {
        lockPassword = ""
        lockPendingPassword = ""
        lockFailure = ""
        lockFailedAttempts = 0
        lockAuthenticating = false
        lockRequested = true
        sessionLock.locked = true
        Qt.callLater(focusLockPassword)
        return true
    }

    function finishUnlock() {
        lockRequested = false
        lockAuthenticating = false
        lockPassword = ""
        lockPendingPassword = ""
        lockFailure = ""
        sessionLock.locked = false
    }

    function submitLockPassword() {
        var password = String(lockPassword || "")
        if (!lockRequested || lockAuthenticating || password.length === 0) return
        lockPendingPassword = password
        lockPassword = ""
        lockFailure = ""
        lockAuthenticating = true
        if (!lockPam.start()) handleLockFailure()
        else Qt.callLater(respondToLockPasswordPrompt)
    }

    function respondToLockPasswordPrompt() {
        if (lockAuthenticating && lockPam.active && lockPam.responseRequired) {
            lockPam.respond(lockPendingPassword)
        }
    }

    function handleLockFailure() {
        lockAuthenticating = false
        lockPendingPassword = ""
        lockFailedAttempts += 1
        lockFailure = "Authentication failed"
        Qt.callLater(focusLockPassword)
    }

    function runLockPowerAction(command) {
        if (!command) return
        lockPowerRunner.command = ["bash", "-lc", command]
        lockPowerRunner.running = true
    }

    Process {
        id: lockPowerRunner
    }

    PamContext {
        id: lockPam
        config: "dotfiles-lock"
        user: root.currentUser
        onResponseRequiredChanged: root.respondToLockPasswordPrompt()
        onPamMessage: root.respondToLockPasswordPrompt()
        onCompleted: function(result) {
            root.lockAuthenticating = false
            root.lockPendingPassword = ""
            if (!root.lockRequested) return
            if (result === PamResult.Success) root.finishUnlock()
            else root.handleLockFailure()
        }
        onError: function(error) {
            root.handleLockFailure()
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): string {
            if (!root.lockRequested) root.beginLock()
            return "ok"
        }

        function status(): string {
            return JSON.stringify({
                requested: root.lockRequested,
                preview: root.lockPreviewOpen,
                locked: sessionLock.locked,
                secure: sessionLock.secure,
                authenticating: root.lockAuthenticating
            })
        }

        function preview(): string {
            root.lockPreviewOpen = true
            return "ok"
        }

        function hidePreview(): string {
            root.lockPreviewOpen = false
            return "ok"
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        WlSessionLockSurface {
            color: Commons.Color.lock.background

            Rectangle {
                anchors.fill: parent
                color: Commons.Color.lock.background

                MouseArea {
                    anchors.fill: parent
                    onClicked: lockPasswordInput.forceActiveFocus()
                }

                Column {
                    id: lockStack
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 48, 560)
                    spacing: 12

                    Text {
                        width: parent.width
                        text: Qt.formatDateTime(lockClock.date, "dddd, d MMMM")
                        color: Commons.Color.lock.text
                        opacity: 0.72
                        font.pixelSize: 22
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        width: parent.width
                        text: Qt.formatDateTime(lockClock.date, "hh:mm")
                        color: Commons.Color.lock.text
                        font.pixelSize: 116
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        width: parent.width
                        text: root.currentUser
                        color: Commons.Color.lock.text
                        opacity: 0.72
                        font.pixelSize: 24
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Rectangle {
                        width: 340
                        height: 58
                        radius: 12
                        color: Commons.Color.lock.passwordBoxBackground
                        border.color: root.lockFailure ? Commons.Color.lock.borderError : Commons.Color.lock.border
                        border.width: 1
                        anchors.horizontalCenter: parent.horizontalCenter

                        TextInput {
                            id: lockPasswordInput
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 18
                            verticalAlignment: TextInput.AlignVCenter
                            horizontalAlignment: TextInput.AlignHCenter
                            color: Commons.Color.lock.text
                            selectionColor: Commons.Color.lock.selection
                            selectedTextColor: Commons.Color.lock.textOnAccent
                            echoMode: TextInput.Password
                            passwordCharacter: "●"
                            passwordMaskDelay: 0
                            enabled: root.lockRequested && !root.lockAuthenticating
                            focus: root.lockRequested
                            text: root.lockPassword
                            font.pixelSize: text.length > 0 ? 24 : 17
                            Component.onCompleted: root.lockPasswordField = lockPasswordInput
                            onTextChanged: {
                                if (text !== root.lockPassword) root.lockPassword = text
                                if (text.length > 0) root.lockFailure = ""
                            }
                            onAccepted: root.submitLockPassword()
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
                                    root.lockPassword = ""
                                    event.accepted = true
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: lockPasswordInput.text.length === 0 && (root.lockAuthenticating || root.lockFailure.length > 0)
                            text: root.lockAuthenticating ? "Checking..." : root.lockFailure
                            color: root.lockFailure ? Commons.Color.lock.textError : Commons.Color.lock.placeholder
                            font.pixelSize: 17
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12
                        topPadding: 18

                        Repeater {
                            model: [
                                { label: "Sleep", command: "systemctl suspend", color: Commons.Color.lock.powerButtonBackground, border: Commons.Color.lock.powerButtonBorder, text: Commons.Color.lock.textOnMuted },
                                { label: "Restart", command: "systemctl reboot", color: Commons.Color.lock.powerButtonBackground, border: Commons.Color.lock.powerButtonBorder, text: Commons.Color.lock.textOnMuted },
                                { label: "Shutdown", command: "systemctl poweroff", color: Commons.Color.lock.dangerButtonBackground, border: Commons.Color.lock.dangerButtonBorder, text: Commons.Color.lock.dangerButtonText }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                width: 124
                                height: 44
                                radius: 12
                                color: powerButtonMouse.containsMouse ? Commons.Color.lock.powerButtonHover : modelData.color
                                border.color: modelData.border
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: modelData.text
                                    font.pixelSize: 15
                                }

                                MouseArea {
                                    id: powerButtonMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.runLockPowerAction(modelData.command)
                                }
                            }
                        }
                    }
                }

                SystemClock {
                    id: lockClock
                    precision: SystemClock.Seconds
                }
            }
        }
    }

    PanelWindow {
        id: lockPreviewPanel
        visible: root.lockPreviewOpen
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: Commons.Color.transparent
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "dotfiles-lock-preview"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Rectangle {
            anchors.fill: parent
            color: Commons.Color.lock.background

            MouseArea {
                anchors.fill: parent
                onClicked: root.lockPreviewOpen = false
            }

            Column {
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 560)
                spacing: 12

                Text {
                    width: parent.width
                    text: Qt.formatDateTime(lockPreviewClock.date, "dddd, d MMMM")
                    color: Commons.Color.lock.text
                    opacity: 0.72
                    font.pixelSize: 22
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: Qt.formatDateTime(lockPreviewClock.date, "hh:mm")
                    color: Commons.Color.lock.text
                    font.pixelSize: 116
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: root.currentUser
                    color: Commons.Color.lock.text
                    opacity: 0.72
                    font.pixelSize: 24
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    width: 340
                    height: 58
                    radius: 12
                    color: Commons.Color.lock.passwordBoxBackground
                    border.color: Commons.Color.lock.border
                    border.width: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    topPadding: 18

                    Repeater {
                        model: [
                            { label: "Sleep", color: Commons.Color.lock.powerButtonBackground, border: Commons.Color.lock.powerButtonBorder, text: Commons.Color.lock.textOnMuted },
                            { label: "Restart", color: Commons.Color.lock.powerButtonBackground, border: Commons.Color.lock.powerButtonBorder, text: Commons.Color.lock.textOnMuted },
                            { label: "Shutdown", color: Commons.Color.lock.dangerButtonBackground, border: Commons.Color.lock.dangerButtonBorder, text: Commons.Color.lock.dangerButtonText }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            width: 124
                            height: 44
                            radius: 12
                            color: previewButtonMouse.containsMouse ? Commons.Color.lock.powerButtonHover : modelData.color
                            border.color: modelData.border
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: modelData.text
                                font.pixelSize: 15
                            }

                            MouseArea {
                                id: previewButtonMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.lockPreviewOpen = false
                            }
                        }
                    }
                }
            }

            SystemClock {
                id: lockPreviewClock
                precision: SystemClock.Seconds
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 18
                text: "Preview"
                color: Commons.Color.lock.text
                opacity: 0.36
                font.pixelSize: 12
            }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root.lockPreviewOpen = false
                    event.accepted = true
                }
            }

            Component.onCompleted: forceActiveFocus()
        }
    }
}
