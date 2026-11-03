// A Nerd Font glyph.
import QtQuick
import qs

Text {
    property real size: Theme.fontSize + 2
    font.family: Theme.font
    font.pixelSize: size
    color: Colors.text
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
