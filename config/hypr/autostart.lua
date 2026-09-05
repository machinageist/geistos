-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function ()
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hyprsunset")
    -- A supervised user service guarantees one live shell; qs -n rejects duplicates.
    hl.exec_cmd("systemctl --user start quickshell-mgeist.service")
    -- "wl-clipboard" is a package name, not a binary; this is what feeds
    -- the clipboard panel
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("pulseaudio --start")
    hl.exec_cmd("sudo systemctl enable --now NetworkManager")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("ollama serve")
end)
