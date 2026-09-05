// Author: Jeff
// Date: 2026-08-21
// Description: Labelled horizontal meter for a single 0..1 value
// Notes: Colour follows the value so load reads at a glance without the label

import QtQuick
import "root:/Theme"

Item {
    id: root

    property string label: ""
    property string detail: ""
    property real value: 0
    property color accent: Theme.accent
    // Shade toward red as the value climbs
    property bool warnOnHigh: true

    implicitHeight: 34

    readonly property color shade: !warnOnHigh ? accent
        : value > 0.9 ? Theme.red
        : value > 0.75 ? Theme.orange
        : accent

    Text {
        id: name
        anchors.left: parent.left
        anchors.top: parent.top
        text: root.label
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
        color: Theme.muted
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        text: root.detail
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
        color: Theme.faint
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 8
        radius: 4
        color: Qt.alpha(Theme.muted, 0.16)

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.max(0, Math.min(1, root.value))
            radius: 4
            color: root.shade

            Behavior on width {
                NumberAnimation { duration: Theme.animNormal }
            }

            Behavior on color {
                ColorAnimation { duration: Theme.animNormal }
            }
        }
    }
}
