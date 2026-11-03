// The quick settings panel's state: open or not, which screen it is on, and how far it has slid
// out of the bar (`progress`, 0-1, animated; the bar opens a gap in its border while it's out).
// The bar pill opens it on its own screen; Super + N and scripts
// (`qs -c nusku ipc call panel toggle|open|close`) on the screen niri has focused.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool open: false
    // Which page: the toggles ("main"), or the Wi-Fi or Bluetooth list.
    property string page: "main"
    // Back to the toggles once it is all the way in (not while it slides away).
    onProgressChanged: if (progress === 0) page = "main"
    property ShellScreen screen: Quickshell.screens[0] ?? null
    property real progress: open ? 1 : 0
    Behavior on progress {
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    // Open on `s` at `p` (the bar's right-click on the network or Bluetooth icon).
    function openPage(s, p) {
        screen = s;
        open = true;
        page = p;
    }
    function toggleOn(s) {
        if (open && screen === s) { open = false; return; }
        screen = s;
        open = true;
    }
    function toggle() {
        if (open) open = false;
        else openOnFocused();
    }
    // Ask niri which output has focus, then open there (the first screen if it can't say).
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
        target: "panel"
        function toggle(): void { root.toggle(); }
        function open(): void { if (!root.open) root.openOnFocused(); }
        function close(): void { root.open = false; }
        function wifi(): void { if (!root.open) root.openOnFocused(); root.page = "wifi"; }
        function bluetooth(): void { if (!root.open) root.openOnFocused(); root.page = "bluetooth"; }
    }
}
