// Author: Jeff
// Date: 2026-08-21
// Description: Local Ollama client plus AI CLI launchers
// Notes: Quickshell has no HTTP client, so requests go through curl. Ollama
//        streams newline-delimited JSON, which SplitParser handles a line at a
//        time. Everything stays on 127.0.0.1 — no prompt leaves the machine
//        unless one of the CLI launchers is used.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string host: "http://127.0.0.1:11434"

    // Each entry is { name, size, sizeGb }
    property var models: []
    property string model: ""

    readonly property real modelSizeGb: {
        for (const m of models)
            if (m.name === root.model) return m.sizeGb;
        return 0;
    }

    readonly property bool modelIsCloud: {
        for (const m of models)
            if (m.name === root.model) return m.cloud;
        return false;
    }
    property bool busy: false
    property string prompt: ""
    property string response: ""
    property string error: ""
    // Diagnostics: stream lines seen, and anything curl complained about
    property int chunks: 0
    property string stderrText: ""

    // AI CLIs, launched in a terminal for a full session
    readonly property var clis: [
        { label: "Claude",   cmd: ["ghostty", "-e", "claude"] },
        { label: "Hermes",   cmd: ["ghostty", "-e", "hermes"] },
        { label: "Grok",     cmd: ["ghostty", "-e", "grok"] },
        { label: "opencode", cmd: ["ghostty", "-e", "opencode"] }
    ]

    // Prompts applied to whatever is on the clipboard
    readonly property var clipActions: [
        { label: "Explain",   glyph: "\uf0eb", instruction: "Explain the following clearly and concisely." },
        { label: "Summarise", glyph: "\uf075", instruction: "Summarise the following in a few sentences." },
        { label: "Rewrite",   glyph: "\uf0d0", instruction: "Rewrite the following to be clearer, keeping the meaning and tone." },
        { label: "Translate", glyph: "\uf1ab", instruction: "Translate the following into English. If it is already English, translate it into Spanish." }
    ]

    Process {
        id: tagsProc
        command: ["curl", "-s", "--max-time", "3", `${root.host}/api/tags`]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    // Smallest first. The default used to be whatever ollama
                    // listed first, which here is an 18GB model that runs 92%
                    // on CPU on a 4GB Quadro and never finishes a prompt.
                    // Cloud models report a stub size (311 bytes for
                    // deepseek-v4-pro:cloud) rather than zero. Anything under
                    // 100MB is not a local weight file. Cloud models send the
                    // prompt off the machine, so they are never the default,
                    // only an explicit choice.
                    const list = JSON.parse(text).models
                        .map(m => ({
                            name: m.name,
                            size: m.size,
                            sizeGb: m.size / 1e9,
                            cloud: m.size < 100e6
                        }))
                        .sort((a, b) => a.size - b.size);

                    root.models = list;
                    root.error = "";

                    if (list.length === 0) {
                        root.error = "no models installed";
                        return;
                    }

                    // Keep a saved choice only if it still exists
                    if (root.model !== "" && list.some(m => m.name === root.model))
                        return;

                    const local = list.filter(m => !m.cloud);
                    root.model = (local.length > 0 ? local[0] : list[0]).name;
                } catch (e) {
                    root.error = "ollama not reachable";
                }
            }
        }
    }

    // Re-read the installed model list
    function refreshModels() {
        if (!tagsProc.running) tagsProc.running = true;
    }

    // Step through the installed models, smallest to largest
    function cycleModel(delta) {
        if (models.length === 0) return;

        const names = models.map(m => m.name);
        const i = names.indexOf(root.model);
        root.setModel(names[(i + delta + names.length) % names.length]);
    }

    // Choose a model and remember it
    function setModel(name) {
        root.model = name;
        stateFile.setText(JSON.stringify({ model: name }, null, 2));
    }

    FileView {
        id: stateFile
        path: `${Quickshell.statePath("ai.json")}`
        printErrors: false

        onLoaded: {
            try {
                const saved = JSON.parse(text()).model;
                if (saved) root.model = saved;
            } catch (e) {
                // Nothing saved; the smallest installed model is used
            }
        }
    }

    Process {
        id: genProc

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: line => {
                root.chunks += 1;
                if (line.trim() === "") return;

                try {
                    const chunk = JSON.parse(line);
                    if (chunk.response) root.response += chunk.response;
                    if (chunk.done) root.busy = false;
                } catch (e) {
                    // Ollama emits an occasional non-JSON keepalive; skip it
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: root.stderrText = text.trim()
        }

        onExited: root.busy = false
    }

    // Send a prompt and stream the answer into `response`
    function ask(text) {
        if (root.busy || text.trim() === "" || root.model === "") return;

        root.prompt = text;
        root.response = "";
        root.error = "";
        root.chunks = 0;
        root.stderrText = "";
        root.busy = true;

        const payload = JSON.stringify({
            model: root.model,
            prompt: text,
            stream: true
        });

        genProc.running = false;
        genProc.command = ["curl", "-sN", "-X", "POST", `${root.host}/api/generate`,
                           "-H", "Content-Type: application/json", "-d", payload];
        genProc.running = true;
    }

    // Run one of the clipboard actions against the current clipboard contents
    function actOnClipboard(action) {
        const clip = Quickshell.clipboardText ?? "";

        if (clip.trim() === "") {
            root.response = "";
            root.error = "clipboard is empty";
            return;
        }

        root.ask(`${action.instruction}\n\n---\n${clip}`);
    }

    // Stop a running generation
    function stop() {
        genProc.running = false;
        root.busy = false;
    }

    // Put the answer on the clipboard
    function copyResponse() {
        if (root.response === "") return;
        Quickshell.clipboardText = root.response;
    }

    // Open one of the AI CLIs in a terminal
    function launch(cli) {
        Quickshell.execDetached(cli.cmd);
    }
}
