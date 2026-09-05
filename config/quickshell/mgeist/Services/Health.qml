// Author: Jeff
// Date: 2026-08-23
// Description: Actionable system-health summary
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property int updates: 0
    property int failedUnits: 0
    property int diskPercent: 0
    property string lastChecked: "never"
    property bool busy: false
    /// A probe reported -1 because the command it needs is missing. Distinct from
    /// a genuine zero, which would otherwise read as "everything is fine".
    property bool unavailable: false
    readonly property bool attention: unavailable
        || updates > 0 || failedUnits > 0 || diskPercent >= 90
    readonly property int severity: unavailable || failedUnits > 0 || diskPercent >= 95
        ? 2 : attention ? 1 : 0

    function refresh() { if (!probe.running) { root.busy = true; probe.running = true; } }

    Process {
        id: probe
        // A missing tool must not read as a healthy zero, so each probe reports -1
        // when the command it needs is absent rather than counting nothing.
        command: ["sh", "-c", "if command -v checkupdates >/dev/null 2>&1; then u=$(checkupdates 2>/dev/null | wc -l); else u=-1; fi; if command -v systemctl >/dev/null 2>&1; then f=$(systemctl --user --failed --no-legend 2>/dev/null | wc -l); else f=-1; fi; d=$(df -P / 2>/dev/null | tail -1 | tr -s ' ' | cut -d' ' -f5 | tr -d '%'); printf '%s|%s|%s' \"$u\" \"$f\" \"${d:--1}\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split("|");
                const read = value => {
                    const parsed = Number(value);
                    return Number.isFinite(parsed) ? parsed : -1;
                };
                root.updates = read(p[0]);
                root.failedUnits = read(p[1]);
                root.diskPercent = read(p[2]);
                root.unavailable = root.updates < 0 || root.failedUnits < 0 || root.diskPercent < 0;
                root.lastChecked = Qt.formatDateTime(new Date(), "HH:mm");
                root.busy = false;
            }
        }
    }

    Timer { interval: 15 * 60000; running: true; repeat: true; onTriggered: root.refresh() }
}
