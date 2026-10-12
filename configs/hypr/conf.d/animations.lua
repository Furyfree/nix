-- Quick window transitions and vertical workspace movement.
hl.config({ animations = { enabled = true } })

-- Spread motion across the transition instead of jumping at the start.
-- Speed is in 100 ms units.
hl.curve("easeOut", { type = "bezier", points = { { 0.215, 0.61 }, { 0.355, 1 } } })
hl.curve("easeIn", { type = "bezier", points = { { 0.4, 0 }, { 1, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
-- Firm column settling and gentle workspace movement.
-- Hyprland 0.56 uses dampening as the damping coefficient.
hl.curve("gentleMove", { type = "spring", mass = 1, stiffness = 800, dampening = 56.56854249 })
hl.curve("gentleWorkspace", { type = "spring", mass = 1, stiffness = 523, dampening = 39 })
hl.animation({
    leaf = "global",
    enabled = true,
    speed = 2.0,
    bezier = "easeOut",
})

-- Open from 95% size in 180 ms; close with a small shrink in 140 ms.
hl.animation({
    leaf = "windowsIn",
    enabled = true,
    speed = 1.8,
    bezier = "easeOut",
    style = "popin 95%",
})
hl.animation({
    leaf = "windowsOut",
    enabled = true,
    speed = 1.4,
    bezier = "easeIn",
    style = "popin 95%",
})
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.8, bezier = "easeOut" })
hl.animation({
    leaf = "fadeOut",
    enabled = true,
    speed = 1.4,
    bezier = "easeIn",
})

-- Keep moves, swaps, and resizing smooth, with a short focus-color transition.
hl.animation({
    leaf = "windowsMove",
    enabled = true,
    speed = 2.0,
    spring = "gentleMove",
})
hl.animation({ leaf = "border", enabled = true, speed = 1, bezier = "linear" })

-- Workspaces remain stacked vertically, with gentle spring settling.
hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 2.4,
    spring = "gentleWorkspace",
    style = "slidevert",
})
