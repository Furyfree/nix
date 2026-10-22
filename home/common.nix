# Home Manager settings shared by every platform: terminal, shell, editors,
# Git, SSH and the agent settings merges. Platform modules import this.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # A live link to a file or folder in the checkout's configs/.
  link = path: config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/${path}";
  # Merges that only make sense on Linux: Noctalia's AI usage widget, and gh
  # opening the browser through UWSM.
  linuxSettings = lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
    merge ${config.xdg.configHome}/ai-usagebar/config.toml ${../configs/ai-usagebar/config.toml} toml
    merge ${config.xdg.configHome}/gh/config.yml ${../configs/gh/linux.yml} yaml
  '';
in
{
  imports = [ ./ssh.nix ];

  xdg = {
    enable = true;
    configFile =
      lib.genAttrs
        [
          "ghostty/config"
          "ghostty/themes/charcoal-blue"
          "sheldon/plugins.toml"
          "zsh/.zprofile"
          "zsh/.zshrc"
          "zsh/conf.d/aliases.zsh"
          "zsh/conf.d/completion.zsh"
          "zsh/conf.d/env.zsh"
          "zsh/conf.d/functions.zsh"
          "zsh/conf.d/fzf.zsh"
          "zsh/conf.d/history.zsh"
          "zsh/conf.d/keybindings.zsh"
          "zsh/conf.d/mise.zsh"
          "zsh/conf.d/options.zsh"
          "zsh/conf.d/plugins.zsh"
          "zsh/conf.d/prompt.zsh"
          "zsh/conf.d/zoxide.zsh"
          "btop/btop.conf"
          "fastfetch/config.jsonc"
          "fastfetch/ff.lua"
          "fastfetch/ff.sh"
          "mise/config.toml"
          "git/config"
          "git/ignore"
        ]
        (name: { source = link name; })
      // {
        # The whole folder, so vim.pack writes its lock file into the checkout.
        "nvim".source = link "nvim";
        "starship.toml".source = link "starship/starship.toml";
      };
  };

  # Zed rewrites its settings for model choices; merge the repo values into
  # its own file on activation instead of linking it.
  programs.zed-editor = {
    enable = true;
    userSettings = lib.importJSON ../configs/zed/settings.json;
    userKeymaps = lib.importJSON ../configs/zed/keymap.json;
  };

  home.file = {
    ".zshenv".source = link "zsh/.zshenv";
  }
  // lib.genAttrs [ "pull-projects" "nix-workstation" ] (name: {
    target = ".local/bin/${name}";
    source = link "bin/${name}";
  });

  # Agents and gh rewrite their own settings; set only the keys in
  # configs/<tool> and keep everything else. Files Yq cannot parse, such as
  # commented JSON, stay as they are.
  home.activation.toolSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    merge() {
      local target=$1 patch=$2 format=$3 merged
      # Yq reads an empty file as nothing, so start those from the patch too.
      if [[ ! -s $target ]]; then
        run install -D -m 0600 "$patch" "$target"
      elif merged=$(${lib.getExe pkgs.yq-go} ea -p "$format" -o "$format" \
        'select(fi == 0) * select(fi == 1)' "$target" "$patch"); then
        # Rewrite in place to keep the file's owner and mode.
        [[ -v DRY_RUN ]] || printf '%s\n' "$merged" >"$target"
      else
        warnEcho "Skipping $target: Yq cannot merge it."
      fi
    }
    merge ${config.home.homeDirectory}/.claude/settings.json ${../configs/claude/settings.json} json
    merge ${config.home.homeDirectory}/.codex/config.toml ${../configs/codex/config.toml} toml
    merge ${config.home.homeDirectory}/.grok/config.toml ${../configs/grok/config.toml} toml
    merge ${config.xdg.configHome}/opencode/opencode.jsonc ${../configs/opencode/opencode.json} json
    merge ${config.home.homeDirectory}/.pi/agent/settings.json ${../configs/pi/settings.json} json
    merge ${config.xdg.configHome}/gh/config.yml ${../configs/gh/config.yml} yaml
    ${linuxSettings}
  '';
}
