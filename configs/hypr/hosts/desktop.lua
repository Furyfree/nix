-- Desktop monitors; home/hyprland.nix links this file to
-- ~/.config/hypr/host.lua on the host named desktop.

-- The MSI MPG322UX OLED (32") is the main display; the BenQ XL2720Z (27") is
-- to its right, near its bottom, so the pointer crosses low on the edge too.
-- Matched by description, so swapping cables keeps the layout.
-- The firmware, Limine and the unlock prompt use the RTX 3080's first
-- DisplayPort.
hl.monitor({
    output = "desc:Microstep MPG322UX OLED 0x01010101",
    mode = "3840x2160@240",
    position = "0x0",
    scale = 1.25,
})
hl.monitor({
    output = "desc:BNQ BenQ XL2720Z SCE00737SL0",
    mode = "1920x1080@144",
    position = "3072x540",
    scale = 1,
})
