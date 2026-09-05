// Author: Jeff
// Date: 2026-08-21
// Description: Clock, click to cycle time/date, ISO date, and millisecond time
// Notes: Default format matches Waybar's " {:%H:%M %D} "

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

Pill {
    id: root
    accent: Theme.accentClock

    property int clockView: 0
    property date millisecondTime: new Date()
    property bool calendarOpen: false
    property bool calendarHovered: false
    property bool calendarPinned: false
    signal appRequested(string page)

    function closeCalendar() {
        showCalendarTimer.stop();
        hideCalendarTimer.stop();
        root.calendarOpen = false;
        root.calendarPinned = false;
    }

    function pinCalendar() {
        showCalendarTimer.stop();
        hideCalendarTimer.stop();
        const alreadyOpen = root.calendarOpen;
        root.calendarPinned = true;

        // grabFocus only changes when PopupWindow is mapped, so promote a
        // hover-open calendar by remapping it once with the grab active.
        if (alreadyOpen) {
            root.calendarOpen = false;
            Qt.callLater(() => root.calendarOpen = true);
        } else {
            root.calendarOpen = true;
        }
    }

    onClicked: {
        root.clockView = (root.clockView + 1) % 3;
        root.closeCalendar();
    }
    onRightClicked: root.appRequested("calendar")

    Timer {
        id: showCalendarTimer
        interval: 120
        onTriggered: root.calendarOpen = true
    }

    Timer {
        id: hideCalendarTimer
        interval: 250
        onTriggered: if (!root.calendarPinned && !root.hovered && !root.calendarHovered)
            root.closeCalendar()
    }

    onHoveredChanged: {
        if (root.hovered) {
            hideCalendarTimer.stop();
            showCalendarTimer.restart();
        } else if (!root.calendarPinned) {
            showCalendarTimer.stop();
            hideCalendarTimer.restart();
        }
    }

    Connections {
        target: GeistUi
        function onCalendarCardOpenRequested() { root.pinCalendar(); }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Timer {
        interval: 16
        running: root.clockView === 2
        repeat: true
        triggeredOnStart: true
        onTriggered: root.millisecondTime = new Date()
    }

    PopupWindow {
        id: calendarPopup
        anchor.item: root
        anchor.rect.x: -(implicitWidth - root.width) / 2
        anchor.rect.y: root.height + Theme.barMargin
        visible: root.calendarOpen
        grabFocus: root.calendarPinned
        implicitWidth: 286
        implicitHeight: 294
        color: "transparent"
        onVisibleChanged: if (!visible && root.calendarOpen) root.closeCalendar()

        Rectangle {
            id: calendar
            anchors.fill: parent
            anchors.margins: 4
            radius: Theme.popupRadius
            color: Theme.popupBg
            border.width: 1
            border.color: Theme.edge(Theme.accentClock)

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                onContainsMouseChanged: {
                    root.calendarHovered = containsMouse;
                    if (containsMouse) hideCalendarTimer.stop();
                    else if (!root.calendarPinned && !root.hovered) hideCalendarTimer.restart();
                }
                onClicked: root.pinCalendar()
            }

            property date today: new Date()
            readonly property int year: today.getFullYear()
            readonly property int month: today.getMonth()
            readonly property int firstDay: new Date(year, month, 1).getDay()
            readonly property int daysInMonth: new Date(year, month + 1, 0).getDate()

            Timer {
                interval: 60000
                running: true
                repeat: true
                onTriggered: parent.today = new Date()
            }

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Text {
                    width: parent.width
                    text: Qt.formatDate(calendar.today, "MMMM yyyy")
                    color: Theme.accentClock
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 2
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Row {
                    width: parent.width
                    spacing: 0
                    Repeater {
                        model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                        Text {
                            width: parent.width / 7
                            text: modelData
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                Grid {
                    width: parent.width
                    columns: 7
                    rows: 6
                    rowSpacing: 2
                    columnSpacing: 0

                    Repeater {
                        model: 42
                        Text {
                            readonly property int day: index - calendar.firstDay + 1
                            width: parent.width / 7
                            height: 25
                            text: day > 0 && day <= calendar.daysInMonth ? day : ""
                            color: day === calendar.today.getDate()
                                && calendar.month === calendar.today.getMonth()
                                ? Theme.accentClock : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.bold: color === Theme.accentClock
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.radius
                    color: openCalendar.containsMouse ? Qt.alpha(Theme.accentClock, 0.14) : "transparent"
                    border.width: 1
                    border.color: Theme.edge(Theme.accentClock)

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.iconGap
                        BarText { text: "\uf073"; color: Theme.accentClock; font.family: Theme.iconFontFamily }
                        BarText { text: "Open mg-calr"; color: Theme.accentClock; font.bold: true }
                    }

                    MouseArea {
                        id: openCalendar
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.closeCalendar();
                            root.appRequested("calendar");
                        }
                    }
                }
            }
        }
    }

    BarText {
        color: Theme.accentClock
        font.family: Theme.iconFontFamily
        text: "\uf017  " + (root.clockView === 0
            ? Qt.formatDateTime(clock.date, "HH:mm MM/dd/yy")
            : root.clockView === 1
                ? Qt.formatDateTime(clock.date, "yyyy-MM-dd")
                : Qt.formatDateTime(root.millisecondTime, "HH:mm:ss.zzz"))
    }
}
