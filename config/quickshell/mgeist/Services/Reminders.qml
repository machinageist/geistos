// Author: Jeff
// Date: 2026-09-04
// Description: Reminder list and actions, carried entirely by the mg-remindr CLI
// Notes: mg-remindr stays the authority. Nothing here opens a database, and a
//        mutation refreshes the calendar's todo projection so the agenda does
//        not silently keep showing a reminder that has just been closed.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string bridge: `${Quickshell.env("HOME")}/dotfiles/scripts/geist-reminders`

    property var reminders: []
    property var counts: ({ open: 0, today: 0, overdue: 0, closed: 0 })
    property bool showClosed: false
    property bool busy: false
    property bool acting: false
    property string error: ""
    property string status: ""
    property string checkedAt: ""

    // Reminders due today or already past, which is what the bar reports
    readonly property int pressing: (counts.today ?? 0) + (counts.overdue ?? 0)

    // A request arriving mid-read is remembered rather than dropped: otherwise
    // toggling the closed filter while a read is in flight leaves the list
    // disagreeing with the control that asked for it.
    property bool refreshPending: false

    function refresh() {
        if (listProcess.running) {
            root.refreshPending = true;
            return;
        }
        root.busy = true;
        root.error = "";
        listProcess.command = root.showClosed
            ? [root.bridge, "list", "--all"] : [root.bridge, "list"];
        listProcess.running = true;
    }

    function setShowClosed(value) {
        if (root.showClosed === value) return;
        root.showClosed = value;
        root.refresh();
    }

    /// Returns false when the work was refused, so the caller can keep the input.
    function add(title, due) {
        const wanted = (title ?? "").trim();
        if (wanted === "") return false;
        return root.run(due ? ["add", wanted, "--due", due] : ["add", wanted], `added ${wanted}`);
    }

    function complete(handle) { return root.run(["done", handle], "completed"); }
    function trash(handle) { return root.run(["rm", handle], "trashed"); }
    function restore(handle) { return root.run(["restore", handle], "restored"); }

    // Not named `arguments`: declaring that inside a function is a syntax error
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

    // What the bridge says it did about the calendar's todo projection
    function readProjection(text) {
        try {
            return JSON.parse(text.trim()).projection ?? "unavailable";
        } catch (parseError) {
            return "failed";
        }
    }

    // The bridge reports its own failures as JSON, so a nonzero exit is expected
    // whenever a reminder is missing, ambiguous, or already in the asked-for state.
    function readError(text) {
        try {
            const payload = JSON.parse(text.trim());
            return payload.error ?? "reminder bridge failed";
        } catch (parseError) {
            return "reminder bridge returned unreadable output";
        }
    }

    Process {
        id: listProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(text.trim());
                    if (payload.ok) {
                        root.reminders = payload.reminders ?? [];
                        root.counts = payload.counts ?? root.counts;
                        root.checkedAt = Qt.formatDateTime(new Date(), "HH:mm:ss");
                    } else {
                        root.error = payload.error ?? "reminder bridge failed";
                    }
                } catch (parseError) {
                    root.error = "reminder bridge returned unreadable output";
                }
            }
        }
        stderr: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            if (exitCode !== 0 && root.error === "")
                root.error = root.readError(listProcess.stdout.text);
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
                // The bridge refreshes the calendar's projection itself, so that
                // a change made from a terminal counts too. Read what it did
                // rather than running the same sync a second time.
                GeistUi.noteProjection(root.readProjection(actProcess.stdout.text));
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
        onTriggered: root.refresh()
    }
}
