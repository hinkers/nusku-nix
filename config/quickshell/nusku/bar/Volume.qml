// The speaker: the output's volume (and mute) at a glance. Click for the volume menu under it
// (menus/VolumeMenu.qml), scroll to change the volume, middle-click to mute.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.widgets

Rectangle {
    id: root
    required property ShellScreen screen
    implicitHeight: Theme.barHeight - 8
    implicitWidth: row.implicitWidth + 20
    radius: Theme.radius
    color: mouse.containsMouse || (Menus.volume.open && Menus.volume.screen === screen) ? Colors.surface1 : Colors.surface0

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Icon { text: Audio.icon; color: Audio.muted ? Colors.overlay1 : Colors.accent }
        Label {
            text: Audio.muted ? "Muted" : Math.round(Audio.volume * 100) + "%"
            color: Audio.muted ? Colors.overlay1 : Colors.text
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: e => {
            if (e.button === Qt.MiddleButton) Audio.toggleMute(Audio.sink);
            else Menus.volume.toggleAt(root.screen, root.mapToItem(null, root.width / 2, 0).x);
        }
        onWheel: e => Audio.nudge(e.angleDelta.y > 0 ? 0.05 : -0.05)
    }
}
