// The calendar, down from under the clock: the month (weeks start on Monday), a dot on days
// with events, and the picked day's events. Events come from GNOME's calendar service through
// nusku-calendar-events, so Online Accounts calendars (Google, Nextcloud) are in it; picking an
// event (or "Open Calendar") opens GNOME Calendar. Keys: arrows move the day, PgUp/PgDn the
// month, Home goes to today, Enter opens the day, Esc closes. Click the clock to open it.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.widgets

PanelWindow {
    id: win
    readonly property var menu: Menus.calendar
    screen: menu.screen
    visible: menu.progress > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: drawer.area }
    WlrLayershell.namespace: "nusku-calendar"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: menu.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    SystemClock { id: clock; precision: SystemClock.Hours }

    // Dates as local midnights; days are compared as "YYYY-MM-DD".
    function key(d) { return Qt.formatDate(d, "yyyy-MM-dd"); }
    function addDays(d, n) { const r = new Date(d); r.setDate(r.getDate() + n); return r; }
    readonly property date today: new Date(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate())
    property date selected: today
    property date month: new Date(today.getFullYear(), today.getMonth(), 1)
    // The 6 x 7 grid: from the Monday on or before the 1st.
    readonly property date gridStart: addDays(month, -((month.getDay() + 6) % 7))
    readonly property var cells: Array.from({ length: 42 }, (_, i) => addDays(gridStart, i))

    property var days: ({})
    property bool hasGnomeCalendar: false
    readonly property var dayEvents: days[key(selected)] ?? []

    function select(d) {
        selected = d;
        if (d.getMonth() !== month.getMonth() || d.getFullYear() !== month.getFullYear())
            month = new Date(d.getFullYear(), d.getMonth(), 1);
    }
    function moveMonth(step) {
        const m = new Date(month.getFullYear(), month.getMonth() + step, 1);
        const last = new Date(m.getFullYear(), m.getMonth() + 1, 0).getDate();
        selected = new Date(m.getFullYear(), m.getMonth(), Math.min(selected.getDate(), last));
        month = m;
    }
    function openGnomeCalendar(args) {
        if (!hasGnomeCalendar) return;
        menu.open = false;
        Quickshell.execDetached(["gnome-calendar", ...args]);
    }
    function load() {
        events.command = ["nusku-calendar-events", key(gridStart), key(addDays(gridStart, 41))];
        events.running = false;
        events.running = true;
    }
    onGridStartChanged: if (menu.open) load()

    Process {
        id: events
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    win.days = r.days ?? {};
                    win.hasGnomeCalendar = r.gnomeCalendar === true;
                } catch (e) {
                    win.days = {};
                }
            }
        }
    }

    Connections {
        target: win.menu
        function onOpenChanged() {
            if (win.menu.open) {
                win.select(win.today);
                win.load();
                keys.forceActiveFocus();
            }
        }
    }

    Drawer {
        id: drawer
        edge: "top"
        length: 360
        depth: body.implicitHeight + 28
        Behavior on depth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        progress: win.menu.progress

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                const step = { [Qt.Key_Left]: -1, [Qt.Key_Right]: 1, [Qt.Key_Up]: -7, [Qt.Key_Down]: 7 }[e.key];
                if (e.key === Qt.Key_Escape) win.menu.open = false;
                else if (step !== undefined) win.select(win.addDays(win.selected, step));
                else if (e.key === Qt.Key_PageUp) win.moveMonth(-1);
                else if (e.key === Qt.Key_PageDown) win.moveMonth(1);
                else if (e.key === Qt.Key_Home) win.select(win.today);
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) win.openGnomeCalendar(["--date", win.key(win.selected)]);
                else return;
                e.accepted = true;
            }

            ColumnLayout {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 8

                // Month and year, with back / today / forward.
                RowLayout {
                    Layout.fillWidth: true
                    IconButton { implicitWidth: 32; implicitHeight: 32; icon: "󰅁"; tooltip: "Previous month"; onClicked: win.moveMonth(-1) }
                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.formatDate(win.month, "MMMM yyyy")
                        font.bold: true
                        font.pixelSize: Theme.fontSizeLarge
                    }
                    IconButton { implicitWidth: 32; implicitHeight: 32; icon: "󰃭"; tooltip: "Today"; onClicked: win.select(win.today) }
                    IconButton { implicitWidth: 32; implicitHeight: 32; icon: "󰅂"; tooltip: "Next month"; onClicked: win.moveMonth(1) }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    rowSpacing: 2
                    columnSpacing: 2

                    Repeater {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                        Label {
                            required property string modelData
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: Colors.overlay1
                            font.pixelSize: Theme.fontSizeSmall - 1
                            font.bold: true
                        }
                    }
                    Repeater {
                        model: win.cells
                        Rectangle {
                            id: day
                            required property date modelData
                            readonly property string k: win.key(modelData)
                            readonly property bool isToday: k === win.key(win.today)
                            readonly property bool isSelected: k === win.key(win.selected)
                            readonly property bool inMonth: modelData.getMonth() === win.month.getMonth()
                            Layout.fillWidth: true
                            implicitHeight: 40
                            radius: height / 2
                            color: isToday ? Colors.accent : dayMouse.containsMouse ? Colors.surface0 : "transparent"
                            border.width: isSelected && !isToday ? 2 : 0
                            border.color: Colors.accent

                            Label {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -2
                                text: day.modelData.getDate()
                                color: day.isToday ? Colors.crust : day.inMonth ? Colors.text : Colors.overlay0
                                font.bold: day.isToday
                            }
                            // A dot on days with events.
                            Rectangle {
                                visible: (win.days[day.k] ?? []).length > 0
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 6
                                width: 5; height: 5; radius: 2.5
                                color: day.isToday ? Colors.crust : Colors.accent
                            }
                            MouseArea {
                                id: dayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.select(day.modelData)
                                onDoubleClicked: win.openGnomeCalendar(["--date", day.k])
                            }
                        }
                    }
                }

                // The picked day's events.
                Label {
                    Layout.topMargin: 6
                    text: Qt.formatDate(win.selected, "dddd d MMMM")
                    color: Colors.subtext0
                    font.bold: true
                    font.pixelSize: Theme.fontSizeSmall
                }
                Label {
                    visible: win.dayEvents.length === 0
                    text: "Nothing on"
                    color: Colors.overlay1
                    font.pixelSize: Theme.fontSizeSmall
                }
                Repeater {
                    model: win.dayEvents.slice(0, 4)
                    Rectangle {
                        id: ev
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: Theme.radius
                        color: evMouse.containsMouse && win.hasGnomeCalendar ? Colors.surface1 : Colors.surface0
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10
                            Label { text: ev.modelData.time; color: Colors.accent; font.pixelSize: Theme.fontSizeSmall }
                            Label { Layout.fillWidth: true; text: ev.modelData.summary }
                        }
                        MouseArea {
                            id: evMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: win.hasGnomeCalendar ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: win.openGnomeCalendar(["--uuid", ev.modelData.uid])
                        }
                    }
                }
                Label {
                    visible: win.dayEvents.length > 4
                    text: `and ${win.dayEvents.length - 4} more`
                    color: Colors.overlay1
                    font.pixelSize: Theme.fontSizeSmall
                }

                IconButton {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 4
                    visible: win.hasGnomeCalendar
                    implicitHeight: 34
                    icon: "󰸗"
                    text: "Open Calendar"
                    iconSize: Theme.fontSize
                    onClicked: win.openGnomeCalendar(["--date", win.key(win.selected)])
                }
                // Without GNOME Calendar there's nowhere to add calendars: say how to get it.
                Label {
                    visible: !win.hasGnomeCalendar
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    text: "Pick GNOME Calendar with ./install.sh --apps to see your Google or Nextcloud calendars here."
                    color: Colors.overlay1
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }
}
