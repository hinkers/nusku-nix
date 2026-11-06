// The power actions: lock, log out, suspend, reboot, shut down. The power menu
// (menus/Session.qml) shows them as buttons; the app launcher lists them when you search.
// `confirm` ones need a second click or Enter.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property var actions: [
        { icon: "󰌾", text: "Lock", keywords: "lock screen", confirm: false, cmd: ["hyprlock"] },
        { icon: "󰍃", text: "Log out", keywords: "logout sign out exit quit session", confirm: true, cmd: ["niri", "msg", "action", "quit", "--skip-confirmation"] },
        { icon: "󰤄", text: "Suspend", keywords: "sleep", confirm: false, cmd: ["systemctl", "suspend"] },
        { icon: "󰜉", text: "Reboot", keywords: "restart", confirm: true, cmd: ["systemctl", "reboot"] },
        { icon: "󰐥", text: "Shut down", keywords: "shutdown power off poweroff turn off", confirm: true, cmd: ["systemctl", "poweroff"] },
    ]
}
