{ ... }:

{
  imports = [
    ../../system.nix
    ../../components/intel-graphics.nix
    ./local/hardware-configuration.nix
  ];

  networking.hostName = "nixos-test";
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = true;
      PubkeyAuthentication = true;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  # Test machine: the installer-chosen account runs sudo without a password.
  security.sudo.wheelNeedsPassword = false;
  system.stateVersion = "26.05";
}
