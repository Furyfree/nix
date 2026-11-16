# Home Manager configuration for the WSL account.
{ ... }:

{
  imports = [ ../../home/wsl.nix ];

  home.stateVersion = "26.11";
}
