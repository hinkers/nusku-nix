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

    // The top-left corner: a click there opens (or closes) niri's overview. The pointer stops at
    // the screen's edge, so flicking it into the corner and clicking lands here.
    MouseArea {
        id: corner
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 6
        onClicked: Quickshell.execDetached(["niri", "msg", "action", "toggle-overview"])
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: centre.left
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

    // The middle: the clock (and calendar) stays centred; the app launcher on its left, what's
    // playing on its right.
    Clock {
        id: clock
        anchors.centerIn: parent
        screen: bar.screen
    }
    LauncherButton {
        id: centre
        anchors.right: clock.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        screen: bar.screen
    }
    MediaButton {
        anchors.left: clock.right
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
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
