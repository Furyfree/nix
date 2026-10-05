source "$ZDOTDIR/conf.d/mise.zsh"
source "$ZDOTDIR/conf.d/env.zsh"
source "$ZDOTDIR/conf.d/options.zsh"
source "$ZDOTDIR/conf.d/history.zsh"
source "$ZDOTDIR/conf.d/keybindings.zsh"
source "$ZDOTDIR/conf.d/functions.zsh"
source "$ZDOTDIR/conf.d/fzf.zsh"
source "$ZDOTDIR/conf.d/prompt.zsh"
source "$ZDOTDIR/conf.d/plugins.zsh"
source "$ZDOTDIR/conf.d/aliases.zsh"

if [[ -r "$ZDOTDIR/conf.d/noctalia.zsh" ]]; then
  source "$ZDOTDIR/conf.d/noctalia.zsh"
fi
