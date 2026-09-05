// Bounded read-only status service for the five Geist applications.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var calendar: ({ status: "checking", detail: "Checking calendar…", count: 0, stale: false })
    property var todo: ({ status: "checking", detail: "Checking todo…", count: 0, stale: false })
    property var brief: ({ status: "checking", detail: "Checking brief…", count: 0, stale: false })
    property var vault: ({ status: "checking", detail: "Checking vault…", count: 0, stale: false })
    property var contacts: ({ status: "checking", detail: "Checking contacts…", count: 0, stale: false })
    property string checkedAt: ""
    property string error: ""
    property bool busy: false

    function value(name) {
        switch (name) {
        case "calendar": return root.calendar;
        case "todo": return root.todo;
        case "brief": return root.brief;
        case "vault": return root.vault;
        case "contacts": return root.contacts;
        default: return ({ status: "unavailable", detail: "Unknown Geist application.", count: 0, stale: false });
        }
    }

    function refresh() {
        if (probe.running) return;
        root.busy = true;
        root.error = "";
        probe.running = true;
    }

    Process {
        id: probe
        command: [`${Quickshell.env("HOME")}/dotfiles/scripts/geist-status.py`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(text.trim());
                    const apps = payload.apps ?? {};
                    root.calendar = apps.calendar ?? root.calendar;
                    root.todo = apps.todo ?? root.todo;
                    root.brief = apps.brief ?? root.brief;
                    root.vault = apps.vault ?? root.vault;
                    root.contacts = apps.contacts ?? root.contacts;
                    root.checkedAt = payload.checked_at
                        ? Qt.formatDateTime(new Date(payload.checked_at), "HH:mm:ss") : "";
                } catch (parseError) {
                    root.error = "Status bridge returned invalid data.";
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") root.error = "Status bridge failed safely."
        }
        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            if (exitCode !== 0) root.error = `Status bridge exited ${exitCode}.`;
        }
    }

    Timer {
        interval: 2 * 60 * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
