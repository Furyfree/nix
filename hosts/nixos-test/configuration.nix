{ ... }:

{
  imports = [
    ../../system.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "nixos-test";
  system.stateVersion = "26.05";
}
