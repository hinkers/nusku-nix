// System tray icons: click to activate, middle-click for the secondary action, right-click
// (or click, for menu-only items) for the item's menu.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs

Rectangle {
    id: root
    required property var bar
    visible: SystemTray.items.values.length > 0
    implicitHeight: Theme.barHeight - 8
    implicitWidth: row.implicitWidth + 20
    radius: Theme.radius
    color: Colors.surface0

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Repeater {
            model: SystemTray.items
            Item {
                id: item
                required property SystemTrayItem modelData
                implicitWidth: 18
                implicitHeight: 18
                opacity: modelData.status === Status.Passive ? 0.6 : 1

                IconImage {
                    anchors.fill: parent
                    source: item.modelData.icon
                    asynchronous: true
                }
                QsMenuAnchor {
                    id: menu
                    menu: item.modelData.menu
                    anchor.window: root.bar
                    anchor.rect.x: item.mapToItem(null, 0, 0).x
                    anchor.rect.y: root.bar.implicitHeight
                    anchor.rect.width: item.width
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: e => {
                        if (e.button === Qt.MiddleButton) item.modelData.secondaryActivate();
                        else if ((e.button === Qt.RightButton || item.modelData.onlyMenu) && item.modelData.hasMenu) menu.open();
                        else item.modelData.activate();
                    }
                    onWheel: e => item.modelData.scroll(e.angleDelta.y, false)
                }
            }
        }
    }
}
