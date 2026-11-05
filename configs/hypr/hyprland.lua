-- Load the Hyprland configuration modules from conf.d.

-- UWSM prepares the session environment before starting Hyprland.
-- Key Promoter wraps hl.bind and hl.gesture, so it loads before both.
pcall(require, "./conf.d/key-promoter.lua")
require("./conf.d/window-actions.lua")
require("./conf.d/input.lua")
require("./conf.d/monitors.lua")
-- Per-machine monitors and workspaces, linked by hosts/<host>/home.nix.
if package.searchpath("host", package.path) then
    require("host")
end
require("./conf.d/layout.lua")
require("./conf.d/workspaces.lua")
require("./conf.d/workspace-layouts.lua")
require("./conf.d/decoration.lua")
require("./conf.d/animations.lua")
require("./conf.d/window-rules.lua")
-- enableoverview: off with components/scrolloverview.nix in system.nix; the plugin crashes Hyprland.
-- require("./conf.d/overview.lua")
require("./conf.d/autostart.lua")
require("./conf.d/keybinds.lua")

-- Hide update announcements; configuration errors remain visible.
hl.config({ ecosystem = { no_update_news = true } })

-- Noctalia owns the generated palette. First login works before it exists.
if package.searchpath("noctalia", package.path) then
    require("noctalia").apply_theme()
end
