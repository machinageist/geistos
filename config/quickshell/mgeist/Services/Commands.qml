// Author: Jeff
// Date: 2026-08-23
// Description: Searchable operating-system actions shared by the launcher
pragma Singleton
import Quickshell

Singleton {
    id: root

    readonly property var actions: [
        { name: "Operations overview", subtitle: "System, AI, power and security status", glyph: "\uf0ae", tags: "health monitor dashboard", ipc: ["operations", "tab", "overview"] },
        { name: "AI usage and costs", subtitle: "OpenAI and Anthropic usage", glyph: "\uf0d0", tags: "tokens spending models", ipc: ["operations", "tab", "ai"] },
        { name: "Battery and power", subtitle: "Runtime, charging, health and profiles", glyph: "\uf240", tags: "energy charging profile", ipc: ["operations", "tab", "power"] },
        { name: "Maintenance", subtitle: "Updates, storage, services and backups", glyph: "\uf0ad", tags: "arch packages disk recovery", ipc: ["operations", "tab", "maintenance"] },
        { name: "Security posture", subtitle: "Firewall, VPN, sessions and failed units", glyph: "\uf3ed", tags: "privacy network auth", ipc: ["operations", "tab", "security"] },
        { name: "Quick settings", subtitle: "Wi-Fi, Bluetooth, audio and desktop modes", glyph: "\uf1de", tags: "network sound brightness", ipc: ["quicksettings", "toggle"] },
        { name: "Notifications", subtitle: "Attention center and do-not-disturb", glyph: "\uf0f3", tags: "alerts dnd", ipc: ["notifications", "toggle"] },
        { name: "Clipboard history", subtitle: "Search and restore clipboard entries", glyph: "\uf0ea", tags: "copy paste cliphist", ipc: ["clipboard", "toggle"] },
        { name: "AI assistant", subtitle: "Local model and AI CLI launchers", glyph: "\uf0d0", tags: "ollama claude hermes", ipc: ["ai", "toggle"] },
        { name: "Theme and wallpaper", subtitle: "Appearance, palettes and rotation", glyph: "\uf53f", tags: "dark light background", ipc: ["selector", "toggle"] },
        { name: "Geist applications", subtitle: "Calendar, todo, brief, vault and contacts", glyph: "\uf1b2", tags: "productivity local apps", ipc: ["geist", "page", "calendar"] },
        { name: "Refresh calendar todo projection", subtitle: "Export mg-remindr and validate the mg-calr agenda projection", glyph: "\uf021", tags: "interop agenda sync projection", ipc: ["geist", "syncProjection"] },
        { name: "Weather", subtitle: "Forecast and location settings", glyph: "\uf0c2", tags: "temperature forecast rain", ipc: ["weather", "refresh"] },
        { name: "Capture tools", subtitle: "Screenshot and screen recording", glyph: "\uf030", tags: "grim slurp record", ipc: ["capture", "toggle"] },
        { name: "Focus mode", subtitle: "Toggle quiet focused desktop state", glyph: "\uf140", tags: "pomodoro dnd productivity", ipc: ["desktop", "focus"] },
        { name: "Pomodoro", subtitle: "Start or pause the focus timer", glyph: "\uf2f2", tags: "timer focus", ipc: ["pomodoro", "toggle"] },
        { name: "Session menu", subtitle: "Lock, suspend, reboot or power off", glyph: "\uf011", tags: "logout sleep shutdown", ipc: ["session", "toggle"] },
        { name: "System monitor TUI", subtitle: "Open btop", glyph: "\uf201", tags: "cpu memory process gpu", command: ["ghostty", "-e", "btop"] },
        { name: "System logs", subtitle: "Warnings from the current boot", glyph: "\uf15c", tags: "journal errors debug", command: ["ghostty", "-e", "sh", "-lc", "journalctl -b -p warning; printf '\nPress Enter'; read"] },
        { name: "User service logs", subtitle: "Failed user units and recent errors", glyph: "\uf071", tags: "systemd journal failure", command: ["ghostty", "-e", "sh", "-lc", "systemctl --user --failed; journalctl --user -b -p warning; printf '\nPress Enter'; read"] },
        { name: "Package updates", subtitle: "Preview pending Arch updates", glyph: "\uf0ab", tags: "pacman aur maintenance", command: ["ghostty", "-e", "sh", "-lc", "checkupdates; printf '\nPress Enter'; read"] },
        { name: "Git dashboard", subtitle: "Open lazygit in the home directory", glyph: "\uf1d3", tags: "repository projects", command: ["ghostty", "-e", "sh", "-lc", "cd ~ && lazygit"] },
        { name: "Keybindings", subtitle: "Search the keyboard reference", glyph: "\uf11c", tags: "shortcuts help", ipc: ["keybindings", "toggle"] },
        { name: "Refresh desktop telemetry", subtitle: "Recheck costs, updates and security state", glyph: "\uf021", tags: "reload probe", ipc: ["operations", "refresh"] }
    ]

    function run(action) {
        if (!action) return;
        if (action.ipc) {
            Quickshell.execDetached(["qs", "-c", "mgeist", "ipc", "call", ...action.ipc]);
        } else if (action.command) {
            Quickshell.execDetached(action.command);
        }
    }
}
