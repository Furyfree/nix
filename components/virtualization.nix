# Docker for development and the Windows VM container.
{ config, lib, ... }:

{
  virtualisation.docker = {
    enable = true;
    daemon.settings.log-driver = "local";
  };

  # The docker group is root-equivalent, as on Fedora. Installer-selected
  # users come from Home Manager, so no username is written here.
  users.users = lib.genAttrs (builtins.attrNames config.home-manager.users) (_: {
    extraGroups = [ "docker" ];
  });
}
