// A rounded button with a glyph (and an optional label). `active` fills it with the accent.
import QtQuick
import QtQuick.Layouts
import qs

Rectangle {
    id: root
    property string icon: ""
    property string text: ""
    property bool active: false
    property real iconSize: Theme.fontSize + 4
    property string tooltip: ""
    readonly property bool hovered: mouse.containsMouse
    signal clicked()
    signal rightClicked()

    implicitHeight: 44
    implicitWidth: text === "" ? 44 : row.implicitWidth + 28
    radius: Theme.radius
    color: active ? Colors.accent : (mouse.containsMouse ? Colors.surface1 : Colors.surface0)
    Behavior on color { ColorAnimation { duration: Theme.animMs } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 10
        Icon {
            text: root.icon
            size: root.iconSize
            color: root.active ? Colors.base : Colors.text
        }
        Label {
            visible: root.text !== ""
            text: root.text
            color: root.active ? Colors.base : Colors.text
            font.bold: root.active
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: e => e.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }

    Tip {
        text: root.tooltip
        hovered: mouse.containsMouse
    }
}
