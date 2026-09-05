// Author: Jeff
// Date: 2026-08-21
// Description: Notification count, opens the centre
// Notes: Click is wired from Bar.qml so the module stays unaware of the panels

import QtQuick
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

Pill {
    id: root
    accent: Notifications.doNotDisturb ? Theme.muted
          : Notifications.history.length > 0 ? Theme.accentNotify
          : Theme.muted
    bordered: Notifications.history.length > 0 && !Notifications.doNotDisturb
    hoverTitle: "Notifications"
    hoverDetail: Notifications.doNotDisturb
        ? "Do not disturb is enabled"
        : `${Notifications.history.length} notification${Notifications.history.length === 1 ? "" : "s"}`

    BarText {
        color: root.accent
        font.family: Theme.iconFontFamily
        // nf-fa-bell_slash while silenced, nf-fa-bell otherwise
        text: Notifications.doNotDisturb
            ? "\uf1f6"
            : Notifications.history.length > 0
                ? `\uf0f3 ${Notifications.history.length}`
                : "\uf0f3"
    }
}
