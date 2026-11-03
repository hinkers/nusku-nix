// The focused window's title.
import QtQuick
import Quickshell.Wayland
import qs
import qs.widgets

Label {
    readonly property var toplevel: ToplevelManager.activeToplevel
    text: toplevel ? toplevel.title : ""
    color: Colors.subtext1
}
