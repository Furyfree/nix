# Home Manager for the Ubuntu work laptop. The ignored ./local/user.nix sets
# home.username, home.homeDirectory and workstation.host.
_:

{
  imports = [ ../../home/ubuntu.nix ];

  workstation.sshProfile = "work";

  home.stateVersion = "26.11";
}
