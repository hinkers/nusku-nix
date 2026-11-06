// The app launcher, down from under the bar: type to search the installed apps (name,
// keywords, description) and the power actions (lock, log out, suspend, reboot, shut down;
// services/Power.qml), arrows to move, Enter to start, Esc to close. Log out, reboot and shut
// down ask for a second Enter or click. Apps that run in a
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
    // the rest of what matches (keywords, generic name, description). No text: A to Z, apps
    // only (the power actions show once you search).
    readonly property var results: {
        const q = search.text.trim().toLowerCase();
        const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay);
        const words = a => [a.genericName, a.comment, ...(a.keywords ?? [])].join(" ").toLowerCase();
        const scored = [];
        const consider = (item, name, rest) => {
            let score = -1;
            if (q === "") score = 3;
            else if (name.startsWith(q)) score = 0;
            else if (name.includes(q)) score = 1;
            else if (rest.includes(q)) score = 2;
            if (score >= 0) scored.push({ item, score, name });
        };
        for (const a of apps) consider(a, (a.name ?? "").toLowerCase(), words(a));
        if (q !== "") {
            for (const p of Power.actions)
                consider({ power: p, name: p.text, comment: "Power", glyph: p.icon },
                    p.text.toLowerCase(), "power " + p.keywords);
        }
        scored.sort((x, y) => x.score - y.score || x.name.localeCompare(y.name));
        return scored.map(s => s.item);
    }
    // The power action waiting for its second Enter or click (its name).
    property string armed: ""
    onResultsChanged: armed = ""

    function launch(app) {
        if (!app) return;
        if (app.power) {
            if (app.power.confirm && armed !== app.name) { armed = app.name; return; }
            menu.open = false;
            Quickshell.execDetached(app.power.cmd);
            return;
        }
        menu.open = false;
        if (app.runInTerminal) Quickshell.execDetached(["kitty", "-e", ...app.command]);
        else app.execute();
    }

    Connections {
        target: win.menu
        function onOpenChanged() {
            if (win.menu.open) {
                search.text = "";
                win.armed = "";
                list.currentIndex = 0;
                search.forceActiveFocus();
            }
        }
    }

    Drawer {
        id: drawer
        edge: "top"
        length: 560
        depth: win.rows * win.rowHeight + 48 + 3 * 16
        progress: win.menu.progress

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            // The search field, under the bar.
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
                        Keys.onUpPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
                        Keys.onDownPressed: list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1)
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

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: win.results
                currentIndex: 0
                onCurrentIndexChanged: win.armed = ""
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                // The best match sits right under the search field.
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
                            visible: !row.modelData.power
                            implicitSize: 32
                            source: row.modelData.power ? "" : Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                            asynchronous: true
                        }
                        Icon {
                            visible: !!row.modelData.power
                            Layout.preferredWidth: 32
                            text: row.modelData.glyph ?? ""
                            size: 22
                            color: (!!row.modelData.power && win.armed === row.modelData.name) ? Colors.red : Colors.accent
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
                                text: (!!row.modelData.power && win.armed === row.modelData.name)
                                    ? "Press Enter or click again to " + row.modelData.name.toLowerCase()
                                    : row.modelData.comment || row.modelData.genericName || ""
                                color: (!!row.modelData.power && win.armed === row.modelData.name) ? Colors.red : Colors.overlay1
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
                    text: "Nothing matches"
                    color: Colors.overlay1
                }
            }
        }
    }
}
