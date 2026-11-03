// Text in the shell's font.
import QtQuick
import qs

Text {
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    color: Colors.text
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
