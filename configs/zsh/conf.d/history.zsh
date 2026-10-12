HISTFILE="$XDG_STATE_HOME/zsh/history"
HISTSIZE=20000
SAVEHIST=10000

# Keep history private without changing the shell's umask.
command mkdir -p -m 700 -- "${HISTFILE:h}" &&
  command chmod 700 -- "${HISTFILE:h}" || {
  unset HISTFILE
  return 1
}

# SHARE_HISTORY writes commands as they are entered and imports other sessions.
unsetopt INC_APPEND_HISTORY INC_APPEND_HISTORY_TIME
setopt SHARE_HISTORY

setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_LEX_WORDS
setopt HIST_VERIFY
