// What's playing, down from under the bar's media button: the art, track and artist, where it
// is in the track (click the bar to jump, when the player allows it), previous / play-pause /
// next, shuffle and repeat, and which player when more than one is open.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.widgets

PanelWindow {
    id: win
    readonly property var menu: Menus.media
    readonly property var player: Media.player
    screen: menu.screen
    visible: menu.progress > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: drawer.area }
    WlrLayershell.namespace: "nusku-media"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: menu.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // MPRIS doesn't announce the position as it plays: ask for it while the menu is out.
    Timer {
        running: win.menu.open && win.player !== null && win.player.isPlaying
        interval: 1000
        repeat: true
        onTriggered: win.player.positionChanged()
    }
    function time(s) {
        if (!(s >= 0) || !isFinite(s)) return "–:––";
        const m = Math.floor(s / 60), sec = Math.floor(s % 60);
        return `${m}:${sec < 10 ? "0" : ""}${sec}`;
    }

    Drawer {
        id: drawer
        edge: "top"
        length: 380
        depth: body.implicitHeight + 28
        Behavior on depth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        progress: win.menu.progress
        readonly property real edgeRoom: Theme.frame + Theme.frameRadius + length / 2
        centre: win.menu.anchor < 0 ? win.width / 2
            : Math.max(edgeRoom, Math.min(win.width - edgeRoom, win.menu.anchor))

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: win.menu.open = false
            Keys.onSpacePressed: if (win.player) win.player.togglePlaying()

            ColumnLayout {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 12

                Label {
                    visible: win.player === null
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                    horizontalAlignment: Text.AlignHCenter
                    text: "Nothing playing"
                    color: Colors.overlay1
                }

                // The track.
                RowLayout {
                    visible: win.player !== null
                    spacing: 14
                    ClippingRectangle {
                        implicitWidth: 96
                        implicitHeight: 96
                        radius: Theme.radiusLarge
                        color: Colors.surface0
                        Image {
                            id: art
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: win.player ? win.player.trackArtUrl : ""
                            asynchronous: true
                        }
                        Icon {
                            anchors.centerIn: parent
                            visible: art.status !== Image.Ready
                            text: "󰎆"
                            size: 36
                            color: Colors.accent
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            Layout.fillWidth: true
                            text: win.player ? (win.player.trackTitle || "Unknown track") : ""
                            font.bold: true
                            font.pixelSize: Theme.fontSizeLarge
                        }
                        Label {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: win.player ? win.player.trackArtist : ""
                            color: Colors.subtext1
                        }
                        Label {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: win.player ? win.player.trackAlbum : ""
                            color: Colors.overlay1
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        Label {
                            Layout.topMargin: 4
                            text: win.player ? win.player.identity : ""
                            color: Colors.overlay1
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                // Where it is in the track.
                ColumnLayout {
                    visible: win.player !== null && win.player.lengthSupported && win.player.length > 0
                    Layout.fillWidth: true
                    spacing: 4
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 14
                        readonly property real frac: win.player && win.player.length > 0
                            ? Math.min(1, Math.max(0, win.player.position / win.player.length)) : 0
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 6
                            radius: 3
                            color: Colors.surface1
                            Rectangle { width: parent.width * parent.parent.frac; height: parent.height; radius: 3; color: Colors.accent }
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: win.player && win.player.canSeek && win.player.positionSupported
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: e => win.player.position = win.player.length * Math.min(1, Math.max(0, e.x / width))
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: win.player ? win.time(win.player.position) : ""; color: Colors.overlay1; font.pixelSize: Theme.fontSizeSmall }
                        Item { Layout.fillWidth: true }
                        Label { text: win.player ? win.time(win.player.length) : ""; color: Colors.overlay1; font.pixelSize: Theme.fontSizeSmall }
                    }
                }

                // The controls.
                RowLayout {
                    visible: win.player !== null
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10
                    IconButton {
                        implicitWidth: 40; implicitHeight: 40
                        visible: win.player && win.player.shuffleSupported
                        icon: "󰒝"
                        active: win.player && win.player.shuffle
                        tooltip: "Shuffle"
                        onClicked: win.player.shuffle = !win.player.shuffle
                    }
                    IconButton {
                        implicitWidth: 44; implicitHeight: 44
                        icon: "󰒮"
                        enabled: win.player && win.player.canGoPrevious
                        tooltip: "Previous"
                        onClicked: win.player.previous()
                    }
                    IconButton {
                        implicitWidth: 56; implicitHeight: 56
                        radius: 28
                        icon: win.player && win.player.isPlaying ? "󰏤" : "󰐊"
                        iconSize: 26
                        active: true
                        tooltip: win.player && win.player.isPlaying ? "Pause" : "Play"
                        onClicked: win.player.togglePlaying()
                    }
                    IconButton {
                        implicitWidth: 44; implicitHeight: 44
                        icon: "󰒭"
                        enabled: win.player && win.player.canGoNext
                        tooltip: "Next"
                        onClicked: win.player.next()
                    }
                    IconButton {
                        implicitWidth: 40; implicitHeight: 40
                        visible: win.player && win.player.loopSupported
                        icon: win.player && win.player.loopState === MprisLoopState.Track ? "󰑘" : "󰑖"
                        active: win.player && win.player.loopState !== MprisLoopState.None
                        tooltip: !win.player ? "" : win.player.loopState === MprisLoopState.None ? "Repeat"
                            : win.player.loopState === MprisLoopState.Playlist ? "Repeat: all" : "Repeat: this track"
                        // None -> Playlist -> Track -> None
                        onClicked: win.player.loopState = win.player.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                            : win.player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
                    }
                }

                // Which player, when there's more than one.
                Flow {
                    visible: Media.players.length > 1
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: Media.players
                        IconButton {
                            required property var modelData
                            implicitHeight: 30
                            icon: modelData.isPlaying ? "󰐊" : "󰏤"
                            text: modelData.identity
                            iconSize: Theme.fontSizeSmall
                            active: modelData === win.player
                            onClicked: Media.pickedName = modelData.dbusName
                        }
                    }
                }
            }
        }
    }
}
