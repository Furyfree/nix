# Home Manager on the Ubuntu work laptop, run on its own: the Linux desktop
# from linux.nix under Niri. Ubuntu, apt, Flatpak and the makers' downloads own
# the system and the apps (ubuntu/); Nix adds the command-line tools.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  apps = "/usr/share/applications";
  flatpakApps = "${config.xdg.dataHome}/flatpak/exports/share/applications";
  # Launcher entries from apt and the Flatpaks, hidden as on NixOS, plus
  # Ubuntu's own tools.
  hiddenSystemEntries = [
    "${apps}/mpv.desktop"
    "${apps}/qt5ct.desktop"
    "${apps}/qt6ct.desktop"
    "${apps}/dev.noctalia.Noctalia.desktop"
    "${apps}/vim.desktop"
    "${apps}/info.desktop"
    "${apps}/im-config.desktop"
    "${apps}/org.freedesktop.IBus.Setup.desktop"
    "${apps}/nm-connection-editor.desktop"
    "${flatpakApps}/org.libreoffice.LibreOffice.base.desktop"
    "${flatpakApps}/org.libreoffice.LibreOffice.math.desktop"
  ];
  # The shared configs call these by their NixOS names.
  commands = {
    zeditor = ''exec "$HOME/.local/bin/zed" "$@"'';
    t3code-desktop = ''exec t3code "$@"'';
    obsidian = ''exec flatpak run md.obsidian.Obsidian "$@"'';
    strata = ''exec nautilus "$@"'';
    # Git's signer; 1Password's package leaves it off PATH.
    op-ssh-sign = ''exec /opt/1Password/op-ssh-sign "$@"'';
  };
in
{
  imports = [
    ./linux.nix
    ./niri.nix
  ];

  targets.genericLinux = {
    enable = true;
    # No graphical app comes from Nix, so Nix needs no GPU drivers.
    gpu.enable = false;
  };

  home.packages =
    import ../components/shell-packages.nix pkgs
    ++ lib.mapAttrsToList pkgs.writeShellScriptBin commands
    ++ (with pkgs; [
      # What components/cli.nix, editors.nix, development.nix and shell.nix
      # add on NixOS; Ubuntu has Git and the C toolchain.
      ffmpeg
      jq
      neovim
      tree-sitter
      mise
      nixd
      clang-tools
      nh
      # Theme parts apt lacks.
      adw-gtk3
      nerd-fonts.jetbrains-mono
    ]);

  # Fonts from Nix.
  fonts.fontconfig.enable = true;

  # Read by systemd, so Niri, Noctalia and the apps they start all get it.
  systemd.user.sessionVariables = import ../components/session-variables.nix;

  # Noctalia from apt has no unit. This starts it with Niri, not with GNOME.
  systemd.user.services.noctalia = {
    Unit = {
      Description = "Noctalia - A lightweight Wayland shell and bar";
      Documentation = "https://docs.noctalia.dev/v5/";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "/usr/bin/noctalia";
      Restart = "on-failure";
      WorkingDirectory = "%h";
    };
    Install.WantedBy = [ "niri.service" ];
  };

  # Zed comes from its own installer and updates itself; Home Manager only
  # merges its settings.
  programs.zed-editor.package = null;

  # Reuse the renderer and reload hook of Noctalia's package, not the
  # config-rewriting apply hook.
  xdg.configFile."noctalia/templates/ghostty".source =
    config.lib.file.mkOutOfStoreSymlink "/usr/share/noctalia/assets/templates/ghostty";

  # Copies of the system's entries with NoDisplay, made on each switch, since
  # Nix cannot read /usr while building. An entry a package drops stays hidden.
  home.activation.hideSystemEntries = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for entry in ${lib.escapeShellArgs hiddenSystemEntries}; do
      if [[ -r $entry ]]; then
        copy="${config.xdg.dataHome}/applications/''${entry##*/}"
        run mkdir -p "''${copy%/*}"
        [[ -v DRY_RUN ]] || sed '/^\[Desktop Entry\]/a NoDisplay=true' "$entry" >"$copy"
      fi
    done
  '';
}
