// Author: Jeff
// Date: 2026-08-21
// Description: Wi-Fi SSID or wired link, click opens Quickshell Quick Settings
// Notes: The same transparent popup exposes networks, adapters and live rates.

import QtQuick
import Quickshell
import Quickshell.Networking
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

Pill {
    id: root

    hoverGraphValues: SysStats.netRxHistory
    hoverGraphStroke: Theme.cyan
    hoverGraphMaxValue: 0
    hoverGraphValues2: SysStats.netTxHistory
    hoverGraphStroke2: Theme.blue
    hoverGraphMaxValue2: 0
    readonly property var wifi: {
        for (const d of Networking.devices.values)
            if (d.type === DeviceType.Wifi && d.connected) return d;
        return null;
    }

    readonly property var wired: {
        for (const d of Networking.devices.values)
            if (d.type === DeviceType.Wired && d.connected) return d;
        return null;
    }

    readonly property bool online: wifi !== null || wired !== null

    accent: online ? Theme.accentNetwork : Theme.accentUrgent
    hoverTitle: "Network"
    hoverDetail: root.wifi
        ? `Wi-Fi: ${root.wifi.networks.values.find(n => n.connected)?.name ?? "connected"} — down ${SysStats.rate(SysStats.netRxRate)} / up ${SysStats.rate(SysStats.netTxRate)}`
        : root.wired ? `Wired connection — down ${SysStats.rate(SysStats.netRxRate)} / up ${SysStats.rate(SysStats.netTxRate)}` : "Offline"

    BarText {
        color: root.accent
        font.family: Theme.iconFontFamily
        text: {
            if (root.wifi) {
                const ssid = root.wifi.networks.values.find(n => n.connected)?.name ?? "wifi";
                return `\uf1eb ${ssid}`;        // nf-fa-wifi
            }
            if (root.wired) return "\uf6ff";    // nf-md-ethernet
            return "\uf127";                    // nf-fa-chain_broken
        }
    }
}
