-- Shared window actions, with layout-specific commands guarded at runtime.
local actions = {}
local function tiled_window(name)
    local window = hl.get_active_window()
    if not window or window.floating or window.fullscreen ~= 0 then return end
    local layout = window.layout
    if layout and layout.name == name then return window, layout end
end

function actions.column_width()
    local window, layout = tiled_window("scrolling")
    if window and layout.column then hl.dispatch(hl.dsp.layout("colresize +conf")) end
end

function actions.center_column()
    local window, layout = tiled_window("scrolling")
    if window and layout.column then hl.dispatch(hl.dsp.layout("center")) end
end

function actions.split()
    local window = tiled_window("dwindle")
    if not window then return end
    local count = 0
    for _, other in ipairs(hl.get_windows({ workspace = window.workspace.id, mapped = true })) do
        if not other.floating and not other.hidden then count = count + 1 end
    end
    if count > 1 then hl.dispatch(hl.dsp.layout("togglesplit")) end
end

function actions.maximize()
    local window = hl.get_active_window()
    if not window or window.fullscreen == 2 then return end
    local layout = window.layout
    if not window.floating and layout and layout.name == "scrolling" and layout.column then
        if window.fullscreen ~= 0 then return end
        local width = layout.column.width >= 1.0 and "0.5" or "1.0"
        hl.dispatch(hl.dsp.layout("colresize " .. width))
    else
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
    end
end

-- Floating a tiled window keeps its tiled size, which can fill the screen.
-- Give it the centered-floating size instead.
function actions.toggle_float()
    local window = hl.get_active_window()
    if not window then return end
    hl.dispatch(hl.dsp.window.float({ window = window, action = "toggle" }))
    local monitor = window.monitor or hl.get_active_monitor()
    if not window.floating or not monitor then return end
    hl.dispatch(hl.dsp.window.resize({
        window = window, relative = false,
        x = math.floor(math.min(900, monitor.width / monitor.scale * 0.7)),
        y = math.floor(math.min(700, monitor.height / monitor.scale * 0.8)),
    }))
    hl.dispatch(hl.dsp.window.center({ window = window }))
end

function actions.resize(axis, amount)
    local window = hl.get_active_window()
    if not window or window.fullscreen ~= 0 then return end
    local function resize(delta)
        hl.dispatch(hl.dsp.window.resize({
            window = window, x = axis == "x" and delta or 0,
            y = axis == "y" and delta or 0, relative = true,
        }))
    end
    if window.floating then resize(amount); return end

    -- A tiled split can resize from either edge. Probe its direction so Plus
    -- enlarges the focused window even when it is on the right or bottom.
    local before = window.size[axis]
    for _, probe in ipairs({ 1, -1 }) do
        resize(probe)
        local change = window.size[axis] - before
        if math.abs(change) > 0.1 then
            resize(-probe)
            resize(amount * (change * probe > 0 and 1 or -1))
            return
        end
    end
end

function actions.join(direction)
    local window, layout = tiled_window("scrolling")
    if not window or not layout.column then return end
    local column = layout.column
    local can_join = #column.windows > 1
    if not can_join then
        local adjacent = column.index + (direction == "prev" and -1 or 1)
        for _, other in ipairs(hl.get_windows({ workspace = window.workspace.id, mapped = true })) do
            local other_layout = other.layout
            if not other.floating and other_layout and other_layout.column
                and other_layout.column.index == adjacent then can_join = true; break end
        end
    end
    if can_join then hl.dispatch(hl.dsp.layout("consume_or_expel " .. direction)) end
end

function actions.focus(direction)
    hl.dispatch(hl.dsp.focus({ direction = direction }))
end

function actions.previous_workspace()
    local previous = hl.get_last_workspace(hl.get_active_monitor())
    if previous then hl.dispatch(hl.dsp.focus({ workspace = previous })) end
end

return actions
