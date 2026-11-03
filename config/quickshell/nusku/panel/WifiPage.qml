// Quick settings' Wi-Fi page: nearby networks (connected first, then saved, then by signal).
// Pick one to connect (a new secured one asks for its password here), the connected one to
// disconnect. It scans while it's open. Network settings opens nm-connection-editor.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs
import qs.services
import qs.widgets

ColumnLayout {
    id: root
    spacing: 10

    readonly property var device: Net.wifiDevice
    // The network asking for a password, and what went wrong last.
    property var asking: null
    property string problem: ""

    // Scan while the page is showing.
    Binding {
        when: root.device !== null
        target: root.device
        property: "scannerEnabled"
        value: root.visible && Net.wifiOn
    }

    readonly property var networks: {
        if (!device) return [];
        const list = [...device.networks.values].filter(n => n.name !== "");
        const rank = n => n.connected ? 0 : n.known ? 1 : 2;
        return list.sort((a, b) => rank(a) - rank(b) || b.signalStrength - a.signalStrength);
    }

    function pick(n) {
        problem = "";
        if (n.connected) n.disconnect();
        else if (n.known || n.security === WifiSecurityType.Open) n.connect();
        else asking = n;
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Wi-Fi"
        on: Net.wifiOn
        onToggled: Quickshell.execDetached(["nusku-quick", "toggle", "wifi"])
    }

    Label {
        visible: !Net.wifiOn || !root.device
        Layout.fillWidth: true
        text: !root.device ? "No Wi-Fi adapter" : "Wi-Fi is off"
        color: Colors.overlay1
    }
    Label {
        visible: root.problem !== ""
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: root.problem
        color: Colors.red
        font.pixelSize: Theme.fontSizeSmall
    }

    Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: Net.wifiOn && root.device !== null
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: list
            width: parent.width
            spacing: 6
            Repeater {
                model: root.networks
                Rectangle {
                    id: row
                    required property var modelData
                    readonly property bool secured: modelData.security !== WifiSecurityType.Open
                    readonly property bool asking: root.asking === modelData
                    Layout.fillWidth: true
                    implicitHeight: col.implicitHeight + 16
                    radius: Theme.radius
                    color: modelData.connected ? Theme.alpha(Colors.accent, 0.25) : rowMouse.containsMouse ? Colors.surface1 : Colors.surface0

                    Connections {
                        target: row.modelData
                        function onConnectionFailed(reason) {
                            root.problem = `Couldn't connect to ${row.modelData.name}` + (row.secured ? " (wrong password?)" : "");
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pick(row.modelData)
                    }
                    ColumnLayout {
                        id: col
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 12
                        spacing: 8
                        RowLayout {
                            spacing: 10
                            Icon {
                                text: ["󰤟", "󰤢", "󰤥", "󰤨"][Math.min(3, Math.floor((row.modelData.signalStrength > 1 ? row.modelData.signalStrength / 100 : row.modelData.signalStrength) * 4))]
                                color: Colors.accent
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Label { Layout.fillWidth: true; text: row.modelData.name; font.bold: row.modelData.connected }
                                Label {
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    text: row.modelData.stateChanging ? "Connecting…"
                                        : row.modelData.connected ? "Connected" : row.modelData.known ? "Saved" : ""
                                    color: Colors.subtext0
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }
                            Icon { visible: row.secured; text: "󰌾"; size: 14; color: Colors.overlay1 }
                        }
                        // The password for a new secured network.
                        Rectangle {
                            visible: row.asking
                            Layout.fillWidth: true
                            implicitHeight: 38
                            radius: Theme.radius
                            color: Colors.base
                            TextInput {
                                id: psk
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: TextInput.Password
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                                color: Colors.text
                                onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                                Keys.onReturnPressed: { row.modelData.connectWithPsk(text); root.asking = null; }
                                Keys.onEnterPressed: { row.modelData.connectWithPsk(text); root.asking = null; }
                                Keys.onEscapePressed: root.asking = null
                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: psk.text === ""
                                    text: "Password, then Enter"
                                    color: Colors.overlay1
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IconButton {
        Layout.alignment: Qt.AlignHCenter
        implicitHeight: 34
        icon: "󰒓"
        text: "Network settings"
        iconSize: Theme.fontSize
        onClicked: { PanelState.open = false; Quickshell.execDetached(["nm-connection-editor"]); }
    }
}
