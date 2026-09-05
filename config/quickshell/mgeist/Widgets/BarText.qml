// Author: Jeff
// Date: 2026-08-21
// Description: Bar label with the theme font already applied
// Notes: Exists so no module repeats font family and size

import QtQuick
import "root:/Theme"

Text {
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    color: Theme.fg
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}
