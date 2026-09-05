// Author: Jeff
// Date: 2026-08-21
// Description: Notification history with a do-not-disturb toggle
// Notes: Anchored under the bar on the right, where the bell module sits.

import QtQuick
import Quickshell
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

PopupPanel {
    id: root

    cardWidth: 420
    cardHeight: 560
    placement: "topRight"
    property string query: ""
    readonly property var filtered: {
        const q = root.query.trim().toLowerCase();
        if (q === "") return Notifications.history;
        return Notifications.history.filter(n => `${n.appName} ${n.summary} ${n.body}`.toLowerCase().includes(q));
    }
    function appCount(name) { return Notifications.history.filter(n => n.appName === name).length; }

    Column {
        id: stack
        width: parent.width
        // The list below measures itself against this, so it has to be a real
        // height rather than one derived from the children it contains
        height: root.cardHeight - root.padding * 2
        spacing: 10

        // Count left, controls right. The spacer this replaces was `cardWidth - 300`,
        // which assumed the count never reached three digits.
        Item {
            id: header
            width: parent.width
            height: Theme.pillHeight

            BarText {
                anchors.left: parent.left
                anchors.right: headerControls.left
                anchors.rightMargin: Theme.cardGutter
                anchors.verticalCenter: parent.verticalCenter
                text: `Notifications (${Notifications.history.length})`
                color: Theme.fg
                elide: Text.ElideRight
            }

            Row {
                id: headerControls
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.moduleSpacing

                Pill {
                    accent: Notifications.doNotDisturb ? Theme.orange : Theme.muted
                    bordered: Notifications.doNotDisturb
                    onClicked: Notifications.toggleDnd()

                    BarText {
                        // nf-fa-bell_slash when silenced, nf-fa-bell otherwise
                        text: Notifications.doNotDisturb ? "\uf1f6" : "\uf0f3"
                        color: Notifications.doNotDisturb ? Theme.orange : Theme.muted
                    }
                }

                Pill {
                    accent: Theme.red
                    onClicked: Notifications.clearHistory()

                    BarText {
                        text: "\uf1f8"   // nf-fa-trash
                        color: Theme.red
                    }
                }
            }
        }

        Rectangle {
            id: search
            width: parent.width
            height: 34
            radius: Theme.popupRadius
            color: "transparent"
            border.width: 1
            border.color: Theme.edge(Theme.muted)
            TextInput {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                text: root.query
                onTextChanged: root.query = text
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                clip: true
                BarText { anchors.verticalCenter: parent.verticalCenter; text: "Search notification history"; color: Theme.faint; visible: parent.text === "" }
            }
        }

        // The empty state belongs inside the list's own space. As a sibling below
        // it, it added its own height plus a gap and was pushed past the card.
        Item {
            width: parent.width
            // Whatever the header and the search field leave, measured from them
            height: stack.height - header.height - search.height - stack.spacing * 2

            BarText {
                anchors.centerIn: parent
                text: "Nothing here yet"
                color: Theme.muted
                visible: Notifications.history.length === 0
            }

            ListView {
                anchors.fill: parent
                clip: true
                spacing: 6
                model: root.filtered
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: row
                    required property var modelData

                    width: ListView.view.width
                    height: Math.max(52, col.implicitHeight + 16)
                    radius: Theme.popupRadius
                    color: Qt.alpha(Theme.muted, 0.08)
                    border.width: 1
                    border.color: row.modelData.urgency === 2
                        ? Theme.edge(Theme.red)
                        : Theme.edge(Theme.muted)

                    Column {
                        id: col
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.modulePadH
                        anchors.rightMargin: Theme.modulePadH
                        spacing: 2

                        BarText {
                            width: parent.width
                            text: `${row.modelData.appName}${root.appCount(row.modelData.appName) > 1 ? ` (${root.appCount(row.modelData.appName)})` : ""}`
                            color: Theme.accent
                            font.pixelSize: Theme.fontSize - 2
                            elide: Text.ElideRight
                        }

                        BarText {
                            width: parent.width
                            text: row.modelData.summary
                            color: Theme.fg
                            elide: Text.ElideRight
                        }

                        BarText {
                            width: parent.width
                            text: row.modelData.body
                            color: Theme.muted
                            font.pixelSize: Theme.fontSize - 1
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            visible: text !== ""
                        }

                        Flow {
                            width: parent.width
                            spacing: 5
                            visible: (row.modelData.actions?.length ?? 0) > 0
                            Repeater {
                                model: row.modelData.actions ?? []
                                Rectangle {
                                    required property var modelData
                                    width: actionLabel.implicitWidth + 14
                                    height: 24
                                    radius: Theme.popupRadius
                                    color: actionHit.containsMouse ? Qt.alpha(Theme.accent, 0.18) : Qt.alpha(Theme.muted, 0.08)
                                    BarText {
                                        id: actionLabel
                                        anchors.centerIn: parent
                                        text: modelData.text
                                        color: Theme.accent
                                        font.pixelSize: Theme.fontSize - 2
                                    }
                                    MouseArea {
                                        id: actionHit
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            modelData.invoke();
                                            Notifications.forget(row.modelData.id);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        onClicked: Notifications.forget(row.modelData.id)
                    }
                }
            }
        }
    }
}
