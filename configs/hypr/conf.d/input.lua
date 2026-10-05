-- Keyboard, mouse, touchpad, and gesture settings.

hl.config({
    input = {
        -- Danish layout, Num Lock, and responsive key repeat.
        kb_layout = "dk",
        numlock_by_default = true,
        repeat_rate = 40,
        repeat_delay = 250,

        -- Focus follows the pointer; keep traditional mouse-wheel scrolling.
        follow_mouse = 1,
        sensitivity = 0,
        natural_scroll = false,

        -- Scroll content directly and use finger count for physical clicks.
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            clickfinger_behavior = true,
            disable_while_typing = true,
        },
    },
    -- Let launching an already-running app bring its window forward.
    misc = { focus_on_activate = true },
    cursor = {
        no_warps = false,
        warp_on_change_workspace = 1,
        warp_on_toggle_special = 1,
    },
    -- Persistent workspaces are a starting set, not a limit on swipe navigation.
    gestures = {
        workspace_swipe_create_new = true,
        -- Retained continuous-swipe preferences; callbacks below do not use them.
        scrolling = { move_snap_to_grid = true, move_snap_cursor = false },
    },
})

-- The NuPhy has US keycaps; AltGr+a/o/' types å/ø/æ as Option does on macOS.
for _, name in ipairs({
    "nuphy-nuphy-air75-v3-dongle", "nuphy-nuphy-air75-v3-dongle-1", -- 2.4 GHz dongle
    "nuphy-air75-v3", "nuphy-air75-v3-1", -- USB cable
}) do
    hl.device({ name = name, kb_layout = "us", kb_variant = "mac" })
end

-- New windows already receive keyboard focus; move the pointer there too.
-- Background windows must not take the pointer away from the active window.
hl.on("window.open", function(window)
    if window.active then
        hl.dispatch(hl.dsp.cursor.move({
            x = window.at.x + window.size.x / 2,
            y = window.at.y + window.size.y / 2,
        }))
    end
end)

-- Natural direction: swipe content up to reach the next workspace below.
-- The root config loads workspaces.lua after this file, before any swipe runs.
hl.gesture({ fingers = 3, direction = "up", action = function()
    assert(package.loaded["./conf.d/workspaces.lua"]).step(1, false)
end })
hl.gesture({ fingers = 3, direction = "down", action = function()
    assert(package.loaded["./conf.d/workspaces.lua"]).step(-1, false)
end })

-- Natural direction: swipe content left to focus the window to the right.
local window_actions = assert(package.loaded["./conf.d/window-actions.lua"])
hl.gesture({ fingers = 3, direction = "left", action = function() window_actions.focus("r") end })
hl.gesture({ fingers = 3, direction = "right", action = function() window_actions.focus("l") end })

-- Super carries the focused window in the same directions.
hl.gesture({ fingers = 3, direction = "up", mods = "SUPER", action = function()
    assert(package.loaded["./conf.d/workspaces.lua"]).step(1, true)
end })
hl.gesture({ fingers = 3, direction = "down", mods = "SUPER", action = function()
    assert(package.loaded["./conf.d/workspaces.lua"]).step(-1, true)
end })
hl.gesture({ fingers = 3, direction = "left", mods = "SUPER", action = function()
    hl.dispatch(hl.dsp.window.swap({ direction = "right" }))
end })
hl.gesture({ fingers = 3, direction = "right", mods = "SUPER", action = function()
    hl.dispatch(hl.dsp.window.swap({ direction = "left" }))
end })
