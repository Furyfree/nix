# Shared user config mappings for the Linux workstations.
{ config, pkgs, ... }:

let
  # Link editable files from the checkout, rather than a copy in the Nix store.
  configs = "${config.home.homeDirectory}/Projects/nix/configs";
  link = config.lib.file.mkOutOfStoreSymlink;
in
{
  home.file = {
    ".bashrc".source = link "${configs}/bash/.bashrc";
    ".bash_profile".source = link "${configs}/bash/.bash_profile";
    ".blerc".source = link "${configs}/bash/.blerc";
    ".zshenv".source = link "${configs}/zsh/.zshenv";
  };

  xdg.enable = true;
  xdg.configFile = {
    "bash/bashrc".source = link "${configs}/bash/bashrc";
    "bash/profile".source = link "${configs}/bash/profile";
    "bash/blerc".source = link "${configs}/bash/blerc";
    "bash/conf.d".source = link "${configs}/bash/conf.d";
    "zsh/.zshrc".source = link "${configs}/zsh/.zshrc";
    "zsh/.zprofile".source = link "${configs}/zsh/.zprofile";
    "zsh/conf.d".source = link "${configs}/zsh/conf.d";
    "starship.toml".source = link "${configs}/starship/starship.toml";
    "sheldon/plugins.toml".source = link "${configs}/sheldon/plugins.toml";
  };

  # The existing Bash config looks for these under XDG_DATA_HOME first.
  xdg.dataFile = {
    "blesh".source = "${pkgs.blesh}/share/blesh";
    "bash-completion".source = "${pkgs.bash-completion}/share/bash-completion";
  };
}
