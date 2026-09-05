// Scriptable UI requests shared by Geist bar modules.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    signal calendarCardOpenRequested()
    property bool projectionBusy: false
    property string projectionStatus: "not refreshed"
    function openCalendarCard() { root.calendarCardOpenRequested(); }
    // Record a refresh a bridge has already performed for itself. The reminders
    // bridge syncs the projection as part of every change it makes, so running
    // the same script again here would only pay for it twice.
    function noteProjection(outcome) {
        root.projectionStatus = outcome === "refreshed" ? "agenda projection refreshed"
            : outcome === "unavailable" ? "projection sync unavailable"
            : "projection refresh failed";
        GeistStatus.refresh();
    }

    function syncTodoProjection() {
        if (projectionProcess.running) return;
        root.projectionBusy = true;
        root.projectionStatus = "refreshing…";
        projectionProcess.running = true;
    }

    Process {
        id: projectionProcess
        command: [`${Quickshell.env("HOME")}/dotfiles/scripts/geist-sync-todo-projection`]
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            root.projectionBusy = false;
            root.projectionStatus = exitCode === 0 ? "agenda projection refreshed" : "projection refresh failed";
            GeistStatus.refresh();
        }
    }
}
