// Author: Jeff
// Date: 2026-08-21
// Description: Shell entrypoint — bars per screen, plus the resident panels
// Notes: Run with `qs -c mgeist`. Quickshell hot-reloads on save.
//        Panels stay loaded and are toggled over IPC, so they open instantly:
//          qs -c mgeist ipc call launcher toggle
//        `qs -c mgeist ipc show` lists every target and function.

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "Bar"
import "Launcher"
import "Panels"
import "Services"
import "Theme"

ShellRoot {
    id: root
    property string lastThemeSyncKey: ""
    property int lastBrightness: -1
    property real lastVolume: -1

    // Export the resolved palette so shells and terminal emulators use the
    // exact colors currently rendered by Quickshell, including "auto".
    function syncThemeClients() {
        const values = [Theme.name, Theme.base, Theme.surface, Theme.fg,
            Theme.muted, Theme.faint, Theme.borderColor, Theme.accent,
            Theme.red, Theme.orange, Theme.yellow, Theme.green, Theme.cyan,
            Theme.blue, Theme.purple, Theme.pink, Theme.isDark];
        const key = values.join("|");
        if (key === root.lastThemeSyncKey) return;
        root.lastThemeSyncKey = key;
        Quickshell.execDetached([
            `${Quickshell.env("HOME")}/.local/bin/quickshell-theme-sync`,
            ...values.map(v => v.toString())
        ]);
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: root.syncThemeClients()
    }

    // Theme cannot import Services/Palette itself; see the note in Theme.qml
    Component.onCompleted: {
        Theme.autoPalette = Palette;
        root.syncThemeClients();
        // A QML singleton is constructed on first use. GeistAlerts owns the timer
        // that emits due reminders and events, and was referenced only inside an
        // IPC function body, so it was never constructed and never fired. Touch it
        // here so its timer starts with the shell.
        GeistAlerts.refresh();
    }

    // Bar declares `required property ShellScreen modelData`, which Variants
    // injects per screen, so the delegate needs no body.
    Variants {
        model: Quickshell.screens

        Bar {
            onLauncherRequested: launcher.toggle()
            onNotificationsRequested: notifications.toggle()
            onQuickSettingsRequested: quickSettings.toggle()
            onSelectorRequested: selector.toggle()
            onAiRequested: ai.toggle()
            onGeistRequested: page => geist.showPage(page)
            onRemindersRequested: reminders.toggle()
            onCalendarCardRequested: calendarCard.toggle()
        }
    }

    Launcher {
        id: launcher
        onKeybindingsRequested: keybindings.show()
    }

    // Popups render per screen, like the bar
    Variants {
        model: Quickshell.screens

        NotificationPopups {}
        OsdPopup {}
    }

    ThemeSelector {
        id: selector
    }

    QuickSettings {
        id: quickSettings
    }

    NotificationCenter {
        id: notifications
    }

    ClipboardMenu {
        id: clipboard
    }

    SessionMenu {
        id: session
    }

    CapturePanel {
        id: capture
    }

    RecoveryPanel {
        id: recovery
    }

    OperationsPanel {
        id: operations
    }

    RemindersPanel {
        id: reminders
    }

    CalendarPanel {
        id: calendarCard
    }

    GeistPanel {
        id: geist
    }

    AiPanel {
        id: ai
    }

    KeybindingsPanel {
        id: keybindings
    }

    // Rotation cannot reach Theme from inside Services, so the pairing is
    // re-applied here whenever it advances
    Connections {
        target: Rotation

        function onRotated() {
            if (Rotation.pairTheme) Theme.setTheme("auto");
            Osd.show("\uf03e", "Wallpaper changed", Wallpaper.currentName, -1, "purple");
        }
    }

    Connections {
        target: DesktopState
        function onAppearanceRequested(mode) {
            if (mode === "auto") Theme.setTheme("auto");
            else if ((mode === "dark") !== Theme.isDark) Theme.toggleMode();
        }
    }

    Connections {
        target: Backlight
        function onPercentChanged() {
            if (root.lastBrightness >= 0 && root.lastBrightness !== Backlight.percent)
                Osd.show("\udb80\udcde", "Brightness", `${Backlight.percent}%`, Backlight.percent / 100, "yellow");
            root.lastBrightness = Backlight.percent;
        }
    }

    // IPC function names must avoid `qs ipc` subcommands — show, call, wait,
    // listen and prop are parsed as subcommands and never reach the handler.
    IpcHandler {
        target: "keybindings"

        function toggle(): void { keybindings.toggle(); }
        function open(): void { keybindings.show(); }
        function close(): void { keybindings.close(); }
        function count(): int { return Keybindings.binds.length; }
        // Diagnostic: confirms the panel's own grouping without opening it
        function groups(): string {
            const c = {};
            for (const b of Keybindings.binds) c[b.group] = (c[b.group] || 0) + 1;
            return Keybindings.groupOrder.filter(g => c[g]).map(g => `${g}\t${c[g]}`).join("\n");
        }
    }

    IpcHandler {
        target: "stats"

        function cpu(): void { SysStats.openCpuCard(); }
        function memory(): void { SysStats.openMemoryCard(); }

        function probe(): string {
            return [`cpu    ${(SysStats.cpuUsage * 100).toFixed(1)}%  cores=${SysStats.coreCount}`,
                    `cores  ${SysStats.coreUsage.map(c => Math.round(c.usage * 100)).join(" ")}`,
                    `mem    ${(SysStats.memUsage * 100).toFixed(1)}%  ${SysStats.memUsedGb.toFixed(1)}/${SysStats.memTotalGb.toFixed(1)}G`,
                    `swap   ${(SysStats.swapUsage * 100).toFixed(1)}%`,
                    `net    rx ${SysStats.rate(SysStats.netRxRate)}  tx ${SysStats.rate(SysStats.netTxRate)}`,
                    `disk   r ${SysStats.rate(SysStats.diskReadRate)}  w ${SysStats.rate(SysStats.diskWriteRate)}`,
                    `temp   ${SysStats.tempC.toFixed(1)}C (${SysStats.tempLabel})`,
                    `load   ${SysStats.load1}`,
                    `hist   cpu=${SysStats.cpuHistory.length} net=${SysStats.netRxHistory.length}`].join("\n");
        }
    }

    IpcHandler {
        target: "audio"

        function probe(): string {
            const d = Pipewire.defaultAudioSink;
            const sinks = [...Pipewire.nodes.values].filter(n => n.isSink && !n.isStream);
            return [`default id=${d ? d.id : "-"} name=${d ? d.name : "-"}`,
                    `spectrum running=${Spectrum.running} cava=${Spectrum.cavaAvailable} source=${Spectrum.monitorSource}`,
                    `levels count=${Spectrum.levels.length} peak=${Math.max(...Spectrum.levels).toFixed(3)}`,
                    ...sinks.map(n => `  sink id=${n.id} name=${n.name}`)].join("\n");
        }
    }

    IpcHandler {
        target: "appearance"

        function open(): void { BlueLight.openAppearanceCard(); }
        function toggleFilter(): void { BlueLight.toggle(); }
        function setTemperature(kelvin: int): void { BlueLight.setTemperature(kelvin); }
        function status(): string {
            return `blueLight active=${BlueLight.active} temperature=${BlueLight.temperature}K auto=${BlueLight.autoShift}`;
        }
    }

    IpcHandler {
        target: "quicksettings"

        function toggle(): void { quickSettings.toggle(); }
        function open(): void { quickSettings.show(); }
        function close(): void { quickSettings.close(); }
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void { notifications.toggle(); }
        function open(): void { notifications.show(); }
        function close(): void { notifications.close(); }
        function dnd(): void { Notifications.toggleDnd(); }
        function clear(): void { Notifications.clearHistory(); }
        function count(): int { return Notifications.history.length; }
    }

    IpcHandler {
        target: "clipboard"

        function toggle(): void { clipboard.toggle(); }
        function open(): void { clipboard.show(); }
        function close(): void { clipboard.close(); }
    }

    IpcHandler {
        target: "session"

        function toggle(): void { session.toggle(); }
        function open(): void { session.show(); }
        function close(): void { session.close(); }
    }

    IpcHandler {
        target: "ai"

        function toggle(): void { ai.toggle(); }
        function open(): void { ai.show(); }
        function close(): void { ai.close(); }
        function ask(text: string): void { ai.show(); Ai.ask(text); }
        function model(): string { return Ai.model; }
        function models(): string {
            // Re-probe so the list recovers if ollama was down at startup
            Ai.refreshModels();
            return Ai.models.map(m => `${m.cloud ? "cloud" : m.sizeGb.toFixed(1) + "G"}\t${m.name}`).join("\n");
        }
        // Ask without opening the panel, for scripting and for checking the
        // Ollama path without taking over the screen
        function query(text: string): void { Ai.ask(text); }
        function status(): string {
            const diag = Ai.stderrText === "" ? "" : `  stderr: ${Ai.stderrText}`;
            return [`busy=${Ai.busy} model=${Ai.model} error=${Ai.error || "-"} `
                    + `chars=${Ai.response.length} chunks=${Ai.chunks}${diag}`,
                    Ai.response.slice(0, 300)].join("\n");
        }
    }

    IpcHandler {
        target: "selector"

        function toggle(): void { selector.toggle(); }
        function open(): void { selector.show(); }
        function close(): void { selector.close(); }
        function tab(name: string): void { selector.tab = name; }
    }

    IpcHandler {
        target: "media"

        function toggle(): void { MediaBridge.toggle(); }
        function next(): void { MediaBridge.next(); }
        function previous(): void { MediaBridge.previous(); }
        function open(): void { MediaBridge.open(); }
        function status(): string {
            return `${MediaBridge.backend || "none"} ${MediaBridge.state || "stopped"} ${MediaBridge.label}`;
        }
    }

    IpcHandler {
        target: "capture"
        function toggle(): void { capture.toggle(); }
        function region(): void { Capture.regionFile(); }
        function screen(): void { Capture.screenFile(); }
        function clipboard(): void { Capture.regionClipboard(); }
        function record(): void { Capture.toggleRecording(); }
    }

    IpcHandler {
        target: "recovery"
        function toggle(): void { recovery.toggle(); }
        function health(): void { Health.refresh(); }
        function status(): string { return `updates=${Health.updates} failed=${Health.failedUnits} disk=${Health.diskPercent}% checked=${Health.lastChecked}`; }
    }

    IpcHandler {
        target: "operations"
        function toggle(): void { operations.toggle(); }
        function open(): void { operations.show(); }
        function close(): void { operations.close(); }
        function tab(name: string): void { operations.showTab(name); }
        function refresh(): void { Telemetry.refresh(); }
        function status(): string {
            return `updated=${Telemetry.updatedAt} disk=${Telemetry.system.diskPercent ?? 0}% `
                + `updates=${Telemetry.system.updates ?? 0} firewall=${Telemetry.system.firewall ?? "unknown"} `
                + `battery=${operations.batteryPercent}% health=${operations.batteryHealthPercent}% `
                + `remaining=${operations.duration(operations.charging ? operations.battery.timeToFull : operations.battery.timeToEmpty)}`;
        }
        function costs(): string {
            return `OpenAI ${Telemetry.money(Telemetry.openAiToday)} • `
                + `Anthropic ${Telemetry.money(Telemetry.anthropicToday)}`;
        }
    }

    IpcHandler {
        target: "desktop"
        function focus(): void { DesktopState.toggleFocus(); }
        function policy(name: string): void { DesktopState.setPolicy(name); }
        function status(): string { return `focus=${DesktopState.focusMode} policy=${DesktopState.appearancePolicy} requested=${DesktopState.requestedMode} quiet=${DesktopState.quietActive}`; }
    }

    IpcHandler {
        target: "osd"
        function push(title: string, detail: string): void { Osd.show("\uf0a1", title, detail, -1, "accent"); }
    }

    IpcHandler {
        target: "rotation"

        function toggle(): void { Rotation.setEnabled(!Rotation.enabled); }
        function next(): void { Rotation.next(); }
        function forward(): void { Rotation.step(1); }
        function back(): void { Rotation.step(-1); }
        function interval(minutes: int): void { Rotation.setInterval(minutes); }
        function status(): string {
            return `${Rotation.enabled ? "on" : "off"} every ${Rotation.intervalMinutes}m pairTheme ${Rotation.pairTheme}`;
        }
    }

    IpcHandler {
        target: "theme"

        function set(name: string): void { Theme.setTheme(name); }
        function next(): void { Theme.cycleTheme(1); }
        function prev(): void { Theme.cycleTheme(-1); }
        function random(): void { Theme.randomTheme(); }
        function current(): string { return Theme.name; }
        function toggle(): void { Theme.toggleMode(); }
        function list(): string { return Theme.catalog.map(c => c.name).join("\n"); }
        // Report the resolved palette, which is the quickest way to tell whether
        // a theme actually took effect
        function colors(): string {
            return [`name   ${Theme.name}`, `base   ${Theme.base}`, `fg     ${Theme.fg}`,
                    `accent ${Theme.accent}`, `yellow ${Theme.yellow}`, `green  ${Theme.green}`,
                    `purple ${Theme.purple}`, `cyan   ${Theme.cyan}`].join("\n");
        }
    }

    IpcHandler {
        target: "palette"

        function probe(): string {
            return [`ready   ${Palette.ready}`, `source  ${Palette.source}`,
                    `swatches ${Palette.swatches.length}`, `median  ${(Palette.medianBrightness * 100).toFixed(1)}%`,
                    `mode    ${Palette.darkMode ? "dark" : "light"}`,
                    `base    ${Palette.base}`, `accent  ${Palette.accent}`, `yellow  ${Palette.yellow}`].join("\n");
        }
    }

    IpcHandler {
        target: "wallpaper"

        function set(path: string): void { Wallpaper.apply(path); }
        function next(): void { Wallpaper.cycle(1); }
        function prev(): void { Wallpaper.cycle(-1); }
        function random(): void { Wallpaper.random(); }
        function current(): string { return Wallpaper.current; }
        function count(): int { return Wallpaper.count; }
        function dir(): string { return Wallpaper.dir; }
    }

    IpcHandler {
        target: "pomodoro"

        function toggle(): void { Pomodoro.toggle(); }
        function reset(): void { Pomodoro.reset(); }
        function skip(): void { Pomodoro.skip(); }
        function clear(): void { Pomodoro.resetAll(); }
        function status(): string {
            return `${Pomodoro.phase} ${Pomodoro.label} ${Pomodoro.running ? "running" : "stopped"} session ${Pomodoro.sessionsCompleted}`;
        }
    }

    IpcHandler {
        target: "stopwatch"

        function toggle(): void { Stopwatch.toggle(); }
        function reset(): void { Stopwatch.reset(); }
        function status(): string {
            return `${Stopwatch.label} ${Stopwatch.running ? "running" : "stopped"}`;
        }
    }

    IpcHandler {
        target: "reminders"

        function toggle(): void { reminders.toggle(); }
        function open(): void { reminders.show(); }
        function close(): void { reminders.close(); }
        function refresh(): void { Reminders.refresh(); }
        function closed(show: bool): void { Reminders.setShowClosed(show); }
        function keep(title: string, due: string): void { Reminders.add(title, due); }
        function done(handle: string): void { Reminders.complete(handle); }
        function trash(handle: string): void { Reminders.trash(handle); }
        function restore(handle: string): void { Reminders.restore(handle); }
        function status(): string {
            if (Reminders.error !== "") return `error=${Reminders.error}`;
            return Reminders.reminders.map(item =>
                `${item.handle} ${item.state} ${item.when || "someday"} ${item.due_label || "-"} ${item.title}`
            ).join("\n") + `\ncounts today=${Reminders.counts.today ?? 0} overdue=${Reminders.counts.overdue ?? 0} open=${Reminders.counts.open ?? 0} closed=${Reminders.counts.closed ?? 0} checked=${Reminders.checkedAt || "-"}`;
        }
    }

    IpcHandler {
        target: "calendar"

        function toggle(): void { calendarCard.toggle(); }
        function open(): void { calendarCard.show(); }
        function close(): void { calendarCard.close(); }
        function refresh(): void { Calendar.refresh(); }
        function move(days: int): void { Calendar.move(days); }
        function today(): void { Calendar.today(); }
        function schedule(title: string, at: string): void { Calendar.add(title, at, 60); }
        function cancel(handle: string): void { Calendar.cancel(handle); }
        function restore(handle: string): void { Calendar.restore(handle); }
        function status(): string {
            if (Calendar.error !== "") return `error=${Calendar.error}`;
            return Calendar.rows.map(item =>
                `${item.handle} ${item.kind} ${item.when} ${item.cancelled ? "cancelled" : "live"} ${item.title}`
            ).join("\n") + `\ndate=${Calendar.date} zone=${Calendar.timezone} events=${Calendar.counts.events ?? 0} todos=${Calendar.counts.todos ?? 0} cancelled=${Calendar.counts.cancelled ?? 0} checked=${Calendar.checkedAt || "-"}`;
        }
    }

    IpcHandler {
        target: "geist"

        function toggle(): void { geist.toggle(); }
        function open(): void { geist.show(); }
        function close(): void { geist.close(); }
        function page(name: string): void { geist.showPage(name); }
        function calendarcard(): void { GeistUi.openCalendarCard(); }
        function syncProjection(): void { GeistUi.syncTodoProjection(); }
        function projectionStatus(): string { return GeistUi.projectionStatus; }
        function refresh(): void { GeistStatus.refresh(); GeistAlerts.refresh(); }
        function status(): string {
            return ["calendar", "todo", "brief", "vault", "contacts"].map(name => {
                const value = GeistStatus.value(name);
                return `${name}=${value.status} count=${value.count ?? 0} stale=${value.stale ?? false} detail=${value.detail ?? "-"}`;
            }).join("\n") + `\nchecked=${GeistStatus.checkedAt || "-"} busy=${GeistStatus.busy} projection=${GeistUi.projectionStatus}`;
        }
    }

    IpcHandler {
        target: "weather"

        function refresh(): void { Weather.refresh(); }
        function open(): void { Weather.openCard(); }
        function settings(): void { Weather.openSettings(); }
        function byip(): void { Weather.setByIp(); }
        function query(value: string): void { Weather.setQuery(value); }
        function coordinates(latitude: string, longitude: string): void { Weather.setCoordinates(latitude, longitude); }
        function status(): string {
            return `${Weather.location} ${Weather.current.tempF || "--"}F ${Weather.current.description || Weather.error || "loading"} mode=${Weather.mode} updated=${Weather.updatedAt || "-"}`;
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void { launcher.toggle(); }
        function open(): void { launcher.show(); }
        function close(): void { launcher.close(); }
        function search(text: string): void { launcher.show(); launcher.query = text; }
        function results(text: string): string {
            launcher.query = text;
            return launcher.results.slice(0, 10).map(entry => `${entry.kind}\t${entry.name}`).join("\n");
        }
    }
}
