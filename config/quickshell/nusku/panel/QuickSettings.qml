// The quick settings panel (bar pill, Super + N): Wi-Fi and Bluetooth, the toggles, brightness
// and volume, power profiles, the media player and the notification list. Esc or a click
// outside closes it.
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
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

    // A click anywhere else closes the panel.
    PanelWindow {
        visible: PanelState.open
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "nusku-panel-catcher"
        WlrLayershell.layer: WlrLayer.Top
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: PanelState.open = false
        }
    }

    // The panel hangs off the bar's right end, flush with the screen edge, in the bar's colour:
    // the bar's bottom border runs on as its outline through a concave corner, so the two read
    // as one piece. Opening slides it down out of the bar (PanelState.progress); closing pulls
    // it back up.
    PanelWindow {
        id: panel
        screen: PanelState.screen
        visible: PanelState.progress > 0
        anchors { top: true; right: true; bottom: true }
        // Over the bar: it starts on the bar's bottom border.
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: Theme.panelWidth + fillet
        color: "transparent"
        WlrLayershell.namespace: "nusku-panel"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: PanelState.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        // Only the panel itself takes clicks; the rest of the strip falls through to the catcher.
        mask: Region { item: clipper }
        // Blur behind the panel's own shape (ext-background-effect), not the whole strip.
        BackgroundEffect.blurRegion: Region {
            item: clipper
            bottomLeftRadius: Theme.radiusLarge
        }

        readonly property real fillet: Theme.radiusLarge
        readonly property real top: Theme.barHeight - 2
        readonly property real fullHeight: Math.min(height - top - Theme.gap, body.implicitHeight + 32)
        readonly property real shown: fullHeight * PanelState.progress

        PwObjectTracker {
            objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
        }
        readonly property var sink: Pipewire.defaultAudioSink

        Shape {
            id: outline
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            readonly property real f: panel.fillet
            readonly property real t: panel.top
            readonly property real w: panel.width
            readonly property real b: panel.top + panel.shown
            readonly property real rf: Math.min(f, panel.shown)
            readonly property real rb: Math.min(Theme.radiusLarge, panel.shown / 2)

            // The panel, from the bar's border: concave corner, left side, rounded bottom.
            ShapePath {
                strokeWidth: -1
                fillColor: Theme.barColor
                startX: 0; startY: outline.t
                PathArc { x: outline.f; y: outline.t + outline.rf; radiusX: outline.f; radiusY: outline.rf; direction: PathArc.Clockwise }
                PathLine { x: outline.f; y: outline.b - outline.rb }
                PathArc { x: outline.f + outline.rb; y: outline.b; radiusX: outline.rb; radiusY: outline.rb; direction: PathArc.Counterclockwise }
                PathLine { x: outline.w - outline.rb; y: outline.b }
                PathArc { x: outline.w; y: outline.b - outline.rb; radiusX: outline.rb; radiusY: outline.rb; direction: PathArc.Counterclockwise }
                PathLine { x: outline.w; y: outline.t }
                PathLine { x: 0; y: outline.t }
            }
            // The bar's border carried on round the panel (not along the top, where it joins the
            // bar, nor up the screen edge).
            ShapePath {
                strokeWidth: 2
                strokeColor: Colors.surface0
                fillColor: "transparent"
                startX: 0; startY: outline.t + 1
                PathArc { x: outline.f + 1; y: outline.t + outline.rf; radiusX: outline.f + 1; radiusY: outline.rf - 1; direction: PathArc.Clockwise }
                PathLine { x: outline.f + 1; y: outline.b - outline.rb }
                PathArc { x: outline.f + 1 + outline.rb; y: outline.b - 1; radiusX: outline.rb; radiusY: outline.rb; direction: PathArc.Counterclockwise }
                PathLine { x: outline.w - outline.rb; y: outline.b - 1 }
                PathArc { x: outline.w; y: outline.b - outline.rb; radiusX: outline.rb; radiusY: outline.rb; direction: PathArc.Counterclockwise }
            }
        }

        // What is out so far; the contents slide down inside it.
        Item {
            id: clipper
            x: panel.fillet
            y: panel.top
            width: Theme.panelWidth
            height: panel.shown
            clip: true

            Item {
                id: frame
                width: parent.width
                height: panel.fullHeight
                y: panel.shown - panel.fullHeight
                focus: true
                Keys.onEscapePressed: PanelState.open = false

                ColumnLayout {
                    id: body
                    anchors.fill: parent
                    anchors.margins: 16
                    anchors.topMargin: 18
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
                            onPick: root.run(["nusku-menu-wifi"])
                        }
                        RadioButton {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            icon: Net.btIcon
                            title: "Bluetooth"
                            status: Net.btLabel
                            active: Net.btOn
                            onToggled: Quickshell.execDetached(["nusku-quick", "toggle", "bluetooth"])
                            tooltip: (active ? "Turn Bluetooth off" : "Turn Bluetooth on")
                            pickTooltip: "Connect a Bluetooth device"
                            onPick: root.run(["nusku-menu-bluetooth"])
                        }
                    }

                    // --- Toggles --------------------------------------------------------------
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 4
                        rowSpacing: Theme.gap
                        columnSpacing: Theme.gap
                        component Toggle: IconButton {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: 48
                        }
                        Toggle {
                            icon: "󰂛"; active: Notifs.dnd; onClicked: Notifs.dnd = !Notifs.dnd
                            tooltip: "Do Not Disturb: " + (active ? "on" : "off")
                        }
                        Toggle {
                            icon: "󰖔"; active: Quick.on("night"); onClicked: Quick.toggle("night")
                            tooltip: "Night light: " + (active ? "on" : "off")
                        }
                        Toggle {
                            icon: "󰀝"; active: Quick.on("airplane"); onClicked: Quick.toggle("airplane")
                            tooltip: "Airplane mode: " + (active ? "on" : "off")
                        }
                        Toggle {
                            icon: "󰅶"; active: Quick.on("caffeine"); onClicked: Quick.toggle("caffeine")
                            tooltip: active ? "Keep awake: on (no dimming, locking or screen off)" : "Keep awake: off"
                        }
                        Toggle {
                            icon: panel.sink && panel.sink.audio && panel.sink.audio.muted ? "󰝟" : "󰕾"
                            active: panel.sink && panel.sink.audio ? panel.sink.audio.muted : false
                            onClicked: if (panel.sink && panel.sink.audio) panel.sink.audio.muted = !panel.sink.audio.muted
                            tooltip: active ? "Sound: muted" : "Mute sound"
                        }
                        Toggle {
                            readonly property var source: Pipewire.defaultAudioSource
                            icon: source && source.audio && source.audio.muted ? "󰍭" : "󰍬"
                            active: source && source.audio ? source.audio.muted : false
                            onClicked: if (source && source.audio) source.audio.muted = !source.audio.muted
                            tooltip: active ? "Microphone: muted" : "Mute microphone"
                        }
                        Toggle {
                            icon: "󰹑"; onClicked: root.run(["sh", "-c", "sleep 0.3; niri msg action screenshot"])
                            tooltip: "Screenshot a region"
                        }
                        Toggle {
                            icon: "󰐥"; onClicked: root.run(["nusku-menu-power"])
                            tooltip: "Power menu: lock, log out, suspend, reboot, shut down"
                        }
                    }

                    // --- Sliders --------------------------------------------------------------
                    SliderRow {
                        Layout.fillWidth: true
                        visible: Brightness.available
                        icon: "󰃟"
                        iconTooltip: "Brightness"
                        value: Brightness.value
                        onMoved: v => Brightness.set(v)
                    }
                    SliderRow {
                        Layout.fillWidth: true
                        visible: panel.sink !== null
                        icon: muted ? "󰝟" : "󰕾"
                        muted: panel.sink && panel.sink.audio ? panel.sink.audio.muted : false
                        value: panel.sink && panel.sink.audio ? panel.sink.audio.volume : 0
                        onMoved: v => { if (panel.sink && panel.sink.audio) panel.sink.audio.volume = v; }
                        onIconClicked: if (panel.sink && panel.sink.audio) panel.sink.audio.muted = !panel.sink.audio.muted
                        iconTooltip: (muted ? "Unmute" : "Mute") + (panel.sink ? " " + (panel.sink.description || panel.sink.nickname || "") : "")
                    }

                    // --- Power profiles ------------------------------------------------------
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.gap
                        component Profile: IconButton {
                            property int profile
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: 38
                            iconSize: Theme.fontSize + 2
                            active: PowerProfiles.profile === profile
                            onClicked: PowerProfiles.profile = profile
                        }
                        Profile {
                            icon: "󰾆"; text: "Saver"; profile: PowerProfile.PowerSaver
                            tooltip: "Power saver: longer battery life, slower"
                        }
                        Profile {
                            icon: "󰾅"; text: "Balanced"; profile: PowerProfile.Balanced
                            tooltip: "Balanced power profile"
                        }
                        Profile {
                            visible: PowerProfiles.hasPerformanceProfile
                            icon: "󰓅"; text: "Perf"; profile: PowerProfile.Performance
                            tooltip: "Performance: fastest, uses more power"
                        }
                    }

                    Media { Layout.fillWidth: true }

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
