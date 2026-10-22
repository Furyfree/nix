if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons=auto --grid --group-directories-first'
  alias ll='eza -la --header --icons=auto --group-directories-first'
  alias la='eza -a --icons=auto --grid --group-directories-first'
  alias lt='eza --tree --icons=auto --group-directories-first'
else
  alias ll='ls -lah'
  alias la='ls -a'
fi

if command -v nvim >/dev/null 2>&1; then
  alias n='nvim'
fi

if whence -p bat >/dev/null 2>&1; then
  alias bat='bat -pp'
elif whence -p batcat >/dev/null 2>&1; then
  alias bat='batcat -pp'
fi

if ! command -v zed >/dev/null 2>&1 && command -v zeditor >/dev/null 2>&1; then
  alias zed='zeditor'
fi

if ! command -v hx >/dev/null 2>&1 && command -v helix >/dev/null 2>&1; then
  alias hx='helix'
fi

# Install the checkout's VSCodium extensions; installed ones are skipped.
if command -v codium >/dev/null 2>&1; then
  alias codium-extensions='xargs -a ~/Projects/nix/configs/vscodium/extensions.txt -n1 codium --install-extension'
fi

if ! command -v code >/dev/null 2>&1; then
  if command -v codium >/dev/null 2>&1; then
    alias code='codium'
  elif command -v vscodium >/dev/null 2>&1; then
    alias code='vscodium'
  fi
fi

alias c='clear'
alias h='history 1'
alias mkdir='mkdir -p'

if command -v fastfetch >/dev/null 2>&1; then
  alias f='fastfetch'
fi

if command -v tldr >/dev/null 2>&1; then
  alias help='tldr'
fi

if command -v lazydocker >/dev/null 2>&1; then
  alias lzd='lazydocker'
fi

if command -v lazygit >/dev/null 2>&1; then
  alias lg='lazygit'
fi

if command -v nix-workstation >/dev/null 2>&1; then
  alias nswitch='nix-workstation switch'
  alias nupdate='nix-workstation update'
  alias ninfo='nix-workstation info'
  alias nrollback='nix-workstation rollback'
  alias nclean='nix-workstation clean'
  alias nsearch='nix-workstation search'
  alias mup='nix-workstation mise'
  alias fup='nix-workstation firmware'
fi

# Nixpkgs' 7-Zip only installs 7zz; Fedora's is 7z.
if ! command -v 7z >/dev/null 2>&1 && command -v 7zz >/dev/null 2>&1; then
  alias 7z='7zz'
fi

