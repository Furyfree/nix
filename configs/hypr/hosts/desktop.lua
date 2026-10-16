-- Desktop monitors and workspaces; hosts/desktop/home.nix links this file to
-- ~/.config/hypr/host.lua.

-- BenQ XL2720Z is the main display; ZOWIE XL LCD is to its right.
hl.monitor({
    output = "DP-4",
    mode = "1920x1080@144",
    position = "0x0",
    scale = 1,
})
hl.monitor({
    output = "DP-3",
    mode = "1920x1080@144",
    position = "1920x0",
    scale = 1,
})
hl.config({ cursor = { default_monitor = "DP-4" } })

return {
    -- Each monitor's ten workspace slots; the IDs match Fedora's.
    workspaces = {
        ["DP-4"] = { 1, 2, 3, 4, 5, 11, 12, 13, 14, 15 },
        ["DP-3"] = { 6, 7, 8, 9, 10, 16, 17, 18, 19, 20 },
    },
}
