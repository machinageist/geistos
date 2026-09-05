// Author: Jeff
// Date: 2026-08-21
// Description: Interactive audio pill with volume, spectrum and media transport controls
// Notes: PwObjectTracker is required or the node stops emitting property updates

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "root:/Theme"
import "root:/Widgets"
import "root:/Services"

Pill {
    id: root
    accent: sink?.audio?.muted ? Theme.muted : Theme.accentVolume
    hoverTitle: "Audio"
    hoverCardWidth: 390
    hoverDetail: {
        const volume = sink?.audio?.muted ? "Muted" : `${percent}% output volume`;
        return hasMedia ? `${volume}\n${trackLabel}` : `${volume} — live sink spectrum`;
    }
    hoverGraphValues: Spectrum.levels
    hoverGraphStroke: Theme.accentMedia
    hoverGraphMaxValue: 1
    hoverGraphBars: true
    hoverContent: mediaControls
    hoverGraphColors: Spectrum.colors

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property int percent: sink?.audio ? Math.round(sink.audio.volume * 100) : 0
    readonly property MprisPlayer player: {
        const all = Mpris.players.values;
        return all.find(p => p.isPlaying) ?? all[0] ?? null;
    }
    readonly property bool hasCliMedia: MediaBridge.available && MediaBridge.title !== ""
    readonly property bool hasMedia: hasCliMedia || player !== null
    readonly property bool mediaPlaying: hasCliMedia ? MediaBridge.playing : (player?.isPlaying ?? false)
    readonly property string trackLabel: hasCliMedia
        ? (MediaBridge.label || MediaBridge.backend)
        : player
            ? `${player.trackArtist || player.identity} — ${player.trackTitle || "No track"}`
            : "No active player"
    readonly property real mediaElapsed: hasCliMedia ? MediaBridge.elapsed : (player?.position ?? 0)
    readonly property real mediaDuration: hasCliMedia ? MediaBridge.duration : (player?.length ?? 0)
    property int previousPercent: -1

    onPercentChanged: {
        if (previousPercent >= 0 && previousPercent !== percent)
            Osd.show("\uf028", "Volume", `${percent}%`, percent / 100, "cyan");
        previousPercent = percent;
    }

    // Without this the sink's volume and muted properties never update
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    onClicked: root.pinHoverCard()
    onRightClicked: if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted

    Connections {
        target: MediaBridge
        function onAudioCardRequested() { root.pinHoverCard(); }
    }

    onScrolledUp: root.setVolume(root.sink.audio.volume + 0.05)
    onScrolledDown: root.setVolume(root.sink.audio.volume - 0.05)

    // Clamp to Waybar's max-volume of 100
    function setVolume(v) {
        if (!root.sink?.audio) return;
        root.sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function formatTime(seconds) {
        const safe = Math.max(0, Math.floor(Number(seconds) || 0));
        const minutes = Math.floor(safe / 60);
        const remainder = String(safe % 60).padStart(2, "0");
        return `${minutes}:${remainder}`;
    }

    function previousTrack() {
        if (hasCliMedia) MediaBridge.previous();
        else if (player?.canGoPrevious) player.previous();
    }

    function togglePlayback() {
        if (hasCliMedia) MediaBridge.toggle();
        else if (player?.canTogglePlaying) player.togglePlaying();
    }

    function nextTrack() {
        if (hasCliMedia) MediaBridge.next();
        else if (player?.canGoNext) player.next();
    }

    function seekTo(fraction) {
        if (mediaDuration <= 0) return;
        const target = Math.max(0, Math.min(1, fraction)) * mediaDuration;
        if (hasCliMedia) MediaBridge.seek(target);
        else if (player?.canSeek && player.positionSupported) player.position = target;
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.hoverCardOpen && (root.player?.isPlaying ?? false) && !root.hasCliMedia
        onTriggered: if (root.player) root.player.positionChanged()
    }

    Component {
        id: mediaControls

        Column {
            width: parent?.width ?? 0
            spacing: 8
            visible: true
            opacity: root.hasMedia ? 1 : 0.55
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.edge(Theme.accentMedia)
            }
            Row {
                width: parent.width
                spacing: 8

                Text {
                    width: parent.width - elapsedText.width - 8
                    text: root.trackLabel
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideRight
                }

                Text {
                    id: elapsedText
                    text: `${root.formatTime(root.mediaElapsed)} / ${root.formatTime(root.mediaDuration)}`
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
            }

            Rectangle {
                width: parent.width
                height: 8
                radius: 4
                color: Theme.edge(Theme.muted)
                opacity: root.mediaDuration > 0 ? 1 : 0.45
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1,
                        root.mediaDuration > 0 ? root.mediaElapsed / root.mediaDuration : 0))
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accentMedia
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.mediaDuration > 0
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onPressed: event => root.seekTo(event.x / width)
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Rectangle {
                    width: 38; height: 30; radius: Theme.radius
                    color: previousMouse.containsMouse ? Qt.alpha(Theme.accentMedia, 0.18) : "transparent"
                    border.width: 1; border.color: Theme.edge(Theme.accentMedia)
                    Text { anchors.centerIn: parent; text: "\uf048"; color: Theme.accentMedia; font.family: Theme.iconFontFamily }
                    MouseArea { id: previousMouse; anchors.fill: parent; enabled: root.hasMedia; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.previousTrack() }
                }

                Rectangle {
                    width: 46; height: 30; radius: Theme.radius
                    color: playMouse.containsMouse ? Qt.alpha(Theme.accentMedia, 0.24) : Qt.alpha(Theme.accentMedia, 0.10)
                    border.width: 1; border.color: Theme.edge(Theme.accentMedia)
                    Text { anchors.centerIn: parent; text: root.mediaPlaying ? "\uf04c" : "\uf04b"; color: Theme.accentMedia; font.family: Theme.iconFontFamily }
                    MouseArea { id: playMouse; anchors.fill: parent; enabled: root.hasMedia; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.togglePlayback() }
                }

                Rectangle {
                    width: 38; height: 30; radius: Theme.radius
                    color: nextMouse.containsMouse ? Qt.alpha(Theme.accentMedia, 0.18) : "transparent"
                    border.width: 1; border.color: Theme.edge(Theme.accentMedia)
                    Text { anchors.centerIn: parent; text: "\uf051"; color: Theme.accentMedia; font.family: Theme.iconFontFamily }
                    MouseArea { id: nextMouse; anchors.fill: parent; enabled: root.hasMedia; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.nextTrack() }
                }
            }
        }
    }

    BarText {
        color: root.accent
        font.family: Theme.iconFontFamily
        text: {
            if (!root.sink?.audio) return "\uf026";               // nf-fa-volume_off
            if (root.sink.audio.muted) return "\uf026";
            const icon = root.percent > 50 ? "\uf028"             // nf-fa-volume_up
                       : root.percent > 0  ? "\uf027"             // nf-fa-volume_down
                       : "\uf026";
            return `${icon} ${root.percent}%`;
        }
    }
}