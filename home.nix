# Shared Home Manager settings, added one tool at a time.
{ config, lib, ... }:

{
  xdg.enable = true;
  xdg.configFile =
    lib.genAttrs
      [
        "hypr/hyprland.lua"
        "hypr/conf.d/window-actions.lua"
        "hypr/conf.d/input.lua"
        "hypr/conf.d/monitors.lua"
        "hypr/conf.d/layout.lua"
        "hypr/conf.d/workspaces.lua"
        "hypr/conf.d/workspace-layouts.lua"
        "hypr/conf.d/decoration.lua"
        "hypr/conf.d/animations.lua"
        "hypr/conf.d/window-rules.lua"
        "hypr/conf.d/overview.lua"
        "hypr/conf.d/autostart.lua"
        "hypr/conf.d/keybinds.lua"
        "uwsm/env"
        "uwsm/env-hyprland"
        "noctalia/config.toml"
        "noctalia/assets/profile-picture.jpg"
        "noctalia/assets/profile-picture-circle.svg"
      ]
      (name: {
        source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/${name}";
      });

  dconf.settings."org/gnome/desktop/interface".gtk-enable-primary-paste = true;
}
