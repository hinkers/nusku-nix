// The bar along the top of a screen: workspaces and the window title on the left, the clock in
// the middle, the tray, battery and quick settings pill on the right.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.widgets

PanelWindow {
    id: bar
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: "transparent"
    WlrLayershell.namespace: "nusku-bar"
    WlrLayershell.layer: WlrLayer.Top

    Rectangle {
        anchors.fill: parent
        color: Theme.barColor
        // The bottom border; while the quick settings panel is out on this screen it stops where
        // the panel hangs off the bar, and the panel's own outline carries it on.
        Rectangle {
            anchors.bottom: parent.bottom
            height: 2
            color: Colors.surface0
            width: PanelState.progress > 0 && PanelState.screen === bar.screen
                ? parent.width - Theme.panelWidth - Theme.radiusLarge : parent.width
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: clock.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 6
        anchors.rightMargin: 12
        spacing: 12
        Workspaces { screen: bar.screen }
        WindowTitle {
            Layout.fillWidth: true
            Layout.maximumWidth: 600
        }
    }

    Clock {
        id: clock
        anchors.centerIn: parent
    }

    RowLayout {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 6
        spacing: 4
        Tray { bar: bar }
        Battery {}
        QuickPill { screen: bar.screen }
    }
}
