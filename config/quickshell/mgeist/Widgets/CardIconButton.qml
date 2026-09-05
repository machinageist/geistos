// Author: Jeff
// Date: 2026-09-04
// Description: Round glyph action used by the reminder and calendar card rows
// Notes: Sized from Theme so a row's action column is the same width in both cards.
//        A glyph alone says nothing about what it does, so `describe` shows on
//        hover; a destructive action arms on the first click and fires on the
//        second, the same shape SessionMenu uses for its destructive rows.

import QtQuick
import "root:/Theme"

Rectangle {
    id: root

    required property string glyph
    required property color tone
    /// Shown on hover. Every action should say what it does before it is clicked.
    property string describe: ""
    /// A destructive action arms first and only fires on a second click.
    property bool destructive: false
    /// Refuse the click while the owning service is busy rather than swallowing it.
    property bool busy: false

    property bool armed: false

    readonly property bool hovered: hit.containsMouse
    readonly property string hint: root.armed ? "click again to confirm" : root.describe

    signal activated()

    // Losing the pointer disarms, so an armed button is never left waiting
    onHoveredChanged: if (!hovered) root.armed = false

    width: Theme.cardActionSize
    height: Theme.cardActionSize
    radius: width / 2
    opacity: root.busy ? 0.45 : 1
    color: root.armed ? Qt.alpha(root.tone, 0.32)
        : hit.containsMouse ? Qt.alpha(root.tone, 0.18)
        : "transparent"
    border.width: root.armed ? 2 : 1
    border.color: Theme.edge(root.tone)

    Behavior on color {
        ColorAnimation { duration: Theme.animFast }
    }

    BarText {
        anchors.centerIn: parent
        text: root.glyph
        color: root.tone
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.fontSize - 1
    }

    MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        enabled: !root.busy
        cursorShape: root.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: {
            if (root.destructive && !root.armed) {
                root.armed = true;
                return;
            }
            root.armed = false;
            root.activated();
        }
    }

    // A small label rather than a full hover card: these sit inside a list row
    Rectangle {
        visible: hit.containsMouse && root.hint !== ""
        anchors.bottom: parent.top
        anchors.bottomMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        width: label.implicitWidth + Theme.iconGap * 2
        height: label.implicitHeight + Theme.iconGap
        radius: Theme.popupRadius
        color: Theme.popupBg
        border.width: 1
        border.color: Theme.edge(root.tone)
        z: 1

        BarText {
            id: label
            anchors.centerIn: parent
            text: root.hint
            color: root.armed ? root.tone : Theme.fg
            font.pixelSize: Theme.fontSize - 2
        }
    }
}
