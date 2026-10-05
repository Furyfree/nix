# macOS's system Bash 3.2 has no autocd option.
if (( BASH_VERSINFO[0] >= 4 )); then
  shopt -s autocd
fi
shopt -s checkwinsize
set -o emacs
