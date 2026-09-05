// Author: Jeff
// Date: 2026-08-21
// Description: Builds a theme from the current wallpaper
// Notes: Uses Quickshell's ColorQuantizer, so there is no pywal or matugen
//        dependency. Exposes the same property surface as a generated theme
//        file, which is what lets Theme.qml treat "auto" like any other theme.

pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property string source: Wallpaper.current
    readonly property bool ready: quantizer.colors.length > 0

    ColorQuantizer {
        id: quantizer
        source: root.source === "" ? "" : `file://${root.source}`
        // 2^4 buckets is enough character without turning into mud
        depth: 4
        rescaleSize: 64
    }

    // Hue anchors shared with scripts/gen-themes.py, so a derived theme and a
    // generated one assign the same meaning to each ramp slot
    readonly property var hueAnchors: ({
        red: 0, orange: 28, yellow: 50, green: 130,
        cyan: 180, blue: 215, purple: 272, pink: 322
    })

    // Shortest distance between two hues on the colour wheel, in degrees
    function hueDistance(a, b) {
        const d = Math.abs(a - b) % 360;
        return d > 180 ? 360 - d : d;
    }

    // Describe a colour as hue/saturation/lightness in degrees and 0..1
    function describe(c) {
        return { h: c.hslHue * 360, s: c.hslSaturation, l: c.hslLightness, c: c };
    }

    readonly property var swatches: {
        const out = [];
        for (const c of quantizer.colors) out.push(root.describe(c));
        return out;
    }

    // Median sampled lightness drives Auto's light/dark decision.
    readonly property real medianBrightness: {
        if (swatches.length === 0) return 0.11;
        const values = swatches.map(s => s.l).sort((a, b) => a - b);
        const mid = Math.floor(values.length / 2);
        return values.length % 2 ? values[mid] : (values[mid - 1] + values[mid]) / 2;
    }

    readonly property bool darkMode: medianBrightness < 0.50
    // Darkest or lightest swatch becomes the surface anchor depending on mode.
    readonly property color base: {
        if (!ready) return darkMode ? Qt.hsla(0, 0, 0.11, 1) : Qt.hsla(0, 0, 0.94, 1);
        const ordered = [...swatches].sort((a, b) => darkMode ? a.l - b.l : b.l - a.l);
        const anchor = ordered[0];
        return Qt.hsla(anchor.h / 360, Math.min(anchor.s, 0.35), darkMode ? Math.min(anchor.l, 0.14) : Math.max(anchor.l, 0.90), 1);
    }

    readonly property color surface: darkMode
        ? Qt.hsla(base.hslHue, base.hslSaturation, Math.max(0, base.hslLightness - 0.03), 1)
        : Qt.hsla(base.hslHue, base.hslSaturation, Math.max(0, base.hslLightness - 0.04), 1)

    // Lightest or darkest swatch becomes readable foreground depending on mode.
    readonly property color fg: {
        if (!ready) return darkMode ? Qt.hsla(0, 0, 0.96, 1) : Qt.hsla(0, 0, 0.14, 1);
        const ordered = [...swatches].sort((a, b) => darkMode ? b.l - a.l : a.l - b.l);
        const anchor = ordered[0];
        return Qt.hsla(anchor.h / 360, Math.min(anchor.s, 0.20), darkMode ? Math.max(anchor.l, 0.93) : Math.min(anchor.l, 0.16), 1);
    }

    readonly property color muted: Qt.hsla(fg.hslHue, darkMode ? 0.15 : 0.25, darkMode ? 0.62 : 0.38, 1)
    readonly property color faint: Qt.hsla(fg.hslHue, darkMode ? 0.12 : 0.20, darkMode ? 0.48 : 0.54, 1)
    readonly property color borderColor: Qt.hsla(base.hslHue, darkMode ? 0.18 : 0.24, darkMode ? 0.30 : 0.72, 1)

    // The most colourful swatch that is not nearly black or nearly white
    readonly property color accent: {
        if (!ready) return Qt.hsla(hueAnchors.purple / 360, 0.62, 0.68, 1);
        const usable = swatches.filter(s => s.l > 0.25 && s.l < 0.85);
        const pool = usable.length > 0 ? usable : swatches;
        const best = [...pool].sort((a, b) => b.s - a.s)[0];
        return Qt.hsla(best.h / 360, Math.max(best.s, 0.55), darkMode ? 0.68 : 0.42, 1);
    }

    readonly property color accentHover: Qt.hsla(accent.hslHue, accent.hslSaturation, 0.78, 1)

    // Pick the wallpaper's own colour nearest each anchor, or synthesise the
    // anchor hue when the image has nothing close to it
    function slot(name) {
        const anchor = hueAnchors[name];
        if (!ready) return Qt.hsla(anchor / 360, 0.65, 0.68, 1);

        const usable = swatches.filter(s => s.s > 0.22 && s.l > 0.20 && s.l < 0.88);
        let best = null;
        let bestD = 999;

        for (const s of usable) {
            const d = root.hueDistance(s.h, anchor);
            if (d < bestD) {
                bestD = d;
                best = s;
            }
        }

        // 40 degrees is about the point past which the hue stops reading as the
        // slot's colour at all, so beyond that use the anchor instead
        if (best === null || bestD > 40)
            return Qt.hsla(anchor / 360, 0.62, darkMode ? 0.68 : 0.42, 1);

        return Qt.hsla(best.h / 360, Math.max(best.s, 0.5), darkMode ? 0.68 : 0.42, 1);
    }

    readonly property color red:    slot("red")
    readonly property color orange: slot("orange")
    readonly property color yellow: slot("yellow")
    readonly property color green:  slot("green")
    readonly property color cyan:   slot("cyan")
    readonly property color blue:   slot("blue")
    readonly property color purple: slot("purple")
    readonly property color pink:   slot("pink")

    readonly property color code: green

    readonly property string themeName: "auto"
    readonly property string label: "Auto (wallpaper)"
    readonly property string group: "Core"
    readonly property string glyph: "\uf03e"
    readonly property bool dark: root.darkMode
}
