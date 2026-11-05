-- Unlisted outputs keep their preferred mode and automatic position and scale.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "auto",
})

-- XWayland apps get the real pixels and scale themselves instead of being
-- stretched blurry; the Windows VM's xfreerdp passes the scale to Windows.
hl.config({ xwayland = { force_zero_scaling = true } })
