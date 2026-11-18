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
  session = import ./session-variables.nix;
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
    description = "Compositor this machine runs under Noctalia; components/<desktop>.nix sets it up.";
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
      # Start with the session: the recorder plugin checks for the running
      # process instead of activating it over D-Bus.
      xdg-desktop-portal.wantedBy = [ "graphical-session.target" ];
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
        cursorTheme = {
          package = pkgs.bibata-cursors;
          name = session.XCURSOR_THEME;
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

    # Picks the compositor's host file in home/niri.nix and home/hyprland.nix.
    home-manager.sharedModules = [ { workstation.host = config.networking.hostName; } ];

    qt = {
      enable = true;
      platformTheme = session.QT_QPA_PLATFORMTHEME;
    };
    # The session environment, which login sets for the compositor, systemd
    # and shells alike: the list Ubuntu shares, and NixOS's own.
    # components/<desktop>.nix adds the compositor's. The qt module sets
    # QT_QPA_PLATFORMTHEME for shells only.
    environment.sessionVariables = session // {
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
      # nixpkgs wrappers (Spotify, Obsidian, Vesktop, VSCodium) run natively on
      # Wayland only with this; otherwise they scale blurrily through XWayland.
      NIXOS_OZONE_WL = "1";
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
