// One menu's state (Menus.qml has one per menu): open or not, on which screen, and how far its
// drawer is out (`progress`, 0-1, animated). `qs -c nusku ipc call <name> toggle|open|close`
// opens it on the screen niri has focused.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    required property string name
    property bool open: false
    property ShellScreen screen: Quickshell.screens[0] ?? null
    property real progress: open ? 1 : 0
    Behavior on progress {
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }
    // Opening one menu closes the others.
    signal opened()
    onOpenChanged: if (open) opened()

    function toggleOn(s) {
        if (open && screen === s) { open = false; return; }
        screen = s;
        open = true;
    }
    function toggle() {
        if (open) open = false;
        else openOnFocused();
    }
    function openOnFocused() {
        focused.running = false;
        focused.running = true;
    }
    Process {
        id: focused
        command: ["niri", "msg", "--json", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: {
                let name = "";
                try { name = JSON.parse(text).name; } catch (e) {}
                root.screen = Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0] ?? null;
                root.open = true;
            }
        }
    }

    IpcHandler {
        target: root.name
        function toggle(): void { root.toggle(); }
        function open(): void { if (!root.open) root.openOnFocused(); }
        function close(): void { root.open = false; }
    }
}
