// Author: Jeff
// Date: 2026-08-21
// Description: Stopwatch, left of the clock
// Notes: Collapses to a bare glyph when idle so the bar stays quiet until used.
//        Click starts and pauses, right-click resets.

import QtQuick
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

Pill {
    id: root
    accent: Stopwatch.running ? Theme.accentStopwatch : Theme.muted
    bordered: !Stopwatch.idle
    hoverTitle: "Stopwatch"
    hoverDetail: Stopwatch.idle ? "Idle — click to start" : `${Stopwatch.label} — right-click to reset`

    onClicked: Stopwatch.toggle()
    onRightClicked: Stopwatch.reset()

    BarText {
        color: root.accent
        // nf-fa-stopwatch
        text: Stopwatch.idle ? "\uf2f2" : `\uf2f2 ${Stopwatch.label}`

        Behavior on color {
            ColorAnimation { duration: Theme.animFast }
        }
    }
}
