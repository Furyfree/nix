# NixOS in WSL on the Windows desktop profile: the shell, CLI and development
# tools, without boot, desktop or Snapper. windows/apply.ps1 writes the ignored
# ./local/user.nix with the Windows account's name, e.g.:
#   { wsl.defaultUser = "alice"; }
{ config, inputs, ... }:

{
  imports = [
    inputs.nixos-wsl.nixosModules.default
    ../../development.nix
    ../../shell.nix
  ];

  wsl.enable = true;
  # No hardware-configuration.nix in WSL to name it; apply.ps1 installs the
  # x86_64 image.
  nixpkgs.hostPlatform = "x86_64-linux";
  # nh and nix-workstation pick nixosConfigurations.wsl by this name.
  networking.hostName = "wsl";

  home-manager.users.${config.wsl.defaultUser} = import ./home.nix;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # The NixOS release of the first nixos.wsl image apply.ps1 installed.
  system.stateVersion = "26.05";
}
