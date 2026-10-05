{ pkgs, ... }:

{
  # TODO: Add automatic discovery of Windows and other operating systems.
  # Integrate detected entries before Limine config hashing and signing.
  boot.loader.limine.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.systemd.enable = true;
  boot.plymouth.enable = true;

  console.keyMap = "dk";
  # console.keyMap = "us";
}
