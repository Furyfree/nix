# Shared NixOS settings, added one component at a time.
{ ... }:

{
  imports = [
    ./1password.nix
    ./apps.nix
    ./boot.nix
    ./claude-desktop.nix
    ./computer-use.nix
    ./craft-suite.nix
    ./desktop.nix
    ./development.nix
    ./devices.nix
    ./hyprland.nix
    ./networking.nix
    ./niri.nix
    ./printing.nix
    ./services.nix
    ./shell.nix
    ./snapper.nix
    ./virtualization.nix
    ./voxtype.nix
    ./windows-vm.nix
  ];

  # Wi-Fi, Bluetooth and GPU firmware from linux-firmware.
  hardware.enableRedistributableFirmware = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  time.timeZone = "Europe/Copenhagen";
  i18n.defaultLocale = "en_DK.UTF-8";

  fileSystems."/".options = [ "compress=zstd" ];
}
