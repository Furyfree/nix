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
    # AirPods control, the tailnet and the screen recorder stay on NixOS.
    noctaliaPluginsOff = [
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
    # The Windows VM's system service and polkit rule, as on NixOS; apps.sh
    # installs them.
    dataFile = {
      "windows-vm/${windows-vm.service}.service".text = lib.generators.toINI { } (
        windows-vm.passthru.unit {
          exe = lib.getExe windows-vm;
          docker = "/usr/bin/docker";
        }
      );
      "windows-vm/windows-vm.rules".text = windows-vm.passthru.polkitRule;
    };
    # Noctalia's renderer and reload hook for Ghostty, from Noctalia's .deb.
    configFile."noctalia/templates/ghostty".source =
      config.lib.file.mkOutOfStoreSymlink "/usr/share/noctalia/assets/templates/ghostty";
  };
}
