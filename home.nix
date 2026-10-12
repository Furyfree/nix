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
        "ghostty/config"
        "ghostty/themes/charcoal-blue"
        "sheldon/plugins.toml"
        "zsh/.zprofile"
        "zsh/.zshrc"
        "zsh/conf.d/aliases.zsh"
        "zsh/conf.d/completion.zsh"
        "zsh/conf.d/env.zsh"
        "zsh/conf.d/functions.zsh"
        "zsh/conf.d/fzf.zsh"
        "zsh/conf.d/history.zsh"
        "zsh/conf.d/keybindings.zsh"
        "zsh/conf.d/mise.zsh"
        "zsh/conf.d/noctalia.zsh"
        "zsh/conf.d/options.zsh"
        "zsh/conf.d/plugins.zsh"
        "zsh/conf.d/prompt.zsh"
        "zsh/conf.d/zoxide.zsh"
        "noctalia/config.toml"
        "noctalia/assets/profile-picture.jpg"
        "noctalia/assets/profile-picture-circle.svg"
      ]
      (name: {
        source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/${name}";
      })
    // {
      "starship.toml".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/starship/starship.toml";
      # Reuse the pinned renderer and reload hook, not the config-rewriting apply hook.
      "noctalia/templates/ghostty".source =
        "${config.programs.noctalia.package}/share/noctalia/assets/templates/ghostty";
    };

  home.file.".zshenv".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/zsh/.zshenv";

  dconf.settings."org/gnome/desktop/interface".gtk-enable-primary-paste = true;
}
