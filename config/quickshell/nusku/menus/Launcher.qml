// The app launcher, up from the bottom border: type to search the installed apps (name,
// keywords, description), arrows to move, Enter to start, Esc to close. Apps that run in a
// terminal open in kitty. Super + Space (Nusku's binds) or Super + D (niri's).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services
import qs.widgets

PanelWindow {
    id: win
    readonly property var menu: Menus.launcher
    screen: menu.screen
    visible: menu.progress > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: drawer.area }
    WlrLayershell.namespace: "nusku-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: menu.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int rows: 7
    readonly property int rowHeight: 52

    // Best matches first: names that start with the text, then names that contain it, then
    // the rest of what matches (keywords, generic name, description). No text: A to Z.
    readonly property var results: {
        const q = search.text.trim().toLowerCase();
        const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay);
        const words = a => [a.genericName, a.comment, ...(a.keywords ?? [])].join(" ").toLowerCase();
        const scored = [];
        for (const a of apps) {
            const name = (a.name ?? "").toLowerCase();
            let score = -1;
            if (q === "") score = 3;
            else if (name.startsWith(q)) score = 0;
            else if (name.includes(q)) score = 1;
            else if (words(a).includes(q)) score = 2;
            if (score >= 0) scored.push({ a, score, name });
        }
        scored.sort((x, y) => x.score - y.score || x.name.localeCompare(y.name));
        return scored.map(s => s.a);
    }

    function launch(app) {
        if (!app) return;
        menu.open = false;
        if (app.runInTerminal) Quickshell.execDetached(["kitty", "-e", ...app.command]);
        else app.execute();
    }

    Connections {
        target: win.menu
        function onOpenChanged() {
            if (win.menu.open) {
                search.text = "";
                list.currentIndex = 0;
                search.forceActiveFocus();
            }
        }
    }

    Drawer {
        id: drawer
        edge: "bottom"
        length: 560
        depth: win.rows * win.rowHeight + 48 + 3 * 16
        progress: win.menu.progress

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: win.results
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                // The best match sits nearest the search field.
                verticalLayoutDirection: ListView.BottomToTop
                highlight: Rectangle { radius: Theme.radius; color: Colors.surface0 }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: win.rowHeight

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 12
                        IconImage {
                            implicitSize: 32
                            source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                            asynchronous: true
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Label {
                                Layout.fillWidth: true
                                text: row.modelData.name
                                font.bold: row.index === list.currentIndex
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: row.modelData.comment || row.modelData.genericName || ""
                                color: Colors.overlay1
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: list.currentIndex = row.index
                        onClicked: win.launch(row.modelData)
                    }
                }

                Label {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: "No apps match"
                    color: Colors.overlay1
                }
            }

            // The search field, nearest the bottom border.
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
                    Icon { text: "󰍉"; color: Colors.accent }
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
                        Keys.onReturnPressed: win.launch(win.results[list.currentIndex])
                        Keys.onEnterPressed: win.launch(win.results[list.currentIndex])
                        // Up moves towards the top of the screen: away from the best match.
                        Keys.onUpPressed: list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1)
                        Keys.onDownPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
                        Keys.onTabPressed: list.currentIndex = (list.currentIndex + 1) % Math.max(1, list.count)

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: search.text === ""
                            text: "Search apps"
                            color: Colors.overlay1
                        }
                    }
                }
            }
        }
    }
}
