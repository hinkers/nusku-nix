// New notifications, stacked in the top right corner under the bar (newest on top), while the
// quick settings panel is closed (its list shows them anyway).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

PanelWindow {
    id: root
    visible: Notifs.popups.length > 0 && !PanelState.open
    anchors {
        top: true
        right: true
    }
    margins {
        top: Theme.gap
        right: Theme.gap
    }
    // Below the bar, never pushing windows aside.
    exclusiveZone: 0
    implicitWidth: Theme.popupWidth
    implicitHeight: column.implicitHeight
    color: "transparent"
    WlrLayershell.namespace: "nusku-notifications"
    WlrLayershell.layer: WlrLayer.Overlay

    ColumnLayout {
        id: column
        width: parent.width
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
