case $- in
  *i*) ;;
  *) return ;;
esac

if [ -r "${XDG_CONFIG_HOME:-$HOME/.config}/bash/bashrc" ]; then
  . "${XDG_CONFIG_HOME:-$HOME/.config}/bash/bashrc"
fi
