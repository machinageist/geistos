// Author: Jeff
// Date: 2026-08-21
// Description: Application launcher over XDG desktop entries
// Notes: Replaces `wofi --show drun`. Stays resident and is toggled over IPC,
//        so opening costs no process spawn.

import QtQuick
import Quickshell
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

PopupPanel {
    id: root

    cardWidth: 560
    cardHeight: 420
    placement: "center"

    property string query: ""
    property int selected: 0

    signal keybindingsRequested()

    onOpenedChanged: {
        if (open) {
            query = "";
            selected = 0;
            Qt.callLater(() => input.forceActiveFocus());
        }
    }

    // Rank entries by where the query hits: prefix beats word-start beats substring
    function score(entry, q) {
        if (q === "") return 0;

        const name = entry.name.toLowerCase();
        const generic = (entry.genericName || "").toLowerCase();
        const keywords = (entry.keywords || []).join(" ").toLowerCase();

        if (name.startsWith(q)) return 100 - name.length * 0.01;
        if (name.split(/[\s-]/).some(w => w.startsWith(q))) return 80;
        if (name.includes(q)) return 60;
        if (generic.includes(q)) return 40;
        if (keywords.includes(q)) return 20;
        return -1;
    }

    readonly property var results: {
        const q = query.trim().toLowerCase();
        const applications = DesktopEntries.applications.values
            .filter(entry => !entry.noDisplay)
            .map(entry => ({
                kind: "application",
                name: entry.name,
                genericName: entry.genericName || "",
                comment: entry.comment || "",
                keywords: entry.keywords || [],
                icon: entry.icon,
                entry: entry
            }));
        const sourceActions = q === "" ? Commands.actions.slice(0, 6) : Commands.actions;
        const actions = sourceActions.map(action => ({
            kind: "action",
            name: action.name,
            genericName: action.subtitle,
            comment: action.subtitle,
            keywords: `${action.tags} system action command`.split(" "),
            glyph: action.glyph,
            action: action
        }));

        return [...actions, ...applications]
            .map(entry => ({ entry: entry, raw: root.score(entry, q) }))
            .filter(result => result.raw >= 0)
            .map(result => ({ entry: result.entry, s: result.raw + (result.entry.kind === "action" ? 5 : 0) }))
            .sort((a, b) => b.s - a.s || a.entry.name.localeCompare(b.entry.name))
            .slice(0, 60)
            .map(result => result.entry);
    }

    // Run the highlighted application or system action and dismiss
    function launch(item) {
        if (!item) return;

        if (item.kind === "action") Commands.run(item.action);
        else if (item.entry.runInTerminal) Quickshell.execDetached(["ghostty", "-e", ...item.entry.command]);
        else Quickshell.execDetached(item.entry.command);

        root.close();
    }

    // Move the highlight, clamped to the result list
    function move(delta) {
        if (results.length === 0) return;
        root.selected = Math.max(0, Math.min(results.length - 1, root.selected + delta));
        list.positionViewAtIndex(root.selected, ListView.Contain);
    }

    Column {
        width: parent.width
        spacing: 10

        // ── Search field ─────────────────────────────────────
        Rectangle {
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
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf002"           // nf-fa-search
                    color: Theme.purple
                }

                TextInput {
                    id: input
                    width: parent.width - 40
                    anchors.verticalCenter: parent.verticalCenter

                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 2
                    color: Theme.fg
                    selectionColor: Theme.edge(Theme.purple)
                    selectedTextColor: Theme.fg
                    clip: true
                    focus: true

                    onTextChanged: {
                        // "?" is the keybindings cheatsheet, the way "/" is search
                        // elsewhere. Handing off rather than duplicating the view.
                        if (text === "?") {
                            text = "";
                            root.close();
                            root.keybindingsRequested();
                            return;
                        }

                        root.query = text;
                        root.selected = 0;
                        list.positionViewAtBeginning();
                    }

                    Keys.onDownPressed: root.move(1)
                    Keys.onUpPressed: root.move(-1)
                    Keys.onReturnPressed: root.launch(root.results[root.selected])
                    Keys.onEnterPressed: root.launch(root.results[root.selected])
                    Keys.onEscapePressed: root.close()

                    BarText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search applications and system actions"
                        color: Theme.muted
                        font.pixelSize: Theme.fontSize + 2
                        visible: input.text === ""
                    }
                }
            }
        }

        // ── Results ──────────────────────────────────────────
        ListView {
            id: list
            width: parent.width
            height: root.cardHeight - 38 - root.padding * 2 - 10
            clip: true
            model: root.results
            currentIndex: root.selected
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index

                width: list.width
                height: 44
                radius: Theme.popupRadius
                color: index === root.selected ? Qt.alpha(Theme.purple, 0.16) : "transparent"

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.modulePadH
                    anchors.rightMargin: Theme.modulePadH
                    spacing: 10

                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26
                        height: 26

                        AppIcon {
                            anchors.centerIn: parent
                            visible: row.modelData.kind === "application"
                            size: 26
                            iconName: row.modelData.icon ?? ""
                            label: row.modelData.name
                        }

                        BarText {
                            anchors.centerIn: parent
                            visible: row.modelData.kind === "action"
                            text: row.modelData.glyph ?? "\uf013"
                            color: Theme.purple
                            font.family: Theme.iconFontFamily
                            font.pixelSize: Theme.iconSize
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 40
                        spacing: 1

                        BarText {
                            text: row.modelData.name
                            color: row.index === root.selected ? Theme.fg : Theme.fg
                            width: parent.width
                            elide: Text.ElideRight
                        }

                        BarText {
                            text: row.modelData.genericName || row.modelData.comment || ""
                            color: Theme.muted
                            font.pixelSize: Theme.fontSize - 1
                            width: parent.width
                            elide: Text.ElideRight
                            visible: text !== ""
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.selected = row.index
                    onClicked: root.launch(row.modelData)
                }
            }
        }
    }
}
