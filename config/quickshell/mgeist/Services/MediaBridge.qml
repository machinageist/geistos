// Author: Jeff
// Date: 2026-08-23
// Description: Quickshell bridge for rmpc/MPD and cliamp playback
// Notes: Both CLIs remain the source of truth; Quickshell polls their machine-readable
//        status and sends transport commands without taking over the terminal.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string backend: ""
    property string state: ""
    property string artist: ""
    property string title: ""
    property real elapsed: 0
    property real duration: 0
    property bool available: false
    signal audioCardRequested()
    readonly property bool playing: state === "play" || state === "playing"
    readonly property string label: artist !== "" ? `${artist} — ${title}` : title

    function refresh() {
        if (!rmpcStatus.running) rmpcStatus.running = true;
        if (!cliampStatus.running) cliampStatus.running = true;
    }

    function chooseRmpc(data) {
        if (!data || !data.state) return;
        root.backend = "rmpc";
        root.state = String(data.state).toLowerCase();
        const song = data.song || {};
        root.artist = song.artist || song["Artist"] || "";
        root.title = song.title || song["Title"] || song.file || "";
        root.elapsed = data.elapsed?.secs || 0;
        root.duration = data.duration?.secs || 0;
        root.available = data.state !== "Stop";
    }

    function chooseCliamp(data) {
        if (!data || (!data.state && !data.status && !data.title)) return;
        root.backend = "cliamp";
        root.state = String(data.state || data.status || "").toLowerCase();
        root.artist = data.artist || data.track_artist || "";
        root.title = data.title || data.track_title || data.track || "";
        root.elapsed = Number(data.elapsed || data.position || 0);
        root.duration = Number(data.duration || 0);
        root.available = true;
    }

    function command(args) {
        const bin = root.backend === "cliamp" ? "cliamp" : "rmpc";
        Quickshell.execDetached([bin, ...args]);
        refreshTimer.restart();
    }

    function toggle() {
        command([root.backend === "cliamp" ? "toggle" : "togglepause"]);
        Osd.show(root.playing ? "\uf04c" : "\uf04b", root.playing ? "Pause" : "Play",
            root.label || root.backend || "Media", -1, "purple");
    }
    function next() {
        command(["next"]);
        Osd.show("\uf051", "Next track", root.label || root.backend, -1, "purple");
    }
    function previous() {
        command([root.backend === "cliamp" ? "prev" : "prev"]);
        Osd.show("\uf048", "Previous track", root.label || root.backend, -1, "purple");
    }
    function seek(seconds) {
        if (!root.available || root.duration <= 0) return;
        const target = Math.max(0, Math.min(root.duration, Number(seconds)));
        command(["seek", String(Math.round(target))]);
        root.elapsed = target;
    }
    function open() {
        root.audioCardRequested();
    }

    Timer {
        id: refreshTimer
        interval: 1500
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: rmpcStatus
        command: ["rmpc", "status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.chooseRmpc(JSON.parse(text)); } catch (e) {}
            }
        }
    }

    Process {
        id: cliampStatus
        command: ["cliamp", "status", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.chooseCliamp(JSON.parse(text)); } catch (e) {}
            }
        }
    }
}
