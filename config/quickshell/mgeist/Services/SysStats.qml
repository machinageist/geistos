// Author: Jeff
// Date: 2026-08-21
// Description: CPU, memory, network, disk, temperature and load from /proc and /sys
// Notes: One shell process per tick gathers everything at once. That is cheaper
//        and far simpler than a FileView per source, and /proc emits no inotify
//        events so watching would not work anyway.
//        Rates are derived from deltas between ticks, never accumulated.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int intervalMs: 500
    // Dense histories keep the pill cards responsive without making them noisy.
    readonly property int historyLength: 180

    // ── Headline values, all 0..1 unless noted ───────────────
    property real cpuUsage: 0
    property var coreUsage: []
    property real memUsage: 0
    property real swapUsage: 0

    property real memTotalKb: 0
    property real memAvailableKb: 0
    property real swapTotalKb: 0
    property real swapFreeKb: 0

    readonly property real memUsedGb: (memTotalKb - memAvailableKb) / 1048576
    readonly property real memTotalGb: memTotalKb / 1048576
    readonly property real swapUsedGb: (swapTotalKb - swapFreeKb) / 1048576
    readonly property real swapTotalGb: swapTotalKb / 1048576

    // Bytes per second
    property real netRxRate: 0
    property real netTxRate: 0
    property real diskReadRate: 0
    property real diskWriteRate: 0

    property real tempC: 0
    property string tempLabel: ""
    property real load1: 0
    property int coreCount: 0

    // ── History, oldest first ────────────────────────────────
    property var cpuHistory: []
    property var memHistory: []
    property var netRxHistory: []
    property var netTxHistory: []

    signal cpuCardRequested()
    signal memoryCardRequested()

    function openCpuCard() { root.cpuCardRequested(); }
    function openMemoryCard() { root.memoryCardRequested(); }

    QtObject {
        id: prev
        property var cpuTotals: ({})
        property var cpuIdles: ({})
        property real netRx: 0
        property real netTx: 0
        property real diskRead: 0
        property real diskWrite: 0
        property real at: 0
    }

    // Append a sample and drop anything past the window
    function push(list, value) {
        const out = [...list, value];
        return out.length > root.historyLength ? out.slice(out.length - root.historyLength) : out;
    }

    // Turn a bytes-per-second figure into something readable
    function rate(bytesPerSecond) {
        const units = ["B", "K", "M", "G"];
        let v = bytesPerSecond;
        let i = 0;
        while (v >= 1024 && i < units.length - 1) {
            v /= 1024;
            i += 1;
        }
        return `${v < 10 ? v.toFixed(1) : Math.round(v)}${units[i]}/s`;
    }

    // ── Section parsers ──────────────────────────────────────

    // Aggregate and per-core usage from /proc/stat deltas
    function parseCpu(text) {
        const totals = {};
        const idles = {};
        const cores = [];

        for (const line of text.split("\n")) {
            if (!line.startsWith("cpu")) continue;

            const parts = line.split(/\s+/);
            const key = parts[0];
            const f = parts.slice(1).map(Number).filter(n => !isNaN(n));
            if (f.length < 5) continue;

            totals[key] = f.reduce((a, b) => a + b, 0);
            idles[key] = f[3] + f[4];
        }

        // First sample only establishes a baseline
        const havePrev = Object.keys(prev.cpuTotals).length > 0;

        if (havePrev) {
            const usageFor = key => {
                const dTotal = totals[key] - prev.cpuTotals[key];
                const dIdle = idles[key] - prev.cpuIdles[key];
                if (!(dTotal > 0)) return 0;
                return Math.max(0, Math.min(1, 1 - dIdle / dTotal));
            };

            root.cpuUsage = usageFor("cpu");

            for (const key of Object.keys(totals)) {
                if (key === "cpu") continue;
                cores.push({ name: key, usage: usageFor(key) });
            }

            cores.sort((a, b) => Number(a.name.slice(3)) - Number(b.name.slice(3)));
            root.coreUsage = cores;
            root.coreCount = cores.length;
            root.cpuHistory = root.push(root.cpuHistory, root.cpuUsage);
        }

        prev.cpuTotals = totals;
        prev.cpuIdles = idles;
    }

    // Memory and swap from /proc/meminfo
    function parseMem(text) {
        for (const line of text.split("\n")) {
            const m = line.match(/^(MemTotal|MemAvailable|SwapTotal|SwapFree):\s+(\d+)/);
            if (!m) continue;

            const v = Number(m[2]);
            if (m[1] === "MemTotal") root.memTotalKb = v;
            else if (m[1] === "MemAvailable") root.memAvailableKb = v;
            else if (m[1] === "SwapTotal") root.swapTotalKb = v;
            else root.swapFreeKb = v;
        }

        root.memUsage = root.memTotalKb > 0
            ? (root.memTotalKb - root.memAvailableKb) / root.memTotalKb
            : 0;
        root.swapUsage = root.swapTotalKb > 0
            ? (root.swapTotalKb - root.swapFreeKb) / root.swapTotalKb
            : 0;
        root.memHistory = root.push(root.memHistory, root.memUsage);
    }

    // Interface totals from /proc/net/dev, skipping loopback and virtual devices
    function parseNet(text, dt) {
        let rx = 0;
        let tx = 0;

        for (const line of text.split("\n")) {
            const m = line.match(/^\s*([\w-]+):\s*(.*)$/);
            if (!m) continue;

            const name = m[1];
            if (name === "lo" || name.startsWith("docker") || name.startsWith("veth")
                || name.startsWith("br-") || name.startsWith("virbr")) continue;

            const f = m[2].split(/\s+/).map(Number);
            rx += f[0] || 0;
            tx += f[8] || 0;
        }

        if (prev.netRx > 0 && dt > 0) {
            root.netRxRate = Math.max(0, (rx - prev.netRx) / dt);
            root.netTxRate = Math.max(0, (tx - prev.netTx) / dt);
            root.netRxHistory = root.push(root.netRxHistory, root.netRxRate);
            root.netTxHistory = root.push(root.netTxHistory, root.netTxRate);
        }

        prev.netRx = rx;
        prev.netTx = tx;
    }

    // Sector counts from /proc/diskstats for whole devices only
    function parseDisk(text, dt) {
        let read = 0;
        let write = 0;

        for (const line of text.split("\n")) {
            const f = line.trim().split(/\s+/);
            if (f.length < 10) continue;

            const name = f[2];
            // Whole devices only; partitions would double-count
            if (!/^(sd[a-z]|nvme\d+n\d+|mmcblk\d+)$/.test(name)) continue;

            read += Number(f[5]) || 0;
            write += Number(f[9]) || 0;
        }

        // /proc/diskstats counts 512-byte sectors
        if (prev.diskRead > 0 && dt > 0) {
            root.diskReadRate = Math.max(0, (read - prev.diskRead) * 512 / dt);
            root.diskWriteRate = Math.max(0, (write - prev.diskWrite) * 512 / dt);
        }

        prev.diskRead = read;
        prev.diskWrite = write;
    }

    // Hottest thermal zone, which on this machine is the CPU package
    function parseTemp(text) {
        let best = 0;
        let label = "";

        for (const line of text.split("\n")) {
            const parts = line.trim().split(" ");
            if (parts.length < 2) continue;

            const c = Number(parts[1]) / 1000;
            if (!isFinite(c) || c <= 0 || c > 150) continue;

            if (c > best) {
                best = c;
                label = parts[0];
            }
        }

        root.tempC = best;
        root.tempLabel = label;
    }

    Process {
        id: sampler
        running: true

        command: ["sh", "-c",
            "cat /proc/stat; echo @@; cat /proc/meminfo; echo @@; cat /proc/net/dev; " +
            "echo @@; cat /proc/diskstats; echo @@; " +
            "for f in /sys/class/thermal/thermal_zone*; do " +
            "echo \"$(cat $f/type 2>/dev/null) $(cat $f/temp 2>/dev/null)\"; done; " +
            "echo @@; cat /proc/loadavg"]

        stdout: StdioCollector {
            onStreamFinished: {
                const now = Date.now();
                const dt = prev.at > 0 ? (now - prev.at) / 1000 : 0;
                const s = text.split("@@\n");
                if (s.length < 6) return;

                root.parseCpu(s[0]);
                root.parseMem(s[1]);
                root.parseNet(s[2], dt);
                root.parseDisk(s[3], dt);
                root.parseTemp(s[4]);
                root.load1 = Number(s[5].trim().split(/\s+/)[0]) || 0;

                prev.at = now;
            }
        }
    }

    Timer {
        interval: root.intervalMs
        running: true
        repeat: true
        onTriggered: if (!sampler.running) sampler.running = true
    }
}
