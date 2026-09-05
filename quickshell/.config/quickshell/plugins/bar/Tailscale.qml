import Quickshell
import Quickshell.Io
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
        root.refresh()
        root.refreshPeers()
        kbNav.reset()
    }
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
        infoProvider.run([home + "/bin/ts-manager", "info"])
    }

    function refreshPeers() {
        peersProvider.run([home + "/bin/ts-manager", "cli", "status", "--json"])
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Commons.JsonProcess {
        id: infoProvider
        label: "ts-manager info"
        onParsed: function(data) {
            root.infoLoaded = true
            root.connected = data.connected === true
            root.exitNode = data.exit_node || ""
        }
        onFailed: {
            root.infoLoaded = true
            root.connected = false
            root.exitNode = ""
        }
    }

    Commons.JsonProcess {
        id: peersProvider
        label: "ts-manager cli status --json"
        onParsed: function(data) {
            var peerMap = data.Peer || {}
            var list = []
            for (var key in peerMap) {
                var p = peerMap[key]
                var ips = p.TailscaleIPs || []
                var ip = ips.length > 0 ? ips[0] : ""
                // Prefer DNSName's first label (the tailnet "given name") over the raw, possibly-stale HostName.
                var dnsLabel = p.DNSName ? p.DNSName.split(".")[0] : ""
                var name = dnsLabel || p.HostName || "unknown"
                // Secondary line shows the raw hostname only when it differs from the display name.
                var altName = (p.HostName && p.HostName !== name) ? p.HostName : ""
                list.push({ name: name, ip: ip, altName: altName, os: p.OS || "", online: p.Online === true })
            }
            list.sort(function(a, b) {
                if (a.online !== b.online) return a.online ? -1 : 1
                return a.name.localeCompare(b.name)
            })
            root.peers = list

            var self = data.Self || {}
            var selfIps = self.TailscaleIPs || []
            var selfDnsLabel = self.DNSName ? self.DNSName.split(".")[0] : ""
            root.selfName = selfDnsLabel || self.HostName || ""
            root.selfIp = selfIps.length > 0 ? selfIps[0] : ""
        }
        onFailed: root.peers = []
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

    Item {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        readonly property real iconSize: 14
        readonly property color dotColor: Commons.Color.bar.text
        readonly property real dotSize: Math.max(2, iconSize * 0.24)
        readonly property real mid: (iconSize - dotSize) / 2
        readonly property real end: iconSize - dotSize

        // Disconnected: flatten every dot to the same faded opacity instead of the brand shape.
        function dotOpacity(shapeValue) {
            return root.connected ? shapeValue : 0.45
        }

        width: iconSize
        height: iconSize
        implicitWidth: iconSize
        implicitHeight: iconSize

        // 3x3 dot grid matching the official Tailscale mark, without relying on a nerd-font glyph.
        Dot { x: 0; y: 0; opacity: icon.dotOpacity(0.24) }
        Dot { x: icon.mid; y: 0; opacity: icon.dotOpacity(0.24) }
        Dot { x: icon.end; y: 0; opacity: icon.dotOpacity(0.24) }
        Dot { x: 0; y: icon.mid; opacity: icon.dotOpacity(1.0) }
        Dot { x: icon.mid; y: icon.mid; opacity: icon.dotOpacity(1.0) }
        Dot { x: icon.end; y: icon.mid; opacity: icon.dotOpacity(1.0) }
        Dot { x: 0; y: icon.end; opacity: icon.dotOpacity(0.24) }
        Dot { x: icon.mid; y: icon.end; opacity: icon.dotOpacity(1.0) }
        Dot { x: icon.end; y: icon.end; opacity: icon.dotOpacity(0.24) }

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

    Commons.PopupPanel {
        id: popupPanel
        open: root.popupOpen
        namespace: "dotfiles-tailscale-popup"
        cardWidth: 280
        cardHeight: Math.min(420, popupColumn.implicitHeight + 24)
        onDismissRequested: root.popupOpen = false

        Commons.KbNavScope {
            id: kbNav
            content: popupColumn
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
                        property bool kbNavTarget: true
                        function kbActivate() { root.runToggle() }
                        readonly property bool navFocused: kbNav.focusedItem === toggleButton
                        width: parent.width
                        height: 30
                        radius: 6
                        color: toggleMouse.containsMouse ? Commons.Color.launcher.selectionBackground : "transparent"
                        border.color: toggleButton.navFocused ? Commons.Color.launcher.selectionBorder : "transparent"
                        border.width: toggleButton.navFocused ? 2 : 0

                        Text {
                            anchors.centerIn: parent
                            text: root.connected ? "Disconnect" : "Connect"
                            color: toggleMouse.containsMouse ? Commons.Color.launcher.textOnMuted : Commons.Color.launcher.text
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
                            property bool kbNavTarget: true
                            function kbActivate() { root.copyIp(peerRow.modelData.ip) }
                            readonly property bool navFocused: kbNav.focusedItem === peerRow

                            width: popupColumn.width
                            height: peerInner.implicitHeight + 8
                            radius: 6
                            color: peerMouse.containsMouse ? Commons.Color.launcher.selectionBackground : "transparent"
                            border.color: peerRow.navFocused ? Commons.Color.launcher.selectionBorder : "transparent"
                            border.width: peerRow.navFocused ? 2 : 0

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
                                    color: peerMouse.containsMouse ? Commons.Color.launcher.textOnMuted : Commons.Color.launcher.text
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    width: parent.width - 78
                                    spacing: 1

                                    Text {
                                        width: parent.width
                                        text: peerRow.modelData.name
                                        color: peerMouse.containsMouse ? Commons.Color.launcher.textOnMuted : Commons.Color.launcher.text
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: [peerRow.modelData.ip, peerRow.modelData.altName].filter(function(s) { return s && s.length > 0 }).join(" · ")
                                        color: peerMouse.containsMouse ? Commons.Color.launcher.textOnMuted : Commons.Color.launcher.textMuted
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
