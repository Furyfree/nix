# The desktop uses the shared home, with its two monitors and larger voice model.
{ lib, ... }:
{
  imports = [ ../../home.nix ];
  _module.args.noctalia = {
    outputs = [ "DP-3" "DP-4" ];
    ddcutil = true;
  };
  xdg.configFile = {
    "hypr/conf.d/monitors.lua".text = lib.mkAfter ''
      hl.monitor({ output = "DP-4", mode = "1920x1080@144", position = "0x0", scale = 1 })
      hl.monitor({ output = "DP-3", mode = "1920x1080@144", position = "1920x0", scale = 1 })
      hl.config({ cursor = { default_monitor = "DP-4" } })
    '';
    "hypr/conf.d/workspace-monitors.lua".text = lib.mkForce ''
      return {
        ["DP-4"] = { 1, 2, 3, 4, 5, 11, 12, 13, 14, 15 },
        ["DP-3"] = { 6, 7, 8, 9, 10, 16, 17, 18, 19, 20 },
      }
    '';
    "voxtype/config.toml".text = lib.mkForce (builtins.replaceStrings
      [ ''model = "small"'' ] [ ''model = "large-v3-turbo"'' ]
      (builtins.readFile ../../configs/voxtype/config.toml));
  };
  dconf.settings."com/vysp3r/ProtonPlus/State" = {
    background-updates-frequency = "1h";
    check-updates-on-boot = true;
    check-updates-on-launch = true;
    background-updates = true;
  };
}
