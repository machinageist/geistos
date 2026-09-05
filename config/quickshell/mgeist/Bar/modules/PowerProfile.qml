// Author: Jeff
// Date: 2026-08-21
// Description: Power profile indicator, click cycles through available profiles
// Notes: Waybar only displayed the profile; clicking to cycle is new

import QtQuick
import Quickshell.Services.UPower
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

Pill {
    id: root
    accent: Theme.accentPower
    bordered: false
    hoverTitle: "Power profile"
    hoverDetail: PowerProfiles.profile === PowerProfile.Performance
        ? "Performance mode"
        : PowerProfiles.profile === PowerProfile.PowerSaver ? "Power saver mode" : "Balanced mode"

    // Performance is absent on some machines, so build the ring from what exists
    readonly property var ring: PowerProfiles.hasPerformanceProfile
        ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
        : [PowerProfile.PowerSaver, PowerProfile.Balanced]

    onClicked: {
        const i = ring.indexOf(PowerProfiles.profile);
        PowerProfiles.profile = ring[(i + 1) % ring.length];
        Qt.callLater(() => Osd.show("\uf0e7", "Power profile", root.hoverDetail, -1, "green"));
    }

    BarText {
        color: Theme.accentPower
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.fontSize
        text: {
            switch (PowerProfiles.profile) {
                case PowerProfile.Performance: return "\uf0e7";   // nf-fa-bolt
                case PowerProfile.PowerSaver:  return "\uf06c";   // nf-fa-leaf
                default:                       return "\udb81\uddd1";        // nf-md-scale_balance
            }
        }
    }
}
