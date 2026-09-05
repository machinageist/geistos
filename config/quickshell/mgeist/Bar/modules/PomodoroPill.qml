// Author: Jeff
// Date: 2026-08-21
// Description: Pomodoro timer, right of the clock
// Notes: Collapses to a bare glyph when idle. Click starts and pauses,
//        right-click resets the phase, middle-click skips it, scroll changes
//        the work length while idle. The border fills as the phase runs down.

import QtQuick
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

Pill {
    id: root

    readonly property bool onBreak: Pomodoro.phase !== "work"

    accent: !Pomodoro.running && !Pomodoro.idle ? Theme.muted
          : onBreak ? Theme.green
          : Theme.accentTimer
    bordered: !Pomodoro.idle
    hoverTitle: "Pomodoro"
    hoverDetail: Pomodoro.idle
        ? `Idle — ${Pomodoro.workMinutes}-minute work phase`
        : `${Pomodoro.label} — scroll adjusts while idle`
    fill: Pomodoro.idle ? 0 : Pomodoro.progress

    onClicked: Pomodoro.toggle()
    onRightClicked: Pomodoro.reset()
    onMiddleClicked: Pomodoro.skip()

    onScrolledUp: if (Pomodoro.idle) Pomodoro.workMinutes = Math.min(90, Pomodoro.workMinutes + 5)
    onScrolledDown: if (Pomodoro.idle) Pomodoro.workMinutes = Math.max(5, Pomodoro.workMinutes - 5)

    BarText {
        color: root.accent
        // nf-fa-hourglass_half
        text: Pomodoro.idle ? "\uf252" : `\uf252 ${Pomodoro.label}`

        Behavior on color {
            ColorAnimation { duration: Theme.animFast }
        }
    }
}
