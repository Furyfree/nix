# Niri, which niri-session starts as the systemd session, with the shared
# desktop from desktop.nix.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # The Home Manager half: the live checkout links and Noctalia's Niri
  # settings. The machine's monitors and keys come from
  # configs/niri/hosts/<hostname>.kdl.
  home =
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
          # ones, so they are config.toml's without the Hyprland-only plugins and
          # Hyprland's colour template; a change there reaches Niri at the next
          # rebuild.
          "noctalia/niri.toml".source = (pkgs.formats.toml { }).generate "noctalia-niri.toml" {
            plugins.enabled = lib.subtractLists [
              "furyfree/key-promoter"
              "profidev/hypr-screen-mirror"
            ] noctalia.plugins.enabled;
            theme.templates.builtin_ids = lib.remove "hyprland" noctalia.theme.templates.builtin_ids;
            # Off in config.toml for Hyprland's crash (#6), which Niri does not have.
            idle.behavior.screen-off.enabled = true;
            # Number workspaces by their place on the monitor, 1 to 5 on each, as
            # Hyprland's names do; the host files' workspace names are internal.
            widget.workspaces.label_source = "id";
          };
        }
        // lib.optionalAttrs (builtins.pathExists ../configs/${host}) {
          "niri/host.kdl".source = link host;
        };
    };
in
{
  config = lib.mkIf (config.workstation.desktop == "niri") {
    programs.niri = {
      enable = true;
      # GTK's file chooser, as under Hyprland.
      useNautilus = false;
    };

    services = {
      displayManager.noctalia-greeter.settings.session.default = "Niri";
      greetd.settings.initial_session = lib.mkIf config.services.displayManager.autoLogin.enable {
        command = lib.getExe' config.programs.niri.package "niri-session";
      };
    };

    # Niri starts it for X11 apps, but the module does not install it.
    environment.systemPackages = [ pkgs.xwayland-satellite ];

    # From Niri's wiki: the NVIDIA driver otherwise keeps freed video memory,
    # and Niri grows towards 1 GiB instead of about 100 MiB.
    environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json" =
      lib.mkIf config.hardware.nvidia.enabled {
        text = builtins.toJSON {
          rules = [
            {
              pattern = {
                feature = "procname";
                matches = "niri";
              };
              profile = "Limit Free Buffer Pool On Wayland Compositors";
            }
          ];
          profiles = [
            {
              name = "Limit Free Buffer Pool On Wayland Compositors";
              settings = [
                {
                  key = "GLVidHeapReuseRatio";
                  value = 0;
                }
              ];
            }
          ];
        };
      };

    home-manager.sharedModules = [ home ];
  };
}
