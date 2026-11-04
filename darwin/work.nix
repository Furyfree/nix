# The work Mac: the shared apps, Mise with the agent CLIs, and the work SSH
# keys. Work's own apps stay out of this repo.
{ config, ... }:

{
  homebrew.brews = [ "mise" ];

  home-manager.users.${config.system.primaryUser} =
    { config, ... }:
    {
      workstation.sshProfile = "work";
      xdg.configFile."mise/conf.d/agents.toml".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/mise/conf.d/agents.toml";
    };
}
