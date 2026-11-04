// The volume menu, down from under the bar's speaker: the output's volume and which output
// (speakers, HDMI, a Bluetooth headset, …), the microphone's volume and which input, and a
// volume for each app playing sound. Sound settings opens pavucontrol for the rest.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import qs
import qs.services
import qs.widgets

PanelWindow {
    id: win
    readonly property var menu: Menus.volume
    screen: menu.screen
    visible: menu.progress > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: drawer.area }
    WlrLayershell.namespace: "nusku-volume"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: menu.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    function volumeOf(n) { return n && n.audio ? n.audio.volume : 0; }
    function mutedOf(n) { return n && n.audio ? n.audio.muted : false; }

    // A section heading.
    component Heading: Label {
        Layout.topMargin: 6
        color: Colors.subtext0
        font.bold: true
        font.pixelSize: Theme.fontSizeSmall
    }
    // A device to pick (output or input): the one in use is marked.
    component DeviceRow: Rectangle {
        id: dev
        required property var node
        property bool current: false
        signal picked()
        Layout.fillWidth: true
        implicitHeight: 34
        radius: Theme.radius
        color: current ? Theme.alpha(Colors.accent, 0.25) : devMouse.containsMouse ? Colors.surface1 : "transparent"
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10
            Icon { text: dev.current ? "󰄬" : ""; size: 14; color: Colors.accent; Layout.preferredWidth: 16 }
            Label { Layout.fillWidth: true; text: Audio.label(dev.node); font.pixelSize: Theme.fontSizeSmall; font.bold: dev.current }
        }
        MouseArea {
            id: devMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: dev.picked()
        }
    }

    // Which output or input: shows the one in use; a click lists them all to pick another.
    component DevicePicker: ColumnLayout {
        id: pk
        required property var nodes
        required property var current
        property bool expanded: false
        signal picked(var node)
        Layout.fillWidth: true
        visible: nodes.length > 1
        spacing: 2

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 34
            radius: Theme.radius
            color: pkMouse.containsMouse ? Colors.surface1 : Colors.surface0
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 10
                Label {
                    Layout.fillWidth: true
                    text: pk.current ? Audio.label(pk.current) : "None"
                    font.pixelSize: Theme.fontSizeSmall
                }
                Icon { text: pk.expanded ? "󰅃" : "󰅀"; size: 14; color: Colors.subtext0 }
            }
            MouseArea {
                id: pkMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: pk.expanded = !pk.expanded
            }
            Tip { text: pk.expanded ? "" : "Choose another"; hovered: pkMouse.containsMouse }
        }
        Repeater {
            model: pk.expanded ? pk.nodes : []
            DeviceRow {
                required property var modelData
                node: modelData
                current: modelData === pk.current
                onPicked: { pk.picked(modelData); pk.expanded = false; }
            }
        }
    }

    // Both pickers start folded each time the menu opens.
    Connections {
        target: win.menu
        function onOpenChanged() {
            if (win.menu.open) { outputs.expanded = false; inputs.expanded = false; }
        }
    }

    Drawer {
        id: drawer
        edge: "top"
        length: 360
        depth: Math.min(win.height - Theme.barHeight - Theme.frame - 2 * Theme.frameRadius, body.implicitHeight + 28)
        Behavior on depth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        progress: win.menu.progress
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
                spacing: 6

                // --- Output -------------------------------------------------------------
                Heading { Layout.topMargin: 0; text: "Output" }
                SliderRow {
                    Layout.fillWidth: true
                    icon: Audio.icon
                    iconTooltip: win.mutedOf(Audio.sink) ? "Unmute" : "Mute"
                    muted: win.mutedOf(Audio.sink)
                    value: win.volumeOf(Audio.sink)
                    onMoved: v => Audio.setVolume(Audio.sink, v)
                    onIconClicked: Audio.toggleMute(Audio.sink)
                }
                DevicePicker {
                    id: outputs
                    nodes: Audio.sinks
                    current: Audio.sink
                    onPicked: node => Pipewire.preferredDefaultAudioSink = node
                }

                // --- Input --------------------------------------------------------------
                Heading { visible: Audio.source !== null; text: "Microphone" }
                SliderRow {
                    Layout.fillWidth: true
                    visible: Audio.source !== null
                    icon: win.mutedOf(Audio.source) ? "󰍭" : "󰍬"
                    iconTooltip: win.mutedOf(Audio.source) ? "Unmute the microphone" : "Mute the microphone"
                    muted: win.mutedOf(Audio.source)
                    value: win.volumeOf(Audio.source)
                    onMoved: v => Audio.setVolume(Audio.source, v)
                    onIconClicked: Audio.toggleMute(Audio.source)
                }
                DevicePicker {
                    id: inputs
                    visible: Audio.source !== null && nodes.length > 1
                    nodes: Audio.sources
                    current: Audio.source
                    onPicked: node => Pipewire.preferredDefaultAudioSource = node
                }

                // --- Apps ---------------------------------------------------------------
                Heading { visible: Audio.streams.length > 0; text: "Apps" }
                Repeater {
                    model: Audio.streams
                    ColumnLayout {
                        id: app
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 0
                        Label {
                            Layout.fillWidth: true
                            Layout.leftMargin: 4
                            text: Audio.label(app.modelData) + ((app.modelData.properties ?? {})["media.name"] ? " · " + app.modelData.properties["media.name"] : "")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Colors.subtext1
                        }
                        SliderRow {
                            Layout.fillWidth: true
                            icon: win.mutedOf(app.modelData) ? "󰝟" : "󰕾"
                            iconTooltip: win.mutedOf(app.modelData) ? "Unmute" : "Mute"
                            muted: win.mutedOf(app.modelData)
                            value: win.volumeOf(app.modelData)
                            onMoved: v => Audio.setVolume(app.modelData, v)
                            onIconClicked: Audio.toggleMute(app.modelData)
                        }
                    }
                }

                IconButton {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 6
                    implicitHeight: 32
                    icon: "󰒓"
                    text: "Sound settings"
                    iconSize: Theme.fontSize
                    onClicked: { win.menu.open = false; Quickshell.execDetached(["pavucontrol"]); }
                }
            }
        }
    }
}
