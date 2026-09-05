// Author: Jeff
// Date: 2026-08-21
// Description: Active-theme singleton — the only color/size/font source in the shell
// Notes: Themes carry color only. Geometry, type and motion live here because they
//        are the design language, identical across all 38 palettes; a theme may
//        still override radius and font where its character demands it.
//        Theme files are generated — edit Theme/palettes.json and run
//        scripts/gen-themes.py.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ── Active theme ─────────────────────────────────────────
    property string name: "dracula"

    // The concrete dark theme "auto" toggles against; its catalog pair is the
    // light side. Named once so the pairing is not restated as a string literal.
    readonly property string autoAnchor: "lunarcore"

    // "auto" is the wallpaper-derived palette rather than a file on disk.
    // Services/Palette is injected by shell.qml rather than imported here:
    // referencing that singleton from inside this one resolves to null, with
    // no error logged, because Theme is constructed first.
    property QtObject autoPalette: null

    readonly property bool isAuto: name === "auto" && autoPalette !== null

    // Optional chaining is deliberately avoided in the proxies below: with
    // `t?.base` the engine stops tracking `base` once `t` itself stops changing,
    // so a wallpaper-derived palette updating in place never reached the bar.
    readonly property QtObject t: isAuto ? autoPalette : loader.item
    readonly property bool ready: t !== null

    Loader {
        id: loader
        asynchronous: false
        source: root.isAuto ? "" : `themes/${root.name}.qml`
    }

    // Every theme in palettes.json plus the wallpaper-derived one, for the
    // selector and for cycling
    readonly property var autoEntry: ({
        name: "auto", label: "Auto (wallpaper)", group: "Core", glyph: "\uf03e", dark: autoPalette ? autoPalette.dark : true
    })

    // The auto entry has no generated swatch; read the live derived palette
    readonly property var autoSwatch: autoPalette
        ? [autoPalette.accent, autoPalette.red, autoPalette.yellow,
           autoPalette.green, autoPalette.cyan, autoPalette.purple]
        : []

    property var catalog: [autoEntry]

    FileView {
        id: catalogFile
        path: Qt.resolvedUrl("index.json").toString().replace("file://", "")
        preload: true
        printErrors: false
        onLoaded: {
            try {
                root.catalog = [root.autoEntry, ...JSON.parse(text())];
            } catch (e) {
                root.catalog = [root.autoEntry];
            }
        }
    }

    // ── Persistence ──────────────────────────────────────────
    // Survives restarts without touching the repo, so the checked-in default
    // stays whatever Jeff committed
    FileView {
        id: stateFile
        path: `${Quickshell.statePath("theme.json")}`
        watchChanges: false
        printErrors: false

        onLoaded: {
            try {
                const saved = JSON.parse(text()).theme;
                if (saved && saved !== root.name) root.name = saved;
            } catch (e) {
                // No saved theme yet; the committed default stands
            }
        }
    }

    // Switch themes and remember the choice
    function setTheme(themeName) {
        if (!themeName || themeName === root.name) return;
        root.name = themeName;
        stateFile.setText(JSON.stringify({ theme: themeName }, null, 2));
    }

    function toggleMode() {
        let target;
        if (root.name === "auto") {
            // "auto" is wallpaper-derived rather than a catalog entry, so toggling
            // leaves it for a concrete theme of the opposite polarity. Ask the
            // catalog for the anchor's pair: "lunarcore-light" was never a theme,
            // so the guard below silently swallowed every toggle out of a dark
            // wallpaper palette — the light direction worked and the dark did not.
            const anchor = root.catalog.find(c => c.name === root.autoAnchor);
            target = root.isDark && anchor ? anchor.pair : root.autoAnchor;
        } else {
            const current = root.catalog.find(c => c.name === root.name);
            const stem = root.name.replace(/-(dark|light)$/, "");
            const lightName = `${stem}-light`;
            const darkName = `${stem}-dark`;
            target = current?.pair || (root.isDark
                ? (root.catalog.some(c => c.name === lightName) ? lightName : stem)
                : (root.catalog.some(c => c.name === darkName) ? darkName : stem));
        }
        if (root.catalog.some(c => c.name === target)) root.setTheme(target);
    }

    // Step through the catalog, wrapping at either end
    function cycleTheme(delta) {
        if (root.catalog.length === 0) return;
        const names = root.catalog.map(c => c.name);
        const i = names.indexOf(root.name);
        root.setTheme(names[(i + delta + names.length) % names.length]);
    }

    // Jump to a random theme other than the current one
    function randomTheme() {
        if (root.catalog.length < 2) return;
        const names = root.catalog.map(c => c.name).filter(n => n !== root.name);
        root.setTheme(names[Math.floor(Math.random() * names.length)]);
    }

    // ── Palette ──────────────────────────────────────────────
    readonly property color base:         t ? t.base : "#282a36"
    readonly property color surface:      t ? t.surface : "#21222c"
    readonly property color fg:           t ? t.fg : "#f8f8f2"
    readonly property color muted:        t ? t.muted : "#6272a4"
    readonly property color faint:        t ? t.faint : "#8f96ad"
    readonly property color borderColor:  t ? (t.border !== undefined ? t.border : t.borderColor) : "#44475a"
    readonly property color accent:       t ? t.accent : "#bd93f9"
    readonly property color accentHover:  t ? t.accentHover : "#cba5ff"
    readonly property color code:         t ? t.code : "#50fa7b"
    readonly property bool  isDark:       t ? t.dark : true

    readonly property color red:    t ? t.red : "#ff5555"
    readonly property color orange: t ? t.orange : "#ffb86c"
    readonly property color yellow: t ? t.yellow : "#f1fa8c"
    readonly property color green:  t ? t.green : "#50fa7b"
    readonly property color cyan:   t ? t.cyan : "#8be9fd"
    readonly property color blue:   t ? t.blue : "#6272a4"
    readonly property color purple: t ? t.purple : "#bd93f9"
    readonly property color pink:   t ? t.pink : "#ff79c6"

    // ── Surface treatment ────────────────────────────────────
    // Bar translucency carried over from window#waybar
    readonly property real surfaceAlpha: 0.63
    // Popups sit denser so text stays readable over any wallpaper
    readonly property real popupAlpha:   0.97
    // One border alpha everywhere; Waybar used 0.25 on the bar and 0.35 on modules
    readonly property real borderAlpha:  0.35

    readonly property color barBg:   Qt.alpha(base, surfaceAlpha)
    readonly property color popupBg: Qt.alpha(base, popupAlpha)

    // ── Geometry ─────────────────────────────────────────────
    readonly property int barHeight:     36
    readonly property int barMargin:      4
    readonly property int moduleSpacing:  4
    readonly property int radius:        18
    readonly property int popupRadius:   12
    readonly property int modulePadH:     8
    readonly property int iconGap:        6
    // Pills sit inside the bar with a hairline of surface showing above and below
    readonly property int pillHeight:    barHeight - 8

    // Card geometry, shared so every popup card lines its columns up identically
    readonly property int cardRowHeight:   34
    readonly property int cardActionSize:  26
    readonly property int cardGutter:      10
    readonly property int cardWhenWidth:   96

    // ── Type ─────────────────────────────────────────────────
    // Waybar asked for "JetBrains Nerd Font", which is not an installed family
    // and silently resolved to Noto Sans. This is the real name.
    readonly property string fontFamily:     "JetBrainsMono Nerd Font"
    // Keep private-use Nerd Font glyphs on the dedicated symbols face. Some
    // patched text faces expose the same codepoints with incompatible icons.
    readonly property string iconFontFamily:  "Symbols Nerd Font"
    readonly property int    fontSize:        13
    readonly property int    iconSize:   19

    // ── Motion ───────────────────────────────────────────────
    readonly property int animFast:   120
    readonly property int animNormal: 180

    // ── Module accents ───────────────────────────────────────
    // Semantic layer so no module names a ramp slot directly
    readonly property color accentOs:         cyan
    readonly property color accentWorkspace:  purple
    readonly property color accentWindow:     muted
    readonly property color accentClock:      yellow
    readonly property color accentCpu:        cyan
    readonly property color accentMemory:     purple
    readonly property color accentNetwork:    green
    readonly property color accentVolume:     orange
    readonly property color accentBrightness: fg
    // Not red: accentUrgent is also red, so a full battery and a critical one
    // rendered identically and the critical threshold was invisible.
    readonly property color accentBattery:    fg
    readonly property color accentCharging:   green
    readonly property color accentMedia:      pink
    readonly property color accentIdle:       pink
    readonly property color accentPower:      orange
    readonly property color accentNotify:     purple
    readonly property color accentUrgent:     red
    readonly property color accentTimer:      orange
    readonly property color accentStopwatch:  cyan
    readonly property color accentReminders:  green

    // Border tint for a given accent, applied identically by every module
    function edge(accent) {
        return Qt.alpha(accent, root.borderAlpha);
    }
}
