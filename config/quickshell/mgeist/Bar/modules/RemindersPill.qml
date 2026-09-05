// Reminders due today, and the entry point for the reminder card.
import QtQuick
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

Pill {
    id: root
    accent: Reminders.error !== "" ? Theme.red
        : Reminders.counts.overdue > 0 ? Theme.orange
        : Reminders.pressing > 0 ? Theme.accentReminders : Theme.muted
    hoverTitle: "Reminders"
    // The service is this module's own concern; Bar.qml only learns that the card was asked for
    onRightClicked: Reminders.refresh()
    hoverDetail: Reminders.error !== "" ? Reminders.error
        : `${Reminders.counts.today ?? 0} due today \u2022 ${Reminders.counts.overdue ?? 0} overdue \u2022 ${Reminders.counts.open ?? 0} open\nChecked ${Reminders.checkedAt || "\u2014"}\nClick: reminder card \u2022 right-click: refresh`

    Row {
        spacing: Theme.iconGap
        BarText {
            text: Reminders.busy || Reminders.acting ? "\uf110"   // nf-fa-spinner
                : Reminders.counts.overdue > 0 ? "\uf071"         // nf-fa-warning
                : "\uf0ae"                                        // nf-fa-tasks
            color: root.accent
            font.family: Theme.iconFontFamily
        }
        BarText {
            text: Reminders.pressing > 0 ? `${Reminders.pressing}` : "\u2014"
            color: root.accent
        }
    }
}
