// The screen's backlight through brightnessctl (absent on desktops: `available` is false).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool available: false
    property real value: 0 // 0-1

    function refresh() {
        readProc.running = false;
        readProc.running = true;
    }
    function set(v) {
        value = Math.min(1, Math.max(0.01, v));
        setProc.command = ["brightnessctl", "-q", "-c", "backlight", "set", Math.round(value * 100) + "%"];
        setProc.running = true;
    }

    // "intel_backlight,backlight,12000,63%,19200"
    Process {
        id: readProc
        command: ["brightnessctl", "-m", "-c", "backlight"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\n")[0].split(",");
                root.available = f.length >= 5;
                if (root.available) root.value = Number(f[2]) / Number(f[4]);
            }
        }
    }
    Process { id: setProc }

    Component.onCompleted: refresh()
}
