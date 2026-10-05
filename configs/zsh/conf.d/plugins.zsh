if command -v sheldon >/dev/null 2>&1; then
  () {
    local plugin_source
    plugin_source="$(command sheldon source)" || {
      source "$ZDOTDIR/conf.d/completion.zsh"
      source "$ZDOTDIR/conf.d/zoxide.zsh"
      return
    }
    eval "$plugin_source"
  }
else
  source "$ZDOTDIR/conf.d/completion.zsh"
  source "$ZDOTDIR/conf.d/zoxide.zsh"
fi
