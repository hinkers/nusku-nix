//@ pragma UseQApplication
// Nusku shell (Quickshell): the bar and a frame round every screen, and what grows out of the
// frame: quick settings and notification pop-ups (top-right corner), the calendar (top), the
// app launcher (bottom) and the power menu (right).
// Run as `qs -c nusku` (the nusku-shell user service).
// Colours: Colors.qml (generated); sizes and fonts: Theme.qml.
import QtQuick
import Quickshell
import qs.bar
import qs.frame
import qs.menus
import qs.panel
import qs.notifications

ShellRoot {
    // Each screen: the bar (the frame's top edge) and the rest of the frame.
    Variants {
        model: Quickshell.screens
        Scope {
            id: perScreen
            required property ShellScreen modelData
            Bar { screen: perScreen.modelData }
            Frame { screen: perScreen.modelData }
        }
    }
    // Closes whichever menu is out on a click elsewhere.
    Catcher {}
    // Created after the pop-ups, so the panel is drawn over them while it slides out and they
    // slide back in (they share the corner).
    Popups {}
    QuickSettings {}
    // The other menus out of the frame: calendar (top), launcher (bottom), power (right).
    Calendar {}
    Launcher {}
    Session {}
}
