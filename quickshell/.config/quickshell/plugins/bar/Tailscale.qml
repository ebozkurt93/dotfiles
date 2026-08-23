import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

import "../../Commons" as Commons

Item {
    id: root
    property var shell
    property bool popupOpen: false
    property string home: Quickshell.env("HOME")
    property bool connected: false
    property string exitNode: ""
    property bool infoLoaded: false
    property string lastError: ""
    property var peers: []
    property string selfName: ""
    property string selfIp: ""

    function osIcon(os) {
        var value = String(os || "").toLowerCase()
        if (value === "linux") return "󰌽"
        if (value === "macos" || value === "ios") return "󰀵"
        if (value === "windows") return "󰍲"
        if (value === "android") return "󰀲"
        return "󰟀"
    }

    function refresh() {
        infoProvider.running = false
        infoProvider.command = [home + "/bin/ts-manager", "info"]
        infoProvider.running = true
    }

    function refreshPeers() {
        peersProvider.running = false
        peersProvider.command = [home + "/bin/ts-manager", "cli", "status", "--json"]
        peersProvider.running = true
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: infoProvider
        property string buffer: ""
        stdout: SplitParser {
            onRead: function(data) { infoProvider.buffer += data + "\n" }
        }
        onStarted: infoProvider.buffer = ""
        onExited: function(exitCode, exitStatus) {
            root.infoLoaded = true
            if (exitCode !== 0 || exitStatus !== 0) {
                root.connected = false
                root.exitNode = ""
                return
            }
            try {
                var parsed = JSON.parse(infoProvider.buffer)
                root.connected = parsed.connected === true
                root.exitNode = parsed.exit_node || ""
            } catch (e) {
                console.warn("ts-manager info returned invalid JSON:", e)
                root.connected = false
                root.exitNode = ""
            }
        }
    }

    Process {
        id: peersProvider
        property string buffer: ""
        stdout: SplitParser {
            onRead: function(data) { peersProvider.buffer += data + "\n" }
        }
        onStarted: peersProvider.buffer = ""
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0 || exitStatus !== 0) {
                root.peers = []
                return
            }
            try {
                var parsed = JSON.parse(peersProvider.buffer)
                var peerMap = parsed.Peer || {}
                var list = []
                for (var key in peerMap) {
                    var p = peerMap[key]
                    var ips = p.TailscaleIPs || []
                    var ip = ips.length > 0 ? ips[0] : ""
                    // DNSName reflects the tailnet/admin-panel "given name" (what
                    // renaming a device actually changes); HostName is the raw
                    // OS-reported name and can be stale/generic ("FB",
                    // "localhost") on devices renamed after enrollment. Prefer
                    // DNSName's first label, matching what `tailscale status`
                    // itself displays.
                    var dnsLabel = p.DNSName ? p.DNSName.split(".")[0] : ""
                    var name = dnsLabel || p.HostName || "unknown"
                    // Secondary line shows the *other* identifier (raw OS
                    // hostname) when it differs from the display name, not
                    // the DNS label again -- that would just repeat the name.
                    var altName = (p.HostName && p.HostName !== name) ? p.HostName : ""
                    list.push({ name: name, ip: ip, altName: altName, os: p.OS || "", online: p.Online === true })
                }
                list.sort(function(a, b) {
                    if (a.online !== b.online) return a.online ? -1 : 1
                    return a.name.localeCompare(b.name)
                })
                root.peers = list

                var self = parsed.Self || {}
                var selfIps = self.TailscaleIPs || []
                var selfDnsLabel = self.DNSName ? self.DNSName.split(".")[0] : ""
                root.selfName = selfDnsLabel || self.HostName || ""
                root.selfIp = selfIps.length > 0 ? selfIps[0] : ""
            } catch (e) {
                console.warn("ts-manager cli status --json returned invalid JSON:", e)
                root.peers = []
            }
        }
    }

    Process {
        id: tsAction
        property string errBuffer: ""
        stdout: SplitParser {
            onRead: function(data) { tsAction.errBuffer += data + "\n" }
        }
        stderr: SplitParser {
            onRead: function(data) { tsAction.errBuffer += data + "\n" }
        }
        onStarted: tsAction.errBuffer = ""
        onExited: function(exitCode, exitStatus) {
            root.lastError = (exitCode !== 0 || exitStatus !== 0) ? tsAction.errBuffer.trim() : ""
            root.refresh()
            if (root.popupOpen) root.refreshPeers()
        }
    }

    function runToggle() {
        tsAction.command = [home + "/bin/ts-manager", root.connected ? "down" : "up"]
        tsAction.running = true
    }

    function copyIp(ip) {
        if (!ip) return
        copyProcess.command = ["bash", "-lc", "printf '%s' " + JSON.stringify(ip) + " | wl-copy"]
        copyProcess.running = true
    }

    Process {
        id: copyProcess
    }

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    Item {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        readonly property real iconSize: 14
        readonly property color dotColor: Commons.Color.bar.text
        readonly property real connectionOpacity: root.connected ? 1.0 : 0.45
        readonly property real dotSize: Math.max(2, iconSize * 0.24)
        readonly property real mid: (iconSize - dotSize) / 2
        readonly property real end: iconSize - dotSize

        width: iconSize
        height: iconSize
        implicitWidth: iconSize
        implicitHeight: iconSize

        // Native rendering of the Tailscale mark: a 3x3 dot grid with the
        // corner/top-row dots faded, matching the official SVG silhouette
        // without relying on a nerd-font glyph. Each dot's own opacity is
        // the grid *shape*; connectionOpacity separately dims the whole
        // icon when disconnected.
        Dot { x: 0; y: 0; opacity: 0.24 * icon.connectionOpacity }
        Dot { x: icon.mid; y: 0; opacity: 0.24 * icon.connectionOpacity }
        Dot { x: icon.end; y: 0; opacity: 0.24 * icon.connectionOpacity }
        Dot { x: 0; y: icon.mid; opacity: 1.0 * icon.connectionOpacity }
        Dot { x: icon.mid; y: icon.mid; opacity: 1.0 * icon.connectionOpacity }
        Dot { x: icon.end; y: icon.mid; opacity: 1.0 * icon.connectionOpacity }
        Dot { x: 0; y: icon.end; opacity: 0.24 * icon.connectionOpacity }
        Dot { x: icon.mid; y: icon.end; opacity: 1.0 * icon.connectionOpacity }
        Dot { x: icon.end; y: icon.end; opacity: 0.24 * icon.connectionOpacity }

        component Dot: Rectangle {
            width: icon.dotSize
            height: icon.dotSize
            radius: width / 2
            color: icon.dotColor
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.popupOpen = !root.popupOpen
                if (root.popupOpen) {
                    root.refresh()
                    root.refreshPeers()
                }
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
        WlrLayershell.namespace: "dotfiles-tailscale-popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: root.popupOpen = false
        }

        Rectangle {
            id: popupCard
            width: 280
            height: Math.min(420, popupColumn.implicitHeight + 24)
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
                    spacing: 8

                    Text {
                        width: parent.width
                        text: root.connected && root.selfName ? root.selfName : "Tailscale"
                        color: Commons.Color.launcher.text
                        font.pixelSize: 14
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: {
                            if (!root.infoLoaded) return "Loading…"
                            if (!root.connected) return "Disconnected"
                            return root.selfIp ? ("Connected · " + root.selfIp) : "Connected"
                        }
                        color: Commons.Color.launcher.textMuted
                        font.pixelSize: 12
                    }

                    Text {
                        width: parent.width
                        visible: root.connected && root.exitNode.length > 0
                        text: "Exit node: " + root.exitNode
                        color: Commons.Color.launcher.textMuted
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: root.lastError.length > 0
                        text: root.lastError
                        color: Commons.Color.dangerText
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Commons.Color.launcher.cardBorder
                    }

                    Rectangle {
                        id: toggleButton
                        width: parent.width
                        height: 30
                        radius: 6
                        color: toggleMouse.containsMouse ? Commons.Color.launcher.selectionBackground : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: root.connected ? "Disconnect" : "Connect"
                            color: Commons.Color.launcher.text
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: toggleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.runToggle()
                        }
                    }

                    Rectangle {
                        visible: root.connected && root.peers.length > 0
                        width: parent.width
                        height: 1
                        color: Commons.Color.launcher.cardBorder
                    }

                    Text {
                        visible: root.connected && root.peers.length > 0
                        width: parent.width
                        text: "Machines"
                        color: Commons.Color.launcher.textMuted
                        font.pixelSize: 11
                    }

                    Repeater {
                        model: root.connected ? root.peers : []

                        Rectangle {
                            id: peerRow
                            required property var modelData

                            width: popupColumn.width
                            height: peerInner.implicitHeight + 8
                            radius: 6
                            color: peerMouse.containsMouse ? Commons.Color.launcher.selectionBackground : "transparent"

                            Row {
                                id: peerInner
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 6

                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: peerRow.modelData.online ? Commons.Color.launcher.selection : Commons.Color.launcher.textMuted
                                }

                                Text {
                                    text: root.osIcon(peerRow.modelData.os)
                                    color: Commons.Color.launcher.text
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    width: parent.width - 78
                                    spacing: 1

                                    Text {
                                        width: parent.width
                                        text: peerRow.modelData.name
                                        color: Commons.Color.launcher.text
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: [peerRow.modelData.ip, peerRow.modelData.altName].filter(function(s) { return s && s.length > 0 }).join(" · ")
                                        color: Commons.Color.launcher.textMuted
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            MouseArea {
                                id: peerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.copyIp(peerRow.modelData.ip)
                            }
                        }
                    }
                }
            }
        }
    }
}
