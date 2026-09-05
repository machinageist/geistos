// Author: Jeff
// Date: 2026-09-04
// Description: Calendar card: read a day, schedule an event, cancel and restore one
// Notes: Every action goes through the Calendar service, which shells out to the
//        mg-calr CLI. Dated reminders appear here through the projection mg-calr
//        has already validated; they are read-only on this card, because mg-remindr
//        owns them. The chrome is CardShell's; only the calendar's own part lives here.

import QtQuick
import Quickshell
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

PopupPanel {
    id: root
    cardWidth: 560
    cardHeight: 0
    placement: "center"

    // Empty schedules an all-day event; otherwise a 24-hour wall time
    property string pendingTime: ""

    readonly property var timeChoices: [
        { id: "", label: "All day" },
        { id: "09:00", label: "09:00" },
        { id: "13:00", label: "13:00" },
        { id: "17:00", label: "17:00" }
    ]

    readonly property string heading: Calendar.date === "" ? "Calendar"
        : Calendar.isToday ? "Today"
        : Qt.formatDate(new Date(Calendar.date + "T12:00:00"), "ddd d MMM")

    function plural(count, noun) {
        return `${count} ${noun}${count === 1 ? "" : "s"}`;
    }

    function schedule() {
        // Clear only once the service accepted it; a refused action used to
        // discard what was typed with no feedback at all
        if (Calendar.add(shell.entry, root.pendingTime, 60)) shell.clearEntry();
    }

    // What the footer says about the todo projection. `complete` only ever meant
    // every record mg-remindr sent arrived; it says nothing about mg-remindr having
    // moved on since, which is what `stale` is for.
    readonly property string projectionNote: {
        const p = Calendar.projection;
        if (!p.present) return "no todo projection";
        if (!p.complete) return "todo projection INCOMPLETE";
        if (p.stale) return `todo projection STALE · ${p.behind} behind`;
        return `todos rev ${p.revision}`;
    }

    function tone(item) {
        if (item.cancelled) return Theme.muted;
        if (item.kind === "todo") return item.completed ? Theme.muted : Theme.accentReminders;
        return Theme.accentClock;
    }

    // Reopening always lands on today rather than wherever browsing stopped.
    // openedChanged, not onOpenChanged: assigning the latter would replace
    // PopupPanel's own handler, which is what grabs keyboard focus for the input.
    onOpenedChanged: {
        if (!open) return;
        // today() already refreshes when the offset moved, so refreshing again
        // here queued a second CLI pass on every open from a browsed day
        if (Calendar.offset === 0) Calendar.refresh();
        else Calendar.today();
    }

    CardShell {
        id: shell
        width: parent.width

        glyph: "\uf073"   // nf-fa-calendar
        accent: Theme.accentClock
        heading: root.heading
        subheading: `${root.plural(Calendar.counts.events ?? 0, "event")}  ·  ${root.plural(Calendar.counts.todos ?? 0, "reminder")}`

        placeholder: "Schedule an event, then Enter"
        onSubmitted: root.schedule()
        onDismissed: root.close()

        rows: Calendar.rows
        busy: Calendar.busy
        busyText: "Reading the day…"
        failedText: "Could not read the day."
        emptyText: "Nothing scheduled. Add one above."

        error: Calendar.error
        status: `${Calendar.status || "mg-calr is the authority"}  ·  ${root.projectionNote}  ·  ${Calendar.timezone}`

        controls: [
            Pill {
                accent: Theme.muted
                onClicked: Calendar.move(-1)
                BarText {
                    text: "\uf053"   // nf-fa-chevron-left
                    color: Theme.muted
                    font.family: Theme.iconFontFamily
                }
            },
            Pill {
                accent: Calendar.isToday ? Theme.muted : Theme.accentClock
                bordered: !Calendar.isToday
                onClicked: Calendar.today()
                BarText {
                    text: "Today"
                    color: Calendar.isToday ? Theme.muted : Theme.accentClock
                }
            },
            Pill {
                accent: Theme.muted
                onClicked: Calendar.move(1)
                BarText {
                    text: "\uf054"   // nf-fa-chevron-right
                    color: Theme.muted
                    font.family: Theme.iconFontFamily
                }
            },
            Pill {
                id: refreshPill
                accent: Calendar.error !== "" ? Theme.red : Theme.cyan
                onClicked: Calendar.refresh()
                BarText {
                    text: Calendar.busy ? "\uf110" : "\uf021"   // nf-fa-spinner, nf-fa-refresh
                    color: refreshPill.accent
                    font.family: Theme.iconFontFamily
                }
            }
        ]

        chips: Repeater {
            model: root.timeChoices
            Pill {
                required property var modelData
                accent: root.pendingTime === modelData.id ? Theme.accentClock : Theme.muted
                bordered: root.pendingTime === modelData.id
                onClicked: root.pendingTime = modelData.id
                BarText {
                    text: modelData.label
                    color: root.pendingTime === modelData.id ? Theme.accentClock : Theme.muted
                }
            }
        }

        chipControls: Pill {
            visible: Calendar.counts.cancelled > 0
            accent: Calendar.showCancelled ? Theme.purple : Theme.muted
            bordered: Calendar.showCancelled
            onClicked: Calendar.setShowCancelled(!Calendar.showCancelled)
            BarText {
                text: `Cancelled ${Calendar.counts.cancelled ?? 0}`
                color: Calendar.showCancelled ? Theme.purple : Theme.muted
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
                    text: line.modelData.when
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
                    color: line.modelData.cancelled || line.modelData.completed ? Theme.muted : Theme.fg
                    font.strikeout: line.modelData.cancelled || line.modelData.completed
                    elide: Text.ElideRight
                }

                Row {
                    id: actions
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.cardGutter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.moduleSpacing

                    // mg-remindr owns reminders, so this card only ever reads them
                    BarText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: line.modelData.kind === "todo"
                        text: "reminder"
                        color: Theme.faint
                        font.pixelSize: Theme.fontSize - 2
                    }
                    CardIconButton {
                        visible: line.modelData.kind === "event" && !line.modelData.cancelled
                        glyph: "\uf00d"   // nf-fa-times
                        tone: Theme.red
                        describe: "cancel"
                        destructive: true
                        busy: Calendar.acting
                        onActivated: Calendar.cancel(line.modelData.handle)
                    }
                    CardIconButton {
                        visible: line.modelData.kind === "event" && line.modelData.cancelled
                        glyph: "\uf0e2"   // nf-fa-undo
                        tone: Theme.cyan
                        describe: "restore"
                        busy: Calendar.acting
                        onActivated: Calendar.restore(line.modelData.handle)
                    }
                }
            }
        }
    }
}
