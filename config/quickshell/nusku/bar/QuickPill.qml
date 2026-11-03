// One pill for network, Bluetooth and notifications: a click opens quick settings. Right-click
// network or Bluetooth for their pickers, the bell for Do Not Disturb.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.widgets

Rectangle {
    implicitHeight: Theme.barHeight - 8
    implicitWidth: row.implicitWidth + 16
    radius: Theme.radius
    color: PanelState.open ? Colors.surface1 : mouse.containsMouse ? Colors.surface1 : Colors.surface0

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: PanelState.toggle()
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 12

        component Glyph: Icon {
            id: g
            property bool off: false
            property var onRight: null
            color: off ? Colors.overlay1 : Colors.accent
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: e => e.button === Qt.RightButton && g.onRight ? g.onRight() : PanelState.toggle()
            }
        }

        Glyph {
            text: Net.netIcon
            off: !Net.online
            onRight: () => Quickshell.execDetached(["nusku-menu-wifi"])
        }
        Glyph {
            text: Net.btIcon
            off: !Net.btOn
            onRight: () => Quickshell.execDetached(["nusku-menu-bluetooth"])
        }
        Glyph {
            text: Notifs.dnd ? "󰂛" : Notifs.count > 0 ? "󱅫" : "󰂜"
            onRight: () => Notifs.dnd = !Notifs.dnd
        }
    }
}
