-- Ten workspace slots are available; only the first five stay when empty.
local monitorWorkspaces = require("./conf.d/workspace-monitors.lua")
if next(monitorWorkspaces) then
    for monitor, workspaces in pairs(monitorWorkspaces) do
        for slot, workspace in ipairs(workspaces) do
            hl.workspace_rule({ workspace = tostring(workspace), default_name = tostring(slot),
                persistent = slot <= 5, monitor = monitor, default = slot == 1 })
        end
    end
else
    for workspace = 1, 10 do
        hl.workspace_rule({
            workspace = tostring(workspace),
            default_name = tostring(workspace),
            persistent = workspace <= 5,
        })
    end
end

local actions
actions = {
    move_window = function(target)
        local window = hl.get_active_window()
        if not window then
            return
        end

        local destination
        if target.workspace then
            destination = hl.get_workspace(target.workspace)
        elseif target.monitor then
            destination = hl.get_active_workspace(target.monitor)
        end
        local workspace = (destination and destination.id) or target.workspace
        local previous_workspace = window.workspace and window.workspace.id
        if not workspace or (window.workspace and window.workspace.id == workspace) then
            return
        end

        local layout = window.layout
        local width
        if not window.floating and window.fullscreen == 0
            and layout and layout.name == "scrolling" and layout.column then
            -- Native moves create a new column at the default width.
            -- Keep the old width on an empty workspace; share occupied ones.
            width = destination and destination.windows > 0 and 0.5 or layout.column.width
        end

        hl.dispatch(hl.dsp.window.move({ workspace = workspace, window = window, follow = true }))

        -- Resize only the moved, focused column after a successful move.
        layout = window.layout
        if width and window.active and window.workspace
            and (window.workspace.id == workspace
                or (not destination and window.workspace.id ~= previous_workspace))
            and layout and layout.name == "scrolling" and layout.column then
            hl.dispatch(hl.dsp.layout("colresize " .. width))
        end
    end,
    step = function(direction, move_window)
        local current = hl.get_active_workspace()
        if not current or current.special then return end

        -- Stop at the first workspace on this monitor instead of wrapping.
        if direction < 0 then
            local has_previous = false
            for _, workspace in ipairs(hl.get_workspaces()) do
                if not workspace.special and workspace.id < current.id
                    and workspace.monitor and current.monitor
                    and workspace.monitor.name == current.monitor.name then
                    has_previous = true
                    break
                end
            end
            if not has_previous then return end
        end

        -- Native r selectors stay on this monitor and include empty slots.
        local target = direction < 0 and "r-1" or "r+1"
        if move_window then
            actions.move_window({ workspace = target })
        else
            hl.dispatch(hl.dsp.focus({ workspace = target }))
        end
    end,
    on_current_monitor = function(slot)
        local monitor = hl.get_active_monitor()
        local workspaces = monitor and monitorWorkspaces[monitor.name]
        return workspaces and workspaces[slot] or slot
    end,
}

return actions
