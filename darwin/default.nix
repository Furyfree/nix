# Shared nix-darwin settings for every Mac. The host's ignored local/user.nix
# sets system.primaryUser and imports this Mac's profile, personal.nix or
# work.nix.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  user = config.system.primaryUser;
in
{
  imports = [
    ./common.nix
    ./settings.nix
    ./shortcuts.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  users.users.${user}.home = "/Users/${user}";

  # Native user config owns completion initialization and the prompt.
  programs.zsh = {
    enable = true;
    enableGlobalCompInit = false;
    promptInit = "";
  };

  # Homebrew installs apps, fonts and tools but never upgrades or removes
  # them: upgrade in Terminal.app, remove by hand. Fonts go where every
  # account reads them.
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";
    };
    caskArgs.fontdir = "/Library/Fonts";
  };

  # Homebrew has no nh, which switches and cleans as on NixOS.
  environment.systemPackages = [ pkgs.nh ];

  # Apply the new settings without a logout where macOS allows it, as System
  # Settings does, and restart Finder for its own; nix-darwin restarts the Dock.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    launchctl asuser "$(id -u -- ${lib.escapeShellArg user})" sudo --user=${lib.escapeShellArg user} -- \
      /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    killall -qu ${lib.escapeShellArg user} Finder || true
  '';
}
