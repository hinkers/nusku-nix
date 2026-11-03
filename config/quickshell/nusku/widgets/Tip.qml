// A tooltip for its parent after a short hover: put one inside a button and bind `hovered`.
// When it shows it moves to the top of the window, so later rows or a scrolling list never
// cover or clip it, and it stays inside the window (above its parent near the bottom).
import QtQuick
import qs

Rectangle {
    id: tip
    property string text: ""
    property bool hovered: false
    property bool shown: false
    // The item it describes: the parent it was declared in.
    property Item target: null

    Component.onCompleted: target = parent

    onHoveredChanged: {
        if (hovered) delay.restart();
        else { delay.stop(); shown = false; }
    }
    Timer {
        id: delay
        interval: 500
        onTriggered: {
            tip.place();
            tip.shown = true;
        }
    }

    function place() {
        if (!target) return;
        let top = target;
        while (top.parent) top = top.parent;
        if (parent !== top) parent = top;
        const p = target.mapToItem(top, 0, 0);
        x = Math.max(4, Math.min(p.x + (target.width - width) / 2, top.width - 4 - width));
        const below = p.y + target.height + 6;
        y = below + height > top.height - 4 ? p.y - height - 6 : below;
    }

    visible: opacity > 0
    opacity: shown && text !== "" ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
    z: 1000
    width: label.width + 18
    height: label.implicitHeight + 10
    radius: 6
    color: Colors.crust
    border.width: 1
    border.color: Colors.surface1

    // Long ones wrap rather than run past the window's edge.
    Text {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, 280)
        text: tip.text
        wrapMode: Text.Wrap
        font.family: Theme.font
        font.pixelSize: Theme.fontSizeSmall
        color: Colors.text
    }
}
