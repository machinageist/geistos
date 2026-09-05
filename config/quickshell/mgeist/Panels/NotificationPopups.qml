// Author: Jeff
// Date: 2026-08-21
// Description: On-screen notification popups, the part that actually replaces mako
// Notes: A plain PanelWindow rather than a PopupPanel — these must never take
//        keyboard focus and must not cover the screen, so the surface is sized
//        to the stack and hidden entirely when there is nothing to show.

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

    readonly property int cardWidth: 380

    visible: Notifications.active.length > 0

    anchors {
        top: true
        right: true
    }

    margins {
        top: Theme.barHeight + Theme.barMargin * 2
        right: Theme.barMargin
    }

    implicitWidth: cardWidth
    implicitHeight: Math.max(1, stack.implicitHeight)
    exclusiveZone: 0
    color: "transparent"

    // Only the cards should be clickable; the rest of the surface stays
    // transparent to input so it never swallows clicks meant for windows
    mask: Region {
        item: stack
    }

    Column {
        id: stack
        width: parent.width
        spacing: 6

        Repeater {
            model: Notifications.active

            Rectangle {
                id: card
                required property var modelData

                width: stack.width
                height: Math.max(56, body.implicitHeight + 18)
                radius: Theme.popupRadius
                color: Theme.popupBg
                border.width: 1
                border.color: card.modelData.urgency === 2
                    ? Theme.edge(Theme.red)
                    : Theme.edge(Theme.accent)

                Column {
                    id: body
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.modulePadH + 2
                    anchors.rightMargin: Theme.modulePadH + 2
                    spacing: 2

                    BarText {
                        width: parent.width
                        text: card.modelData.appName
                        color: Theme.accent
                        font.pixelSize: Theme.fontSize - 2
                        elide: Text.ElideRight
                    }

                    BarText {
                        width: parent.width
                        text: card.modelData.summary
                        color: Theme.fg
                        elide: Text.ElideRight
                    }

                    BarText {
                        width: parent.width
                        text: card.modelData.body
                        color: Theme.muted
                        font.pixelSize: Theme.fontSize - 1
                        wrapMode: Text.WordWrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                        visible: text !== ""
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Notifications.forget(card.modelData.id)
                }
            }
        }
    }
}
