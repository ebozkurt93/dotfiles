import Quickshell
import Quickshell.Io
import QtQuick

import "../../Commons" as Commons

Item {
    id: root
    property var shell
    property bool popupOpen: false
    property string home: Quickshell.env("HOME")
    // Named weatherData, not data: `data` is QtQuick.Item's own default property, and shadowing it silently breaks every child in this file from attaching.
    property var weatherData: null

    readonly property bool hasData: root.weatherData !== null
    readonly property real temperatureC: hasData && root.weatherData.temperature_c !== undefined ? root.weatherData.temperature_c : 0
    readonly property var feelsLikeC: hasData ? root.weatherData.feels_like_c : null
    readonly property string symbolCode: hasData ? (root.weatherData.symbol_code || "") : ""
    readonly property string label: hasData ? (root.weatherData.label || "Weather") : "Weather"
    readonly property var nextRainAt: hasData ? root.weatherData.next_rain_at : null
    readonly property var nextRainAmountMm: hasData ? root.weatherData.next_rain_amount_mm : null
    readonly property var fetchedAt: hasData ? root.weatherData.fetched_at : null
    readonly property var latitude: hasData ? root.weatherData.latitude : null
    readonly property var longitude: hasData ? root.weatherData.longitude : null

    // Maps met.no/Yr's `symbol_code` strings (e.g. "clearsky_day"), not Omarchy's wttr.in-derived codes.
    function symbolIcon(code) {
        if (!code) return "󰖐"
        if (code.indexOf("thunder") !== -1) return "󰙾"
        if (code.indexOf("sleet") !== -1) return "󰙿"
        if (code.indexOf("snow") !== -1) return "󰖘"
        if (code.indexOf("rain") !== -1) return "󰖗"
        if (code.indexOf("fog") !== -1) return "󰖑"
        if (code.indexOf("clearsky") !== -1) return code.indexOf("night") !== -1 ? "󰖔" : "󰖙"
        if (code.indexOf("fair") !== -1 || code.indexOf("partlycloudy") !== -1)
            return code.indexOf("night") !== -1 ? "󰼱" : "󰖕"
        return "󰖐"
    }

    function refresh() {
        weatherProvider.running = false
        weatherProvider.command = [home + "/bin/weather"]
        weatherProvider.running = true
    }

    property bool forcedRefreshPending: false

    function forceRefresh() {
        forcedRefreshPending = true
        weatherProvider.running = false
        weatherProvider.command = [home + "/bin/weather", "--force"]
        weatherProvider.running = true
    }

    function yrUrl() {
        if (root.latitude === null || root.longitude === null) return ""
        return "https://www.yr.no/en/search?q=" + root.latitude + "," + root.longitude
    }

    function openInYr() {
        var url = yrUrl()
        if (url === "") return
        Quickshell.execDetached(["xdg-open", url])
    }

    Component.onCompleted: refresh()

    // The script itself caches through `bkt` (45m TTL); this timer just picks up the cache expiring.
    Timer {
        interval: 900000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: weatherProvider
        property string buffer: ""
        stdout: SplitParser {
            onRead: function(data) { weatherProvider.buffer += data }
        }
        onStarted: weatherProvider.buffer = ""
        onExited: function(exitCode, exitStatus) {
            var wasForced = root.forcedRefreshPending
            root.forcedRefreshPending = false
            if (exitCode !== 0 || exitStatus !== 0) {
                if (wasForced) Quickshell.execDetached(["notify-send", "-t", "3000", "Weather", "Refresh failed"])
                return
            }
            try {
                root.weatherData = JSON.parse(weatherProvider.buffer)
            } catch (e) {
                console.warn("weather returned invalid JSON:", e)
                if (wasForced) Quickshell.execDetached(["notify-send", "-t", "3000", "Weather", "Refresh failed"])
            }
        }
    }

    function formatTemp(c) {
        return Math.round(c) + "°"
    }

    function formatRainEta(iso) {
        if (!iso) return ""
        var d = new Date(iso)
        if (isNaN(d.getTime())) return ""
        var diffMin = Math.round((d.getTime() - Date.now()) / 60000)
        if (diffMin <= 0) return "now"
        if (diffMin < 60) return diffMin + "m"
        return Math.round(diffMin / 60) + "h"
    }

    function formatAgo(iso) {
        if (!iso) return ""
        var d = new Date(iso)
        if (isNaN(d.getTime())) return ""
        var diffMin = Math.round((Date.now() - d.getTime()) / 60000)
        if (diffMin <= 0) return "just now"
        if (diffMin < 60) return diffMin + "m ago"
        return Math.round(diffMin / 60) + "h ago"
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Commons.Color.bar.text
            text: root.symbolIcon(root.symbolCode)
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Commons.Color.bar.text
            text: root.hasData ? root.formatTemp(root.temperatureC) : "--"
        }
    }

    // Delays the single-click toggle so a double-click doesn't flash the popup open first.
    Timer {
        id: singleClickTimer
        interval: 250
        repeat: false
        onTriggered: {
            root.popupOpen = !root.popupOpen
            if (root.popupOpen) root.refresh()
        }
    }

    MouseArea {
        anchors.fill: row
        onClicked: singleClickTimer.restart()
        onDoubleClicked: {
            singleClickTimer.stop()
            Quickshell.execDetached(["notify-send", "-t", "3000", "Weather", "Refreshing…"])
            root.forceRefresh()
        }
    }

    Commons.PopupPanel {
        id: popupPanel
        open: root.popupOpen
        namespace: "dotfiles-weather-popup"
        cardWidth: 240
        cardHeight: popupColumn.implicitHeight + 24
        onDismissRequested: root.popupOpen = false

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
                    height: Math.max(headerIcon.implicitHeight, headerText.implicitHeight, headerTemp.implicitHeight)

                    Text {
                        id: headerIcon
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.symbolIcon(root.symbolCode)
                        color: Commons.Color.launcher.text
                        font.pixelSize: 22
                    }

                    Text {
                        id: headerTemp
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.hasData ? root.formatTemp(root.temperatureC) + "C" : "--"
                        color: Commons.Color.launcher.text
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Column {
                        id: headerText
                        anchors.left: headerIcon.right
                        anchors.leftMargin: 10
                        anchors.right: headerTemp.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: root.label
                            color: Commons.Color.launcher.text
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.hasData ? root.symbolCode.replace(/_/g, " ") : "Loading…"
                            color: Commons.Color.launcher.textMuted
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    visible: root.hasData
                    width: parent.width
                    height: 1
                    color: Commons.Color.launcher.cardBorder
                }

                Commons.InfoRow {
                    visible: root.hasData && root.feelsLikeC !== null
                    label: "Feels like"
                    value: root.hasData && root.feelsLikeC !== null ? root.formatTemp(root.feelsLikeC) + "C" : ""
                }

                Commons.InfoRow {
                    visible: root.hasData && root.nextRainAt !== null
                    label: "Next rain"
                    value: root.hasData ? root.formatRainEta(root.nextRainAt)
                        + (root.nextRainAmountMm !== null ? " (" + root.nextRainAmountMm + "mm)" : "") : ""
                }

                Text {
                    visible: root.hasData && root.fetchedAt !== null
                    width: parent.width
                    text: "Updated " + root.formatAgo(root.fetchedAt)
                    color: Commons.Color.launcher.textMuted
                    font.pixelSize: 10
                }

                Text {
                    visible: root.hasData && root.yrUrl() !== ""
                    width: parent.width
                    text: "Open in Yr"
                    color: Commons.Color.launcher.selection
                    font.pixelSize: 11
                    font.bold: true

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openInYr()
                    }
                }
        }
    }

}
