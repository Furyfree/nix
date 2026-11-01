-- ScrollOverview, built by components/scrolloverview.nix. Hyprland loads
-- registered plugins after parsing and then reloads, so the block below applies
-- on that second pass.
hl.plugin.load("/etc/hypr/plugins/scrolloverview.so")

if hl.plugin.scrolloverview then
    hl.config({
        plugin = {
            scrolloverview = {
                scale = 0.5,
                workspace_gap = 100,
                layout = "vertical",
                wallpaper = 2,
                blur = true,
            },
        },
    })
end

local mainMod = "SUPER"

local function toggle_overview()
    if hl.plugin.scrolloverview then
        hl.plugin.scrolloverview.overview("toggle all")
    else
        hl.exec_cmd("notify-send 'Workspace overview unavailable' 'ScrollOverview did not load; check hyprctl plugin list.'")
    end
end
hl.bind(mainMod .. " + O", toggle_overview, { description = "Toggle workspace overview on all monitors" })
-- NuPhy F3 without Fn is Mission Control.
hl.bind("XF86LaunchA", toggle_overview, { description = "NuPhy F3: toggle workspace overview" })
