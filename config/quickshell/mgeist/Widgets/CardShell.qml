// Author: Jeff
// Date: 2026-09-05
// Description: The skeleton every Geist card wears — header, entry, chips, list, footer
// Notes: Extracted from RemindersPanel and CalendarPanel, which had grown into
//        near-twins line for line. A body rather than a window, so a GeistPanel
//        page can wear it as readily as a standalone popup can.
//        Columns are anchored rather than spaced: no row depends on a guessed width.

import QtQuick
import "root:/Theme"

Column {
    id: root

    // ── Identity, left of the header ─────────────────────
    property string glyph: ""
    property color accent: Theme.fg
    property string heading: ""
    // Counts and other at-a-glance detail beside the heading
    property string subheading: ""

    // ── Entry row; no placeholder means the card takes no input ──
    property string placeholder: ""
    property alias entry: input.text

    // ── List ─────────────────────────────────────────────
    property int listHeight: 300
    property var rows: []
    property Component row: null
    // What the frame says when `rows` is empty and nothing is wrong
    property string emptyText: ""
    property string busyText: ""
    property string failedText: ""
    property bool busy: false

    // ── Footer; an error replaces the status and turns it red ──
    property string status: ""
    property string error: ""

    // Slots the host fills with its own controls
    property alias controls: controlsRow.data
    property alias chips: chipsRow.data
    property alias chipControls: chipEnd.data

    signal submitted()
    signal dismissed()

    // Clear the entry field
    function clearEntry() {
        input.text = "";
    }

    // Put the caret back in the entry field
    function focusEntry() {
        input.forceActiveFocus();
    }

    spacing: Theme.cardGutter

    // ── Header: identity left, controls right, no guessed spacer between ──
    Item {
        width: parent.width
        height: Theme.pillHeight

        // Name and count are separate groups, so the count never crowds the title
        Row {
            anchors.left: parent.left
            anchors.right: controlsRow.left
            anchors.rightMargin: Theme.cardGutter
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.cardGutter + Theme.iconGap

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.iconGap

                BarText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.glyph
                    color: root.accent
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fontSize + 4
                }
                BarText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.heading
                    color: root.accent
                    font.pixelSize: Theme.fontSize + 4
                    font.bold: true
                }
            }

            BarText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.subheading
                color: Theme.faint
                elide: Text.ElideRight
            }
        }

        Row {
            id: controlsRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.moduleSpacing
        }
    }

    Rectangle { width: parent.width; height: 1; color: Theme.edge(Theme.muted) }

    // ── Entry ────────────────────────────────────────────
    Rectangle {
        width: parent.width
        height: 38
        visible: root.placeholder !== ""
        radius: Theme.radius
        color: "transparent"
        border.width: 1
        border.color: Theme.edge(root.accent)

        BarText {
            id: entryGlyph
            anchors.left: parent.left
            anchors.leftMargin: Theme.modulePadH + 2
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf067"   // nf-fa-plus
            color: root.accent
            font.family: Theme.iconFontFamily
        }

        TextInput {
            id: input
            anchors.left: entryGlyph.right
            anchors.leftMargin: Theme.iconGap
            anchors.right: parent.right
            anchors.rightMargin: Theme.modulePadH
            anchors.verticalCenter: parent.verticalCenter
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 1
            color: Theme.fg
            clip: true
            focus: true

            Keys.onReturnPressed: root.submitted()
            Keys.onEnterPressed: root.submitted()
            Keys.onEscapePressed: root.dismissed()

            BarText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.placeholder
                color: Theme.muted
                font.pixelSize: Theme.fontSize + 1
                visible: input.text === ""
            }
        }
    }

    // ── Chips: choices left, an optional filter right ────
    Item {
        width: parent.width
        height: Theme.pillHeight
        visible: chipsRow.children.length > 0 || chipEnd.children.length > 0

        Row {
            id: chipsRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.moduleSpacing
        }

        Row {
            id: chipEnd
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.moduleSpacing
        }
    }

    // ── List ─────────────────────────────────────────────
    Rectangle {
        width: parent.width
        height: root.listHeight
        radius: Theme.radius
        color: Qt.alpha(Theme.muted, 0.06)
        border.width: 1
        border.color: Theme.edge(Theme.muted)

        // An empty list and a failed read used to read the same; they do not now
        BarText {
            anchors.centerIn: parent
            width: parent.width - Theme.cardGutter * 2
            horizontalAlignment: Text.AlignHCenter
            visible: root.rows.length === 0
            text: root.error !== "" ? root.failedText
                : root.busy ? root.busyText
                : root.emptyText
            color: root.error !== "" ? Theme.red : Theme.muted
            wrapMode: Text.WordWrap
        }

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 8
            clip: true
            spacing: 2
            model: root.rows
            delegate: root.row
        }
    }

    // ── Footer ───────────────────────────────────────────
    BarText {
        width: parent.width
        text: root.error !== "" ? root.error : root.status
        color: root.error !== "" ? Theme.red : Theme.faint
        font.pixelSize: Theme.fontSize - 2
        elide: Text.ElideRight
    }
}
