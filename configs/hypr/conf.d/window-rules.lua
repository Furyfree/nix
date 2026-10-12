-- Window and layer rules for applications and Noctalia surfaces.

-- Assign app tags before the shared rules that use them.
hl.window_rule({
    name = "1password",
    match = { class = "^com\\.onepassword\\.OnePassword$" },
    tag = "+centered-floating",
})
hl.window_rule({
    name = "screen-share-picker",
    match = { class = "^hyprland-share-picker$" },
    tag = "+centered-floating",
})
hl.window_rule({
    name = "terminal-presentation",
    match = { class = "^com\\.mitchellh\\.ghostty\\.presentation$" },
    tag = "+centered-floating",
})
hl.window_rule({
    name = "steam-settings-and-friends",
    -- Steam gives these and its main window the same class and window type.
    -- Keep the app match and narrow it to these two initial titles.
    match = {
        class = "^steam$",
        initial_title = "^(Steam Settings|Friends List)$",
    },
    tag = "+centered-floating",
})
hl.window_rule({
    name = "obsidian-settings",
    -- Settings shares the vault window's class; its title names the vault.
    match = {
        class = "^md\\.obsidian\\.Obsidian$",
        initial_title = "^Settings - .* - Obsidian .*$",
    },
    tag = "+centered-floating",
})
hl.window_rule({
    name = "jetbrains-welcome",
    -- Every JetBrains IDE shares this class prefix and titles its welcome
    -- frame "Welcome to ...". Use a fixed size instead of the shared
    -- centered-floating tag: that tag keeps the app's remembered width, which
    -- the IDEs can grow to the full monitor. Opening a project disposes this
    -- frame and opens the project in a separate window, which stays tiled.
    match = {
        class = "^jetbrains-.*$",
        initial_title = "^Welcome to .*$",
    },
    float = true,
    size = { "min(900,monitor_w*0.7)", "min(700,monitor_h*0.8)" },
    center = true,
})

-- These classes expose background alpha while keeping their content opaque.
-- Verified with hyprctl clients; the presentation profile has its own app ID.
hl.window_rule({
    name = "native-background-transparency",
    match = { class = "^(com\\.mitchellh\\.ghostty(\\.presentation)?|dev\\.noctalia\\.Noctalia)$" },
    tag = "+native-transparency",
})
hl.window_rule({
    name = "preserve-native-transparency",
    match = { tag = "native-transparency" },
    opacity = "1.0 override 0.98 override 1.0 override",
})

hl.window_rule({
    name = "world-of-warcraft",
    -- Proton gives games without an app ID this shared class; retail and
    -- Classic share the title.
    match = {
        class = "^steam_app_default$",
        initial_title = "^World of Warcraft$",
    },
    tag = "+game",
})

-- Assign verified game classes tag = "+game" above this rule to start fullscreen.
hl.window_rule({
    name = "game",
    match = { tag = "game" },
    fullscreen = true,
    opacity = "1.0 override 1.0 override 1.0 override",
    force_rgbx = true,
    no_blur = true,
})

-- Actual fullscreen content stays opaque, including native-alpha terminals.
hl.window_rule({
    name = "fullscreen-opaque",
    match = { fullscreen = true },
    opacity = "1.0 override 1.0 override 1.0 override",
    force_rgbx = true,
    no_blur = true,
})

-- Other apps can opt in with tag = "+centered-floating" above this rule.
hl.window_rule({
    name = "centered-floating",
    match = { tag = "centered-floating" },
    float = true,
    size = { "window_w", "min(700,monitor_h*0.8)" },
    center = true,
})

-- Keep Noctalia settings separate from the scrolling columns.
hl.window_rule({
    name = "noctalia-settings",
    match = { class = "^dev\\.noctalia\\.Noctalia$" },
    float = true,
    size = { 1080, 920 },
    center = true,
})

-- Blur Noctalia's visible surfaces while keeping its own panel animations.
hl.layer_rule({
    name = "noctalia",
    match = {
        namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$",
    },
    no_anim = true,
    blur = true,
    blur_popups = true,
    ignore_alpha = 0.5,
})
