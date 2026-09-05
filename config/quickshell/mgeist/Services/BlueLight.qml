// Blue-light filter state and hyprsunset integration.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: false
    property bool autoShift: false
    property int temperature: 3500
    property int dayTemperature: 4000
    property int nightTemperature: 2700
    property int dayHour: 7
    property int nightHour: 19
    property bool loaded: false
    signal appearanceCardRequested()

    function openAppearanceCard() { root.appearanceCardRequested(); }

    readonly property bool nightNow: {
        const hour = new Date().getHours();
        return hour >= root.nightHour || hour < root.dayHour;
    }

    function apply() {
        // hyprsunset is a single long-running CTM manager. Starting another
        // instance unlinks the live daemon's IPC socket before the duplicate
        // exits, so all runtime changes must go through hyprctl instead.
        if (!root.active) {
            Quickshell.execDetached(["hyprctl", "hyprsunset", "identity"]);
            return;
        }
        Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(root.temperature)]);
    }

    function save() {
        stateFile.setText(JSON.stringify({
            active: root.active,
            autoShift: root.autoShift,
            temperature: root.temperature,
            dayTemperature: root.dayTemperature,
            nightTemperature: root.nightTemperature,
            dayHour: root.dayHour,
            nightHour: root.nightHour
        }, null, 2));
    }

    function toggle() {
        root.active = !root.active;
        if (root.active && root.autoShift)
            root.temperature = root.nightNow ? root.nightTemperature : root.dayTemperature;
        root.apply();
        root.save();
    }

    function setTemperature(value) {
        root.temperature = Math.max(1800, Math.min(4000, Math.round(Number(value))));
        root.active = true;
        root.apply();
        root.save();
    }

    function adjust(delta) {
        root.setTemperature(root.temperature + delta);
    }

    function setAutoShift(enabled) {
        root.autoShift = enabled;
        if (enabled) {
            root.active = true;
            root.temperature = root.nightNow ? root.nightTemperature : root.dayTemperature;
            root.apply();
        }
        root.save();
    }

    function updateAuto() {
        if (!root.autoShift) return;
        const wanted = root.nightNow ? root.nightTemperature : root.dayTemperature;
        if (!root.active || root.temperature !== wanted) {
            root.active = true;
            root.temperature = wanted;
            root.apply();
            root.save();
        }
    }

    FileView {
        id: stateFile
        path: Quickshell.statePath("blue-light.json")
        printErrors: false
        onLoaded: {
            try {
                const value = JSON.parse(text());
                root.active = Boolean(value.active);
                root.autoShift = Boolean(value.autoShift);
                root.temperature = Math.max(1800, Math.min(4000, Number(value.temperature) || 3500));
                root.dayTemperature = Math.max(1800, Math.min(4000, Number(value.dayTemperature) || 4000));
                root.nightTemperature = Math.max(1800, Math.min(4000, Number(value.nightTemperature) || 2700));
                root.dayHour = Math.max(0, Math.min(23, Number(value.dayHour) || 7));
                root.nightHour = Math.max(0, Math.min(23, Number(value.nightHour) || 19));
            } catch (error) {
                // Keep safe defaults when no state has been saved yet.
            }
            root.loaded = true;
            if (root.autoShift) root.updateAuto();
            else if (root.active) root.apply();
        }
    }

    Timer {
        interval: 60 * 1000
        repeat: true
        running: true
        onTriggered: root.updateAuto()
    }
}
