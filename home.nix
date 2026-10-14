# Shared Home Manager settings, added one tool at a time.
{ config, lib, ... }:

{
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
      extraConfig = {
        SCREENSHOTS = "${config.home.homeDirectory}/Pictures/Screenshots";
        WALLPAPERS = "${config.home.homeDirectory}/Pictures/Wallpapers";
        RECORDINGS = "${config.home.homeDirectory}/Videos/Recordings";
      };
    };
    configFile =
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
          "btop/btop.conf"
          "fastfetch/config.jsonc"
          "zathura/zathurarc"
          "udiskie/config.yml"
          "mise/config.toml"
          "mise/conf.d/linux-tools.toml"
          "mimeapps.list"
        ]
        (name: {
          source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/${name}";
        })
      // {
        "starship.toml".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/starship/starship.toml";
        "gtk-3.0/settings.ini".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/gtk/gtk-3.0/settings.ini";
        "gtk-4.0/settings.ini".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/gtk/gtk-4.0/settings.ini";
        # File manager sidebar; bookmarks need absolute paths.
        "gtk-3.0/bookmarks".text =
          lib.concatMapStrings (path: "file://${config.home.homeDirectory}/${path} ${baseNameOf path}\n")
            [
              "Documents"
              "Downloads"
              "Projects"
              "Pictures"
              "Projects/dtu-bachelor"
              "Projects/nix"
            ];
        # Reuse the pinned renderer and reload hook, not the config-rewriting apply hook.
        "noctalia/templates/ghostty".source =
          "${config.programs.noctalia.package}/share/noctalia/assets/templates/ghostty";
      }
      # qtct needs an absolute palette path; Noctalia's Qt template writes the colors.
      // lib.genAttrs [ "qt5ct" "qt6ct" ] (name: {
        target = "${name}/${name}.conf";
        text = ''
          [Appearance]
          color_scheme_path=${config.xdg.configHome}/${name}/colors/noctalia.conf
          custom_palette=true
          icon_theme=Papirus-Dark
          style=Fusion
        '';
      });
  };

  home.file.".zshenv".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/zsh/.zshenv";

  dconf.settings."org/gnome/desktop/interface" = {
    gtk-enable-primary-paste = true;
    icon-theme = "Papirus-Dark";
    cursor-theme = "Bibata-Modern-Ice";
    cursor-size = 24;
  };
}
