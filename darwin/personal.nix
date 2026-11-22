# The personal Mac: Office, the Craft apps, Tailscale, Discord, and Codex and
# Claude Code for every account.
# Uncomment the games to add them back.
{ config, ... }:

{
  homebrew = {
    casks = [
      "codexbar" # menu bar icon issue on 27: CodexBar#4506
      "microsoft-word"
      "microsoft-excel"
      "microsoft-powerpoint"
      # The Office casks leave it out, so nothing else patches Office.
      "microsoft-auto-update"
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

  # macOS ships with its firewall off; IT manages the work Mac's. Stealth mode
  # leaves pings and probes of closed ports unanswered.
  networking.applicationFirewall = {
    enable = true;
    enableStealthMode = true;
  };

  # CodexBar belongs to the personal Mac; its account state stays native.
  home-manager.users.${config.system.primaryUser} =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      # Providers enabled on the personal Mac.
      codexbarProviders = [
        "claude"
        "codex"
        "grok"
        "openrouter"
      ];
    in
    {
      targets.darwin.defaults = {
        # CodexBar's display and refresh choices; account ids and usage state stay
        # out.
        "com.steipete.codexbar" = {
          launchAtLogin = true;
          refreshFrequency = "adaptive";
          refreshAllProvidersOnMenuOpen = true;
          backgroundWorkLowPowerModePreference = "automatic";
          terminalApp = "ghostty";
          menuBarColorByProvider = true;
          menuBarColorPace = true;
          menuBarHighContrastOnInactiveDisplays = true;
          menuBarShowsBrandIconWithPercent = true;
          menuBarHidesCritters = false;
          highlightMenuCardsOnHover = false;
          paceVisible = false;
          quotaWarningMarkersVisible = false;
          showOptionalCreditsAndExtraUsage = false;
          usageBarsShowUsed = true;
          stayAwakeEnabled = true;
          tokenCostUsageEnabled = false;
          openAIWebAccessEnabled = false;
          agentSessionsRemoteEnabled = false;
          mergedOverviewAllAccounts = false;
        };
      };

      home = {
        # CodexBar's config.json also holds keys and token accounts, so it is never
        # linked: each switch only turns these providers on. Other providers stay
        # as each Mac has them; restart CodexBar to load the change.
        activation.codexbarProviders =
          let
            yq = lib.getExe pkgs.yq-go;
            wanted = ".providers[] | select(${
              lib.concatMapStringsSep " or " (id: ".id == \"${id}\"") codexbarProviders
            })";
          in
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            config=${config.xdg.configHome}/codexbar/config.json
            if [[ -s $config ]] && ! ${yq} -p json -e '[${wanted} | .enabled] | all' "$config" >/dev/null 2>&1; then
              if updated=$(${yq} -p json -o json '(${wanted} | .enabled) = true' "$config"); then
                [[ -v DRY_RUN ]] || printf '%s\n' "$updated" >"$config"
              else
                warnEcho "Skipping $config: Yq cannot read it."
              fi
            fi
          '';
      };
    };
}
