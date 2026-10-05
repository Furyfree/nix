-- Local per-workspace layout choices, following Omarchy's toggle behaviour.
local state_home = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
local state_dir = state_home .. "/hypr/workspace-layouts"
local state_file = state_dir .. "/choices.tsv"
local choices = {}

local saved = io.open(state_file, "r")
if saved then
    for line in saved:lines() do
        local id, layout = line:match("^(%-?%d+)\t(%a+)$")
        if id and (layout == "dwindle" or layout == "scrolling") then
            choices[id] = layout
            hl.workspace_rule({ workspace = id, layout = layout })
        end
    end
    saved:close()
end

local function save_choices()
    local quoted_dir = "'" .. state_dir:gsub("'", [['\'']]) .. "'"
    -- Hyprland reaps child processes; validate the file open, not execute's status.
    os.execute("mkdir -p -- " .. quoted_dir)
    local file = assert(io.open(state_file .. ".tmp", "w"))
    local ids = {}
    for id in pairs(choices) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b) return tonumber(a) < tonumber(b) end)
    for _, id in ipairs(ids) do
        assert(file:write(id .. "\t" .. choices[id] .. "\n"))
    end
    assert(file:close())
    assert(os.rename(state_file .. ".tmp", state_file))
end

return {
    toggle = function()
        local workspace = hl.get_active_workspace()
        if not workspace then return end
        local id = tostring(workspace.id)
        local layout = workspace.tiled_layout == "dwindle" and "scrolling" or "dwindle"
        hl.workspace_rule({ workspace = id, layout = layout })
        choices[id] = layout
        save_choices()
        hl.exec_cmd("notify-send -a Hyprland -t 1800 'Workspace " .. id .. "' 'Layout: " .. layout .. "'")
    end,
}
