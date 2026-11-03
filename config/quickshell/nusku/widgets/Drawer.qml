// A drawer growing out of the frame along one edge: from under the bar ("top"), up from the
// bottom border ("bottom") or in from the right border ("right"). It is in the shell's colour,
// with a concave corner on each side where it meets the frame and rounded outer corners.
// Fill a full-screen window; `length` is its size along the edge, `depth` how far it comes out
// when fully open, `progress` (0-1, animated by the caller) how far it is out now, and
// `centre` where along the edge it sits (default: the middle). The contents go inside: they
// fill `depth` and are clipped to what is out, sliding out with the drawer's leading edge.
import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: root
    anchors.fill: parent

    property string edge: "top"
    property real length: 400
    property real depth: 300
    property real progress: 0
    property real centre: edge === "right"
        ? Theme.barHeight + (height - Theme.barHeight - Theme.frame) / 2
        : width / 2
    readonly property real shown: depth * progress
    readonly property Item area: clip
    default property alias content: inner.data

    readonly property real r: Theme.frameRadius
    readonly property bool vertical: edge === "right"

    // The shape, drawn as a "top" drawer in its own coordinates (u along the edge, v outwards)
    // and turned into place for the other edges.
    Item {
        id: box
        visible: root.shown > 0
        width: root.length + 2 * root.r
        height: root.depth + root.r
        x: root.edge === "right" ? 0 : root.centre - width / 2
        y: root.edge === "top" ? Theme.barHeight
            : root.edge === "bottom" ? root.height - Theme.frame - height : 0
        transform: [
            // "bottom": flipped, so it grows upwards from the bottom border.
            Scale { origin.y: box.height / 2; yScale: root.edge === "bottom" ? -1 : 1 },
            // "right": turned a quarter so it grows leftwards from the right border.
            Rotation { angle: root.edge === "right" ? 90 : 0 },
            Translate {
                x: root.edge === "right" ? root.width - Theme.frame : 0
                y: root.edge === "right" ? root.centre - box.width / 2 : 0
            }
        ]

        Shape {
            id: sh
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            readonly property real r: root.r
            readonly property real s: root.shown
            readonly property real l: root.length
            readonly property real rc: Math.min(r, s)       // concave corners into the frame
            readonly property real rb: Math.min(r, s / 2)   // rounded outer corners

            ShapePath {
                strokeWidth: -1
                fillColor: Theme.shellColor
                startX: 0; startY: 0
                PathArc { x: root.r; y: sh.rc; radiusX: root.r; radiusY: sh.rc; direction: PathArc.Clockwise }
                PathLine { x: root.r; y: sh.s - sh.rb }
                PathArc { x: root.r + sh.rb; y: sh.s; radiusX: sh.rb; radiusY: sh.rb; direction: PathArc.Counterclockwise }
                PathLine { x: root.r + sh.l - sh.rb; y: sh.s }
                PathArc { x: root.r + sh.l; y: sh.s - sh.rb; radiusX: sh.rb; radiusY: sh.rb; direction: PathArc.Counterclockwise }
                PathLine { x: root.r + sh.l; y: sh.rc }
                PathArc { x: 2 * root.r + sh.l; y: 0; radiusX: root.r; radiusY: sh.rc; direction: PathArc.Clockwise }
                PathLine { x: 0; y: 0 }
            }
        }
    }

    // What is out so far, in screen orientation; the contents slide with the leading edge.
    Item {
        id: clip
        clip: true
        x: root.edge === "right" ? root.width - Theme.frame - root.shown : root.centre - root.length / 2
        y: root.edge === "top" ? Theme.barHeight
            : root.edge === "bottom" ? root.height - Theme.frame - root.shown
            : root.centre - root.length / 2
        width: root.vertical ? root.shown : root.length
        height: root.vertical ? root.length : root.shown

        Item {
            id: inner
            width: root.vertical ? root.depth : root.length
            height: root.vertical ? root.length : root.depth
            x: 0
            y: root.edge === "top" ? root.shown - root.depth : 0
        }
    }
}
