import QtQuick

import "../../Commons" as Commons

Column {
    id: root
    width: parent ? parent.width : 0
    spacing: 10

    property string provider: ""
    property var providers: []
    property string effectiveServers: ""
    property bool customOpen: false
    property string customText: ""

    signal providerPicked(string provider)
    signal customDnsRequested()
    signal customTextEdited(string text)
    signal customSubmitted()
    signal customCancelled()

    Text {
        width: parent.width
        text: "DNS" + (root.provider !== "" ? " · " + root.provider : "")
        color: Commons.Color.launcher.textMuted
        font.pixelSize: 10
    }

    Commons.InfoRow {
        visible: root.effectiveServers !== ""
        label: "Servers"
        value: root.effectiveServers
    }

    Row {
        id: dnsRow
        width: parent.width
        spacing: 6

        readonly property real cellWidth: (width - spacing * (root.providers.length - 1)) / root.providers.length

        Repeater {
            model: root.providers

            Rectangle {
                id: dnsPill
                required property string modelData

                readonly property bool active: root.provider === modelData

                width: dnsRow.cellWidth
                height: 26
                radius: 6
                color: active ? Commons.Color.launcher.selectionBackground : "transparent"
                border.color: active ? Commons.Color.launcher.selectionBorder : Commons.Color.launcher.cardBorder
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: dnsPill.modelData
                    color: dnsPill.active ? Commons.Color.launcher.textOnMuted : Commons.Color.launcher.text
                    font.pixelSize: 10
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (dnsPill.modelData === "Custom") root.customDnsRequested()
                        else root.providerPicked(dnsPill.modelData)
                    }
                }
            }
        }
    }

    Item {
        visible: root.customOpen
        width: parent.width
        height: visible ? customDnsColumn.implicitHeight : 0

        Column {
            id: customDnsColumn
            width: parent.width
            spacing: 6

            Text {
                width: parent.width
                text: "Custom DNS servers (space-separated)"
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
                    id: customDnsInput
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    color: Commons.Color.launcher.text
                    font.pixelSize: 12
                    focus: root.customOpen
                    text: root.customText
                    onTextChanged: root.customTextEdited(text)
                    onAccepted: root.customSubmitted()
                    Keys.onEscapePressed: root.customCancelled()
                }
            }

            Row {
                spacing: 8
                anchors.right: parent.right

                Text {
                    text: "Cancel"
                    color: Commons.Color.launcher.textMuted
                    font.pixelSize: 11
                    MouseArea { anchors.fill: parent; onClicked: root.customCancelled() }
                }

                Text {
                    text: "Set"
                    color: Commons.Color.launcher.selection
                    font.pixelSize: 11
                    font.bold: true
                    MouseArea { anchors.fill: parent; onClicked: root.customSubmitted() }
                }
            }
        }
    }
}
