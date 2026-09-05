// Today's schedule, and the entry point for the calendar card.
import QtQuick
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

Pill {
    id: root
    accent: Calendar.error !== "" ? Theme.red
        : Calendar.todayScheduled > 0 ? Theme.accentClock : Theme.muted
    hoverTitle: "Calendar"
    // The service is this module's own concern; Bar.qml only learns the card was asked for
    onRightClicked: Calendar.refresh()
    hoverDetail: Calendar.error !== "" ? Calendar.error
        : `${Calendar.counts.events ?? 0} events \u00b7 ${Calendar.counts.todos ?? 0} dated reminders\n${Calendar.projection.present ? (Calendar.projection.complete ? "todo projection complete" : "todo projection INCOMPLETE") : "no todo projection stored"}\nChecked ${Calendar.checkedAt || "\u2014"}\nClick: calendar card \u00b7 right-click: refresh`

    Row {
        spacing: Theme.iconGap
        BarText {
            text: Calendar.busy || Calendar.acting ? "\uf110"   // nf-fa-spinner
                : "\uf073"                                      // nf-fa-calendar
            color: root.accent
            font.family: Theme.iconFontFamily
        }
        BarText {
            text: Calendar.todayScheduled > 0 ? `${Calendar.todayScheduled}` : "\u2014"
            color: root.accent
        }
    }
}
