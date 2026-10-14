{ pkgs, ... }:

{
  boot = {
    loader.limine = {
      enable = true;
      maxGenerations = 10;
    };
    loader.efi.canTouchEfiVariables = true;

    kernelPackages = pkgs.linuxPackages_latest;
    initrd.systemd.enable = true;
    plymouth.enable = true;
  };

  console.keyMap = "dk";
  # console.keyMap = "us";
}
