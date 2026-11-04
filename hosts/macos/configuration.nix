# Every Mac. The ignored ./local/user.nix names the account and imports this
# Mac's profile from darwin/ (personal.nix or work.nix), e.g.:
#   { imports = [ ../../../darwin/personal.nix ]; system.primaryUser = "alice"; }
{ config, ... }:

{
  imports = [ ../../darwin ];

  home-manager.users.${config.system.primaryUser} = import ./home.nix;

  system.stateVersion = 6;
}
