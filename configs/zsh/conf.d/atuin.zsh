# After fzf.zsh, so Atuin's Ctrl-R replaces fzf's; Up keeps its prefix search.
if command -v atuin >/dev/null 2>&1; then
  () {
    local atuin_source
    atuin_source="$(command atuin init zsh --disable-up-arrow)" || return
    eval "$atuin_source"
  }
fi
