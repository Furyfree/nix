-- Laptop monitors; hosts/laptop/home.nix links this file to
-- ~/.config/hypr/host.lua.

-- The 2880x1800 internal panel uses a 1920x1200 logical workspace.
hl.monitor({
    output = "eDP-1",
    mode = "preferred",
    position = "auto",
    scale = 1.5,
})

-- Keep the laptop awake with the lid closed, for example on a dock.
hl.bind(
    "SUPER + CTRL + L",
    hl.dsp.exec_cmd("noctalia msg plugin 8bury/lid-guard:lid-guard-service all toggle"),
    { description = "Toggle Lid Guard" }
)

return {}
