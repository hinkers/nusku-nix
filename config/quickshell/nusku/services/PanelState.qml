// Which pop-out is open: the quick settings panel (bar pill, Super + N). Other parts can call
// `qs -c nusku ipc call panel toggle|open|close`.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool open: false

    function toggle() { open = !open; }

    IpcHandler {
        target: "panel"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open = true; }
        function close(): void { root.open = false; }
    }
}
