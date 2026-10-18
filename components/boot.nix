{ pkgs, ... }:

{
  boot = {
    loader.limine = {
      enable = true;
      maxGenerations = 10;
    };

    kernelPackages = pkgs.linuxPackages_latest;
    initrd.systemd.enable = true;
    plymouth.enable = true;
  };

  console.keyMap = "dk";
  # console.keyMap = "us";
}
