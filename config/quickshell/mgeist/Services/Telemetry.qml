// Author: Jeff
// Date: 2026-08-23
// Description: Normalized AI, maintenance and security telemetry
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var snapshot: ({})
    property string error: ""
    property bool busy: false
    property string updatedAt: "never"

    readonly property var ai: snapshot.ai ?? ({})
    readonly property var today: ai.today ?? ({})
    readonly property var week: ai.week ?? ({})
    readonly property var month: ai.month ?? ({})
    readonly property var openAiToday: today.openai ?? ({})
    readonly property var anthropicToday: today.anthropic ?? ({})
    readonly property var system: snapshot.system ?? ({})

    function refresh() {
        if (probe.running) return;
        root.busy = true;
        root.error = "";
        probe.running = true;
    }

    function money(provider) {
        const actual = Number(provider?.actualCostUsd ?? 0);
        const estimated = Number(provider?.estimatedCostUsd ?? 0);
        if (actual > 0) return `$${actual.toFixed(2)} billed`;
        if (estimated > 0) return `~$${estimated.toFixed(2)}`;
        return provider?.billing?.includes("subscription") ? "$0 metered" : "$0.00";
    }

    function tokens(value) {
        const n = Number(value ?? 0);
        if (n >= 1000000000) return `${(n / 1000000000).toFixed(1)}B`;
        if (n >= 1000000) return `${(n / 1000000).toFixed(1)}M`;
        if (n >= 1000) return `${(n / 1000).toFixed(1)}K`;
        return `${n}`;
    }

    Process {
        id: probe
        command: [`${Quickshell.env("HOME")}/dotfiles/scripts/desktop-telemetry.py`]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.snapshot = JSON.parse(text);
                    root.updatedAt = Qt.formatDateTime(new Date(), "HH:mm");
                    root.error = "";
                } catch (e) {
                    root.error = "telemetry unavailable";
                }
                root.busy = false;
            }
        }
        stderr: StdioCollector { id: telemetryErr }
        // stderr finishes after stdout, so any warning on a successful run used
        // to overwrite a good read. Only a nonzero exit is a failure, and a more
        // specific error from stdout wins over the raw stderr tail.
        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            if (exitCode !== 0 && root.error === "")
                root.error = telemetryErr.text.trim().split("\n").pop() || "telemetry unavailable";
        }
    }

    Timer {
        interval: 5 * 60000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
