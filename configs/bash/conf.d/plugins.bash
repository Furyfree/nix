# ble.sh must be sourced at top level, before other interactive setup.
if [[ -t 0 && -t 1 && $TERM != dumb && -z ${BLE_VERSION-} ]]; then
  dotfiles_bash_ble_paths=("$XDG_DATA_HOME/blesh/ble.sh")
  case "$OSTYPE" in
    linux*)
      dotfiles_bash_ble_paths+=(/usr/share/blesh/ble.sh /usr/local/share/blesh/ble.sh)
      ;;
    darwin*)
      dotfiles_bash_ble_paths+=(/opt/homebrew/share/blesh/ble.sh /usr/local/share/blesh/ble.sh)
      ;;
  esac
  for dotfiles_bash_ble in "${dotfiles_bash_ble_paths[@]}"; do
    if [[ -r $dotfiles_bash_ble ]]; then
      source "$dotfiles_bash_ble" --attach=none --rcfile "$XDG_CONFIG_HOME/bash/blerc"
      break
    fi
  done
  unset dotfiles_bash_ble dotfiles_bash_ble_paths
fi
