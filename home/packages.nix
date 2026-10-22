# Command-line tools the shared configs expect on every platform. NixOS
# installs them system-wide (components/shell.nix); macOS installs them through
# Home Manager (home/darwin.nix).
pkgs:
with pkgs;
[
  starship
  fzf
  zoxide
  gh
  sheldon
  bat
  eza
  yazi
  fd
  ripgrep
  tealdeer
  btop
  just
  lazygit
  yq-go
  file
  zip
  unzip
  _7zz
  unrar-free
  poppler-utils
  imagemagick
  yt-dlp
  typst
  duf
  tokei
  nmap
  gitleaks
]
