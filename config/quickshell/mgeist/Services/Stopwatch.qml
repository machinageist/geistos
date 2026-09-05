// Author: Jeff
// Date: 2026-08-21
// Description: Plain count-up stopwatch
// Notes: Same Date.now() approach as Pomodoro — the tick only refreshes the
//        display, it never accumulates, so drift cannot build up.

pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool running: false
    property real accumulatedMs: 0
    property real startedAt: 0
    property real now: Date.now()

    readonly property real elapsedMs: accumulatedMs + (running ? now - startedAt : 0)
    readonly property int elapsed: Math.floor(elapsedMs / 1000)
    readonly property bool idle: !running && accumulatedMs === 0

    readonly property string label: {
        const h = Math.floor(elapsed / 3600);
        const m = Math.floor(elapsed / 60) % 60;
        const s = elapsed % 60;
        return h > 0
            ? `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`
            : `${m}:${String(s).padStart(2, "0")}`;
    }

    // Begin or resume counting
    function start() {
        if (running) return;
        root.startedAt = Date.now();
        root.now = root.startedAt;
        root.running = true;
    }

    // Hold the count where it is
    function pause() {
        if (!running) return;
        root.accumulatedMs = root.elapsedMs;
        root.running = false;
    }

    // Start if stopped, hold if running
    function toggle() {
        running ? pause() : start();
    }

    // Back to zero and stopped
    function reset() {
        root.running = false;
        root.accumulatedMs = 0;
    }

    Timer {
        interval: 250
        running: root.running
        repeat: true
        onTriggered: root.now = Date.now()
    }
}
