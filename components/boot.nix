{ pkgs, ... }:

{
  boot.loader.limine = {
    enable = true;
    maxGenerations = 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.systemd.enable = true;
  boot.plymouth.enable = true;

  console.keyMap = "dk";
  # console.keyMap = "us";
}
