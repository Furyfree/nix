# Mise owns runtimes and developer tools; Nix provides Mise and what its downloads need.
{ pkgs, ... }:

{
  programs = {
    # Mise downloads prebuilt runtimes and tools that expect a standard ELF
    # loader.
    nix-ld = {
      enable = true;
      # Added to the module's defaults; .NET needs ICU.
      libraries = [ pkgs.icu ];
    };
    neovim = {
      enable = true;
      defaultEditor = true;
    };
  };

  environment.systemPackages = with pkgs; [
    # C compiler and linker for Rust, cgo and Neovim's tree-sitter parsers.
    gcc
    # Metals, which Mise has no entry for; home/cli-tools.nix has the language
    # servers Ubuntu shares.
    metals
  ];
}
