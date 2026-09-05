// Consolidated appearance controls: theme, brightness, idle and blue light.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

Pill {
    id: root

    accent: BlueLight.active ? Theme.orange : (Theme.isDark ? Theme.blue : Theme.yellow)
    bordered: true
    hoverTitle: "Appearance"
    hoverCardWidth: 390
    hoverDetail: `Theme: ${Theme.isDark ? "Dark" : "Light"}\n`
        + `Brightness: ${Backlight.percent}%  •  ${inhibitor.enabled ? "Sleep blocked" : "Sleep allowed"}\n`
        + `Blue light: ${BlueLight.active ? `${BlueLight.temperature}K${BlueLight.autoShift ? " (auto)" : ""}` : "Off"}`
    hoverContent: appearanceControls

    onClicked: root.pinHoverCard()
    onRightClicked: BlueLight.toggle()
    onScrolledUp: Backlight.adjust(5)
    onScrolledDown: Backlight.adjust(-5)

    Connections {
        target: BlueLight
        function onAppearanceCardRequested() { root.pinHoverCard(); }
    }

    IdleInhibitor {
        id: inhibitor
        window: QsWindow.window
        enabled: false
    }

    function toggleTheme() {
        DesktopState.setPolicy("manual");
        Theme.toggleMode();
        Qt.callLater(() => Osd.show(Theme.isDark ? "\uf186" : "\uf185",
            Theme.isDark ? "Dark mode" : "Light mode", Theme.name, -1,
            Theme.isDark ? "blue" : "yellow"));
    }

    Component {
        id: appearanceControls

        Column {
            width: parent?.width ?? 0
            spacing: 8

            Rectangle { width: parent.width; height: 1; color: Theme.edge(root.accent) }

            Row {
                width: parent.width
                spacing: 8

                Text {
                    width: parent.width - brightnessDown.width - brightnessUp.width - 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: `Display brightness — ${Backlight.percent}%`
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }

                Rectangle {
                    id: brightnessDown
                    width: 38; height: 28; radius: Theme.radius
                    color: brightnessDownHit.containsMouse ? Qt.alpha(Theme.yellow, 0.18) : "transparent"
                    border.width: 1; border.color: Theme.edge(Theme.yellow)
                    Text { anchors.centerIn: parent; text: "−"; color: Theme.yellow; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 2 }
                    MouseArea { id: brightnessDownHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Backlight.adjust(-5) }
                }

                Rectangle {
                    id: brightnessUp
                    width: 38; height: 28; radius: Theme.radius
                    color: brightnessUpHit.containsMouse ? Qt.alpha(Theme.yellow, 0.18) : "transparent"
                    border.width: 1; border.color: Theme.edge(Theme.yellow)
                    Text { anchors.centerIn: parent; text: "+"; color: Theme.yellow; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 2 }
                    MouseArea { id: brightnessUpHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Backlight.adjust(5) }
                }
            }

            Rectangle {
                width: parent.width
                height: 32
                radius: Theme.radius
                color: themeHit.containsMouse ? Qt.alpha(Theme.isDark ? Theme.blue : Theme.yellow, 0.16) : "transparent"
                border.width: 1
                border.color: Theme.edge(Theme.isDark ? Theme.blue : Theme.yellow)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10
                    Text { width: 22; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignHCenter; text: Theme.isDark ? "\uf186" : "\uf185"; color: Theme.isDark ? Theme.blue : Theme.yellow; font.family: Theme.iconFontFamily; font.pixelSize: Theme.iconSize }
                    Text { width: parent.width - 32; anchors.verticalCenter: parent.verticalCenter; text: Theme.isDark ? "Dark theme — switch to light" : "Light theme — switch to dark"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; elide: Text.ElideRight }
                }
                MouseArea { id: themeHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleTheme() }
            }

            Rectangle {
                width: parent.width
                height: 32
                radius: Theme.radius
                color: idleHit.containsMouse || inhibitor.enabled ? Qt.alpha(Theme.accentIdle, 0.14) : "transparent"
                border.width: 1
                border.color: Theme.edge(inhibitor.enabled ? Theme.accentIdle : Theme.muted)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10
                    Text { width: 22; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignHCenter; text: inhibitor.enabled ? "\uf06e" : "\uf070"; color: inhibitor.enabled ? Theme.accentIdle : Theme.muted; font.family: Theme.iconFontFamily; font.pixelSize: Theme.iconSize }
                    Text { width: parent.width - 32; anchors.verticalCenter: parent.verticalCenter; text: inhibitor.enabled ? "Idle inhibitor on — sleep blocked" : "Idle inhibitor off — sleep allowed"; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; elide: Text.ElideRight }
                }
                MouseArea { id: idleHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: inhibitor.enabled = !inhibitor.enabled }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.edge(Theme.orange) }

            Row {
                width: parent.width
                spacing: 8

                Text {
                    width: parent.width - filterToggle.width - 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: BlueLight.active ? `Blue light filter — ${BlueLight.temperature}K` : "Blue light filter — off"
                    color: BlueLight.active ? Theme.orange : Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }

                Rectangle {
                    id: filterToggle
                    width: 64; height: 28; radius: Theme.radius
                    color: filterHit.containsMouse ? Qt.alpha(Theme.orange, 0.22) : Qt.alpha(Theme.orange, BlueLight.active ? 0.14 : 0.05)
                    border.width: 1; border.color: Theme.edge(Theme.orange)
                    Text { anchors.centerIn: parent; text: BlueLight.active ? "On" : "Off"; color: Theme.orange; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
                    MouseArea { id: filterHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: BlueLight.toggle() }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Repeater {
                    model: [{ label: "−", value: -200 }, { label: "+", value: 200 }]
                    Rectangle {
                        required property var modelData
                        width: 42; height: 28; radius: Theme.radius
                        color: adjustHit.containsMouse ? Qt.alpha(Theme.orange, 0.18) : "transparent"
                        border.width: 1; border.color: Theme.edge(Theme.orange)
                        Text { anchors.centerIn: parent; text: modelData.label; color: Theme.orange; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize + 2 }
                        MouseArea { id: adjustHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: BlueLight.adjust(modelData.value) }
                    }
                }

                Text { anchors.verticalCenter: parent.verticalCenter; text: `${BlueLight.temperature}K`; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize }
            }

            Row {
                width: parent.width
                spacing: 6

                Repeater {
                    model: [1800, 2700, 3500, 4000]
                    Rectangle {
                        required property int modelData
                        width: (parent.width - 18) / 4
                        height: 28
                        radius: Theme.radius
                        color: presetHit.containsMouse || (BlueLight.active && BlueLight.temperature === modelData) ? Qt.alpha(Theme.orange, 0.18) : "transparent"
                        border.width: 1; border.color: Theme.edge(Theme.orange)
                        Text { anchors.centerIn: parent; text: `${modelData}K`; color: Theme.orange; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1 }
                        MouseArea { id: presetHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: BlueLight.setTemperature(modelData) }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 30
                radius: Theme.radius
                color: autoHit.containsMouse || BlueLight.autoShift ? Qt.alpha(Theme.cyan, 0.14) : "transparent"
                border.width: 1; border.color: Theme.edge(Theme.cyan)
                Text {
                    anchors.centerIn: parent
                    text: BlueLight.autoShift ? `Auto shift on • ${BlueLight.dayHour}:00 / ${BlueLight.nightHour}:00` : "Auto shift off"
                    color: Theme.cyan; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize
                }
                MouseArea { id: autoHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: BlueLight.setAutoShift(!BlueLight.autoShift) }
            }

            Text {
                width: parent.width
                text: "Scroll the pill for brightness. Right-click toggles the blue-light filter."
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
                wrapMode: Text.WordWrap
            }
        }
    }

    Row {
        spacing: Theme.iconGap
        BarText {
            color: root.accent
            font.family: Theme.iconFontFamily
            text: Theme.isDark ? "\uf186" : "\uf185"
        }
        BarText {
            color: root.accent
            text: `${Backlight.percent}%`
        }
    }
}
