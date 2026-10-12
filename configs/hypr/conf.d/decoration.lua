-- Gaps, borders, rounding, opacity, blur, and shadows.
hl.config({
    -- Equal gaps keep off-screen scrolling columns outside the monitor edge.
    general = { gaps_in = 3, gaps_out = 3, border_size = 2 },
    decoration = {
        -- Subtle whole-window fade; native translucent apps override this below.
        rounding = 12,
        rounding_power = 2,
        active_opacity = 0.97,
        inactive_opacity = 0.95,
        fullscreen_opacity = 1,
        dim_inactive = false,

        -- Shared blur for windows and shell layers; keep its strength stable on focus.
        blur = { enabled = true, size = 3, passes = 2, ignore_opacity = true, xray = false },

        -- Small, soft shadows give overlapping windows some separation.
        shadow = {
            enabled = true,
            range = 10,
            render_power = 3,
            color = 0x40000000,
        },
    },
})
