-- ScrollOverview is installed and updated separately through HyprPM.
-- Its config keys exist only after the plugin has loaded.
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
