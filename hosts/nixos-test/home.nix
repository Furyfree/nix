# Home Manager configuration for the user on the NixOS test machine.
{ ... }:

{
  imports = [ ../../home.nix ];

  home.stateVersion = "26.05";
}
