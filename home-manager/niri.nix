# Niri's live checkout links and Noctalia's Niri settings, for NixOS
# (nixos/niri.nix) and Ubuntu. The machine's monitors and keys come from
# configs/niri/hosts/<host>.kdl.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.lib.workstation) link script;
  host = "niri/hosts/${config.workstation.host}.kdl";
  noctalia = builtins.fromTOML (builtins.readFile ../configs/noctalia/config.toml);
in
{
  options.workstation = {
    host = lib.mkOption {
      type = lib.types.str;
      description = "Picks configs/niri/hosts/<host>.kdl: the hostname on NixOS, a fixed name on Ubuntu.";
    };
    noctaliaPluginsOff = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Noctalia plugins this machine leaves out under Niri.";
    };
    noctaliaTemplates = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = { };
      description = "Noctalia user templates only this machine has, beside config.toml's.";
    };
  };

  config = {
    home.file.".local/bin/follow-mini-player".source = script "follow-mini-player";

    # Files, not the folder: Noctalia writes noctalia.kdl beside them.
    xdg.configFile =
      lib.genAttrs
        [
          "niri/config.kdl"
          "niri/conf.d/input.kdl"
          "niri/conf.d/monitors.kdl"
          "niri/conf.d/layout.kdl"
          "niri/conf.d/decoration.kdl"
          "niri/conf.d/window-rules.kdl"
          "niri/conf.d/autostart.kdl"
          "niri/conf.d/keybinds.kdl"
        ]
        (name: {
          source = link name;
        })
      // {
        # Noctalia reads this after config.toml. Its lists replace the earlier
        # ones, so they are config.toml's without the Hyprland-only plugins, this
        # machine's noctaliaPluginsOff and Hyprland's colour template; a change
        # there reaches Niri at the next switch.
        "noctalia/niri.toml".source = (pkgs.formats.toml { }).generate "noctalia-niri.toml" {
          plugins.enabled = lib.subtractLists (
            [ "profidev/hypr-screen-mirror" ] ++ config.workstation.noctaliaPluginsOff
          ) noctalia.plugins.enabled;
          # Each workspace on the bar's monitor as a box of its windows' app
          # icons, in place of the plain numbers; clicking an icon brings that
          # window into view, even one scrolled off screen.
          bar.default.start = [ "taskbar" ];
          widget.taskbar = {
            group_by_workspace = true;
            # Number workspaces by their place on the monitor, 1 to 5 on each,
            # as Hyprland's names do; the host files' workspace names are internal.
            label_source = "id";
            # The number's dot inside each pill, not on its edge; bold, as the
            # small number is hard to read thin.
            workspace_label_placement = "inside";
            font_weight = 700;
          };
          theme.templates = {
            builtin_ids = lib.remove "hyprland" noctalia.theme.templates.builtin_ids;
          }
          // lib.optionalAttrs (config.workstation.noctaliaTemplates != { }) {
            user = config.workstation.noctaliaTemplates;
          };
          # Off in config.toml for Hyprland's crash (#6), which Niri does not have.
          idle.behavior.screen-off.enabled = true;
        };
      }
      // lib.optionalAttrs (builtins.pathExists ../configs/${host}) {
        "niri/host.kdl".source = link host;
      };
  };
}
