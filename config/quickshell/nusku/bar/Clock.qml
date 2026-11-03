// Day, date and time; a click opens the calendar under it (menus/Calendar.qml; again closes it).
import QtQuick
import Quickshell
import qs
import qs.services
import qs.widgets

Rectangle {
    id: root
    required property ShellScreen screen
    implicitHeight: Theme.barHeight - 8
    implicitWidth: label.implicitWidth + 24
    radius: Theme.radius
    color: mouse.containsMouse || (Menus.calendar.open && Menus.calendar.screen === screen) ? Colors.surface1 : Colors.surface0

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    Label {
        id: label
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "ddd dd MMM  HH:mm")
        color: Colors.accent
        font.bold: true
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Menus.calendar.toggleOn(root.screen)
    }
}
