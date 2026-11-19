# Hyprland, which starts the systemd session itself, with the shared desktop
# from desktop.nix.
{
  config,
  lib,
  ...
}:

let
  # The Home Manager half: the live checkout links and Noctalia's Hyprland
  # settings. The machine's monitors and keys come from
  # configs/hypr/hosts/<hostname>.lua.
  home =
    {
      config,
      lib,
      osConfig,
      pkgs,
      ...
    }:

    let
      inherit (config.lib.workstation) link;
      host = "hypr/hosts/${osConfig.networking.hostName}.lua";
      noctalia = builtins.fromTOML (builtins.readFile ../configs/noctalia/config.toml);
    in
    {
      xdg.configFile =
        lib.genAttrs
          [
            "hypr/hyprland.lua"
            "hypr/conf.d/window-actions.lua"
            "hypr/conf.d/input.lua"
            "hypr/conf.d/monitors.lua"
            "hypr/conf.d/layout.lua"
            "hypr/conf.d/workspaces.lua"
            "hypr/conf.d/workspace-layouts.lua"
            "hypr/conf.d/decoration.lua"
            "hypr/conf.d/animations.lua"
            "hypr/conf.d/window-rules.lua"
            "hypr/conf.d/autostart.lua"
            "hypr/conf.d/keybinds.lua"
          ]
          (name: {
            source = link name;
          })
        // {
          # Key Promoter snippet, as a live checkout link; hyprland.lua loads it first.
          "hypr/conf.d/key-promoter.lua".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/noctalia-key-promoter/key-promoter/hypr/key-promoter.lua";
          # Noctalia reads this after config.toml. Its list replaces the earlier
          # one, so it is config.toml's without Niri's colour template; a change
          # there reaches Hyprland at the next rebuild.
          "noctalia/hyprland.toml".source = (pkgs.formats.toml { }).generate "noctalia-hyprland.toml" {
            theme.templates.builtin_ids = lib.remove "niri" noctalia.theme.templates.builtin_ids;
          };
        }
        // lib.optionalAttrs (builtins.pathExists ../configs/${host}) {
          "hypr/host.lua".source = link host;
        };
    };
in
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

    home-manager.sharedModules = [ home ];
  };
}
