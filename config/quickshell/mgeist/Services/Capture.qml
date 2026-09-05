// Author: Jeff
// Date: 2026-08-23
// Description: Screenshot and optional recording workflow
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool recording: false
    readonly property string dir: `${Quickshell.env("HOME")}/pictures/screenshots`

    function run(script, title) {
        Quickshell.execDetached(["sh", "-c", `mkdir -p '${root.dir}'; ${script}`]);
        Osd.show("\uf030", title, root.dir, -1, "purple");
    }
    function regionFile() { run(`grim -g "$(slurp)" '${dir}/$(date +%Y%m%d_%H%M%S).png'`, "Region captured"); }
    function regionClipboard() { run(`grim -g "$(slurp)" - | wl-copy`, "Region copied"); }
    function screenFile() { run(`grim '${dir}/$(date +%Y%m%d_%H%M%S).png'`, "Screen captured"); }
    function screenClipboard() { run(`grim - | wl-copy`, "Screen copied"); }
    function windowFile() { run(`g=$(hyprctl activewindow -j | python -c 'import json,sys;d=json.load(sys.stdin);a=d["at"];s=d["size"];print(f"{a[0]},{a[1]} {s[0]}x{s[1]}")'); grim -g "$g" '${dir}/$(date +%Y%m%d_%H%M%S).png'`, "Window captured"); }
    function toggleRecording() {
        if (root.recording) {
            Quickshell.execDetached(["pkill", "-INT", "wf-recorder"]);
            root.recording = false;
            Osd.show("\uf04d", "Recording saved", root.dir, -1, "red");
        } else {
            recorderProbe.running = true;
        }
    }

    Process {
        id: recorderProbe
        command: ["sh", "-c", "command -v wf-recorder >/dev/null"]
        onExited: code => {
            if (code !== 0) {
                Osd.show("\uf071", "Recorder unavailable", "Install wf-recorder to enable recording", -1, "yellow");
                return;
            }
            Quickshell.execDetached(["sh", "-c", `mkdir -p '${root.dir}'; wf-recorder -f '${root.dir}/recording_$(date +%Y%m%d_%H%M%S).mp4'`]);
            root.recording = true;
            Osd.show("\uf03d", "Recording started", "Use Capture again to stop", -1, "red");
        }
    }
}
