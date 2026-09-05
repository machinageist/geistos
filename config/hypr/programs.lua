-- Shared program names used by autostart and keybindings.

local M = {
    terminal    = "ghostty",
    fileManager = "yazi",
    -- Quickshell launcher, toggled over IPC so it opens without a spawn
    menu        = "qs -c mgeist ipc call launcher toggle",
    browser     = "firefox",
    video       = "vlc",
    mainMod     = "SUPER",
}

return M
