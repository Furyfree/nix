# Shared NixOS settings, added one component at a time.
{ ... }:

{
  imports = [
    ./components/boot.nix
    ./components/networking.nix
    ./components/snapper.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  users.users.user = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [
      
    ];
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  fileSystems."/".options = [ "compress=zstd" ];
}
