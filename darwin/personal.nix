# The personal Mac: Office, the Craft apps, Tailscale, Discord, and Codex and
# Claude Code for every account. Mise adds the runtimes in my account only.
# Uncomment the games to add them back.
{ config, ... }:

{
  homebrew = {
    casks = [
      "microsoft-word" # .pkg without AutoUpdate: upgrade with --greedy
      "microsoft-excel"
      "microsoft-powerpoint"
      "photocraft"
      "filmcraft"
      "soundcraft"
      "effectcraft"
      "tailscale-app"
      "discord"
      # "steam"
      # "prismlauncher"
      # "battle-net" # Rosetta; run the staged installer yourself

      # Mise's agents.toml installs these elsewhere; Homebrew gives them to
      # every account here.
      "claude-code"
      "codex"
    ];
    brews = [ "mise" ];
  };

  home-manager.users.${config.system.primaryUser} =
    { config, ... }:
    {
      xdg.configFile."mise/conf.d/runtimes.toml".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/mise/conf.d/runtimes.toml";
    };
}
