-- ScrollOverview, built by components/hyprland-noctalia.nix. Hyprland loads
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
