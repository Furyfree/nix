# Mise owns runtimes and developer tools; Nix provides Mise and what its downloads need.
{ pkgs, ... }:

{
  # Mise downloads prebuilt runtimes and tools that expect a standard ELF loader.
  programs.nix-ld = {
    enable = true;
    # Added to the module's defaults; .NET needs ICU.
    libraries = [ pkgs.icu ];
  };

  environment.systemPackages = with pkgs; [
    mise
    # C compiler and linker for Rust and cgo builds.
    gcc
  ];
}
