# The work Mac: the shared apps, Mise with the work tools, and the work SSH
# keys. Work's own apps stay out of this repo.
{ config, ... }:

{
  homebrew.brews = [ "mise" ];

  home-manager.users.${config.system.primaryUser} =
    { config, ... }:
    {
      workstation.sshProfile = "work";
      xdg.configFile."mise/conf.d/work.toml".source = config.lib.workstation.link "mise/conf.d/work.toml";
    };
}
