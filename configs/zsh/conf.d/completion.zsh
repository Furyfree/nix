command mkdir -p -m 700 -- "$XDG_CACHE_HOME/zsh" || return

zmodload zsh/complist || return
autoload -Uz compinit

# The full check for new completions and unsafe folders runs once a day; other
# shells reuse the cached list. Delete it to pick up new completions at once.
() {
  local dump="$XDG_CACHE_HOME/zsh/zcompdump"
  local -a fresh=("$dump"(N.mh-24))
  if (( $#fresh )); then
    compinit -C -d "$dump"
  else
    compinit -d "$dump" && command touch -- "$dump"
  fi
} || return

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}'
# Group headings in completion lists, fzf-tab's too.
zstyle ':completion:*:descriptions' format '[%d]'
