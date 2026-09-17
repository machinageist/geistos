// Author: Jeff
// Description: Asynchronous launcher calculator provider backed by geist-math.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string executable: Quickshell.env("GEIST_MATH_BIN") || `${Quickshell.env("HOME")}/geistos/bin/geist-math`
    property string query: ""
    property var result: null

    function isCandidate(text) {
        const value = text.trim();
        return value !== "" && value.length <= 200
            && /^[0-9a-zA-Z_().,%+*/^\- =]+$/.test(value)
            && /[0-9]|\b(?:pi|tau|sin|cos|tan|log|ln|sqrt|abs|exp|factorial)\b/.test(value);
    }

    function setQuery(text) {
        root.query = text;
        root.result = null;
        worker.running = false;
        if (!root.isCandidate(text)) return;
        worker.command = [root.executable, text];
        worker.running = true;
    }

    Process {
        id: worker
        command: [root.executable, "0"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(text.trim());
                    if (payload.error !== undefined) return;
                    root.result = payload.value;
                } catch (error) {
                    root.result = null;
                }
            }
        }
    }
}
