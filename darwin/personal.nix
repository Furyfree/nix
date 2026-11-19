# The personal Mac: Office, the Craft apps, Tailscale, Discord, and Codex and
# Claude Code for every account.
# Uncomment the games to add them back.
{ config, ... }:

{
  homebrew = {
    casks = [
      "codexbar" # menu bar icon issue on 27: CodexBar#4506
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

  home-manager.users.${config.system.primaryUser}.imports = [ ../home/darwin-personal.nix ];
}
