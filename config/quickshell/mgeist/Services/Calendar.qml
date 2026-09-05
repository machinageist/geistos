// Author: Jeff
// Date: 2026-09-04
// Description: One day of the calendar, carried entirely by the mg-calr CLI
// Notes: mg-calr stays the authority for events, and reads todos only through the
//        projection it has already validated. Nothing here opens a database.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string bridge: `${Quickshell.env("HOME")}/dotfiles/scripts/geist-calendar`

    // Offset in days from today; the card moves this rather than holding a date
    property int offset: 0

    property var items: []
    property var cancelled: []
    property var counts: ({ events: 0, todos: 0, cancelled: 0 })
    property var projection: ({ producer: "", revision: 0, complete: false, present: false,
        stale: false, behind: 0 })
    property string date: ""
    property string timezone: ""
    property bool isToday: true
    property bool showCancelled: false
    property bool busy: false
    property bool acting: false
    property bool refreshPending: false
    property string error: ""
    property string status: ""
    property string checkedAt: ""

    // How much of the viewed day is scheduled
    readonly property int scheduled: (counts.events ?? 0) + (counts.todos ?? 0)
    // What the bar reports, held separately so browsing to another day cannot
    // make the pill claim a count that is not today's
    property int todayScheduled: 0

    readonly property var rows: showCancelled
        ? root.items.concat(root.cancelled) : root.items

    function refresh() {
        if (dayProcess.running) {
            root.refreshPending = true;
            return;
        }
        root.busy = true;
        root.error = "";
        dayProcess.command = [root.bridge, "day", "--date", root.wantedDate()];
        dayProcess.running = true;
    }

    // A date rather than an offset, so the bridge never has to guess what "today" meant
    function wantedDate() {
        const day = new Date();
        day.setDate(day.getDate() + root.offset);
        return Qt.formatDate(day, "yyyy-MM-dd");
    }

    function move(days) {
        root.offset += days;
        root.refresh();
    }

    function today() {
        if (root.offset === 0) return;
        root.offset = 0;
        root.refresh();
    }

    function setShowCancelled(value) {
        root.showCancelled = value;
    }

    /// Returns false when the work was refused, so the caller can keep the input.
    function add(title, at, minutes) {
        const wanted = (title ?? "").trim();
        if (wanted === "") return false;
        // Not named `arguments`: declaring that inside a function is a syntax error
        let parts = ["add", wanted, "--date", root.wantedDate()];
        if (at) parts = parts.concat(["--at", at, "--minutes", `${minutes ?? 60}`]);
        return root.run(parts, `added ${wanted}`);
    }

    function cancel(handle) { return root.run(["cancel", handle], "cancelled"); }
    function restore(handle) { return root.run(["restore", handle], "restored"); }

    function run(parts, describe) {
        if (actProcess.running) {
            root.status = "still working on the last one";
            return false;
        }
        root.acting = true;
        root.error = "";
        root.status = "working…";
        actProcess.describe = describe;
        actProcess.command = [root.bridge].concat(parts);
        actProcess.running = true;
        return true;
    }

    // The bridge reports its own failures as JSON, so a nonzero exit is expected
    // whenever an event is missing, ambiguous, or already in the asked-for state.
    function readError(text) {
        try {
            const payload = JSON.parse(text.trim());
            return payload.error ?? "calendar bridge failed";
        } catch (parseError) {
            return "calendar bridge returned unreadable output";
        }
    }

    Process {
        id: dayProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(text.trim());
                    if (payload.ok) {
                        root.items = payload.items ?? [];
                        root.cancelled = payload.cancelled ?? [];
                        root.counts = payload.counts ?? root.counts;
                        root.projection = payload.projection ?? root.projection;
                        root.date = payload.date ?? "";
                        root.timezone = payload.timezone ?? "";
                        root.isToday = payload.is_today ?? false;
                        if (root.isToday)
                            root.todayScheduled = (root.counts.events ?? 0) + (root.counts.todos ?? 0);
                        root.checkedAt = Qt.formatDateTime(new Date(), "HH:mm:ss");
                    } else {
                        root.error = payload.error ?? "calendar bridge failed";
                    }
                } catch (parseError) {
                    root.error = "calendar bridge returned unreadable output";
                }
            }
        }
        stderr: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            if (exitCode !== 0 && root.error === "")
                root.error = root.readError(dayProcess.stdout.text);
            if (root.refreshPending) {
                root.refreshPending = false;
                root.refresh();
            }
        }
    }

    Process {
        id: actProcess
        property string describe: ""
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            root.acting = false;
            if (exitCode === 0) {
                root.status = actProcess.describe;
                root.refresh();
            } else {
                root.error = root.readError(actProcess.stdout.text);
                root.status = "";
            }
        }
    }

    Timer {
        interval: 5 * 60 * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (root.offset === 0) root.refresh()
    }
}
