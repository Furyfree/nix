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
  # Niri-style workspace overview, built against the system's Hyprland as the
  # plugin's own flake does. This commit is the one HyprPM built for 0.56.2 on
  # Fedora; bump it if a Hyprland update stops it compiling.
  scrolloverview = pkgs.hyprlandPlugins.mkHyprlandPlugin {
    hyprland = config.programs.hyprland.package;
    pluginName = "scrolloverview";
    version = "0-unstable-2026-09-07";
    src = pkgs.fetchFromGitHub {
      owner = "yayuuu";
      repo = "hyprland-scroll-overview";
      rev = "5e96ae20ec73c320248bcf3ff68b330bc1ed4152";
      hash = "sha256-clDeTM5itsJPvqpbEkbWUmuPROsz2+YUnTpqsjQDMqU=";
    };
    buildInputs = [ pkgs.lua5_4 ];
    enableParallelBuilding = true;
    dontUseCmakeConfigure = true;
    buildPhase = ''
      runHook preBuild
      export SCROLLOVERVIEW_BUILD_VERSION=5e96ae2
      make all
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -D scrolloverview.so $out/lib/libscrolloverview.so
      runHook postInstall
    '';
    meta = {
      homepage = "https://github.com/yayuuu/hyprland-scroll-overview";
      license = lib.licenses.bsd3;
    };
  };
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
  # The keyring module locks a new keyring with the login password, which
  # auto-login never supplies; keep the keyring's blank password instead.
  security.pam.services.login.enableGnomeKeyring = lib.mkForce false;

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

  # A fixed path for overview.lua's hl.plugin.load.
  environment.etc."hypr/plugins/scrolloverview.so".source =
    "${scrolloverview}/lib/libscrolloverview.so";

  qt = {
    enable = true;
    platformTheme = "qt5ct";
  };
  environment.systemPackages = with pkgs; [
    ghostty
    udiskie
    zathura
    libnotify
    # Noctalia plugin commands: area selection, screen mirror, crash reports
    # and the tailnet plugin's gio.
    slurp
    socat
    jq
    glib
    # Noctalia screenshots, text recognition, QR codes and plugin data.
    grim
    (tesseract.override { enableLanguages = [ "eng" ]; })
    qrencode
    sqlite
    # Noctalia template hooks, such as LibreOffice's.
    python3
    bibata-cursors
    papirus-icon-theme
    adw-gtk3
  ];
  fonts.packages = with pkgs; [
    inter
    nerd-fonts.jetbrains-mono
    jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    terminus_font
  ];
}
