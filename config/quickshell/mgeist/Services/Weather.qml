// Persisted weather state and normalized wttr.in bridge.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string mode: "ip"
    property string query: ""
    property string latitude: ""
    property string longitude: ""
    property string location: "Locating…"
    property var current: ({})
    property var forecast: []
    property string provider: "wttr.in"
    property string error: ""
    property bool busy: false
    property string updatedAt: ""
    signal cardOpenRequested()
    signal settingsOpenRequested()

    function openCard() { root.cardOpenRequested(); }
    function openSettings() { root.settingsOpenRequested(); }

    function save() {
        settings.setText(JSON.stringify({
            mode: root.mode,
            query: root.query,
            latitude: root.latitude,
            longitude: root.longitude
        }, null, 2));
    }

    function setByIp() {
        root.mode = "ip";
        root.save();
        root.refresh();
    }

    function setQuery(value) {
        const clean = String(value).trim();
        if (clean === "") return;
        root.mode = "query";
        root.query = clean;
        root.save();
        root.refresh();
    }

    function setCoordinates(lat, lon) {
        const cleanLat = String(lat).trim();
        const cleanLon = String(lon).trim();
        if (cleanLat === "" || cleanLon === "") return;
        root.mode = "coords";
        root.latitude = cleanLat;
        root.longitude = cleanLon;
        root.save();
        root.refresh();
    }

    function refresh() {
        if (probe.running) return;
        root.busy = true;
        root.error = "";
        probe.command = [
            `${Quickshell.env("HOME")}/dotfiles/scripts/weather-bridge.py`,
            "--mode", root.mode,
            "--query", root.query,
            "--latitude", root.latitude,
            "--longitude", root.longitude
        ];
        probe.running = true;
    }

    FileView {
        id: settings
        path: Quickshell.statePath("weather.json")
        printErrors: false
        onLoaded: {
            try {
                const value = JSON.parse(text());
                root.mode = ["ip", "query", "coords"].includes(value.mode) ? value.mode : "ip";
                root.query = value.query ?? "";
                root.latitude = value.latitude ?? "";
                root.longitude = value.longitude ?? "";
            } catch (error) {
                root.mode = "ip";
            }
            root.refresh();
        }
    }

    Process {
        id: probe
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const value = JSON.parse(text.trim());
                    if (!value.ok) {
                        root.error = value.error ?? "Weather lookup failed";
                        return;
                    }
                    root.provider = value.provider ?? "wttr.in";
                    root.location = value.location || (root.mode === "ip" ? "By IP" : "Configured location");
                    root.current = value.current ?? ({});
                    root.forecast = value.forecast ?? [];
                    root.updatedAt = Qt.formatDateTime(new Date(), "HH:mm");
                    root.error = "";
                } catch (error) {
                    root.error = "Weather response was invalid";
                }
            }
        }
        stderr: StdioCollector { id: probeErr }
        // stderr finishes after stdout, so any warning on a successful run used
        // to overwrite a good read. Only a nonzero exit is a failure, and a more
        // specific error from stdout wins over the raw stderr tail.
        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            if (exitCode !== 0 && root.error === "")
                root.error = probeErr.text.trim().split("\n").pop() || "weather lookup failed";
        }
    }

    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
