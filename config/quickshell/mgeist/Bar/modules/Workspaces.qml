// Author: Jeff
// Date: 2026-08-21
// Description: Workspace pills driven by Hyprland's IPC model
// Notes: Left-click activates, matching Waybar's "on-click": "activate"

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

Row {
    id: root
    spacing: Theme.moduleSpacing
    anchors.verticalCenter: parent?.verticalCenter ?? undefined

    function identity(id) {
        const map = {
            1: { glyph: "\uf120", label: "Develop", mode: "focus" },
            2: { glyph: "\uf269", label: "Research", mode: "normal" },
            3: { glyph: "\uf086", label: "Communicate", mode: "normal" },
            4: { glyph: "\uf001", label: "Media", mode: "media" }
        };
        return map[id] || { glyph: String(id), label: `Workspace ${id}`, mode: "normal" };
    }

    Repeater {
        // Hyprland reports workspaces unordered; Waybar sorted by number
        model: ScriptModel {
            values: [...Hyprland.workspaces.values]
                .filter(ws => ws.id > 0)
                .sort((a, b) => a.id - b.id)
        }

        Pill {
            id: pill
            required property HyprlandWorkspace modelData

            readonly property bool isActive: modelData.focused
            readonly property bool isUrgent: modelData.urgent
            readonly property var identity: root.identity(modelData.id)
            readonly property int windowCount: [...Hyprland.toplevels.values].filter(t => t.workspace?.id === modelData.id).length

            accent: isUrgent ? Theme.accentUrgent
                  : isActive ? Theme.accentWorkspace
                  : Theme.muted
            bordered: isActive || isUrgent
            hoverTitle: identity.label
            hoverDetail: `${windowCount} window${windowCount === 1 ? "" : "s"} — ${identity.mode} workspace`

            onClicked: {
                modelData.activate();
                DesktopState.setFocus(identity.mode === "focus");
                Osd.show(identity.glyph, identity.label,
                    identity.mode === "focus" ? "Focus mode enabled" : "Normal desktop mode",
                    -1, identity.mode === "focus" ? "purple" : "accent");
            }

            BarText {
                text: modelData.id
                font.family: Theme.fontFamily
                color: pill.isUrgent ? Theme.accentUrgent
                     : pill.isActive ? Theme.accentWorkspace
                     : Theme.muted

                Behavior on color {
                    ColorAnimation { duration: Theme.animFast }
                }
            }
        }
    }
}
