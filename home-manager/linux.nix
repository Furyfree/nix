# Home Manager for every Linux machine, NixOS and Ubuntu: the Noctalia
# desktop's settings, GTK and Qt, the removable-drive mounter, VSCodium's Linux
# paths and the Linux Mise tools. The compositor's half comes from its own
# module.
{ config, lib, ... }:

let
  inherit (config.lib.workstation) link script;
in
{
  # gh opening the browser in its own systemd unit, and VSCodium, which saves
  # its settings itself.
  workstation.settingMerges = ''
    merge ${config.xdg.configHome}/gh/config.yml ${../configs/gh/linux.yml} yaml
    merge ${config.xdg.configHome}/VSCodium/User/settings.json ${../configs/vscodium/settings.json} json
  '';

  xdg = {
    # A terminal app from Mise's Linux tools; launch tui opens it in its own
    # Ghostty window, or focuses the one already open.
    desktopEntries = {
      vm-curator = {
        name = "VM Curator";
        exec = "launch tui vm-curator";
        icon = "qemu";
      };
      # Replaces the package's entry, which opens in the system's terminal;
      # window rules float and centre it.
      btop = {
        name = "btop";
        exec = "launch tui btop";
        icon = "btop";
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
        "VSCodium/User/keybindings.json" = "keybindings.json";
      };
  };

  home.file.".local/bin/launch".source = script "launch";
}
