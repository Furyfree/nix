# The laptop uses the shared home, with panel scaling and the lid controls.
{ lib, ... }:
{
  imports = [ ../../home.nix ];
  _module.args.noctalia = {
    outputs = [ "eDP-1" ];
    extraPlugins = [ "8bury/lid-guard" ];
  };
  xdg.configFile = {
    "hypr/conf.d/monitors.lua".text = lib.mkAfter ''
      hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1.5 })
    '';
    "hypr/conf.d/keybinds.lua".text = lib.mkAfter ''
      hl.bind("SUPER + CTRL + L",
        hl.dsp.exec_cmd("noctalia msg plugin 8bury/lid-guard:lid-guard-service all toggle"),
        { description = "Toggle Lid Guard" })
    '';
  };
}
