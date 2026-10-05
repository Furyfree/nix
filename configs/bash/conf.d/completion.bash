dotfiles_bash_completion() {
  [[ -z ${BASH_COMPLETION_VERSINFO-} ]] || return 0
  local file
  local candidates=("$XDG_DATA_HOME/bash-completion/bash_completion")
  case "$OSTYPE" in
    linux*) candidates+=(/usr/share/bash-completion/bash_completion /etc/bash_completion) ;;
    darwin*)
      if (( BASH_VERSINFO[0] >= 4 )); then
        candidates+=(/opt/homebrew/etc/profile.d/bash_completion.sh /usr/local/etc/profile.d/bash_completion.sh)
      else
        candidates+=(/opt/homebrew/etc/bash_completion /usr/local/etc/bash_completion)
      fi
      ;;
  esac
  for file in "${candidates[@]}"; do
    if [[ -r $file ]]; then
      dotfiles_bash_source_if_readable "$file"
      break
    fi
  done
}
dotfiles_bash_completion
unset -f dotfiles_bash_completion

if [[ -t 0 && $TERM != dumb ]]; then
  bind 'set completion-ignore-case on'
  bind 'set show-all-if-ambiguous on'
fi
