# Home Manager configuration for the installer-selected user on this host.
{ ... }:

{
  imports = [ ../../home/linux.nix ];

  home.stateVersion = "26.11";
}
