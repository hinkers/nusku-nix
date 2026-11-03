// New notifications grow out of the frame's top-right corner, where the bar meets the right
// border (widgets/CornerDrawer.qml), newest on top; the drawer grows and shrinks as they come
// and go. Not while the quick settings panel is out (its list shows them anyway).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.widgets

PanelWindow {
    id: root
    readonly property bool wanted: Notifs.popups.length > 0 && PanelState.progress === 0
    visible: drawer.shown > 0
    screen: PanelState.screen
    anchors {
        top: true
        right: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: drawer.windowWidth
    color: "transparent"
    mask: Region { item: drawer.area }
    WlrLayershell.namespace: "nusku-notifications"
    WlrLayershell.layer: WlrLayer.Overlay

    CornerDrawer {
        id: drawer
        bodyWidth: Theme.popupWidth
        shown: root.wanted ? column.implicitHeight + 2 * Theme.gap : 0
        Behavior on shown {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        // Pinned to the bottom of what is out, so the cards slide down out of the bar.
        ColumnLayout {
            id: column
            x: Theme.gap
            width: parent.width - 2 * Theme.gap
            y: drawer.shown - implicitHeight - Theme.gap
            spacing: Theme.gap
            Repeater {
                model: Notifs.popups.slice(0, 5)
                NotificationCard {
                    required property var modelData
                    Layout.fillWidth: true
                    notification: modelData
                    popup: true
                }
            }
        }
    }
}
