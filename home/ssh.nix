# Which SSH keys a machine gets. Personal machines offer the GitHub, homelab and
# personal keys; work machines the GitHub and work keys. Hosts and the default
# key come from the profile's private 1Password document (INSTALLATION.md).
{ config, lib, ... }:

{
  options.workstation.sshProfile = lib.mkOption {
    type = lib.types.enum [
      "personal"
      "work"
    ];
    default = "personal";
    description = "SSH key set for this machine; work hosts set it in hosts/<host>/home.nix.";
  };

  config.xdg.configFile."1Password/ssh/agent.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/1password/ssh/${config.workstation.sshProfile}.toml";
}
