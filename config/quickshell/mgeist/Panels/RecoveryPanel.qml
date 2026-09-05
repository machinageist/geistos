// Author: Jeff
// Date: 2026-08-23
// Description: Desktop diagnostics and bounded recovery controls
import QtQuick
import Quickshell
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

PopupPanel {
    id: root
    cardWidth: 520
    placement: "center"
    readonly property var actions: [
        { label: "Restart Quickshell", glyph: "\uf021", command: ["sh", "-c", "qs -c mgeist kill; qs -c mgeist -d -n"] },
        { label: "Restart wallpaper service", glyph: "\uf03e", command: ["sh", "-c", "pkill -x hyprpaper; hyprpaper"] },
        { label: "Restart PipeWire", glyph: "\uf028", command: ["systemctl", "--user", "restart", "pipewire", "pipewire-pulse", "wireplumber"] },
        { label: "Restart NetworkManager", glyph: "\uf1eb", command: ["systemctl", "restart", "NetworkManager"] },
        { label: "Refresh health checks", glyph: "\uf0ae", health: true }
    ]

    Column {
        width: parent.width
        spacing: 8
        BarText { text: "Desktop recovery"; color: Theme.red; font.bold: true }
        BarText { text: `Theme ${Theme.name} • wallpaper ${Wallpaper.currentName}`; color: Theme.muted }
        BarText { text: `CPU ${Math.round(SysStats.cpuUsage * 100)}% • memory ${Math.round(SysStats.memUsage * 100)}% • disk ${Health.diskPercent}%`; color: Theme.muted }
        BarText { text: `${Health.updates} updates • ${Health.failedUnits} failed user services`; color: Health.attention ? Theme.yellow : Theme.green }
        Repeater {
            model: root.actions
            Rectangle {
                required property var modelData
                width: parent.width; height: 38; radius: Theme.popupRadius
                color: hit.containsMouse ? Qt.alpha(Theme.red, 0.12) : "transparent"
                Row { anchors.fill: parent; anchors.leftMargin: 10; spacing: 10
                    BarText { anchors.verticalCenter: parent.verticalCenter; text: modelData.glyph; color: Theme.red; font.family: Theme.iconFontFamily }
                    BarText { anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: Theme.fg }
                }
                MouseArea {
                    id: hit; anchors.fill: parent; hoverEnabled: true
                    onClicked: {
                        if (modelData.health) Health.refresh();
                        else Quickshell.execDetached(modelData.command);
                        root.close();
                    }
                }
            }
        }
    }
}
