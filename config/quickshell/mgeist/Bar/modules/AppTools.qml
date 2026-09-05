// Author: Jeff
// Date: 2026-08-23
// Description: Focused-application tools menu for the left bar
// Notes: Profiles are explicit and conservative. Actions use native CLIs where
// possible; the menu stays empty for unsupported applications.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

Pill {
    id: root

    readonly property string appClass: activeClass.toLowerCase()
    readonly property string appTitle: activeTitle || Hyprland.activeToplevel?.title || ""
    readonly property string appTitleLower: appTitle.toLowerCase()
    readonly property bool isYazi: appClass === "yazi" || appTitleLower.includes("yazi")
    readonly property var actions: root.profile(root.appClass)
    property string activeClass: ""
    property string activeTitle: ""
    property bool menuOpen: false

    visible: actions.length > 0
    accent: Theme.accentWindow
    bordered: menuOpen
    hoverTitle: root.menuOpen ? "" : "Application tools"
    hoverDetail: root.menuOpen ? "" : `${root.appLabel()} — ${actions.length} available actions`

    Timer {
        interval: 400
        running: true
        repeat: true
        onTriggered: if (!activeWindow.running) activeWindow.running = true
    }

    Process {
        id: activeWindow
        command: ["hyprctl", "activewindow", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.activeClass = data.class || data.initialClass || "";
                    root.activeTitle = data.title || "";
                } catch (e) {
                    root.activeClass = "";
                    root.activeTitle = "";
                }
            }
        }
    }

    function appLabel() {
        if (isYazi) return "Yazi";
        if (appClass.includes("firefox")) return "Firefox";
        if (appClass.includes("ghostty")) return "Ghostty";
        if (appClass.includes("neovim") || appClass === "nvim") return "Neovim";
        if (appClass.includes("rmpc")) return "rmpc";
        if (appClass.includes("cliamp")) return "cliamp";
        return appTitle || "Application";
    }

    function profile(cls) {
        if (isYazi) return [
            { label: "New file manager", glyph: "\uf07b", command: ["ghostty", "-e", "yazi"] },
            { label: "Yazi config", glyph: "\uf013", command: ["ghostty", "-e", "nvim", `${Quickshell.env("HOME")}/.config/yazi/yazi.toml`] },
            { label: "Yazi keymap", glyph: "\uf11c", command: ["ghostty", "-e", "nvim", `${Quickshell.env("HOME")}/.config/yazi/keymap.toml`] },
            { label: "Yazi theme", glyph: "\uf1fc", command: ["ghostty", "-e", "nvim", `${Quickshell.env("HOME")}/.config/yazi/theme.toml`] },
            { label: "Clear Yazi cache", glyph: "\uf021", command: ["ya", "cache", "clear"] }
        ];
        if (cls.includes("firefox")) return [
            { label: "New tab", glyph: "\uf067", command: ["firefox", "--new-tab", "about:blank"] },
            { label: "New window", glyph: "\uf2d0", command: ["firefox", "--new-window"] },
            { label: "Private window", glyph: "\uf21b", command: ["firefox", "--private-window"] },
            { label: "Downloads", glyph: "\uf019", command: ["firefox", "about:downloads"] }
        ];
        if (cls.includes("ghostty")) return [
            { label: "New terminal", glyph: "\uf120", command: ["ghostty"] },
            { label: "New terminal window", glyph: "\uf00a", command: ["ghostty", "+new-window"] }
        ];
        if (cls === "yazi") return [
            { label: "New file manager", glyph: "\uf07b", command: ["ghostty", "-e", "yazi"] },
            { label: "Terminal here", glyph: "\uf120", command: ["ghostty"] }
        ];
        if (cls.includes("neovim") || cls === "nvim") return [
            { label: "New Neovim", glyph: "\uf121", command: ["ghostty", "-e", "nvim"] },
            { label: "Edit config", glyph: "\uf085", command: ["ghostty", "-e", "nvim", `${Quickshell.env("HOME")}/.config/nvim/init.lua`] }
        ];
        if (cls.includes("rmpc")) return [
            { label: "Play / pause", glyph: "\uf04b", media: "toggle" },
            { label: "Next track", glyph: "\uf051", media: "next" },
            { label: "Open rmpc", glyph: "\uf001", media: "open" }
        ];
        if (cls.includes("cliamp")) return [
            { label: "Play / pause", glyph: "\uf04b", media: "toggle" },
            { label: "Next track", glyph: "\uf051", media: "next" },
            { label: "Open cliamp", glyph: "\uf001", media: "open" }
        ];
        return [];
    }

    function run(action) {
        if (action.media === "toggle") MediaBridge.toggle();
        else if (action.media === "next") MediaBridge.next();
        else if (action.media === "open") MediaBridge.open();
        else if (action.command) Quickshell.execDetached(action.command);
        root.menuOpen = false;
    }

    onClicked: {
        root.closeHoverCard();
        root.menuOpen = !root.menuOpen;
    }

    BarText {
        color: root.accent
        font.family: Theme.iconFontFamily
        text: `\uf0c9 ${root.appLabel()}`
        elide: Text.ElideRight
    }

    PopupWindow {
        id: menu
        anchor.item: root
        anchor.rect.x: -(implicitWidth - root.width) / 2
        anchor.rect.y: root.height + Theme.barMargin
        visible: root.menuOpen
        grabFocus: true
        implicitWidth: 260
        implicitHeight: card.implicitHeight + 8
        color: "transparent"
        onVisibleChanged: if (!visible && root.menuOpen) root.menuOpen = false

        Rectangle {
            id: card
            anchors.fill: parent
            anchors.margins: 4
            radius: Theme.popupRadius
            color: Theme.popupBg
            border.width: 1
            border.color: Theme.edge(root.accent)
            implicitHeight: body.implicitHeight + 24

            Column {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 5

                Text {
                    width: parent.width
                    text: `${root.appLabel()} tools`
                    color: root.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                }

                Repeater {
                    model: root.actions

                    Rectangle {
                        required property var modelData
                        width: body.width
                        height: 30
                        radius: Theme.popupRadius
                        color: actionMouse.containsMouse ? Qt.alpha(root.accent, 0.14) : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            spacing: Theme.iconGap

                            BarText {
                                text: modelData.glyph
                                color: root.accent
                                font.family: Theme.iconFontFamily
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                        }

                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.run(modelData)
                        }
                    }
                }
            }
        }
    }
}
