// Author: Jeff
// Date: 2026-08-21
// Description: Notification server plus the history the centre reads
// Notes: Quickshell owns org.freedesktop.Notifications here, so mako must not
//        run — only one process can hold that bus name. Notifications must be
//        marked tracked or they are dropped as soon as they are delivered.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Io

Singleton {
    id: root

    property bool doNotDisturb: false
    property var mutedApps: []
    property var sensitiveApps: ["1password", "bitwarden", "keepassxc"]
    property var history: []
    readonly property bool suppressPopups: doNotDisturb || DesktopState.focusMode || DesktopState.quietActive
    // Popups currently on screen
    property var active: []

    readonly property int maxHistory: 100

    NotificationServer {
        id: server

        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true

        onNotification: notif => {
            // Without this the server discards it immediately
            notif.tracked = true;

            const appKey = String(notif.appName || "").toLowerCase();
            const privateEntry = root.sensitiveApps.some(a => appKey.includes(a));
            const entry = {
                id: notif.id,
                appName: notif.appName,
                summary: privateEntry ? "Private notification" : notif.summary,
                body: privateEntry ? "Content hidden" : notif.body,
                image: notif.image,
                appIcon: notif.appIcon,
                urgency: notif.urgency,
                actions: notif.actions,
                at: Date.now(),
                notif: notif
            };

            root.history = [entry, ...root.history].slice(0, root.maxHistory);

            if (root.suppressPopups || root.mutedApps.includes(appKey)) return;

            root.active = [entry, ...root.active];
            dismissTimer.restart();
        }
    }

    // Drop the oldest on-screen popup
    function expireOldest() {
        if (root.active.length === 0) return;
        root.active = root.active.slice(0, root.active.length - 1);
    }

    // Clear every stored notification
    function clearHistory() {
        root.history = [];
    }

    // Remove one stored notification
    function forget(id) {
        root.history = root.history.filter(e => e.id !== id);
        root.active = root.active.filter(e => e.id !== id);
    }

    // Flip do-not-disturb, clearing anything on screen when turning it on
    function toggleDnd() {
        root.doNotDisturb = !root.doNotDisturb;
        if (root.doNotDisturb) root.active = [];
        settings.setText(JSON.stringify({ doNotDisturb: root.doNotDisturb, mutedApps: root.mutedApps }, null, 2));
    }

    FileView {
        id: settings
        path: Quickshell.statePath("notifications.json")
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.doNotDisturb = s.doNotDisturb ?? false;
                root.mutedApps = s.mutedApps ?? [];
            } catch (e) {}
        }
    }

    Timer {
        id: dismissTimer
        interval: 5000
        repeat: true
        running: root.active.length > 0
        onTriggered: root.expireOldest()
    }
}
