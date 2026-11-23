# Home Manager for the Ubuntu work laptop: the terminal, app configs and Niri
# desktop from home-manager/, with the work SSH keys. apps.sh installs the
# apps. The flake adds the ignored ubuntu/local/user.nix with the account, e.g.:
#   { home.username = "alice"; home.homeDirectory = "/home/alice"; }
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # The shared fastfetch layout with Ubuntu's logo, as darwin/home.nix gives
  # the Mac its own; a switch applies edits.
  fastfetch =
    let
      shared = lib.importJSON ../configs/fastfetch/config.jsonc;
    in
    pkgs.writeText "fastfetch-config.jsonc" (
      builtins.toJSON (
        shared
        // {
          logo = shared.logo // {
            source = "ubuntu";
          };
        }
      )
    );
  # Docker and systemd come from apt, so the script uses theirs.
  windows-vm = import ../bin/windows-vm.nix { inherit pkgs; };
  # Ptyxis names its profiles with random IDs on first start, so this one has a
  # fixed ID that carries Noctalia's palette (noctaliaTemplates.ptyxis).
  ptyxisProfile = "4b6a268a8d504a9ebb29e6f66ce9780d";
  # A mail link as a new mail in Outlook on the web, in its own Brave window as
  # the Outlook entry opens; Outlook reads the whole mailto: link from mailtouri.
  outlookMail = pkgs.writeShellScript "outlook-mail" ''
    exec launch webapp "https://outlook.office.com/mail/deeplink/compose?mailtouri=$(${lib.getExe pkgs.jq} -rn --arg link "$1" '$link | @uri')"
  '';
in
{
  imports = [
    ../home-manager/common.nix
    ../home-manager/linux.nix
    ../home-manager/niri.nix
  ];

  # Nix's profile on the session's paths. Ubuntu's own drivers serve the GUI
  # apps, which come from apt and Flatpak.
  targets.genericLinux = {
    enable = true;
    gpu.enable = false;
  };

  home = {
    packages =
      import ../home-manager/cli-tools.nix pkgs
      ++ (with pkgs; [
        # NixOS gets it from its module.
        neovim
        # Ghostty's font
        nerd-fonts.jetbrains-mono
        # GTK 3's theme, which linux.nix picks; Ubuntu's archive has none.
        adw-gtk3
        # Git signs with this name, which 1Password's .deb keeps in /opt.
        (writeShellScriptBin "op-ssh-sign" ''exec /opt/1Password/op-ssh-sign "$@"'')
      ])
      ++ [ windows-vm ];
    stateVersion = "26.11";
    # Ptyxis uses only profiles in its list, which also holds those made in its
    # own settings: add ours beside them and make it the default when it goes
    # in. Ptyxis has made a default of its own by then, since bootstrap.sh runs
    # in it; a default chosen later in its settings stays. Home Manager's dconf
    # step drops its bus helper when done.
    activation.ptyxisProfile = lib.hm.dag.entryAfter [ "dconfSettings" ] ''
      ptyxis_dconf() {
        if [[ -v DBUS_SESSION_BUS_ADDRESS ]]; then
          ${lib.getExe' pkgs.dconf "dconf"} "$@"
        else
          ${lib.getExe' pkgs.dbus "dbus-run-session"} --dbus-daemon=${lib.getExe' pkgs.dbus "dbus-daemon"} \
            ${lib.getExe' pkgs.dconf "dconf"} "$@"
        fi
      }
      uuids=$(ptyxis_dconf read /org/gnome/Ptyxis/profile-uuids)
      case $uuids in
        *"'${ptyxisProfile}'"*) ;;
        "" | "@as []") run ptyxis_dconf write /org/gnome/Ptyxis/profile-uuids "['${ptyxisProfile}']" ;;
        *)
          run ptyxis_dconf write /org/gnome/Ptyxis/profile-uuids "['${ptyxisProfile}', ''${uuids#[}"
          run ptyxis_dconf write /org/gnome/Ptyxis/default-profile-uuid "'${ptyxisProfile}'"
          ;;
      esac
      case $(ptyxis_dconf read /org/gnome/Ptyxis/default-profile-uuid) in
        "" | "'''") run ptyxis_dconf write /org/gnome/Ptyxis/default-profile-uuid "'${ptyxisProfile}'" ;;
      esac
    '';
  };
  fonts.fontconfig.enable = true;
  # The session settings nixos/desktop.nix sets for NixOS.
  systemd.user.sessionVariables = {
    # Qt apps take Noctalia's colours through qt5ct, whose settings linux.nix
    # writes; qt6ct answers to the same name.
    QT_QPA_PLATFORMTHEME = "qt5ct";
    # GTK combines dead keys, such as AltGr+¨ for ~, itself: no input method
    # runs under Niri, and Ghostty leaves them to one.
    GTK_IM_MODULE = "simple";
  };

  workstation = {
    sshProfile = "work";
    # configs/niri/hosts/ubuntu.kdl, a fixed name rather than the laptop's own.
    host = "ubuntu";
    # Ptyxis, Ubuntu's own terminal, in Noctalia's colours; dconf.settings
    # below picks the palette.
    noctaliaTemplates.ptyxis = {
      enabled = true;
      input_path = "templates/ptyxis.palette";
      output_path = "$XDG_DATA_HOME/org.gnome.Ptyxis/palettes/noctalia.palette";
    };
    # AI usage, Git Companion (GitHub only), AirPods control, the tailnet and
    # the screen recorder stay on NixOS.
    noctaliaPluginsOff = [
      "felipeartur/ai-usagebar"
      "tphilippot/git_companion"
      "harveywuk/airpods"
      "rylos/tailnet"
      "noctalia/screen_recorder"
    ];
  };

  dconf.settings."org/gnome/Ptyxis/Profiles/${ptyxisProfile}".palette = "noctalia";

  # Zed installs and updates itself; Home Manager merges its settings.
  programs.zed-editor.package = null;

  # Old Home Manager generations and unused store paths go weekly, as
  # nixos/shell.nix has nh do on NixOS.
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep 10 --keep-since 14d";
    };
  };

  xdg = {
    # Web apps in their own Brave window; Papirus has their icons.
    desktopEntries = {
      teams = {
        name = "Teams";
        exec = "launch focus-webapp https://teams.microsoft.com/";
        icon = "teams";
      };
      outlook = {
        name = "Outlook";
        exec = "launch focus-webapp https://outlook.office.com/mail/";
        icon = "ms-outlook";
      };
      # Mail links; configs/mimeapps.list names it after NixOS's Fastmail.
      outlook-mail = {
        name = "Outlook mail";
        exec = "${outlookMail} %u";
        icon = "ms-outlook";
        noDisplay = true;
        mimeType = [ "x-scheme-handler/mailto" ];
      };
    };
    dataFile =
      # Hidden as on NixOS: settings tools, helpers, the terminal editors and
      # manual reader, and Noctalia itself, which runs already. Hidden=true
      # deletes an entry for this account.
      lib.genAttrs
        (map (name: "applications/${name}.desktop") [
          "qt5ct"
          "qt6ct"
          "org.freedesktop.IBus.Setup"
          "gnome-language-selector"
          "dev.noctalia.Noctalia"
          "nvim"
          "yazi"
          "vim"
          "info"
        ])
        (_: {
          text = "[Desktop Entry]\nHidden=true\n";
        })
      // {
        # The Windows VM's system service and polkit rule, as on NixOS; apps.sh
        # installs them.
        "windows-vm/${windows-vm.service}.service".text = lib.generators.toINI { } (
          windows-vm.passthru.unit {
            exe = lib.getExe windows-vm;
            docker = "/usr/bin/docker";
          }
        );
        "windows-vm/windows-vm.rules".text = windows-vm.passthru.polkitRule;
      };
    configFile = {
      "mise/conf.d/work.toml".source = config.lib.workstation.link "mise/conf.d/work.toml";
      # Ubuntu opens Terminal=true apps in its own terminal; Ghostty has the
      # Noctalia colours that btop, Yazi and Neovim take from it.
      "xdg-terminals.list".text = "com.mitchellh.ghostty.desktop\n";
      "fastfetch/config.jsonc".source = lib.mkForce fastfetch;
      "noctalia/templates/ptyxis.palette".source =
        config.lib.workstation.link "noctalia/templates/ptyxis.palette";
      # Noctalia's renderer and reload hook for Ghostty, from Noctalia's .deb.
      "noctalia/templates/ghostty".source =
        config.lib.file.mkOutOfStoreSymlink "/usr/share/noctalia/assets/templates/ghostty";
      # niri.service starts XDG autostart entries here, so 1Password's own Start
      # at login would run a second copy beside autostart.kdl's; GNOME keeps it.
      "systemd/user/app-com.onepassword.OnePassword@autostart.service.d/niri.conf".text = ''
        [Unit]
        ConditionEnvironment=!XDG_CURRENT_DESKTOP=niri
      '';
    };
  };
}
