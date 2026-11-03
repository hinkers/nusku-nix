// While a menu is out, a click anywhere else on its screen closes it (the menus' windows sit
// above this one and take their own clicks).
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

PanelWindow {
    readonly property var menu: PanelState.open ? PanelState : (Menus.all.find(m => m.open) ?? null)
    visible: menu !== null
    screen: menu ? menu.screen : null
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "nusku-menu-catcher"
    WlrLayershell.layer: WlrLayer.Top
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: Menus.closeAll(null)
    }
}
