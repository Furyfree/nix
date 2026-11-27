bindkey -e

# Treat whitespace as an empty prompt, then let Zsh handle EOF normally.
_delete_char_or_eof() {
  if [[ -n $BUFFER && -z ${BUFFER//[[:space:]]/} ]]; then
    BUFFER=''
    zle -U $'\x04'
  else
    zle .delete-char-or-list
  fi
}
zle -N delete-char-or-eof _delete_char_or_eof
bindkey '^D' delete-char-or-eof

# Up/Down search history for lines that start with what is typed, as in fish;
# on an empty line they step through history as before.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

# Use the terminal's Home, End, Delete and arrow sequences when available.
if zmodload zsh/terminfo; then
  [[ -n ${terminfo[khome]-} ]] && bindkey "${terminfo[khome]}" beginning-of-line
  [[ -n ${terminfo[kend]-} ]] && bindkey "${terminfo[kend]}" end-of-line
  [[ -n ${terminfo[kdch1]-} ]] && bindkey "${terminfo[kdch1]}" delete-char
  [[ -n ${terminfo[kcuu1]-} ]] && bindkey "${terminfo[kcuu1]}" up-line-or-beginning-search
  [[ -n ${terminfo[kcud1]-} ]] && bindkey "${terminfo[kcud1]}" down-line-or-beginning-search
fi

# Common sequences also sent outside application-keypad mode.
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# Ctrl-X Ctrl-E edits the command line in $EDITOR, as in bash.
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# Page Up/Down search history using the text before the cursor.
bindkey '^[[5~' history-beginning-search-backward
bindkey '^[[6~' history-beginning-search-forward

bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word
bindkey '^[[3;5~' kill-word
bindkey '^W' backward-kill-word
bindkey '^[^?' backward-kill-word
