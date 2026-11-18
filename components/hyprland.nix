# Hyprland, which starts the systemd session itself, with the shared desktop
# from desktop.nix. Its links are in home/hyprland.nix.
{
  config,
  lib,
  ...
}:

{
  config = lib.mkIf (config.workstation.desktop == "hyprland") {
    programs.hyprland.enable = true;

    # GTK prefers native Wayland, with X11 as a fallback. Hyprland only: under
    # Niri it turns off the GNOME portal's screen sharing (Niri's wiki,
    # Important Software).
    environment.sessionVariables.GDK_BACKEND = "wayland,x11,*";

    services = {
      displayManager.noctalia-greeter.settings.session.default = "Hyprland";
      greetd.settings.initial_session = lib.mkIf config.services.displayManager.autoLogin.enable {
        command = lib.getExe' config.programs.hyprland.package "start-hyprland";
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
