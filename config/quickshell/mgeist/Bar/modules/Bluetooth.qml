// Author: Jeff
// Date: 2026-08-23
// Description: Bluetooth adapter and connected-device pill
// Notes: The pill opens the shared transparent Quick Settings card.

import QtQuick
import Quickshell.Bluetooth
import "root:/Theme"
import "root:/Widgets"

Pill {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var connectedDevices: adapter ? [...adapter.devices.values].filter(d => d.connected) : []
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool connected: connectedDevices.length > 0

    accent: connected ? Theme.blue : enabled ? Theme.muted : Theme.faint
    bordered: enabled
    hoverTitle: "Bluetooth"
    hoverDetail: !enabled
        ? "Bluetooth disabled — click to open controls"
        : connected
            ? connectedDevices.map(d => d.deviceName || d.name || d.address).join(", ")
            : "Enabled — no connected devices"

    BarText {
        color: root.accent
        font.family: Theme.iconFontFamily
        text: `\uf293${root.connected ? ` ${root.connectedDevices.length}` : ""}`
    }
}
