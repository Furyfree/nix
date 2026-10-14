# Shared NixOS settings, added one component at a time.
{ ... }:

{
  imports = [
    ./components/boot.nix
    ./components/development.nix
    ./components/editors.nix
    ./components/hyprland-noctalia.nix
    ./components/networking.nix
    ./components/shell.nix
    ./components/snapper.nix
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  time.timeZone = "Europe/Copenhagen";
  i18n.defaultLocale = "en_DK.UTF-8";

  fileSystems."/".options = [ "compress=zstd" ];
}
