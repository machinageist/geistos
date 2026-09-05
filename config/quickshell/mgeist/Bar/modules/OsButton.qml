// Author: Jeff
// Date: 2026-08-21
// Description: Arch glyph, opens the launcher
// Notes: Waybar pointed this at rofi, which is not installed.
//        Glyphs are written as \u escapes so no editor or shell can mangle them.

import QtQuick
import "root:/Theme"
import "root:/Widgets"

Pill {
    id: root
    accent: Theme.accentOs
    bordered: false
    hoverTitle: "Arch launcher"
    hoverDetail: "Click to open the application launcher"

    BarText {
        font.family: Theme.iconFontFamily
        text: "\uf303"   // nf-linux-archlinux
        color: Theme.accentOs
        font.pixelSize: Theme.iconSize
    }
}
