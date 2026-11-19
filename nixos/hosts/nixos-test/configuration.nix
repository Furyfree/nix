{ pkgs, ... }:

{
  imports = [
    ../../default.nix
    ../../ssh.nix
    ./local/hardware-configuration.nix
  ];

  networking.hostName = "nixos-test";
  # Intel integrated graphics: VA-API video encoding and decoding.
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
  # Test machine: the installer-chosen account runs sudo without a password.
  security.sudo.wheelNeedsPassword = false;
  system.stateVersion = "26.05";
}
