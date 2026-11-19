# Which SSH keys a machine gets. Personal machines use the GitHub, homelab and
# personal keys; work machines the GitHub and work keys. Each profile has its
# own SSH config and 1Password agent file in configs/; hosts stay in the
# profile's private 1Password document (README.md, SSH keys).
{ config, lib, ... }:

let
  inherit (config.workstation) sshProfile;
  inherit (config.lib.workstation) link;
in
{
  options.workstation.sshProfile = lib.mkOption {
    type = lib.types.enum [
      "personal"
      "work"
    ];
    default = "personal";
    description = "SSH key set for this machine; darwin/work.nix and ubuntu/home.nix set work.";
  };

  config = {
    home.file.".ssh/config".source = link "ssh/${sshProfile}.conf";
    xdg.configFile."1Password/ssh/agent.toml".source = link "1password/ssh/${sshProfile}.toml";
  };
}
