# .profile may source .bashrc, so prepare PATH before preserving its setup.
if [ -r "${XDG_CONFIG_HOME:-$HOME/.config}/bash/profile" ]; then
  . "${XDG_CONFIG_HOME:-$HOME/.config}/bash/profile"
fi

if [ -r "$HOME/.profile" ]; then
  . "$HOME/.profile"
fi

if [ -r "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi
