{ ... }:

{
  imports = [
    ../../system.nix
    ../../components/intel-graphics.nix
    ../../components/ssh.nix
    ./local/hardware-configuration.nix
  ];

  networking.hostName = "nixos-test";
  # Test machine: the installer-chosen account runs sudo without a password.
  security.sudo.wheelNeedsPassword = false;
  system.stateVersion = "26.05";
}
