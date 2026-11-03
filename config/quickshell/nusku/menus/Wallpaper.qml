// The wallpaper picker, up from the bottom: a row of thumbnails (the current one marked),
// left/right to move, Enter or a click to set it, Esc to close. The chips pick which monitor
// (all of them by default). nusku-wallpaper does the setting. Super + W (Nusku's binds).
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
    readonly property var menu: Menus.wallpaper
    screen: menu.screen
    visible: menu.progress > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: drawer.area }
    WlrLayershell.namespace: "nusku-wallpaper"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: menu.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property var files: []
    property string current: ""
    property string target: "all"

    function apply(file) {
        if (!file) return;
        menu.open = false;
        Quickshell.execDetached(["nusku-wallpaper", "set", file, target]);
    }

    // nusku-wallpaper list, then the saved choice (~/.local/state/nusku/current-wallpaper).
    Process {
        id: lister
        command: ["sh", "-c", 'nusku-wallpaper list; printf "current=%s\\n" "$(readlink "${XDG_STATE_HOME:-$HOME/.local/state}/nusku/current-wallpaper")"']
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l !== "");
                win.current = (lines.find(l => l.startsWith("current=")) ?? "current=").slice(8);
                win.files = lines.filter(l => !l.startsWith("current="));
                const i = win.files.indexOf(win.current);
                strip.currentIndex = i >= 0 ? i : 0;
                strip.positionViewAtIndex(strip.currentIndex, ListView.Center);
            }
        }
    }

    Connections {
        target: win.menu
        function onOpenChanged() {
            if (win.menu.open) {
                win.target = "all";
                lister.running = false;
                lister.running = true;
                strip.forceActiveFocus();
            }
        }
    }

    Drawer {
        id: drawer
        edge: "bottom"
        length: Math.min(win.width - 2 * Theme.frame - 2 * Theme.frameRadius - 80, 1100)
        // The thumbnails and their names, plus the monitor chips when there's more than one.
        depth: 124 + 26 + 2 * 16 + (Quickshell.screens.length > 1 ? 42 : 0)
        progress: win.menu.progress

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            ListView {
                id: strip
                Layout.fillWidth: true
                Layout.fillHeight: true
                orientation: ListView.Horizontal
                spacing: 12
                clip: true
                model: win.files
                highlightMoveDuration: 120
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: width / 2 - 110
                preferredHighlightEnd: width / 2 + 110
                focus: true
                Keys.onEscapePressed: win.menu.open = false
                Keys.onReturnPressed: win.apply(win.files[currentIndex])
                Keys.onEnterPressed: win.apply(win.files[currentIndex])

                delegate: Item {
                    id: thumb
                    required property string modelData
                    required property int index
                    readonly property bool isCurrent: modelData === win.current
                    width: 200
                    height: ListView.view.height

                    Rectangle {
                        id: frame
                        width: parent.width
                        height: 124
                        radius: Theme.radiusLarge
                        color: Colors.surface0
                        border.width: thumb.index === strip.currentIndex ? 3 : thumb.isCurrent ? 2 : 0
                        border.color: thumb.index === strip.currentIndex ? Colors.accent : Colors.overlay1
                        Image {
                            anchors.fill: parent
                            anchors.margins: 3
                            source: "file://" + thumb.modelData
                            sourceSize.width: 400
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            layer.enabled: true
                        }
                        Icon {
                            visible: thumb.isCurrent
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            text: "󰄬"
                            color: Colors.accent
                        }
                    }
                    Label {
                        anchors.top: frame.bottom
                        anchors.topMargin: 6
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: thumb.modelData.split("/").pop().replace(/\.[^.]+$/, "")
                        color: thumb.index === strip.currentIndex ? Colors.text : Colors.subtext0
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: strip.currentIndex = thumb.index
                        onClicked: win.apply(thumb.modelData)
                    }
                }
            }

            // Which monitor (only shown with more than one).
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                visible: Quickshell.screens.length > 1
                spacing: 8
                Repeater {
                    model: ["all", ...Quickshell.screens.map(s => s.name)]
                    IconButton {
                        required property string modelData
                        implicitHeight: 30
                        icon: modelData === "all" ? "󰍺" : "󰍹"
                        text: modelData === "all" ? "All monitors" : modelData
                        iconSize: Theme.fontSize
                        active: win.target === modelData
                        onClicked: win.target = modelData
                    }
                }
            }
        }
    }
}
