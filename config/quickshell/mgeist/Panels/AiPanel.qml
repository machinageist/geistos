// Author: Jeff
// Date: 2026-08-21
// Description: Ask a local model, act on the clipboard, or open an AI CLI
// Notes: Answers stream in from Ollama on localhost. The CLI row is the escape
//        hatch for anything wanting a full session in a terminal.

import QtQuick
import Quickshell
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

PopupPanel {
    id: root

    cardWidth: 660
    cardHeight: 520
    placement: "center"

    onOpenedChanged: {
        if (!open) return;
        Ai.refreshModels();
        Qt.callLater(() => input.forceActiveFocus());
    }

    Column {
        id: stack
        width: parent.width
        // The answer frame measures itself against this, so it needs a real height
        height: root.cardHeight - root.padding * 2
        spacing: 10

        // ── Model and clipboard actions ──────────────────────
        Row {
            id: actions
            width: parent.width
            spacing: Theme.moduleSpacing

            Pill {
                id: modelPill
                // Cloud models leave the machine, so they read as a warning
                accent: Ai.error !== "" ? Theme.red
                      : Ai.modelIsCloud ? Theme.orange
                      : Theme.purple
                onClicked: Ai.cycleModel(1)
                onRightClicked: Ai.cycleModel(-1)
                onScrolledUp: Ai.cycleModel(1)
                onScrolledDown: Ai.cycleModel(-1)

                BarText {
                    // Size is shown because it is what decides whether a prompt
                    // finishes in seconds or grinds on the CPU
                    text: Ai.error !== "" ? `\uf0d0 ${Ai.error}`
                        : Ai.model === "" ? "\uf0d0 no models"
                        : Ai.modelIsCloud ? `\uf0d0 ${Ai.model}  cloud`
                        : `\uf0d0 ${Ai.model}  ${Ai.modelSizeGb.toFixed(1)}G`
                    color: modelPill.accent
                }
            }

            Repeater {
                model: Ai.clipActions

                Pill {
                    id: actionPill
                    required property var modelData

                    accent: Theme.cyan
                    onClicked: Ai.actOnClipboard(actionPill.modelData)

                    BarText {
                        text: `${actionPill.modelData.glyph} ${actionPill.modelData.label}`
                        color: Theme.cyan
                    }
                }
            }
        }

        // ── Prompt ───────────────────────────────────────────
        Rectangle {
            id: prompt
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
                    id: promptGlyph
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf0d0"   // nf-fa-magic
                    color: Theme.purple
                }

                TextInput {
                    id: input
                    // Whatever the glyph and the stop/copy button leave
                    width: parent.width - promptGlyph.width - promptAction.width - parent.spacing * 2
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 2
                    color: Theme.fg
                    clip: true
                    focus: true

                    Keys.onReturnPressed: {
                        Ai.ask(text);
                        text = "";
                    }
                    Keys.onEnterPressed: {
                        Ai.ask(text);
                        text = "";
                    }
                    Keys.onEscapePressed: root.close()

                    BarText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Ask the local model"
                        color: Theme.muted
                        font.pixelSize: Theme.fontSize + 2
                        visible: input.text === ""
                    }
                }

                Pill {
                    id: promptAction
                    anchors.verticalCenter: parent.verticalCenter
                    accent: Ai.busy ? Theme.red : Theme.muted
                    bordered: false
                    onClicked: Ai.busy ? Ai.stop() : Ai.copyResponse()

                    BarText {
                        // nf-fa-stop while streaming, nf-fa-copy once done
                        text: Ai.busy ? "\uf04d" : "\uf0c5"
                        color: Ai.busy ? Theme.red : Theme.muted
                    }
                }
            }
        }

        // ── Answer ───────────────────────────────────────────
        Rectangle {
            width: parent.width
            // Whatever the other three rows leave. All four have to be counted:
            // leaving the CLI row out pushed it clean off the bottom of the card.
            height: stack.height - actions.height - prompt.height - clis.height
                - stack.spacing * 3
            radius: Theme.popupRadius
            color: Qt.alpha(Theme.muted, 0.07)
            border.width: 1
            border.color: Theme.edge(Theme.muted)

            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: Theme.modulePadH
                contentHeight: answer.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // Follow the stream as it arrives
                onContentHeightChanged: if (Ai.busy) contentY = Math.max(0, contentHeight - height)

                BarText {
                    id: answer
                    width: flick.width
                    text: Ai.response !== "" ? Ai.response
                        : Ai.busy ? "…"
                        : "Ask a question, or run one of the clipboard actions above."
                    color: Ai.response !== "" ? Theme.fg : Theme.muted
                    wrapMode: Text.Wrap
                }
            }
        }

        // ── CLI sessions ─────────────────────────────────────
        Row {
            id: clis
            width: parent.width
            spacing: Theme.moduleSpacing

            BarText {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf120"   // nf-fa-terminal
                color: Theme.muted
            }

            Repeater {
                model: Ai.clis

                Pill {
                    id: cliPill
                    required property var modelData

                    accent: Theme.green
                    onClicked: {
                        root.close();
                        Ai.launch(cliPill.modelData);
                    }

                    BarText {
                        text: cliPill.modelData.label
                        color: Theme.green
                    }
                }
            }
        }
    }
}
