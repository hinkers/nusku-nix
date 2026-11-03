// A glyph (click: `iconClicked`, e.g. mute) and a 0-1 slider. `moved(value)` while dragging.
import QtQuick
import QtQuick.Layouts
import qs

RowLayout {
    id: root
    property string icon: ""
    property real value: 0
    property bool muted: false
    property string iconTooltip: ""
    signal moved(real value)
    signal iconClicked()
    spacing: 12

    Rectangle {
        implicitWidth: 36
        implicitHeight: 36
        radius: Theme.radius
        color: iconMouse.containsMouse ? Colors.surface1 : "transparent"
        Icon {
            anchors.centerIn: parent
            text: root.icon
            color: root.muted ? Colors.overlay1 : Colors.accent
        }
        MouseArea {
            id: iconMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.iconClicked()
        }
        Tip {
            text: root.iconTooltip
            hovered: iconMouse.containsMouse
        }
    }

    Item {
        id: track
        Layout.fillWidth: true
        implicitHeight: 24
        readonly property real shown: drag.pressed ? drag.dragValue : root.value

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 8
            radius: 4
            color: Colors.surface1
            Rectangle {
                width: Math.max(height, parent.width * Math.min(1, Math.max(0, track.shown)))
                height: parent.height
                radius: 4
                color: root.muted ? Colors.overlay1 : Colors.accent
            }
        }
        Rectangle {
            x: (track.width - width) * Math.min(1, Math.max(0, track.shown))
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            radius: 8
            color: Colors.text
        }
        MouseArea {
            id: drag
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            property real dragValue: 0
            function update(x) {
                dragValue = Math.min(1, Math.max(0, x / width));
                root.moved(dragValue);
            }
            onPressed: e => update(e.x)
            onPositionChanged: e => { if (pressed) update(e.x); }
            onWheel: e => root.moved(Math.min(1, Math.max(0, root.value + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
    }

    Label {
        Layout.preferredWidth: 40
        horizontalAlignment: Text.AlignRight
        text: Math.round(track.shown * 100) + "%"
        color: Colors.subtext0
        font.pixelSize: Theme.fontSizeSmall
    }
}
