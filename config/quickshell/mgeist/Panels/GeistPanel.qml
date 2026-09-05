// Lightweight under-toolbar card for the local-first Geist application suite.
import QtQuick
import Quickshell
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

PopupPanel {
    id: root
    cardWidth: 720
    cardHeight: 500
    placement: "center"
    property string currentPage: "calendar"

    readonly property var pages: [
        { id: "calendar", label: "Calendar", glyph: "\uf073", accent: Theme.yellow,
          title: "mg-calr", summary: "Calendar and event authority with a projection-backed todo agenda.",
          capabilities: "Calendar/event commands, projection-backed agenda queries, lifecycle operations, interop snapshots, and a bounded keyboard shell.",
          remaining: "Recurrence exceptions, iCalendar sync, backup/restore, and a full-screen raw-mode TUI remain incremental." },
        { id: "todo", label: "Plan / Todo", glyph: "\uf0ae", accent: Theme.orange,
          title: "mg-plan + mg-remindr", summary: "Plan-native commitment and verification kernel with the legacy todo compatibility surface.",
          capabilities: "Stable work items, prerequisites, criteria, revision-pinned verification, typed gaps, scheduling requests/receipts, and compatibility persistence.",
          remaining: "The mg-remindr migration and a user-facing plan UI remain incremental." },
        { id: "brief", label: "Brief", glyph: "\uf1ea", accent: Theme.cyan,
          title: "mg-brief", summary: "Local-first RSS/Atom collection and immutable provenance-first CVE intelligence.",
          capabilities: "Register, list, fetch, and export feeds; ingest CVE revisions; query current/history; inspect assets; deterministic redacted interop export; read-only status.",
          remaining: "Scheduled monitoring, richer finding workflows, and explainable advisory-to-asset matching remain incremental." },
        { id: "vault", label: "Vault", glyph: "\uf02d", accent: Theme.purple,
          title: "mg-vault", summary: "Markdown-authoritative local knowledge with a disposable search projection.",
          capabilities: "Read-only vault registry status; safe notes, index rebuild/status/search, and interop export in the app.",
          remaining: "Watcher service, richer projections, query grammar, editor/TUI, and sync remain open." },
        { id: "contacts", label: "Contacts", glyph: "\uf2bb", accent: Theme.green,
          title: "mg-contacts", summary: "Encrypted-key foundation for a private local contacts authority.",
          capabilities: "Encrypted contact CRUD, process-local authentication, soft deletion, audit history, and redacted key/configuration status with XDG boundaries.",
          remaining: "Imports, organizations, relationships, digests, and interoperability remain incremental." }
    ]

    readonly property var current: pages.find(page => page.id === currentPage) ?? pages[0]
    readonly property var live: GeistStatus.value(currentPage)

    function showPage(name) {
        root.currentPage = root.pages.some(page => page.id === name) ? name : "calendar";
        root.show();
    }

    function launch(name) {
        if (!root.canLaunch(name)) return;
        Quickshell.execDetached([`${Quickshell.env("HOME")}/dotfiles/scripts/geist-app-launch`, name]);
        root.close();
    }

    function canLaunch(name) {
        const status = GeistStatus.value(name).status;
        return status !== "unavailable" && status !== "unsupported" && status !== "stale";
    }

    // Page ids are UI labels; the suite directories they open are named separately
    readonly property var repositories: ({
        calendar: "mg-calr",
        todo: "mg-remindr",
        brief: "mg-briefr",
        vault: "mg-vaultr",
        contacts: "mg-contactr"
    })

    function openRepository(name) {
        const directory = root.repositories[name] ?? root.repositories.calendar;
        Quickshell.execDetached(["ghostty", `--working-directory=${Quickshell.env("HOME")}/geistos/mg-suite/${directory}`]);
        root.close();
    }

    function statusTone(status) {
        if (status === "ready") return Theme.green;
        if (status === "checking") return Theme.cyan;
        if (status === "stale") return Theme.yellow;
        if (status === "locked" || status === "unconfigured" || status === "storage-disabled") return Theme.orange;
        return Theme.red;
    }

    component ActionButton: Rectangle {
        required property string label
        required property color tone
        property bool enabled: true
        signal activated()
        width: 164
        height: 36
        radius: Theme.radius
        opacity: enabled ? 1 : 0.45
        color: enabled && actionHit.containsMouse ? Qt.alpha(tone, 0.16) : "transparent"
        border.width: 1
        border.color: Theme.edge(tone)
        BarText { anchors.centerIn: parent; text: parent.label; color: parent.tone; font.bold: true }
        MouseArea { id: actionHit; anchors.fill: parent; hoverEnabled: parent.enabled; enabled: parent.enabled; onClicked: parent.activated() }
    }

    Column {
        width: parent.width
        spacing: 12

        // Pages left, refresh anchored right; the 500 this replaces was a guess at
        // the combined width of five page pills
        Item {
            width: parent.width
            height: Theme.pillHeight

            Row {
                anchors.left: parent.left
                anchors.right: refreshPill.left
                anchors.rightMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                Repeater {
                    model: root.pages
                    Pill {
                        required property var modelData
                        accent: root.currentPage === modelData.id ? modelData.accent : Theme.muted
                        bordered: root.currentPage === modelData.id
                        onClicked: root.currentPage = modelData.id
                        Row {
                            spacing: Theme.iconGap
                            BarText { text: modelData.glyph; color: root.currentPage === modelData.id ? modelData.accent : Theme.muted; font.family: Theme.iconFontFamily }
                            BarText { text: modelData.label; color: root.currentPage === modelData.id ? modelData.accent : Theme.muted }
                        }
                    }
                }
            }

            Pill {
                id: refreshPill
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                accent: GeistStatus.error !== "" ? Theme.red : Theme.cyan
                onClicked: GeistStatus.refresh()
                BarText {
                    text: GeistStatus.busy ? "\uf110" : "\uf021"
                    color: refreshPill.accent
                    font.family: Theme.iconFontFamily
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.edge(Theme.muted) }

        Row {
            id: body
            width: parent.width
            spacing: 16

            Column {
                id: sidebar
                width: 164
                spacing: 10
                Rectangle {
                    width: 78; height: 78; radius: 39
                    color: Qt.alpha(root.current.accent, 0.12)
                    border.width: 1; border.color: Theme.edge(root.current.accent)
                    BarText { anchors.centerIn: parent; text: root.current.glyph; color: root.current.accent; font.family: Theme.iconFontFamily; font.pixelSize: 34 }
                }
                BarText { text: root.current.title; color: root.current.accent; font.pixelSize: Theme.fontSize + 4; font.bold: true }
                ActionButton {
                    label: root.canLaunch(root.currentPage) ? `Open ${root.current.title}` : "Unavailable"
                    tone: root.current.accent
                    enabled: root.canLaunch(root.currentPage)
                    onActivated: root.launch(root.currentPage)
                }
                ActionButton {
                    visible: root.currentPage === "calendar"
                    label: GeistUi.projectionBusy ? "Refreshing…" : "Refresh todo agenda"
                    tone: Theme.cyan
                    enabled: !GeistUi.projectionBusy
                    onActivated: GeistUi.syncTodoProjection()
                }
                ActionButton { label: "Open repository"; tone: Theme.muted; onActivated: root.openRepository(root.currentPage) }
            }

            Column {
                // The 180 this replaces was the sidebar plus the gap, restated
                width: parent.width - sidebar.width - body.spacing
                spacing: 10

                BarText {
                    width: parent.width
                    text: root.current.summary
                    color: Theme.fg
                    font.pixelSize: Theme.fontSize + 2
                    font.bold: true
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: parent.width
                    height: liveColumn.implicitHeight + Theme.cardGutter * 2
                    radius: Theme.radius
                    color: Qt.alpha(root.statusTone(root.live.status), 0.09)
                    border.width: 1
                    border.color: Theme.edge(root.statusTone(root.live.status))
                    Column {
                        id: liveColumn
                        x: Theme.cardGutter; y: Theme.cardGutter
                        width: parent.width - Theme.cardGutter * 2
                        spacing: 4
                        BarText {
                            text: `Live status  •  ${root.live.status ?? "unavailable"}`
                            color: root.statusTone(root.live.status)
                            font.bold: true
                        }
                        BarText { width: parent.width; text: root.live.detail ?? "No detail available."; color: Theme.fg; wrapMode: Text.WordWrap }
                        BarText {
                            width: parent.width
                            text: `Checked ${GeistStatus.checkedAt || "—"}${root.live.stale ? " • showing last known state" : ""}`
                            color: Theme.faint
                            font.pixelSize: Theme.fontSize - 2
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: capabilitiesColumn.implicitHeight + Theme.cardGutter * 2
                    radius: Theme.radius
                    color: Qt.alpha(root.current.accent, 0.07)
                    border.width: 1
                    border.color: Theme.edge(root.current.accent)
                    Column {
                        id: capabilitiesColumn
                        x: Theme.cardGutter; y: Theme.cardGutter
                        width: parent.width - Theme.cardGutter * 2
                        spacing: 4
                        BarText { text: "Supported now"; color: root.current.accent; font.bold: true }
                        BarText { width: parent.width; text: root.current.capabilities; color: Theme.fg; wrapMode: Text.WordWrap }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: remainingColumn.implicitHeight + Theme.cardGutter * 2
                    radius: Theme.radius
                    color: Qt.alpha(Theme.muted, 0.06)
                    border.width: 1
                    border.color: Theme.edge(Theme.muted)
                    Column {
                        id: remainingColumn
                        x: Theme.cardGutter; y: Theme.cardGutter
                        width: parent.width - Theme.cardGutter * 2
                        spacing: 4
                        BarText { text: "Remaining scope"; color: Theme.muted; font.bold: true }
                        BarText { width: parent.width; text: root.current.remaining; color: Theme.muted; wrapMode: Text.WordWrap }
                    }
                }

                BarText {
                    width: parent.width
                    text: GeistStatus.error !== "" ? GeistStatus.error : `${GeistUi.projectionStatus} • read-only probes use bounded output and no sibling database access.`
                    color: GeistStatus.error !== "" ? Theme.red : Theme.faint
                    font.pixelSize: Theme.fontSize - 2
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
