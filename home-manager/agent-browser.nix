# The agents' browser, on personal machines only (NixOS and the personal Mac):
# agent-browser from Mise, driving Brave through bin/agent-brave. Its profile
# keeps passed bot checks and sign-ins, so it is the agents' own, never signed
# into work accounts.
{ config, pkgs, ... }:

let
  inherit (config.lib.workstation) script;
  # agent-browser expands no ~ in its config, so Nix writes the paths.
  settings = pkgs.writeText "agent-browser.json" (
    builtins.toJSON {
      executablePath = "${config.home.homeDirectory}/.local/bin/agent-brave";
      profile = "${config.xdg.dataHome}/agent-browser";
      maxOutput = 50000;
      idleTimeout = "10m";
    }
  );
in
{
  home.file.".local/bin/agent-brave".source = script "agent-brave";
  workstation.settingMerges = ''
    merge ${config.home.homeDirectory}/.agent-browser/config.json ${settings} json
  '';
}
