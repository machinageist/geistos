// Author: Jeff
// Date: 2026-08-21
// Description: The bar's visual signature — transparent fill, hairline accent border
// Notes: Every bar module composes this. Reproduces Waybar's border-only module
//        style, plus the click and scroll actions modules used to declare in JSONC.

import QtQuick
import Quickshell
import "root:/Theme"

Rectangle {
    id: root

    // Drives border, and by convention the content's text color
    property color accent: Theme.fg
    property bool bordered: true
    // Optional 0..1 progress fill drawn behind the content. Lives here rather
    // than in the default content slot, which is the Row and would lay a fill
    // rectangle out as if it were another label.
    property real fill: 0
    property alias hovered: mouse.containsMouse
    property string hoverTitle: ""
    property string hoverDetail: ""
    property var hoverGraphValues: []
    property color hoverGraphStroke: accent
    property real hoverGraphMaxValue: 1
    property bool hoverGraphBars: false
    property var hoverGraphColors: []
    property var hoverGraphValues2: []
    property color hoverGraphStroke2: accent
    property real hoverGraphMaxValue2: 1
    property string hoverMeterLabel: ""
    property string hoverMeterDetail: ""
    property real hoverMeterValue: -1
    property color hoverMeterAccent: accent
    property bool hoverMeterWarnOnHigh: false
    // Optional module-owned content appended to the shared hover card. This
    // keeps card chrome/placement shared while allowing interactive controls.
    property Component hoverContent: null
    property int hoverCardWidth: 300
    property bool hoverCardOpen: false
    // Hover cards are transient by default. A pill that explicitly opens its
    // card can pin it; pinned cards use the compositor's popup focus grab so
    // a click anywhere outside dismisses them.
    property bool hoverCardPinned: false
    default property alias content: layout.data

    signal clicked()
    signal rightClicked()
    signal middleClicked()
    signal scrolledUp()
    signal scrolledDown()

    function showHoverCard() {
        hideHoverTimer.stop();
        root.hoverCardOpen = true;
    }

    function pinHoverCard() {
        showHoverTimer.stop();
        hideHoverTimer.stop();

        // grabFocus only takes effect when a PopupWindow is mapped. If this
        // card was already shown by hover, remap it once with the grab active.
        const alreadyOpen = root.hoverCardOpen;
        root.hoverCardPinned = true;
        if (alreadyOpen) {
            root.hoverCardOpen = false;
            Qt.callLater(() => root.hoverCardOpen = true);
        } else {
            root.hoverCardOpen = true;
        }
    }

    function closeHoverCard() {
        showHoverTimer.stop();
        hideHoverTimer.stop();
        root.hoverCardOpen = false;
        root.hoverCardPinned = false;
    }

    implicitWidth: layout.implicitWidth + Theme.modulePadH * 2
    implicitHeight: Theme.pillHeight

    radius: Theme.radius
    color: mouse.containsMouse ? Qt.alpha(root.accent, 0.10) : "transparent"
    border.width: root.bordered ? 1 : 0
    border.color: Theme.edge(root.accent)

    Behavior on color {
        ColorAnimation { duration: Theme.animFast }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * Math.max(0, Math.min(1, root.fill))
        radius: parent.radius
        color: Qt.alpha(root.accent, 0.14)
        visible: root.fill > 0

        Behavior on width {
            NumberAnimation { duration: Theme.animNormal }
        }
    }

    Row {
        id: layout
        anchors.centerIn: parent
        spacing: Theme.iconGap
    }

    Timer {
        id: showHoverTimer
        interval: 180
        onTriggered: if (root.hoverDetail !== "") root.showHoverCard()
    }

    Timer {
        id: hideHoverTimer
        interval: 250
        onTriggered: if (!root.hoverCardPinned && !root.hovered && !cardHover.containsMouse)
            root.closeHoverCard()
    }

    onHoveredChanged: {
        if (root.hovered && root.hoverDetail !== "") {
            hideHoverTimer.stop();
            showHoverTimer.restart();
        } else if (!root.hoverCardPinned) {
            showHoverTimer.stop();
            hideHoverTimer.restart();
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.ArrowCursor

        onClicked: event => {
            if (event.button === Qt.LeftButton) root.clicked();
            else if (event.button === Qt.RightButton) root.rightClicked();
            else if (event.button === Qt.MiddleButton) root.middleClicked();
        }

        onWheel: event => {
            if (event.angleDelta.y > 0) root.scrolledUp();
            else if (event.angleDelta.y < 0) root.scrolledDown();
        }
    }

    PopupWindow {
        id: hoverCard
        anchor.item: root
        anchor.rect.x: -(implicitWidth - root.width) / 2
        anchor.rect.y: root.height + Theme.barMargin
        visible: root.hoverCardOpen
        grabFocus: root.hoverCardPinned
        implicitWidth: root.hoverCardWidth
        implicitHeight: card.implicitHeight + 8
        color: "transparent"

        // A focus-grabbed PopupWindow is dismissed by the compositor on an
        // outside click. Keep the shared state in sync so it can reopen.
        onVisibleChanged: if (!visible && root.hoverCardOpen)
            root.closeHoverCard()

        Rectangle {
            id: card
            anchors.fill: parent
            anchors.margins: 4
            radius: Theme.popupRadius
            color: Theme.popupBg
            border.width: 1
            border.color: Theme.edge(root.accent)
            implicitHeight: body.implicitHeight + 24

            MouseArea {
                id: cardHover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                onContainsMouseChanged: {
                    if (containsMouse) hideHoverTimer.stop();
                    else if (!root.hoverCardPinned && !root.hovered) hideHoverTimer.restart();
                }
                // Clicking a transient card promotes it to a pinned popup.
                // Child controls are stacked above and retain their clicks.
                onClicked: root.pinHoverCard()
            }

            Column {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 5

                Text {
                    width: parent.width
                    text: root.hoverTitle
                    color: root.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.hoverDetail
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    wrapMode: Text.WordWrap
                    maximumLineCount: 5
                    elide: Text.ElideRight
                }

                BarMeter {
                    width: parent.width
                    visible: root.hoverMeterValue >= 0
                    label: root.hoverMeterLabel
                    detail: root.hoverMeterDetail
                    value: Math.max(0, root.hoverMeterValue)
                    accent: root.hoverMeterAccent
                    warnOnHigh: root.hoverMeterWarnOnHigh
                }

                Graph {
                    width: parent.width
                    height: 60
                    visible: root.hoverGraphValues.length > 1
                    values: root.hoverGraphValues
                    stroke: root.hoverGraphStroke
                    maxValue: root.hoverGraphMaxValue
                    grid: false
                    lineWidth: 1.5
                    barMode: root.hoverGraphBars
                    barColors: root.hoverGraphColors
                }

                Graph {
                    width: parent.width
                    height: 48
                    visible: root.hoverGraphValues2.length > 1
                    values: root.hoverGraphValues2
                    stroke: root.hoverGraphStroke2
                    maxValue: root.hoverGraphMaxValue2
                    grid: false
                    lineWidth: 1.25
                }

                Loader {
                    width: parent.width
                    active: root.hoverContent !== null
                    visible: active
                    sourceComponent: root.hoverContent
                }
            }
        }
    }
}
