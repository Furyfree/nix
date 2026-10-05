dotfiles_bash_prompt() {
  type -P starship >/dev/null 2>&1 || return 0
  local generated
  generated="$(command starship init bash)" || return
  export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship.toml"
  eval "$generated"
}
dotfiles_bash_prompt
unset -f dotfiles_bash_prompt
