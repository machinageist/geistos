// Author: Jeff
// Date: 2026-08-21
// Description: Pomodoro cycle — work, short break, long break
// Notes: Elapsed time is measured from Date.now() rather than counted in the
//        tick handler, so a missed or late tick never loses time.
//        Paired with Bar/modules/PomodoroPill.qml; a service and a bar module
//        may not share a file name, hence the Pill suffix on the module.

pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // ── Durations, in minutes ────────────────────────────────
    property int workMinutes:  25
    property int shortMinutes:  5
    property int longMinutes:  15
    // Long break replaces the short one after this many work sessions
    property int sessionsPerLong: 4

    // work | short | long
    property string phase: "work"
    property bool running: false
    property int sessionsCompleted: 0

    property real accumulatedMs: 0
    property real startedAt: 0
    property real now: Date.now()

    readonly property int phaseSeconds: {
        switch (phase) {
        case "short": return shortMinutes * 60;
        case "long":  return longMinutes * 60;
        default:      return workMinutes * 60;
        }
    }

    readonly property real elapsedMs: accumulatedMs + (running ? now - startedAt : 0)
    readonly property int remaining: Math.max(0, phaseSeconds - Math.floor(elapsedMs / 1000))
    readonly property bool idle: !running && accumulatedMs === 0
    readonly property real progress: phaseSeconds > 0 ? 1 - remaining / phaseSeconds : 0

    readonly property string label: {
        const m = Math.floor(remaining / 60);
        const s = remaining % 60;
        return `${m}:${String(s).padStart(2, "0")}`;
    }

    // Begin or resume the current phase
    function start() {
        if (running) return;
        root.startedAt = Date.now();
        root.now = root.startedAt;
        root.running = true;
    }

    // Hold the current phase where it is
    function pause() {
        if (!running) return;
        root.accumulatedMs = root.elapsedMs;
        root.running = false;
    }

    // Start if stopped, hold if running
    function toggle() {
        running ? pause() : start();
    }

    // Send the current phase back to zero without changing which phase it is
    function reset() {
        root.running = false;
        root.accumulatedMs = 0;
    }

    // Move to whatever phase comes next in the cycle
    function advance(countSession) {
        if (phase === "work") {
            if (countSession) root.sessionsCompleted += 1;
            // A long break is earned by finishing sessions, not by skipping one.
            // Without the countSession guard a skip from a fresh cycle hit
            // 0 % 4 === 0 and awarded a long break on the very first press.
            root.phase = (countSession && root.sessionsCompleted % root.sessionsPerLong === 0)
                ? "long" : "short";
        } else {
            root.phase = "work";
        }
        reset();
    }

    // Skip the rest of this phase by hand; does not count as a finished session
    function skip() {
        advance(false);
    }

    // Clear the whole cycle back to a fresh first work session
    function resetAll() {
        root.sessionsCompleted = 0;
        root.phase = "work";
        reset();
    }

    Timer {
        interval: 250
        running: root.running
        repeat: true
        onTriggered: {
            root.now = Date.now();

            if (root.remaining > 0) return;

            const finished = root.phase;
            root.advance(true);

            const title = finished === "work" ? "Pomodoro complete" : "Break over";
            const body = root.phase === "work"
                ? `Back to work — session ${root.sessionsCompleted + 1}`
                : `Take a ${root.phase === "long" ? root.longMinutes : root.shortMinutes} minute break`;

            Quickshell.execDetached(["notify-send", "-a", "Pomodoro", title, body]);
        }
    }
}
