{
  config,
  lib,
  pkgs,
  ...
}:

let
  autoLogin = config.services.displayManager.autoLogin;
  desktopUsers = lib.filter (name: config.users.users.${name}.isNormalUser) (
    builtins.attrNames config.home-manager.users
  );
  noctaliaSession = pkgs.writeShellScript "noctalia-session" ''
    if session_id=$(${lib.getExe' pkgs.systemd "loginctl"} show-user "$UID" --property=Display --value) && [[ -n "$session_id" ]]; then
      export XDG_SESSION_ID="$session_id"
    else
      printf '%s\n' 'Noctalia: logind display session unavailable; using the existing session lookup.' >&2
    fi
    exec ${lib.getExe config.programs.noctalia.package} "$@"
  '';
in
{
  programs = {
    hyprland = {
      enable = true;
      withUWSM = true;
    };
    noctalia = {
      enable = true;
      systemd.enable = true;
      recommendedServices.enable = true;
    };
    dconf.enable = true;
    # Noctalia's screen recorder plugin.
    gpu-screen-recorder.enable = true;
  };

  systemd.user.services = {
    noctalia.serviceConfig = {
      WorkingDirectory = "%h";
      ExecStart = lib.mkForce noctaliaSession;
    };
    # Start with the session as on Fedora; the recorder plugin checks for the
    # running process instead of activating it over D-Bus.
    xdg-desktop-portal.wantedBy = [ "graphical-session.target" ];
  };

  services = {
    # Secret Service for apps; the keyring has a blank password because
    # auto-login never supplies one.
    gnome.gnome-keyring.enable = true;
    displayManager.autoLogin.user = lib.mkDefault (
      if builtins.length desktopUsers == 1 then builtins.head desktopUsers else null
    );
    displayManager.noctalia-greeter = {
      enable = true;
      cursorTheme = {
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Ice";
      };
      passwordlessSyncUsers = lib.optional autoLogin.enable autoLogin.user;
      settings = {
        appearance = {
          scheme = "Synced";
          password_style = "default";
          hide_logo = true;
          power_buttons_position = "bottom-right";
          scheme_selector_position = "hidden";
          font_family = "Inter";
        };
        keyboard.layout = "dk";
        session.default = "Hyprland (uwsm-managed)";
        user.default = lib.mkIf autoLogin.enable autoLogin.user;
      };
    };
    greetd.settings = {
      general.source_profile = false;
      initial_session = lib.mkIf autoLogin.enable {
        command = "${lib.getExe pkgs.uwsm} start -e -D Hyprland hyprland.desktop";
        inherit (autoLogin) user;
      };
    };
    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
    udisks2.enable = true;
  };
  security.rtkit.enable = true;

  xdg.portal = {
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.hyprland = {
      default = [
        "hyprland"
        "gtk"
      ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };
  };

  qt = {
    enable = true;
    platformTheme = "qt5ct";
  };
  environment.systemPackages = with pkgs; [
    ghostty
    udiskie
    zathura
    libnotify
    # Noctalia plugin commands: area selection, screen mirror and crash reports.
    slurp
    socat
    jq
    # Noctalia template hooks, such as LibreOffice's.
    python3
    bibata-cursors
    papirus-icon-theme
    adw-gtk3
  ];
  fonts.packages = with pkgs; [
    inter
    nerd-fonts.jetbrains-mono
  ];
}
