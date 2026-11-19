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

  # Linux slows each thread that takes a split lock on Intel CPUs; games under
  # Proton and the Windows VM take many. SteamOS turns the slowdown off too.
  boot.kernel.sysctl."kernel.split_lock_mitigate" = 0;

  environment.systemPackages = with pkgs; [
    mangohud
    heroic
    protonplus
    # Brings its own Java runtimes.
    prismlauncher
    wowup-cf
    # Battle.net through its Wine runner.
    lutris
  ];

  nixpkgs.config.allowUnfreePackages = [
    "steam"
    "steam-unwrapped"
    "wowup-cf"
  ];
}
