// The frame round a screen: the bar is its top edge, this draws a slim border down the left,
// right and bottom with rounded inner corners, and keeps windows inside it. The quick settings
// panel and the notification pop-ups grow out of its top-right corner (widgets/CornerDrawer.qml).
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs

Scope {
    id: root
    required property ShellScreen screen

    // Room for the borders: windows are laid out inside them (the bar reserves the top).
    component Zone: PanelWindow {
        screen: root.screen
        color: "transparent"
        mask: Region {}
        exclusiveZone: Theme.frame
        implicitWidth: Theme.frame
        implicitHeight: Theme.frame
        WlrLayershell.namespace: "nusku-frame-zone"
    }
    Zone { anchors { left: true; top: true; bottom: true } }
    Zone { anchors { right: true; top: true; bottom: true } }
    Zone { anchors { bottom: true; left: true; right: true } }

    // The border itself: everything below the bar, minus the rounded inside. Takes no input.
    PanelWindow {
        id: win
        screen: root.screen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        WlrLayershell.namespace: "nusku-frame"
        WlrLayershell.layer: WlrLayer.Top

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillColor: Theme.shellColor
                fillRule: ShapePath.OddEvenFill
                PathRectangle { x: 0; y: Theme.barHeight; width: win.width; height: win.height - Theme.barHeight }
                PathRectangle {
                    x: Theme.frame
                    y: Theme.barHeight
                    width: win.width - 2 * Theme.frame
                    height: win.height - Theme.barHeight - Theme.frame
                    radius: Theme.frameRadius
                }
            }
        }
    }
}
