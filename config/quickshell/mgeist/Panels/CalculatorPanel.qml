// Author: Jeff
// Description: Keyboard-first calculator panel backed by the Rust mg-calcr CLI.
// Notes: The panel owns input/history only; parsing, evaluation, formatting, and
//        graph sampling remain in the presentation-independent suite core.

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "root:/Theme"
import "root:/Widgets"

PopupPanel {
    id: root

    cardWidth: 560
    cardHeight: root.mode === "graph" ? 500 : 680
    placement: "center"

    property string expression: ""
    property string result: ""
    property string error: ""
    property string mode: "standard"
    property string angle: "radians"
    property var history: []
    property var graphPoints: []
    property real graphMin: -10
    property real graphMax: 10
    property bool requestBusy: false
    property bool copyOnResult: false
    property int requestSerial: 0
    readonly property string calcrBinary: Quickshell.env("MG_CALCR_BIN") || `${Quickshell.env("HOME")}/geistos/mg-suite/mg-calcr/target/debug/mg-calcr`
    readonly property var standardKeys: ["7", "8", "9", "/", "4", "5", "6", "*", "1", "2", "3", "-", "0", ".", "(", ")", "C", "^", "%", "+"]
    readonly property var scientificKeys: ["sin(", "cos(", "tan(", "ln(", "log(", "sqrt(", "pi", "e", "abs(", "exp(", "!", "^"]

    onOpenedChanged: {
        if (!open) return;
        root.expression = "";
        input.text = "";
        root.result = "";
        root.error = "";
        root.requestBusy = false;
        root.copyOnResult = false;
        root.mode = "standard";
        Qt.callLater(() => input.forceActiveFocus());
    }

    function calculate() {
        root.error = "";
        if (root.expression.trim() === "") {
            root.result = "";
            root.graphPoints = [];
            root.requestBusy = false;
            return;
        }
        requestTimer.restart();
    }

    function issueRustRequest() {
        root.requestSerial += 1;
        root.requestBusy = true;
        root.result = "";
        root.error = "";
        const args = root.mode === "graph"
            ? ["sample", root.expression, `--minimum=${root.graphMin}`, `--maximum=${root.graphMax}`, "--points", "240", "--angle", root.angle, "--json"]
            : ["evaluate", root.expression, "--angle", root.angle, "--json"];
        if (calculatorProcess.running) calculatorProcess.running = false;
        calculatorProcess.command = [root.calcrBinary, ...args];
        calculatorProcess.running = true;
    }

    function acceptRustOutput(text) {
        if (!root.requestBusy) return;
        try {
            const data = JSON.parse(String(text));
            if (root.mode === "graph") {
                if (!Array.isArray(data)) throw new Error("mg-calcr returned an invalid graph");
                root.graphPoints = data;
                root.error = data.some(point => point.y !== null) ? "" : "No finite points in range";
            } else if (data.error) {
                root.error = data.error;
                root.result = "";
            } else {
                root.result = data.formatted || "";
                if (root.copyOnResult && root.result !== "") {
                    root.history = [{ expression: root.expression, result: root.result }].concat(root.history).slice(0, 12);
                    Quickshell.clipboardText = root.result;
                    root.copyOnResult = false;
                }
            }
        } catch (e) {
            root.error = "mg-calcr returned invalid JSON";
        }
        root.requestBusy = false;
    }

    function accept() {
        root.copyOnResult = true;
        requestTimer.stop();
        root.issueRustRequest();
    }

    function useHistory(item) {
        root.expression = item.expression;
        input.text = item.expression;
        root.calculate();
    }

    function press(key) {
        if (key === "C") {
            input.text = "";
            root.expression = "";
            root.calculate();
            input.forceActiveFocus();
            return;
        }
        input.insert(input.cursorPosition, key);
        input.forceActiveFocus();
    }

    function zoomGraph(factor) {
        const center = (root.graphMin + root.graphMax) / 2;
        const half = Math.max(0.25, (root.graphMax - root.graphMin) * factor / 2);
        root.graphMin = Math.round((center - half) * 100) / 100;
        root.graphMax = Math.round((center + half) * 100) / 100;
        root.calculate();
    }

    function resetGraphRange() {
        root.graphMin = -10;
        root.graphMax = 10;
        root.calculate();
    }

    Timer {
        id: requestTimer
        interval: 120
        repeat: false
        onTriggered: root.issueRustRequest()
    }

    Process {
        id: calculatorProcess
        command: []
        stdout: StdioCollector {
            onStreamFinished: root.acceptRustOutput(text)
        }
        onExited: code => {
            if (code !== 0 && root.requestBusy) {
                root.requestBusy = false;
                root.error = `mg-calcr unavailable (exit ${code})`;
            }
        }
    }

    Column {
        width: parent.width
        spacing: 10

        Column {
            width: parent.width
            spacing: 8

            BarText {
                text: "Calculator"
                color: Theme.fg
                font.pixelSize: Theme.fontSize + 4
                font.bold: true
            }

            Row {
                width: parent.width
                spacing: 6
                Button {
                    width: 86
                    height: 30
                    text: "Standard"
                    onClicked: { root.mode = "standard"; root.calculate(); }
                    Accessible.name: "Standard calculator mode"
                }
                Button {
                    width: 98
                    height: 30
                    text: "Scientific"
                    onClicked: { root.mode = "scientific"; root.calculate(); }
                    Accessible.name: "Scientific calculator mode"
                }
                Button {
                    width: 64
                    height: 30
                    text: "Graph"
                    onClicked: { root.mode = "graph"; root.calculate(); }
                    Accessible.name: "Graphing calculator mode"
                }
                Button {
                    width: 54
                    height: 30
                    text: root.angle === "radians" ? "RAD" : "DEG"
                    onClicked: root.angle = root.angle === "radians" ? "degrees" : "radians"
                    Accessible.name: "Toggle radians and degrees"
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 128
            radius: Theme.radius
            color: Theme.surface
            border.width: 1
            border.color: Theme.edge(Theme.purple)

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                TextInput {
                    id: input
                    width: parent.width
                    height: 48
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 10
                    selectByMouse: true
                    clip: true
                    onTextChanged: { root.expression = text; root.calculate(); }
                    Keys.onReturnPressed: root.accept()
                    Keys.onEnterPressed: root.accept()
                    Keys.onEscapePressed: root.close()
                }

                BarText {
                    width: parent.width
                    text: root.error !== "" ? root.error : (root.requestBusy ? "Evaluating with mg-calcr…" : (root.result === "" ? (root.mode === "scientific" ? "sin, cos, tan, log, ln, sqrt, x^y, factorial" : root.mode === "graph" ? "y = sin(x) or x^2" : "Enter an expression") : `= ${root.result}`))
                    color: root.error !== "" ? Theme.red : Theme.muted
                    font.pixelSize: Theme.fontSize + 2
                    font.bold: root.result !== ""
                }
            }
        }

        Grid {
            visible: root.mode !== "graph"
            width: parent.width
            columns: 4
            rowSpacing: 6
            columnSpacing: 6
            Repeater {
                model: root.mode === "scientific" ? root.scientificKeys : root.standardKeys
                Button {
                    required property string modelData
                    width: (parent.width - 18) / 4
                    height: 34
                    text: modelData
                    Accessible.name: modelData === "C" ? "Clear calculator" : `Insert ${modelData}`
                    onClicked: root.press(modelData)
                }
            }
        }

        Row {
            visible: root.mode === "graph"
            width: parent.width
            spacing: 6
            Button {
                text: "−"
                Accessible.name: "Zoom graph out"
                onClicked: root.zoomGraph(1.5)
            }
            Button {
                text: "+"
                Accessible.name: "Zoom graph in"
                onClicked: root.zoomGraph(0.67)
            }
            BarText {
                width: 190
                anchors.verticalCenter: parent.verticalCenter
                text: `x range ${root.graphMin} to ${root.graphMax}`
                color: Theme.muted
                elide: Text.ElideRight
            }
            Button {
                text: "Reset range"
                Accessible.name: "Reset graph range"
                onClicked: root.resetGraphRange()
            }
        }

        Graph {
            visible: root.mode === "graph"
            width: parent.width
            height: 190
            plotMode: true
            points: root.graphPoints
            xMin: root.graphMin
            xMax: root.graphMax
            yMin: -10
            yMax: 10
            stroke: Theme.purple
        }

        BarText {
            text: root.history.length === 0 ? "No history" : "History"
            color: Theme.muted
            visible: root.history.length > 0
        }

        ListView {
            width: parent.width
            height: Math.min(180, root.history.length * 30)
            model: root.history
            clip: true
            delegate: Rectangle {
                required property var modelData
                width: parent ? parent.width : 0
                height: 28
                radius: Theme.popupRadius
                color: mouse.containsMouse ? Qt.alpha(Theme.purple, 0.14) : "transparent"
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.modulePadH
                    spacing: 8
                    BarText { text: modelData.expression; color: Theme.fg }
                    BarText { text: `= ${modelData.result}`; color: Theme.muted }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.useHistory(modelData)
                }
            }
        }

        BarText {
            text: "Enter evaluates and copies · Escape closes"
            color: Theme.faint
            font.pixelSize: Theme.fontSize - 1
        }
    }
}
