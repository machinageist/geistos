// Author: Jeff
// Date: 2026-08-21
// Description: Reads the live keybinding table out of Hyprland
// Notes: `hyprctl binds -j` is the source of truth, so the panel can never drift
//        from what is actually bound. A bind only appears if keybindings.lua
//        gave it a description — Hyprland exposes that as `has_description`.
//        Modmask bits: SHIFT 1, CTRL 4, ALT 8, SUPER 64.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var binds: []
    property bool loaded: false

    readonly property var groupOrder: [
        "Windows", "Workspaces", "Applications", "Panels", "Media", "Capture"
    ]

    // Break a modmask into the modifier chips shown before the key
    function modifiers(mask) {
        const out = [];
        if (mask & 64) out.push("Super");
        if (mask & 4) out.push("Ctrl");
        if (mask & 1) out.push("Shift");
        if (mask & 8) out.push("Alt");
        return out;
    }

    // Give the raw key a label a person would recognise
    function keyLabel(key) {
        const map = {
            RETURN: "Enter", SPACE: "Space", ESCAPE: "Esc", PRINT: "PrtSc",
            TAB: "Tab", SLASH: "/", GRAVE: "`", BACKSPACE: "Backspace",
            LEFT: "\u2190", RIGHT: "\u2192", UP: "\u2191", DOWN: "\u2193",
            mouse_down: "Scroll \u2193", mouse_up: "Scroll \u2191",
            "mouse:272": "Left click", "mouse:273": "Right click"
        };

        if (map[key]) return map[key];

        const upper = String(key).toUpperCase();
        if (map[upper]) return map[upper];

        // XF86 media keys read better without the prefix
        if (upper.startsWith("XF86")) return String(key).slice(4);

        return upper.length === 1 ? upper : String(key);
    }

    // Sort a bind into one of the sections the panel renders.
    // Classifying on the modifier alone does not work: the launcher and the
    // terminal live on bare SUPER but are applications, not window management.
    // The description is the honest signal, and this config writes it.
    function groupFor(bind) {
        const mask = bind.modmask;
        const key = String(bind.key).toUpperCase();
        const d = bind.description.toLowerCase();

        if (key.startsWith("XF86")) return "Media";
        if (d.startsWith("screenshot")) return "Capture";
        if (d.includes("workspace") || d.includes("scratchpad")) return "Workspaces";
        if (d.includes("launcher") || d === "terminal" || d === "file manager") return "Applications";
        if (mask & 4) return "Panels";
        return "Windows";
    }

    Process {
        id: reader
        command: ["hyprctl", "binds", "-j"]
        // Load at construction so the list is ready the first time the panel opens
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                let raw = [];
                try {
                    raw = JSON.parse(text);
                } catch (e) {
                    root.binds = [];
                    root.loaded = true;
                    return;
                }

                const out = [];
                for (const b of raw) {
                    // Undescribed binds are internal or user-forgotten; either way
                    // there is nothing useful to teach about them
                    if (!b.has_description || b.description === "") continue;

                    out.push({
                        mods: root.modifiers(b.modmask),
                        key: root.keyLabel(b.key),
                        description: b.description,
                        group: root.groupFor(b),
                        mouse: b.mouse,
                        chord: root.modifiers(b.modmask).concat([root.keyLabel(b.key)]).join(" + ")
                    });
                }

                // Group order first, then by modifier count so bare keys lead
                out.sort((a, b) => {
                    const g = root.groupOrder.indexOf(a.group) - root.groupOrder.indexOf(b.group);
                    if (g !== 0) return g;
                    if (a.mods.length !== b.mods.length) return a.mods.length - b.mods.length;
                    return a.description.localeCompare(b.description);
                });

                root.binds = out;
                root.loaded = true;
            }
        }
    }

    // Re-read from Hyprland; cheap enough to do on every panel open
    function refresh() {
        if (!reader.running) reader.running = true;
    }
}
