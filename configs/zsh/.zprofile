# Homebrew on macOS, which path_helper in /etc/zprofile leaves out.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Rust tools installed with cargo install.
if [[ -r "$HOME/.cargo/env" ]]; then
  source "$HOME/.cargo/env"
fi

# Ubuntu: Nix's installer puts its profiles on PATH for interactive shells
# only, and the Niri session takes PATH from this login shell. NixOS sets both
# at login (nixos/desktop.nix).
if [[ $OSTYPE == linux* && ! -e /etc/NIXOS ]]; then
  if [[ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi
  path=("$HOME/.local/share/mise/shims"(N/) "${path[@]}")
fi

path=(
  "$HOME/.local/bin"
  "$HOME/.pixi/bin"(N/)
  "$HOME/.lmstudio/bin"(N/)
  "${path[@]}"
)

typeset -U path
export PATH
