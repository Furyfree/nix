{ pkgs, ... }:

{
  users.defaultUserShell = pkgs.zsh;
  programs = {
    zsh = {
      enable = true;
      # Native user config owns completion initialization and the prompt.
      enableGlobalCompInit = false;
      promptInit = "";
    };
    # NH_FLAKE comes from the user's shell, which knows the checkout path.
    nh.enable = true;
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
