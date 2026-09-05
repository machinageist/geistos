// Author: Jeff
// Date: 2026-08-23
// Description: Shared transient on-screen display state
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root
    property bool visible: false
    property string glyph: ""
    property string title: ""
    property string detail: ""
    property real progress: -1
    property string accentRole: "accent"

    function show(glyph, title, detail, progress, accentRole) {
        root.glyph = glyph || "";
        root.title = title || "";
        root.detail = detail || "";
        root.progress = progress ?? -1;
        root.accentRole = accentRole || "accent";
        root.visible = true;
        hide.restart();
    }

    Timer {
        id: hide
        interval: 1300
        onTriggered: root.visible = false
    }
}
