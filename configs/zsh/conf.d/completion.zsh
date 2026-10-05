command mkdir -p -m 700 -- "$XDG_CACHE_HOME/zsh" || return

zmodload zsh/complist || return
autoload -Uz compinit
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump" || return

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}'
