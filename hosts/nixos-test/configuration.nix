{ ... }:

{
  imports = [
    ../../system.nix
    (
      if builtins.pathExists ./local/installation.nix then
        ./local/hardware-configuration.nix
      else
        ./hardware-configuration.nix
    )
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
  security.sudo.extraRules = [
    {
      users = [ "pby" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
  system.stateVersion = "26.05";
}
