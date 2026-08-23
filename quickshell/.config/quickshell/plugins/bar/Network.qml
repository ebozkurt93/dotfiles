import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Networking
import QtQuick

import "../../Commons" as Commons

Item {
    id: root
    property var shell
    property bool popupOpen: false

    property var routeInfo: ({})  // { iface, ip, gateway }
    property string passwordSsid: ""
    property string passwordText: ""
    property string passwordError: ""

    readonly property bool networkManagerAvailable: Networking.backend === NetworkBackendType.NetworkManager
    readonly property var networkDevices: Networking.devices ? Networking.devices.values : []
    readonly property var wiredDevice: findDevice(DeviceType.Wired)
    readonly property var wifiDevice: findDevice(DeviceType.Wifi)
    readonly property bool wifiStationAvailable: networkManagerAvailable && !!wifiDevice
    readonly property var wifiNetworkObjects: wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : []
    readonly property var connectedWifiNetwork: findConnectedWifiNetwork()
    property var wifiNetworks: []
    property bool scanning: false

    readonly property string kind: {
        if (wiredDevice && wiredDevice.connected) return "ethernet"
        if (connectedWifiNetwork) return "wifi"
        return "disconnected"
    }
    readonly property int signalStrength: connectedWifiNetwork
        ? Math.round((connectedWifiNetwork.signalStrength || 0) * 100)
        : -1

    function findDevice(type) {
        var devices = networkDevices || []
        var fallback = null
        for (var i = 0; i < devices.length; i++) {
            var device = devices[i]
            if (!device || device.type !== type) continue
            if (device.connected) return device
            if (!fallback) fallback = device
        }
        return fallback
    }

    function findConnectedWifiNetwork() {
        var networks = wifiNetworkObjects || []
        for (var i = 0; i < networks.length; i++) {
            if (networks[i] && networks[i].connected) return networks[i]
        }
        return null
    }

    function connectionIcon() {
        if (root.kind === "ethernet") return "󰈀"
        if (root.kind === "wifi") return wifiIconFor(root.signalStrength)
        return "󰤮"
    }

    function wifiIconFor(strength) {
        var icons = ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]
        var index = Math.max(0, Math.min(4, Math.ceil(strength / 20) - 1))
        return icons[index]
    }

    function requiresCredentials(security) {
        return security !== WifiSecurityType.Open && security !== WifiSecurityType.Owe
    }

    // Primitives only: NetworkManager churn (scans, AP removals) can destroy
    // a WifiNetwork object while a Repeater delegate holding it is still
    // incubating -- same crash Omarchy's network panel documents avoiding.
    function syncWifiNetworks() {
        var nets = []
        var networks = wifiNetworkObjects || []
        for (var i = 0; i < networks.length; i++) {
            var n = networks[i]
            if (!n) continue
            nets.push({
                ssid: n.name || "",
                connected: !!n.connected,
                known: !!n.known,
                signal: Math.round((n.signalStrength || 0) * 100),
                security: n.security
            })
        }
        nets.sort(function(a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1
            if (a.known !== b.known) return a.known ? -1 : 1
            return b.signal - a.signal
        })
        root.wifiNetworks = nets
        root.scanning = false
    }

    onWifiNetworkObjectsChanged: syncWifiNetworks()

    function networkForSsid(ssid) {
        var networks = wifiNetworkObjects || []
        for (var i = 0; i < networks.length; i++) {
            if (networks[i] && networks[i].name === ssid) return networks[i]
        }
        return null
    }

    function toggleWifiRadio() {
        if (!root.networkManagerAvailable) return
        Networking.wifiEnabled = !Networking.wifiEnabled
    }

    function cancelPasswordPrompt() {
        root.passwordSsid = ""
        root.passwordText = ""
        root.passwordError = ""
    }

    function activateRow(row) {
        var network = networkForSsid(row.ssid)
        if (!network) return
        if (network.connected) { network.disconnect(); return }
        if (root.requiresCredentials(network.security) && !network.known) {
            root.passwordSsid = row.ssid
            root.passwordText = ""
            root.passwordError = ""
            return
        }
        network.connect()
    }

    function submitPassword() {
        var network = networkForSsid(root.passwordSsid)
        if (!network || root.passwordText.length === 0) return
        network.connectWithPsk(root.passwordText)
        root.cancelPasswordPrompt()
    }

    function forgetNetwork(ssid) {
        var network = networkForSsid(ssid)
        if (network) network.forget()
    }

    function refreshRoute() {
        routeProc.running = false
        routeProc.command = ["ip", "-j", "route", "get", "1.1.1.1"]
        routeProc.running = true
    }

    function updateRoute(raw) {
        try {
            var parsed = JSON.parse(raw)
            var entry = Array.isArray(parsed) && parsed.length > 0 ? parsed[0] : null
            root.routeInfo = entry ? {
                iface: entry.dev || "",
                ip: entry.prefsrc || "",
                gateway: entry.gateway || ""
            } : {}
        } catch (e) {
            root.routeInfo = {}
        }
    }

    Process {
        id: routeProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.updateRoute(text)
        }
    }

    Timer {
        id: routePoll
        interval: 5000
        repeat: true
        running: root.popupOpen
        triggeredOnStart: true
        onTriggered: root.refreshRoute()
    }

    // scannerEnabled has no reference counting on the shared WifiDevice, but
    // this widget is only ever instantiated once (single bar, single
    // monitor), so a plain on/off tied to popupOpen is enough here.
    onPopupOpenChanged: {
        if (popupOpen) {
            if (root.wifiDevice) {
                root.scanning = true
                root.wifiDevice.scannerEnabled = true
            }
            root.refreshRoute()
        } else {
            if (root.wifiDevice) root.wifiDevice.scannerEnabled = false
            root.cancelPasswordPrompt()
        }
    }

    Component.onDestruction: {
        if (root.wifiDevice) root.wifiDevice.scannerEnabled = false
    }

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    Text {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        color: Commons.Color.bar.text
        opacity: root.kind === "disconnected" ? 0.45 : 1.0
        text: root.connectionIcon()

        MouseArea {
            anchors.fill: parent
            onClicked: root.popupOpen = !root.popupOpen
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
        WlrLayershell.namespace: "dotfiles-network-popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.passwordSsid !== "" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: root.popupOpen = false
        }

        Rectangle {
            id: popupCard
            width: 300
            height: Math.min(440, popupColumn.implicitHeight + 24)
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

            Flickable {
                anchors.fill: parent
                anchors.margins: 12
                contentHeight: popupColumn.implicitHeight
                clip: true

                Column {
                    id: popupColumn
                    width: parent.width
                    spacing: 10

                    Item {
                        width: parent.width
                        height: Math.max(headerIcon.implicitHeight, headerText.implicitHeight, radioSwitch.height)

                        Text {
                            id: headerIcon
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.connectionIcon()
                            color: Commons.Color.launcher.text
                            font.pixelSize: 22
                        }

                        Rectangle {
                            id: radioSwitch
                            visible: root.wifiStationAvailable
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 22
                            radius: 11
                            color: Networking.wifiEnabled ? Commons.Color.launcher.selection : Commons.Color.launcher.cardBorder

                            Rectangle {
                                width: 18
                                height: 18
                                radius: 9
                                color: Commons.Color.launcher.cardBackground
                                anchors.verticalCenter: parent.verticalCenter
                                x: Networking.wifiEnabled ? parent.width - width - 2 : 2

                                Behavior on x {
                                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.toggleWifiRadio()
                            }
                        }

                        Column {
                            id: headerText
                            anchors.left: headerIcon.right
                            anchors.leftMargin: 10
                            anchors.right: radioSwitch.visible ? radioSwitch.left : parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                width: parent.width
                                text: {
                                    if (root.kind === "wifi") return root.connectedWifiNetwork.name || "Wi-Fi"
                                    if (root.kind === "ethernet") return "Ethernet"
                                    return "Disconnected"
                                }
                                color: Commons.Color.launcher.text
                                font.pixelSize: 14
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: root.routeInfo.ip || ""
                                color: Commons.Color.launcher.textMuted
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Rectangle {
                        visible: !!root.routeInfo.gateway
                        width: parent.width
                        height: 1
                        color: Commons.Color.launcher.cardBorder
                    }

                    InfoRow {
                        visible: !!root.routeInfo.gateway
                        label: "Gateway"
                        value: root.routeInfo.gateway || ""
                    }

                    InfoRow {
                        visible: !!root.routeInfo.iface
                        label: "Interface"
                        value: root.routeInfo.iface || ""
                    }

                    Rectangle {
                        visible: root.wifiStationAvailable
                        width: parent.width
                        height: 1
                        color: Commons.Color.launcher.cardBorder
                    }

                    Text {
                        width: parent.width
                        visible: root.wifiStationAvailable && root.scanning && root.wifiNetworks.length === 0
                        text: "SCANNING…"
                        color: Commons.Color.launcher.textMuted
                        font.pixelSize: 10
                    }

                    Repeater {
                        model: root.wifiStationAvailable ? root.wifiNetworks : []
                        delegate: WifiRow {}
                    }

                    Item {
                        visible: root.passwordSsid !== ""
                        width: parent.width
                        height: visible ? passwordColumn.implicitHeight : 0

                        Column {
                            id: passwordColumn
                            width: parent.width
                            spacing: 6

                            Text {
                                width: parent.width
                                text: "Password for " + root.passwordSsid
                                color: Commons.Color.launcher.textMuted
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                width: parent.width
                                height: 30
                                radius: 6
                                color: Commons.Color.launcher.inputBackground
                                border.color: Commons.Color.launcher.inputBorder
                                border.width: 1

                                TextInput {
                                    id: passwordInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Commons.Color.launcher.text
                                    echoMode: TextInput.Password
                                    passwordCharacter: "●"
                                    font.pixelSize: 12
                                    focus: root.passwordSsid !== ""
                                    text: root.passwordText
                                    onTextChanged: root.passwordText = text
                                    onAccepted: root.submitPassword()
                                    Keys.onEscapePressed: root.cancelPasswordPrompt()
                                }
                            }

                            Row {
                                spacing: 8
                                anchors.right: parent.right

                                Text {
                                    text: "Cancel"
                                    color: Commons.Color.launcher.textMuted
                                    font.pixelSize: 11
                                    MouseArea { anchors.fill: parent; onClicked: root.cancelPasswordPrompt() }
                                }

                                Text {
                                    text: "Connect"
                                    color: Commons.Color.launcher.selection
                                    font.pixelSize: 11
                                    font.bold: true
                                    MouseArea { anchors.fill: parent; onClicked: root.submitPassword() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component InfoRow: Item {
        property string label: ""
        property string value: ""

        width: parent ? parent.width : 0
        height: visible ? labelText.implicitHeight : 0

        Text {
            id: labelText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: label
            color: Commons.Color.launcher.textMuted
            font.pixelSize: 11
        }

        Text {
            anchors.left: labelText.right
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: value
            color: Commons.Color.launcher.text
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    component WifiRow: Rectangle {
        id: wifiRow
        required property var modelData

        width: parent ? parent.width : 0
        height: rowInner.implicitHeight + 12
        radius: 6
        color: rowMouse.containsMouse ? Commons.Color.launcher.selectionBackground : "transparent"

        Row {
            id: rowInner
            anchors.left: parent.left
            anchors.right: forgetIcon.visible ? forgetIcon.left : parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.wifiIconFor(wifiRow.modelData.signal)
                color: wifiRow.modelData.connected ? Commons.Color.launcher.selection : Commons.Color.launcher.textMuted
                font.pixelSize: 15
            }

            Text {
                width: parent.width - 20 - (lockIcon.visible ? lockIcon.width + 4 : 0)
                text: wifiRow.modelData.ssid
                color: Commons.Color.launcher.text
                font.pixelSize: 13
                font.bold: wifiRow.modelData.connected
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: lockIcon
                visible: root.requiresCredentials(wifiRow.modelData.security)
                anchors.verticalCenter: parent.verticalCenter
                text: "󰌾"
                color: Commons.Color.launcher.textMuted
                font.pixelSize: 11
            }
        }

        Text {
            id: forgetIcon
            visible: wifiRow.modelData.known && !wifiRow.modelData.connected
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: "󰅗"
            color: Commons.Color.launcher.textMuted
            font.pixelSize: 13

            MouseArea {
                anchors.fill: parent
                onClicked: root.forgetNetwork(wifiRow.modelData.ssid)
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.activateRow(wifiRow.modelData)
        }
    }
}
