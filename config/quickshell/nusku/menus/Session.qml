// The power menu, in from the right border: lock, log out, suspend, reboot, shut down. Log out,
// reboot and shut down ask for a second click (the button turns red for a few seconds).
// Keys: up/down, Enter, Esc. Super + Escape (or Super + X), or the quick settings power button.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.widgets

PanelWindow {
    id: win
    readonly property var menu: Menus.session
    screen: menu.screen
    visible: menu.progress > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: drawer.area }
    WlrLayershell.namespace: "nusku-session"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: menu.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var actions: [
        { icon: "󰌾", text: "Lock", confirm: false, cmd: ["hyprlock"] },
        { icon: "󰍃", text: "Log out", confirm: true, cmd: ["niri", "msg", "action", "quit", "--skip-confirmation"] },
        { icon: "󰤄", text: "Suspend", confirm: false, cmd: ["systemctl", "suspend"] },
        { icon: "󰜉", text: "Reboot", confirm: true, cmd: ["systemctl", "reboot"] },
        { icon: "󰐥", text: "Shut down", confirm: true, cmd: ["systemctl", "poweroff"] },
    ]
    property int current: 0
    property int armed: -1 // the action waiting for its second click

    function run(i) {
        const a = actions[i];
        if (a.confirm && armed !== i) {
            armed = i;
            disarm.restart();
            return;
        }
        armed = -1;
        menu.open = false;
        Quickshell.execDetached(a.cmd);
    }
    Timer { id: disarm; interval: 4000; onTriggered: win.armed = -1 }
    Connections {
        target: win.menu
        function onOpenChanged() {
            if (win.menu.open) { win.current = 0; win.armed = -1; keys.forceActiveFocus(); }
        }
    }

    Drawer {
        id: drawer
        edge: "right"
        length: column.implicitHeight + 32
        depth: 64 + 32
        progress: win.menu.progress

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: win.menu.open = false
            Keys.onUpPressed: win.current = (win.current + win.actions.length - 1) % win.actions.length
            Keys.onDownPressed: win.current = (win.current + 1) % win.actions.length
            Keys.onReturnPressed: win.run(win.current)
            Keys.onEnterPressed: win.run(win.current)

            ColumnLayout {
                id: column
                anchors.centerIn: parent
                spacing: 10
                Repeater {
                    model: win.actions
                    IconButton {
                        required property var modelData
                        required property int index
                        implicitWidth: 64
                        implicitHeight: 64
                        radius: Theme.radiusLarge
                        icon: modelData.icon
                        iconSize: 26
                        active: win.current === index
                        color: win.armed === index ? Colors.red
                            : active ? Colors.accent : (hovered ? Colors.surface1 : Colors.surface0)
                        tooltip: win.armed === index ? "Click again to " + modelData.text.toLowerCase() : modelData.text
                        onClicked: win.run(index)
                        onHoveredChanged: if (hovered) win.current = index
                    }
                }
            }
        }
    }
}
