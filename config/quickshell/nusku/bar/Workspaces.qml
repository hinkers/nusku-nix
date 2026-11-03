// This screen's niri workspaces (ext-workspace), in order; click one to go there.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.WindowManager
import qs
import qs.widgets

RowLayout {
    id: root
    required property ShellScreen screen
    spacing: 4

    readonly property var sets: {
        const p = WindowManager.screenProjection(root.screen);
        const list = p ? [...p.windowsets] : [];
        return list.filter(w => w.shouldDisplay)
            .sort((a, b) => (a.coordinates[1] ?? 0) - (b.coordinates[1] ?? 0));
    }

    Repeater {
        model: root.sets
        Rectangle {
            id: button
            required property var modelData
            implicitHeight: Theme.barHeight - 10
            implicitWidth: Math.max(implicitHeight + 4, label.implicitWidth + 20)
            radius: Theme.radius
            color: modelData.urgent ? Colors.red
                : modelData.active ? Colors.accent
                : mouse.containsMouse ? Colors.surface0 : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.animMs } }

            Label {
                id: label
                anchors.centerIn: parent
                text: button.modelData.name
                color: button.modelData.active || button.modelData.urgent ? Colors.base : Colors.subtext0
                font.bold: button.modelData.active
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (button.modelData.canActivate) button.modelData.activate()
            }
        }
    }
}
