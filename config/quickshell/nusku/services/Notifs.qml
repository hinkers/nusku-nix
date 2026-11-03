// The notification server (org.freedesktop.Notifications): every notification is kept for the
// quick settings list until dismissed; new ones also pop up for a while (none while Do Not
// Disturb is on, except critical ones). `qs -c nusku ipc call notifications <fn>` for scripts.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    property bool dnd: false
    // Newest first.
    readonly property list<Notification> list: [...server.trackedNotifications.values].reverse()
    readonly property int count: server.trackedNotifications.values.length
    // Shown as pop-ups right now (a subset of `list`).
    property list<Notification> popups: []

    // Seconds a pop-up stays: the sender's timeout when it gives one, else by urgency.
    function timeoutFor(n) {
        if (n.urgency === NotificationUrgency.Critical) return 0;
        if (n.expireTimeout > 0) return n.expireTimeout;
        return n.urgency === NotificationUrgency.Low ? 4 : 8;
    }
    function hidePopup(n) {
        popups = popups.filter(p => p !== n);
    }
    function clearAll() {
        for (const n of [...server.trackedNotifications.values]) n.dismiss();
        popups = [];
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true

        onNotification: n => {
            n.tracked = true;
            if (!root.dnd || n.urgency === NotificationUrgency.Critical)
                root.popups = [n, ...root.popups];
            n.closed.connect(() => root.hidePopup(n));
        }
    }

    IpcHandler {
        target: "notifications"
        function toggleDnd(): void { root.dnd = !root.dnd; }
        function dnd(): string { return root.dnd ? "true" : "false"; }
        function clear(): void { root.clearAll(); }
        function count(): int { return root.count; }
    }
}
