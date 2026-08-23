import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland
import QtQuick

import "../../Commons" as Commons

Item {
    id: root
    property var shell
    property bool nowPlayingPopupOpen: false
    property bool nowPlayingTooltipVisible: false
    property string selectedPlayerKey: ""

    function playerKey(p) {
        return p ? p.dbusName : ""
    }

    function hasTrackMetadata(p) {
        return !!(p && (p.trackTitle || p.trackArtist))
    }

    readonly property var mprisPlayers: Mpris.players ? Mpris.players.values : []
    readonly property var sourcePlayers: {
        var list = []
        for (var i = 0; i < mprisPlayers.length; i++) {
            if (hasTrackMetadata(mprisPlayers[i])) list.push(mprisPlayers[i])
        }
        return list
    }
    readonly property var activePlayer: {
        if (root.selectedPlayerKey) {
            for (var i = 0; i < sourcePlayers.length; i++) {
                if (playerKey(sourcePlayers[i]) === root.selectedPlayerKey) return sourcePlayers[i]
            }
        }
        for (var j = 0; j < sourcePlayers.length; j++) {
            if (sourcePlayers[j].isPlaying) return sourcePlayers[j]
        }
        return sourcePlayers.length > 0 ? sourcePlayers[0] : null
    }

    onActivePlayerChanged: if (!activePlayer) nowPlayingPopupOpen = false

    readonly property real activePlayerLength: activePlayer && activePlayer.lengthSupported ? activePlayer.length : 0
    readonly property real seekProgress: activePlayerLength > 0 ? Math.min(1, livePosition / activePlayerLength) : 0
    property real livePosition: 0

    function formatSeekTime(seconds) {
        if (!isFinite(seconds) || seconds < 0) return "--:--"
        var s = Math.floor(seconds)
        var m = Math.floor(s / 60)
        var r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    Timer {
        interval: 250
        running: root.activePlayer !== null && root.activePlayer.isPlaying
        repeat: true
        onTriggered: root.livePosition = root.activePlayer.position
    }

    Connections {
        target: root.activePlayer
        function onPlaybackStateChanged() { root.livePosition = root.activePlayer.position }
        function onTrackTitleChanged() { root.livePosition = root.activePlayer.position }
        function onPositionChanged() { root.livePosition = root.activePlayer.position }
    }

    implicitWidth: nowPlaying.implicitWidth
    implicitHeight: nowPlaying.implicitHeight

    Row {
        id: nowPlaying
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        visible: root.activePlayer !== null

        Text {
            id: nowPlayingIcon
            anchors.verticalCenter: parent.verticalCenter
            color: root.activePlayer && root.activePlayer.isPlaying ? Commons.Color.bar.text : Qt.darker(Commons.Color.bar.text, 1.5)
            text: root.activePlayer && root.activePlayer.isPlaying ? "⏸" : "▶"

            MouseArea {
                anchors.fill: parent
                onClicked: if (root.activePlayer) root.activePlayer.togglePlaying()
            }
        }

        Item {
            id: nowPlayingScrollClip
            readonly property real maxWidth: nowPlayingFontMetrics.averageCharacterWidth * 30
            width: Math.min(maxWidth, nowPlayingLabel.implicitWidth)
            height: nowPlayingIcon.implicitHeight
            clip: true
            anchors.verticalCenter: parent.verticalCenter

            FontMetrics {
                id: nowPlayingFontMetrics
                font: nowPlayingLabel.font
            }

            Text {
                id: nowPlayingLabel
                anchors.verticalCenter: parent.verticalCenter
                color: Commons.Color.bar.text
                text: {
                    var p = root.activePlayer
                    if (!p) return ""
                    var artist = p.trackArtist ? (p.trackArtist + "  ·  ") : ""
                    return artist + (p.trackTitle || "")
                }

                property bool needsScroll: implicitWidth > nowPlayingScrollClip.width

                NumberAnimation on x {
                    running: nowPlayingLabel.needsScroll && !root.nowPlayingPopupOpen
                    loops: Animation.Infinite
                    duration: Math.max(6000, nowPlayingLabel.implicitWidth * 25)
                    from: nowPlayingScrollClip.width
                    to: -nowPlayingLabel.implicitWidth
                    easing.type: Easing.Linear
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.nowPlayingPopupOpen = !root.nowPlayingPopupOpen
                onEntered: root.nowPlayingTooltipVisible = true
                onExited: root.nowPlayingTooltipVisible = false
            }
        }
    }

    Rectangle {
        id: nowPlayingTooltip
        visible: root.nowPlayingTooltipVisible && root.activePlayer !== null && !root.nowPlayingPopupOpen
        width: tooltipText.implicitWidth + 16
        height: tooltipText.implicitHeight + 10
        radius: 6
        color: Commons.Color.launcher.cardBackground
        border.color: Commons.Color.launcher.cardBorder
        border.width: 1
        anchors.top: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 4

        Text {
            id: tooltipText
            anchors.centerIn: parent
            color: Commons.Color.launcher.text
            font.pixelSize: 12
            text: {
                var p = root.activePlayer
                if (!p) return ""
                return (p.trackTitle || "") + (p.trackArtist ? "  —  " + p.trackArtist : "")
            }
        }
    }

    PanelWindow {
        id: nowPlayingPopupPanel
        visible: root.nowPlayingPopupOpen
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: Commons.Color.transparent
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "dotfiles-now-playing-popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: root.nowPlayingPopupOpen = false
        }

        Rectangle {
            id: popupCard
            visible: root.activePlayer !== null
            width: 320
            height: popupColumn.implicitHeight + 28
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
                anchors.margins: 14
                spacing: 10

                Row {
                    width: parent.width
                    spacing: 10

                    Rectangle {
                        id: artFrame
                        width: 64
                        height: 64
                        radius: 8
                        color: Commons.Color.launcher.inputBackground
                        border.color: Commons.Color.launcher.cardBorder
                        border.width: 1

                        Image {
                            anchors.fill: parent
                            anchors.margins: 2
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            source: root.activePlayer && root.activePlayer.trackArtUrl ? root.activePlayer.trackArtUrl : ""
                            visible: source !== ""
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !root.activePlayer || !root.activePlayer.trackArtUrl
                            text: "♪"
                            color: Commons.Color.launcher.textMuted
                            font.pixelSize: 28
                        }
                    }

                    Column {
                        width: parent.width - 74
                        spacing: 4
                        anchors.verticalCenter: artFrame.verticalCenter

                        Text {
                            width: parent.width
                            text: root.activePlayer ? (root.activePlayer.trackTitle || "Unknown title") : ""
                            color: Commons.Color.launcher.text
                            font.pixelSize: 15
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.activePlayer ? (root.activePlayer.trackArtist || "") : ""
                            color: Commons.Color.launcher.textMuted
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            visible: text.length > 0
                        }

                        Text {
                            width: parent.width
                            text: root.activePlayer ? (root.activePlayer.trackAlbum || "") : ""
                            color: Commons.Color.launcher.textMuted
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            visible: text.length > 0
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 4
                    visible: root.activePlayer !== null && root.activePlayerLength > 0

                    Item {
                        id: seekBarWrap
                        width: parent.width
                        height: 6

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 2
                            radius: 1
                            color: Commons.Color.launcher.cardBorder
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * root.seekProgress
                            height: 2
                            radius: 1
                            color: Commons.Color.launcher.selection
                        }

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: Commons.Color.launcher.selection
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width, parent.width * root.seekProgress - width / 2))
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.topMargin: -6
                            anchors.bottomMargin: -6
                            enabled: root.activePlayer && root.activePlayer.canSeek && root.activePlayerLength > 0
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: function(mouse) {
                                var frac = Math.max(0, Math.min(1, mouse.x / width))
                                var target = frac * root.activePlayerLength
                                root.activePlayer.position = target
                                root.livePosition = target
                            }
                        }
                    }

                    Row {
                        width: parent.width

                        Text {
                            text: root.formatSeekTime(root.livePosition)
                            color: Commons.Color.launcher.textMuted
                            font.pixelSize: 10
                        }

                        Item { width: parent.width - 70; height: 1 }

                        Text {
                            text: root.formatSeekTime(root.activePlayerLength)
                            color: Commons.Color.launcher.textMuted
                            font.pixelSize: 10
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 18

                    Text {
                        readonly property bool enabledHere: root.activePlayer && root.activePlayer.canGoPrevious
                        text: "⏮"
                        font.pixelSize: 18
                        color: Commons.Color.launcher.text
                        opacity: enabledHere ? 1.0 : 0.35
                        MouseArea {
                            anchors.fill: parent
                            enabled: parent.enabledHere
                            onClicked: root.activePlayer.previous()
                        }
                    }

                    Text {
                        readonly property bool enabledHere: root.activePlayer && (root.activePlayer.canTogglePlaying || root.activePlayer.canPlay || root.activePlayer.canPause)
                        text: root.activePlayer && root.activePlayer.isPlaying ? "⏸" : "▶"
                        font.pixelSize: 20
                        color: Commons.Color.launcher.text
                        opacity: enabledHere ? 1.0 : 0.35
                        MouseArea {
                            anchors.fill: parent
                            enabled: parent.enabledHere
                            onClicked: root.activePlayer.togglePlaying()
                        }
                    }

                    Text {
                        readonly property bool enabledHere: root.activePlayer && root.activePlayer.canGoNext
                        text: "⏭"
                        font.pixelSize: 18
                        color: Commons.Color.launcher.text
                        opacity: enabledHere ? 1.0 : 0.35
                        MouseArea {
                            anchors.fill: parent
                            enabled: parent.enabledHere
                            onClicked: root.activePlayer.next()
                        }
                    }
                }

                Rectangle {
                    visible: root.sourcePlayers.length > 1
                    width: parent.width
                    height: 1
                    color: Commons.Color.launcher.cardBorder
                }

                Column {
                    id: sourceList
                    visible: root.sourcePlayers.length > 1
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: root.sourcePlayers

                        Rectangle {
                            id: sourceRow
                            required property var modelData

                            readonly property var player: modelData
                            readonly property bool selected: root.activePlayer && player && root.playerKey(root.activePlayer) === root.playerKey(player)
                            readonly property string sourceTitle: player ? (player.trackTitle || player.identity || player.desktopEntry || "Media source") : "Media source"
                            readonly property string sourceDetail: player && player.trackArtist ? player.trackArtist : (player && player.identity ? player.identity : "")

                            width: sourceList.width
                            height: sourceInner.implicitHeight + 10
                            radius: 6
                            color: selected ? Commons.Color.launcher.selectionBackground : "transparent"
                            border.color: selected ? Commons.Color.launcher.selectionBorder : "transparent"
                            border.width: 1

                            Row {
                                id: sourceInner
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    text: sourceRow.player && sourceRow.player.isPlaying ? "⏸" : "▶"
                                    color: Commons.Color.launcher.text
                                    font.pixelSize: 12
                                    width: 16
                                    horizontalAlignment: Text.AlignHCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    width: parent.width - 24
                                    spacing: 1
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        width: parent.width
                                        text: sourceRow.sourceTitle
                                        color: Commons.Color.launcher.text
                                        font.pixelSize: 12
                                        font.bold: sourceRow.selected
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: sourceRow.sourceDetail
                                        color: Commons.Color.launcher.textMuted
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                        visible: text.length > 0
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.selectedPlayerKey = root.playerKey(sourceRow.player)
                            }
                        }
                    }
                }
            }
        }
    }
}
