// Author: Jeff
// Date: 2026-08-23
// Description: Integrated screenshot and recording card
import QtQuick
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

PopupPanel {
    id: root
    cardWidth: 420
    placement: "center"
    readonly property var entries: [
        { label: "Region to file", glyph: "\uf1fc", action: "regionFile" },
        { label: "Region to clipboard", glyph: "\uf0c5", action: "regionClipboard" },
        { label: "Active window to file", glyph: "\uf2d0", action: "windowFile" },
        { label: "Screen to file", glyph: "\uf108", action: "screenFile" },
        { label: "Screen to clipboard", glyph: "\uf24d", action: "screenClipboard" },
        { label: Capture.recording ? "Stop recording" : "Start recording", glyph: Capture.recording ? "\uf04d" : "\uf03d", action: "record" }
    ]

    function invoke(a) {
        root.close();
        if (a === "regionFile") Capture.regionFile();
        else if (a === "regionClipboard") Capture.regionClipboard();
        else if (a === "windowFile") Capture.windowFile();
        else if (a === "screenFile") Capture.screenFile();
        else if (a === "screenClipboard") Capture.screenClipboard();
        else Capture.toggleRecording();
    }

    Column {
        width: parent.width
        spacing: 5
        BarText { text: "Capture"; color: Theme.purple; font.bold: true }
        Repeater {
            model: root.entries
            Rectangle {
                required property var modelData
                width: parent.width
                height: 36
                radius: Theme.popupRadius
                color: hit.containsMouse ? Qt.alpha(Theme.purple, 0.14) : "transparent"
                Row {
                    anchors.fill: parent; anchors.leftMargin: 10; spacing: 10
                    BarText { anchors.verticalCenter: parent.verticalCenter; text: modelData.glyph; color: Theme.purple; font.family: Theme.iconFontFamily }
                    BarText { anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: Theme.fg }
                }
                MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; onClicked: root.invoke(modelData.action) }
            }
        }
    }
}
