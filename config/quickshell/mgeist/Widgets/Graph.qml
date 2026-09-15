// Author: Jeff
// Date: 2026-08-21
// Description: Filled area sparkline over a rolling series
// Notes: Canvas rather than Shape because the series is redrawn wholesale every
//        tick anyway. maxValue of 0 auto-scales, which is what network rates
//        need — their range spans several orders of magnitude.

import QtQuick
import "root:/Theme"

Canvas {
    id: root

    property var values: []
    property color stroke: Theme.accent
    property real maxValue: 1
    property real lineWidth: 1.5
    property bool barMode: false
    property var barColors: []
    property bool grid: true
    // Optional Cartesian plotting mode. Existing sparkline consumers leave this false.
    property bool plotMode: false
    property var points: []
    property real xMin: -10
    property real xMax: 10
    property real yMin: -10
    property real yMax: 10

    readonly property real peak: {
        if (root.maxValue > 0) return root.maxValue;

        let m = 0;
        for (const v of root.values) if (v > m) m = v;
        // Never divide by zero, and leave headroom so a flat line is not glued
        // to the top of the box
        return m > 0 ? m * 1.15 : 1;
    }

    onValuesChanged: requestPaint()
    onPointsChanged: requestPaint()
    onStrokeChanged: requestPaint()
    onBarModeChanged: requestPaint()
    onPlotModeChanged: requestPaint()
    onBarColorsChanged: requestPaint()
    onXMinChanged: requestPaint()
    onXMaxChanged: requestPaint()
    onYMinChanged: requestPaint()
    onYMaxChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.clearRect(0, 0, width, height);

        if (root.plotMode) {
            const xSpan = Math.max(0.000001, root.xMax - root.xMin);
            const ySpan = Math.max(0.000001, root.yMax - root.yMin);
            const xFor = x => (x - root.xMin) / xSpan * width;
            const yForPlot = y => height - (y - root.yMin) / ySpan * height;
            ctx.strokeStyle = Qt.alpha(root.stroke, 0.14);
            ctx.lineWidth = 1;
            for (let i = 1; i < 10; i++) {
                const gx = width * i / 10;
                const gy = height * i / 10;
                ctx.beginPath(); ctx.moveTo(gx, 0); ctx.lineTo(gx, height); ctx.stroke();
                ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(width, gy); ctx.stroke();
            }
            ctx.strokeStyle = Qt.alpha(root.stroke, 0.55);
            const axisX = xFor(0);
            const axisY = yForPlot(0);
            if (axisX >= 0 && axisX <= width) { ctx.beginPath(); ctx.moveTo(axisX, 0); ctx.lineTo(axisX, height); ctx.stroke(); }
            if (axisY >= 0 && axisY <= height) { ctx.beginPath(); ctx.moveTo(0, axisY); ctx.lineTo(width, axisY); ctx.stroke(); }
            ctx.beginPath();
            let drawing = false;
            for (const point of root.points) {
                if (!point || point.y === null || !Number.isFinite(point.y)) { drawing = false; continue; }
                const px = xFor(point.x);
                const py = yForPlot(point.y);
                if (px < 0 || px > width) { drawing = false; continue; }
                if (!drawing) { ctx.moveTo(px, py); drawing = true; }
                else ctx.lineTo(px, py);
            }
            ctx.strokeStyle = root.stroke;
            ctx.lineWidth = root.lineWidth + 0.5;
            ctx.stroke();
            return;
        }

        if (root.grid) {
            ctx.strokeStyle = Qt.alpha(root.stroke, 0.12);
            ctx.lineWidth = 1;
            for (let i = 1; i < 6; i++) {
                const y = height * i / 6;
                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(width, y);
                ctx.stroke();
            }
        }

        const n = root.values.length;
        if (n < 2) return;

        const step = width / (n - 1);
        const yFor = v => height - Math.max(0, Math.min(1, v / root.peak)) * height;

        const gradient = ctx.createLinearGradient(0, 0, 0, height);
        gradient.addColorStop(0, Qt.alpha(root.stroke, 0.42));
        gradient.addColorStop(1, Qt.alpha(root.stroke, 0.02));

        if (root.barMode) {
            const cellWidth = width / n;
            const gap = Math.min(1.25, cellWidth * 0.24);
            ctx.fillStyle = gradient;
            for (let i = 0; i < n; i++) {
                const value = Math.max(0, Math.min(1, root.values[i] / root.peak));
                const barHeight = Math.max(1.25, value * height);
                ctx.fillStyle = root.barColors.length > i ? root.barColors[i] : gradient;
                ctx.fillRect(i * cellWidth + gap / 2, height - barHeight,
                    Math.max(0.5, cellWidth - gap), barHeight);
            }
            return;
        }

        ctx.beginPath();
        ctx.moveTo(0, height);
        for (let i = 0; i < n; i++) ctx.lineTo(i * step, yFor(root.values[i]));
        ctx.lineTo(width, height);
        ctx.closePath();
        ctx.fillStyle = gradient;
        ctx.fill();

        ctx.beginPath();
        for (let i = 0; i < n; i++) {
            const x = i * step;
            const y = yFor(root.values[i]);
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        }
        ctx.strokeStyle = root.stroke;
        ctx.lineWidth = root.lineWidth;
        ctx.stroke();
    }
}
