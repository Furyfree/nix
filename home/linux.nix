# Home Manager settings for the NixOS desktop: Hyprland, Noctalia, GTK and Qt,
# launcher entries and Linux-only tools. Builds on common.nix.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  link =
    path:
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/${path}";
  # A copy of a package's launcher entry, hidden from app menus but still
  # usable for file associations.
  hidden =
    package: name:
    pkgs.runCommand "hidden-${name}" { } ''
      sed '/^\[Desktop Entry\]/a NoDisplay=true' ${package}/share/applications/${name} > $out
    '';
in
{
  imports = [ ./common.nix ];

  xdg = {
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
      // lib.genAttrs [ "chatgpt" "fotmob" "google-maps" ] (name: {
        target = "icons/hicolor/512x512/apps/webapp-${name}.png";
        source = ../configs/icons/webapp-${name}.png;
      });
    desktopEntries = {
      chatgpt = {
        name = "ChatGPT";
        exec = "launch focus-webapp https://chatgpt.com/";
        icon = "webapp-chatgpt";
      };
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
          "zsh/conf.d/noctalia.zsh"
          "noctalia/config.toml"
          "noctalia/vscodium.toml"
          "noctalia/templates/vscodium-output-path.sh"
          "noctalia/assets/profile-picture.jpg"
          "noctalia/assets/profile-picture-circle.svg"
          "zathura/zathurarc"
          "udiskie/config.yml"
          "mise/conf.d/linux-tools.toml"
          # Kept in GLib's own format, without comments: apps that set themselves
          # as default rewrite the whole file that way.
          "mimeapps.list"
          "voxtype/config.toml"
          "MangoHud/MangoHud.conf"
        ]
        (name: {
          source = link name;
        })
      // {
        "gtk-3.0/settings.ini".source = link "gtk/gtk-3.0/settings.ini";
        "gtk-4.0/settings.ini".source = link "gtk/gtk-4.0/settings.ini";
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
      // lib.mapAttrs (_: name: { source = link "vscodium/${name}"; }) {
        "VSCodium/product.json" = "product.json";
        "VSCodium/User/settings.json" = "settings.json";
        "VSCodium/User/keybindings.json" = "keybindings.json";
      };
  };

  home.file = {
    # Steam's own link, made before Noctalia's Steam template can create a real
    # folder here that stops Steam's first-run setup.
    ".steam/steam".source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.dataHome}/Steam";
    ".local/bin/launch".source = link "bin/launch";
  };

  home.activation = {
    # As the COPR launcher did: opt out of Toolbox's default autostart before its
    # first launch, then leave the setting to Toolbox.
    jetbrainsToolboxAutostart = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      settings="${config.xdg.dataHome}/JetBrains/Toolbox/.settings.json"
      if [[ ! -e $settings ]]; then
        run install -D -m 0644 /dev/stdin "$settings" <<<'{ "autostart": false }'
      fi
    '';

    # The wallpapers repository lives with the other clones so pull-projects
    # updates it; link it where Noctalia looks once it is cloned. Runs before
    # Home Manager creates the user folders, and replaces only an empty folder.
    wallpapersLink = lib.hm.dag.entryBetween [ "createXdgUserDirectories" ] [ "writeBoundary" ] ''
      clone="${config.home.homeDirectory}/Projects/wallpapers"
      link="${config.home.homeDirectory}/Pictures/Wallpapers"
      if [[ -d $clone && ! -L $link ]]; then
        if [[ -d $link && -z $(ls -A "$link") ]]; then
          run rmdir "$link"
        fi
        if [[ ! -e $link ]]; then
          run mkdir -p "$(dirname "$link")"
          run ln -s "$clone" "$link"
        fi
      fi
    '';
  };

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
      # ProtonPlus keeps Proton builds updated in the background (hourly by default).
      "com/vysp3r/ProtonPlus/State" = {
        background-updates = true;
        check-updates-on-boot = true;
        check-updates-on-launch = true;
      };
    };
}
