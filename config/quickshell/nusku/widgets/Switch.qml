// An on/off switch.
import QtQuick
import qs

Rectangle {
    id: root
    property bool checked: false
    signal toggled()
    implicitWidth: 44
    implicitHeight: 24
    radius: height / 2
    color: checked ? Colors.accent : Colors.surface1
    Behavior on color { ColorAnimation { duration: Theme.animMs } }
    Rectangle {
        width: 18; height: 18; radius: 9
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 3 : 3
        Behavior on x { NumberAnimation { duration: Theme.animMs } }
        color: root.checked ? Colors.base : Colors.text
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
