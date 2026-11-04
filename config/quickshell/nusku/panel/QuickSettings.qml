// The quick settings panel (bar pill, Super + N): Wi-Fi and Bluetooth (with their pages), the
// toggles, brightness and the notification list. Volume, media, power profiles and the power
// menu have their own places now (the bar's speaker, media button and battery; Super + Escape).
// Esc or a click outside closes it.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.widgets
import qs.notifications

Scope {
    id: root

    // Every time it opens: read the states that aren't pushed to us.
    Connections {
        target: PanelState
        function onOpenChanged() {
            if (PanelState.open) {
                Quick.refresh();
                Brightness.refresh();
                // They're all in the list now: don't pop them up again once it closes.
                Notifs.popups = [];
            }
        }
    }

    function run(cmd) {
        PanelState.open = false;
        Quickshell.execDetached(cmd);
    }

    // The panel grows out of the frame's top-right corner, where the bar meets the right border
    // (widgets/CornerDrawer.qml): it slides down out of the bar as it opens
    // (PanelState.progress) and back up as it closes.
    PanelWindow {
        id: panel
        screen: PanelState.screen
        visible: PanelState.progress > 0
        anchors { top: true; right: true; bottom: true }
        // Over the frame: it is drawn from the bar's lower edge, against the right border.
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: drawer.windowWidth
        color: "transparent"
        WlrLayershell.namespace: "nusku-panel"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: PanelState.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        // Only the panel itself takes clicks; the rest of the strip falls through to the catcher.
        mask: Region { item: drawer.area }

        // The Wi-Fi and Bluetooth pages get a fixed height (their lists scroll).
        readonly property real maxHeight: height - Theme.barHeight - Theme.frame - Theme.frameRadius
        property real fullHeight: Math.min(maxHeight, PanelState.page === "main" ? body.implicitHeight + 32 : 520)
        Behavior on fullHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }


        CornerDrawer {
            id: drawer
            bodyWidth: Theme.panelWidth
            shown: panel.fullHeight * PanelState.progress

            // The contents slide down inside what is out so far.
            Item {
                id: frame
                width: parent.width
                height: panel.fullHeight
                y: drawer.shown - panel.fullHeight
                focus: true
                Keys.onEscapePressed: PanelState.open = false

                WifiPage {
                    anchors.fill: parent
                    anchors.margins: 16
                    anchors.topMargin: 12
                    visible: PanelState.page === "wifi"
                }
                BluetoothPage {
                    anchors.fill: parent
                    anchors.margins: 16
                    anchors.topMargin: 12
                    visible: PanelState.page === "bluetooth"
                }

                ColumnLayout {
                    id: body
                    visible: PanelState.page === "main"
                    anchors.fill: parent
                    anchors.margins: 16
                    anchors.topMargin: 12
                    spacing: 12

                    // --- Wi-Fi and Bluetooth --------------------------------------------------
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.gap
                        RadioButton {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            icon: Net.wifiOn ? "󰖩" : "󰖪"
                            title: "Wi-Fi"
                            status: Net.wifiLabel
                            active: Net.wifiOn
                            onToggled: Quickshell.execDetached(["nusku-quick", "toggle", "wifi"])
                            tooltip: (active ? "Turn Wi-Fi off" : "Turn Wi-Fi on")
                            pickTooltip: "Choose a Wi-Fi network"
                            onPick: PanelState.page = "wifi"
                        }
                        RadioButton {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            icon: Net.btIcon
                            title: "Bluetooth"
                            status: Net.btLabel
                            active: Net.btOn
                            onToggled: Quickshell.execDetached(["nusku-quick", "toggle", "bluetooth"])
                            // With several connected the button shows a count: name them here.
                            tooltip: (active ? "Turn Bluetooth off" : "Turn Bluetooth on")
                                + (Net.btConnected.length > 1 ? " (connected: " + Net.btConnected.map(d => d.name).join(", ") + ")" : "")
                            pickTooltip: "Connect a Bluetooth device"
                            onPick: PanelState.page = "bluetooth"
                        }
                    }

                    // --- Toggles --------------------------------------------------------------
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: Theme.gap
                        columnSpacing: Theme.gap
                        component Tile: ToggleTile {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                        }
                        Tile {
                            icon: "󰂛"; title: "Do Not Disturb"; active: Notifs.dnd
                            onClicked: Notifs.dnd = !Notifs.dnd
                            tooltip: active ? "Notifications don't pop up (they still collect below)" : ""
                        }
                        Tile {
                            icon: "󰖔"; title: "Night light"; active: Quick.on("night")
                            onClicked: Quick.toggle("night")
                            tooltip: "A warmer screen"
                        }
                        Tile {
                            icon: "󰀝"; title: "Airplane mode"; active: Quick.on("airplane")
                            onClicked: Quick.toggle("airplane")
                            tooltip: "Every radio off: Wi-Fi and Bluetooth"
                        }
                        Tile {
                            icon: "󰅶"; title: "Keep awake"; active: Quick.on("caffeine")
                            onClicked: Quick.toggle("caffeine")
                            tooltip: "No dimming, locking or screen off while it's on"
                        }
                    }

                    // --- Brightness -----------------------------------------------------------
                    SliderRow {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        visible: Brightness.available
                        icon: "󰃟"
                        iconTooltip: "Brightness"
                        value: Brightness.value
                        onMoved: v => Brightness.set(v)
                    }

                    // --- Notifications -------------------------------------------------------
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        Label {
                            Layout.fillWidth: true
                            text: Notifs.count > 0 ? `Notifications (${Notifs.count})` : "Notifications"
                            font.bold: true
                            color: Colors.subtext1
                        }
                        IconButton {
                            visible: Notifs.count > 0
                            implicitHeight: 30
                            icon: "󰎟"
                            text: "Clear all"
                            tooltip: "Dismiss every notification"
                            iconSize: Theme.fontSize
                            onClicked: Notifs.clearAll()
                        }
                    }
                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: Notifs.count > 0 ? 80 : 40
                        Layout.preferredHeight: list.implicitHeight
                        contentHeight: list.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: list
                            width: parent.width
                            spacing: Theme.gap
                            Label {
                                visible: Notifs.count === 0
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                horizontalAlignment: Text.AlignHCenter
                                text: Notifs.dnd ? "Do Not Disturb is on" : "No notifications"
                                color: Colors.overlay1
                            }
                            Repeater {
                                model: Notifs.list
                                NotificationCard {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    notification: modelData
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
