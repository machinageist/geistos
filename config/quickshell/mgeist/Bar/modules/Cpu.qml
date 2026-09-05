// Author: Jeff
// Date: 2026-08-21
// Description: CPU usage, click opens btop
// Notes: Click action carried over from Waybar's "on-click": "ghostty -e btop"

import QtQuick
import Quickshell
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

Pill {
    id: root
    accent: Theme.accentCpu
    hoverTitle: "CPU usage"
    hoverDetail: `${Math.round(SysStats.cpuUsage * 100)}% across ${SysStats.coreCount} cores`
    hoverCardWidth: 330
    hoverMeterLabel: "Current CPU load"
    hoverMeterDetail: `${Math.round(SysStats.cpuUsage * 100)}%`
    hoverMeterValue: SysStats.cpuUsage
    hoverMeterAccent: Theme.accentCpu
    hoverMeterWarnOnHigh: true
    hoverGraphValues: SysStats.cpuHistory
    hoverGraphStroke: Theme.accentCpu
    onClicked: Quickshell.execDetached(["ghostty", "-e", "btop"])

    Connections {
        target: SysStats
        function onCpuCardRequested() { root.pinHoverCard(); }
    }

    BarText {
        color: Theme.accentCpu
        font.family: Theme.iconFontFamily
        text: `\uf4bc ${Math.round(SysStats.cpuUsage * 100)}%`   // nf-oct-cpu
    }
}
