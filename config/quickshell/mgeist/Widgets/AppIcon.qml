// Author: Jeff
// Date: 2026-08-21
// Description: Desktop-entry icon with a letter badge when the theme has none
// Notes: Many entries name icons this icon theme does not ship, and the usual
//        application-x-executable fallback is missing too, which left Qt drawing
//        its magenta "broken image" checkerboard. iconPath(icon, true) returns
//        an empty string instead of a broken URL, so the badge can take over.

import QtQuick
import Quickshell
import Quickshell.Widgets
import "root:/Theme"

Item {
    id: root

    property string iconName: ""
    property string label: ""
    property int size: 26

    implicitWidth: size
    implicitHeight: size

    readonly property string resolved: iconName === "" ? "" : Quickshell.iconPath(iconName, true)

    IconImage {
        anchors.centerIn: parent
        implicitSize: root.size
        source: root.resolved
        visible: root.resolved !== ""
    }

    Rectangle {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        radius: root.size / 4
        visible: root.resolved === ""

        color: Qt.alpha(Theme.purple, 0.14)
        border.width: 1
        border.color: Theme.edge(Theme.purple)

        Text {
            anchors.centerIn: parent
            text: (root.label[0] || "?").toUpperCase()
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(root.size * 0.5)
            font.bold: true
            color: Theme.purple
        }
    }
}
