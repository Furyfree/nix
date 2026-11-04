# Home Manager for the account that ./local/user.nix names.
_:

{
  imports = [ ../../home/darwin.nix ];

  home.stateVersion = "26.11";
}
