# Strata replaces Nautilus as the file manager:
# https://github.com/Furyfree/nix/issues/18. Its FileManager1 service answers
# "Show in folder". File dialogs stay GTK's, since Strata's chooser handles
# local files only (strata#176).
{ inputs, pkgs, ... }:

let
  strata = inputs.strata.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  environment.systemPackages = [ strata ];
  services.dbus.packages = [ strata.fileManagerService ];
}
