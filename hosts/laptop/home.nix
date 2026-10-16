# Home Manager configuration for the installer-selected user on this host.
{ config, ... }:

{
  imports = [ ../../home.nix ];

  # The laptop's internal panel scale, as a live checkout link.
  xdg.configFile."hypr/host.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/hypr/hosts/laptop.lua";

  home.stateVersion = "26.11";
}
