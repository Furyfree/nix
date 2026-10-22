# Standalone Home Manager configuration for the work Mac. The ignored
# ./local/user.nix sets home.username (INSTALLATION.md).
_:

{
  imports = [ ../../home/darwin.nix ];

  workstation.sshProfile = "work";

  home.stateVersion = "26.11";
}
