{ pkgs, ... }:

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
{
  users.defaultUserShell = pkgs.zsh;
  programs = {
    zsh = {
      enable = true;
      # Native user config owns completion initialization and the prompt.
      enableGlobalCompInit = false;
      promptInit = "";
    };
    # NH_FLAKE comes from the user's shell, which knows the checkout path.
    nh.enable = true;
    git = {
      enable = true;
      lfs.enable = true;
    };
  };

  # The shared list in home/packages.nix, plus the Lua-enabled fastfetch and
  # the Wayland clipboard.
  environment.systemPackages = [
    fastfetch
    pkgs.wl-clipboard
  ]
  ++ import ../home/packages.nix pkgs;
}
