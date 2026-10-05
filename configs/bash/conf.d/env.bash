dotfiles_bash_env() {
  local editor
  if [[ -z ${EDITOR-} ]]; then
    for editor in nvim vim vi; do
      if type -P "$editor" >/dev/null 2>&1; then
        export EDITOR="$editor"
        break
      fi
    done
  fi
  if [[ -n ${EDITOR-} ]]; then
    export EDITOR
    export VISUAL="${VISUAL:-$EDITOR}"
  fi
  if [[ -z ${PAGER-} ]] && type -P less >/dev/null 2>&1; then
    export PAGER='less -R'
  fi
}
dotfiles_bash_env
unset -f dotfiles_bash_env
