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
  link =
    path:
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/${path}";
in
{
  imports = [ ./ssh.nix ];

  # Platform modules add their own merge lines for toolSettings below.
  options.workstation.settingMerges = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = "More merge lines for the toolSettings activation step.";
  };

  config = {
    xdg = {
      enable = true;
      configFile =
        lib.genAttrs
          [
            "ghostty/config"
            "ghostty/themes/charcoal-blue"
            "sheldon/plugins.toml"
            "zsh/.zprofile"
            # Child zsh inherits ZDOTDIR and reads this copy, not ~/.zshenv.
            "zsh/.zshenv"
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
          (name: {
            source = link name;
          })
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
      # T3 Code keeps these next to its threads and secrets, which stay unlinked.
      ".t3/userdata/settings.json".source = link "t3code/settings.json";
      ".t3/userdata/client-settings.json".source = link "t3code/client-settings.json";
      ".t3/userdata/keybindings.json".source = link "t3code/keybindings.json";
    }
    // lib.genAttrs [ "pull-projects" "nix-workstation" ] (name: {
      target = ".local/bin/${name}";
      source = link "bin/${name}";
    });

    # Agents and gh rewrite their own settings; set only the keys in
    # configs/<tool> and keep everything else. Files Yq cannot parse, such as
    # commented JSON, stay as they are.
    # After linkGeneration removes links it no longer manages, so a merge never
    # writes through an old link into the checkout.
    home.activation.toolSettings =
      lib.hm.dag.entryAfter
        [
          "writeBoundary"
          "linkGeneration"
        ]
        ''
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
          merge ${config.xdg.configHome}/gh/config.yml ${../configs/gh/config.yml} yaml
          ${config.workstation.settingMerges}
        '';
  };
}
