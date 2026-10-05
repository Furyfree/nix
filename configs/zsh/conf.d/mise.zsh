if command -v mise >/dev/null 2>&1; then
  () {
    local mise_source
    mise_source="$(command mise activate zsh)" || return
    eval "$mise_source"
  }
fi
