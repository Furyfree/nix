if command -v zoxide >/dev/null 2>&1; then
  () {
    local zoxide_source
    zoxide_source="$(command zoxide init zsh)" || return
    eval "$zoxide_source"
  }
fi
