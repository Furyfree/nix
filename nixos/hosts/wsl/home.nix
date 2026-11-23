# Home Manager for the WSL account: home-manager/common.nix without Zed, which
# runs on Windows, and Git through Windows' ssh.exe and 1Password's WSL signing
# program, since 1Password's agent lives on the Windows side.
{ config, lib, ... }:

let
  inherit (config.lib.workstation) link;
in
{
  imports = [ ../../../home-manager/common.nix ];

  programs.zed-editor.enable = lib.mkForce false;

  xdg.configFile = {
    "mise/conf.d/wsl.toml".source = link "mise/conf.d/wsl.toml";
    # git/config includes this. Windows' own ssh by path, as on Windows: Git
    # for Windows' ssh, first in PATH under Git Bash, cannot reach the agent.
    # The signing program comes through Windows' PATH.
    "git/windows".text = ''
      [core]
      	sshCommand = /mnt/c/Windows/System32/OpenSSH/ssh.exe
      [gpg "ssh"]
      	program = op-ssh-sign-wsl.exe
    '';
  };

  home.stateVersion = "26.11";
}
