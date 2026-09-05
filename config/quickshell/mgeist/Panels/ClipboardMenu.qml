// Author: Jeff
// Date: 2026-08-21
// Description: Searchable clipboard history backed by cliphist
// Notes: cliphist list emits "<id>\t<preview>"; putting an entry back on the
//        clipboard needs `cliphist decode <id> | wl-copy`, which is a pipeline
//        and so runs through sh -c.

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/Theme"
import "root:/Widgets"

PopupPanel {
    id: root

    cardWidth: 620
    cardHeight: 460
    placement: "center"

    property var entries: []
    property var pinned: []
    property string query: ""
    property int selected: 0

    onOpenedChanged: {
        if (!open) return;
        root.query = "";
        root.selected = 0;
        lister.running = true;
        Qt.callLater(() => input.forceActiveFocus());
    }

    readonly property var results: {
        const q = query.trim().toLowerCase();
        const hits = q === "" ? entries : entries.filter(e => e.preview.toLowerCase().includes(q));
        return [...hits].sort((a, b) => Number(root.pinned.includes(b.id)) - Number(root.pinned.includes(a.id))).slice(0, 200);
    }

    Process {
        id: lister
        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (line === "") continue;
                    const tab = line.indexOf("\t");
                    if (tab < 0) continue;
                    out.push({ id: line.slice(0, tab), preview: line.slice(tab + 1) });
                }
                root.entries = out;
            }
        }
    }

    function isSensitive(entry) {
        if (!entry) return false;
        return /(password|passwd|passphrase|one[- ]?time|\botp\b|api[_ -]?key|secret|bearer\s+[a-z0-9._-]+|authorization:)/i.test(entry.preview);
    }

    // Put an entry back on the clipboard
    function pick(entry) {
        if (!entry) return;
        Quickshell.execDetached(["sh", "-c", `cliphist decode ${entry.id} | wl-copy`]);
        root.close();
    }

    function togglePin(entry) {
        if (!entry) return;
        root.pinned = root.pinned.includes(entry.id)
            ? root.pinned.filter(id => id !== entry.id)
            : [...root.pinned, entry.id];
        pinState.setText(JSON.stringify({ pinned: root.pinned }, null, 2));
    }

    function remove(entry) {
        if (!entry) return;
        Quickshell.execDetached(["sh", "-c", `printf '%s' '${entry.id}' | cliphist delete`]);
        root.entries = root.entries.filter(e => e.id !== entry.id);
        root.pinned = root.pinned.filter(id => id !== entry.id);
    }

    FileView {
        id: pinState
        path: Quickshell.statePath("clipboard-pins.json")
        printErrors: false
        onLoaded: {
            try { root.pinned = JSON.parse(text()).pinned ?? []; } catch (e) {}
        }
    }

    // Move the highlight within the filtered list
    function move(delta) {
        if (results.length === 0) return;
        root.selected = Math.max(0, Math.min(results.length - 1, root.selected + delta));
        list.positionViewAtIndex(root.selected, ListView.Contain);
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
                spacing: Theme.iconGap

                BarText {
                    id: searchGlyph
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf0c5"   // nf-fa-copy
                    color: Theme.purple
                }

                TextInput {
                    id: input
                    // Whatever the glyph leaves, measured from it
                    width: parent.width - searchGlyph.width - parent.spacing - Theme.modulePadH
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 2
                    color: Theme.fg
                    clip: true
                    focus: true

                    onTextChanged: {
                        root.query = text;
                        root.selected = 0;
                    }

                    Keys.onDownPressed: root.move(1)
                    Keys.onUpPressed: root.move(-1)
                    Keys.onReturnPressed: root.pick(root.results[root.selected])
                    Keys.onEnterPressed: root.pick(root.results[root.selected])
                    Keys.onEscapePressed: root.close()

                    BarText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `Search ${root.entries.length} clipboard entries`
                        color: Theme.muted
                        font.pixelSize: Theme.fontSize + 2
                        visible: input.text === ""
                    }
                }
            }
        }

        ListView {
            id: list
            width: parent.width
            // Whatever the search field leaves, measured from it
            height: stack.height - search.height - stack.spacing
            clip: true
            model: root.results
            currentIndex: root.selected
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool sensitive: root.isSensitive(modelData)

                width: list.width
                height: 32
                radius: Theme.popupRadius
                color: index === root.selected ? Qt.alpha(Theme.purple, 0.16) : "transparent"

                BarText {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.modulePadH
                    anchors.rightMargin: Theme.modulePadH
                    text: `${root.pinned.includes(row.modelData.id) ? "\uf08d  " : ""}${row.sensitive ? "\uf023  sensitive clipboard entry" : row.modelData.preview}`
                    color: row.sensitive ? Theme.orange : Theme.fg
                    elide: Text.ElideRight
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onEntered: root.selected = row.index
                    onClicked: event => {
                        if (event.button === Qt.RightButton) root.togglePin(row.modelData);
                        else if (event.button === Qt.MiddleButton) root.remove(row.modelData);
                        else root.pick(row.modelData);
                    }
                }
            }
        }
    }
}
