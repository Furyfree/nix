# Niri, which niri-session starts as the systemd session, with the shared
# desktop from desktop.nix.
{
  config,
  lib,
  pkgs,
  ...
}:

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

    home-manager.sharedModules = [
      ../home-manager/niri.nix
      { workstation.host = config.networking.hostName; }
      # The keys for NixOS's own apps; Ubuntu's are in its host file.
      (
        { config, ... }:
        {
          xdg.configFile."niri/conf.d/nixos.kdl".source = config.lib.workstation.link "niri/conf.d/nixos.kdl";
        }
      )
    ];
  };
}
