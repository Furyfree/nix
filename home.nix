# Shared Home Manager settings, added one tool at a time.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # A copy of a package's launcher entry, hidden from app menus but still
  # usable for file associations.
  hidden =
    package: name:
    pkgs.runCommand "hidden-${name}" { } ''
      sed '/^\[Desktop Entry\]/a NoDisplay=true' ${package}/share/applications/${name} > $out
    '';
in
{
  xdg = {
    enable = true;
    dataFile =
      lib.mapAttrs'
        (name: package: lib.nameValuePair "applications/${name}" { source = hidden package name; })
        {
          "btop.desktop" = pkgs.btop;
          "nvim.desktop" = pkgs.neovim;
          "yazi.desktop" = pkgs.yazi;
          "mpv.desktop" = pkgs.mpv;
          "qt5ct.desktop" = pkgs.libsForQt5.qt5ct;
          "qt6ct.desktop" = pkgs.qt6Packages.qt6ct;
          "base.desktop" = pkgs.libreoffice;
          "math.desktop" = pkgs.libreoffice;
          "remote-viewer.desktop" = pkgs.virt-viewer;
          "dev.noctalia.Noctalia.desktop" = config.programs.noctalia.package;
          "uuctl.desktop" = pkgs.uwsm;
          "me.kavishdevar.librepods.desktop" = pkgs.librepods;
        }
      // lib.genAttrs [ "fotmob" "google-maps" ] (name: {
        target = "icons/hicolor/512x512/apps/webapp-${name}.png";
        source = ./configs/icons/webapp-${name}.png;
      });
    desktopEntries = {
      fotmob = {
        name = "FotMob";
        exec = "launch focus-webapp https://www.fotmob.com/";
        icon = "webapp-fotmob";
      };
      google-maps = {
        name = "Google Maps";
        exec = "launch focus-webapp https://www.google.com/maps";
        icon = "webapp-google-maps";
      };
    };
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
          "fastfetch/ff.lua"
          "fastfetch/ff.sh"
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
        # The whole folder, so vim.pack writes its lock file into the checkout.
        "nvim".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/nvim";
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
      })
      //
        lib.mapAttrs
          (_: name: {
            source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/vscodium/${name}";
          })
          {
            "VSCodium/product.json" = "product.json";
            "VSCodium/User/settings.json" = "settings.json";
            "VSCodium/User/keybindings.json" = "keybindings.json";
          };
  };

  # Zed rewrites its settings for model choices; merge the repo values into
  # its own file on activation instead of linking it.
  programs.zed-editor = {
    enable = true;
    userSettings = lib.importJSON ./configs/zed/settings.json;
    userKeymaps = lib.importJSON ./configs/zed/keymap.json;
  };

  home.file = {
    ".zshenv".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/zsh/.zshenv";
  }
  // lib.genAttrs [ "launch" "pull-projects" ] (name: {
    target = ".local/bin/${name}";
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/bin/${name}";
  });

  # As the COPR launcher did: opt out of Toolbox's default autostart before its
  # first launch, then leave the setting to Toolbox.
  home.activation.jetbrainsToolboxAutostart = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="${config.xdg.dataHome}/JetBrains/Toolbox/.settings.json"
    if [[ ! -e $settings ]]; then
      run install -D -m 0644 /dev/stdin "$settings" <<<'{ "autostart": false }'
    fi
  '';

  dconf.settings =
    let
      # Show hidden files and folders first; open where the app is working.
      fileChooser = {
        show-hidden = true;
        sort-directories-first = true;
        startup-mode = "cwd";
      };
    in
    {
      "org/gnome/desktop/interface" = {
        gtk-enable-primary-paste = true;
        icon-theme = "Papirus-Dark";
        cursor-theme = "Bibata-Modern-Ice";
        cursor-size = 24;
      };
      "org/gnome/nautilus/preferences".show-hidden-files = true;
      "org/gnome/desktop/privacy".remember-recent-files = false;
      "org/gtk/settings/file-chooser" = fileChooser;
      "org/gtk/gtk4/settings/file-chooser" = fileChooser;
    };
}
