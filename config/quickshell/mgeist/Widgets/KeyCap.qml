// Author: Jeff
// Date: 2026-08-21
// Description: One key rendered as a small cap
// Notes: Same border-only idiom as Pill, at reduced scale, so a chord reads as
//        keys rather than as text.

import QtQuick
import "root:/Theme"

Rectangle {
    id: root

    property string label: ""
    property color accent: Theme.muted

    implicitWidth: Math.max(text.implicitWidth + 12, 22)
    implicitHeight: 20

    radius: 5
    color: Qt.alpha(root.accent, 0.10)
    border.width: 1
    border.color: Theme.edge(root.accent)

    Text {
        id: text
        anchors.centerIn: parent
        text: root.label
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
        color: root.accent
    }
}
