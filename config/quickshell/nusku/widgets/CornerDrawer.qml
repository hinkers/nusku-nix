// A drawer growing out of the frame's top-right corner: under the bar, against the right
// border, in the shell's colour, with a concave corner where it meets each of them and a
// rounded bottom-left. Fill a window that is anchored top, right and bottom and is
// `windowWidth` wide; set `shown` (its height now, animated by the caller) and put the
// contents inside (they are clipped to what is out, and can slide with `shown`).
import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: root
    anchors.fill: parent

    property real bodyWidth: Theme.panelWidth
    property real shown: 0
    readonly property real windowWidth: Theme.frameRadius + bodyWidth + Theme.frame
    // Where the contents go (also the region that takes clicks).
    readonly property Item area: clip
    default property alias content: clip.data

    Shape {
        id: shape
        anchors.fill: parent
        visible: root.shown > 0
        preferredRendererType: Shape.CurveRenderer
        readonly property real r: Theme.frameRadius
        readonly property real t: Theme.barHeight
        readonly property real x1: r + root.bodyWidth // the right border's inner edge
        readonly property real b: t + root.shown
        // Corners shrink with a drawer that's only just out.
        readonly property real rc: Math.min(r, root.shown)
        readonly property real rb: Math.min(r, root.shown / 2)

        ShapePath {
            strokeWidth: -1
            fillColor: Theme.shellColor
            startX: 0; startY: shape.t
            // Concave corner off the bar.
            PathArc { x: shape.r; y: shape.t + shape.rc; radiusX: shape.r; radiusY: shape.rc; direction: PathArc.Clockwise }
            PathLine { x: shape.r; y: shape.b - shape.rb }
            // Rounded bottom-left.
            PathArc { x: shape.r + shape.rb; y: shape.b; radiusX: shape.rb; radiusY: shape.rb; direction: PathArc.Counterclockwise }
            PathLine { x: shape.x1 - shape.rc; y: shape.b }
            // Concave corner into the right border.
            PathArc { x: shape.x1; y: shape.b + shape.rc; radiusX: shape.rc; radiusY: shape.rc; direction: PathArc.Clockwise }
            PathLine { x: shape.x1; y: shape.t }
            PathLine { x: 0; y: shape.t }
        }
    }

    Item {
        id: clip
        x: Theme.frameRadius
        y: Theme.barHeight
        width: root.bodyWidth
        height: root.shown
        clip: true
    }
}
