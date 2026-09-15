// Author: Jeff
// Description: Optional network-backed dictionary and thesaurus result panel.
// Notes: The launcher remains usable offline. This panel only runs after an
//        explicit lookup command and reports network/API failures plainly.

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "root:/Theme"
import "root:/Widgets"

PopupPanel {
    id: root

    cardWidth: 620
    cardHeight: 430
    placement: "center"

    property string lookupType: "dictionary"
    property string query: ""
    property string title: ""
    property string body: ""
    property string error: ""
    property bool busy: false

    function lookup(kind, word) {
        root.lookupType = kind === "thesaurus" ? "thesaurus" : "dictionary";
        root.query = String(word || "").trim();
        root.title = root.lookupType === "dictionary" ? `Define ${root.query}` : `Synonyms for ${root.query}`;
        root.body = "";
        root.error = "";
        root.busy = true;
        const encoded = encodeURIComponent(root.query);
        request.command = root.lookupType === "dictionary"
            ? ["curl", "--fail", "--silent", "--show-error", "--max-time", "5", `https://api.dictionaryapi.dev/api/v2/entries/en/${encoded}`]
            : ["curl", "--fail", "--silent", "--show-error", "--max-time", "5", `https://api.datamuse.com/words?rel_syn=${encoded}&max=16`];
        request.running = true;
    }

    function accept(text) {
        if (String(text).trim() === "") {
            root.busy = false;
            root.error = "Lookup unavailable (offline or service error)";
            return;
        }
        try {
            const data = JSON.parse(text);
            if (root.lookupType === "dictionary") {
                const entry = data[0];
                const lines = [];
                if (entry.phonetic) lines.push(entry.phonetic);
                for (const meaning of (entry.meanings || [])) {
                    for (const definition of (meaning.definitions || []).slice(0, 3)) {
                        lines.push(`${meaning.partOfSpeech || "word"}: ${definition.definition}`);
                    }
                }
                root.body = lines.join("\n\n");
            } else {
                root.body = data.map(item => item.word).filter(word => word).join(" · ");
            }
            if (root.body === "") root.error = "No result found";
        } catch (e) {
            root.error = "The lookup returned invalid data";
        }
        root.busy = false;
    }

    onOpenedChanged: {
        if (open) Qt.callLater(() => root.followFocus());
    }

    Process {
        id: request
        command: []
        stdout: StdioCollector {
            onStreamFinished: root.accept(text)
        }
        onExited: code => {
            if (code !== 0 && root.busy) {
                root.busy = false;
                root.error = "Lookup unavailable (offline or service error)";
            }
        }
    }

    Column {
        width: parent.width
        spacing: 10

        BarText {
            text: root.title
            color: Theme.fg
            font.pixelSize: Theme.fontSize + 3
        }

        Rectangle {
            width: parent.width
            height: 300
            radius: Theme.radius
            color: Theme.surface
            border.width: 1
            border.color: Theme.edge(Theme.purple)

            ScrollView {
                anchors.fill: parent
                anchors.margins: 12
                TextArea {
                    readOnly: true
                    text: root.busy ? "Looking up…" : (root.error !== "" ? root.error : root.body)
                    color: root.error !== "" ? Theme.red : Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    wrapMode: TextEdit.Wrap
                    background: null
                }
            }
        }

        BarText {
            text: "Optional network lookup · Escape closes"
            color: Theme.faint
            font.pixelSize: Theme.fontSize - 1
        }
    }
}
