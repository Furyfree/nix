# The desktop every compositor shares: Noctalia, its greeter, the keyring,
# sound, fonts and apps. The compositor comes from workstation.desktop.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  autoLogin = config.services.displayManager.autoLogin;
  cursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = "24";
  };
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
  options.workstation.desktop = lib.mkOption {
    type = lib.types.enum [
      "hyprland"
      "niri"
    ];
    default = "hyprland";
    description = "Compositor this machine runs under Noctalia; nixos/<desktop>.nix sets it up.";
  };

  config = {
    programs = {
      noctalia = {
        enable = true;
        systemd.enable = true;
        recommendedServices.enable = true;
      };
      dconf.enable = true;
      # Noctalia's screen recorder plugin.
      gpu-screen-recorder.enable = true;
      # View and unlock the GNOME keyring.
      seahorse.enable = true;
    };

    systemd.user.services = {
      noctalia.serviceConfig = {
        WorkingDirectory = "%h";
        ExecStart = lib.mkForce noctaliaSession;
      };
      xdg-desktop-portal = {
        # Start with the session: the recorder plugin checks for the running
        # process instead of activating it over D-Bus.
        wantedBy = [ "graphical-session.target" ];
        # Take the session's PATH: NixOS's short one hid every app whose entry
        # names a bare program, so links Brave hands the portal found no app.
        environment.PATH = lib.mkForce null;
      };
    };

    services = {
      # Secret Service for apps; the keyring has a blank password because
      # auto-login never supplies one.
      gnome.gnome-keyring.enable = true;
      displayManager.autoLogin.user = lib.mkDefault (
        if builtins.length desktopUsers == 1 then builtins.head desktopUsers else null
      );
      # The compositor's component sets the default session.
      displayManager.noctalia-greeter = {
        enable = true;
        cursorTheme = { inherit (cursor) package name; };
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
          user.default = lib.mkIf autoLogin.enable autoLogin.user;
        };
      };
      # The compositor's component sets the auto-login command.
      greetd.settings = {
        general.source_profile = false;
        initial_session = lib.mkIf autoLogin.enable {
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

    xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

    qt = {
      enable = true;
      platformTheme = "qt5ct";
    };
    # The session environment, which login sets for the compositor, systemd
    # and shells alike; nixos/<desktop>.nix adds the compositor's own.
    environment.sessionVariables = {
      # The checkout's helpers, such as launch, and the tools mise installs.
      PATH = [
        "$HOME/.local/bin"
        "$HOME/.local/share/mise/shims"
      ];
      # Agents write bash, so run their commands in bash; .zshenv sets the same.
      CLAUDE_CODE_SHELL = "/run/current-system/sw/bin/bash";
      GROK_SHELL = "/run/current-system/sw/bin/bash";
      # T3 Code writes its t3code:// link handler with this command; the Nix
      # package leaves it unset, so the handler would start bare Electron.
      T3CODE_DESKTOP_LAUNCHER_PATH = "/run/current-system/sw/bin/t3code-desktop";
      # Prefer native Wayland, with X11 as a fallback. GTK does so by itself;
      # nixos/hyprland.nix forces it there only.
      QT_QPA_PLATFORM = "wayland;xcb";
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      # nixpkgs wrappers (Spotify, Obsidian, Discord, VSCodium) run natively on
      # Wayland only with this; otherwise they scale blurrily through XWayland.
      NIXOS_OZONE_WL = "1";
      GTK_IM_MODULE = "simple";
      # The qt module sets this for shells only. qt6ct also accepts qt5ct, so
      # both Qt generations load their plugin.
      QT_QPA_PLATFORMTHEME = config.qt.platformTheme;
      XCURSOR_THEME = cursor.name;
      XCURSOR_SIZE = cursor.size;
      # Hyprland's cursor library; other desktops ignore these.
      HYPRCURSOR_THEME = cursor.name;
      HYPRCURSOR_SIZE = cursor.size;
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
  };
}
