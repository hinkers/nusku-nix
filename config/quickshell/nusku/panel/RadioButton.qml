// A wide toggle with a status line (Wi-Fi, Bluetooth) and a › that opens its picker.
import QtQuick
import QtQuick.Layouts
import qs
import qs.widgets

Rectangle {
    id: root
    property string icon: ""
    property string title: ""
    property string status: ""
    property bool active: false
    property string tooltip: ""
    property string pickTooltip: ""
    signal toggled()
    signal pick()

    implicitHeight: 56
    radius: Theme.radiusLarge
    color: active ? Colors.accent : Colors.surface0
    Behavior on color { ColorAnimation { duration: Theme.animMs } }

    MouseArea {
        id: main
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
    Tip {
        text: root.tooltip
        hovered: main.containsMouse && !pickMouse.containsMouse
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 6
        spacing: 10
        Icon {
            text: root.icon
            size: 20
            color: root.active ? Colors.base : Colors.text
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
                Layout.fillWidth: true
                text: root.title
                font.bold: true
                color: root.active ? Colors.base : Colors.text
            }
            Label {
                Layout.fillWidth: true
                text: root.status
                font.pixelSize: Theme.fontSizeSmall
                color: root.active ? Theme.alpha(Colors.base, 0.75) : Colors.subtext0
            }
        }
        Rectangle {
            implicitWidth: 32
            implicitHeight: 44
            radius: Theme.radius
            color: pickMouse.containsMouse ? Theme.alpha(Colors.base, 0.2) : "transparent"
            Icon {
                anchors.centerIn: parent
                text: "󰅂"
                color: root.active ? Colors.base : Colors.text
            }
            MouseArea {
                id: pickMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pick()
            }
            Tip {
                text: root.pickTooltip
                hovered: pickMouse.containsMouse
            }
        }
    }
}
