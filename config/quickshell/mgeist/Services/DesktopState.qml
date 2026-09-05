// Author: Jeff
// Date: 2026-08-23
// Description: Persisted desktop modes and appearance policy
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool focusMode: false
    property string appearancePolicy: "wallpaper" // manual | wallpaper | schedule
    property int dayHour: 7
    property int nightHour: 19
    property bool quietHours: true
    property int quietStart: 22
    property int quietEnd: 7
    property bool quietActive: false
    property string requestedMode: "auto"
    property bool loaded: false
    signal appearanceRequested(string mode)

    function setFocus(on) { root.focusMode = !!on; save(); }
    function toggleFocus() { setFocus(!root.focusMode); }
    function setPolicy(policy) { root.appearancePolicy = policy; evaluate(); save(); }
    function evaluate() {
        if (!root.loaded) return;
        const h = new Date().getHours();
        root.quietActive = root.quietHours && (root.quietStart > root.quietEnd
            ? (h >= root.quietStart || h < root.quietEnd)
            : (h >= root.quietStart && h < root.quietEnd));
        if (root.appearancePolicy === "wallpaper") root.requestedMode = "auto";
        else if (root.appearancePolicy === "schedule") {
            root.requestedMode = h >= root.dayHour && h < root.nightHour ? "light" : "dark";
        } else return;
        root.appearanceRequested(root.requestedMode);
    }
    function save() {
        state.setText(JSON.stringify({ focusMode, appearancePolicy, dayHour, nightHour, quietHours, quietStart, quietEnd }, null, 2));
    }

    FileView {
        id: state
        path: Quickshell.statePath("desktop-state.json")
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.focusMode = s.focusMode ?? false;
                root.appearancePolicy = s.appearancePolicy ?? "wallpaper";
                root.dayHour = s.dayHour ?? 7;
                root.nightHour = s.nightHour ?? 19;
                root.quietHours = s.quietHours ?? true;
                root.quietStart = s.quietStart ?? 22;
                root.quietEnd = s.quietEnd ?? 7;
            } catch (e) {}
            root.loaded = true;
            root.evaluate();
        }
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.evaluate() }
}
