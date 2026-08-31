import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtQuick

import "../../Commons" as Commons

Item {
    id: root
    property var shell
    property bool popupOpen: false
    property string chargeCycles: ""
    property string nightlightMode: "auto" // "auto", "on", "off"
    property bool nightlightTinted: false  // whether the filter is visually applying right now
    property string home: Quickshell.env("HOME")

    function refreshNightlight() {
        nightlightStatusProvider.running = false
        nightlightStatusProvider.command = [home + "/bin/desktop", "nightlight", "status"]
        nightlightStatusProvider.running = true
    }

    Component.onCompleted: refreshNightlight()

    IpcHandler {
        target: "nightlight"

        function refresh(): string {
            root.refreshNightlight()
            return "ok"
        }
    }

    Process {
        id: nightlightStatusProvider
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(" ")
                root.nightlightMode = parts[0] || "auto"
                root.nightlightTinted = parts[1] === "on"
            }
        }
    }

    Process {
        id: nightlightToggleAction
        command: [root.home + "/bin/desktop", "nightlight", "toggle"]
    }

    readonly property var device: UPower.displayDevice
    readonly property bool isPresent: device && device.isPresent
    readonly property bool onBattery: UPower.onBattery
    readonly property real percentage: isPresent ? device.percentage : 0
    readonly property bool fullyCharged: isPresent && device.state === UPowerDeviceState.FullyCharged

    // Quickshell's native UPowerDevice binding doesn't expose charge-cycle count, so shell out to `upower -i` for it.
    function refreshChargeCycles() {
        if (!root.isPresent) return
        cyclesProvider.running = false
        cyclesProvider.command = ["bash", "-lc", "upower -i \"$(upower -e | grep -i BAT | head -1)\" 2>/dev/null | awk -F': *' '/charge-cycles/{print $2}'"]
        cyclesProvider.running = true
    }

    Timer {
        interval: 30000
        running: root.isPresent
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshChargeCycles()
    }

    Process {
        id: cyclesProvider
        property string buffer: ""
        stdout: SplitParser {
            onRead: function(data) { cyclesProvider.buffer += data }
        }
        onStarted: cyclesProvider.buffer = ""
        onExited: function(exitCode, exitStatus) {
            var value = cyclesProvider.buffer.trim()
            root.chargeCycles = (exitCode === 0 && value.length > 0 && value !== "N/A") ? value : ""
        }
    }
    readonly property var profileList: PowerProfiles.hasPerformanceProfile
        ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
        : [PowerProfile.PowerSaver, PowerProfile.Balanced]

    function batteryIcon() {
        if (!root.isPresent) return "󰚥"
        if (root.fullyCharged) return "󰂅"
        var chargingIcons = ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]
        var defaultIcons = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
        var index = Math.max(0, Math.min(9, Math.floor(root.percentage * 10)))
        return root.onBattery ? defaultIcons[index] : chargingIcons[index]
    }

    function profileIcon(profile) {
        if (profile === PowerProfile.PowerSaver) return "󰌪"
        if (profile === PowerProfile.Balanced) return "󰊚"
        if (profile === PowerProfile.Performance) return "󰓅"
        return "󰂄"
    }

    function profileName(profile) {
        if (profile === PowerProfile.PowerSaver) return "Power Saver"
        if (profile === PowerProfile.Balanced) return "Balanced"
        if (profile === PowerProfile.Performance) return "Performance"
        return "Unknown"
    }

    function statusText() {
        if (!root.isPresent) return "NO BATTERY"
        if (root.fullyCharged) return "FULLY CHARGED"
        return root.onBattery ? "DISCHARGING" : "CHARGING"
    }

    function formatTime(seconds) {
        if (!seconds || seconds <= 0) return "—"
        var h = Math.floor(seconds / 3600)
        var m = Math.floor((seconds % 3600) / 60)
        return h > 0 ? (h + "h " + m + "m") : (m + "m")
    }

    implicitWidth: iconRow.implicitWidth
    implicitHeight: iconRow.implicitHeight

    Row {
        id: iconRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Text {
            id: nightlightIcon
            anchors.verticalCenter: parent.verticalCenter
            visible: root.nightlightTinted
            color: Commons.Color.bar.text
            text: "󰛨"

            MouseArea {
                anchors.fill: parent
                onDoubleClicked: nightlightToggleAction.running = true
            }
        }

        Text {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            color: Commons.Color.bar.text
            text: root.isPresent ? root.batteryIcon() : root.profileIcon(PowerProfiles.profile)

            MouseArea {
                anchors.fill: parent
                onClicked: root.popupOpen = !root.popupOpen
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
        WlrLayershell.namespace: "dotfiles-power-popup"
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
                    visible: root.isPresent

                    Text {
                        id: headerIcon
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.batteryIcon()
                        color: Commons.Color.launcher.text
                        font.pixelSize: 22
                    }

                    Text {
                        id: headerPercent
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(root.percentage * 100) + "%"
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
                            text: "Battery"
                            color: Commons.Color.launcher.text
                            font.pixelSize: 14
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            text: root.statusText()
                            color: Commons.Color.launcher.textMuted
                            font.pixelSize: 10
                        }
                    }
                }

                Commons.InfoRow {
                    visible: root.isPresent && !root.fullyCharged
                    label: root.onBattery ? "Time left" : "Time to full"
                    value: root.formatTime(root.onBattery ? root.device.timeToEmpty : root.device.timeToFull)
                }

                Commons.InfoRow {
                    visible: root.isPresent && root.device.healthSupported
                    label: "Health"
                    value: root.isPresent ? Math.round(root.device.healthPercentage) + "%" : ""
                }

                Commons.InfoRow {
                    visible: root.isPresent && root.chargeCycles.length > 0
                    label: "Charge cycles"
                    value: root.chargeCycles
                }

                Commons.InfoRow {
                    visible: root.isPresent && root.device.energyCapacity > 0
                    label: "Capacity"
                    value: root.isPresent ? root.device.energyCapacity.toFixed(1) + " Wh" : ""
                }

                Commons.InfoRow {
                    visible: root.isPresent && root.device.model && root.device.model.length > 0
                    label: "Model"
                    value: root.isPresent ? (root.device.model || "") : ""
                }

                Rectangle {
                    visible: root.isPresent
                    width: parent.width
                    height: 1
                    color: Commons.Color.launcher.cardBorder
                }

                Text {
                    width: parent.width
                    text: "POWER PROFILE"
                    color: Commons.Color.launcher.textMuted
                    font.pixelSize: 10
                }

                Row {
                    id: profileRow
                    width: parent.width
                    spacing: 6

                    readonly property real cellWidth: (width - spacing * (root.profileList.length - 1)) / root.profileList.length

                    Repeater {
                        model: root.profileList

                        Rectangle {
                            id: profileCell
                            required property var modelData

                            readonly property bool active: PowerProfiles.profile === modelData

                            width: profileRow.cellWidth
                            height: 52
                            radius: 6
                            color: active ? Commons.Color.launcher.selectionBackground : "transparent"
                            border.color: active ? Commons.Color.launcher.selectionBorder : Commons.Color.launcher.cardBorder
                            border.width: 1

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.profileIcon(profileCell.modelData)
                                    color: profileCell.active ? Commons.Color.launcher.textOnMuted : Commons.Color.launcher.text
                                    font.pixelSize: 16
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.profileName(profileCell.modelData)
                                    color: profileCell.active ? Commons.Color.launcher.textOnMuted : Commons.Color.launcher.text
                                    font.pixelSize: 9
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: PowerProfiles.profile = profileCell.modelData
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Commons.Color.launcher.cardBorder
                }

                Item {
                    id: nightlightRow
                    width: parent.width
                    height: Math.max(nightlightLabel.implicitHeight, nightlightState.implicitHeight)

                    Text {
                        id: nightlightLabel
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Night Light"
                        color: Commons.Color.launcher.text
                        font.pixelSize: 12
                    }

                    Text {
                        id: nightlightState
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.nightlightMode === "auto" ? (root.nightlightTinted ? "Auto (on)" : "Auto (off)")
                            : root.nightlightMode === "on" ? "On"
                            : "Off"
                        color: Commons.Color.launcher.textMuted
                        font.pixelSize: 12
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: nightlightToggleAction.running = true
                    }
                }
            }
        }
    }

}
