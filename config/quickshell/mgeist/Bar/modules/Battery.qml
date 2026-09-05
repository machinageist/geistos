// Author: Jeff
// Date: 2026-08-21
// Description: Battery level with Waybar's warning and critical thresholds
// Notes: Charging is green here. Waybar coloured it the same as discharging,
//        so the two states were visually identical.

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "root:/Theme"
import "root:/Widgets"

Pill {
    id: root

    readonly property UPowerDevice batt: UPower.displayDevice
    readonly property UPowerDevice physicalBatt: {
        for (const device of UPower.devices.values)
            if (device.isLaptopBattery) return device;
        return batt;
    }
    // UPower reports 0..1 here, not 0..100
    readonly property int percent: batt?.isPresent ? Math.round(batt.percentage * 100) : 0
    readonly property bool charging: batt?.state === UPowerDeviceState.Charging
                                  || batt?.state === UPowerDeviceState.FullyCharged
    readonly property real remainingSeconds: charging ? (batt?.timeToFull ?? 0) : (batt?.timeToEmpty ?? 0)
    readonly property int healthPercent: {
        if (!physicalBatt?.healthSupported) return 0;
        const value = Number(physicalBatt.healthPercentage);
        return Math.round(value <= 1 ? value * 100 : value);
    }
    readonly property string remainingLabel: {
        if (!(remainingSeconds > 0)) return "";
        const hours = Math.floor(remainingSeconds / 3600);
        const minutes = Math.round((remainingSeconds % 3600) / 60);
        return hours > 0 ? `${hours}h${minutes.toString().padStart(2, "0")}` : `${minutes}m`;
    }

    visible: batt?.isPresent ?? false

    accent: charging ? Theme.accentCharging
          : percent <= 15 ? Theme.accentUrgent
          : percent <= 30 ? Theme.yellow
          : Theme.accentBattery
    hoverTitle: charging ? "Battery · charging" : "Battery · discharging"
    hoverDetail: `${percent}% • ${remainingLabel || "time calculating"} ${charging ? "to full" : "remaining"}\n${Number(batt?.changeRate ?? 0).toFixed(1)} W`
    hoverMeterLabel: "Battery health"
    hoverMeterDetail: physicalBatt?.healthSupported ? `${healthPercent}%` : "Not reported"
    hoverMeterValue: physicalBatt?.healthSupported ? healthPercent / 100 : -1
    hoverMeterAccent: healthPercent < 70 ? Theme.red : healthPercent < 85 ? Theme.yellow : Theme.green
    onClicked: Quickshell.execDetached(["qs", "-c", "mgeist", "ipc", "call", "operations", "tab", "power"])

    BarText {
        color: root.accent
        font.family: Theme.iconFontFamily
        text: {
            if (root.charging) return `\uf0e7 ${root.percent}%`;   // nf-fa-bolt
            // Waybar's five discharging icons, empty through full
            const icons = ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"];
            const idx = Math.min(icons.length - 1, Math.floor(root.percent / 20));
            return `${icons[idx]} ${root.percent}%`;
        }
    }
}
