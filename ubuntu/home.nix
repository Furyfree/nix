# Home Manager for the Ubuntu work laptop: the terminal and app configs from
# home/common.nix, with the work SSH keys. apps.sh installs the apps. The
# flake adds the ignored hosts/ubuntu/local/user.nix with the account, e.g.:
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
in
{
  imports = [ ../home/common.nix ];

  # Nix's profile on the session's paths. Ubuntu's own drivers serve the GUI
  # apps, which come from apt and Flatpak.
  targets.genericLinux = {
    enable = true;
    gpu.enable = false;
  };

  home = {
    packages =
      import ../home/cli-tools.nix pkgs
      ++ (with pkgs; [
        # NixOS gets these two from its modules.
        neovim
        nh
        # Ghostty's font
        nerd-fonts.jetbrains-mono
        # Git signs with this name, which 1Password's .deb keeps in /opt.
        (writeShellScriptBin "op-ssh-sign" ''exec /opt/1Password/op-ssh-sign "$@"'')
      ]);
    file.".local/bin/launch".source = link "bin/launch";
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

  xdg.configFile =
    lib.genAttrs [ "mise/conf.d/agents.toml" "mise/conf.d/linux-tools.toml" ] (name: {
      source = link name;
    })
    // lib.mapAttrs (_: name: { source = link "vscodium/${name}"; }) {
      "VSCodium/product.json" = "product.json";
      "VSCodium/User/settings.json" = "settings.json";
      "VSCodium/User/keybindings.json" = "keybindings.json";
    };
}
