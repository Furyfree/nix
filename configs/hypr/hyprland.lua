-- Load the Hyprland configuration modules from conf.d.

-- UWSM prepares the session environment before starting Hyprland.
require("./conf.d/window-actions.lua")
require("./conf.d/input.lua")
require("./conf.d/monitors.lua")
require("./conf.d/layout.lua")
require("./conf.d/workspaces.lua")
require("./conf.d/workspace-layouts.lua")
require("./conf.d/decoration.lua")
require("./conf.d/animations.lua")
require("./conf.d/window-rules.lua")
require("./conf.d/overview.lua")
require("./conf.d/autostart.lua")
require("./conf.d/keybinds.lua")

-- Hide update announcements; configuration errors remain visible.
hl.config({ ecosystem = { no_update_news = true } })

-- Noctalia owns the generated palette. First login works before it exists.
if package.searchpath("noctalia", package.path) then
    require("noctalia").apply_theme()
end
