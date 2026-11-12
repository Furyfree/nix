# Niri under UWSM, with the shared desktop from desktop.nix. Its links and
# Noctalia settings are in home/niri.nix.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # UWSM's recommended path, so the session runs the system's Niri.
  niri = "/run/current-system/sw/bin/niri";
in
{
  config = lib.mkIf (config.workstation.desktop == "niri") {
    programs = {
      niri = {
        enable = true;
        # GTK's file chooser, as under Hyprland.
        useNautilus = false;
      };
      # niri.desktop runs niri-session, which skips UWSM. With --session, Niri
      # hands its environment to systemd, which UWSM waits for.
      uwsm = {
        enable = true;
        waylandCompositors.niri = {
          prettyName = "Niri";
          comment = "Niri compositor managed by UWSM";
          binPath = niri;
          extraArgs = [ "--session" ];
        };
      };
    };

    services = {
      displayManager.noctalia-greeter.settings.session.default = "Niri (UWSM)";
      greetd.settings.initial_session = lib.mkIf config.services.displayManager.autoLogin.enable {
        command = "${lib.getExe pkgs.uwsm} start -e -D niri -- ${niri} --session";
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

    home-manager.sharedModules = [ ../home/niri.nix ];
  };
}
