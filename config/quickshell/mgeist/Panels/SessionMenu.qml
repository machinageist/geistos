// Author: Jeff
// Date: 2026-08-21
// Description: Lock, logout, suspend, reboot, power off
// Notes: Destructive entries ask for a second click rather than firing on the
//        first, since this panel is one keystroke away.

import QtQuick
import Quickshell
import "root:/Theme"
import "root:/Widgets"

PopupPanel {
    id: root

    cardWidth: 420
    placement: "center"

    property string armed: ""

    onOpenedChanged: if (!open) root.armed = ""

    readonly property var entries: [
        { key: "lock",     label: "Lock",      glyph: "\uf023", accent: Theme.cyan,   confirm: false, cmd: ["hyprlock", "--config", `${Quickshell.env("HOME")}/.config/hyprlock/quickshell.conf`] },
        { key: "suspend",  label: "Suspend",   glyph: "\uf186", accent: Theme.blue,   confirm: false, cmd: ["systemctl", "suspend"] },
        { key: "logout",   label: "Log out",   glyph: "\uf2f5", accent: Theme.orange, confirm: true,  cmd: ["hyprctl", "dispatch", "exit"] },
        { key: "reboot",   label: "Reboot",    glyph: "\uf021", accent: Theme.yellow, confirm: true,  cmd: ["systemctl", "reboot"] },
        { key: "poweroff", label: "Power off", glyph: "\uf011", accent: Theme.red,    confirm: true,  cmd: ["systemctl", "poweroff"] }
    ]

    // Fire an entry, arming it first when it needs confirming
    function invoke(entry) {
        if (entry.confirm && root.armed !== entry.key) {
            root.armed = entry.key;
            return;
        }

        root.close();
        Quickshell.execDetached(entry.cmd);
    }

    Column {
        width: parent.width
        spacing: 6

        Repeater {
            model: root.entries

            Rectangle {
                id: row
                required property var modelData

                readonly property bool isArmed: root.armed === modelData.key

                width: parent.width
                height: 44
                radius: Theme.popupRadius
                color: hover.containsMouse || isArmed ? Qt.alpha(modelData.accent, 0.14) : "transparent"
                border.width: isArmed ? 1 : 0
                border.color: Theme.edge(modelData.accent)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.modulePadH + 4
                    spacing: 12

                    BarText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.glyph
                        color: row.modelData.accent
                        font.pixelSize: Theme.iconSize
                    }

                    BarText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.isArmed ? `${row.modelData.label} — click again` : row.modelData.label
                        color: row.isArmed ? row.modelData.accent : Theme.fg
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.invoke(row.modelData)
                }
            }
        }
    }
}
