# Shared NixOS settings, added one component at a time.
{ ... }:

{
  imports = [
    ./components/1password.nix
    ./components/apps.nix
    ./components/boot.nix
    ./components/claude-desktop.nix
    ./components/computer-use.nix
    ./components/craft-suite.nix
    ./components/desktop.nix
    ./components/development.nix
    ./components/devices.nix
    ./components/editors.nix
    ./components/hyprland.nix
    ./components/networking.nix
    ./components/niri.nix
    ./components/printing.nix
    ./components/services.nix
    ./components/shell.nix
    ./components/snapper.nix
    ./components/strata.nix
    ./components/virtualization.nix
    ./components/voxtype.nix
    ./components/windows-vm.nix
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
