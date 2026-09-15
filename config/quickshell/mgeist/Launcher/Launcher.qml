// Author: Jeff
// Date: 2026-08-21
// Description: Application launcher over XDG desktop entries
// Notes: Replaces `wofi --show drun`. Stays resident and is toggled over IPC,
//        so opening costs no process spawn.

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"
import "../Services/LauncherProviders.js" as Providers
import "../Services/MathEngine.js" as MathEngine

PopupPanel {
    id: root

    cardWidth: 620
    cardHeight: 500
    placement: "center"

    property string query: ""
    property int selected: 0
    property var rustCalculatorResult: null
    property bool rustCalculatorBusy: false
    readonly property string calcrBinary: Quickshell.env("MG_CALCR_BIN") || `${Quickshell.env("HOME")}/geistos/mg-suite/mg-calcr/target/debug/mg-calcr`

    signal keybindingsRequested()

    onOpenedChanged: {
        if (open) {
            query = "";
            selected = 0;
            rustCalculatorResult = null;
            rustCalculatorBusy = false;
            Qt.callLater(() => input.forceActiveFocus());
        }
    }

    Timer {
        id: rustCalculatorTimer
        interval: 120
        repeat: false
        onTriggered: root.requestRustCalculator()
    }

    Process {
        id: rustCalculatorProcess
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.rustCalculatorBusy) return;
                try {
                    const data = JSON.parse(String(text));
                    root.rustCalculatorResult = data.error ? null : Providers.calculatorResult(root.query.trim(), data.formatted);
                } catch (e) {
                    root.rustCalculatorResult = null;
                }
                root.rustCalculatorBusy = false;
            }
        }
        onExited: code => {
            if (code !== 0 && root.rustCalculatorBusy) {
                root.rustCalculatorBusy = false;
                root.rustCalculatorResult = null;
            }
        }
    }

    function requestRustCalculator() {
        const expression = root.query.trim();
        root.rustCalculatorResult = null;
        if (expression === "") {
            root.rustCalculatorBusy = false;
            return;
        }
        root.rustCalculatorBusy = true;
        if (rustCalculatorProcess.running) rustCalculatorProcess.running = false;
        rustCalculatorProcess.command = [root.calcrBinary, "evaluate", expression, "--json"];
        rustCalculatorProcess.running = true;
    }

    onQueryChanged: rustCalculatorTimer.restart()

    // Provider-specific search stays outside the launcher presentation.
    readonly property var results: {
        const q = query.trim().toLowerCase();
        const applications = DesktopEntries.applications.values
            .filter(entry => !entry.noDisplay)
            .map(entry => Providers.application(entry));
        const sourceActions = q === "" ? Commands.actions.slice(0, 6) : Commands.actions;
        const actions = sourceActions.map(action => Providers.action(action));
        const converter = Providers.unitConversion(query.trim(), MathEngine);
        const lookup = Providers.lexicalLookup(query.trim());
        const sources = [lookup, converter, root.rustCalculatorResult, ...actions, ...applications].filter(entry => entry !== null);
        return Providers.search(sources, q);
    }

    // Run the highlighted application, system action, or calculator result.
    function launch(item) {
        if (!item) return;
        if (item.kind === "calculator" || item.kind === "converter") {
            Quickshell.clipboardText = item.value;
        } else if (item.kind === "lookup") {
            Quickshell.execDetached(["qs", "-c", "mgeist", "ipc", "call", "lookup", "open", item.lookupType, item.lookupQuery]);
        } else if (item.kind === "action") {
            Commands.run(item.action);
        } else if (item.entry.runInTerminal) {
            AppLaunch.run(["ghostty", "-e", ...item.entry.command]);
        } else {
            AppLaunch.run(item.entry.command);
        }
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

        Row {
            width: parent.width
            spacing: 8
            BarText { text: `${root.results.length} results`; color: Theme.muted; font.pixelSize: Theme.fontSize - 1 }
            BarText { text: root.query.trim() === "" ? "Applications and actions" : `Searching for “${root.query.trim()}”`; color: Theme.faint; font.pixelSize: Theme.fontSize - 1; elide: Text.ElideRight; width: parent.width - 90 }
        }

        // ── Results ──────────────────────────────────────────
        ListView {
            id: list
            width: parent.width
            height: root.cardHeight - 76 - root.padding * 2 - 10
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
                            visible: row.modelData.kind !== "application"
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

        Item {
            width: parent.width
            height: 26
            visible: root.results.length === 0
            BarText { anchors.centerIn: parent; text: root.query.trim() === "" ? "No launchable entries" : "No matching applications or actions"; color: Theme.muted }
        }

        Row {
            width: parent.width
            spacing: 12
            BarText { text: "↑↓ select"; color: Theme.faint; font.pixelSize: Theme.fontSize - 1 }
            BarText { text: "Enter launch"; color: Theme.faint; font.pixelSize: Theme.fontSize - 1 }
            BarText { text: "Esc close"; color: Theme.faint; font.pixelSize: Theme.fontSize - 1 }
            BarText { text: "? shortcuts"; color: Theme.faint; font.pixelSize: Theme.fontSize - 1 }
        }
    }
}
