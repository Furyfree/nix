{
  config,
  lib,
  pkgs,
  ...
}:

let
  autoLogin = config.services.displayManager.autoLogin;
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
  };

  systemd.user.services.noctalia.serviceConfig.WorkingDirectory = "%h";

  services = {
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
    libnotify
    bibata-cursors
    papirus-icon-theme
    adw-gtk3
  ];
  fonts.packages = with pkgs; [
    inter
    nerd-fonts.jetbrains-mono
  ];
}
