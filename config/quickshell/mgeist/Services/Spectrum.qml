// Author: Jeff
// Date: 2026-08-21
// Description: Audio spectrum from cava, with a PipeWire level meter fallback
// Notes: cava does the FFT; Quickshell cannot. cava is driven in raw ASCII mode
//        writing to stdout, one semicolon-separated frame per line, which
//        SplitParser reads a frame at a time.
//        When cava is absent the analyser falls back to PwNodePeakMonitor,
//        which is per-channel peak level, not a spectrum — honest but coarse.

pragma Singleton

import QtQuick
import "root:/Theme"
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property int bars: 64
    readonly property int framerate: 30

    // Whether cava is installed; drives which renderer the panel uses
    property bool cavaAvailable: false
    property bool running: true

    // 0..1 per bar, low frequency first
    property var levels: new Array(root.bars).fill(0)

    readonly property string configPath: `${Quickshell.cachePath("cava.conf")}`

    // cava captures the default *source* unless told otherwise, which is the
    // microphone. What we want is the current sink's monitor.
    readonly property string monitorSource: root.sink ? `${root.sink.name}.monitor` : ""

    readonly property string configBody: `[general]
bars = ${root.bars}
framerate = ${root.framerate}
autosens = 1

[input]
method = pulse
source = ${root.monitorSource}

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
channels = mono

[smoothing]
noise_reduction = 40
`

    // ── Fallback: PipeWire peak level ────────────────────────
    readonly property PwNode sink: Pipewire.defaultAudioSink

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    PwNodePeakMonitor {
        id: peaks
        node: root.sink
        enabled: root.running && !root.cavaAvailable
    }

    // Spread a single peak level across the bars so the fallback still reads as
    // a meter rather than a flat line
    Timer {
        interval: 1000 / root.framerate
        running: root.running && !root.cavaAvailable
        repeat: true

        onTriggered: {
            const p = Math.max(0, Math.min(1, peaks.peak));
            const out = [];

            for (let i = 0; i < root.bars; i++) {
                // Weight the middle bars so it looks like a level, not a wall
                const centre = 1 - Math.abs(i - (root.bars - 1) / 2) / ((root.bars - 1) / 2);
                out.push(Math.max(0, Math.min(1, p * (0.45 + 0.55 * centre))));
            }

            root.levels = out;
        }
    }

    // ── Frequency-colored EQ bins ─────────────────────────────
    // Color each bar from red (lowest freq) to violet (highest freq)
    // for high contrast against the dark bar background.
    // Spectrum has 64 bars; we map each index to a color in the visible spectrum.
    property var colors: {
        // Read through Theme so the spectrum follows all 38 palettes. These were
        // six Dracula hex literals, the one place in the shell that never
        // changed with the theme.
        const stops = [
            Theme.red, Theme.orange, Theme.yellow,
            Theme.green, Theme.cyan, Theme.purple, Theme.purple
        ];
        const out = [];
        for (let i = 0; i < root.bars; i++) {
            const proportion = root.bars > 1 ? i / (root.bars - 1) : 0;
            const at = proportion * (stops.length - 1);
            const lower = stops[Math.floor(at)];
            const upper = stops[Math.ceil(at)];
            const blend = at - Math.floor(at);
            // Qt colour components are 0..1 floats, so no hex round-tripping
            out.push(Qt.rgba(
                lower.r + (upper.r - lower.r) * blend,
                lower.g + (upper.g - lower.g) * blend,
                lower.b + (upper.b - lower.b) * blend,
                1
            ));
        }
        return out;
    }

// ── cava ─────────────────────────────────────────────────
    FileView {
        id: configFile
        path: root.configPath
        printErrors: false
    }

    Process {
        id: probe
        command: ["sh", "-c", "command -v cava >/dev/null && echo yes || echo no"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.cavaAvailable = text.trim() === "yes"
        }
    }

    Process {
        id: cava

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: line => {
                if (line === "") return;

                const parts = line.split(";").filter(v => v !== "");
                if (parts.length === 0) return;

                root.levels = parts.map(v => Math.max(0, Math.min(1, Number(v) / 100)));
            }
        }

        onExited: if (root.running && root.cavaAvailable) restart.start()
    }

    // cava exits if the audio device disappears; come back rather than going dead
    Timer {
        id: restart
        interval: 2000
        onTriggered: if (root.running) root.startCava()
    }

    onCavaAvailableChanged: if (root.cavaAvailable && root.running) root.startCava()

    // Launch cava against the freshly written config
    function startCava() {
        if (!root.cavaAvailable || root.monitorSource === "") return;
        configFile.setText(root.configBody);
        cava.running = false;
        cava.command = ["cava", "-p", root.configPath];
        cava.running = true;
    }

    // Follow the default sink; the monitor source name changes with it
    onMonitorSourceChanged: if (root.running && root.cavaAvailable) root.startCava()

    // Begin analysing; only worth running while something is watching
    function start() {
        root.running = true;
        if (root.cavaAvailable) root.startCava();
    }

    // Stop analysing and clear the bars
    function stop() {
        root.running = false;
        cava.running = false;
        restart.stop();
        root.levels = new Array(root.bars).fill(0);
    }

    // Re-check whether cava has been installed since startup
    function refresh() {
        if (!probe.running) probe.running = true;
    }
}
