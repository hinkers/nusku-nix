// Left of the clock: opens the app launcher (the same as Super + Space).
import QtQuick
import Quickshell
import qs
import qs.services
import qs.widgets

Rectangle {
    id: root
    required property ShellScreen screen
    implicitHeight: Theme.barHeight - 8
    implicitWidth: implicitHeight + 6
    radius: Theme.radius
    color: mouse.containsMouse || (Menus.launcher.open && Menus.launcher.screen === screen) ? Colors.surface1 : Colors.surface0

    Icon { anchors.centerIn: parent; text: "󰀻"; color: Colors.accent }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Menus.launcher.toggleOn(root.screen)
    }
    Tip { text: "Apps (Super + Space)"; hovered: mouse.containsMouse }
}
