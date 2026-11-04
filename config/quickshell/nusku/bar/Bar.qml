// The bar along the top of a screen, the frame's top edge: workspaces and the window title on
// the left, the clock in the middle, the tray, battery and quick settings pill on the right.
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

    // The top of the frame round the screen (frame/Frame.qml draws the rest).
    Rectangle {
        anchors.fill: parent
        color: Theme.shellColor
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
        screen: bar.screen
    }

    RowLayout {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 6
        spacing: 4
        Tray { bar: bar }
        Volume { screen: bar.screen }
        Battery { screen: bar.screen }
        QuickPill { screen: bar.screen }
    }
}
