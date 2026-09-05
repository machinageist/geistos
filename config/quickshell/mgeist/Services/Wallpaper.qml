// Author: Jeff
// Date: 2026-08-21
// Description: Wallpaper library and hyprpaper control
// Notes: hyprpaper 0.8.4 dropped preload/reload; hyprctl only forwards
//        `wallpaper` and `listactive`, and the empty-monitor form ",path" is
//        ignored, so every monitor has to be named explicitly.
//        Running more than one hyprpaper makes every request fail with
//        "invalid hyprpaper request" — SUPER+W spawns a duplicate each press.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("HOME")}/pictures/wallpaper`

    property var files: []
    property string current: ""
    readonly property int count: files.length

    readonly property string currentName: {
        if (current === "") return "";
        const base = current.split("/").pop();
        return base.replace(/\.[^.]+$/, "");
    }

    readonly property var extensions: ["png", "jpg", "jpeg", "webp"]

    // Build the library once at startup. Extensions are filtered here rather
    // than with find -iregex; passing that regex through as a bare argv entry
    // silently matched nothing.
    Process {
        id: scanner
        command: ["find", root.dir, "-type", "f"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                root.files = text.trim().split("\n")
                    .filter(l => l !== "")
                    .filter(l => root.extensions.includes(l.split(".").pop().toLowerCase()))
                    .sort();
            }
        }

        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("wallpaper scan:", text.trim());
        }
    }

    // Ask hyprpaper what is on screen right now
    Process {
        id: probe
        command: ["hyprctl", "hyprpaper", "listactive"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                // Lines look like "eDP-1: /path/to/image.png"
                const first = text.trim().split("\n")[0] ?? "";
                const idx = first.indexOf(": ");
                if (idx > 0) root.current = first.slice(idx + 2).trim();
            }
        }
    }

    // Re-read what hyprpaper considers active
    function refresh() {
        if (!probe.running) probe.running = true;
    }

    // Put an image on every connected monitor
    function apply(path) {
        if (!path) return;

        for (const m of Hyprland.monitors.values)
            Quickshell.execDetached(["hyprctl", "hyprpaper", "wallpaper", `${m.name},${path}`]);

        root.current = path;
        stateFile.setText(JSON.stringify({ wallpaper: path }, null, 2));
    }

    // Step through the library in order
    function cycle(delta) {
        if (files.length === 0) return;
        const i = files.indexOf(root.current);
        apply(files[(i + delta + files.length) % files.length]);
    }

    // Jump to any other image in the library
    function random() {
        if (files.length < 2) return;
        const pool = files.filter(f => f !== root.current);
        apply(pool[Math.floor(Math.random() * pool.length)]);
    }

    FileView {
        id: stateFile
        path: `${Quickshell.statePath("wallpaper.json")}`
        printErrors: false

        onLoaded: {
            try {
                const saved = JSON.parse(text()).wallpaper;
                // Re-apply so a restart restores the last pick over hyprpaper.conf
                if (saved && saved !== root.current) root.apply(saved);
            } catch (e) {
                // Nothing saved yet; hyprpaper.conf's default stands
            }
        }
    }
}
