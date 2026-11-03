// A quick settings page's header: back to the toggles, the title, and an on/off switch.
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

RowLayout {
    id: root
    property string title: ""
    property bool on: false
    signal toggled()
    spacing: 8
    IconButton {
        implicitWidth: 36; implicitHeight: 36
        icon: "󰁍"
        tooltip: "Back"
        onClicked: PanelState.page = "main"
    }
    Label {
        Layout.fillWidth: true
        text: root.title
        font.bold: true
        font.pixelSize: Theme.fontSizeLarge
    }
    Switch {
        checked: root.on
        onToggled: root.toggled()
    }
}
