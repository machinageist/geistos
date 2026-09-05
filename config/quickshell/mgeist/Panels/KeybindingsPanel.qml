// Author: Jeff
// Date: 2026-08-21
// Description: Every keybinding, as chord chips and a description
// Notes: Read live from `hyprctl binds -j`, so it cannot drift from the config.
//        Bindings are namespaced the way Omarchy namespaces them, and the
//        modifier colour makes that visible: bare Super is window management,
//        Super+Ctrl is a panel, Super+Shift launches something.

import QtQuick
import Quickshell
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

PopupPanel {
    id: root

    cardWidth: 720
    cardHeight: 600
    placement: "center"

    property string query: ""

    onOpenedChanged: {
        if (!open) return;
        root.query = "";
        Keybindings.refresh();
        Qt.callLater(() => input.forceActiveFocus());
    }

    // Colour a chord by its namespace, so the scheme is legible at a glance
    function accentFor(group) {
        switch (group) {
        case "Panels":       return Theme.purple;
        case "Applications": return Theme.green;
        case "Workspaces":   return Theme.cyan;
        case "Media":        return Theme.orange;
        case "Capture":      return Theme.pink;
        default:             return Theme.accentCpu;
        }
    }

    readonly property var results: {
        const q = root.query.trim().toLowerCase();
        if (q === "") return Keybindings.binds;
        return Keybindings.binds.filter(b =>
            b.description.toLowerCase().includes(q) || b.chord.toLowerCase().includes(q));
    }

    // Rows carry their group; a header is drawn when the group changes
    function isFirstOfGroup(index) {
        if (index === 0) return true;
        return root.results[index].group !== root.results[index - 1].group;
    }

    Column {
        id: stack
        width: parent.width
        // The list measures itself against this, so it needs a real height
        height: root.cardHeight - root.padding * 2
        spacing: 10

        Rectangle {
            id: search
            width: parent.width
            height: 38
            radius: Theme.radius
            color: "transparent"
            border.width: 1
            border.color: Theme.edge(Theme.purple)

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.modulePadH + 2
                anchors.rightMargin: Theme.modulePadH
                spacing: Theme.iconGap

                BarText {
                    id: searchGlyph
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf11c"   // nf-fa-keyboard_o
                    color: Theme.purple
                }

                TextInput {
                    id: input
                    // Whatever the glyph and the result count leave, measured from them
                    width: parent.width - searchGlyph.width - resultCount.width - parent.spacing * 2
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 2
                    color: Theme.fg
                    clip: true
                    focus: true

                    onTextChanged: root.query = text
                    Keys.onEscapePressed: root.close()

                    BarText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `Search ${Keybindings.binds.length} keybindings`
                        color: Theme.muted
                        font.pixelSize: Theme.fontSize + 2
                        visible: input.text === ""
                    }
                }

                BarText {
                    id: resultCount
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${root.results.length}`
                    color: Theme.faint
                }
            }
        }

        // The empty state belongs inside the list's own space. As a sibling below
        // it, it added its own height plus a gap and was pushed past the card.
        Item {
            width: parent.width
            // Whatever the search field leaves, measured from it
            height: stack.height - search.height - stack.spacing

            BarText {
                anchors.centerIn: parent
                text: Keybindings.loaded ? "No match" : "Reading bindings\u2026"
                color: Theme.muted
                visible: root.results.length === 0
            }

            ListView {
                anchors.fill: parent
                clip: true
                model: root.results
                boundsBehavior: Flickable.StopAtBounds
                spacing: 1

                delegate: Column {
                    id: row
                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    spacing: 2

                    BarText {
                        text: row.modelData.group
                        color: root.accentFor(row.modelData.group)
                        font.pixelSize: Theme.fontSize - 2
                        visible: root.isFirstOfGroup(row.index)
                        topPadding: row.index === 0 ? 0 : 10
                        bottomPadding: 2
                    }

                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: Theme.popupRadius
                        color: hover.containsMouse ? Qt.alpha(Theme.muted, 0.10) : "transparent"

                        Row {
                            id: chord
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.modulePadH
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Repeater {
                                model: row.modelData.mods

                                KeyCap {
                                    required property var modelData
                                    label: modelData
                                    accent: Theme.muted
                                }
                            }

                            KeyCap {
                                label: row.modelData.key
                                accent: root.accentFor(row.modelData.group)
                            }
                        }

                        BarText {
                            anchors.left: chord.right
                            anchors.leftMargin: 14
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.modulePadH
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.description
                            color: Theme.fg
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: hover
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }
                }
            }
        }
    }
}
