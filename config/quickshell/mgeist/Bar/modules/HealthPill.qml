// Author: Jeff
// Date: 2026-08-23
// Description: Conditional system-health and updates pill
import QtQuick
import Quickshell
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

Pill {
    id: root
    visible: Health.attention
    accent: Health.severity === 2 ? Theme.red : Theme.yellow
    hoverTitle: "System health"
    hoverDetail: `${Health.updates} updates — ${Health.failedUnits} failed user units — disk ${Health.diskPercent}%`
    onClicked: Quickshell.execDetached(["qs", "-c", "mgeist", "ipc", "call", "operations", "tab", "maintenance"])
    onRightClicked: { Health.refresh(); Telemetry.refresh(); }

    BarText {
        text: Health.severity === 2 ? "\uf071" : `\uf0ab ${Health.updates}`
        color: root.accent
        font.family: Theme.iconFontFamily
    }
}
