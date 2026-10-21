-- Desktop monitors and workspaces; hosts/desktop/home.nix links this file to
-- ~/.config/hypr/host.lua.

-- BenQ XL2720Z is the main display; ZOWIE XL LCD is to its right. Matched by
-- description, so swapping cables keeps the layout. The firmware, Limine and
-- the unlock prompt use the RTX 3080's first DisplayPort, so the BenQ goes there.
local benq = "desc:BNQ BenQ XL2720Z SCE00737SL0"
local zowie = "desc:BNQ ZOWIE XL LCD 95H03263SL0"

hl.monitor({
    output = benq,
    mode = "1920x1080@144",
    position = "0x0",
    scale = 1,
})
hl.monitor({
    output = zowie,
    mode = "1920x1080@144",
    position = "1920x0",
    scale = 1,
})
hl.config({ cursor = { default_monitor = benq } })

return {
    -- Each monitor's ten workspace slots; the IDs match Fedora's.
    workspaces = {
        [benq] = { 1, 2, 3, 4, 5, 11, 12, 13, 14, 15 },
        [zowie] = { 6, 7, 8, 9, 10, 16, 17, 18, 19, 20 },
    },
}
