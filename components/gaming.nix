# Steam with Proton, launchers and game helpers.
{ pkgs, ... }:

{
  programs = {
    # Also enables 32-bit graphics for Proton and older games.
    steam = {
      enable = true;
      protontricks.enable = true;
    };
    gamemode.enable = true;
    gamescope.enable = true;
  };

  environment.systemPackages = with pkgs; [
    mangohud
    heroic
    protonplus
    # Brings its own Java runtimes.
    prismlauncher
    wowup-cf
    # Battle.net through its Wine runner, as on Fedora.
    lutris
  ];
}
