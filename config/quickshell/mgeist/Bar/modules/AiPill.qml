// Author: Jeff
// Date: 2026-08-21
// Description: AI module, opens the local-model panel
// Notes: Pulses while a generation is streaming so the bar shows work in flight

import QtQuick
import Quickshell
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

Pill {
    id: root
    accent: Ai.busy ? Theme.purple : Theme.muted
    bordered: Ai.busy
    hoverTitle: "AI usage · today"
    hoverDetail: Ai.busy
        ? "Generating a response…"
        : `OpenAI ${Telemetry.money(Telemetry.openAiToday)} • ${Telemetry.tokens(Telemetry.openAiToday.inputTokens)} input\nAnthropic ${Telemetry.money(Telemetry.anthropicToday)} • ${Telemetry.tokens(Telemetry.anthropicToday.inputTokens)} input\nClick: assistant • right-click: costs`
    onRightClicked: Quickshell.execDetached(["qs", "-c", "mgeist", "ipc", "call", "operations", "tab", "ai"])

    BarText {
        color: root.accent
        font.family: Theme.iconFontFamily
        text: "\uf0d0"   // nf-fa-magic
        font.pixelSize: Theme.iconSize - 2

        SequentialAnimation on opacity {
            running: Ai.busy
            loops: Animation.Infinite
            NumberAnimation { to: 0.35; duration: 600 }
            NumberAnimation { to: 1.0;  duration: 600 }
        }
    }
}
