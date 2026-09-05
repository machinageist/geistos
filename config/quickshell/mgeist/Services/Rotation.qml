// Author: Jeff
// Date: 2026-08-21
// Description: Paired wallpaper and theme rotation
// Notes: Deliberately knows nothing about Theme. Services cannot reference the
//        Theme singleton — it is constructed first and resolves to null with no
//        error — so this emits `rotated` and shell.qml re-pairs the theme.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool enabled: false
    property int intervalMinutes: 30
    // Rotation puts the theme back on "auto" so it always suits the wallpaper
    property bool pairTheme: true

    signal rotated()

    // Move to a random wallpaper
    function next() {
        Wallpaper.random();
        root.rotated();
        if (root.enabled) timer.restart();
        else timer.stop();
    }

    // Step the library in order
    function step(delta) {
        Wallpaper.cycle(delta);
        root.rotated();
        if (root.enabled) timer.restart();
        else timer.stop();
    }

    function syncTimer() {
        timer.stop();
        timer.interval = root.intervalMinutes * 60000;
        timer.running = root.enabled;
    }

    // Turn rotation on or off and remember the choice
    function setEnabled(on) {
        root.enabled = !!on;
        root.syncTimer();
        root.save();
    }

    // Change the gap between rotations, clamped to something sensible
    function setInterval(minutes) {
        root.intervalMinutes = Math.max(1, Math.min(1440, minutes));
        root.syncTimer();
        root.save();
    }

    // Persist rotation settings
    function save() {
        stateFile.setText(JSON.stringify({
            enabled: root.enabled,
            intervalMinutes: root.intervalMinutes,
            pairTheme: root.pairTheme
        }, null, 2));
    }

    Timer {
        id: timer
        interval: 30 * 60000
        running: false
        repeat: true
        onTriggered: {
            Wallpaper.random();
            root.rotated();
        }
    }

    FileView {
        id: stateFile
        path: `${Quickshell.statePath("rotation.json")}`
        printErrors: false

        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.enabled = s.enabled ?? false;
                root.intervalMinutes = s.intervalMinutes ?? 30;
                root.pairTheme = s.pairTheme ?? true;
                root.syncTimer();
            } catch (e) {
                // No saved settings; rotation stays off
            }
        }
    }
}
