import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick

import "../../Commons" as Commons

Item {
    id: root
    property var shell
    property bool popupOpen: false
    property bool kbFocused: false
    property bool kbAvailable: true
    readonly property alias kbNavScope: kbNav
    property string home: Quickshell.env("HOME")

    function kbActivate() {
        root.popupOpen = true
        kbNav.reset()
    }

    property var routeInfo: ({})  // { iface, ip, gateway }
    property string passwordSsid: ""
    property string passwordText: ""
    property string passwordError: ""

    // ---- DNS provider (helper_scripts/bin/dns-manager) ----
    readonly property var dnsProviders: ["DHCP", "Cloudflare", "Google", "Custom"]
    property string dnsProvider: ""
    property string pendingDnsProvider: ""
    property bool customDnsOpen: false
    property string customDnsText: ""
    property string effectiveDnsServers: ""

    // ---- Interface details: MAC and link speed, refreshed when the
    // interface changes rather than on every stats tick (they're static). ----
    property string macAddress: ""
    property string linkSpeedMbps: ""

    // ---- Session totals: cumulative bytes since the popup was first
    // opened for the current interface (not since boot/connect). ----
    property real sessionStartRxBytes: -1
    property real sessionStartTxBytes: -1
    property real sessionRxBytes: 0
    property real sessionTxBytes: 0

    // ---- Public IP, fetched once per popup-open (cached externally via
    // bkt too, same pattern as helper_scripts/bin/weather). ----
    property string publicIp: ""

    // ---- Live stats: ping + throughput, only sampled while popup is open ----
    property string statsIface: ""
    property real prevRxBytes: 0
    property real prevTxBytes: 0
    property real prevSampleTime: 0
    property real downloadRate: 0  // bytes/sec
    property real uploadRate: 0    // bytes/sec
    property var routerPingSamples: []
    property var internetPingSamples: []
    readonly property int pingHistoryWindow: 24
    readonly property int pingAverageWindow: 5

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

    // Primitives only: NetworkManager churn can destroy a WifiNetwork object while a Repeater delegate is still incubating it.
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

    // ---- DNS provider ----

    function refreshDns() {
        dnsCurrentProc.running = false
        dnsCurrentProc.command = [home + "/bin/dns-manager", "current"]
        dnsCurrentProc.running = true
    }

    function setDns(provider) {
        if (dnsSetProc.running) return
        if (provider === "Custom") {
            if (root.customDnsText.trim() === "") return
            root.pendingDnsProvider = provider
            dnsSetProc.command = [home + "/bin/dns-manager", "set", "Custom", root.customDnsText.trim()]
        } else {
            root.pendingDnsProvider = provider
            dnsSetProc.command = [home + "/bin/dns-manager", "set", provider]
        }
        dnsSetProc.running = true
    }

    function openCustomDns() {
        root.customDnsOpen = true
        root.customDnsText = ""
    }

    function cancelCustomDns() {
        root.customDnsOpen = false
        root.customDnsText = ""
    }

    Process {
        id: dnsCurrentProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.dnsProvider = text.trim()
        }
    }

    Process {
        id: dnsSetProc
        onExited: function(exitCode) {
            if (exitCode === 0) {
                root.dnsProvider = root.pendingDnsProvider
                if (root.pendingDnsProvider === "Custom") root.cancelCustomDns()
                // dns-manager's nmcli reapply hasn't necessarily landed in
                // /etc/resolv.conf yet the instant this process exits.
                dnsServersRefreshDelay.restart()
            }
            root.pendingDnsProvider = ""
            root.refreshDns()
        }
    }

    Timer {
        id: dnsServersRefreshDelay
        interval: 500
        repeat: false
        onTriggered: root.refreshDnsServers()
    }

    // ---- Live stats: ping (router + internet) and throughput ----

    function pingSampleValue(raw) {
        var match = String(raw || "").match(/time[=<]\s*([\d.]+)\s*ms/)
        if (!match) return null
        var value = parseFloat(match[1])
        return isFinite(value) && value >= 0 ? value : null
    }

    function appendPingSample(samples, value) {
        var next = (samples || []).slice()
        next.push(value)
        if (next.length > root.pingHistoryWindow) next.shift()
        return next
    }

    function averagePingLatency(samples) {
        var values = (samples || []).slice(-root.pingAverageWindow)
        var real = values.filter(function(v) { return v !== null })
        if (real.length === 0) return -1
        var sum = 0
        for (var i = 0; i < real.length; i++) sum += real[i]
        return sum / real.length
    }

    function pingPacketLossPercent(samples) {
        var values = samples || []
        if (values.length === 0) return 0
        var lost = 0
        for (var i = 0; i < values.length; i++) if (values[i] === null) lost++
        return Math.round((lost / values.length) * 100)
    }

    readonly property real routerPingLatency: averagePingLatency(routerPingSamples)
    readonly property real internetPingLatency: averagePingLatency(internetPingSamples)
    readonly property int internetPingPacketLoss: pingPacketLossPercent(internetPingSamples)
    readonly property bool hasInternetPingSamples: internetPingSamples.length > 0

    function formatBytes(bytes) {
        var n = Number(bytes)
        if (!isFinite(n) || n < 0) n = 0
        if (n < 1024) return Math.round(n) + " B"
        if (n < 1024 * 1024) return (n / 1024).toFixed(1) + " KB"
        if (n < 1024 * 1024 * 1024) return (n / (1024 * 1024)).toFixed(1) + " MB"
        return (n / (1024 * 1024 * 1024)).toFixed(2) + " GB"
    }

    function formatRate(bytesPerSec) {
        return formatBytes(bytesPerSec) + "/s"
    }

    function formatPingLatency(ms) {
        if (!root.hasInternetPingSamples) return "--"
        return ms >= 0 ? Math.round(ms) + " ms" : "timeout"
    }

    function pollStats() {
        if (!root.popupOpen) return
        var iface = root.routeInfo.iface || ""
        if (iface !== root.statsIface) {
            root.statsIface = iface
            root.prevSampleTime = 0
            root.downloadRate = 0
            root.uploadRate = 0
            root.routerPingSamples = []
            root.internetPingSamples = []
            root.sessionStartRxBytes = -1
            root.sessionStartTxBytes = -1
            root.sessionRxBytes = 0
            root.sessionTxBytes = 0
            root.macAddress = ""
            root.linkSpeedMbps = ""
            if (iface !== "") {
                macProc.command = ["cat", "/sys/class/net/" + iface + "/address"]
                macProc.running = true
                linkSpeedProc.command = ["cat", "/sys/class/net/" + iface + "/speed"]
                linkSpeedProc.running = true
            }
        }
        if (iface !== "") {
            throughputProc.command = ["ip", "-s", "-j", "link", "show", "dev", iface]
            throughputProc.running = true
        }
        if (root.routeInfo.gateway) {
            pingRouterProc.command = ["ping", "-c", "1", "-W", "1", root.routeInfo.gateway]
            pingRouterProc.running = true
        }
        pingInternetProc.command = ["ping", "-c", "1", "-W", "1", "1.1.1.1"]
        pingInternetProc.running = true
    }

    Process {
        id: pingRouterProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.routerPingSamples = root.appendPingSample(root.routerPingSamples, root.pingSampleValue(text))
        }
    }

    Process {
        id: pingInternetProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.internetPingSamples = root.appendPingSample(root.internetPingSamples, root.pingSampleValue(text))
        }
    }

    Process {
        id: throughputProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text)
                    var entry = Array.isArray(parsed) && parsed.length > 0 ? parsed[0] : null
                    var stats = entry && entry.stats64 ? entry.stats64 : null
                    if (!stats) return
                    var rx = Number(stats.rx && stats.rx.bytes || 0)
                    var tx = Number(stats.tx && stats.tx.bytes || 0)
                    var now = Date.now() / 1000
                    if (root.prevSampleTime > 0) {
                        var dt = now - root.prevSampleTime
                        if (dt > 0) {
                            root.downloadRate = Math.max(0, (rx - root.prevRxBytes) / dt)
                            root.uploadRate = Math.max(0, (tx - root.prevTxBytes) / dt)
                        }
                    }
                    root.prevRxBytes = rx
                    root.prevTxBytes = tx
                    root.prevSampleTime = now

                    if (root.sessionStartRxBytes < 0) {
                        root.sessionStartRxBytes = rx
                        root.sessionStartTxBytes = tx
                    }
                    root.sessionRxBytes = Math.max(0, rx - root.sessionStartRxBytes)
                    root.sessionTxBytes = Math.max(0, tx - root.sessionStartTxBytes)
                } catch (e) {
                    // Leave prior rates in place on a parse miss.
                }
            }
        }
    }

    // Static per-interface info -- only re-read when the interface changes,
    // not on every 2s stats tick.
    Process {
        id: macProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.macAddress = text.trim()
        }
    }

    Process {
        id: linkSpeedProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var mbps = parseInt(text.trim(), 10)
                // Wireless interfaces (and a link that's momentarily down)
                // report -1 or nothing here; only wired wants this row.
                root.linkSpeedMbps = (isFinite(mbps) && mbps > 0) ? String(mbps) : ""
            }
        }
    }

    // Both fetched once per popup-open, not on the fast stats timer -- they
    // rarely change and the public IP lookup is a real network request.
    function refreshDnsServers() {
        dnsServersProc.running = false
        dnsServersProc.command = ["cat", "/etc/resolv.conf"]
        dnsServersProc.running = true
    }

    function refreshExtras() {
        refreshDnsServers()

        publicIpProc.running = false
        publicIpProc.command = ["bash", "-c",
            "bkt --ttl 10m --scope network-public-ip -- curl --fail --silent --max-time 3 https://ipinfo.io/ip"]
        publicIpProc.running = true
    }

    Process {
        id: dnsServersProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var servers = []
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var match = lines[i].match(/^nameserver\s+(\S+)/)
                    if (match) servers.push(match[1])
                }
                root.effectiveDnsServers = servers.join(", ")
            }
        }
    }

    Process {
        id: publicIpProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.publicIp = text.trim()
        }
    }

    Timer {
        id: statsPoll
        interval: 2000
        repeat: true
        running: root.popupOpen
        triggeredOnStart: true
        onTriggered: root.pollStats()
    }

    // scannerEnabled has no reference counting, but this widget is only ever instantiated once, so plain on/off is enough.
    onPopupOpenChanged: {
        if (popupOpen) {
            if (root.wifiDevice) {
                root.scanning = true
                root.wifiDevice.scannerEnabled = true
            }
            root.refreshRoute()
            root.refreshDns()
            root.refreshExtras()
        } else {
            if (root.wifiDevice) root.wifiDevice.scannerEnabled = false
            root.cancelPasswordPrompt()
            root.cancelCustomDns()
            root.statsIface = ""
            root.prevSampleTime = 0
            root.publicIp = ""
            root.effectiveDnsServers = ""
        }
    }

    Component.onDestruction: {
        if (root.wifiDevice) root.wifiDevice.scannerEnabled = false
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
        opacity: root.kind === "disconnected" ? 0.45 : 1.0
        text: root.connectionIcon()

        MouseArea {
            anchors.fill: parent
            onClicked: root.popupOpen = !root.popupOpen
        }
    }

    Commons.KbNavScope {
        id: kbNav
        content: popupColumn
    }

    Commons.PopupPanel {
        id: popupPanel
        open: root.popupOpen
        namespace: "dotfiles-network-popup"
        wantsKeyboardFocus: root.passwordSsid !== "" || root.customDnsOpen
        cardWidth: 300
        cardHeight: Math.min(620, popupColumn.implicitHeight + 24)
        onDismissRequested: root.popupOpen = false

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

                        Commons.ToggleSwitch {
                            id: radioSwitch
                            property bool kbNavTarget: true
                            function kbActivate() { root.toggleWifiRadio() }
                            visible: root.wifiStationAvailable
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            checked: Networking.wifiEnabled
                            border.color: kbNav.focusedItem === radioSwitch ? Commons.Color.launcher.selectionBorder : "transparent"
                            border.width: kbNav.focusedItem === radioSwitch ? 2 : 0
                            onToggled: root.toggleWifiRadio()
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
                                text: {
                                    var ip = root.routeInfo.ip || ""
                                    if (!root.kbFocused) return ip
                                    return ip !== "" ? ip + "  ·  ↑↓ Enter" : "↑↓ Enter"
                                }
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

                    Commons.InfoRow {
                        visible: !!root.routeInfo.gateway
                        label: "Gateway"
                        value: root.routeInfo.gateway || ""
                    }

                    Commons.InfoRow {
                        visible: !!root.routeInfo.iface
                        label: "Interface"
                        value: root.routeInfo.iface || ""
                    }

                    Commons.InfoRow {
                        visible: !!root.routeInfo.iface
                        label: "Ping"
                        value: root.formatPingLatency(root.internetPingLatency)
                    }

                    Commons.InfoRow {
                        visible: !!root.routeInfo.iface
                        label: "Packet Loss"
                        value: root.hasInternetPingSamples ? root.internetPingPacketLoss + "%" : "--"
                    }

                    Commons.InfoRow {
                        visible: !!root.routeInfo.iface
                        label: "Receiving"
                        value: root.formatRate(root.downloadRate)
                    }

                    Commons.InfoRow {
                        visible: !!root.routeInfo.iface
                        label: "Sending"
                        value: root.formatRate(root.uploadRate)
                    }

                    Commons.InfoRow {
                        visible: root.linkSpeedMbps !== ""
                        label: "Link Speed"
                        value: root.linkSpeedMbps + " Mbps"
                    }

                    Commons.InfoRow {
                        visible: root.macAddress !== ""
                        label: "MAC Address"
                        value: root.macAddress
                    }

                    Commons.InfoRow {
                        visible: !!root.routeInfo.iface
                        label: "Session Total"
                        value: root.formatBytes(root.sessionRxBytes) + " ↓ / " + root.formatBytes(root.sessionTxBytes) + " ↑"
                    }

                    Commons.InfoRow {
                        visible: root.publicIp !== ""
                        label: "Public IP"
                        value: root.publicIp
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Commons.Color.launcher.cardBorder
                    }

                    NetworkDns {
                        kbNavScope: kbNav
                        provider: root.dnsProvider
                        providers: root.dnsProviders
                        effectiveServers: root.effectiveDnsServers
                        customOpen: root.customDnsOpen
                        customText: root.customDnsText
                        onProviderPicked: function(provider) { root.setDns(provider) }
                        onCustomDnsRequested: root.openCustomDns()
                        onCustomTextEdited: function(text) { root.customDnsText = text }
                        onCustomSubmitted: root.setDns("Custom")
                        onCustomCancelled: root.cancelCustomDns()
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
                        delegate: NetworkWifiRow {
                            id: wifiRow
                            property bool kbNavTarget: true
                            function kbActivate() { root.activateRow(modelData) }
                            navFocused: kbNav.focusedItem === wifiRow
                            onActivateRequested: root.activateRow(modelData)
                            onForgetRequested: root.forgetNetwork(modelData.ssid)
                        }
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
