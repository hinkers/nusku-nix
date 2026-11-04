// The battery's details, down from under the bar's battery: the charge, charging or not and
// the time to full / empty, the power draw, the battery's health and size, the power profile,
// and other devices' batteries (a Bluetooth headset or mouse, when UPower knows them).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import qs
import qs.services
import qs.widgets

PanelWindow {
    id: win
    readonly property var menu: Menus.battery
    screen: menu.screen
    visible: menu.progress > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: drawer.area }
    WlrLayershell.namespace: "nusku-battery"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: menu.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property var dev: UPower.displayDevice
    // The laptop's own battery (health, size and model are per battery).
    readonly property var battery: UPower.devices.values.find(d => d.isLaptopBattery) ?? null
    // Other devices with a battery: headsets, mice, keyboards, …
    readonly property var others: UPower.devices.values.filter(d =>
        !d.isLaptopBattery && d.isPresent && d.type !== UPowerDeviceType.LinePower
        && d.type !== UPowerDeviceType.Battery && d.percentage > 0)

    function pct(d) { return d ? Math.round(d.percentage * (d.percentage <= 1 ? 100 : 1)) : 0; }
    readonly property bool charging: dev && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.PendingCharge)
    readonly property bool full: dev && dev.state === UPowerDeviceState.FullyCharged
    readonly property color tint: charging || full ? Colors.teal : pct(dev) <= 10 ? Colors.red : pct(dev) <= 25 ? Colors.yellow : Colors.green

    // "2 h 15 min", "40 min", or "" when UPower doesn't know.
    function duration(s) {
        if (!(s > 0)) return "";
        const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60);
        return h > 0 ? `${h} h ${m} min` : `${m} min`;
    }
    readonly property string status: full ? "Fully charged"
        : charging ? (duration(dev.timeToFull) ? `Charging: full in ${duration(dev.timeToFull)}` : "Charging")
        : dev && dev.state === UPowerDeviceState.Discharging ? (duration(dev.timeToEmpty) ? `${duration(dev.timeToEmpty)} left` : "On battery")
        : "Plugged in"

    function glyph(d) {
        switch (d.type) {
        case UPowerDeviceType.Mouse: return "󰍽";
        case UPowerDeviceType.Keyboard: return "󰌌";
        case UPowerDeviceType.Headset:
        case UPowerDeviceType.Headphones: return "󰋋";
        case UPowerDeviceType.Phone: return "󰄜";
        case UPowerDeviceType.GamingInput: return "󰊴";
        default: return "󰂯";
        }
    }

    Drawer {
        id: drawer
        edge: "top"
        length: 320
        depth: body.implicitHeight + 28
        Behavior on depth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        progress: win.menu.progress
        // Under the battery, kept inside the frame.
        readonly property real edgeRoom: Theme.frame + Theme.frameRadius + length / 2
        centre: win.menu.anchor < 0 ? win.width / 2
            : Math.max(edgeRoom, Math.min(win.width - edgeRoom, win.menu.anchor))

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: win.menu.open = false

            ColumnLayout {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 10

                // The charge.
                RowLayout {
                    spacing: 14
                    Icon {
                        text: win.charging ? "󰂄" : ["󰁺", "󰁼", "󰁾", "󰂀", "󰁹"][Math.min(4, Math.floor(win.pct(win.dev) / 20))]
                        size: 36
                        color: win.tint
                    }
                    ColumnLayout {
                        spacing: 0
                        Label { text: win.pct(win.dev) + "%"; font.pixelSize: 28; font.bold: true; color: win.tint }
                        Label { text: win.status; color: Colors.subtext0; font.pixelSize: Theme.fontSizeSmall }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 8
                    radius: 4
                    color: Colors.surface1
                    Rectangle {
                        width: parent.width * Math.min(1, win.pct(win.dev) / 100)
                        height: parent.height
                        radius: 4
                        color: win.tint
                    }
                }

                // The numbers.
                GridLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 4
                    component Key: Label { color: Colors.subtext0; font.pixelSize: Theme.fontSizeSmall }
                    component Value: Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; font.pixelSize: Theme.fontSizeSmall }

                    Key { visible: win.dev && Math.abs(win.dev.changeRate) > 0.05; text: win.charging ? "Charging at" : "Using" }
                    Value { visible: win.dev && Math.abs(win.dev.changeRate) > 0.05; text: win.dev ? Math.abs(win.dev.changeRate).toFixed(1) + " W" : "" }
                    Key { visible: win.battery !== null; text: "Energy" }
                    Value {
                        visible: win.battery !== null
                        text: win.battery ? `${win.battery.energy.toFixed(1)} of ${win.battery.energyCapacity.toFixed(1)} Wh` : ""
                    }
                    Key { visible: win.battery && win.battery.healthSupported; text: "Health" }
                    Value {
                        visible: win.battery && win.battery.healthSupported
                        text: win.battery ? Math.round(win.battery.healthPercentage) + "% of its design capacity" : ""
                    }
                    Key { visible: win.battery && win.battery.model !== ""; text: "Battery" }
                    Value { visible: win.battery && win.battery.model !== ""; text: win.battery ? win.battery.model : "" }
                }

                // The power profile (as in quick settings).
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 6
                    component Profile: IconButton {
                        property int profile
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 34
                        iconSize: Theme.fontSize
                        active: PowerProfiles.profile === profile
                        onClicked: PowerProfiles.profile = profile
                    }
                    Profile { icon: "󰾆"; profile: PowerProfile.PowerSaver; tooltip: "Power saver: longer battery life, slower" }
                    Profile { icon: "󰾅"; profile: PowerProfile.Balanced; tooltip: "Balanced power profile" }
                    Profile {
                        visible: PowerProfiles.hasPerformanceProfile
                        icon: "󰓅"; profile: PowerProfile.Performance; tooltip: "Performance: fastest, uses more power"
                    }
                }

                // Other devices' batteries.
                Label {
                    visible: win.others.length > 0
                    Layout.topMargin: 6
                    text: "Devices"
                    color: Colors.subtext0
                    font.bold: true
                    font.pixelSize: Theme.fontSizeSmall
                }
                Repeater {
                    model: win.others
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 10
                        Icon { text: win.glyph(parent.modelData); color: Colors.accent }
                        Label { Layout.fillWidth: true; text: parent.modelData.model || "Device" }
                        Label { text: win.pct(parent.modelData) + "%"; color: win.pct(parent.modelData) <= 20 ? Colors.red : Colors.subtext0 }
                    }
                }
            }
        }
    }
}
