# Hyprland's live checkout links and Noctalia's Hyprland settings, loaded by
# components/hyprland.nix. The machine's monitors and keys come from
# configs/hypr/hosts/<hostname>.lua.
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  link =
    path:
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/${path}";
  host = "hypr/hosts/${osConfig.networking.hostName}.lua";
  noctalia = builtins.fromTOML (builtins.readFile ../configs/noctalia/config.toml);
in
{
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
        "hypr/conf.d/autostart.lua"
        "hypr/conf.d/keybinds.lua"
        "uwsm/env-hyprland"
      ]
      (name: {
        source = link name;
      })
    // {
      # Key Promoter snippet, as a live checkout link; hyprland.lua loads it first.
      "hypr/conf.d/key-promoter.lua".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/noctalia-key-promoter/key-promoter/hypr/key-promoter.lua";
      # Noctalia reads this after config.toml. Its list replaces the earlier
      # one, so it is config.toml's without Niri's colour template; a change
      # there reaches Hyprland at the next rebuild.
      "noctalia/hyprland.toml".source = (pkgs.formats.toml { }).generate "noctalia-hyprland.toml" {
        theme.templates.builtin_ids = lib.remove "niri" noctalia.theme.templates.builtin_ids;
      };
    }
    // lib.optionalAttrs (builtins.pathExists ../configs/${host}) {
      "hypr/host.lua".source = link host;
    };
}
