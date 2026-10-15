# Shared NixOS settings, added one component at a time.
{ ... }:

{
  imports = [
    ./components/apps.nix
    ./components/boot.nix
    ./components/development.nix
    ./components/devices.nix
    ./components/editors.nix
    ./components/hyprland-noctalia.nix
    ./components/networking.nix
    ./components/services.nix
    ./components/shell.nix
    ./components/snapper.nix
    ./components/virtualization.nix
    ./components/windows-vm.nix
  ];

  # Allow closed-source apps such as Spotify, Obsidian, Steam and NVIDIA.
  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  time.timeZone = "Europe/Copenhagen";
  i18n.defaultLocale = "en_DK.UTF-8";

  fileSystems."/".options = [ "compress=zstd" ];
}
