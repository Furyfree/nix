# Hyprland under UWSM, with the shared desktop from desktop.nix. Its links
# are in home/hyprland.nix.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf (config.workstation.desktop == "hyprland") {
    programs.hyprland = {
      enable = true;
      withUWSM = true;
    };

    services = {
      displayManager.noctalia-greeter.settings.session.default = "Hyprland (uwsm-managed)";
      greetd.settings.initial_session = lib.mkIf config.services.displayManager.autoLogin.enable {
        command = "${lib.getExe pkgs.uwsm} start -e -D Hyprland hyprland.desktop";
      };
    };

    xdg.portal.config.hyprland = {
      default = [
        "hyprland"
        "gtk"
      ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };

    home-manager.sharedModules = [ ../home/hyprland.nix ];
  };
}
