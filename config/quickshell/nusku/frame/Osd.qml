// The volume / brightness pop-up: a slim gauge in from the right border (widgets/Drawer.qml)
// for a moment after a change. Volume and mute changes show it by themselves (not at login).
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
    screen: PanelState.screen
    visible: Osd.progress > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "nusku-osd"
    WlrLayershell.layer: WlrLayer.Overlay

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [win.sink, win.source] }

    // Changes in the first seconds are PipeWire settling in, not the user.
    property bool ready: false
    Timer { running: true; interval: 3000; onTriggered: win.ready = true }
    Connections {
        target: win.sink ? win.sink.audio : null
        // Not while the volume menu is out: it shows the same thing.
        function onVolumeChanged() { if (win.ready && !Menus.volume.open) Osd.show("volume"); }
        function onMutedChanged() { if (win.ready && !Menus.volume.open) Osd.show("volume"); }
    }
    Connections {
        target: win.source ? win.source.audio : null
        function onMutedChanged() { if (win.ready && !Menus.volume.open) Osd.show("mic"); }
    }

    readonly property bool muted: Osd.kind === "volume" ? (sink && sink.audio ? sink.audio.muted : false)
        : Osd.kind === "mic" ? (source && source.audio ? source.audio.muted : false) : false
    readonly property real value: Osd.kind === "brightness" ? Brightness.value
        : Osd.kind === "mic" ? (source && source.audio ? source.audio.volume : 0)
        : (sink && sink.audio ? sink.audio.volume : 0)
    readonly property string glyph: Osd.kind === "brightness" ? "󰃟"
        : Osd.kind === "mic" ? (muted ? "󰍭" : "󰍬")
        : muted ? "󰝟" : value < 0.34 ? "󰕿" : value < 0.67 ? "󰖀" : "󰕾"

    Drawer {
        id: drawer
        edge: "right"
        length: 220
        depth: 60
        progress: Osd.progress

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: win.muted ? "off" : Math.round(win.value * 100)
                color: Colors.subtext0
                font.pixelSize: Theme.fontSizeSmall
            }
            // The gauge, filling from the bottom.
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: true
                implicitWidth: 10
                radius: 5
                color: Colors.surface1
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(width, parent.height * Math.min(1, win.value))
                    radius: 5
                    color: win.muted ? Colors.overlay1 : Colors.accent
                    Behavior on height { NumberAnimation { duration: 120 } }
                }
            }
            Icon {
                Layout.alignment: Qt.AlignHCenter
                text: win.glyph
                color: win.muted ? Colors.overlay1 : Colors.accent
            }
        }
    }
}
