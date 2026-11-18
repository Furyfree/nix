{ config, pkgs, ... }:

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
    nh = {
      enable = true;
      # Weekly; keeps the generations Limine's menu shows and any from the last
      # two weeks.
      clean = {
        enable = true;
        extraArgs = "--keep ${toString config.boot.loader.limine.maxGenerations} --keep-since 14d";
      };
    };
    git = {
      enable = true;
      lfs.enable = true;
    };
  };

  environment.systemPackages = import ./shell-packages.nix pkgs;
}
