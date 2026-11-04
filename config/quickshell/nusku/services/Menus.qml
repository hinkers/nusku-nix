// The menus that grow out of the frame, besides quick settings (PanelState): the calendar
// (from under the clock), the app launcher, clipboard, wallpaper and keybind menus (down from
// under the bar too) and the power menu (in from the right). One is open at a time, quick
// settings too.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root
    readonly property DrawerState calendar: DrawerState { name: "calendar"; onOpened: root.closeAll(this) }
    readonly property DrawerState launcher: DrawerState { name: "launcher"; onOpened: root.closeAll(this) }
    readonly property DrawerState session: DrawerState { name: "session"; onOpened: root.closeAll(this) }
    // Where the launcher is: clipboard history, the wallpaper picker, the keybind search.
    readonly property DrawerState clipboard: DrawerState { name: "clipboard"; onOpened: root.closeAll(this) }
    readonly property DrawerState wallpaper: DrawerState { name: "wallpaper"; onOpened: root.closeAll(this) }
    readonly property DrawerState keybinds: DrawerState { name: "keybinds"; onOpened: root.closeAll(this) }
    // Down from under the bar's battery: charge, time left, health, other devices' batteries.
    readonly property DrawerState battery: DrawerState { name: "battery"; onOpened: root.closeAll(this) }
    // Down from under the bar's speaker: outputs, inputs and each app's volume.
    readonly property DrawerState volume: DrawerState { name: "volume"; onOpened: root.closeAll(this) }
    readonly property list<DrawerState> all: [calendar, launcher, session, clipboard, wallpaper, keybinds, battery, volume]
    readonly property bool anyOpen: PanelState.open || all.some(m => m.open)

    // Close every menu but `keep` (null: all of them).
    function closeAll(keep) {
        for (const m of all) if (m !== keep) m.open = false;
        if (keep !== PanelState) PanelState.open = false;
    }

    Connections {
        target: PanelState
        function onOpenChanged() { if (PanelState.open) root.closeAll(PanelState); }
    }
}
