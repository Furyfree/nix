{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../system.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking.hostName = "nixos-test";
  networking.networkmanager.enable = true;

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

  services.snapper.configs.root = {
    SUBVOLUME = "/";
    FSTYPE = "btrfs";
    SYNC_ACL = false;
    BACKGROUND_COMPARISON = false;
    NUMBER_CLEANUP = true;
    NUMBER_MIN_AGE = 0;
    NUMBER_LIMIT = 6;
    NUMBER_LIMIT_IMPORTANT = 0;
    TIMELINE_CREATE = false;
    TIMELINE_CLEANUP = false;
    EMPTY_PRE_POST_CLEANUP = false;
  };

  system.stateVersion = "26.05";
}
