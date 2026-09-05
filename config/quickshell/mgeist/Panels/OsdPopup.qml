// Author: Jeff
// Date: 2026-08-23
// Description: Theme-aware centered OSD for system changes
import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

PanelWindow {
    id: root
    required property ShellScreen modelData
    screen: modelData
    visible: Osd.visible
    anchors { top: true }
    margins.top: Theme.barHeight + Theme.barMargin * 2
    implicitWidth: 340
    implicitHeight: 86
    exclusiveZone: 0
    color: "transparent"
    mask: Region { item: card }

    readonly property color osdAccent: {
        const role = Osd.accentRole;
        if (role === "red") return Theme.red;
        if (role === "yellow") return Theme.yellow;
        if (role === "green") return Theme.green;
        if (role === "cyan") return Theme.cyan;
        if (role === "blue") return Theme.blue;
        if (role === "purple") return Theme.purple;
        return Theme.accent;
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.popupRadius
        color: Theme.popupBg
        border.width: 1
        border.color: Theme.edge(root.osdAccent)

        Row {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            BarText {
                id: osdGlyph
                anchors.verticalCenter: parent.verticalCenter
                text: Osd.glyph
                color: root.osdAccent
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSize + 8
            }

            Column {
                // Whatever the glyph leaves; it is drawn at iconSize + 8, so its
                // width moves with the theme's icon size
                width: parent.width - osdGlyph.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                BarText { width: parent.width; text: Osd.title; color: Theme.fg; font.bold: true; elide: Text.ElideRight }
                BarText { width: parent.width; text: Osd.detail; color: Theme.muted; font.pixelSize: Theme.fontSize - 1; elide: Text.ElideRight }
                Rectangle {
                    width: parent.width
                    height: 5
                    radius: 2
                    color: Qt.alpha(Theme.muted, 0.18)
                    visible: Osd.progress >= 0
                    Rectangle { width: parent.width * Math.max(0, Math.min(1, Osd.progress)); height: parent.height; radius: parent.radius; color: root.osdAccent }
                }
            }
        }
    }
}
