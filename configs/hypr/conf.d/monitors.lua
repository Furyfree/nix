-- Unlisted outputs keep their preferred mode and automatic position and scale.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "auto",
})

-- X11 apps get the real pixels instead of being stretched blurry; on a scaled
-- monitor, those that do not scale themselves look smaller. The Windows VM
-- passes the scale to Windows.
hl.config({ xwayland = { force_zero_scaling = true } })
