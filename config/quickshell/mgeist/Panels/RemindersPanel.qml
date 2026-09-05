// Author: Jeff
// Date: 2026-09-04
// Description: Reminder card: keep, complete, trash and restore without a terminal
// Notes: Every action goes through the Reminders service, which shells out to the
//        mg-remindr CLI. The card holds no reminder state of its own. The chrome is
//        CardShell's; only what is particular to reminders lives here.

import QtQuick
import Quickshell
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

PopupPanel {
    id: root
    cardWidth: 560
    // Sized by content; the list below carries its own fixed height
    cardHeight: 0
    placement: "center"

    // What a new reminder is due; empty means no due value at all
    property string pendingDue: "today"

    readonly property var dueChoices: [
        { id: "today", label: "Today" },
        { id: "tomorrow", label: "Tomorrow" },
        { id: "", label: "Someday" }
    ]

    function keep() {
        // Clear only once the service accepted it; a refused action used to
        // discard what was typed with no feedback at all
        if (Reminders.add(shell.entry, root.pendingDue)) shell.clearEntry();
    }

    function tone(reminder) {
        if (!reminder.open) return Theme.muted;
        if (reminder.when === "overdue") return Theme.orange;
        if (reminder.when === "today") return Theme.accentReminders;
        return Theme.fg;
    }

    // openedChanged, not onOpenChanged: assigning the latter would replace
    // PopupPanel's own handler, which is what grabs keyboard focus for the input.
    onOpenedChanged: if (open) Reminders.refresh()

    CardShell {
        id: shell
        width: parent.width

        glyph: "\uf0ae"   // nf-fa-tasks
        accent: Theme.accentReminders
        heading: "Reminders"
        subheading: `${Reminders.counts.today ?? 0} today  ·  ${Reminders.counts.overdue ?? 0} overdue  ·  ${Reminders.counts.open ?? 0} open`

        placeholder: "Keep a reminder, then Enter"
        onSubmitted: root.keep()
        onDismissed: root.close()

        rows: Reminders.reminders
        busy: Reminders.busy
        busyText: "Reading reminders…"
        failedText: "Could not read reminders."
        emptyText: Reminders.showClosed ? "Nothing kept yet." : "Nothing open. Keep one above."

        error: Reminders.error
        status: `${Reminders.status || "mg-remindr is the authority"}  ·  ${GeistUi.projectionStatus}`

        controls: [
            Pill {
                accent: Reminders.showClosed ? Theme.purple : Theme.muted
                bordered: Reminders.showClosed
                onClicked: Reminders.setShowClosed(!Reminders.showClosed)
                BarText {
                    text: "Closed"
                    color: Reminders.showClosed ? Theme.purple : Theme.muted
                }
            },
            Pill {
                id: refreshPill
                accent: Reminders.error !== "" ? Theme.red : Theme.cyan
                onClicked: Reminders.refresh()
                BarText {
                    text: Reminders.busy ? "\uf110" : "\uf021"   // nf-fa-spinner, nf-fa-refresh
                    color: refreshPill.accent
                    font.family: Theme.iconFontFamily
                }
            }
        ]

        chips: Repeater {
            model: root.dueChoices
            Pill {
                required property var modelData
                accent: root.pendingDue === modelData.id ? Theme.accentReminders : Theme.muted
                bordered: root.pendingDue === modelData.id
                onClicked: root.pendingDue = modelData.id
                BarText {
                    text: modelData.label
                    color: root.pendingDue === modelData.id ? Theme.accentReminders : Theme.muted
                }
            }
        }

        row: Component {
            Item {
                id: line
                required property var modelData
                width: ListView.view.width
                height: Theme.cardRowHeight

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius
                    color: rowHover.containsMouse ? Qt.alpha(Theme.fg, 0.05) : "transparent"
                }
                MouseArea { id: rowHover; anchors.fill: parent; hoverEnabled: true }

                BarText {
                    id: when
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.cardGutter
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.cardWhenWidth
                    text: line.modelData.due_label !== "" ? line.modelData.due_label : "someday"
                    color: root.tone(line.modelData)
                    font.pixelSize: Theme.fontSize - 1
                    elide: Text.ElideRight
                }

                // The title fills whatever the fixed columns leave, and elides there
                BarText {
                    anchors.left: when.right
                    anchors.leftMargin: Theme.iconGap
                    anchors.right: actions.left
                    anchors.rightMargin: Theme.cardGutter
                    anchors.verticalCenter: parent.verticalCenter
                    text: line.modelData.title
                    color: line.modelData.open ? Theme.fg : Theme.muted
                    font.strikeout: line.modelData.state === "completed"
                    elide: Text.ElideRight
                }

                Row {
                    id: actions
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.cardGutter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.moduleSpacing

                    CardIconButton {
                        visible: line.modelData.open
                        glyph: "\uf00c"   // nf-fa-check
                        tone: Theme.accentReminders
                        describe: "complete"
                        busy: Reminders.acting
                        onActivated: Reminders.complete(line.modelData.handle)
                    }
                    CardIconButton {
                        visible: line.modelData.open
                        glyph: "\uf1f8"   // nf-fa-trash
                        tone: Theme.red
                        describe: "trash"
                        destructive: true
                        busy: Reminders.acting
                        onActivated: Reminders.trash(line.modelData.handle)
                    }
                    CardIconButton {
                        visible: !line.modelData.open
                        glyph: "\uf0e2"   // nf-fa-undo
                        tone: Theme.cyan
                        describe: "restore"
                        busy: Reminders.acting
                        onActivated: Reminders.restore(line.modelData.handle)
                    }
                }
            }
        }
    }
}
