// The quick settings toggles that nusku-quick knows (night light, airplane mode, caffeine,
// sound and microphone mute), read with `nusku-quick status NAME` and flipped with
// `nusku-quick toggle NAME`. Wi-Fi, Bluetooth and Do Not Disturb are read natively.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property list<string> names: ["night", "airplane", "caffeine", "sound", "mic"]
    property var state: ({})

    function on(name) { return state[name] === true; }

    function refresh() {
        statusProc.running = false;
        statusProc.running = true;
    }
    function toggle(name) {
        // Show the new state at once; the refresh after the command confirms it.
        const s = Object.assign({}, state);
        s[name] = !s[name];
        state = s;
        toggleProc.command = ["nusku-quick", "toggle", name];
        toggleProc.running = true;
    }

    Process {
        id: toggleProc
        onExited: refreshLater.restart()
    }
    // Some toggles take a moment to show (rfkill, a service stopping).
    Timer {
        id: refreshLater
        interval: 300
        onTriggered: root.refresh()
    }

    // One process prints NAME=true|false for every toggle.
    Process {
        id: statusProc
        command: ["sh", "-c", root.names.map(n => `printf '%s=%s\\n' ${n} "$(nusku-quick status ${n})"`).join("; ")]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = {};
                for (const line of text.trim().split("\n")) {
                    const [k, v] = line.split("=");
                    if (k) s[k] = v === "true";
                }
                root.state = s;
            }
        }
    }

    Component.onCompleted: refresh()

    IpcHandler {
        target: "quick"
        function refresh(): void { root.refresh(); }
    }
}
