-- Desktop monitor; home/hyprland.nix links this file to
-- ~/.config/hypr/host.lua on the host named desktop.

-- The BenQ XL2720Z, matched by description. The firmware, Limine and the
-- unlock prompt use the RTX 3080's first DisplayPort, so it goes there.
hl.monitor({
    output = "desc:BNQ BenQ XL2720Z SCE00737SL0",
    mode = "1920x1080@144",
    position = "0x0",
    scale = 1,
})
