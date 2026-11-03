// Nusku shell - sizes, fonts and helpers shared by every part. Colours are in Colors.qml
// (generated from lib/palette.nix with the host's accent).
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 14
    readonly property int fontSizeSmall: 12
    readonly property int fontSizeLarge: 16

    readonly property int barHeight: 34
    readonly property int radius: 8
    readonly property int radiusLarge: 14
    readonly property int gap: 8
    readonly property int panelWidth: 380
    readonly property int popupWidth: 360

    readonly property int animMs: 150

    // The bar's background; the quick settings panel uses the same, so they read as one piece.
    readonly property color barColor: alpha(Colors.base, 0.92)

    // The colour with an alpha (0-1).
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
}
