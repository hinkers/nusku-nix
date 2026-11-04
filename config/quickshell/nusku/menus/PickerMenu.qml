// A searchable list down from under the bar (clipboard history, keybind search): type to
// filter, arrows to move, Enter to pick, Delete to remove an entry (when `removable`), Esc to
// close. `items` are objects with `title`, and optionally `subtitle`, `icon` (a glyph) and
// `keys` (shown on the right).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.widgets

PanelWindow {
    id: win
    required property var menu
    property string namespace: "nusku-picker"
    property string placeholder: "Search"
    property string empty: "Nothing here"
    property string searchIcon: "󰍉"
    property var items: []
    property bool removable: false
    property int rows: 8
    readonly property int rowHeight: 46
    // Extra buttons next to the search field (e.g. "Clear all").
    default property alias actions: actionRow.data
    signal picked(var item)
    signal removed(var item)
    signal opened()

    screen: menu.screen
    visible: menu.progress > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: drawer.area }
    WlrLayershell.namespace: namespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: menu.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var results: {
        const q = search.text.trim().toLowerCase();
        if (q === "") return items;
        return items.filter(i => [i.title, i.subtitle, i.keys].join(" ").toLowerCase().includes(q));
    }
    function pick(i) {
        if (!i) return;
        menu.open = false;
        picked(i);
    }

    Connections {
        target: win.menu
        function onOpenChanged() {
            if (win.menu.open) {
                search.text = "";
                list.currentIndex = 0;
                search.forceActiveFocus();
                win.opened();
            }
        }
    }

    Drawer {
        id: drawer
        edge: "top"
        length: 640
        depth: win.rows * win.rowHeight + 48 + 3 * 16
        progress: win.menu.progress

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    radius: Theme.radiusLarge
                    color: Colors.surface0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12
                        Icon { text: win.searchIcon; color: Colors.accent }
                        TextInput {
                            id: search
                            Layout.fillWidth: true
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize + 1
                            color: Colors.text
                            selectionColor: Colors.accent
                            clip: true
                            onTextChanged: list.currentIndex = 0

                            Keys.onEscapePressed: win.menu.open = false
                            Keys.onReturnPressed: win.pick(win.results[list.currentIndex])
                            Keys.onEnterPressed: win.pick(win.results[list.currentIndex])
                            Keys.onUpPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
                            Keys.onDownPressed: list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1)
                            Keys.onTabPressed: list.currentIndex = (list.currentIndex + 1) % Math.max(1, list.count)
                            Keys.onDeletePressed: e => {
                                if (win.removable && list.count > 0 && search.cursorPosition === search.text.length) {
                                    win.removed(win.results[list.currentIndex]);
                                    e.accepted = true;
                                } else e.accepted = false;
                            }

                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: search.text === ""
                                text: win.placeholder
                                color: Colors.overlay1
                            }
                        }
                    }
                }
                RowLayout {
                    id: actionRow
                    // Layouts fill by default; this one only takes what its buttons need.
                    Layout.fillWidth: false
                    visible: children.length > 0
                    spacing: 8
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: win.results
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                // The first entry sits right under the search field.
                highlight: Rectangle { radius: Theme.radius; color: Colors.surface0 }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: win.rowHeight

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12
                        Icon {
                            visible: (row.modelData.icon ?? "") !== ""
                            text: row.modelData.icon ?? ""
                            color: Colors.accent
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Label {
                                Layout.fillWidth: true
                                text: row.modelData.title
                                font.bold: row.index === list.currentIndex
                                maximumLineCount: 1
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: (row.modelData.subtitle ?? "") !== ""
                                text: row.modelData.subtitle ?? ""
                                color: Colors.overlay1
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                        Label {
                            visible: (row.modelData.keys ?? "") !== ""
                            text: row.modelData.keys ?? ""
                            color: Colors.subtext0
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: list.currentIndex = row.index
                        onClicked: win.pick(row.modelData)
                    }
                }

                Label {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: win.empty
                    color: Colors.overlay1
                }
            }
        }
    }
}
