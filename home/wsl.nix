# Home Manager settings for NixOS in WSL: common.nix without Zed, which runs on
# Windows, and Git through Windows' ssh.exe and 1Password's WSL signing
# program, since 1Password's agent lives on the Windows side.
{ config, lib, ... }:

let
  link =
    path:
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/nix/configs/${path}";
in
{
  imports = [ ./common.nix ];

  programs.zed-editor.enable = lib.mkForce false;

  xdg.configFile = {
    "mise/conf.d/agents.toml".source = link "mise/conf.d/agents.toml";
    "mise/conf.d/runtimes.toml".source = link "mise/conf.d/runtimes.toml";
    # git/config includes this; both programs come through Windows' PATH.
    "git/windows".text = ''
      [core]
      	sshCommand = ssh.exe
      [gpg "ssh"]
      	program = op-ssh-sign-wsl.exe
    '';
  };
}
