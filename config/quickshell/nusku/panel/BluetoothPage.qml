// Quick settings' Bluetooth page: devices (connected first, then paired, then new ones found
// by the scan it runs while open). Pick a device to connect or disconnect it; a new one is
// paired, trusted and connected. Bluetooth Manager (Blueman) is there for anything more.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs
import qs.services
import qs.widgets

ColumnLayout {
    id: root
    spacing: 10

    readonly property var adapter: Net.adapter

    // Look for new devices while the page is showing.
    Binding {
        when: root.adapter !== null
        target: root.adapter
        property: "discovering"
        value: root.visible && Net.btOn
    }

    readonly property var devices: {
        const list = [...Bluetooth.devices.values].filter(d => d.name !== "" && d.name !== d.address.replace(/:/g, "-"));
        const rank = d => d.connected ? 0 : d.paired ? 1 : 2;
        return list.sort((a, b) => rank(a) - rank(b) || a.name.localeCompare(b.name));
    }

    function glyph(icon) {
        if (/headset|headphone|audio-card/.test(icon)) return "󰋋";
        if (/speaker|audio/.test(icon)) return "󰓃";
        if (/keyboard/.test(icon)) return "󰌌";
        if (/mouse/.test(icon)) return "󰍽";
        if (/gaming|joystick/.test(icon)) return "󰊴";
        if (/phone/.test(icon)) return "󰄜";
        if (/computer/.test(icon)) return "󰌢";
        return "󰂯";
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Bluetooth"
        on: Net.btOn
        onToggled: Quickshell.execDetached(["nusku-quick", "toggle", "bluetooth"])
    }

    Label {
        visible: !Net.btOn
        Layout.fillWidth: true
        text: root.adapter ? "Bluetooth is off" : "No Bluetooth adapter"
        color: Colors.overlay1
    }
    Label {
        visible: Net.btOn && root.adapter && root.adapter.discovering
        Layout.fillWidth: true
        text: "Looking for devices…"
        color: Colors.overlay1
        font.pixelSize: Theme.fontSizeSmall
    }

    Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: Net.btOn
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: list
            width: parent.width
            spacing: 6
            Repeater {
                model: root.devices
                Rectangle {
                    id: row
                    required property var modelData
                    // A new device: connect once pairing is done.
                    property bool connectWhenPaired: false
                    readonly property bool busy: modelData.pairing || modelData.state === BluetoothDeviceState.Connecting
                        || modelData.state === BluetoothDeviceState.Disconnecting
                    Layout.fillWidth: true
                    implicitHeight: 52
                    radius: Theme.radius
                    color: modelData.connected ? Theme.alpha(Colors.accent, 0.25) : rowMouse.containsMouse ? Colors.surface1 : Colors.surface0

                    Connections {
                        target: row.modelData
                        function onPairedChanged() {
                            if (row.modelData.paired && row.connectWhenPaired) {
                                row.connectWhenPaired = false;
                                row.modelData.trusted = true;
                                row.modelData.connect();
                            }
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const d = row.modelData;
                            if (row.busy) return;
                            if (d.connected) d.disconnect();
                            else if (d.paired) d.connect();
                            else { row.connectWhenPaired = true; d.pair(); }
                        }
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10
                        Icon { text: root.glyph(row.modelData.icon); color: Colors.accent }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Label { Layout.fillWidth: true; text: row.modelData.name; font.bold: row.modelData.connected }
                            Label {
                                Layout.fillWidth: true
                                text: row.modelData.pairing ? "Pairing…"
                                    : row.modelData.state === BluetoothDeviceState.Connecting ? "Connecting…"
                                    : row.modelData.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…"
                                    : row.modelData.connected ? "Connected" + (row.modelData.batteryAvailable ? ` · ${Math.round(row.modelData.battery * 100)}%` : "")
                                    : row.modelData.paired ? "Paired" : "New: click to pair"
                                color: Colors.subtext0
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }
                }
            }
        }
    }

    IconButton {
        Layout.alignment: Qt.AlignHCenter
        implicitHeight: 34
        icon: "󰒓"
        text: "Bluetooth Manager"
        iconSize: Theme.fontSize
        onClicked: { PanelState.open = false; Quickshell.execDetached(["blueman-manager"]); }
    }
}
