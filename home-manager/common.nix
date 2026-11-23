# Home Manager settings shared by every platform: terminal, shell, editors,
# Git, SSH and the agent settings merges. Platform modules import this.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.lib.workstation) link script;
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
    # Live links into the checkout, for every Home Manager module here.
    lib.workstation = {
      # A file or folder in configs/.
      link =
        path:
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/${path}";
      # One of the checkout's own scripts in bin/.
      script =
        name: config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/bin/${name}";
    };

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
    }
    // lib.genAttrs [ "pull-projects" "nix-workstation" ] (name: {
      target = ".local/bin/${name}";
      source = script name;
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
          # Yq's INI output pads "key = value", which xdg-open's reader skips,
          # and reads ";" as a comment, which mimeapps.list's lists use; merge
          # INI line by line instead. The patch's keys replace the target's in
          # their section, as plain key=value; everything else stays.
          merge_ini() {
            local target=$1 patch=$2 line section="" key value entry out=""
            local -A patched=() merged_keys=()
            local -a order=()
            while IFS= read -r line || [[ -n $line ]]; do
              if [[ $line == \[*\] ]]; then
                section=''${line:1:-1}
              elif [[ $line == *=* ]]; then
                key=''${line%%=*} value=''${line#*=}
                key=''${key%"''${key##*[![:space:]]}"} value=''${value#"''${value%%[![:space:]]*}"}
                [[ -n ''${patched[$section/$key]+set} ]] || order+=("$section/$key")
                patched[$section/$key]=$value
              fi
            done <"$patch"
            # The patch's keys a section has not had yet go at its end.
            merge_ini_rest() {
              local entry
              for entry in "''${order[@]}"; do
                if [[ ''${entry%%/*} == "$1" && -z ''${merged_keys[$entry]+set} ]]; then
                  out+="''${entry#*/}=''${patched[$entry]}"$'\n'
                  merged_keys[$entry]=1
                fi
              done
            }
            section=""
            while IFS= read -r line || [[ -n $line ]]; do
              if [[ $line == \[*\] ]]; then
                merge_ini_rest "$section"
                section=''${line:1:-1}
                out+="$line"$'\n'
              elif [[ $line == *=* ]]; then
                key=''${line%%=*} value=''${line#*=}
                key=''${key%"''${key##*[![:space:]]}"} value=''${value#"''${value%%[![:space:]]*}"}
                if [[ -n ''${patched[$section/$key]+set} ]]; then
                  value=''${patched[$section/$key]}
                  merged_keys[$section/$key]=1
                fi
                out+="$key=$value"$'\n'
              else
                out+="$line"$'\n'
              fi
            done <"$target"
            merge_ini_rest "$section"
            # Sections only the patch has.
            for entry in "''${order[@]}"; do
              [[ -z ''${merged_keys[$entry]+set} ]] || continue
              section=''${entry%%/*}
              out+=$'\n'"[$section]"$'\n'
              merge_ini_rest "$section"
            done
            [[ -v DRY_RUN ]] || printf '%s' "$out" >"$target"
          }
          merge() {
            local target=$1 patch=$2 format=$3 merged
            local expression='select(fi == 0) * select(fi == 1)'
            # A list merges entry by entry, as windows/apply.ps1 merges it: T3
            # Code's keybindings by key and when. Entries only the machine has
            # stay.
            if [[ $(${lib.getExe pkgs.yq-go} -p "$format" -o yaml tag "$patch" 2>/dev/null) == '!!seq' ]]; then
              expression='[.] | flatten(1) | group_by(.context // ((.key // "") + "|" + (.when // ""))) | map(. as $g | $g[] as $item ireduce ({}; . * $item))'
            fi
            # Yq reads an empty file as nothing, so start those from the patch too.
            if [[ ! -s $target ]]; then
              run install -D -m 0600 "$patch" "$target"
            elif [[ $format == ini ]]; then
              merge_ini "$target" "$patch"
            elif merged=$(${lib.getExe pkgs.yq-go} ea -p "$format" -o "$format" \
              "$expression" "$target" "$patch"); then
              # Rewrite in place to keep the file's owner and mode.
              [[ -v DRY_RUN ]] || printf '%s\n' "$merged" >"$target"
            else
              warnEcho "Skipping $target: Yq cannot merge it."
            fi
          }
          merge ${config.home.homeDirectory}/.claude/settings.json ${../configs/claude/settings.json} json
          merge ${config.home.homeDirectory}/.codex/config.toml ${../configs/codex/config.toml} toml
          merge ${config.xdg.configHome}/gh/config.yml ${../configs/gh/config.yml} yaml
          merge ${config.home.homeDirectory}/.t3/userdata/settings.json ${../configs/t3code/settings.json} json
          merge ${config.home.homeDirectory}/.t3/userdata/client-settings.json ${../configs/t3code/client-settings.json} json
          merge ${config.home.homeDirectory}/.t3/userdata/keybindings.json ${../configs/t3code/keybindings.json} json
          ${config.workstation.settingMerges}
        '';
  };
}
