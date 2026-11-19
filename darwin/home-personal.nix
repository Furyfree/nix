# CodexBar belongs to the personal Mac; its account state stays native.
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
}
