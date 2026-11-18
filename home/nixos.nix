# Home Manager settings only the NixOS desktops have: the apps, games and agent
# tools Ubuntu leaves out, the hidden entries of Nix-installed apps, and
# Noctalia's Ghostty template from its Nix package. Builds on linux.nix.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  link =
    path:
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/${path}";
in
{
  imports = [ ./linux.nix ];

  workstation.hiddenEntries = {
    "mpv.desktop" = pkgs.mpv;
    "qt5ct.desktop" = pkgs.libsForQt5.qt5ct;
    "qt6ct.desktop" = pkgs.qt6Packages.qt6ct;
    "base.desktop" = pkgs.libreoffice;
    "math.desktop" = pkgs.libreoffice;
    "remote-viewer.desktop" = pkgs.virt-viewer;
    "dev.noctalia.Noctalia.desktop" = config.programs.noctalia.package;
    "me.kavishdevar.librepods.desktop" = pkgs.librepods;
  };

  xdg = {
    dataFile."icons/hicolor/512x512/apps/webapp-fotmob.png".source = ../configs/icons/webapp-fotmob.png;
    desktopEntries = {
      fotmob = {
        name = "FotMob";
        exec = "launch focus-webapp https://www.fotmob.com/";
        icon = "webapp-fotmob";
      };
      # Watch, pause or help an agent in its hidden desktop.
      agent-workspace = {
        name = "Agent Workspace";
        exec = "agent-workspace-linux viewer --id default --input-forwarding";
        icon = "preferences-desktop-remote-desktop";
      };
    };
    configFile =
      lib.genAttrs
        [
          "zathura/zathurarc"
          "mise/conf.d/nixos-tools.toml"
          "mise/conf.d/runtimes.toml"
          # Kept in GLib's own format, without comments: apps that set themselves
          # as default rewrite the whole file that way.
          "mimeapps.list"
          "voxtype/config.toml"
          "MangoHud/MangoHud.conf"
        ]
        (name: {
          source = link name;
        })
      // {
        # Reuse the pinned renderer and reload hook, not the config-rewriting apply hook.
        "noctalia/templates/ghostty".source =
          "${config.programs.noctalia.package}/share/noctalia/assets/templates/ghostty";
      };
  };

  # Steam's own link, made before Noctalia's Steam template can create a real
  # folder here that stops Steam's first-run setup.
  home.file.".steam/steam".source =
    config.lib.file.mkOutOfStoreSymlink "${config.xdg.dataHome}/Steam";

  # Zed's registry Grok starts its bin with Node, but Grok's npm install swaps
  # that bin for the native binary; start mise's grok directly instead.
  programs.zed-editor.userSettings.agent_servers.Grok = {
    type = "custom";
    command = "grok";
    args = [
      "agent"
      "stdio"
    ];
  };

  # Codex's Linux desktop tools, and the agents only these machines install.
  workstation.settingMerges = ''
    merge ${config.home.homeDirectory}/.codex/config.toml ${../configs/codex/linux.toml} toml
    merge ${config.home.homeDirectory}/.grok/config.toml ${../configs/grok/config.toml} toml
    merge ${config.xdg.configHome}/opencode/opencode.jsonc ${../configs/opencode/opencode.json} json
    merge ${config.home.homeDirectory}/.pi/agent/settings.json ${../configs/pi/settings.json} json
    merge ${config.home.homeDirectory}/.pi/agent/mcp.json ${../configs/pi/mcp.json} json
  '';

  home.activation = {
    # Prism picks the bundled Java each instance needs; a chosen Java is a store
    # path that breaks when Prism updates. Yq would drop the quotes Qt needs, so
    # change only this line.
    prismJavaSwitch = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      cfg="${config.xdg.dataHome}/PrismLauncher/prismlauncher.cfg"
      if [[ ! -e $cfg ]]; then
        run install -D -m 0644 /dev/stdin "$cfg" <<<$'[General]\nAutomaticJavaSwitch=true'
      elif ! grep -qx 'AutomaticJavaSwitch=true' "$cfg"; then
        run sed -i -e '/^AutomaticJavaSwitch=/d' \
          -e '/^\[General\]$/a AutomaticJavaSwitch=true' "$cfg"
      fi
    '';

    # Strata saves its settings only through links its user owns, not through
    # Home Manager's link into the store, so link the file straight to the
    # checkout. A settings file already there is kept as settings.toml.backup.
    strataSettingsLink = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      tracked="${config.home.homeDirectory}/Projects/nix/configs/strata/settings.toml"
      link="${config.xdg.configHome}/strata/settings.toml"
      if [[ ! -L $link ]]; then
        if [[ -e $link ]]; then
          run mv --backup=numbered "$link" "$link.backup"
        fi
        run mkdir -p "$(dirname "$link")"
        run ln -s "$tracked" "$link"
      fi
    '';

    # Newest first where new files land. Strata keeps per-folder sorts as its
    # own state, so write them only before its first run, then leave the file
    # to Strata.
    strataFolderSorts =
      let
        views = (pkgs.formats.toml { }).generate "strata-folder-views.toml" {
          version = 1;
          folder =
            map
              (path: {
                inherit path;
                sort = "created";
                direction = "descending";
              })
              [
                config.xdg.userDirs.download
                config.xdg.userDirs.extraConfig.SCREENSHOTS
                config.xdg.userDirs.extraConfig.RECORDINGS
              ];
        };
      in
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        file="${config.xdg.stateHome}/strata/folder-views.toml"
        if [[ ! -e $file ]]; then
          run install -D -m 0600 ${views} "$file"
        fi
      '';
  };

  dconf.settings = {
    # Apps list their buttons and fields for computer-use-linux.
    "org/gnome/desktop/interface".toolkit-accessibility = true;
    # ProtonPlus keeps Proton builds updated in the background (hourly by default).
    "com/vysp3r/ProtonPlus/State" = {
      background-updates = true;
      check-updates-on-boot = true;
      check-updates-on-launch = true;
    };
  };
}
