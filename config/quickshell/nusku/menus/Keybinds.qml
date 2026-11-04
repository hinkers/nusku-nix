// The keybind search, down from under the bar: every niri bind with what it does (its
// hotkey-overlay-title) and its keys. Type to search, Enter runs the bind. Super + /.
// nusku-menu-keybinds reads niri's config (config.kdl and its includes) and runs the picks.
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.widgets

PickerMenu {
    id: root
    menu: Menus.keybinds
    namespace: "nusku-keybinds"
    placeholder: "Search keybinds"
    empty: "No keybinds match"
    searchIcon: "󰌌"
    rows: 9

    onOpened: {
        lister.running = false;
        lister.running = true;
    }
    onPicked: item => {
        if (item.runnable) Quickshell.execDetached(["nusku-menu-keybinds", "--run", String(item.index)]);
    }

    // nusku-menu-keybinds --list: INDEX<TAB>DESCRIPTION<TAB>KEYS<TAB>RUNNABLE
    Process {
        id: lister
        command: ["nusku-menu-keybinds", "--list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.items = text.split("\n").filter(l => l !== "").map(l => {
                    const [index, title, keys, runnable] = l.split("\t");
                    return { index: Number(index), title, keys, runnable: runnable === "1" };
                });
            }
        }
    }
}
