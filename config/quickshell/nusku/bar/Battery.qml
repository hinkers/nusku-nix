// The battery (laptops only): green, yellow at 25%, red at 10%, teal while charging.
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs
import qs.widgets

Rectangle {
    readonly property var dev: UPower.displayDevice
    readonly property real pct: dev ? Math.round(dev.percentage * (dev.percentage <= 1 ? 100 : 1)) : 0
    readonly property bool charging: dev && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged || dev.state === UPowerDeviceState.PendingCharge)
    readonly property color tint: charging ? Colors.teal : pct <= 10 ? Colors.red : pct <= 25 ? Colors.yellow : Colors.green

    visible: dev && dev.ready && dev.isLaptopBattery
    implicitHeight: Theme.barHeight - 8
    implicitWidth: row.implicitWidth + 24
    radius: Theme.radius
    color: Colors.surface0

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
