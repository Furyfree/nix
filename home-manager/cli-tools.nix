# The command-line tools the shared configs use, from Nix: nixos/shell.nix
# installs them on NixOS and ubuntu/home.nix on Ubuntu. A list, not a module.
# The Mac's brews in darwin/common.nix list the same tools; a tool added here
# goes there too.
pkgs:

let
  # The native fastfetch config formats rows with Lua, which nixpkgs leaves out.
  lua = pkgs.lua5_4;
  # fastfetch loads Lua at runtime as liblua5.4.so; Nix names it liblua.so.5.4.
  luaLibrary = pkgs.runCommand "liblua5.4" { } ''
    mkdir -p $out/lib
    ln -s ${lua}/lib/liblua.so.5.4 $out/lib/liblua5.4.so
  '';
  fastfetch = pkgs.fastfetch.override {
    fastfetch-unwrapped = pkgs.fastfetch-unwrapped.overrideAttrs (old: {
      # First, so its headers win over another input's Lua 5.2.
      buildInputs = [ lua ] ++ old.buildInputs;
    });
    extraRuntimeDependencies = [ luaLibrary ];
  };
in
with pkgs;
[
  starship
  fzf
  zoxide
  gh
  wl-clipboard
  sheldon
  bat
  eza
  yazi
  fd
  ripgrep
  fastfetch
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
  ffmpeg
  # nix-workstation, and Noctalia's plugin commands on the desktops.
  jq
  # Mise owns runtimes and developer tools; Nix provides Mise itself.
  mise
  tree-sitter
  # Language servers tied to Nix and the C toolchain; Mise installs the rest.
  nixd
  clang-tools
]
