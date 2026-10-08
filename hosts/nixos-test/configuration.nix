{ ... }:

{
  imports = [
    ../../system.nix
    ./hardware-configuration.nix
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
  system.stateVersion = "26.05";
}
