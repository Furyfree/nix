# Shared user config mappings for the Linux workstations.
{ config, lib, pkgs, noctalia, ... }:

let
  # Link editable files from the checkout, rather than a copy in the Nix store.
  configs = "${config.home.homeDirectory}/Projects/nix/configs";
  link = config.lib.file.mkOutOfStoreSymlink;
  json5 = pkgs.python3Packages.toPythonApplication pkgs.python3Packages.json5;
  settingsMerger = pkgs.writeShellApplication {
    name = "merge-settings";
    runtimeInputs = [ pkgs.coreutils pkgs.jq json5 pkgs.yq-go ];
    text = builtins.readFile ./scripts/merge-settings.sh;
  };
  merge = format: source: target: operation:
    "run ${lib.getExe settingsMerger} ${lib.escapeShellArgs [ format "${configs}/${source}" target operation ]}";
  withHome = file: builtins.replaceStrings [ "@HOME@" ] [ config.home.homeDirectory ] (builtins.readFile file);
  noctaliaBase = builtins.fromTOML (builtins.readFile ./configs/noctalia/config.toml);
  outputs = noctalia.outputs or [ "" ];
  outputWidgets = output:
    let
      widgets = (builtins.fromTOML (builtins.replaceStrings
        [ "@OUTPUT@" ] [ output ] (withHome ./configs/noctalia/lockscreen-output.toml))).lockscreen_widgets.widget;
    in
    if output == "" then builtins.removeAttrs widgets [ "lockscreen-login-box@" ] else widgets;
  noctaliaSettings = lib.recursiveUpdate noctaliaBase {
    plugins.enabled = noctaliaBase.plugins.enabled ++ (noctalia.extraPlugins or [ ]);
    lockscreen_widgets = {
      enabled = true;
      schema_version = 2;
      grid = { cell_size = 16; major_interval = 4; visible = false; };
      widget_order = lib.concatMap (output: lib.optional (output != "") "lockscreen-login-box@${output}" ++ [
        "minimal-date-${output}"
        "minimal-clock-${output}" "minimal-avatar-${output}"
      ]) outputs;
      widget = lib.foldl' (widgets: output: widgets // outputWidgets output) { } outputs;
    };
  } // lib.optionalAttrs (noctalia ? ddcutil) { brightness = noctaliaBase.brightness // { enable_ddcutil = noctalia.ddcutil; }; };
in
{
  _module.args.noctalia = lib.mkDefault { };
  home.file = {
    ".bashrc".source = link "${configs}/bash/.bashrc";
    ".bash_profile".source = link "${configs}/bash/.bash_profile";
    ".blerc".source = link "${configs}/bash/.blerc";
    ".zshenv".source = link "${configs}/zsh/.zshenv";
    ".ssh/config".source = link "${configs}/ssh/config";
  };

  xdg.enable = true;
  xdg.configFile = {
    "bash/bashrc".source = link "${configs}/bash/bashrc";
    "bash/profile".source = link "${configs}/bash/profile";
    "bash/blerc".source = link "${configs}/bash/blerc";
    "bash/conf.d".source = link "${configs}/bash/conf.d";
    "zsh/.zshrc".source = link "${configs}/zsh/.zshrc";
    "zsh/.zprofile".source = link "${configs}/zsh/.zprofile";
    "zsh/conf.d".source = link "${configs}/zsh/conf.d";
    "starship.toml".source = link "${configs}/starship/starship.toml";
    "sheldon/plugins.toml".source = link "${configs}/sheldon/plugins.toml";
    "git/config".source = link "${configs}/git/config";
    "git/ignore".source = link "${configs}/git/ignore";
    "gh/config.yml".source = link "${configs}/gh/config.yml";
    "nvim".source = link "${configs}/nvim";
    "zed/keymap.json".source = link "${configs}/zed/keymap.json";
    "VSCodium/product.json".source = link "${configs}/vscodium/product.json";
    "VSCodium/User/keybindings.json".source = link "${configs}/vscodium/keybindings.json";
    "ghostty/config".source = link "${configs}/ghostty/config";
    "ghostty/themes/charcoal-blue".source = link "${configs}/ghostty/themes/charcoal-blue";
    "fastfetch/config.jsonc".source = link "${configs}/fastfetch/config.jsonc";
    "btop/btop.conf".source = link "${configs}/btop/btop.conf";
    "mise/config.toml".source = link "${configs}/mise/config.toml";
    "mise/conf.d/linux-tools.toml".source = link "${configs}/mise/conf.d/linux-tools.toml";
    "topgrade.toml".source = link "${configs}/topgrade/topgrade.toml";
    "uwsm/env".source = link "${configs}/uwsm/env";
    "uwsm/env-hyprland".source = link "${configs}/uwsm/env-hyprland";
    "gtk-3.0/settings.ini".source = link "${configs}/gtk/gtk-3.0.ini";
    "gtk-4.0/settings.ini".source = link "${configs}/gtk/gtk-4.0.ini";
    "gtk-3.0/bookmarks".text = withHome ./configs/gtk/bookmarks;
    "user-dirs.dirs".source = link "${configs}/gtk/user-dirs.dirs";
    "mimeapps.list".source = link "${configs}/gtk/mimeapps.list";
    "qt5ct/qt5ct.conf".text = withHome ./configs/qt/qt5ct.conf;
    "qt6ct/qt6ct.conf".text = withHome ./configs/qt/qt6ct.conf;
    "zathura/zathurarc".source = link "${configs}/zathura/zathurarc";
    "udiskie/config.yml".source = link "${configs}/udiskie/config.yml";
    "vm-curator/config.toml".source = link "${configs}/vm-curator/config.toml";
    "1Password/ssh/agent.toml".source = link "${configs}/1password/agent.toml";
    "voxtype/config.toml".text = builtins.readFile ./configs/voxtype/config.toml;
    "hypr/hyprland.lua".source = link "${configs}/hypr/hyprland.lua";
    "hypr/plugins.toml".source = link "${configs}/hypr/plugins.toml";
    "hypr/conf.d/monitors.lua".text = builtins.readFile ./configs/hypr/conf.d/monitors.lua;
    "hypr/conf.d/workspace-monitors.lua".text = builtins.readFile ./configs/hypr/conf.d/workspace-monitors.lua;
    "hypr/conf.d/keybinds.lua".text = builtins.readFile ./configs/hypr/conf.d/keybinds.lua;
    "noctalia/config.toml".source = (pkgs.formats.toml { }).generate "noctalia-config.toml" noctaliaSettings;
    "noctalia/vscodium.toml".source = link "${configs}/noctalia/vscodium.toml";
    "noctalia/templates".source = link "${configs}/noctalia/templates";
    "noctalia/assets".source = link "${configs}/noctalia/assets";
  } // lib.genAttrs (map (name: "hypr/conf.d/${name}.lua") [
    "animations" "autostart" "decoration" "input"
    "layout" "overview" "window-actions" "window-rules" "workspace-layouts" "workspaces"
  ]) (name: { source = link "${configs}/${name}"; });

  dconf.settings = {
    "org/gnome/nautilus/preferences".show-hidden-files = true;
    "org/gnome/desktop/privacy".remember-recent-files = false;
    "org/gnome/desktop/interface".gtk-enable-primary-paste = true;
    "org/gtk/settings/file-chooser" = {
      show-hidden = true;
      sort-directories-first = true;
      startup-mode = "cwd";
    };
    "org/gtk/gtk4/settings/file-chooser" = {
      show-hidden = true;
      sort-directories-first = true;
      startup-mode = "cwd";
    };
  };

  home.activation.userDirectories = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/Desktop" "$HOME/Downloads" "$HOME/Templates" "$HOME/Public" \
      "$HOME/Documents" "$HOME/Music" "$HOME/Projects" "$HOME/Pictures/Screenshots" \
      "$HOME/Videos/Recordings"
  '';

  # Apps retain writable files. Only preferences present in configs/ are managed.
  home.activation.appSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ${merge "json" "zed/settings.json" "${config.xdg.configHome}/zed/settings.json" ".[0] * .[1]"}
    ${merge "json" "vscodium/settings.json" "${config.xdg.configHome}/VSCodium/User/settings.json" ".[0] * .[1]"}
    ${merge "toml" "codex/config.toml" "${config.home.homeDirectory}/.codex/config.toml" ".[0] * .[1]"}
    ${merge "json" "claude/settings.json" "${config.home.homeDirectory}/.claude/settings.json" ".[0] * .[1]"}
    ${merge "toml" "grok/config.toml" "${config.home.homeDirectory}/.grok/config.toml" ".[0] * .[1]"}
    ${merge "json" "pi/settings.json" "${config.home.homeDirectory}/.pi/agent/settings.json" ".[0] * .[1]"}
    ${merge "json" "opencode/opencode.jsonc" "${config.xdg.configHome}/opencode/opencode.jsonc" ".[0] + .[1]"}
    ${merge "toml" "ai-usagebar/config.toml" "${config.xdg.configHome}/ai-usagebar/config.toml" ".[0] * .[1]"}
  '';

  home.activation.obsidianSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    vault=${lib.escapeShellArg "${config.home.homeDirectory}/Projects/dtu-bachelor/.obsidian"}
    if [[ -d "$vault" ]]; then
      if ${pkgs.procps}/bin/pgrep -u "$(${pkgs.coreutils}/bin/id -u)" -f '(^|/)obsidian( |$)' > /dev/null; then
        echo "Home Manager: close Obsidian and activate again to update its preferences."
      else
        ${lib.concatMapStringsSep "\n" (file:
          merge "json" "obsidian/${file}" "${config.home.homeDirectory}/Projects/dtu-bachelor/.obsidian/${file}" ".[0] * .[1]"
        ) [ "app.json" "appearance.json" "hotkeys.json" "plugins/tinymist/data.json" "plugins/omnisearch/data.json" "plugins/obsidian-hider/data.json" ]}
        ${merge "json" "obsidian/workspace.json" "${config.home.homeDirectory}/Projects/dtu-bachelor/.obsidian/workspace.json" ".[1] + .[0] + {left: .[1].left, right: .[1].right}"}
      fi
    fi
  '';

  # The existing Bash config looks for these under XDG_DATA_HOME first.
  xdg.dataFile = {
    "blesh".source = "${pkgs.blesh}/share/blesh";
    "bash-completion".source = "${pkgs.bash-completion}/share/bash-completion";
  };
}
