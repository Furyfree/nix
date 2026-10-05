dotfiles_bash_zoxide() {
  type -P zoxide >/dev/null 2>&1 || return 0
  local generated
  generated="$(command zoxide init bash)" || return
  eval "$generated"
}
dotfiles_bash_zoxide
unset -f dotfiles_bash_zoxide
