# Home Manager settings only NixOS has: launcher entries, web apps, the agents
# and tools only NixOS installs, and its apps' settings. Builds on
# home-manager/common.nix and linux.nix; the compositor's links come from its
# module.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.lib.workstation) link;
  # A copy of a package's launcher entry, hidden from app menus but still
  # usable for file associations.
  hidden =
    package: name:
    pkgs.runCommand "hidden-${name}" { } ''
      sed '/^\[Desktop Entry\]/a NoDisplay=true' ${package}/share/applications/${name} > $out
    '';
in
{
  imports = [
    ../home-manager/common.nix
    ../home-manager/linux.nix
    ../home-manager/agent-browser.nix
  ];

  # Merges only NixOS needs: Noctalia's AI usage widget, Codex's Linux desktop
  # tools, the agents only NixOS installs, VSCodium, and the default apps;
  # apps save these settings themselves.
  workstation.settingMerges = ''
    merge ${config.xdg.configHome}/mimeapps.list ${../configs/mimeapps.list} ini
    merge ${config.xdg.configHome}/VSCodium/User/settings.json ${../configs/vscodium/settings.json} json
    merge ${config.xdg.configHome}/ai-usagebar/config.toml ${../configs/ai-usagebar/config.toml} toml
    merge ${config.home.homeDirectory}/.codex/config.toml ${../configs/codex/linux.toml} toml
    merge ${config.home.homeDirectory}/.grok/config.toml ${../configs/grok/config.toml} toml
    merge ${config.xdg.configHome}/opencode/opencode.jsonc ${../configs/opencode/opencode.json} json
    merge ${config.home.homeDirectory}/.pi/agent/settings.json ${../configs/pi/settings.json} json
    merge ${config.home.homeDirectory}/.pi/agent/mcp.json ${../configs/pi/mcp.json} json
  '';

  xdg = {
    dataFile =
      lib.mapAttrs'
        (name: package: lib.nameValuePair "applications/${name}" { source = hidden package name; })
        {
          "nvim.desktop" = pkgs.neovim;
          "yazi.desktop" = pkgs.yazi;
          "qt5ct.desktop" = pkgs.libsForQt5.qt5ct;
          "qt6ct.desktop" = pkgs.qt6Packages.qt6ct;
          "base.desktop" = pkgs.libreoffice;
          "math.desktop" = pkgs.libreoffice;
          "remote-viewer.desktop" = pkgs.virt-viewer;
          "dev.noctalia.Noctalia.desktop" = config.programs.noctalia.package;
          "me.kavishdevar.librepods.desktop" = pkgs.librepods;
        }
      // lib.genAttrs [ "chatgpt" "fotmob" "google-maps" ] (name: {
        target = "icons/hicolor/512x512/apps/webapp-${name}.png";
        source = ../configs/icons/webapp-${name}.png;
      });
    desktopEntries = {
      chatgpt = {
        name = "ChatGPT";
        exec = "launch focus-webapp https://chatgpt.com/";
        icon = "webapp-chatgpt";
      };
      fotmob = {
        name = "FotMob";
        exec = "launch focus-webapp https://www.fotmob.com/";
        icon = "webapp-fotmob";
      };
      google-maps = {
        name = "Google Maps";
        exec = "launch focus-webapp https://www.google.com/maps";
        icon = "webapp-google-maps";
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
          "ghostty/nixos"
          "zathura/zathurarc"
          "mise/conf.d/nixos-tools.toml"
          "voxtype/config.toml"
          "MangoHud/MangoHud.conf"
          "noctalia/vscodium.toml"
          "noctalia/templates/vscodium-output-path.sh"
        ]
        (name: {
          source = link name;
        })
      // lib.mapAttrs (_: name: { source = link "vscodium/${name}"; }) {
        "VSCodium/product.json" = "product.json";
        "VSCodium/User/keybindings.json" = "keybindings.json";
      }
      // {
        # Reuse the pinned renderer and reload hook, not the config-rewriting apply hook.
        "noctalia/templates/ghostty".source =
          "${config.programs.noctalia.package}/share/noctalia/assets/templates/ghostty";
      };
  };

  home.file = {
    # Steam's own link, made before Noctalia's Steam template can create a real
    # folder here that stops Steam's first-run setup.
    ".steam/steam".source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.dataHome}/Steam";
  };

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

    # The wallpapers repository lives with the other clones so pull-projects
    # updates it; link it where Noctalia looks once it is cloned. Runs before
    # Home Manager creates the user folders, and replaces only an empty folder.
    wallpapersLink = lib.hm.dag.entryBetween [ "createXdgUserDirectories" ] [ "writeBoundary" ] ''
      clone="${config.home.homeDirectory}/Projects/wallpapers"
      link="${config.home.homeDirectory}/Pictures/Wallpapers"
      if [[ -d $clone && ! -L $link ]]; then
        if [[ -d $link && -z $(ls -A "$link") ]]; then
          run rmdir "$link"
        fi
        if [[ ! -e $link ]]; then
          run mkdir -p "$(dirname "$link")"
          run ln -s "$clone" "$link"
        fi
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

  dconf.settings =
    let
      # Show hidden files and folders first; open where the app is working.
      fileChooser = {
        show-hidden = true;
        sort-directories-first = true;
        startup-mode = "cwd";
      };
    in
    {
      "org/gnome/desktop/interface" = {
        gtk-enable-primary-paste = true;
        icon-theme = "Papirus-Dark";
        cursor-theme = "Bibata-Modern-Ice";
        cursor-size = 24;
        # Apps list their buttons and fields for computer-use-linux.
        toolkit-accessibility = true;
      };
      "org/gnome/desktop/privacy".remember-recent-files = false;
      "org/gtk/settings/file-chooser" = fileChooser;
      "org/gtk/gtk4/settings/file-chooser" = fileChooser;
      # ProtonPlus keeps Proton builds updated in the background (hourly by default).
      "com/vysp3r/ProtonPlus/State" = {
        background-updates = true;
        check-updates-on-boot = true;
        check-updates-on-launch = true;
      };
    };
}
