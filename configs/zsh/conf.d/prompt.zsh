if command -v starship >/dev/null 2>&1; then
  () {
    local starship_source
    starship_source="$(command starship init zsh)" || return
    export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship.toml"
    eval "$starship_source"
  }
fi
