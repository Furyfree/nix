() {
  local editor

  if [[ -z ${EDITOR-} ]]; then
    for editor in nvim vim vi; do
      if whence -p "$editor" >/dev/null 2>&1; then
        export EDITOR="$editor"
        break
      fi
    done
  fi

  if [[ -n ${EDITOR-} ]]; then
    export EDITOR
    export VISUAL="${VISUAL:-$EDITOR}"
  fi

  if [[ -z ${PAGER-} ]] && whence -p less >/dev/null 2>&1; then
    export PAGER='less -R'
  fi
}
