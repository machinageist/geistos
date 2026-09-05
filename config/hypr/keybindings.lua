---------------------
---- KEYBINDINGS ----
---------------------

-- Namespaced the way Omarchy 4 namespaces bindings, so its docs and videos
-- describe this machine:
--   SUPER          window management
--   SUPER + SHIFT  launch applications
--   SUPER + CTRL   shell panels and system toggles
--   SUPER + ALT    variants of the bare-SUPER action
--
-- Every bind carries a description. Hyprland exposes it through
-- `hyprctl binds -j`, which is what the shell's keybindings panel reads
-- (SUPER + CTRL + K). A bind with no description does not appear there.

local programs = require("programs")
local mainMod = programs.mainMod

-- Shorthand so the panel bindings below stay readable
local function panel(target, action)
    return hl.dsp.exec_cmd("qs -c mgeist ipc call " .. target .. " " .. (action or "toggle"))
end

---------------------------
---- WINDOW MANAGEMENT ----
---------------------------

hl.bind(mainMod .. " + W", hl.dsp.window.close(),                          { description = "Close window" })
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), { description = "Full screen" })
hl.bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" }),     { description = "Toggle floating" })
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo(),                         { description = "Pseudo window" })
hl.bind(mainMod .. " + ALT + J", hl.dsp.layout("togglesplit"),             { description = "Toggle split direction" })

-- Focus with vim keys. J and K were inverted before this: J moved focus up.
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }),  { description = "Focus window left" })
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }),  { description = "Focus window down" })
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }),    { description = "Focus window up" })
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }), { description = "Focus window right" })

-- Arrows do the same, matching Omarchy's defaults
hl.bind(mainMod .. " + LEFT",  hl.dsp.focus({ direction = "left" }),  { description = "Focus window left" })
hl.bind(mainMod .. " + DOWN",  hl.dsp.focus({ direction = "down" }),  { description = "Focus window down" })
hl.bind(mainMod .. " + UP",    hl.dsp.focus({ direction = "up" }),    { description = "Focus window up" })
hl.bind(mainMod .. " + RIGHT", hl.dsp.focus({ direction = "right" }), { description = "Focus window right" })

hl.bind("ALT + TAB",         hl.dsp.window.cycle_next(),                { description = "Focus next window" })
hl.bind("ALT + SHIFT + TAB", hl.dsp.window.cycle_next({ next = false }), { description = "Focus previous window" })

-- Move and resize with the mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Move window" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window" })

--------------------
---- WORKSPACES ----
--------------------

for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,
        hl.dsp.focus({ workspace = i }),
        { description = "Switch to workspace " .. i })
    hl.bind(mainMod .. " + SHIFT + " .. key,
        hl.dsp.window.move({ workspace = i }),
        { description = "Move window to workspace " .. i })
end

hl.bind(mainMod .. " + TAB",         hl.dsp.focus({ workspace = "e+1" }), { description = "Next workspace" })
hl.bind(mainMod .. " + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }), { description = "Previous workspace" })

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Next workspace" })
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), { description = "Previous workspace" })

-- Scratchpad. The special workspace keeps the name "magic" rather than
-- Omarchy's "scratchpad"; renaming would orphan anything already stashed there.
hl.bind(mainMod .. " + S",       hl.dsp.workspace.toggle_special("magic"),           { description = "Toggle scratchpad" })
hl.bind(mainMod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:magic" }), { description = "Move window to scratchpad" })

----------------------
---- APPLICATIONS ----
----------------------

hl.bind(mainMod .. " + RETURN",    hl.dsp.exec_cmd(programs.terminal),    { description = "Terminal" })
hl.bind(mainMod .. " + SPACE",     hl.dsp.exec_cmd(programs.menu),        { description = "Application launcher" })
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.exec_cmd(programs.fileManager), { description = "File manager" })

----------------
---- PANELS ----
----------------

hl.bind(mainMod .. " + CTRL + W",     panel("quicksettings"),  { description = "Quick settings" })
hl.bind(mainMod .. " + CTRL + V",     panel("clipboard"),      { description = "Clipboard history" })
hl.bind(mainMod .. " + CTRL + N",     panel("notifications"),  { description = "Notifications" })
hl.bind(mainMod .. " + CTRL + T",     panel("monitor"),        { description = "System monitor" })
hl.bind(mainMod .. " + CTRL + A",     panel("ai"),             { description = "AI" })
hl.bind(mainMod .. " + CTRL + K",     panel("keybindings"),    { description = "Keybindings" })
hl.bind(mainMod .. " + CTRL + SPACE", panel("selector"),       { description = "Theme and wallpaper" })
hl.bind(mainMod .. " + CTRL + R",     panel("rotation", "next"), { description = "Next wallpaper and theme" })
hl.bind(mainMod .. " + CTRL + G",     panel("pomodoro"),       { description = "Pomodoro timer" })
hl.bind(mainMod .. " + CTRL + D",     panel("stopwatch"),      { description = "Stopwatch" })
hl.bind(mainMod .. " + ESCAPE",       panel("session"),        { description = "Session menu" })

hl.bind(mainMod .. " + CTRL + L", hl.dsp.exec_cmd("hyprlock"), { description = "Lock screen" })
hl.bind(mainMod .. " + CTRL + B",
    hl.dsp.exec_cmd("systemctl --user restart quickshell-mgeist.service"),
    { description = "Restart shell" })

---------------
---- MEDIA ----
---------------

hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "Volume up" })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true, description = "Volume down" })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true, description = "Mute output" })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true, description = "Mute microphone" })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true, description = "Brightness up" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true, description = "Brightness down" })

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true, description = "Next track" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play/pause" })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play/pause" })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true, description = "Previous track" })

-----------------
---- CAPTURE ----
-----------------

hl.bind("PRINT",
    hl.dsp.exec_cmd([[grim -g "$(slurp)" ~/pictures/screenshots/$(date +%Y%m%d_%H%M%S).png]]),
    { description = "Screenshot region to file" })
hl.bind(mainMod .. " + PRINT",
    hl.dsp.exec_cmd([[grim ~/pictures/screenshots/$(date +%Y%m%d_%H%M%S).png]]),
    { description = "Screenshot screen to file" })
hl.bind(mainMod .. " + SHIFT + S",
    hl.dsp.exec_cmd([[grim -g "$(slurp)" - | wl-copy]]),
    { description = "Screenshot region to clipboard" })
