{ pkgs, ... }:

{
  # jq: nix-workstation, and Noctalia's plugin commands on the desktops.
  environment.systemPackages = [
    pkgs.ffmpeg
    pkgs.jq
  ];
}
