# Home Manager for every Linux machine, NixOS and Ubuntu: the Noctalia
# desktop's settings, GTK and Qt, the removable-drive mounter, VS Code's Linux
# paths and the Linux Mise tools. The compositor's half comes from its own
# module.
{ config, lib, ... }:

let
  inherit (config.lib.workstation) link script;
in
{
  # gh opening the browser in its own systemd unit, and VS Code, which saves
  # its settings itself.
  workstation.settingMerges = ''
    merge ${config.xdg.configHome}/gh/config.yml ${../configs/gh/linux.yml} yaml
    merge ${config.xdg.configHome}/Code/User/settings.json ${../configs/vscode/settings.json} json
  '';

  xdg = {
    desktopEntries = {
      # Replaces the package's entry, which opens in the system's terminal;
      # launch tui opens it in its own Ghostty window, which window rules
      # float and centre, or focuses the one already open.
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
          "noctalia/vscode.toml"
          "noctalia/templates/vscode-output-path.sh"
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
        "Code/User/keybindings.json".source = link "vscode/keybindings.json";
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
      });
  };

  # GNOME's interface settings, where Noctalia takes its app icons and GTK apps
  # their cursor; NixOS and Ubuntu install both themes.
  dconf.settings."org/gnome/desktop/interface" = {
    icon-theme = "Papirus-Dark";
    cursor-theme = "Bibata-Modern-Ice";
    cursor-size = 24;
  };

  home = {
    file = {
      ".local/bin/launch".source = script "launch";
      # What xdg-open opens gets a scope of its own, as from Niri's launcher:
      # Ghostty runs as a service, and stopping it took a browser it had
      # started along.
      ".local/bin/xdg-open" = {
        executable = true;
        text = ''
          #!/bin/sh
          for real in /usr/bin/xdg-open /run/current-system/sw/bin/xdg-open; do
            [ -x "$real" ] && break
          done
          exec systemd-run --user --scope --collect --quiet -- "$real" "$@"
        '';
      };
    };
    # Opt out of Toolbox's default autostart before its first launch, then leave
    # the setting to Toolbox.
    activation.jetbrainsToolboxAutostart = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      settings="${config.xdg.dataHome}/JetBrains/Toolbox/.settings.json"
      if [[ ! -e $settings ]]; then
        run install -D -m 0644 /dev/stdin "$settings" <<<'{ "autostart": false }'
      fi
    '';
  };
}
