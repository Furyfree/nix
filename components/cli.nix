# Shell packages and utilities used by the shared Bash and Zsh configs.
{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    # Sheldon initializes completion after adding its plugins to fpath.
    enableGlobalCompInit = false;
    # The user config initializes Starship.
    promptInit = "";
  };

  environment.systemPackages = with pkgs; [
    bat
    bash-completion
    blesh
    eza
    fzf
    git
    less
    sheldon
    starship
    wl-clipboard
    xclip
    zoxide
  ];
}
