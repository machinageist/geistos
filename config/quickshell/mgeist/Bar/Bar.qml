// Author: Jeff
// Date: 2026-08-21
// Description: The bar surface — one instance per screen, anchored top
// Notes: exclusiveZone reserves the bar's height plus its margin so tiled
//        windows never sit underneath it

import QtQuick
import Quickshell
import "root:/Theme"
import "root:/Services"
import "modules"

PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    readonly property bool autoHide: DesktopState.barAutoHide
    property bool revealed: !autoHide
    readonly property int revealHeight: 4
    readonly property real shownBarY: Theme.barMargin
    readonly property real hiddenBarY: -(Theme.barHeight - revealHeight)

    // Bar modules do not know about panels; shell.qml connects these
    signal notificationsRequested()
    signal quickSettingsRequested()
    signal launcherRequested()
    signal selectorRequested()
    signal aiRequested()
    signal geistRequested(string page)
    signal remindersRequested()
    signal calendarCardRequested()

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: 0
        left: Theme.barMargin
        right: Theme.barMargin
    }

    implicitHeight: Theme.barHeight + Theme.barMargin
    exclusiveZone: autoHide && !revealed ? 0 : Theme.barHeight + Theme.barMargin
    color: "transparent"
    mask: Region { item: root.autoHide && !root.revealed ? revealRegion : barContent }

    function updateAutoHide() {
        if (!root.autoHide) {
            hideTimer.stop();
            root.revealed = true;
        } else if (barHover.hovered || revealHover.hovered) {
            hideTimer.stop();
            root.revealed = true;
        } else {
            hideTimer.restart();
        }
    }
    onAutoHideChanged: updateAutoHide()

    Timer {
        id: hideTimer
        interval: 420
        onTriggered: {
            if (!root.autoHide) return;
            if (barHover.hovered || revealHover.hovered) {
                restart();
                return;
            }
            root.revealed = false;
        }
    }

    Item {
        id: revealRegion
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.revealHeight
    }

    HoverHandler {
        id: revealHover
        target: revealRegion
        onHoveredChanged: root.updateAutoHide()
    }
    HoverHandler {
        id: barHover
        target: barContent
        onHoveredChanged: root.updateAutoHide()
    }

    Item {
        id: barContent
        width: parent.width
        height: Theme.barHeight
        y: root.autoHide && !root.revealed ? root.hiddenBarY : root.shownBarY

        Behavior on y {
            NumberAnimation { duration: Theme.animNormal; easing.type: Easing.InOutQuad }
        }

        Rectangle {
            id: surface
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.barBg
            border.width: 1
            border.color: Theme.edge(Theme.purple)

        // ── Left ─────────────────────────────────────────────
        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.modulePadH
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.moduleSpacing

            OsButton {
                onClicked: root.launcherRequested()
                onRightClicked: root.selectorRequested()
            }
            Workspaces {}
            AppTools {}
            ActiveWindow {}
        }

        // ── Center ───────────────────────────────────────────
        // Stopwatch and pomodoro flank the clock; both stay a bare glyph
        // until they are actually running
        Row {
            anchors.centerIn: parent
            spacing: Theme.moduleSpacing

            StopwatchPill {}
            Clock {
                onAppRequested: page => root.geistRequested(page)
            }
            PomodoroPill {}
        }

        // ── Right ────────────────────────────────────────────
        // Order carried over from Waybar's modules-right
        Row {
            id: rightRow
            anchors.right: parent.right
            anchors.rightMargin: Theme.modulePadH
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.moduleSpacing

            PowerProfile {}
            Appearance {}

            Cpu {}
            Memory {}
            Battery {}
            Volume {}
            Bluetooth {
                onClicked: root.quickSettingsRequested()
            }

            Network {
                onClicked: root.quickSettingsRequested()
                onRightClicked: root.quickSettingsRequested()
            }

            WeatherPill {}

            GeistPill {
                onClicked: root.geistRequested("calendar")
                onRightClicked: root.geistRequested("vault")
            }

            RemindersPill {
                onClicked: root.remindersRequested()
            }

            CalendarPill {
                onClicked: root.calendarCardRequested()
            }

            HealthPill {}

            AiPill {
                onClicked: root.aiRequested()
            }

            // Alerts sit last, at the far right edge
            NotificationBell {
                onClicked: root.notificationsRequested()
            }

        }
        }
    }
}
