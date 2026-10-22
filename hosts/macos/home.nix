# Standalone Home Manager configuration for the user on macOS. The ignored
# ./local/user.nix sets home.username (INSTALLATION.md).
_:

{
  imports = [ ../../home/darwin.nix ];

  home.stateVersion = "26.11";
}
