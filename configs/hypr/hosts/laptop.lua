-- Laptop monitors; hosts/laptop/home.nix links this file to
-- ~/.config/hypr/host.lua.

-- The 2880x1800 internal panel uses a 1920x1200 logical workspace.
hl.monitor({
    output = "eDP-1",
    mode = "preferred",
    position = "auto",
    scale = 1.5,
})

return {}
