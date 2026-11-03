// The media player (the one playing, else the first): art, title, artist and controls.
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs
import qs.widgets

Rectangle {
    id: root
    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.isPlaying) ?? players[0] ?? null
    visible: player !== null
    implicitHeight: 84
    radius: Theme.radiusLarge
    color: Colors.surface0

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 12
        ClippingRectangle {
            implicitWidth: 64
            implicitHeight: 64
            radius: Theme.radius
            color: Colors.surface1
            Image {
                id: art
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: root.player ? root.player.trackArtUrl : ""
                asynchronous: true
            }
            Icon {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: "󰎆"
                size: 26
                color: Colors.accent
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label {
                Layout.fillWidth: true
                text: root.player ? (root.player.trackTitle || root.player.identity) : ""
                font.bold: true
            }
            Label {
                Layout.fillWidth: true
                text: root.player ? root.player.trackArtist : ""
                color: Colors.subtext0
                font.pixelSize: Theme.fontSizeSmall
            }
            RowLayout {
                spacing: 4
                IconButton {
                    implicitHeight: 32; implicitWidth: 32
                    icon: "󰒮"
                    tooltip: "Previous"
                    enabled: root.player && root.player.canGoPrevious
                    onClicked: root.player.previous()
                }
                IconButton {
                    implicitHeight: 32; implicitWidth: 40
                    icon: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
                    tooltip: (root.player && root.player.isPlaying ? "Pause" : "Play") + (root.player ? " (" + root.player.identity + ")" : "")
                    active: true
                    onClicked: root.player.togglePlaying()
                }
                IconButton {
                    implicitHeight: 32; implicitWidth: 32
                    icon: "󰒭"
                    tooltip: "Next"
                    enabled: root.player && root.player.canGoNext
                    onClicked: root.player.next()
                }
            }
        }
    }
}
