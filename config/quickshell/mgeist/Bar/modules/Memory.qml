// Author: Jeff
// Date: 2026-08-21
// Description: Memory usage, click opens htop
// Notes: Percentage is (MemTotal - MemAvailable) / MemTotal, as Waybar computed it

import QtQuick
import Quickshell
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

Pill {
    id: root
    accent: Theme.accentMemory
    hoverTitle: "Memory usage"
    hoverDetail: `${Math.round(SysStats.memUsage * 100)}% — ${SysStats.memUsedGb.toFixed(1)} / ${SysStats.memTotalGb.toFixed(1)} GiB`
    hoverCardWidth: 330
    hoverMeterLabel: "Memory in use"
    hoverMeterDetail: `${SysStats.memUsedGb.toFixed(1)} / ${SysStats.memTotalGb.toFixed(1)} GiB`
    hoverMeterValue: SysStats.memUsage
    hoverMeterAccent: Theme.accentMemory
    hoverMeterWarnOnHigh: true
    hoverGraphValues: SysStats.memHistory
    hoverGraphStroke: Theme.accentMemory
    onClicked: Quickshell.execDetached(["ghostty", "-e", "htop"])

    Connections {
        target: SysStats
        function onMemoryCardRequested() { root.pinHoverCard(); }
    }

    BarText {
        color: Theme.accentMemory
        font.family: Theme.iconFontFamily
        text: `\udb80\udf5b ${Math.round(SysStats.memUsage * 100)}%`   // nf-md-memory
    }
}
