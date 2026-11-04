// Clipboard history (cliphist), down from under the bar: type to search, Enter copies the entry
// back, Delete removes it, "Clear" empties the history. Super + V (Nusku's binds).
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.widgets

PickerMenu {
    id: root
    menu: Menus.clipboard
    namespace: "nusku-clipboard"
    placeholder: "Search the clipboard"
    empty: "The clipboard history is empty"
    searchIcon: "󰅌"
    removable: true

    // cliphist list: "ID<TAB>preview", newest first; binary entries read "[[ binary data … ]]".
    function load() {
        lister.running = false;
        lister.running = true;
    }
    onOpened: load()
    onPicked: item => Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "sh", item.line])
    onRemoved: item => {
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist delete', "sh", item.line]);
        items = items.filter(i => i.line !== item.line);
    }

    Process {
        id: lister
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.items = text.split("\n").filter(l => l.includes("\t")).map(line => {
                    const preview = line.slice(line.indexOf("\t") + 1);
                    const binary = /^\[\[ binary data (.*) \]\]$/.exec(preview);
                    return binary
                        ? { line, title: "Image", subtitle: binary[1], icon: "󰋩" }
                        : { line, title: preview.replace(/\s+/g, " ").trim(), icon: "" };
                });
            }
        }
    }

    IconButton {
        implicitHeight: 48
        icon: "󰎟"
        text: "Clear"
        tooltip: "Empty the clipboard history"
        onClicked: {
            Quickshell.execDetached(["cliphist", "wipe"]);
            root.items = [];
        }
    }
}
