# Home Manager for the Ubuntu work laptop: the terminal, app configs and Niri
# desktop from home-manager/, with the work SSH keys. apps.sh installs the
# apps. The flake adds the ignored ubuntu/local/user.nix with the account, e.g.:
#   { home.username = "alice"; home.homeDirectory = "/home/alice"; }
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # The shared fastfetch layout with Ubuntu's logo, as darwin/home.nix gives
  # the Mac its own; a switch applies edits.
  fastfetch =
    let
      shared = lib.importJSON ../configs/fastfetch/config.jsonc;
    in
    pkgs.writeText "fastfetch-config.jsonc" (
      builtins.toJSON (
        shared
        // {
          logo = shared.logo // {
            source = "ubuntu";
          };
        }
      )
    );
  # Docker and systemd come from apt, so the script uses theirs.
  windows-vm = import ../bin/windows-vm.nix { inherit pkgs; };
in
{
  imports = [
    ../home-manager/common.nix
    ../home-manager/linux.nix
    ../home-manager/niri.nix
  ];

  # Nix's profile on the session's paths. Ubuntu's own drivers serve the GUI
  # apps, which come from apt and Flatpak.
  targets.genericLinux = {
    enable = true;
    gpu.enable = false;
  };

  home = {
    packages =
      import ../home-manager/cli-tools.nix pkgs
      ++ (with pkgs; [
        # NixOS gets these two from its modules.
        neovim
        nh
        # Ghostty's font
        nerd-fonts.jetbrains-mono
        # Git signs with this name, which 1Password's .deb keeps in /opt.
        (writeShellScriptBin "op-ssh-sign" ''exec /opt/1Password/op-ssh-sign "$@"'')
      ])
      ++ [ windows-vm ];
    stateVersion = "26.11";
  };
  fonts.fontconfig.enable = true;

  workstation = {
    sshProfile = "work";
    # configs/niri/hosts/ubuntu.kdl, a fixed name rather than the laptop's own.
    host = "ubuntu";
    # AI usage, Git Companion (GitHub only; work uses GitLab), Mini Docker,
    # AirPods control, the tailnet and the screen recorder stay on NixOS.
    noctaliaPluginsOff = [
      "felipeartur/ai-usagebar"
      "tphilippot/git_companion"
      "8bury/mini-docker"
      "harveywuk/airpods"
      "rylos/tailnet"
      "noctalia/screen_recorder"
    ];
    # Under Niri nothing names an app for folders, so xdg-open took Yazi, which
    # needs a terminal; GNOME's own default applies only in GNOME.
    settingMerges = ''
      merge ${config.xdg.configHome}/mimeapps.list ${pkgs.writeText "mimeapps.list" ''
        [Default Applications]
        inode/directory=org.gnome.Nautilus.desktop
      ''} ini
    '';
  };

  # Zed installs and updates itself; Home Manager merges its settings.
  programs.zed-editor.package = null;

  xdg = {
    dataFile =
      # Hidden as on NixOS: settings tools, helpers and Noctalia itself, which
      # runs already. Hidden=true deletes an entry for this account.
      lib.genAttrs
        (map (name: "applications/${name}.desktop") [
          "qt5ct"
          "qt6ct"
          "mpv"
          "org.freedesktop.IBus.Setup"
          "gnome-language-selector"
          "dev.noctalia.Noctalia"
          "nvim"
          "yazi"
        ])
        (_: {
          text = "[Desktop Entry]\nHidden=true\n";
        })
      // {
        # The Windows VM's system service and polkit rule, as on NixOS; apps.sh
        # installs them.
        "windows-vm/${windows-vm.service}.service".text = lib.generators.toINI { } (
          windows-vm.passthru.unit {
            exe = lib.getExe windows-vm;
            docker = "/usr/bin/docker";
          }
        );
        "windows-vm/windows-vm.rules".text = windows-vm.passthru.polkitRule;
      };
    configFile = {
      # Ubuntu opens Terminal=true apps in its own terminal; Ghostty has the
      # Noctalia colours that btop, Yazi and Neovim take from it.
      "xdg-terminals.list".text = "com.mitchellh.ghostty.desktop\n";
      "fastfetch/config.jsonc".source = lib.mkForce fastfetch;
      # Noctalia's renderer and reload hook for Ghostty, from Noctalia's .deb.
      "noctalia/templates/ghostty".source =
        config.lib.file.mkOutOfStoreSymlink "/usr/share/noctalia/assets/templates/ghostty";
      # niri.service starts XDG autostart entries here, so 1Password's own Start
      # at login would run a second copy beside autostart.kdl's; GNOME keeps it.
      "systemd/user/app-com.onepassword.OnePassword@autostart.service.d/niri.conf".text = ''
        [Unit]
        ConditionEnvironment=!XDG_CURRENT_DESKTOP=niri
      '';
    };
  };
}
