// Author: Jeff
// Date: 2026-08-21
// Description: Shared overlay chrome for the launcher and every dropdown panel
// Notes: The window covers the whole screen so a click anywhere outside the card
//        dismisses it without needing a focus grab. Keyboard focus is exclusive
//        only while open, so the compositor keeps normal input otherwise.
//        The card sizes to `body`, which is deliberately not anchor-filled —
//        card.height depending on a child that fills the card is a binding loop.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "root:/Theme"

WlrLayershell {
    id: root

    property bool open: false
    property int cardWidth: 560
    // 0 sizes the card to its content
    property int cardHeight: 0
    // center | topRight | topLeft
    property string placement: "center"
    property int padding: 12

    default property alias content: body.data

    signal openedChanged()

    visible: open
    layer: WlrLayer.Overlay
    namespace: "quickshell-popup"
    keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Pin to whichever monitor has focus, captured at open time so the panel
    // cannot move out from under the pointer while it is up. Without this a
    // popup lands on whichever screen Quickshell picked, which on a two-head
    // setup is regularly the one you are not looking at.
    function followFocus() {
        const name = Hyprland.focusedMonitor?.name;
        if (!name) return;

        for (const s of Quickshell.screens)
            if (s.name === name) {
                root.screen = s;
                return;
            }
    }

    // Grab focus once the surface exists so typing works without a click
    onOpenChanged: {
        if (open) {
            Qt.callLater(() => scope.forceActiveFocus());
        }
        root.openedChanged();
    }

    // Close the panel
    function close() {
        root.open = false;
    }

    // Open the panel
    function show() {
        root.followFocus();
        root.open = true;
    }

    // Flip the panel's state
    function toggle() {
        if (!root.open) root.followFocus();
        root.open = !root.open;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.close()

        Rectangle {
            id: card

            width: root.cardWidth
            height: root.cardHeight > 0 ? root.cardHeight : body.implicitHeight + root.padding * 2

            x: {
                switch (root.placement) {
                case "topRight": return root.width - width - Theme.barMargin;
                case "topLeft":  return Theme.barMargin;
                default:         return (root.width - width) / 2;
                }
            }

            y: root.placement === "center"
                ? Math.max(Theme.barHeight * 2, (root.height - height) / 3)
                : Theme.barHeight + Theme.barMargin * 2

            radius: Theme.popupRadius
            color: Theme.popupBg
            border.width: 1
            border.color: Theme.edge(Theme.purple)

            // Swallow clicks so they never reach the dismiss backdrop
            MouseArea {
                anchors.fill: parent
            }

            Item {
                id: body
                x: root.padding
                y: root.padding
                width: card.width - root.padding * 2
                implicitHeight: childrenRect.height
            }
        }
    }
}
