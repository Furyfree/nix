-- Keyboard and mouse bindings for applications, windows, and workspaces.
local mainMod = "SUPER"
-- The root config loads this shared module before the bindings.
local workspaces = assert(package.loaded["./conf.d/workspaces.lua"])
local window_actions = assert(package.loaded["./conf.d/window-actions.lua"])

-- Keep directional focus and swaps on this monitor; move between monitors explicitly.
hl.config({ binds = { window_direction_monitor_fallback = false } })

-- 1. Applications and panels
-- Focus the most recently used app window, even on another workspace.
-- Match exact compositor classes; launcher names and desktop metadata can differ.
local function focus_or_launch(class, command, alternate_class)
    return function()
        local target
        local newest = math.huge
        for _, window in ipairs(hl.get_windows({ mapped = true })) do
            if (window.class == class or window.class == alternate_class) and not window.hidden then
                local rank = window.focus_history_id
                if rank < 0 then rank = math.huge end
                if not target or rank < newest then
                    target = window
                    newest = rank
                end
            end
        end
        if target then
            if not target.active then hl.dispatch(hl.dsp.focus({ window = target })) end
        else
            hl.exec_cmd(command)
        end
    end
end

hl.bind(
    mainMod .. " + SHIFT + B",
    hl.dsp.exec_cmd("uwsm-app -- brave"),
    { description = "Open Brave browser" }
)
hl.bind(
    mainMod .. " + SHIFT + F",
    hl.dsp.exec_cmd("uwsm-app -- nautilus"),
    { description = "Open file manager" }
)
hl.bind(
    mainMod .. " + SHIFT + O",
    focus_or_launch("md.obsidian.Obsidian", "uwsm-app -- obsidian"),
    { description = "Focus or open Obsidian" }
)
-- Native activation targets the main window; Quick Access shares its class.
hl.bind(
    mainMod .. " + SHIFT + P",
    hl.dsp.exec_cmd("uwsm-app -- 1password"),
    { description = "Focus or open 1Password" }
)
hl.bind(
    "CTRL + SHIFT + Space",
    hl.dsp.exec_cmd("uwsm-app -- 1password --quick-access"),
    { description = "Open 1Password Quick Access" }
)
hl.bind(
    mainMod .. " + SHIFT + A",
    -- Native Wayland and explicit XWayland launches report different classes.
    focus_or_launch("chatgpt", "uwsm-app -- chatgpt", "Chatgpt"),
    { description = "Focus or open ChatGPT" }
)
hl.bind(
    mainMod .. " + SHIFT + Z",
    hl.dsp.exec_cmd("uwsm-app -- zed"),
    { description = "Open Zed" }
)
hl.bind(
    mainMod .. " + SHIFT + R",
    focus_or_launch("zeron", "uwsm-app -- zeron"),
    { description = "Focus or open Zeron" }
)
hl.bind(
    mainMod .. " + SHIFT + T",
    focus_or_launch("t3code", [[for app in t3code-nightly t3code; do
        if command -v "$app" >/dev/null 2>&1; then exec uwsm-app -- "$app"; fi
    done
    notify-send "T3 Code" "T3 Code is not installed."]]),
    { description = "Focus or open T3 Code" }
)
hl.bind(
    mainMod .. " + SHIFT + V",
    hl.dsp.exec_cmd("uwsm-app -- codium"),
    { description = "Open VSCodium" }
)
hl.bind(
    mainMod .. " + SHIFT + D",
    focus_or_launch("vesktop", "uwsm-app -- vesktop"),
    { description = "Focus or open Discord in Vesktop" }
)
hl.bind(
    mainMod .. " + SHIFT + G",
    focus_or_launch("signal", "uwsm-app -- signal-desktop"),
    { description = "Focus or open Signal" }
)
hl.bind(
    mainMod .. " + SHIFT + E",
    focus_or_launch("com.fastmail.Fastmail", "uwsm-app -- flatpak run com.fastmail.Fastmail"),
    { description = "Focus or open Fastmail" }
)
hl.bind(
    mainMod .. " + Return",
    hl.dsp.exec_cmd("uwsm-app -- ghostty +new-window"),
    { description = "Open Ghostty terminal" }
)
hl.bind(
    mainMod .. " + W",
    hl.dsp.window.close(),
    { description = "Close focused window" }
)
hl.bind(
    mainMod .. " + Q",
    window_actions.toggle_float,
    { description = "Toggle floating window" }
)
hl.bind(
    mainMod .. " + Space",
    hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"),
    { description = "Open Noctalia launcher" }
)
hl.bind(
    mainMod .. " + V",
    hl.dsp.exec_cmd("noctalia msg panel-toggle clipboard"),
    { description = "Open clipboard history" }
)
local function toggle_overview()
    if hl.plugin.scrolloverview then
        hl.plugin.scrolloverview.overview("toggle all")
    else
        hl.exec_cmd("notify-send 'Workspace overview unavailable' 'Install and enable ScrollOverview with HyprPM, then reload Hyprland.'")
    end
end
hl.bind(mainMod .. " + O", toggle_overview, { description = "Toggle workspace overview on all monitors" })
hl.bind(
    mainMod .. " + SHIFT + N",
    hl.dsp.exec_cmd("noctalia msg panel-toggle control-center notifications"),
    { description = "Open notification centre" }
)
hl.bind(
    mainMod .. " + comma",
    hl.dsp.exec_cmd("noctalia msg settings-toggle"),
    { description = "Toggle Noctalia settings" }
)
hl.bind(
    mainMod .. " + SHIFT + W",
    hl.dsp.exec_cmd("noctalia msg panel-toggle wallpaper"),
    { description = "Open wallpaper browser" }
)
hl.bind(
    mainMod .. " + CTRL + C",
    hl.dsp.exec_cmd("noctalia msg panel-toggle umedbazarov/crashes:panel"),
    { description = "Open crash history and diagnostics" }
)
hl.bind(
    mainMod .. " + Escape",
    hl.dsp.exec_cmd(
        "noctalia msg panel-toggle kenn/keybind-cheatsheet:cheatsheet"
    ),
    { description = "Open keybind cheatsheet" }
)

-- 2. Noctalia tools
for _, binding in ipairs({
    { key = "G", panel = "tphilippot/git_companion:main", description = "Open Git Companion" },
    { key = "D", panel = "8bury/mini-docker:manager", description = "Open Docker manager" },
    { key = "P", panel = "rxtsel/portctl:panel", description = "Open port manager" },
    { key = "M", panel = "profidev/hypr-screen-mirror:panel", description = "Open screen mirroring" },
    { key = "N", panel = "noctalia/notes:panel", description = "Open notes" },
    { key = "S", panel = "launcher '/ssh '", description = "Open SSH launcher" },
}) do
    hl.bind(
        mainMod .. " + CTRL + " .. binding.key,
        hl.dsp.exec_cmd("noctalia msg panel-toggle " .. binding.panel),
        { description = binding.description }
    )
end

-- 3. Layout, column size and fullscreen
hl.bind(
    mainMod .. " + ALT + L",
    assert(package.loaded["./conf.d/workspace-layouts.lua"]).toggle,
    { description = "Toggle workspace layout: Dwindle / Scrolling" }
)
hl.bind(mainMod .. " + R", window_actions.column_width,
    { description = "Scrolling: cycle column width" })
hl.bind(mainMod .. " + C", window_actions.center_column,
    { description = "Scrolling: center column" })
hl.bind(mainMod .. " + J", window_actions.split,
    { description = "Dwindle: toggle split orientation" })
hl.bind(mainMod .. " + F", window_actions.maximize,
    { description = "Scrolling: half/full width; Dwindle: maximize/restore" })
hl.bind(mainMod .. " + SHIFT + Return",
    hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }),
    { description = "Toggle fullscreen" })

-- Danish Minus/Plus keys; Shift adjusts height. Hold to repeat.
for _, binding in ipairs({
    { key = "minus", amount = -50, width = "Narrow window", height = "Shorten window" },
    { key = "plus", amount = 50, width = "Widen window", height = "Taller window" },
}) do
    hl.bind(mainMod .. " + " .. binding.key,
        function() window_actions.resize("x", binding.amount) end,
        { description = binding.width, repeating = true })
    hl.bind(mainMod .. " + SHIFT + " .. binding.key,
        function() window_actions.resize("y", binding.amount) end,
        { description = binding.height, repeating = true })
end
hl.bind(mainMod .. " + ALT + left", function() window_actions.join("prev") end,
    { description = "Scrolling: join/separate window toward left" })
hl.bind(mainMod .. " + ALT + right", function() window_actions.join("next") end,
    { description = "Scrolling: join/separate window toward right" })

-- 4. Session and screenshots
hl.bind(
    mainMod .. " + L",
    hl.dsp.exec_cmd("noctalia msg session lock"),
    { description = "Lock session" }
)
hl.bind(
    mainMod .. " + SHIFT + L",
    hl.dsp.exec_cmd("noctalia msg panel-toggle session"),
    { description = "Open Noctalia session menu" }
)
-- Open the visual window picker; Alt+Tab recalls a workspace.
-- Noctalia handles Tab/Shift+Tab navigation while its picker is open.
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd("noctalia msg window-switcher"),
    { description = "Open Noctalia window picker" })
hl.bind("ALT + Tab", window_actions.previous_workspace,
    { description = "Return to last workspace on this monitor" })
hl.bind(
    mainMod .. " + SHIFT + S",
    hl.dsp.exec_cmd("noctalia msg screenshot-region"),
    { description = "Capture screen region" }
)
hl.bind(
    "Print",
    hl.dsp.exec_cmd("noctalia msg screenshot-region"),
    { description = "Capture screen region" }
)
hl.bind(
    "SHIFT + Print",
    hl.dsp.exec_cmd("noctalia msg screenshot-fullscreen"),
    { description = "Capture current monitor" }
)

-- 5. Sound and brightness
for _, binding in ipairs({
    { key = "XF86AudioRaiseVolume", action = "volume-up", description = "Increase volume" },
    { key = "XF86AudioLowerVolume", action = "volume-down", description = "Decrease volume" },
    { key = "XF86MonBrightnessUp", action = "brightness-up", description = "Increase brightness" },
    { key = "XF86MonBrightnessDown", action = "brightness-down", description = "Decrease brightness" },
}) do
    hl.bind(
        binding.key,
        hl.dsp.exec_cmd("noctalia msg " .. binding.action),
        { description = binding.description, locked = true, repeating = true }
    )
end
hl.bind(
    "XF86AudioMute",
    hl.dsp.exec_cmd("noctalia msg volume-mute"),
    { description = "Toggle speaker mute", locked = true }
)
hl.bind(
    "XF86AudioMicMute",
    hl.dsp.exec_cmd("noctalia msg mic-mute"),
    { description = "Toggle microphone mute", locked = true }
)
for _, binding in ipairs({
    { key = "XF86AudioPrev", action = "previous", description = "Previous track" },
    { key = "XF86AudioPlay", action = "toggle", description = "Play/pause" },
    { key = "XF86AudioNext", action = "next", description = "Next track" },
}) do
    hl.bind(
        binding.key,
        hl.dsp.exec_cmd("noctalia msg media " .. binding.action),
        { description = binding.description, locked = true }
    )
end

-- NuPhy top row without Fn: F3 is Mission Control, F5 dictation, F6 moon.
hl.bind("XF86LaunchA", toggle_overview, { description = "NuPhy F3: toggle workspace overview" })
hl.bind(
    "XF86VoiceCommand",
    hl.dsp.exec_cmd("noctalia msg mic-mute"),
    { description = "NuPhy F5: toggle microphone mute", locked = true }
)
hl.bind(
    "XF86DoNotDisturb",
    hl.dsp.exec_cmd("noctalia msg notification-dnd-toggle"),
    { description = "NuPhy F6: toggle Do Not Disturb", locked = true }
)
-- Dictation: the Voxtype daemon only listens for its native recording
-- commands, so the compositor owns the shortcut. Toggle avoids the
-- press/release race of push-to-talk; cancel discards a wrong take before
-- it is typed into the focused window.
hl.bind(
    mainMod .. " + D",
    hl.dsp.exec_cmd("voxtype record toggle"),
    { description = "Dictation: start or stop recording" }
)
hl.bind(
    mainMod .. " + SHIFT + Escape",
    hl.dsp.exec_cmd("voxtype record cancel"),
    { description = "Dictation: cancel recording" }
)

-- 6. Window and monitor navigation
-- Super+arrows focuses windows; Ctrl focuses monitors and moves the pointer.
-- Shift swaps windows; Shift+Ctrl moves windows between monitors.
for _, direction in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(
        mainMod .. " + " .. direction,
        hl.dsp.focus({ direction = direction }),
        { description = "Focus window " .. direction }
    )
    hl.bind(
        mainMod .. " + CTRL + " .. direction,
        hl.dsp.focus({ monitor = direction:sub(1, 1) }),
        { description = "Focus monitor and pointer " .. direction }
    )
    hl.bind(
        mainMod .. " + SHIFT + " .. direction,
        hl.dsp.window.swap({ direction = direction }),
        { description = "Swap window on this monitor " .. direction }
    )
    hl.bind(
        mainMod .. " + SHIFT + CTRL + " .. direction,
        function()
            workspaces.move_window({ monitor = direction:sub(1, 1) })
        end,
        { description = "Move window to monitor " .. direction }
    )
end

-- 7. Workspaces
-- Alt+Up/Down steps through workspaces; Shift carries the focused window.
for _, direction in ipairs({ { key = "up", step = -1 }, { key = "down", step = 1 } }) do
    hl.bind(
        mainMod .. " + ALT + " .. direction.key,
        function() workspaces.step(direction.step, false) end,
        { description = "Switch workspace " .. direction.key .. " on this monitor" }
    )
    hl.bind(
        mainMod .. " + SHIFT + ALT + " .. direction.key,
        function() workspaces.step(direction.step, true) end,
        { description = "Move window to workspace " .. direction.key .. " and follow" }
    )
end

-- All ten slots are addressable, including workspaces not created yet.
for i = 1, 10 do
    local key = i % 10
    hl.bind(
        mainMod .. " + " .. key,
        function()
            hl.dispatch(hl.dsp.focus({ workspace = workspaces.on_current_monitor(i) }))
        end,
        { description = "Switch to local workspace " .. i }
    )
    hl.bind(
        mainMod .. " + SHIFT + " .. key,
        function()
            workspaces.move_window({ workspace = workspaces.on_current_monitor(i) })
        end,
        { description = "Move window to local workspace " .. i }
    )
end

-- 8. Mouse controls
-- Hold Super and drag with the left/right mouse button to move/resize.
hl.bind(
    mainMod .. " + mouse:272",
    hl.dsp.window.drag(),
    { mouse = true, description = "Move window with mouse" }
)
hl.bind(
    mainMod .. " + mouse:273",
    hl.dsp.window.resize(),
    { mouse = true, description = "Resize window with mouse" }
)

-- Super+wheel steps workspaces; Shift carries the window; Ctrl focuses monitors.
for _, wheel in ipairs({
    { key = "mouse_up", name = "up", step = -1, monitor = "left" },
    { key = "mouse_down", name = "down", step = 1, monitor = "right" },
}) do
    hl.bind(
        mainMod .. " + " .. wheel.key,
        function() workspaces.step(wheel.step, false) end,
        { description = "Switch workspace " .. wheel.name .. " on this monitor" }
    )
    hl.bind(
        mainMod .. " + SHIFT + " .. wheel.key,
        function() workspaces.step(wheel.step, true) end,
        { description = "Move window to workspace " .. wheel.name .. " and follow" }
    )
    hl.bind(
        mainMod .. " + CTRL + " .. wheel.key,
        hl.dsp.focus({ monitor = wheel.monitor:sub(1, 1) }),
        { description = "Focus monitor " .. wheel.monitor }
    )
end
