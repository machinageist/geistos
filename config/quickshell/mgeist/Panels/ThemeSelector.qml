// Author: Jeff
// Date: 2026-08-21
// Description: Theme and wallpaper picker with rotation controls
// Notes: Theme chips paint their own palette so the roster reads at a glance
//        without applying anything. Wallpaper thumbnails are capped with
//        sourceSize so a 157-image library does not decode at full resolution.

import QtQuick
import Quickshell
import "root:/Theme"
import "root:/Widgets"
import "root:/Services" as Services

PopupPanel {
    id: root

    cardWidth: 760
    cardHeight: 540
    placement: "center"

    // themes | wallpaper
    property string tab: "themes"

    onOpenedChanged: if (open) Services.Wallpaper.refresh()

    Column {
        width: parent.width
        spacing: 12

        // ── Tabs and rotation ────────────────────────────────
        // Tabs left, rotation right. The spacer this replaces guessed 520 for
        // the combined width of the four pills around it.
        Item {
            width: parent.width
            height: Theme.pillHeight

            Row {
                anchors.left: parent.left
                anchors.right: rotationControls.left
                anchors.rightMargin: Theme.moduleSpacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.moduleSpacing

                Pill {
                    accent: root.tab === "themes" ? Theme.purple : Theme.muted
                    bordered: root.tab === "themes"
                    onClicked: root.tab = "themes"

                    BarText {
                        text: `\uf1de  Themes`   // nf-fa-sliders
                        color: root.tab === "themes" ? Theme.purple : Theme.muted
                    }
                }

                Pill {
                    accent: root.tab === "wallpaper" ? Theme.purple : Theme.muted
                    bordered: root.tab === "wallpaper"
                    onClicked: root.tab = "wallpaper"

                    BarText {
                        text: `\uf03e  Wallpaper`   // nf-fa-image
                        color: root.tab === "wallpaper" ? Theme.purple : Theme.muted
                    }
                }

            }

            Row {
                id: rotationControls
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.moduleSpacing

                Pill {
                    accent: Services.Rotation.enabled ? Theme.green : Theme.muted
                    bordered: Services.Rotation.enabled ?? false
                    onClicked: Services.Rotation.setEnabled(!Services.Rotation.enabled)
                    onScrolledUp: Services.Rotation.setInterval(Services.Rotation.intervalMinutes + 5)
                    onScrolledDown: Services.Rotation.setInterval(Services.Rotation.intervalMinutes - 5)

                    BarText {
                        // nf-fa-refresh
                        text: Services.Rotation.enabled ? `\uf021  ${Services.Rotation.intervalMinutes}m` : "\uf021  off"
                        color: Services.Rotation.enabled ? Theme.green : Theme.muted
                    }
                }

                Pill {
                    accent: Theme.orange
                    onClicked: Services.Rotation.next()

                    BarText {
                        text: "\uf04b"   // nf-fa-play
                        color: Theme.orange
                    }
                }
            }
        }

        // ── Themes ───────────────────────────────────────────
        GridView {
            width: parent.width
            height: 440
            visible: root.tab === "themes"
            clip: true
            cellWidth: Math.floor(parent.width / 4)
            cellHeight: 74
            model: Theme.catalog
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                required property var modelData
                width: GridView.view.cellWidth - 6
                height: 68

                readonly property bool active: modelData.name === Theme.name

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.popupRadius
                    color: parent.active ? Qt.alpha(Theme.purple, 0.16) : "transparent"
                    border.width: 1
                    border.color: parent.active ? Theme.edge(Theme.purple) : Theme.edge(Theme.muted)

                    Column {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        BarText {
                            width: parent.width
                            elide: Text.ElideRight
                            text: `${modelData.glyph}  ${modelData.label}`
                            color: parent.parent.parent.active ? Theme.fg : Theme.muted
                        }

                        // A live swatch strip of that theme's own colours
                        Row {
                            spacing: 3

                            Repeater {
                                model: modelData.name === "auto"
                                    ? Theme.autoSwatch
                                    : (modelData.swatch ?? [])

                                Rectangle {
                                    required property var modelData
                                    width: 14
                                    height: 14
                                    radius: 3
                                    color: modelData
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Theme.setTheme(modelData.name)
                }
            }
        }

        // ── Wallpapers ───────────────────────────────────────
        GridView {
            width: parent.width
            height: 440
            visible: root.tab === "wallpaper"
            clip: true
            cellWidth: Math.floor(parent.width / 4)
            cellHeight: 110
            model: Services.Wallpaper.files
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 400

            delegate: Item {
                required property var modelData
                width: GridView.view.cellWidth - 6
                height: 104

                readonly property bool active: modelData === Services.Wallpaper.current

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.popupRadius
                    color: "transparent"
                    border.width: parent.active ? 2 : 1
                    border.color: parent.active ? Theme.purple : Theme.edge(Theme.muted)
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 3
                        source: `file://${modelData}`
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        // Decode small; the library is 157 images
                        sourceSize.width: 240
                        sourceSize.height: 140
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Services.Wallpaper.apply(modelData)
                }
            }
        }
    }
}
