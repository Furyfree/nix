dotfiles_bash_mise() {
  type -P mise >/dev/null 2>&1 || return 0
  local generated
  generated="$(command mise activate bash)" || return
  eval "$generated"
}
dotfiles_bash_mise
unset -f dotfiles_bash_mise
