# Firmware updates and network services shared by every machine.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.services.displayManager.autoLogin) user;
in
{
  services = {
    fwupd.enable = true;
    tailscale = {
      enable = true;
      # As Nimbus's tailscale-operator step: the desktop user, and Noctalia's
      # tailnet plugin, control Tailscale without sudo. Sign in with tailscale up.
      extraSetFlags = lib.optional (user != null) "--operator=${user}";
    };
  };

  # WireGuard is built into NetworkManager; OpenConnect needs its plugin.
  networking.networkmanager.plugins = [ pkgs.networkmanager-openconnect ];
  environment.systemPackages = [ pkgs.wireguard-tools ];
}
