// Day, date and time; a click opens the calendar drop-down (nusku-calendar; again closes it).
import QtQuick
import Quickshell
import qs
import qs.widgets

Rectangle {
    implicitHeight: Theme.barHeight - 8
    implicitWidth: label.implicitWidth + 24
    radius: Theme.radius
    color: mouse.containsMouse ? Colors.surface1 : Colors.surface0

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
        onClicked: Quickshell.execDetached(["nusku-calendar"])
    }
}
