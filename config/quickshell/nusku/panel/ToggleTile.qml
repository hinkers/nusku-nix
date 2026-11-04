// A quick settings toggle: an icon, its name and whether it's on; the accent when it is.
import QtQuick
import QtQuick.Layouts
import qs
import qs.widgets

Rectangle {
    id: root
    property string icon: ""
    property string title: ""
    property bool active: false
    property string tooltip: ""
    signal clicked()

    implicitHeight: 52
    radius: Theme.radiusLarge
    color: active ? Colors.accent : mouse.containsMouse ? Colors.surface1 : Colors.surface0
    Behavior on color { ColorAnimation { duration: Theme.animMs } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 10
        spacing: 10
        Icon { text: root.icon; size: 18; color: root.active ? Colors.base : Colors.text }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
                Layout.fillWidth: true
                text: root.title
                font.bold: true
                font.pixelSize: Theme.fontSizeSmall + 1
                color: root.active ? Colors.base : Colors.text
            }
            Label {
                Layout.fillWidth: true
                text: root.active ? "On" : "Off"
                font.pixelSize: Theme.fontSizeSmall
                color: root.active ? Theme.alpha(Colors.base, 0.75) : Colors.subtext0
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
    Tip { text: root.tooltip; hovered: mouse.containsMouse }
}
