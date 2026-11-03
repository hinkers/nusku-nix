//@ pragma UseQApplication
// Nusku shell (Quickshell): the bar on every screen, the quick settings panel and the
// notification pop-ups. Run as `qs -c nusku` (the nusku-shell user service).
// Colours: Colors.qml (generated); sizes and fonts: Theme.qml.
import QtQuick
import Quickshell
import qs.bar
import qs.panel
import qs.notifications

ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {
            required property ShellScreen modelData
            screen: modelData
        }
    }
    QuickSettings {}
    Popups {}
}
