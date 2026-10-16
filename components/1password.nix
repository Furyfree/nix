# 1Password app, CLI and SSH agent; 1Password keeps the vault and sign-ins.
{ config, ... }:

{
  programs = {
    _1password.enable = true;
    _1password-gui = {
      enable = true;
      # Unlock the CLI and browser integration with system authentication.
      polkitPolicyOwners = builtins.attrNames config.home-manager.users;
    };
  };
}
