// The volume and brightness pop-up (frame/Osd.qml): which one, and whether it's out. Volume and
// mute changes show it by themselves; the brightness keys call
// `qs -c nusku ipc call osd brightness` (the backlight doesn't announce changes).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string kind: "volume" // volume | mic | brightness
    property bool shown: false
    property real progress: shown ? 1 : 0
    Behavior on progress {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    function show(k) {
        kind = k;
        shown = true;
        hide.restart();
    }
    Timer { id: hide; interval: 1500; onTriggered: root.shown = false }

    IpcHandler {
        target: "osd"
        function brightness(): void { Brightness.refresh(); root.show("brightness"); }
        function volume(): void { root.show("volume"); }
    }
}
