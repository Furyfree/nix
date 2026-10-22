# Home Manager configuration for the installer-selected user on this host.
{ config, ... }:

{
  imports = [ ../../home/linux.nix ];

  # The desktop's monitors and workspaces, as a live checkout link.
  xdg.configFile."hypr/host.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/hypr/hosts/desktop.lua";

  home.stateVersion = "26.11";
}
