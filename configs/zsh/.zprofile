# Homebrew on macOS, which path_helper in /etc/zprofile leaves out.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Rust tools installed with cargo install.
if [[ -r "$HOME/.cargo/env" ]]; then
  source "$HOME/.cargo/env"
fi

path=(
  "$HOME/.local/bin"
  "$HOME/.pixi/bin"(N/)
  "${path[@]}"
)

typeset -U path
export PATH
