{ pkgs, ... }:

{
  users.defaultUserShell = pkgs.zsh;
  programs.zsh = {
    enable = true;
    # Native user config owns completion initialization and the prompt.
    enableGlobalCompInit = false;
    promptInit = "";
  };

  environment.systemPackages = with pkgs; [
    starship
    fzf
    zoxide
    git
    wl-clipboard
    sheldon
    bat
    eza
    yazi
    fd
    ripgrep
    fastfetch
    tealdeer
  ];
}
