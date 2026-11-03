// One notification: app icon or image, summary, body and action buttons. A click runs the
// default action (if any); × dismisses it. `popup` cards also expire (Notifs.timeoutFor).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs
import qs.services
import qs.widgets

Rectangle {
    id: card
    required property Notification notification
    property bool popup: false
    readonly property bool critical: notification && notification.urgency === NotificationUrgency.Critical
    readonly property var actions: notification ? notification.actions.filter(a => a.identifier !== "default") : []
    readonly property var defaultAction: notification ? notification.actions.find(a => a.identifier === "default") : null

    implicitHeight: content.implicitHeight + 24
    radius: Theme.radiusLarge
    color: popup ? Colors.base : Colors.surface0
    border.width: popup || critical ? 2 : 0
    border.color: critical ? Colors.red : Colors.accent

    Timer {
        running: card.popup && card.notification && Notifs.timeoutFor(card.notification) > 0 && !hover.containsMouse
        interval: card.notification ? Notifs.timeoutFor(card.notification) * 1000 : 0
        onTriggered: Notifs.hidePopup(card.notification)
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: card.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (card.defaultAction) card.defaultAction.invoke();
            if (card.popup) Notifs.hidePopup(card.notification);
        }
    }

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // The notification's image, else the app's icon, else a bell.
        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 40
            implicitHeight: 40
            ClippingRectangle {
                anchors.fill: parent
                radius: Theme.radius
                color: "transparent"
                visible: image.status === Image.Ready
                Image {
                    id: image
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: card.notification ? (card.notification.image || "") : ""
                    asynchronous: true
                }
            }
            IconImage {
                id: appIcon
                anchors.fill: parent
                visible: image.status !== Image.Ready && status === Image.Ready
                source: card.notification && card.notification.appIcon
                    ? (card.notification.appIcon.startsWith("/") || card.notification.appIcon.includes("://")
                        ? card.notification.appIcon : Quickshell.iconPath(card.notification.appIcon, true))
                    : ""
                asynchronous: true
            }
            Icon {
                anchors.centerIn: parent
                visible: image.status !== Image.Ready && appIcon.status !== Image.Ready
                text: "󰂚"
                size: 26
                color: card.critical ? Colors.red : Colors.accent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.fillWidth: true
                    text: card.notification ? card.notification.summary : ""
                    font.bold: true
                }
                Label {
                    text: card.notification ? card.notification.appName : ""
                    color: Colors.overlay1
                    font.pixelSize: Theme.fontSizeSmall
                    Layout.maximumWidth: 110
                }
                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 11
                    color: close.containsMouse ? Colors.surface1 : "transparent"
                    Icon {
                        anchors.centerIn: parent
                        text: "󰅖"
                        size: 14
                        color: Colors.subtext0
                    }
                    MouseArea {
                        id: close
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.notification.dismiss()
                    }
                    Tip {
                        text: "Dismiss"
                        hovered: close.containsMouse
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.notification ? card.notification.body : ""
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: card.popup ? 4 : 6
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeSmall + 1
                color: Colors.subtext1
                linkColor: Colors.accent
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: card.actions.length > 0
                spacing: 6
                Repeater {
                    model: card.actions
                    Rectangle {
                        required property var modelData
                        implicitHeight: 28
                        implicitWidth: actionLabel.implicitWidth + 20
                        radius: Theme.radius
                        color: actionMouse.containsMouse ? Colors.accent : Colors.surface1
                        Label {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: parent.modelData.text
                            font.pixelSize: Theme.fontSizeSmall
                            color: actionMouse.containsMouse ? Colors.base : Colors.text
                        }
                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: parent.modelData.invoke()
                        }
                    }
                }
            }
        }
    }
}
