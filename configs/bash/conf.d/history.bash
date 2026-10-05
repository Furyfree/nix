HISTFILE="$XDG_STATE_HOME/bash/history"
HISTSIZE=20000
HISTFILESIZE=10000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend cmdhist histverify

if ! command mkdir -p -m 700 -- "${HISTFILE%/*}" ||
  ! command chmod 700 -- "${HISTFILE%/*}"; then
  unset HISTFILE
  return 1
fi

dotfiles_bash_history() {
  local result=$?
  if [[ -n ${HISTFILE-} ]]; then
    builtin history -a
    builtin history -n
  fi
  return "$result"
}

# Keep existing hooks and the last command's exit status intact.
case "${PROMPT_COMMAND[*]-}" in
  *dotfiles_bash_history*) ;;
  *)
    if [[ $(declare -p PROMPT_COMMAND 2>/dev/null) == 'declare -a '* ]]; then
      PROMPT_COMMAND=(dotfiles_bash_history "${PROMPT_COMMAND[@]}")
    else
      # This branch handles a scalar, not the array above.
      # shellcheck disable=SC2178,SC2128
      PROMPT_COMMAND="dotfiles_bash_history${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
    fi
    ;;
esac
