// Author: Jeff
// Date: 2026-08-21
// Description: Backlight percentage via brightnessctl
// Notes: `brightnessctl -m` prints device,class,current,percent,max on one line

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int percent: 0

    // Read the current backlight level
    function refresh() {
        if (!reader.running) reader.running = true;
    }

    // Nudge the backlight and re-read once brightnessctl has applied it
    function adjust(deltaPercent) {
        const step = deltaPercent > 0 ? `${deltaPercent}%+` : `${-deltaPercent}%-`;
        Quickshell.execDetached(["brightnessctl", "set", step]);
        settle.restart();
    }

    Process {
        id: reader
        command: ["brightnessctl", "-m"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const field = text.trim().split(",")[3];
                if (field) root.percent = parseInt(field);
            }
        }
    }

    Timer {
        id: settle
        interval: 80
        onTriggered: root.refresh()
    }

    // Catch changes made by the XF86 brightness keys, which bypass this service
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
