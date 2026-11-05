// Right of the clock: what's playing (the track, when there is one); a click opens the media
// menu under it (menus/MediaMenu.qml), middle-click plays or pauses, scroll skips tracks.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.widgets

Rectangle {
    id: root
    required property ShellScreen screen
    readonly property var player: Media.player
    implicitHeight: Theme.barHeight - 8
    // Just the icon (nothing playing, or no title): the same size as the launcher button on
    // the clock's other side, so the two match.
    implicitWidth: title.visible ? row.implicitWidth + 20 : implicitHeight + 6
    radius: Theme.radius
    color: mouse.containsMouse || (Menus.media.open && Menus.media.screen === screen) ? Colors.surface1 : Colors.surface0

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Icon {
            id: icon
            text: root.player && root.player.isPlaying ? "󰏤" : "󰎆"
            color: root.player ? Colors.accent : Colors.overlay1
            // Centre the glyph's ink, not its advance: these glyphs have more room on the left.
            Layout.leftMargin: -2 * (ink.tightBoundingRect.x + ink.tightBoundingRect.width / 2 - ink.advanceWidth / 2)
            TextMetrics { id: ink; font: icon.font; text: icon.text }
        }
        Label {
            id: title
            visible: root.player !== null && text !== ""
            Layout.maximumWidth: 220
            text: root.player ? (root.player.trackTitle || root.player.identity) : ""
            color: Colors.subtext1
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: e => {
            if (e.button === Qt.MiddleButton) { if (root.player) root.player.togglePlaying(); }
            else Menus.media.toggleAt(root.screen, root.mapToItem(null, root.width / 2, 0).x);
        }
        onWheel: e => {
            if (!root.player) return;
            if (e.angleDelta.y > 0 && root.player.canGoPrevious) root.player.previous();
            else if (e.angleDelta.y < 0 && root.player.canGoNext) root.player.next();
        }
    }
    Tip { text: root.player ? "" : "Nothing playing"; hovered: mouse.containsMouse }
}
