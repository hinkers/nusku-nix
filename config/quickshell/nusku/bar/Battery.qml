// The battery (laptops only): green, yellow at 25%, red at 10%, teal while charging. A click
// opens its details under it (menus/BatteryMenu.qml).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.services
import qs.widgets

Rectangle {
    id: root
    required property ShellScreen screen
    readonly property var dev: UPower.displayDevice
    readonly property real pct: dev ? Math.round(dev.percentage * (dev.percentage <= 1 ? 100 : 1)) : 0
    readonly property bool charging: dev && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged || dev.state === UPowerDeviceState.PendingCharge)
    readonly property color tint: charging ? Colors.teal : pct <= 10 ? Colors.red : pct <= 25 ? Colors.yellow : Colors.green

    visible: dev && dev.ready && dev.isLaptopBattery
    implicitHeight: Theme.barHeight - 8
    implicitWidth: row.implicitWidth + 24
    radius: Theme.radius
    color: mouse.containsMouse || (Menus.battery.open && Menus.battery.screen === screen) ? Colors.surface1 : Colors.surface0

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Menus.battery.toggleAt(root.screen, root.mapToItem(null, root.width / 2, 0).x)
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Icon {
            text: charging ? "󰂄" : ["󰁺", "󰁼", "󰁾", "󰂀", "󰁹"][Math.min(4, Math.floor(pct / 20))]
            color: tint
        }
        Label {
            text: pct + "%"
            color: tint
        }
    }
}
