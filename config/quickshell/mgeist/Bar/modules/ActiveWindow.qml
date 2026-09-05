// Author: Jeff
// Date: 2026-08-21
// Description: Focused window title
// Notes: Reproduces Waybar's rewrite rule "(.*) - (.*)" -> "$1" and 50-char clamp

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "root:/Theme"
import "root:/Widgets"

Item {
    id: root
    implicitWidth: label.implicitWidth
    implicitHeight: Theme.pillHeight

    readonly property string title: Hyprland.activeToplevel?.title ?? ""

    BarText {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.accentWindow
        elide: Text.ElideRight
        // Two leading spaces, matching Waybar's "  {title}"
        text: root.title === "" ? "" : "  " + strip(root.title)

        // Drop trailing " - App Name" the way Waybar's rewrite did
        function strip(raw) {
            const cut = raw.replace(/^(.*) - (.*)$/, "$1");
            return cut.length > 50 ? cut.slice(0, 49) + "…" : cut;
        }
    }
}
