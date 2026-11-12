# Niri's live checkout links and Noctalia's Niri settings, loaded by
# components/niri.nix. The machine's monitors and keys come from
# configs/niri/hosts/<hostname>.kdl.
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  link =
    path:
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/${path}";
  host = "niri/hosts/${osConfig.networking.hostName}.kdl";
  noctalia = builtins.fromTOML (builtins.readFile ../configs/noctalia/config.toml);
in
{
  xdg.configFile = {
    # Files, not the folder: Noctalia writes noctalia.kdl beside them.
    "niri/config.kdl".source = link "niri/config.kdl";
    # Noctalia reads this after config.toml. Its plugin list replaces the
    # earlier one, so it is config.toml's list without the Hyprland-only
    # plugins; a change there reaches Niri at the next rebuild.
    "noctalia/niri.toml".source = (pkgs.formats.toml { }).generate "noctalia-niri.toml" {
      plugins.enabled = lib.subtractLists [
        "furyfree/key-promoter"
        "profidev/hypr-screen-mirror"
      ] noctalia.plugins.enabled;
      # Off in config.toml for Hyprland's crash (#6), which Niri does not have.
      idle.behavior.screen-off.enabled = true;
    };
  }
  // lib.optionalAttrs (builtins.pathExists ../configs/${host}) {
    "niri/host.kdl".source = link host;
  };
}
