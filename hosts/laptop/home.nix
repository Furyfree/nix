# Home Manager configuration for the installer-selected user on this host.
{ ... }:

{
  imports = [ ../../home/nixos.nix ];

  home.stateVersion = "26.11";
}
