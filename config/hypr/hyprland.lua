-- Hyprland Lua config entrypoint.
-- Section modules live next to this file and are loaded in order.

local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local hypr_config = config_home .. "/hypr"

-- Make `require("somefile")` resolve modules from ~/.config/hypr even when
-- Hyprland is launched from a different working directory.
package.path = hypr_config .. "/?.lua;" .. package.path

require("programs")
require("monitors")
require("autostart")
require("environment")
require("permissions")
require("look_and_feel")
require("animations")
require("layout")
require("input")
require("keybindings")
require("window_rules")

misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
}
