# Home Manager settings for the Linux desktop on NixOS and Ubuntu: Noctalia,
# GTK and Qt, launcher entries and the Linux merges. Builds on common.nix;
# nixos.nix and ubuntu.nix add each system's own, and the compositor's links
# come from niri.nix or hyprland.nix.
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
  session = import ../components/session-variables.nix;
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

  options.workstation = {
    host = lib.mkOption {
      type = lib.types.str;
      description = "Picks configs/niri/hosts/<host>.kdl and configs/hypr/hosts/<host>.lua: the hostname on NixOS, local/user.nix on Ubuntu.";
    };
    hiddenEntries = lib.mkOption {
      type = lib.types.attrsOf lib.types.package;
      default = { };
      description = "Launcher entries to hide, by file name, with the Nix package that has them.";
    };
  };

  config = {
    workstation.hiddenEntries = {
      "nvim.desktop" = pkgs.neovim;
      "yazi.desktop" = pkgs.yazi;
    };

    xdg = {
      dataFile =
        lib.mapAttrs' (
          name: package: lib.nameValuePair "applications/${name}" { source = hidden package name; }
        ) config.workstation.hiddenEntries
        // lib.genAttrs [ "chatgpt" "google-maps" ] (name: {
          target = "icons/hicolor/512x512/apps/webapp-${name}.png";
          source = ../configs/icons/webapp-${name}.png;
        });
      desktopEntries = {
        chatgpt = {
          name = "ChatGPT";
          exec = "launch focus-webapp https://chatgpt.com/";
          icon = "webapp-chatgpt";
        };
        google-maps = {
          name = "Google Maps";
          exec = "launch focus-webapp https://www.google.com/maps";
          icon = "webapp-google-maps";
        };
        # Replaces the package's entry; window rules float and centre it.
        btop = {
          name = "btop";
          exec = "launch tui btop";
          icon = "com.github.stsdc.monitor";
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
            "zsh/conf.d/noctalia.zsh"
            "noctalia/config.toml"
            "noctalia/vscodium.toml"
            "noctalia/templates/vscodium-output-path.sh"
            "noctalia/templates/strata.toml"
            "noctalia/assets/profile-picture.jpg"
            "noctalia/assets/profile-picture-circle.svg"
            "udiskie/config.yml"
            "mise/conf.d/agents.toml"
            "mise/conf.d/linux-tools.toml"
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

    home.file.".local/bin/launch".source = link "bin/launch";

    # Noctalia's AI usage widget, and gh opening the browser in its own systemd
    # unit.
    workstation.settingMerges = ''
      merge ${config.xdg.configHome}/ai-usagebar/config.toml ${../configs/ai-usagebar/config.toml} toml
      merge ${config.xdg.configHome}/gh/config.yml ${../configs/gh/linux.yml} yaml
    '';

    home.activation = {
      # Opt out of Toolbox's default autostart before its first launch, then leave
      # the setting to Toolbox.
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
          cursor-theme = session.XCURSOR_THEME;
          cursor-size = lib.toInt session.XCURSOR_SIZE;
        };
        "org/gnome/desktop/privacy".remember-recent-files = false;
        "org/gtk/settings/file-chooser" = fileChooser;
        "org/gtk/gtk4/settings/file-chooser" = fileChooser;
      };
  };
}
