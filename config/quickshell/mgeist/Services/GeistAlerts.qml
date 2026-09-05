// Periodic, deduplicated alert bridge for the Geist application suite.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var calendar: ({ status: "checking", count: 0 })
    property var todo: ({ status: "checking", count: 0 })
    property var brief: ({ status: "checking", count: 0 })
    property int emitted: 0
    property string error: ""
    property string checkedAt: ""
    property bool busy: false

    function refresh() {
        if (probe.running) return;
        root.busy = true;
        root.error = "";
        probe.running = true;
    }

    Process {
        id: probe
        command: [`${Quickshell.env("HOME")}/dotfiles/scripts/geist-alerts.py`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const value = JSON.parse(text.trim());
                    root.calendar = value.calendar ?? ({ status: "unavailable", count: 0 });
                    root.todo = value.todo ?? ({ status: "unavailable", count: 0 });
                    root.brief = value.brief ?? ({ status: "unavailable", count: 0 });
                    root.emitted = value.emitted ?? 0;
                    root.checkedAt = Qt.formatDateTime(new Date(), "HH:mm");
                } catch (error) {
                    root.error = "Alert bridge returned invalid data";
                }
            }
        }
        stderr: StdioCollector { id: alertsErr }
        // stderr finishes after stdout, so any warning on a successful run used
        // to overwrite a good read. Only a nonzero exit is a failure, and a more
        // specific error from stdout wins over the raw stderr tail.
        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            if (exitCode !== 0 && root.error === "")
                root.error = alertsErr.text.trim().split("\n").pop() || "alert bridge failed";
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
