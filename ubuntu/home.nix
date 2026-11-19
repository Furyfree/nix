# Home Manager for the Ubuntu work laptop: the terminal and app configs from
# home-manager/common.nix, with the work SSH keys. apps.sh installs the apps. The
# flake adds the ignored ubuntu/local/user.nix with the account, e.g.:
#   { home.username = "alice"; home.homeDirectory = "/home/alice"; }
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
  # A live link to one of the checkout's own scripts in bin/.
  script =
    name: config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/bin/${name}";
  # Docker and systemd come from apt, so the script uses theirs.
  windows-vm = import ../bin/windows-vm.nix { inherit pkgs; };
in
{
  imports = [ ../home-manager/common.nix ];

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
    file.".local/bin/launch".source = script "launch";
    stateVersion = "26.11";
  };
  fonts.fontconfig.enable = true;

  workstation = {
    sshProfile = "work";
    # Noctalia's AI usage widget, and gh opening the browser in its own systemd
    # unit, as on NixOS.
    settingMerges = ''
      merge ${config.xdg.configHome}/ai-usagebar/config.toml ${../configs/ai-usagebar/config.toml} toml
      merge ${config.xdg.configHome}/gh/config.yml ${../configs/gh/linux.yml} yaml
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
    configFile =
      lib.genAttrs [ "mise/conf.d/agents.toml" "mise/conf.d/linux-tools.toml" ] (name: {
        source = link name;
      })
      // lib.mapAttrs (_: name: { source = link "vscodium/${name}"; }) {
        "VSCodium/product.json" = "product.json";
        "VSCodium/User/settings.json" = "settings.json";
        "VSCodium/User/keybindings.json" = "keybindings.json";
      };
  };
}
