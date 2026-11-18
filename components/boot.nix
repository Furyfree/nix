{ pkgs, ... }:

{
  boot = {
    loader.limine = {
      enable = true;
      maxGenerations = 10;
    };

    kernelPackages = pkgs.linuxPackages_latest;
    plymouth.enable = true;
  };

  # nix-workstation switch reads the firmware's boot list with it to find
  # Windows for Limine's menu (limine-windows.nix).
  environment.systemPackages = [ pkgs.efibootmgr ];

  console.keyMap = "dk";
  # console.keyMap = "us";
}
